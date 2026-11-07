--!strict
-- Armes côté serveur : charge (loadout), équipement, tirs, coups de mêlée, parade,
-- rechargement. Le serveur fait foi : il vérifie chaque requête et calcule lui-même les
-- touches avec compensation de latence.
-- Studio : ServerScriptService > Server > Systems > WeaponService
--
-- Tir (hitscan) — vérifications dans l'ordre :
--   1. types (Vector3 finis, heure)            4. origine proche du joueur
--   2. arme équipée de type « Hitscan »        5. obstacle du décor (rayon réel)
--   3. cadence, munitions, rechargement        6. cibles « remontées dans le temps »
-- Le client ne choisit JAMAIS ce qu'il touche ni les dégâts.
--
-- Charge : emplacement 1 = arme à feu, 2 = mêlée. Par défaut l'équipement de base
-- (pistolet, lame courte) ; l'armurerie du Refuge permet d'en changer (WeaponService.setWeapon).
-- Le futur système d'inventaire passera par la même fonction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Ability = require(Shared.Combat.Ability)
local CombatConfig = require(Shared.Combat.CombatConfig)
local Damage = require(Shared.Combat.Damage)
local HitMath = require(Shared.Combat.HitMath)
local Parry = require(Shared.Combat.Parry)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local WeaponState = require(Shared.Combat.WeaponState)
local Guard = require(Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local CombatTargets = require(script.Parent.CombatTargets)
local HealthService = require(script.Parent.HealthService)
local MovementGuard = require(script.Parent.MovementGuard)
local WeaponModels = require(script.Parent.Parent.Lib.WeaponModels)

local BASE_LOADOUT = table.freeze({ "weapon.fracture_pistol", "weapon.short_blade" })
local SLOT_KIND: { [number]: WeaponDefs.Slot } = { "Firearm", "Melee" }
local FIRE_TOLERANCE = 0.05 -- gigue réseau acceptée sur la cadence
local INTERPOLATION_DELAY = 0.05 -- retard d'affichage des autres joueurs chez le tireur
local HEAVY_COOLDOWN_FACTOR = 2.2 -- l'attaque chargée occupe plus de temps qu'un coup simple
local PIERCE_FALLOFF = 0.7 -- dégâts conservés par cible traversée
-- Enchaînement de mêlée (v0.4.6) : 3 coups, le 3e (estoc) fait plus mal.
local COMBO_WINDOW = 0.9
local COMBO_LENGTH = 3
local THRUST_MULTIPLIER = 1.3
-- Fente de mêlée côté client : quelques studs très vite (voir CombatController).
local LUNGE_ALLOWANCE = 0.5
local LUNGE_SPEED = 40

type Loadout = {
	weapons: { string }, -- [1] arme à feu, [2] mêlée
	equipped: number, -- 0 = mains nues
	states: { [string]: WeaponState.State },
	parry: Parry.State,
	lastMelee: number, -- heure du dernier coup simple (enchaînement)
	combo: number,
}

local WeaponService = {}

local loadouts: { [Player]: Loadout } = {}
-- Bonus du prochain coup de mêlée (Riposte, Pas de l'ombre) : multiplicateur et échéance.
local hitBonuses: { [Player]: { multiplier: number, expires: number } } = {}
-- Salve au levier (fusil) : tirs autorisés sans attendre la cadence.
local volleys: { [Player]: { remaining: number, expires: number } } = {}
-- Modificateur de dégâts des tirs (Souffle, bulle de stase), fourni par AbilityService.
local damageModifier: ((Player, WeaponDefs.WeaponDef, Vector3, Vector3, boolean) -> number)? = nil

local function rootOf(model: Model?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function canAct(player: Player): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	return character:GetAttribute("Downed") ~= true and character:GetAttribute("Dead") ~= true
end

local function stateFor(loadout: Loadout, id: string): WeaponState.State
	local state = loadout.states[id]
	if state == nil then
		state = WeaponState.new(WeaponDefs[id])
		loadout.states[id] = state
	end
	return state
end

local function equippedDef(player: Player): (WeaponDefs.WeaponDef?, WeaponState.State?)
	local loadout = loadouts[player]
	if loadout == nil or loadout.equipped == 0 then
		return nil, nil
	end
	local id = loadout.weapons[loadout.equipped]
	if id == nil then
		return nil, nil
	end
	return WeaponDefs[id], stateFor(loadout, id)
end

-- Envoie l'état réel au joueur : (idArme, munitions, secondes de rechargement restantes).
local function sendState(player: Player, def: WeaponDefs.WeaponDef, state: WeaponState.State)
	local remaining = if state.reloadEndsAt then math.max(0, state.reloadEndsAt - os.clock()) else 0
	Net.fire("WeaponState", player, def.id, state.ammo, remaining)
end

-- La charge est publiée en attributs du joueur (répliqués, lecture seule pour le client) :
-- Loadout1 = arme à feu, Loadout2 = mêlée.
local function sendLoadout(player: Player)
	local loadout = loadouts[player]
	if loadout then
		for slot = 1, #SLOT_KIND do
			player:SetAttribute(`Loadout{slot}`, loadout.weapons[slot] or "")
		end
	end
end

-- Heure « vue par le tireur » : heure annoncée, bornée, moins sa latence d'affichage.
local function viewTime(player: Player, clientTime: number): number
	local now = workspace:GetServerTimeNow()
	local t = math.clamp(clientTime, now - CombatConfig.MAX_REWIND, now)
	local ping = player:GetNetworkPing() -- aller-retour, en secondes
	return math.max(now - CombatConfig.MAX_REWIND, t - ping / 2 - INTERPOLATION_DELAY)
end

local function excludeAllTargets(shooter: Model?): RaycastParams
	local list: { Instance } = {}
	for model in CombatTargets.all() do
		table.insert(list, model)
	end
	if shooter then
		table.insert(list, shooter)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	return params
end

type Hit = { target: CombatTargets.Target, distance: number, headshot: boolean }

-- Toutes les cibles touchées par le rayon avant `maxDistance`, de la plus proche à la plus
-- lointaine.
local function traceTargets(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	t: number
): { Hit }
	local hits: { Hit } = {}
	local tolerance = CombatConfig.HITBOX_TOLERANCE
	for model, target in CombatTargets.all() do
		if target.player == shooter or not HealthService.canDamage(shooter, model) then
			continue
		end
		local cf = CombatTargets.rewind(target, t)
		if (cf.Position - origin).Magnitude > maxDistance + 8 then
			continue
		end
		local o = cf:PointToObjectSpace(origin)
		local d = cf:VectorToObjectSpace(direction)
		local box = target.hitbox
		local head = HitMath.raySphere(
			o.X,
			o.Y,
			o.Z,
			d.X,
			d.Y,
			d.Z,
			box.headOffset.X,
			box.headOffset.Y,
			box.headOffset.Z,
			box.headRadius + tolerance,
			maxDistance
		)
		local bo = o - box.bodyOffset
		local half = box.bodyHalfSize + Vector3.one * tolerance
		local body =
			HitMath.rayBox(bo.X, bo.Y, bo.Z, d.X, d.Y, d.Z, half.X, half.Y, half.Z, maxDistance)
		if head and (body == nil or head <= body + 0.3) then
			table.insert(hits, { target = target, distance = head, headshot = true })
		elseif body then
			table.insert(hits, { target = target, distance = body, headshot = false })
		end
	end
	table.sort(hits, function(a, b)
		return a.distance < b.distance
	end)
	return hits
end

local function notifyHit(
	attacker: Player?,
	victimTarget: CombatTargets.Target,
	result: any,
	headshot: boolean,
	origin: Vector3
)
	if attacker then
		Net.fire("CombatEvent", attacker, {
			type = "Hit",
			amount = result.applied,
			headshot = headshot,
			killed = result.killed,
			downed = result.downed,
			position = victimTarget.root.Position,
		})
	end
	local victim = victimTarget.player
	if victim then
		Net.fire(
			"CombatEvent",
			victim,
			{ type = "Damaged", amount = result.applied, from = origin }
		)
	end
end

local function applyHit(
	shooter: Player,
	def: WeaponDefs.WeaponDef,
	hit: Hit,
	origin: Vector3,
	extra: number?,
	point: Vector3?
)
	-- Modificateurs posés par les capacités (Souffle, bulle de stase…), voir AbilityService.
	local modifier = if damageModifier and point
		then damageModifier(shooter, def, origin, point, hit.headshot)
		else 1
	local amount = Damage.compute(
		def,
		hit.distance,
		hit.headshot,
		CombatConfig.HEADSHOT_MULTIPLIER,
		(extra or 1) * modifier
	)
	local result = HealthService.applyDamage(hit.target.model, amount, {
		attacker = shooter,
		weaponId = def.id,
		headshot = hit.headshot,
		origin = origin,
	})
	if result then
		notifyHit(shooter, hit.target, result, hit.headshot, origin)
		-- Trait « recharge sur élimination » (pistolet) : chargeur plein immédiatement.
		local loadout = loadouts[shooter]
		if loadout and def.passive == "ReloadOnKill" and (result.killed or result.downed) then
			local state = stateFor(loadout, def.id)
			WeaponState.cancelReload(state)
			state.ammo = def.magazine
			sendState(shooter, def, state)
			Net.fire("CombatEvent", shooter, { type = "Passive", passive = "ReloadOnKill" })
		end
	end
end

local function broadcastFx(except: Player?, info: { [string]: any })
	for _, other in Players:GetPlayers() do
		if other ~= except then
			Net.fire("ShotFx", other, info)
		end
	end
end

-- Parade ---------------------------------------------------------------------------------

-- Le défenseur pare-t-il un coup venu de `attackerPosition` ? Si oui : effets et notifications.
local function tryParry(defender: CombatTargets.Target, attackerPosition: Vector3): boolean
	local player = defender.player
	local loadout = player and loadouts[player]
	if player == nil or loadout == nil then
		return false
	end
	local root = defender.root
	local toAttacker = attackerPosition - root.Position
	local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	local look = root.CFrame.LookVector
	local angle = if flat.Magnitude > 0.1
		then HitMath.angleBetween(look.X, 0, look.Z, flat.Unit.X, 0, flat.Unit.Z)
		else 0
	if not Parry.blocks(loadout.parry, os.clock(), angle, Parry.NETWORK_TOLERANCE) then
		return false
	end
	Net.fire("CombatEvent", player, { type = "ParrySuccess", from = attackerPosition })
	broadcastFx(player, { shooter = player, kind = "ParrySuccess" })
	return true
end

local function stunAttacker(attackerPlayer: Player?, attackerModel: Model)
	local now = os.clock()
	if attackerPlayer then
		local loadout = loadouts[attackerPlayer]
		if loadout then
			Parry.stun(loadout.parry, now)
		end
		Net.fire(
			"CombatEvent",
			attackerPlayer,
			{ type = "Stunned", duration = Parry.STUN_DURATION }
		)
	end
	-- Les ennemis lisent cet attribut pour suspendre leurs attaques.
	attackerModel:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + Parry.STUN_DURATION)
end

-- Frappe de mêlée générique (joueurs et, plus tard, Échoués). Choisit la cible la plus proche
-- dans le cône, vérifie la ligne de vue et la parade, applique les dégâts.
-- Renvoie "Hit", "Parried" ou nil (rien touché).
function WeaponService.meleeStrike(
	attackerModel: Model,
	attackerPlayer: Player?,
	def: WeaponDefs.WeaponDef,
	direction: Vector3,
	rewindTime: number,
	extra: number?
): string?
	local root = rootOf(attackerModel)
	if root == nil then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	local halfArc = (def.arcDegrees or 60) / 2
	local losParams = excludeAllTargets(attackerModel)

	local best: Hit? = nil
	for model, target in CombatTargets.all() do
		if model == attackerModel or not HealthService.canDamage(attackerPlayer, model) then
			continue
		end
		-- Un ennemi (ou un mannequin) ne frappe que les joueurs, pas ses semblables.
		if attackerPlayer == nil and target.kind ~= "Player" then
			continue
		end
		local position = CombatTargets.rewind(target, rewindTime).Position
		local offset = position - root.Position
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		if horizontal.Magnitude > def.range + 1 or math.abs(offset.Y) > 5 then
			continue
		end
		local angle = if horizontal.Magnitude > 0.5
			then HitMath.angleBetween(flat.X, 0, flat.Z, horizontal.Unit.X, 0, horizontal.Unit.Z)
			else 0
		if angle > halfArc then
			continue
		end
		if workspace:Raycast(root.Position, offset, losParams) then
			continue -- mur entre les deux
		end
		if best == nil or horizontal.Magnitude < best.distance then
			best = { target = target, distance = horizontal.Magnitude, headshot = false }
		end
	end
	if best == nil then
		return nil
	end
	if tryParry(best.target, root.Position) then
		stunAttacker(attackerPlayer, attackerModel)
		-- Trait « Riposte » (lame courte) : le coup suivant du défenseur fait ×2.
		local defender = best.target.player
		local defenderLoadout = defender and loadouts[defender]
		local defenderWeapon = defenderLoadout and defenderLoadout.weapons[defenderLoadout.equipped]
		local defenderDef = defenderWeapon and WeaponDefs[defenderWeapon]
		if defender and defenderDef and defenderDef.passive == "Riposte" then
			WeaponService.grantNextHitBonus(
				defender,
				Ability.RIPOSTE_MULTIPLIER,
				Ability.RIPOSTE_WINDOW
			)
			Net.fire("CombatEvent", defender, { type = "Passive", passive = "Riposte" })
		end
		return "Parried"
	end
	-- Bonus en attente (Riposte, attaque dans le dos) : consommé par ce coup.
	if attackerPlayer then
		local bonus = hitBonuses[attackerPlayer]
		if bonus then
			hitBonuses[attackerPlayer] = nil
			if os.clock() <= bonus.expires then
				extra = (extra or 1) * bonus.multiplier
			end
		end
	end
	local amount =
		Damage.compute(def, best.distance, false, CombatConfig.HEADSHOT_MULTIPLIER, extra)
	local result = HealthService.applyDamage(best.target.model, amount, {
		attacker = attackerPlayer,
		weaponId = def.id,
		headshot = false,
		origin = root.Position,
	})
	if result then
		notifyHit(attackerPlayer, best.target, result, false, root.Position)
		return "Hit"
	end
	return nil
end

-- Charge ---------------------------------------------------------------------------------

-- Place une arme dans un emplacement (1 = arme à feu, 2 = mêlée). Seul point d'entrée pour
-- changer d'arme (armurerie aujourd'hui, inventaire demain). Renvoie false si refusé.
function WeaponService.setWeapon(player: Player, slot: number, id: string): boolean
	local loadout = loadouts[player]
	local def = WeaponDefs[id]
	if loadout == nil or def == nil or SLOT_KIND[slot] ~= def.slot then
		return false
	end
	local previous = loadout.weapons[slot]
	if previous and loadout.states[previous] then
		WeaponState.cancelReload(loadout.states[previous])
	end
	loadout.weapons[slot] = id
	loadout.states[id] = WeaponState.new(def)
	if loadout.equipped == slot then
		local character = player.Character
		if character then
			character:SetAttribute("EquippedWeapon", id)
			WeaponModels.equip(character, id)
		end
		sendState(player, def, loadout.states[id])
	end
	sendLoadout(player)
	return true
end

-- Salve au levier : les `shots` prochains tirs ignorent la cadence pendant `window` secondes.
function WeaponService.grantVolley(player: Player, shots: number, window: number)
	volleys[player] = { remaining = shots, expires = os.clock() + window }
end

-- Modificateur de dégâts appliqué à chaque tir (une seule fonction, fournie à l'init).
function WeaponService.setDamageModifier(fn: (
	Player,
	WeaponDefs.WeaponDef,
	Vector3,
	Vector3
) -> number)
	damageModifier = fn
end

-- La cible pare-t-elle un coup venu de `fromPosition` ? (Onde de fracture : parable)
function WeaponService.tryParryFrom(model: Model, fromPosition: Vector3): boolean
	local target = CombatTargets.get(model)
	return target ~= nil and tryParry(target, fromPosition)
end

-- Dégâts d'une capacité (Onde de fracture) : mêmes règles et retours qu'un coup normal.
function WeaponService.dealDamage(
	player: Player,
	def: WeaponDefs.WeaponDef,
	model: Model,
	amount: number,
	origin: Vector3
): boolean
	local target = CombatTargets.get(model)
	if target == nil then
		return false
	end
	local result = HealthService.applyDamage(
		model,
		amount,
		{ attacker = player, weaponId = def.id, headshot = false, origin = origin }
	)
	if result then
		notifyHit(player, target, result, false, origin)
	end
	return result ~= nil
end

-- Le prochain coup de mêlée du joueur (s'il touche dans `duration` secondes) fait ×multiplier.
function WeaponService.grantNextHitBonus(player: Player, multiplier: number, duration: number)
	hitBonuses[player] = { multiplier = multiplier, expires = os.clock() + duration }
end

-- Arme en main (définition) et son emplacement, ou nil mains nues.
function WeaponService.getEquipped(player: Player): (WeaponDefs.WeaponDef?, number)
	local loadout = loadouts[player]
	if loadout == nil or loadout.equipped == 0 then
		return nil, 0
	end
	local id = loadout.weapons[loadout.equipped]
	return if id then WeaponDefs[id] else nil, loadout.equipped
end

-- Le joueur peut-il agir (vivant, debout, pas étourdi par une parade) ?
function WeaponService.canUseAbility(player: Player): boolean
	local loadout = loadouts[player]
	return loadout ~= nil and canAct(player) and not Parry.isStunned(loadout.parry, os.clock())
end

function WeaponService.getLoadout(player: Player): { string }?
	local loadout = loadouts[player]
	return if loadout then table.clone(loadout.weapons) else nil
end

-- Gestionnaires -------------------------------------------------------------------------

local function onEquip(player: Player, slot: unknown)
	local loadout = loadouts[player]
	if loadout == nil or not Guard.isIntegerInRange(slot, 0, #loadout.weapons) then
		return
	end
	local current = loadout.weapons[loadout.equipped]
	if current and loadout.states[current] then
		WeaponState.cancelReload(loadout.states[current])
	end
	loadout.equipped = slot :: number
	local id = loadout.weapons[loadout.equipped]
	local character = player.Character
	if character then
		character:SetAttribute("EquippedWeapon", id or "")
		WeaponModels.equip(character, id)
	end
	local def = id and WeaponDefs[id]
	if def then
		sendState(player, def, stateFor(loadout, def.id))
	end
end

-- Tir réel (déjà validé) : décor, cibles remontées dans le temps, perforation, ricochet.
-- Renvoie les points de la trajectoire (départ, [rebond], arrivée) et le premier impact.
local function performShot(
	player: Player,
	def: WeaponDefs.WeaponDef,
	o: Vector3,
	dir: Vector3,
	t: number,
	ricochet: boolean,
	rangeOverride: number?
): ({ Vector3 }, Vector3)
	local params = excludeAllTargets(player.Character)
	local range = rangeOverride or def.range
	local world = workspace:Raycast(o, dir * range, params)
	local maxDistance = if world then world.Distance else range
	local hits = traceTargets(player, o, dir, maxDistance, t)
	local maxTargets = 1 + (def.pierce or 0)
	local endDistance = maxDistance
	for index, hit in hits do
		if index > maxTargets then
			break
		end
		applyHit(player, def, hit, o, PIERCE_FALLOFF ^ (index - 1), o + dir * hit.distance)
		endDistance = hit.distance
	end
	if #hits > 0 and #hits <= maxTargets and (def.pierce or 0) > 0 then
		endDistance = maxDistance -- un carreau qui traverse continue jusqu'au mur
	elseif #hits > 0 then
		endDistance = hits[math.min(#hits, maxTargets)].distance
	end
	local finish = o + dir * endDistance
	-- Premier impact (cible ou mur) : là où naît une bulle de stase.
	local firstImpact = if hits[1] then o + dir * hits[1].distance else o + dir * maxDistance
	local points = { o, finish }
	-- Balle de rebond : si rien n'a été touché avant le mur, elle repart une fois.
	if ricochet and #hits == 0 and world then
		local normal = world.Normal
		local bounced = (dir - 2 * dir:Dot(normal) * normal).Unit
		local from = world.Position + normal * 0.05
		local remaining = math.max(0, range - world.Distance)
		local second = workspace:Raycast(from, bounced * remaining, params)
		local secondMax = if second then second.Distance else remaining
		local secondHits = traceTargets(player, from, bounced, secondMax, t)
		local stop = secondMax
		local first = secondHits[1]
		if first then
			local along = first.distance
			first.distance += world.Distance -- chute des dégâts sur le trajet total
			applyHit(player, def, first, from, nil, from + bounced * along)
			stop = along
		end
		finish = from + bounced * stop
		points = { o, world.Position, finish }
		firstImpact = finish
	end
	return points, firstImpact
end

-- Vérifications communes à tout tir demandé par un client. Renvoie arme, état, origine, direction.
local function validateShot(
	player: Player,
	origin: unknown,
	direction: unknown,
	clientTime: unknown
): (WeaponDefs.WeaponDef?, WeaponState.State?, Vector3, Vector3)
	if
		not (
			Guard.isFiniteVector3(origin)
			and Guard.isFiniteVector3(direction)
			and Guard.isFiniteNumber(clientTime)
		)
	then
		return nil, nil, Vector3.zero, Vector3.zero
	end
	local o, dir = origin :: Vector3, direction :: Vector3
	if dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
		return nil, nil, o, dir
	end
	local def, state = equippedDef(player)
	if def == nil or state == nil or def.kind ~= "Hitscan" or not canAct(player) then
		return nil, nil, o, dir
	end
	local root = rootOf(player.Character)
	if root == nil or (o - root.Position).Magnitude > CombatConfig.MAX_MUZZLE_OFFSET then
		return nil, nil, o, dir
	end
	return def, state, o, dir.Unit
end

local function onFire(player: Player, origin: unknown, direction: unknown, clientTime: unknown)
	local def, state, o, dir = validateShot(player, origin, direction, clientTime)
	if def == nil or state == nil then
		return
	end
	local now = os.clock()
	-- Salve au levier : la cadence est ignorée pour les tirs de la salve (munitions requises).
	local volley = volleys[player]
	if volley and volley.remaining > 0 and now <= volley.expires then
		if state.ammo <= 0 or WeaponState.isReloading(state, now, def) then
			return
		end
		volley.remaining -= 1
	elseif not WeaponState.canFire(state, def, now, FIRE_TOLERANCE) then
		sendState(player, def, state) -- resynchronise un client qui s'est trompé
		return
	end
	WeaponState.fire(state, def, now)
	local points = performShot(player, def, o, dir, viewTime(player, clientTime :: number), false)
	broadcastFx(player, {
		shooter = player,
		kind = "Shot",
		weapon = def.id,
		origin = points[1],
		finish = points[#points],
	})
end

-- Tir spécial d'une capacité (balle de rebond, carreau de stase) : mêmes vérifications qu'un
-- tir normal sauf la cadence ; consomme une munition (sauf `useAmmo = false`). Renvoie le
-- premier impact, ou nil et la raison du refus (« NoAmmo », « Invalid »).
function WeaponService.fireSpecial(
	player: Player,
	kind: string,
	origin: unknown,
	direction: unknown,
	clientTime: unknown,
	options: { useAmmo: boolean, range: number? }?
): (Vector3?, string?)
	local def, state, o, dir = validateShot(player, origin, direction, clientTime)
	if def == nil or state == nil then
		return nil, "Invalid"
	end
	local now = os.clock()
	-- Un tir spécial peut se passer de munition (carreau de stase : tiré par le noyau).
	local useAmmo = options == nil or options.useAmmo
	if useAmmo then
		if state.ammo <= 0 or WeaponState.isReloading(state, now, def) then
			return nil, "NoAmmo"
		end
		WeaponState.fire(state, def, now)
		sendState(player, def, state)
	end
	local points, impact = performShot(
		player,
		def,
		o,
		dir,
		viewTime(player, clientTime :: number),
		kind == "Ricochet",
		options and options.range
	)
	for _, other in Players:GetPlayers() do
		Net.fire(
			"ShotFx",
			other,
			{ shooter = player, kind = kind, weapon = def.id, points = points }
		)
	end
	return impact, nil
end

local function onReload(player: Player)
	local def, state = equippedDef(player)
	if def and state and canAct(player) and WeaponState.reload(state, def, os.clock()) then
		sendState(player, def, state)
		-- Publié pour l'animation de rechargement (visible par tous).
		local character = player.Character
		if character then
			character:SetAttribute("ReloadWeapon", def.id)
			character:SetAttribute("ReloadEnd", workspace:GetServerTimeNow() + def.reloadTime)
		end
	end
end

local function onMelee(player: Player, heavy: unknown, direction: unknown, clientTime: unknown)
	if
		typeof(heavy) ~= "boolean"
		or not Guard.isFiniteVector3(direction)
		or not Guard.isFiniteNumber(clientTime)
	then
		return
	end
	local loadout = loadouts[player]
	local def, state = equippedDef(player)
	if
		loadout == nil
		or def == nil
		or state == nil
		or def.kind ~= "Melee"
		or not canAct(player)
		or (player.Character :: Model):GetAttribute("TimeGuard") == true
	then
		return
	end
	local now = os.clock()
	if
		Parry.isStunned(loadout.parry, now)
		or not WeaponState.canFire(state, def, now, FIRE_TOLERANCE)
	then
		return
	end
	WeaponState.fire(state, def, now)
	if heavy then
		-- L'attaque chargée occupe plus longtemps l'arme : jamais plus forte que le spam.
		state.lastShot = now + (HEAVY_COOLDOWN_FACTOR - 1) / def.fireRate
	end
	-- Enchaînement (même calcul que le client) : le coup chargé le remet à zéro.
	if heavy then
		loadout.combo = 0
	elseif now - loadout.lastMelee <= COMBO_WINDOW then
		loadout.combo = loadout.combo % COMBO_LENGTH + 1
	else
		loadout.combo = 1
	end
	if not heavy then
		loadout.lastMelee = now
	else
		loadout.lastMelee = -math.huge
	end
	local multiplier = if heavy
		then def.heavyMultiplier
		elseif loadout.combo == COMBO_LENGTH then THRUST_MULTIPLIER
		else nil
	-- Le client avance de quelques studs vers sa cible : la garde de mouvement le tolère.
	MovementGuard.allow(player, LUNGE_ALLOWANCE, LUNGE_SPEED, 0)
	local character = player.Character :: Model
	WeaponService.meleeStrike(
		character,
		player,
		def,
		direction :: Vector3,
		viewTime(player, clientTime :: number),
		multiplier
	)
	broadcastFx(player, {
		shooter = player,
		kind = if heavy then "HeavySwing" else "Swing",
		weapon = def.id,
		combo = if heavy then 1 else loadout.combo,
	})
end

local function onParry(player: Player)
	local loadout = loadouts[player]
	local def = equippedDef(player)
	if loadout == nil or def == nil or def.kind ~= "Melee" or not canAct(player) then
		return
	end
	if Parry.start(loadout.parry, os.clock(), def.parryWindow or 0.2) then
		broadcastFx(player, { shooter = player, kind = "Parry", weapon = def.id })
	end
end

function WeaponService.init()
	Net.on("EquipWeapon", onEquip)
	Net.on("FireWeapon", onFire)
	Net.on("ReloadWeapon", onReload)
	Net.on("MeleeSwing", onMelee)
	Net.on("Parry", onParry)

	local function onCharacter(player: Player, character: Model)
		local previous = loadouts[player]
		-- La charge choisie est conservée d'une vie à l'autre (pas encore sauvegardée).
		local weapons = if previous then previous.weapons else table.clone(BASE_LOADOUT)
		loadouts[player] = {
			weapons = weapons,
			equipped = 0,
			states = {},
			parry = Parry.new(),
			lastMelee = -math.huge,
			combo = 0,
		}
		character:SetAttribute("EquippedWeapon", "")
		sendLoadout(player)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		loadouts[player] = nil
		hitBonuses[player] = nil
		volleys[player] = nil
	end)
end

return WeaponService
