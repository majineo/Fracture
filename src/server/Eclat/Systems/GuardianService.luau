--!strict
-- Le Gardien, le Roi Sans Heure (v0.8.0, GDD 07 §3) : il s'éveille dans la cour du Donjon au début
-- de la Faille finale ; 3 phases ; couronne exposée après une charge ratée ; récompense.
-- Studio : ServerScriptService > Server > Place > Systems > GuardianService (place Éclat)
--
-- Le corps est un Échoué (EnemyService, comportement « Boss ») agrandi ×3 ; les décisions viennent
-- de Shared/Combat/GuardianBrain (testé) ; ce service les exécute. Chaque attaque est annoncée
-- (attributs lus par le client : GuardianAction, GuardianActionEnd, CrownExposedUntil).
-- Test dans Studio : workspace:SetAttribute("QA_SummonGuardian", true) le réveille tout de suite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuardianBrain = require(Shared:WaitForChild("Combat"):WaitForChild("GuardianBrain"))
local CollapseSchedule = require(Shared:WaitForChild("Eclat"):WaitForChild("CollapseSchedule"))
local ItemDefs = require(Shared:WaitForChild("Loot"):WaitForChild("ItemDefs"))
local Districts = require(Shared:WaitForChild("Eclat"):WaitForChild("Districts"))
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local AbilityService = require(Core.Systems.AbilityService)
local CombatTargets = require(Core.Systems.CombatTargets)
local EnemyService = require(Core.Systems.EnemyService)
local HealthService = require(Core.Systems.HealthService)
local EclatService = require(script.Parent.EclatService)
local LootService = require(script.Parent.LootService)

-- Trône : dans la cour, devant le Donjon (Shared/Eclat/Districts).
local THRONE_SPOT = (Districts.get("Donjon") :: Districts.District).throne :: Districts.Spot
local THRONE = Vector3.new(THRONE_SPOT.x, THRONE_SPOT.y, THRONE_SPOT.z)
-- L'arène = la tuile du Donjon (il ne quitte pas sa tuile).
local ARENA_HALF = EclatLayout.TILE / 2 - 3
local SCALE = 3
local TICK = 0.2
local SWING_DAMAGE = 35
local SWING_REACH = 15
local SWING_ARC = 140
local CHARGE_SPEED = 70
local CHARGE_DAMAGE = 45
local CHARGE_HIT_RADIUS = 7
local SHOCK_RADIUS = 20
local SHOCK_DAMAGE = 25
local HEALTH_PER_EXTRA_PLAYER = 0.5 -- +50 % de santé par joueur en plus

local GuardianService = {}

type State = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	brain: GuardianBrain.Brain,
	maxHealth: number,
	arena: Vector3, -- centre de la tuile du Donjon
	home: Vector3, -- son trône
	match: number,
	chargeDirection: Vector3?,
	chargeHit: boolean,
}

local current: State? = nil
local matchToken = 0

