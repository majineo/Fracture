--!strict
-- Animations procédurales de TOUS les personnages visibles (le sien et ceux des autres) :
-- glissade, escalade, grappin, saut, chute, réception, inclinaison du sprint.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > CharacterAnimation
--
-- Les poses (Animation/Poses) sont mélangées par-dessus les animations Roblox de base, avec
-- des transitions par ressort. Le mode de déplacement vient :
--   * du MovementController pour son propre personnage ;
--   * de l'attribut "MoveMode" (recopié par le serveur) pour les autres joueurs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local JointRig = require(Client.Animation.JointRig)
local MovementEffects = require(Client.Animation.MovementEffects)
local PoseAnimator = require(Client.Animation.PoseAnimator)
local Poses = require(Client.Animation.Poses)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponDefs = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("WeaponDefs")
) :: any
local CombatController = require(script.Parent.CombatController)
local GrappleVisuals = require(script.Parent.GrappleVisuals)
local MovementController = require(script.Parent.MovementController)

local localPlayer = Players.LocalPlayer

-- Durées estimées pour les autres joueurs (dont on ne connaît pas l'avancement exact).
local REMOTE_DURATION = { Slide = 0.8, Mantle = 0.4, Grapple = 1.2 }
local MANTLE_SPLIT = 0.45 -- avancement où l'on passe de « attraper » à « se hisser »
local LAND_MIN_SPEED = 12
local SPRINT_LEAN_FROM = 15

type Tracked = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	upperTorso: BasePart?,
	rightArm: BasePart?,
	animator: PoseAnimator.PoseAnimator,
	effects: MovementEffects.Effects,
	rayParams: RaycastParams,
	rootToFeet: number,
	wasGrounded: boolean,
	peakFall: number,
	lastMode: string,
	modeStartedAt: number,
	latched: boolean,
}

local CharacterAnimation = {}

local tracked: { [Model]: Tracked } = {}

local function buildAnimator(rig: JointRig.Rig): PoseAnimator.PoseAnimator
	local animator = PoseAnimator.new(rig)
	-- Ordre = priorité : les dernières couches l'emportent.
	animator.addLayer("SprintLean", Poses.SprintLean, true, 6)
	animator.addLayer("JumpRise", Poses.JumpRise, false, 12)
	animator.addLayer("Fall", Poses.Fall, false, 6)
	animator.addLayer("Land", Poses.Land, false, 11)
	animator.addLayer("Slide", Poses.Slide, false, 18)
	animator.addLayer("MantleReach", Poses.MantleReach, false, 24)
	animator.addLayer("MantleVault", Poses.MantleVault, false, 20)
	animator.addLayer("Grapple", Poses.Grapple, false, 14)
	-- Combat : par-dessus le déplacement (on peut viser en glissant).
	animator.addLayer("AimSupport", Poses.AimSupport, false, 16)
	animator.addLayer("AimArm", { RightShoulder = CFrame.identity }, false, 22)
	animator.addLayer("BladeGuard", Poses.BladeGuard, false, 12)
	animator.addLayer("Swing", { RightShoulder = CFrame.identity }, false, 40)
	animator.addLayer("Parry", Poses.Parry, false, 30)
	animator.addLayer("Downed", Poses.Downed, false, 8)
	return animator
end

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Coup de lame : le bras balaie de droite à gauche (coup simple) ou de haut en bas (chargé).
local SWING_DURATION = { light = 0.2, heavy = 0.32 }
local function swingPose(t: number, heavy: boolean): { [string]: CFrame }
	local e = 1 - (1 - t) * (1 - t) -- départ vif, fin amortie
	if heavy then
		return {
			RightShoulder = A(170, 0, 10):Lerp(A(35, 0, -15), e),
			RightElbow = A(30, 0, 0):Lerp(A(5, 0, 0), e),
			Waist = A(10, 0, 0):Lerp(A(-18, 0, 0), e),
		}
	end
	return {
		RightShoulder = A(95, 0, 75):Lerp(A(80, 0, -55), e),
		RightElbow = A(40, 0, 0):Lerp(A(10, 0, 0), e),
		Waist = A(0, -28, 0):Lerp(A(0, 32, 0), e),
	}
end
local WIND_UP = { RightShoulder = A(120, 0, 65), RightElbow = A(70, 0, 0), Waist = A(0, -22, 0) }

local function untrack(character: Model)
	local entry = tracked[character]
	if entry then
		entry.animator.destroy()
		entry.effects.destroy()
		tracked[character] = nil
	end
end

