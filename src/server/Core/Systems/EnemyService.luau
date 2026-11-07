--!strict
-- Ennemis : apparition, intelligence (serveur), attaques annoncées, mort, réapparition.
-- Studio : ServerScriptService > Server > Systems > EnemyService
--
-- Les Échoués (GDD 07) sont des personnages R15 contrôlés par le serveur. Ils perçoivent les
-- joueurs (distance, ligne de vue), le module pur EnemyBrain décide, ce système exécute.
--
-- Attaques annoncées (publiées en attributs, lues par les clients pour les signaux) :
--   AttackAt  : heure serveur où le coup de mêlée partira (lame levée et lumineuse avant)
--   AimAt / AimTargetId : heure du tir et joueur visé (trait rouge entre les deux)
-- Une mêlée passe par WeaponService.meleeStrike : la parade des joueurs fonctionne.
--
-- Équipement : ServerStorage > EnemyOutfits > <nom> (modélisé dans Blender ; chaque pièce
-- nommée « PartieDuCorps__Pièce__Matériau » est soudée à la partie du corps correspondante).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local EnemyBrain = require(Shared.Combat.EnemyBrain)
local EnemyDefs = require(Shared.Combat.EnemyDefs)
local Net = require(script.Parent.Parent.Lib.Net)
local WeaponModels = require(script.Parent.Parent.Lib.WeaponModels)
local CombatTargets = require(script.Parent.CombatTargets)
local HealthService = require(script.Parent.HealthService)
local WeaponService = require(script.Parent.WeaponService)

local THINK_INTERVAL = 0.2
local PATH_INTERVAL = 1.0
local CORPSE_TIME = 3.5
local SKIN = Color3.fromRGB(140, 152, 168) -- teint gris-bleu des figés
local STUTTER_MIN, STUTTER_MAX = 4, 9 -- secondes entre deux « sauts » temporels
local STUTTER_DURATION = 0.18
local PATH_AGENT = { AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true }

-- Animations R15 par défaut de Roblox.
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://913376220",
}

type Enemy = {
	model: Model,
	def: EnemyDefs.EnemyDef,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	home: Vector3,
	brain: EnemyBrain.Brain,
	target: Player?,
	tracks: { [string]: AnimationTrack },
	lastPath: number,
	waypoints: { Vector3 },
	nextStutter: number,
	onDeath: ((Enemy) -> ())?,
	alive: boolean,
}

local EnemyService = {}

local enemies: { [Model]: Enemy } = {}

-- Apparence ----------------------------------------------------------------------------

