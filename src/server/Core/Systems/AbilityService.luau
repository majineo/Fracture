--!strict
-- Capacités spéciales des armes (v0.4.5, D-038) : noyaux, Retour (pistolet), Pas de l'ombre
-- (lame courte). Le serveur fait foi : il vérifie tout et déplace lui-même le joueur.
-- Studio : ServerScriptService > Server > Systems > AbilityService
--
-- Noyau : un par arme, rempli par les dégâts infligés avec cette arme (Combat/Ability).
-- Publié en attributs du joueur : AbilityCharge1 / AbilityCharge2 (0 à 1, par emplacement).
-- Pendant la préparation d'une capacité, le personnage porte AbilityCast (id) et
-- AbilityCastEnd (heure serveur) : les clients affichent l'annonce.
-- Pas de l'ombre : la cible porte ShadowMarkedAt (heure serveur) ; une victime joueur reçoit
-- aussi un avertissement (CombatEvent « ShadowWarning »).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Ability = require(Shared.Combat.Ability)
local Guard = require(Shared.Util.Guard)
local WeaponDefs = require(Shared.Combat.WeaponDefs)
local Net = require(script.Parent.Parent.Lib.Net)
local CombatTargets = require(script.Parent.CombatTargets)
local HealthService = require(script.Parent.HealthService)
local MovementGuard = require(script.Parent.MovementGuard)
local WeaponService = require(script.Parent.WeaponService)

local SAMPLE_INTERVAL = 0.1
local HISTORY_DURATION = 3
local RANGE_TOLERANCE = 1.5 -- studs : écart de position dû à la latence
local MAX_HEIGHT_GAP = 6 -- Pas de l'ombre : différence de hauteur maximale avec la cible
local TELEPORT_GRACE = 1
local SLOTS = 2

type Sample = { position: Vector3, health: number }

local AbilityService = {}

local cores: { [Player]: { [string]: Ability.Core } } = {}
local histories: { [Player]: Ability.History<Sample> } = {}
local casting: { [Player]: boolean } = {}
-- Souffle (fusil) : depuis quand le joueur est immobile.
local stillSince: { [Player]: number } = {}
local lastPositions: { [Player]: Vector3 } = {}