local function track(player: Player, character: Model)
	untrack(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if
		humanoid == nil
		or root == nil
		or not humanoid:IsA("Humanoid")
		or not root:IsA("BasePart")
	then
		return
	end
	-- Les articulations peuvent arriver un peu après le personnage.
	local rig = JointRig.find(character)
	for _ = 1, 20 do
		if rig then
			break
		end
		task.wait(0.1)
		rig = JointRig.find(character)
	end
	if rig == nil or character.Parent == nil then
		return -- R6 ou avatar incomplet : animations Roblox de base uniquement
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local rootToFeet = root.Size.Y / 2 + humanoid.HipHeight
	local upperTorso = character:FindFirstChild("UpperTorso")
	local rightArm = character:FindFirstChild("RightUpperArm")

	tracked[character] = {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		upperTorso = if upperTorso and upperTorso:IsA("BasePart") then upperTorso else nil,
		rightArm = if rightArm and rightArm:IsA("BasePart") then rightArm else nil,
		animator = buildAnimator(rig),
		effects = MovementEffects.new(root, rootToFeet),
		rayParams = rayParams,
		rootToFeet = rootToFeet,
		wasGrounded = true,
		peakFall = 0,
		lastMode = "Normal",
		modeStartedAt = os.clock(),
		latched = false,
	}

	humanoid.Died:Connect(function()
		untrack(character)
	end)
end

-- Rotation d'épaule qui pointe le bras droit vers `target`.
local function aimArm(entry: Tracked, target: Vector3): CFrame?
	local torso, arm = entry.upperTorso, entry.rightArm
	if torso == nil or arm == nil then
		return nil
	end
	local shoulder = arm.Position + arm.CFrame.UpVector * (arm.Size.Y / 2)
	local direction = target - shoulder
	if direction.Magnitude < 1e-3 then
		return nil
	end
	local localDir = torso.CFrame:VectorToObjectSpace(direction.Unit)
	local rest = Vector3.new(0, -1, 0) -- bras au repos : vers le bas
	local axis = rest:Cross(localDir)
	local angle = math.acos(math.clamp(rest:Dot(localDir), -1, 1))
	if axis.Magnitude < 1e-4 then
		return if angle > 1 then CFrame.Angles(math.pi, 0, 0) else CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

local function updateEntry(entry: Tracked, dt: number)
	local isLocal = entry.player == localPlayer
	local mode: string = if isLocal
		then MovementController.getMode()
		else (entry.character:GetAttribute("MoveMode") :: string?) or "Normal"

	if mode ~= entry.lastMode then
		entry.lastMode = mode
		entry.modeStartedAt = os.clock()
		entry.latched = false
		if mode == "Grapple" then
			entry.effects.grappleFire()
		end
	end
	local progress: number
	if isLocal then
		progress = MovementController.getProgress()
	else
		local duration = REMOTE_DURATION[mode] or 1
		progress = math.clamp((os.clock() - entry.modeStartedAt) / duration, 0, 1)
	end
	-- Son d'accroche : fin du vol du crochet (exacte pour soi, estimée pour les autres).
	if mode == "Grapple" and not entry.latched then
		local hooked = if isLocal then progress > 0 else os.clock() - entry.modeStartedAt > 0.15
		if hooked then
			entry.latched = true
			entry.effects.grappleLatch()
		end
	end

	local root = entry.root
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local ground = workspace:Raycast(
		root.Position,
		Vector3.new(0, -(entry.rootToFeet + 0.6), 0),
		entry.rayParams
	)
	local grounded = ground ~= nil
	local animator = entry.animator

	-- Réception
	if grounded and not entry.wasGrounded and entry.peakFall >= LAND_MIN_SPEED then
		local strength = math.clamp(entry.peakFall / 60, 0, 1)
		animator.snapWeight("Land", 0.3 + 0.55 * strength)
		entry.effects.landingImpact(strength, ground and ground.Instance.Color)
	end
	if grounded then
		entry.peakFall = 0
	else
		entry.peakFall = math.max(entry.peakFall, -velocity.Y)
	end
	entry.wasGrounded = grounded

	local normalAir = mode == "Normal" and not grounded
	animator.setWeight("Land", 0)
	animator.setWeight("JumpRise", if normalAir and velocity.Y > 1.5 then 1 else 0)
	animator.setWeight(
		"Fall",
		if normalAir and velocity.Y <= 1.5 then math.clamp(0.45 + -velocity.Y / 50, 0.45, 1) else 0
	)
	animator.setWeight(
		"SprintLean",
		if mode == "Normal" and grounded
			then math.clamp((horizontal - SPRINT_LEAN_FROM) / 7, 0, 1)
			else 0
	)
	animator.setWeight("Slide", if mode == "Slide" then 1 else 0)
	animator.setWeight("MantleReach", if mode == "Mantle" and progress < MANTLE_SPLIT then 1 else 0)
	animator.setWeight(
		"MantleVault",
		if mode == "Mantle" and progress >= MANTLE_SPLIT then 1 else 0
	)

	if mode == "Grapple" then
		local target = if isLocal
			then MovementController.getGrappleTarget()
			else GrappleVisuals.getTarget(entry.player)
		local pose = table.clone(Poses.Grapple)
		local arm = if target then aimArm(entry, target) else nil
		pose.RightShoulder = arm or CFrame.Angles(math.rad(150), 0, math.rad(5))
		animator.setPose("Grapple", pose)
		animator.setWeight("Grapple", 1)
	else
		animator.setWeight("Grapple", 0)
	end

	-- Combat ----------------------------------------------------------------------------
	local downed = entry.character:GetAttribute("Downed") == true
	local weapon: string? = if isLocal
		then CombatController.getEquipped()
		else entry.character:GetAttribute("EquippedWeapon") :: string?
	local usable = not downed and (mode == "Normal" or mode == "Slide")
	local def = if usable and weapon and weapon ~= "" then WeaponDefs[weapon] else nil
	local hold = def and def.hold
	local holdingGun = hold == "Pistol" or hold == "LongGun"
	local holdingBlade = hold == "Blade" or hold == "Greatsword"

	if holdingGun then
		-- Bras droit vers le point visé (soi) ou droit devant (les autres joueurs).
		local target = if isLocal
			then CombatController.getAimPoint()
			else root.Position + root.CFrame.LookVector * 60 + Vector3.new(0, 1, 0)
		local arm = if target then aimArm(entry, target) else nil
		animator.setPose("AimArm", { RightShoulder = arm or A(90, 0, 0) })
		animator.setWeight("AimArm", 1)
		local aiming = isLocal and CombatController.isAiming()
		if hold == "LongGun" then
			-- Une arme longue se tient toujours à deux mains.
			animator.setPose("AimSupport", Poses.AimLongGun)
			animator.setWeight("AimSupport", 1)
		else
			animator.setPose("AimSupport", Poses.AimSupport)
			animator.setWeight("AimSupport", if aiming or not isLocal then 1 else 0.35)
		end
	else
		animator.setWeight("AimArm", 0)
		animator.setWeight("AimSupport", 0)
	end

	-- Parade : lame levée en travers pendant la fenêtre de parade.
	local parryAt = if holdingBlade
		then CombatController.getParry(if isLocal then nil else entry.player)
		else -math.huge
	local parryWindow = (def and def.parryWindow) or 0.2
	animator.setWeight("Parry", if os.clock() - parryAt <= parryWindow + 0.1 then 1 else 0)

	local swing = if holdingBlade
		then CombatController.getSwing(if isLocal then nil else entry.player)
		else nil
	local swingActive = false
	if swing then
		local light = (def and def.swingTime) or SWING_DURATION.light
		local duration = if swing.heavy then light * 1.6 else light
		local t = (os.clock() - swing.at) / duration
		if t >= 0 and t <= 1.15 then
			swingActive = true
			animator.setPose("Swing", swingPose(math.min(t, 1), swing.heavy))
			animator.snapWeight("Swing", 1)
		end
	end
	if not swingActive and holdingBlade and isLocal and CombatController.getMeleeCharge() then
		-- Attaque chargée en préparation : bras armé en arrière.
		animator.setPose("Swing", WIND_UP)
		animator.setWeight("Swing", CombatController.getMeleeCharge() :: number)
		swingActive = true
	end
	if not swingActive then
		animator.setWeight("Swing", 0)
	end
	animator.setPose(
		"BladeGuard",
		if hold == "Greatsword" then Poses.GreatswordGuard else Poses.BladeGuard
	)
	animator.setWeight("BladeGuard", if holdingBlade then 1 else 0)
	animator.setWeight("Downed", if downed then 1 else 0)

	entry.effects.setSliding(
		mode == "Slide" and grounded and not downed,
		ground and ground.Instance.Color
	)
	animator.step(dt)
end

function CharacterAnimation.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			track(player, character)
		end)
		player.CharacterRemoving:Connect(untrack)
		if player.Character then
			task.spawn(track, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	-- Stepped : après la mise à jour de l'Animator, avant la physique et le rendu.
	local isStudio = RunService:IsStudio()
	RunService.Stepped:Connect(function(_, dt: number)
		-- Studio : l'attribut QA_NoProceduralAnim sur le joueur coupe ce système (diagnostic).
		if isStudio and localPlayer:GetAttribute("QA_NoProceduralAnim") then
			return
		end
		for character, entry in tracked do
			if character.Parent == nil then
				untrack(character)
			else
				updateEntry(entry, dt)
			end
		end
	end)
end

return CharacterAnimation