local function dressOutfit(model: Model, root: BasePart, outfitName: string)
	local folder = ServerStorage:FindFirstChild("EnemyOutfits")
	local source = folder and folder:FindFirstChild(outfitName)
	if source == nil or not source:IsA("Model") then
		-- Équipement pas encore importé : simple bandeau lumineux (le Temps figé).
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local band = Instance.new("Part")
			band.Name = "TimeBand"
			band.Size = Vector3.new(1.2, 0.18, 1.2)
			band.Material = Enum.Material.Neon
			band.Color = Color3.fromRGB(80, 230, 255)
			band.CanCollide = false
			band.Massless = true
			band.CFrame = head.CFrame * CFrame.new(0, 0.2, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = band
			w.Parent = band
			band.Parent = model
		end
		return
	end
	local outfit = source:Clone()
	-- L'équipement a été modélisé autour d'un R15 debout, racine à l'origine.
	outfit:PivotTo(root.CFrame)
	for _, part in outfit:GetDescendants() do
		if part:IsA("BasePart") then
			local bodyName = part.Name:match("^(.-)__")
			local body = bodyName and model:FindFirstChild(bodyName)
			if body and body:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = part
				w.Parent = part
			end
		end
	end
	outfit.Name = "Outfit"
	outfit.Parent = model
end

local function loadAnimations(humanoid: Humanoid): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			tracks[name] = track
		end
	end
	return tracks
end

local function playMove(enemy: Enemy, speed: number)
	local wanted = if speed < 0.5 then "idle" elseif speed < 11 then "walk" else "run"
	for name, track in enemy.tracks do
		if name == wanted then
			if not track.IsPlaying then
				track:Play(0.2)
			end
		elseif track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

-- Perception ---------------------------------------------------------------------------

local function enemyFilter(): RaycastParams
	local list: { Instance } = {}
	for model in enemies do
		table.insert(list, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = list
	return params
end

-- Joueur valide le plus proche (vivant, pas à terre) et ligne de vue vers lui.
local function perceive(enemy: Enemy, params: RaycastParams): (Player?, number, boolean)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and character:GetAttribute("Downed") ~= true
			and character:GetAttribute("Dead") ~= true
		then
			local distance = (root.Position - enemy.root.Position).Magnitude
			local range = if enemy.target == player
				then enemy.def.leashRange
				else enemy.def.aggroRange
			if distance < range and distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	if best == nil then
		return nil, 0, false
	end
	local targetRoot = (best.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	local origin = enemy.head.Position
	local hit = workspace:Raycast(origin, targetRoot.Position - origin, params)
	local sight = hit == nil or hit.Instance:IsDescendantOf(best.Character :: Model)
	-- Un ennemi qui ne voit pas encore le joueur ne le repère pas.
	if enemy.target ~= best and not sight then
		return nil, 0, false
	end
	return best, bestDistance, sight
end

-- Actions ------------------------------------------------------------------------------

local function targetRoot(enemy: Enemy): BasePart?
	local character = enemy.target and enemy.target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function face(enemy: Enemy, position: Vector3)
	local p = enemy.root.Position
	local flat = Vector3.new(position.X, p.Y, position.Z)
	if (flat - p).Magnitude > 0.1 then
		enemy.root.CFrame = enemy.root.CFrame:Lerp(CFrame.lookAt(p, flat), 0.5)
	end
end

local function moveTowards(enemy: Enemy, destination: Vector3, direct: boolean)
	if direct then
		enemy.waypoints = {}
		enemy.humanoid:MoveTo(destination)
		return
	end
	local now = os.clock()
	if now - enemy.lastPath > PATH_INTERVAL then
		-- Calcul en tâche de fond : un chemin long ne bloque pas les autres ennemis.
		enemy.lastPath = now
		local from = enemy.root.Position
		task.spawn(function()
			local path = PathfindingService:CreatePath(PATH_AGENT)
			local ok = pcall(function()
				path:ComputeAsync(from, destination)
			end)
			local points = {}
			if ok and path.Status == Enum.PathStatus.Success then
				for i, waypoint in path:GetWaypoints() do
					if i > 1 then
						table.insert(points, waypoint.Position)
					end
				end
			end
			enemy.waypoints = points
		end)
	end
	local nextPoint = enemy.waypoints[1]
	if nextPoint then
		if (nextPoint - enemy.root.Position).Magnitude < 3 then
			table.remove(enemy.waypoints, 1)
			nextPoint = enemy.waypoints[1]
		end
	end
	enemy.humanoid:MoveTo(nextPoint or destination)
end

local function stop(enemy: Enemy)
	enemy.humanoid:MoveTo(enemy.root.Position)
end

local MELEE_STRIKES: { [string]: any } = {}
local function meleeDef(def: EnemyDefs.EnemyDef): any
	local cached = MELEE_STRIKES[def.id]
	if cached == nil then
		cached = {
			id = def.id,
			damage = def.damage,
			falloffStart = 0,
			falloffEnd = 0,
			minDamageRatio = 1,
			range = def.strikeRange or def.attackRange,
			arcDegrees = def.arcDegrees or 90,
		}
		MELEE_STRIKES[def.id] = cached
	end
	return cached
end

local function strike(enemy: Enemy)
	local root = targetRoot(enemy)
	local direction = if root
		then root.Position - enemy.root.Position
		else enemy.root.CFrame.LookVector
	-- Le signal visuel du coup vient de l'attribut AttackAt (lu par les clients).
	WeaponService.meleeStrike(
		enemy.model,
		nil,
		meleeDef(enemy.def),
		direction,
		workspace:GetServerTimeNow()
	)
end

local function fire(enemy: Enemy, params: RaycastParams)
	local player = enemy.target
	local character = player and player.Character
	local root = targetRoot(enemy)
	if player == nil or character == nil or root == nil then
		return
	end
	-- On vise là où le joueur était il y a un instant : bouger au bon moment fait esquiver.
	local target = CombatTargets.get(character)
	local lag = enemy.def.aimLag or 0.3
	local aimPoint = if target
		then CombatTargets.rewind(target, workspace:GetServerTimeNow() - lag).Position
		else root.Position
	aimPoint += Vector3.new(0, 0.6, 0)
	local held = enemy.model:FindFirstChild("HeldWeapon")
	local muzzle = held and held:FindFirstChild("Muzzle", true)
	local origin = if muzzle and muzzle:IsA("Attachment")
		then muzzle.WorldPosition
		else enemy.head.Position
	local spread = math.rad(enemy.def.spreadDegrees or 0)
	local direction = (CFrame.lookAt(origin, aimPoint) * CFrame.Angles(
		(math.random() - 0.5) * spread,
		(math.random() - 0.5) * spread,
		0
	)).LookVector
	local hit = workspace:Raycast(origin, direction * (enemy.def.attackRange + 10), params)
	local finish = if hit then hit.Position else origin + direction * enemy.def.attackRange
	if hit then
		local victimModel = hit.Instance:FindFirstAncestorOfClass("Model")
		local victim = victimModel and Players:GetPlayerFromCharacter(victimModel)
		if victim and victimModel then
			local result = HealthService.applyDamage(victimModel, enemy.def.damage, {
				attacker = nil,
				weaponId = enemy.def.id,
				headshot = false,
				origin = origin,
			})
			if result then
				Net.fire(
					"CombatEvent",
					victim,
					{ type = "Damaged", amount = result.applied, from = origin }
				)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		Net.fire("ShotFx", other, {
			shooter = enemy.model,
			kind = "Shot",
			weapon = "weapon.heavy_crossbow",
			origin = origin,
			finish = finish,
		})
	end
end

-- Boucle de réflexion -------------------------------------------------------------------

-- Commandes pendant lesquelles l'ennemi reste face à sa cible.
local FACING: { [string]: boolean } =
	{ Hold = true, BeginWindup = true, Windup = true, BeginAim = true, Aim = true }

local function think(enemy: Enemy, params: RaycastParams)
	local model = enemy.model
	local now = workspace:GetServerTimeNow()
	local player, distance, sight = perceive(enemy, params)
	enemy.target = player
	local stunnedUntil = (model:GetAttribute("StunnedUntil") :: number?) or 0
	local command = EnemyBrain.step(enemy.brain, {
		now = now,
		hasTarget = player ~= nil,
		distance = distance,
		lineOfSight = sight,
		homeDistance = (enemy.root.Position - enemy.home).Magnitude,
		stunnedUntil = stunnedUntil,
	}, enemy.def)

	local root = targetRoot(enemy)
	local humanoid = enemy.humanoid
	if command == "Chase" and root then
		humanoid.WalkSpeed = enemy.def.chaseSpeed
		moveTowards(enemy, root.Position, sight)
	elseif command == "Retreat" and root then
		humanoid.WalkSpeed = enemy.def.walkSpeed
		local away = (enemy.root.Position - root.Position) * Vector3.new(1, 0, 1)
		moveTowards(enemy, enemy.root.Position + away.Unit * 10, true)
	elseif command == "Return" then
		humanoid.WalkSpeed = enemy.def.walkSpeed
		moveTowards(enemy, enemy.home, false)
	elseif command == "BeginWindup" then
		stop(enemy)
		model:SetAttribute("AttackAt", now + enemy.def.windup)
	elseif command == "Strike" then
		model:SetAttribute("AttackAt", nil)
		strike(enemy)
	elseif command == "BeginAim" and player then
		stop(enemy)
		model:SetAttribute("AimTargetId", player.UserId)
		model:SetAttribute("AimAt", now + enemy.def.windup)
	elseif command == "Fire" then
		model:SetAttribute("AimAt", nil)
		model:SetAttribute("AimTargetId", nil)
		fire(enemy, params)
	else
		stop(enemy) -- Idle, Hold, Windup, Aim, Stunned
	end
	-- Signaux d'attaque : effacés dès que la phase correspondante est finie ou annulée
	-- (étourdissement, cible cachée…).
	if enemy.brain.phase ~= "Windup" and model:GetAttribute("AttackAt") then
		model:SetAttribute("AttackAt", nil)
	end
	if enemy.brain.phase ~= "Aim" and model:GetAttribute("AimAt") then
		model:SetAttribute("AimAt", nil)
		model:SetAttribute("AimTargetId", nil)
	end
	if root and FACING[command] then
		face(enemy, root.Position)
	end
end

-- Mort ---------------------------------------------------------------------------------

local function die(enemy: Enemy)
	if not enemy.alive then
		return
	end
	enemy.alive = false
	enemies[enemy.model] = nil
	CombatTargets.unregister(enemy.model)
	for _, track in enemy.tracks do
		track:Stop()
	end
	enemy.humanoid.BreakJointsOnDeath = true
	enemy.humanoid.Health = 0 -- l'effet de bris est déclenché côté client par l'attribut Dead
	task.delay(CORPSE_TIME, function()
		enemy.model:Destroy()
	end)
	if enemy.onDeath then
		task.spawn(enemy.onDeath, enemy)
	end
end

-- API publique -------------------------------------------------------------------------

-- Fait apparaître un ennemi. `onDeath` (facultatif) est appelé à sa mort (réapparition…).
function EnemyService.spawn(id: string, cframe: CFrame, onDeath: ((any) -> ())?): Model?
	local def = EnemyDefs[id]
	if def == nil then
		warn(`[EnemyService] ennemi inconnu : {id}`)
		return nil
	end
	local ok, created = pcall(function()
		local description = Instance.new("HumanoidDescription")
		for _, field in
			{
				"HeadColor",
				"TorsoColor",
				"LeftArmColor",
				"RightArmColor",
				"LeftLegColor",
				"RightLegColor",
			}
		do
			(description :: any)[field] = SKIN
		end
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or created == nil then
		warn(`[EnemyService] création impossible : {created}`)
		return nil
	end
	local model = created :: Model
	model.Name = def.name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = def.walkSpeed
	model:PivotTo(cframe)
	dressOutfit(model, root, def.outfit)
	model:SetAttribute("EnemyKind", def.id)
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- le serveur simule l'ennemi (pas un joueur)
	WeaponModels.equip(model, def.weaponModel)
	HealthService.registerTarget(model, "Enemy", def.health, def.armor)

	local enemy: Enemy = {
		model = model,
		def = def,
		humanoid = humanoid,
		root = root,
		head = head,
		home = cframe.Position,
		brain = EnemyBrain.new(),
		target = nil,
		tracks = loadAnimations(humanoid),
		lastPath = 0,
		waypoints = {},
		nextStutter = os.clock() + math.random(STUTTER_MIN, STUTTER_MAX),
		onDeath = onDeath,
		alive = true,
	}
	enemies[model] = enemy
	humanoid.Running:Connect(function(speed: number)
		if enemy.alive then
			playMove(enemy, speed)
		end
	end)
	playMove(enemy, 0)
	return model
end

-- Retire tous les ennemis (tests), sans déclencher de réapparition.
function EnemyService.clear()
	for model, enemy in enemies do
		enemy.alive = false
		enemies[model] = nil
		CombatTargets.unregister(model)
		model:Destroy()
	end
end

function EnemyService.count(): number
	local n = 0
	for _ in enemies do
		n += 1
	end
	return n
end

function EnemyService.init()
	HealthService.Killed:Connect(function(model: Model)
		local enemy = enemies[model]
		if enemy then
			die(enemy)
		end
	end)
end

function EnemyService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		local clock = os.clock()
		-- « Sauts » temporels : l'ennemi se fige une fraction de seconde (identité des Échoués).
		for _, enemy in enemies do
			if clock >= enemy.nextStutter then
				enemy.nextStutter = clock + math.random(STUTTER_MIN, STUTTER_MAX)
				for _, track in enemy.tracks do
					if track.IsPlaying then
						track:AdjustSpeed(0)
						task.delay(STUTTER_DURATION, function()
							track:AdjustSpeed(1)
						end)
					end
				end
				enemy.model:SetAttribute("StutterAt", workspace:GetServerTimeNow())
			end
		end
		if accumulator < THINK_INTERVAL then
			return
		end
		accumulator = 0
		local params = enemyFilter()
		for _, enemy in enemies do
			if enemy.alive and enemy.model.Parent then
				think(enemy, params)
			end
		end
	end)
end

return EnemyService