local function rootOf(model: Model?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function abilityOf(weaponId: string?): Ability.AbilityDef?
	local def = weaponId and WeaponDefs[weaponId]
	local id = def and def.ability
	return if id then (Ability.DEFS :: any)[id] else nil
end

local function coreFor(player: Player, weaponId: string): Ability.Core
	local playerCores = cores[player]
	if playerCores == nil then
		playerCores = {}
		cores[player] = playerCores
	end
	local core = playerCores[weaponId]
	if core == nil then
		core = Ability.newCore()
		playerCores[weaponId] = core
	end
	return core
end

-- Publie le remplissage des noyaux des deux armes de la charge.
local function publish(player: Player)
	for slot = 1, SLOTS do
		local weaponId = player:GetAttribute(`Loadout{slot}`) :: string?
		local adef = abilityOf(weaponId)
		local value = 0
		if weaponId and adef then
			value = math.floor(Ability.fraction(coreFor(player, weaponId), adef) * 100 + 0.5) / 100
		end
		if player:GetAttribute(`AbilityCharge{slot}`) ~= value then
			player:SetAttribute(`AbilityCharge{slot}`, value)
		end
	end
end

local function broadcastFx(info: { [string]: any })
	for _, other in Players:GetPlayers() do
		Net.fire("ShotFx", other, info)
	end
end

local function teleport(player: Player, root: BasePart, cframe: CFrame)
	MovementGuard.grace(player, TELEPORT_GRACE)
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
end

local function setCast(character: Model, adef: Ability.AbilityDef?)
	character:SetAttribute("AbilityCast", if adef then adef.id else nil)
	character:SetAttribute(
		"AbilityCastEnd",
		if adef then workspace:GetServerTimeNow() + adef.windup else nil
	)
end

-- Le lanceur peut-il encore agir à la fin de la préparation ?
local function stillValid(player: Player, character: Model): boolean
	return player.Character == character
		and character.Parent ~= nil
		and WeaponService.canUseAbility(player)
end

local function targetAlive(model: Model): boolean
	return model.Parent ~= nil
		and CombatTargets.get(model) ~= nil
		and model:GetAttribute("Dead") ~= true
end

local function worldParams(...: Instance): RaycastParams
	local list: { Instance } = { ... }
	for model in CombatTargets.all() do
		table.insert(list, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	return params
end

-- Retour -------------------------------------------------------------------------------

local function castRewind(
	player: Player,
	adef: Ability.AbilityDef,
	core: Ability.Core,
	character: Model,
	root: BasePart
)
	task.delay(adef.windup, function()
		casting[player] = nil
		setCast(character, nil)
		local history = histories[player]
		local sample = history
			and Ability.sampleAt(
				history,
				workspace:GetServerTimeNow() - (adef.rewindSeconds or 2) - adef.windup
			)
		if not stillValid(player, character) or sample == nil then
			Ability.refund(core, adef)
			publish(player)
			return
		end
		local start = root.Position
		teleport(player, root, CFrame.new(sample.position) * root.CFrame.Rotation)
		local current = (character:GetAttribute("Health") :: number?) or 0
		local wanted = Ability.rewindHealth(current, sample.health, adef.healCap or 0)
		HealthService.heal(character, wanted - current)
		-- On repart d'un historique vierge : deux Retours d'affilée ne remontent pas plus loin.
		histories[player] = Ability.newHistory(HISTORY_DURATION)
		broadcastFx({ shooter = player, kind = "Rewind", origin = start, finish = sample.position })
	end)
end

-- Pas de l'ombre ---------------------------------------------------------------------------

-- Cible acceptable ? (le client propose, le serveur décide)
local function validShadowTarget(
	player: Player,
	character: Model,
	root: BasePart,
	adef: Ability.AbilityDef,
	target: unknown
): (Model?, BasePart?)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or target == character then
		return nil, nil
	end
	local model = target :: Model
	local targetRoot = rootOf(model)
	if targetRoot == nil or not targetAlive(model) then
		return nil, nil
	end
	-- Mêmes règles que les dégâts : jamais un joueur au Refuge, jamais soi-même.
	if not HealthService.canDamage(player, model) then
		return nil, nil
	end
	local offset = targetRoot.Position - root.Position
	if
		offset.Magnitude > (adef.range or 12) + RANGE_TOLERANCE
		or math.abs(offset.Y) > MAX_HEIGHT_GAP
	then
		return nil, nil
	end
	local head = character:FindFirstChild("Head")
	local eye = if head and head:IsA("BasePart") then head.Position else root.Position
	if workspace:Raycast(eye, targetRoot.Position - eye, worldParams(character)) then
		return nil, nil -- mur entre les deux
	end
	return model, targetRoot
end

-- Point libre derrière la cible (sinon sur ses côtés), à la hauteur du sol. nil si aucun.
local function findBehind(
	targetRoot: BasePart,
	distance: number,
	casterRoot: BasePart,
	params: RaycastParams
): Vector3?
	-- Hauteur de la racine du lanceur au-dessus du sol (pour le poser à la bonne hauteur).
	local below = workspace:Raycast(casterRoot.Position, Vector3.new(0, -10, 0), params)
	local hipHeight = if below then casterRoot.Position.Y - below.Position.Y else 3
	local diagonal = distance * 0.72
	local candidates = {
		Vector3.new(0, 0, distance), -- dans le dos (+Z = derrière, le personnage regarde -Z)
		Vector3.new(diagonal, 0, diagonal),
		Vector3.new(-diagonal, 0, diagonal),
		Vector3.new(distance, 0, 0),
		Vector3.new(-distance, 0, 0),
	}
	local origin = targetRoot.Position
	for _, local_ in candidates do
		local point = (targetRoot.CFrame * CFrame.new(local_)).Position
		point = Vector3.new(point.X, origin.Y, point.Z)
		-- Passage libre depuis la cible (pas de mur) avec une marge pour le corps.
		local toPoint = point - origin
		if not workspace:Raycast(origin, toPoint + toPoint.Unit * 1, params) then
			local ground =
				workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
			if ground then
				return Vector3.new(point.X, ground.Position.Y + hipHeight, point.Z)
			end
		end
	end
	return nil
end

local function castShadowStep(
	player: Player,
	adef: Ability.AbilityDef,
	core: Ability.Core,
	character: Model,
	root: BasePart,
	target: Model
)
	local castEnd = workspace:GetServerTimeNow() + adef.windup
	target:SetAttribute("ShadowMarkedAt", castEnd)
	local victim = Players:GetPlayerFromCharacter(target)
	if victim then
		-- Contrepartie (D-038) : la victime est prévenue et peut se retourner pour parer.
		Net.fire(
			"CombatEvent",
			victim,
			{ type = "ShadowWarning", from = root.Position, duration = adef.windup }
		)
	end
	task.delay(adef.windup, function()
		casting[player] = nil
		setCast(character, nil)
		if target:GetAttribute("ShadowMarkedAt") == castEnd then
			target:SetAttribute("ShadowMarkedAt", nil)
		end
		local targetRoot = rootOf(target)
		if not stillValid(player, character) or targetRoot == nil or not targetAlive(target) then
			Ability.refund(core, adef)
			publish(player)
			return
		end
		local destination = findBehind(targetRoot, adef.behind or 2.6, root, worldParams(character))
		if destination == nil then
			Ability.refund(core, adef)
			publish(player)
			return
		end
		local start = root.Position
		local facing = Vector3.new(targetRoot.Position.X, destination.Y, targetRoot.Position.Z)
		teleport(player, root, CFrame.lookAt(destination, facing))
		WeaponService.grantNextHitBonus(
			player,
			adef.backstabMultiplier or 1.5,
			adef.backstabWindow or 1.5
		)
		broadcastFx({ shooter = player, kind = "ShadowStep", origin = start, finish = destination })
	end)
end

-- Ralentissement (bulle de stase, onde de fracture, Garde du Temps) : attributs lus par le
-- client (MovementController) et par les Échoués (EnemyService).
local function slow(model: Model, factor: number, duration: number)
	local now = workspace:GetServerTimeNow()
	local untilTime = math.max((model:GetAttribute("SlowUntil") :: number?) or 0, now + duration)
	local current = (model:GetAttribute("SlowFactor") :: number?) or 1
	if ((model:GetAttribute("SlowUntil") :: number?) or 0) < now then
		current = 1
	end
	model:SetAttribute("SlowFactor", math.min(current, factor))
	model:SetAttribute("SlowUntil", untilTime)
end

-- Bulles de stase actives (arbalète).
type Bubble = {
	position: Vector3,
	radius: number,
	expires: number,
	adef: Ability.AbilityDef,
	part: BasePart,
}
local bubbles: { Bubble } = {}
local bubbleFolder: Folder? = nil

local function createBubble(position: Vector3, adef: Ability.AbilityDef)
	if bubbleFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "StasisBubbles"
		folder.Parent = workspace
		bubbleFolder = folder
	end
	local radius = adef.radius or 4
	local part = Instance.new("Part")
	part.Name = "StasisBubble"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(80, 230, 255)
	part.Transparency = 0.25
	part:SetAttribute("Expires", workspace:GetServerTimeNow() + (adef.duration or 3))
	part.Parent = bubbleFolder
	table.insert(bubbles, {
		position = position,
		radius = radius,
		expires = os.clock() + (adef.duration or 3),
		adef = adef,
		part = part,
	})
end

-- Distance d'un point à un segment (tir qui traverse une bulle).
local function segmentDistance(a: Vector3, b: Vector3, point: Vector3): number
	local ab = b - a
	local length = ab.Magnitude
	if length < 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / (length * length), 0, 1)
	return (a + ab * t - point).Magnitude
end

-- Onde de fracture (épée longue) ----------------------------------------------------------

local function castFractureWave(
	player: Player,
	def: any,
	adef: Ability.AbilityDef,
	core: Ability.Core,
	character: Model,
	root: BasePart
)
	task.delay(adef.windup, function()
		casting[player] = nil
		setCast(character, nil)
		if not stillValid(player, character) then
			Ability.refund(core, adef)
			publish(player)
			return
		end
		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z).Unit
		local origin = root.Position
		local length = adef.length or 8
		local params = worldParams(character)
		for model, target in CombatTargets.all() do
			if model ~= character and HealthService.canDamage(player, model) then
				local offset = target.root.Position - origin
				local along = offset:Dot(forward)
				local side = (Vector3.new(offset.X, 0, offset.Z) - forward * along).Magnitude
				if
					along >= 0
					and along <= length + 1
					and side <= (adef.halfWidth or 1.75) + 1
					and math.abs(offset.Y) <= 4
					and not workspace:Raycast(origin, offset, params)
				then
					-- Parable : un joueur qui pare de face annule l'onde (sans étourdir le lanceur).
					if not WeaponService.tryParryFrom(model, origin) then
						if
							WeaponService.dealDamage(player, def, model, adef.damage or 35, origin)
						then
							if target.kind == "Player" then
								slow(model, adef.slow or 0.4, adef.slowDuration or 1.2)
							else
								model:SetAttribute(
									"StunnedUntil",
									workspace:GetServerTimeNow() + (adef.slowDuration or 1.2)
								)
							end
						end
					end
				end
			end
		end
		broadcastFx({
			shooter = player,
			kind = "FractureWave",
			origin = origin,
			finish = origin + forward * length,
		})
	end)
