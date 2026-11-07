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

-- Requête du client ------------------------------------------------------------------------

local function onUseAbility(player: Player, target: unknown)
	if casting[player] then
		return
	end
	local def = WeaponService.getEquipped(player)
	local adef = def and abilityOf(def.id)
	local character = player.Character
	local root = rootOf(character)
	if def == nil or adef == nil or character == nil or root == nil then
		return
	end
	if not WeaponService.canUseAbility(player) then
		return
	end
	local core = coreFor(player, def.id)
	local now = os.clock()
	if not Ability.isReady(core, adef, now) then
		publish(player) -- resynchronise un client qui s'est trompé
		return
	end
	local shadowTarget: Model? = nil
	if adef.id == "ShadowStep" then
		shadowTarget = validShadowTarget(player, character, root, adef, target)
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
	elseif shadowTarget then
		castShadowStep(player, adef, core, character, root, shadowTarget)
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
		accumulator = 0
		local now = workspace:GetServerTimeNow()
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
