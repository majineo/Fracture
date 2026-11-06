--!strict
-- Armes côté serveur : équipement, tirs, coups de mêlée, rechargement. Le serveur fait foi :
-- il vérifie chaque requête et calcule lui-même les touches avec compensation de latence.
-- Studio : ServerScriptService > Server > Systems > WeaponService
--
-- Tir (hitscan) — vérifications dans l'ordre :
--   1. types (Vector3 finis, heure)            4. origine proche du joueur
--   2. arme équipée de type « Hitscan »        5. obstacle du décor (rayon réel)
--   3. cadence, munitions, rechargement        6. cibles « remontées dans le temps »
-- Le client ne choisit JAMAIS ce qu'il touche ni les dégâts.
--
-- Équipement : v0.4.0 = équipement de base pour tous (pistolet, lame courte). Le système
-- d'inventaire et de charge le remplacera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Combat.CombatConfig)
local Damage = require(Shared.Combat.Damage)
local HitMath = require(Shared.Combat.HitMath)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local WeaponState = require(Shared.Combat.WeaponState)
local Guard = require(Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local CombatTargets = require(script.Parent.CombatTargets)
local HealthService = require(script.Parent.HealthService)
local WeaponModels = require(script.Parent.Parent.Lib.WeaponModels)

local BASE_LOADOUT = table.freeze({ "weapon.fracture_pistol", "weapon.short_blade" })
local FIRE_TOLERANCE = 0.05 -- gigue réseau acceptée sur la cadence
local INTERPOLATION_DELAY = 0.05 -- retard d'affichage des autres joueurs chez le tireur
local HEAVY_COOLDOWN_FACTOR = 2.2 -- l'attaque chargée occupe plus de temps qu'un coup simple

type Loadout = {
	weapons: { string },
	equipped: number, -- 0 = mains nues
	states: { [string]: WeaponState.State },
}

local WeaponService = {}

local loadouts: { [Player]: Loadout } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
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

local function equippedDef(player: Player): (WeaponDefs.WeaponDef?, WeaponState.State?)
	local loadout = loadouts[player]
	if loadout == nil or loadout.equipped == 0 then
		return nil, nil
	end
	local id = loadout.weapons[loadout.equipped]
	return WeaponDefs[id], loadout.states[id]
end

-- Envoie l'état réel au joueur : (idArme, munitions, secondes de rechargement restantes).
local function sendState(player: Player, def: WeaponDefs.WeaponDef, state: WeaponState.State)
	local remaining = if state.reloadEndsAt then math.max(0, state.reloadEndsAt - os.clock()) else 0
	Net.fire("WeaponState", player, def.id, state.ammo, remaining)
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

-- Première cible touchée par le rayon (origine, direction unitaire) avant `maxDistance`.
local function traceTargets(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	t: number
): Hit?
	local best: Hit? = nil
	local tolerance = CombatConfig.HITBOX_TOLERANCE
	for model, target in CombatTargets.all() do
		if target.player == shooter or not HealthService.canDamage(shooter, model) then
			continue
		end
		local cf = CombatTargets.rewind(target, t)
		-- Tri rapide : cible trop loin du rayon.
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
		local distance: number? = nil
		local headshot = false
		if head and (body == nil or head <= body + 0.3) then
			distance, headshot = head, true
		elseif body then
			distance = body
		end
		if distance and (best == nil or distance < best.distance) then
			best = { target = target, distance = distance, headshot = headshot }
		end
	end
	return best
end

local function applyHit(
	shooter: Player,
	def: WeaponDefs.WeaponDef,
	hit: Hit,
	origin: Vector3,
	extra: number?
)
	local amount =
		Damage.compute(def, hit.distance, hit.headshot, CombatConfig.HEADSHOT_MULTIPLIER, extra)
	local result = HealthService.applyDamage(hit.target.model, amount, {
		attacker = shooter,
		weaponId = def.id,
		headshot = hit.headshot,
		origin = origin,
	})
	if result == nil then
		return
	end
	Net.fire("CombatEvent", shooter, {
		type = "Hit",
		amount = result.applied,
		headshot = hit.headshot,
		killed = result.killed,
		downed = result.downed,
		position = hit.target.root.Position,
	})
	local victim = hit.target.player
	if victim then
		Net.fire(
			"CombatEvent",
			victim,
			{ type = "Damaged", amount = result.applied, from = origin }
		)
	end
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
		sendState(player, def, loadout.states[id])
	end
end

local function onFire(player: Player, origin: unknown, direction: unknown, clientTime: unknown)
	if
		not (
			Guard.isFiniteVector3(origin)
			and Guard.isFiniteVector3(direction)
			and Guard.isFiniteNumber(clientTime)
		)
	then
		return
	end
	local o, dir = origin :: Vector3, direction :: Vector3
	if dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
		return
	end
	dir = dir.Unit
	local def, state = equippedDef(player)
	if def == nil or state == nil or def.kind ~= "Hitscan" or not canAct(player) then
		return
	end
	local root = rootOf(player)
	if root == nil or (o - root.Position).Magnitude > CombatConfig.MAX_MUZZLE_OFFSET then
		return
	end
	local now = os.clock()
	if not WeaponState.canFire(state, def, now, FIRE_TOLERANCE) then
		sendState(player, def, state) -- resynchronise un client qui s'est trompé
		return
	end
	WeaponState.fire(state, def, now)

	-- Obstacle du décor : le tir s'arrête au premier mur.
	local world = workspace:Raycast(o, dir * def.range, excludeAllTargets(player.Character))
	local maxDistance = if world then world.Distance else def.range
	local hit = traceTargets(player, o, dir, maxDistance, viewTime(player, clientTime :: number))
	local endPoint = if hit then o + dir * hit.distance else o + dir * maxDistance
	if hit then
		applyHit(player, def, hit, o)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(
				"ShotFx",
				other,
				{ shooter = player, kind = "Shot", origin = o, finish = endPoint }
			)
		end
	end
end

local function onReload(player: Player)
	local def, state = equippedDef(player)
	if def and state and canAct(player) and WeaponState.reload(state, def, os.clock()) then
		sendState(player, def, state)
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
	local def, state = equippedDef(player)
	if def == nil or state == nil or def.kind ~= "Melee" or not canAct(player) then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	local now = os.clock()
	if not WeaponState.canFire(state, def, now, FIRE_TOLERANCE) then
		return
	end
	WeaponState.fire(state, def, now)
	if heavy then
		-- L'attaque chargée occupe plus longtemps l'arme : jamais plus forte que le spam.
		state.lastShot = now + (HEAVY_COOLDOWN_FACTOR - 1) / def.fireRate
	end

	local flat = Vector3.new((direction :: Vector3).X, 0, (direction :: Vector3).Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	local halfArc = (def.arcDegrees or 60) / 2
	local t = viewTime(player, clientTime :: number)
	local losParams = excludeAllTargets(player.Character)

	local best: Hit? = nil
	for model, target in CombatTargets.all() do
		if target.player == player or not HealthService.canDamage(player, model) then
			continue
		end
		local position = CombatTargets.rewind(target, t).Position
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
	if best then
		applyHit(player, def, best, root.Position, if heavy then def.heavyMultiplier else nil)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Net.fire(
				"ShotFx",
				other,
				{ shooter = player, kind = if heavy then "HeavySwing" else "Swing" }
			)
		end
	end
end

function WeaponService.init()
	Net.on("EquipWeapon", onEquip)
	Net.on("FireWeapon", onFire)
	Net.on("ReloadWeapon", onReload)
	Net.on("MeleeSwing", onMelee)

	local function onCharacter(player: Player, character: Model)
		local states = {}
		for _, id in BASE_LOADOUT do
			states[id] = WeaponState.new(WeaponDefs[id])
		end
		loadouts[player] = { weapons = table.clone(BASE_LOADOUT), equipped = 0, states = states }
		character:SetAttribute("EquippedWeapon", "")
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
	end)
end

return WeaponService