end

-- Rayon du Zénith (Fusil du Zénith) --------------------------------------------------------

local strikeFolder: Folder? = nil

local function castZenith(
	player: Player,
	def: any,
	adef: Ability.AbilityDef,
	character: Model,
	impact: Vector3
)
	if strikeFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "ZenithStrikes"
		folder.Parent = workspace
		strikeFolder = folder
	end
	-- Marqueur répliqué : les clients dessinent les cercles runiques (annonce visible par tous).
	local marker = Instance.new("Part")
	marker.Name = "ZenithStrike"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	marker.CFrame = CFrame.new(impact)
	marker:SetAttribute("ImpactAt", workspace:GetServerTimeNow() + adef.windup)
	marker:SetAttribute("Radius", adef.radius or 7)
	marker.Parent = strikeFolder
	task.delay(adef.windup, function()
		casting[player] = nil
		setCast(character, nil)
		local radius = adef.radius or 7
		local damage = adef.damage or 70
		for model, target in CombatTargets.all() do
			local distance = (target.root.Position - impact).Magnitude
			if distance <= radius + 1 and HealthService.canDamage(player, model) then
				local falloff = 1 - 0.5 * math.clamp(distance / radius, 0, 1)
				WeaponService.dealDamage(
					player,
					def,
					model,
					damage * falloff,
					impact + Vector3.new(0, 20, 0)
				)
			end
		end
		broadcastFx({ shooter = player, kind = "ZenithImpact", origin = impact, finish = impact })
		task.delay(0.6, function()
			marker:Destroy()
		end)
	end)