local function alivePlayers(): { { player: Player, root: BasePart, character: Model } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			character
			and root
			and root:IsA("BasePart")
			and character:GetAttribute("Dead") ~= true
			and character.Parent
		then
			table.insert(out, { player = player, root = root, character = character })
		end
	end
	return out
end

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Net.fire("Notice", player, text)
	end
end

local function setAction(state: State, action: string?, duration: number?)
	state.model:SetAttribute("GuardianAction", action)
	state.model:SetAttribute(
		"GuardianActionEnd",
		if duration then workspace:GetServerTimeNow() + duration else nil
	)
end

local function hurt(state: State, character: Model, amount: number)
	HealthService.applyDamage(character, amount, {
		attacker = nil,
		weaponId = nil,
		headshot = false,
		origin = state.root.Position,
	})
end

local function swing(state: State)
	local root = state.root
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	for _, p in alivePlayers() do
		local offset = p.root.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude <= SWING_REACH and math.abs(offset.Y) < 14 then
			local angle = if flat.Magnitude > 0.1
				then math.deg(math.acos(math.clamp(flat.Unit:Dot(look), -1, 1)))
				else 0
			if angle <= SWING_ARC / 2 then
				hurt(state, p.character, SWING_DAMAGE)
			end
		end
	end
	AbilityService.fx({
		shooter = state.model,
		kind = "FractureWave",
		origin = root.Position,
		finish = root.Position + look * SWING_REACH,
	})
end

local function charge(state: State, target: BasePart?)
	local root = state.root
	local direction = if target
		then Vector3.new(
			target.Position.X - root.Position.X,
			0,
			target.Position.Z - root.Position.Z
		)
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, 1)
	end
	state.chargeDirection = direction.Unit
	state.chargeHit = false
	local hitAlready: { [Model]: boolean } = {}
	local token = matchToken
	task.spawn(function()
		local started = os.clock()
		while
			os.clock() - started < GuardianBrain.CHARGE_TIME
			and token == matchToken
			and state.model.Parent
		do
			local dir = state.chargeDirection :: Vector3
			root.AssemblyLinearVelocity = Vector3.new(
				dir.X * CHARGE_SPEED,
				root.AssemblyLinearVelocity.Y,
				dir.Z * CHARGE_SPEED
			)
			for _, p in alivePlayers() do
				if
					not hitAlready[p.character]
					and (p.root.Position - root.Position).Magnitude <= CHARGE_HIT_RADIUS
				then
					hitAlready[p.character] = true
					state.chargeHit = true
					hurt(state, p.character, CHARGE_DAMAGE)
					p.root.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 30, 0)
				end
			end
			task.wait()
		end
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		if token == matchToken and state.model.Parent and not state.chargeHit then
			-- Charge ratée : étourdi, couronne exposée (point faible, tirs à la tête ×2).
			GuardianBrain.chargeMissed(state.brain, workspace:GetServerTimeNow())
			state.model:SetAttribute("CrownExposedUntil", state.brain.stunnedUntil)
			state.model:SetAttribute("StunnedUntil", state.brain.stunnedUntil)
			setAction(state, "Stunned", GuardianBrain.STUN_TIME)
		end
	end)
end

local function shockwave(state: State)
	local origin = state.root.Position
	for _, p in alivePlayers() do
		local offset = p.root.Position - origin
		if
			Vector3.new(offset.X, 0, offset.Z).Magnitude <= SHOCK_RADIUS
			and math.abs(offset.Y) < 16
		then
			hurt(state, p.character, SHOCK_DAMAGE)
			AbilityService.slow(p.character, 0.4, 2)
		end
	end
	AbilityService.fx({
		shooter = state.model,
		kind = "ZenithImpact",
		origin = origin,
		finish = origin,
	})
end

local function summon(state: State)
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2
		local position = state.root.Position
			+ Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)
		EnemyService.spawn("enemy.man_at_arms", CFrame.new(position))
	end
	announce("Le Roi appelle sa garde !")
end

local function freezeZones()
	for _, p in alivePlayers() do
		AbilityService.stasisAt(p.root.Position, 6, 3, 0.35)
	end
end

local function inArena(state: State, position: Vector3): boolean
	return math.abs(position.X - state.arena.X) <= ARENA_HALF
		and math.abs(position.Z - state.arena.Z) <= ARENA_HALF
		and position.Y > -10
end

-- Seuls les joueurs entrés dans l'arène sont visés.
local function nearestTarget(state: State): (BasePart?, number)
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, p in alivePlayers() do
		local d = (p.root.Position - state.root.Position).Magnitude
		if d < bestDistance and inArena(state, p.root.Position) then
			best, bestDistance = p.root, d
		end
	end
	return best, bestDistance
end

local function face(state: State, target: BasePart?)
	if target then
		local look = Vector3.new(target.Position.X, state.root.Position.Y, target.Position.Z)
		if (look - state.root.Position).Magnitude > 0.5 then
			state.root.CFrame = CFrame.lookAt(state.root.Position, look)
		end
	end