end

-- Garde du Temps (épée longue) --------------------------------------------------------------

local guards: { [Player]: { core: Ability.Core, adef: Ability.AbilityDef, character: Model } } = {}

local function stopGuard(player: Player)
	local guard = guards[player]
	if guard then
		guards[player] = nil
		guard.character:SetAttribute("TimeGuard", nil)
		publish(player)
	end
end

-- Requête du client ------------------------------------------------------------------------

-- UseAbility(capacité, ...) : la capacité doit être celle de l'arme en main (ability/ability2).
local function onUseAbility(player: Player, kind: unknown, a: unknown, b: unknown, c: unknown)
	if typeof(kind) ~= "string" then
		return
	end
	local def = WeaponService.getEquipped(player)
	local character = player.Character
	local root = rootOf(character)
	if def == nil or character == nil or root == nil then
		return
	end
	if kind ~= def.ability and kind ~= def.ability2 then
		return
	end
	local adef: Ability.AbilityDef? = (Ability.DEFS :: any)[kind]
	if adef == nil then
		return
	end
	local core = coreFor(player, def.id)

	-- Garde du Temps : (true) pour lever la garde, (false) pour la baisser.
	if adef.id == "TimeGuard" then
		if a == false then
			stopGuard(player)
			return
		end
		if guards[player] or casting[player] or not WeaponService.canUseAbility(player) then
			return
		end
		if not Ability.isReady(core, adef, os.clock()) then
			publish(player)
			return
		end
		core.lastUse = os.clock()
		guards[player] = { core = core, adef = adef, character = character }
		character:SetAttribute("TimeGuard", true)
		return
	end

	if casting[player] or guards[player] then
		return
	end
	if not WeaponService.canUseAbility(player) then
		return
	end
	local now = os.clock()
	if not Ability.isReady(core, adef, now) then
		publish(player) -- resynchronise un client qui s'est trompé
		return
	end

	-- Tirs spéciaux (fusil, arbalète) : un tir réel validé comme les autres.
	if adef.id == "Ricochet" or adef.id == "Stasis" then
		Ability.consume(core, adef, now)
		-- Le carreau de stase est tiré par le noyau : pas besoin d'un carreau chargé ; portée
		-- limitée pour que la bulle reste visible.
		local options = if adef.id == "Stasis" then { useAmmo = false, range = adef.range } else nil
		local impact, reason = WeaponService.fireSpecial(player, adef.id, a, b, c, options)
		if impact == nil then
			Ability.refund(core, adef)
			Net.fire("CombatEvent", player, { type = "AbilityRefused", reason = reason })
		elseif adef.id == "Stasis" then
			-- Rien touché à portée : la bulle tombe au sol à cet endroit.
			local ground = workspace:Raycast(
				impact + Vector3.new(0, 1, 0),
				Vector3.new(0, -200, 0),
				worldParams(character)
			)
			createBubble(if ground then ground.Position + Vector3.new(0, 1, 0) else impact, adef)
		end
		publish(player)
		return
	end
	if adef.id == "ZenithBeam" then
		-- Point visé (le client propose) : à portée, visible, posé au sol.
		if not Guard.isFiniteVector3(a) then
			return
		end
		local point = a :: Vector3
		if (point - root.Position).Magnitude > (adef.range or 160) + 5 then
			Net.fire("CombatEvent", player, { type = "AbilityRefused", reason = "NoTarget" })
			return
		end
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position
		local params = worldParams(character)
		local blocked = workspace:Raycast(eye, point - eye, params)
		if blocked and (blocked.Position - point).Magnitude > 3 then
			Net.fire("CombatEvent", player, { type = "AbilityRefused", reason = "NoTarget" })
			return
		end
		local ground =
			workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
		local impact = if ground then ground.Position else point
		Ability.consume(core, adef, now)
		publish(player)
		casting[player] = true
		setCast(character, adef)
		castZenith(player, def, adef, character, impact)
		return
	end
	if adef.id == "Volley" then
		Ability.consume(core, adef, now)
		local shots = adef.shots or 3
		local interval = adef.interval or 0.2
		WeaponService.grantVolley(player, shots, shots * interval + 0.6)
		Net.fire("CombatEvent", player, {
			type = "Volley",
			shots = shots,
			interval = interval,
			extraSpread = adef.extraSpread or 2.5,
		})
		publish(player)
		return
	end

	local shadowTarget: Model? = nil
	if adef.id == "ShadowStep" then
		shadowTarget = validShadowTarget(player, character, root, adef, a)
		if shadowTarget == nil then
			Net.fire("CombatEvent", player, { type = "AbilityRefused", reason = "NoTarget" })
			return
		end
	end
	Ability.consume(core, adef, now)
	publish(player)
	casting[player] = true
	setCast(character, adef)
	if adef.id == "Rewind" then
		castRewind(player, adef, core, character, root)
	elseif adef.id == "FractureWave" then
		castFractureWave(player, def, adef, core, character, root)
	elseif shadowTarget then
		castShadowStep(player, adef, core, character, root, shadowTarget)
	else
		casting[player] = nil
		setCast(character, nil)
	end
end

-- API --------------------------------------------------------------------------------------

-- Remplit les noyaux des deux armes (outils de test Studio uniquement, voir DevTools).
function AbilityService.fill(player: Player)
	for slot = 1, SLOTS do
		local weaponId = player:GetAttribute(`Loadout{slot}`) :: string?
		local adef = abilityOf(weaponId)
		if weaponId and adef then
			Ability.addDamage(coreFor(player, weaponId), adef.charge, adef)
		end
	end
	publish(player)
end

function AbilityService.init()
	Net.on("UseAbility", onUseAbility)

	-- Modificateur de dégâts des tirs : Souffle (fusil) et bulles de stase traversées.
	WeaponService.setDamageModifier(function(player, def, origin, point, headshot)
		local multiplier = 1
		-- Concentration (Fusil du Zénith) : immobile depuis 0,8 s → tir dans la tête renforcé.
		if def.passive == "ScopeFocus" and headshot then
			local since = stillSince[player]
			if since and os.clock() - since >= Ability.SCOPE_FOCUS_TIME then
				multiplier *= Ability.SCOPE_FOCUS_HEADSHOT
				Net.fire("CombatEvent", player, { type = "Passive", passive = "ScopeFocus" })
			end
		end
		if def.passive == "Steady" then
			local since = stillSince[player]
			if since and os.clock() - since >= Ability.STEADY_TIME then
				multiplier *= Ability.STEADY_MULTIPLIER
				stillSince[player] = os.clock() -- consommé : il faut de nouveau rester immobile
				Net.fire("CombatEvent", player, { type = "Passive", passive = "Steady" })
			end
		end
		for _, bubble in bubbles do
			if segmentDistance(origin, point, bubble.position) <= bubble.radius then
				multiplier *= bubble.adef.shotDamping or 0.5
				break
			end
		end
		return multiplier
	end)

	-- Garde du Temps : étincelles quand un coup est arrêté.
	HealthService.Blocked:Connect(function(model: Model)
		local root = rootOf(model)
		if root then
			broadcastFx({
				shooter = model,
				kind = "GuardBlock",
				origin = root.Position + root.CFrame.LookVector * 1.4 + Vector3.new(0, 0.8, 0),
				finish = root.Position,
			})
		end
	end)

	-- Les dégâts infligés remplissent le noyau de l'arme utilisée.
	HealthService.Damaged:Connect(function(model: Model, result: any, info: any)
		local attacker: Player? = info.attacker
		if attacker == nil or model == attacker.Character or typeof(info.weaponId) ~= "string" then
			return
		end
		local adef = abilityOf(info.weaponId)
		if adef and Ability.addDamage(coreFor(attacker, info.weaponId), result.applied, adef) then
			Net.fire("CombatEvent", attacker, { type = "AbilityReady", weapon = info.weaponId })
		end
		publish(attacker)
	end)

	local function watch(player: Player)
		-- Nouvelle vie : noyaux vides (on perd tout à la mort, D-002).
		player.CharacterAdded:Connect(function()
			cores[player] = {}
			casting[player] = nil
			guards[player] = nil
			stillSince[player] = nil
			histories[player] = Ability.newHistory(HISTORY_DURATION)
			publish(player)
		end)
		for slot = 1, SLOTS do
			player:GetAttributeChangedSignal(`Loadout{slot}`):Connect(function()
				publish(player)
			end)
		end
		histories[player] = Ability.newHistory(HISTORY_DURATION)
		publish(player)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		cores[player] = nil
		histories[player] = nil
		casting[player] = nil
		guards[player] = nil
		stillSince[player] = nil
		lastPositions[player] = nil
	end)