end

local function think(state: State)
	local health = (state.model:GetAttribute("Health") :: number?) or 0
	local target, distance = nearestTarget(state)
	local now = workspace:GetServerTimeNow()
	local phaseBefore = state.brain.phase
	local command = GuardianBrain.step(state.brain, {
		now = now,
		healthRatio = health / state.maxHealth,
		hasTarget = target ~= nil,
		distance = distance,
	})
	if state.brain.phase ~= phaseBefore then
		state.model:SetAttribute("GuardianPhase", state.brain.phase)
		announce(if state.brain.phase == 2 then "La Couronne brisée !" else "Le Temps s'arrête !")
	end
	local t = if state.brain.phase >= 3 then GuardianBrain.PHASE3_SPEED else 1
	if command == "Chase" and target then
		state.humanoid.WalkSpeed = if state.brain.phase >= 3 then 19 else 15
		state.humanoid:MoveTo(target.Position)
	elseif command == "Idle" or command == "Stunned" or command == "Busy" then
		if
			command == "Idle"
			and target == nil
			and (state.root.Position - state.home).Magnitude > 6
		then
			-- Personne dans l'arène : il retourne à son trône.
			state.humanoid.WalkSpeed = 12
			state.humanoid:MoveTo(state.home)
		elseif command ~= "Busy" then
			state.humanoid:MoveTo(state.root.Position)
		end
	else
		state.humanoid:MoveTo(state.root.Position)
		if command == "BeginSwing" then
			face(state, target)
			setAction(state, "Swing", GuardianBrain.SWING_WINDUP * t)
		elseif command == "Swing" then
			swing(state)
			setAction(state, nil)
		elseif command == "BeginCharge" then
			face(state, target)
			setAction(state, "Charge", GuardianBrain.CHARGE_WINDUP * t)
		elseif command == "Charge" then
			setAction(state, "Charging", GuardianBrain.CHARGE_TIME)
			charge(state, target)
		elseif command == "BeginShockwave" then
			setAction(state, "Shockwave", GuardianBrain.SHOCK_WINDUP * t)
		elseif command == "Shockwave" then
			shockwave(state)
			setAction(state, nil)
		elseif command == "Summon" then
			summon(state)
		elseif command == "FreezeZones" then
			freezeZones()
		end
	end
end