end

function AbilityService.start()
	-- Historique position + santé (pour le Retour), 10 fois par seconde.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < SAMPLE_INTERVAL then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()

		-- Garde du Temps : vide le noyau, ralentit, s'arrête si vide ou si l'on ne peut plus agir.
		for player, guard in guards do
			local alive = player.Character == guard.character
				and WeaponService.canUseAbility(player)
			if not alive or not Ability.drain(guard.core, guard.adef, elapsed) then
				stopGuard(player)
			else
				slow(guard.character, guard.adef.slow or 0.5, 0.3)
				publish(player)
			end
		end

		-- Bulles de stase : ralentissent tout ce qui est dedans, puis disparaissent.
		for index = #bubbles, 1, -1 do
			local bubble = bubbles[index]
			if clock >= bubble.expires then
				bubble.part:Destroy()
				table.remove(bubbles, index)
			else
				for model, target in CombatTargets.all() do
					if (target.root.Position - bubble.position).Magnitude <= bubble.radius + 1 then
						slow(model, bubble.adef.slow or 0.5, 0.3)
					end
				end
			end
		end

		-- Souffle : immobilité (moins de 0,3 stud depuis le dernier échantillon).
		for _, player in Players:GetPlayers() do
			local root = rootOf(player.Character)
			if root then
				local last = lastPositions[player]
				local moved = last == nil or (root.Position - last).Magnitude > 0.3
				if moved or stillSince[player] == nil then
					stillSince[player] = clock
				end
				lastPositions[player] = root.Position
			end
		end

		for player, history in histories do
			local character = player.Character
			local root = rootOf(character)
			if root and character and character:GetAttribute("Downed") ~= true then
				Ability.record(history, now, {
					position = root.Position,
					health = (character:GetAttribute("Health") :: number?) or 0,
				})
			end
		end
	end)
end

return AbilityService