local function reward(position: Vector3)
	local relic = ItemDefs.RELICS[math.random(1, #ItemDefs.RELICS)]
	LootService.spawnContainer("Coffre", CFrame.new(position), {
		{ id = relic, qty = 3 },
		{ id = "mat.rift_stone", qty = 3 },
		{ id = "mat.ancient_steel", qty = 4 },
		{ id = ItemDefs.GRAINS, qty = 150 },
	}, "Trésor du Roi")
end

local function awaken()
	if current then
		return
	end
	local layout = EclatService.layout()
	if layout == nil then
		return
	end
	local donjon = nil
	for _, tile in layout.tiles do
		if tile.kind == "Donjon" then
			donjon = tile
		end
	end
	if donjon == nil or not EclatService.isStanding(donjon.x, donjon.z) then
		return
	end
	local tileFrame = EclatService.tileFrame(donjon)
	local frame = tileFrame * CFrame.new(THRONE) * CFrame.Angles(0, math.pi, 0)
	local model = EnemyService.spawn("enemy.guardian", frame * CFrame.new(0, 3, 0))
	if model == nil then
		return
	end
	-- Couronne (point faible) : provisoire tant que l'équipement Blender « Guardian » n'est pas
	-- importé dans ServerStorage > EnemyOutfits.
	local outfit = model:FindFirstChild("Outfit")
	if outfit then
		-- Armure Blender importée : couleurs et matériaux d'après le suffixe des pièces.
		local looks: { [string]: { Enum.Material | Color3 } } = {
			Laiton = { Enum.Material.Metal, Color3.fromRGB(214, 172, 74) },
			Acier = { Enum.Material.Metal, Color3.fromRGB(176, 182, 190) },
			Metal = { Enum.Material.Metal, Color3.fromRGB(46, 48, 56) },
			Indigo = { Enum.Material.Fabric, Color3.fromRGB(52, 58, 150) },
			Cristal = { Enum.Material.Neon, Color3.fromRGB(170, 95, 255) },
			Cuir = { Enum.Material.Leather, Color3.fromRGB(110, 70, 44) },
		}
		for _, part in outfit:GetDescendants() do
			local suffix = part:IsA("BasePart") and string.match(part.Name, "__(%a+)$")
			local look = suffix and looks[suffix]
			if look then
				(part :: BasePart).Material = look[1] :: Enum.Material
				(part :: BasePart).Color = look[2] :: Color3
			end
		end
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and outfit == nil then
		local crown = Instance.new("Model")
		crown.Name = "Couronne"
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			local spike = Instance.new("Part")
			spike.Name = "Couronne"
			spike.Size = Vector3.new(0.22, 0.45, 0.22)
			spike.Material = Enum.Material.Metal
			spike.Color = Color3.fromRGB(220, 180, 70)
			spike.CanCollide = false
			spike.Massless = true
			spike.CFrame = head.CFrame
				* CFrame.new(math.cos(angle) * 0.5, 0.75, math.sin(angle) * 0.5)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = spike
			weld.Parent = spike
			spike.Parent = crown
		end
		local ring = Instance.new("Part")
		ring.Name = "Couronne"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 1.15, 1.15)
		ring.Material = Enum.Material.Metal
		ring.Color = Color3.fromRGB(220, 180, 70)
		ring.CanCollide = false
		ring.Massless = true
		ring.CFrame = head.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = ring
		weld.Parent = ring
		ring.Parent = crown
		crown.Parent = model
	end
	model:ScaleTo(SCALE)
	model:PivotTo(frame * CFrame.new(0, 3 * SCALE, 0))
	-- La zone de touche a été mesurée avant l'agrandissement : on la remesure.
	CombatTargets.remeasure(model)
	-- Santé adaptée au nombre de joueurs présents.
	local players = math.max(1, #alivePlayers())
	local maxHealth = 1500 * (1 + HEALTH_PER_EXTRA_PLAYER * (players - 1))
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("Guardian", true)
	model:SetAttribute("GuardianPhase", 1)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local state: State = {
		model = model,
		humanoid = humanoid,
		root = root,
		brain = GuardianBrain.new(workspace:GetServerTimeNow() + 2),
		maxHealth = maxHealth,
		arena = tileFrame.Position,
		home = frame.Position,
		match = matchToken,
		chargeDirection = nil,
		chargeHit = false,
	}
	current = state
	announce("Le Roi Sans Heure s'éveille au pied du Donjon !")
end

function GuardianService.init()
	EclatService.Built:Connect(function()
		matchToken += 1
		current = nil
	end)
	HealthService.Killed:Connect(function(model: Model)
		local state = current
		if state and model == state.model then
			current = nil
			reward(state.root.Position)
			announce("Le Roi Sans Heure est tombé : son trésor vous attend.")
		end
	end)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("QA_SummonGuardian"):Connect(function()
			if workspace:GetAttribute("QA_SummonGuardian") == true then
				workspace:SetAttribute("QA_SummonGuardian", nil)
				awaken()
			end
		end)
	end
end

function GuardianService.start()
	while true do
		local schedule = EclatService.schedule()
		if
			current == nil
			and schedule
			and CollapseSchedule.phase(schedule, EclatService.elapsed()) == "FinalRift"
		then
			awaken()
		end
		local state = current
		if state and state.model.Parent and state.match == matchToken then
			think(state)
		end
		task.wait(TICK)
	end
end

return GuardianService
