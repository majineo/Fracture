--!strict
-- Signaux visuels des Échoués (GDD 07 §1 : toute attaque est annoncée avant de partir).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > EnemyVisuals
--
-- Ne décide rien : lit les attributs publiés par le serveur (EnemyService) et affiche.
--   AttackAt  → épée levée, lame qui rougeoie de plus en plus, puis traînée du coup
--   AimAt     → arbalète épaulée, trait rouge vers le joueur visé, qui s'intensifie
--   StunnedUntil → posture déséquilibrée (coup paré)
--   StutterAt → « saut » temporel : silhouette cyan une fraction de seconde
--   Dead      → bris en éclats cyan

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local CombatSounds = require(Client.Combat.CombatSounds)
local WeaponFx = require(Client.Combat.WeaponFx)
local JointRig = require(Client.Animation.JointRig)
local PoseAnimator = require(Client.Animation.PoseAnimator)
local Poses = require(Client.Animation.Poses)
local WeaponHold = require(Client.Animation.WeaponHold)
local EnemyDefs = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Combat")
		:WaitForChild("EnemyDefs")
) :: any

local WARN_COLOR = Color3.fromRGB(255, 70, 40)
local HOT_COLOR = Color3.fromRGB(255, 230, 200)
local BRISURE_CYAN = Color3.fromRGB(80, 230, 255)
local STUTTER_FLASH = 0.16
local STRIKE_HOLD = 0.25 -- durée de la pose de fin de coup
local RUN_HOLD_FROM = 10 -- au-delà (studs/s), l'arme est tenue en port d'arme
local GRIP_SMOOTHING = 12

type Visual = {
	model: Model,
	root: BasePart,
	upperTorso: BasePart?,
	animator: PoseAnimator.PoseAnimator?,
	-- Tenue de l'arme (comme les joueurs, voir Animation/WeaponHold)
	arms: WeaponHold.Arms?,
	hold: string?,
	weaponId: string?,
	grip: CFrame?,
	highlight: Highlight,
	beam: Beam,
	beamFrom: Attachment,
	beamTo: Attachment,
	attackAt: number?,
	aimAt: number?,
	strikeUntil: number,
	stutterUntil: number,
	lastStutter: number?,
	dead: boolean,
}

local EnemyVisuals = {}

local visuals: { [Model]: Visual } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function heldPart(model: Model, name: string): BasePart?
	local held = model:FindFirstChild("HeldWeapon")
	local found = held and held:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function muzzleOf(model: Model): Attachment?
	local held = model:FindFirstChild("HeldWeapon")
	local found = held and held:FindFirstChild("Muzzle", true)
	return if found and found:IsA("Attachment") then found else nil
end

local function attach(model: Model)
	if visuals[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if root == nil or not root:IsA("BasePart") or model.Parent == nil then
		return
	end

	local animator: PoseAnimator.PoseAnimator? = nil
	local arms: WeaponHold.Arms? = nil
	local rig = JointRig.find(model)
	if rig then
		local a = PoseAnimator.new(rig)
		a.addLayer("Hold", {}, false, 14)
		a.addLayer("Windup", Poses.EnemyWindup, false, 12)
		a.addLayer("Strike", Poses.EnemyStrike, false, 30)
		a.addLayer("Stunned", Poses.EnemyStunned, false, 16)
		animator = a
		arms = WeaponHold.measureArms(rig)
	end
	local def = EnemyDefs[model:GetAttribute("EnemyKind")]
	local upperTorso = model:FindFirstChild("UpperTorso")

	-- Contour : rouge pendant l'annonce d'une attaque, cyan pendant un « saut » temporel.
	local highlight = Instance.new("Highlight")
	highlight.Enabled = false
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	-- Trait de visée de l'arbalétrier.
	local beamFrom = Instance.new("Attachment")
	beamFrom.Name = "AimFrom"
	beamFrom.Parent = workspace.Terrain
	local beamTo = Instance.new("Attachment")
	beamTo.Name = "AimTo"
	beamTo.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamFrom
	beam.Attachment1 = beamTo
	beam.Color = ColorSequence.new(WARN_COLOR)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = 0.06
	beam.Width1 = 0.06
	beam.Enabled = false
	beam.Parent = workspace.Terrain

	local visual: Visual = {
		model = model,
		root = root,
		upperTorso = if upperTorso and upperTorso:IsA("BasePart") then upperTorso else nil,
		animator = animator,
		arms = arms,
		hold = if def then (if def.behavior == "Ranged" then "LongGun" else "Blade") else nil,
		weaponId = if def then def.weaponModel else nil,
		grip = nil,
		highlight = highlight,
		beam = beam,
		beamFrom = beamFrom,
		beamTo = beamTo,
		attackAt = nil,
		aimAt = nil,
		strikeUntil = 0,
		stutterUntil = 0,
		lastStutter = model:GetAttribute("StutterAt") :: number?,
		dead = false,
	}
	visuals[model] = visual

	model.Destroying:Connect(function()
		EnemyVisuals.detach(model)
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			EnemyVisuals.detach(model)
		end
	end)
end

function EnemyVisuals.detach(model: Model)
	local visual = visuals[model]
	if visual == nil then
		return
	end
	visuals[model] = nil
	if visual.animator then
		visual.animator.destroy()
	end
	visual.beam:Destroy()
	visual.beamFrom:Destroy()
	visual.beamTo:Destroy()
	visual.highlight:Destroy()
end

local function targetPoint(userId: number?): Vector3?
	if userId == nil then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 0.6, 0) else nil
end

-- Arme tenue à deux mains (arbalète) ou en garde (épée), épaulée vers la cible en visée.
local function updateHold(
	visual: Visual,
	animator: PoseAnimator.PoseAnimator,
	aimTarget: Vector3?,
	dt: number
): boolean
	local arms, hold, weaponId, torso = visual.arms, visual.hold, visual.weaponId, visual.upperTorso
	if arms == nil or hold == nil or weaponId == nil or torso == nil then
		return false
	end
	local velocity = visual.root.AssemblyLinearVelocity
	local running = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > RUN_HOLD_FROM
	local state: WeaponHold.State = if aimTarget then "Aim" elseif running then "Sprint" else "Ready"
	local direction = if aimTarget
		then torso.CFrame:VectorToObjectSpace(aimTarget - torso.Position)
		else nil
	local wanted = WeaponHold.targetGrip(arms, hold, weaponId, state, direction)
	if wanted == nil then
		return false
	end
	local grip = visual.grip
	grip = if grip then grip:Lerp(wanted, 1 - math.exp(-GRIP_SMOOTHING * dt)) else wanted
	visual.grip = grip
	animator.setPose("Hold", (WeaponHold.solve(arms, hold, weaponId, grip :: CFrame)))
	return true
end

local function update(visual: Visual, dt: number)
	local model = visual.model
	local t = now()
	local clock = os.clock()

	-- Mort : bris, puis plus rien.
	if model:GetAttribute("Dead") == true then
		if not visual.dead then
			visual.dead = true
			WeaponFx.shatter(visual.root.Position)
			CombatSounds.playAt("EnemyShatter", visual.root.Position)
			visual.beam.Enabled = false
			visual.highlight.Enabled = false
			if visual.animator then
				visual.animator.destroy()
				visual.animator = nil
			end
		end
		return
	end

	-- Préparation d'un coup de mêlée.
	local attackAt = model:GetAttribute("AttackAt") :: number?
	if attackAt and visual.attackAt ~= attackAt then
		CombatSounds.playAt("EnemyWindup", visual.root.Position, 0.85)
	elseif attackAt == nil and visual.attackAt ~= nil and t >= visual.attackAt - 0.15 then
		-- Le coup est parti (sinon : préparation annulée par une parade / un étourdissement).
		visual.strikeUntil = clock + STRIKE_HOLD
		WeaponFx.swingArc(visual.root, true, WARN_COLOR)
		CombatSounds.playAt("HeavySwing", visual.root.Position, 0.8)
	end
	visual.attackAt = attackAt

	-- Visée de l'arbalétrier.
	local aimAt = model:GetAttribute("AimAt") :: number?
	visual.aimAt = aimAt
	local aimTarget = if aimAt
		then targetPoint(model:GetAttribute("AimTargetId") :: number?)
		else nil
	local muzzle = muzzleOf(model)
	if aimAt and aimTarget then
		local from = if muzzle
			then muzzle.WorldPosition
			else visual.root.Position + Vector3.new(0, 1.5, 0)
		visual.beamFrom.WorldPosition = from
		visual.beamTo.WorldPosition = aimTarget
		-- Le trait s'épaissit et devient plus opaque à l'approche du tir ; il clignote à la fin.
		local remaining = math.max(0, aimAt - t)
		local closeness = 1 - math.clamp(remaining / 1.1, 0, 1)
		local width = 0.04 + closeness * 0.1
		local blink = remaining < 0.3 and (math.floor(clock * 20) % 2 == 0)
		visual.beam.Width0 = width
		visual.beam.Width1 = width
		visual.beam.Transparency = NumberSequence.new(if blink then 0 else 0.55 - closeness * 0.45)
		visual.beam.Enabled = true
	else
		visual.beam.Enabled = false
	end

	-- « Saut » temporel.
	local stutterAt = model:GetAttribute("StutterAt") :: number?
	if stutterAt and stutterAt ~= visual.lastStutter then
		visual.lastStutter = stutterAt
		visual.stutterUntil = clock + STUTTER_FLASH
	end

	-- Contour.
	local highlight = visual.highlight
	if attackAt then
		local remaining = math.max(0, attackAt - t)
		local heat = 1 - math.clamp(remaining / 0.6, 0, 1)
		highlight.OutlineColor = WARN_COLOR:Lerp(HOT_COLOR, heat)
		highlight.FillColor = WARN_COLOR
		highlight.FillTransparency = 1 - heat * 0.35
		highlight.Enabled = true
	elseif clock < visual.stutterUntil then
		highlight.OutlineColor = BRISURE_CYAN
		highlight.FillColor = BRISURE_CYAN
		highlight.FillTransparency = 0.6
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end

	-- Lame qui rougeoie pendant la préparation.
	local blade = heldPart(model, "Blade")
	if blade then
		local light = blade:FindFirstChild("WarnLight") :: PointLight?
		if attackAt then
			if light == nil then
				local created = Instance.new("PointLight")
				created.Name = "WarnLight"
				created.Color = WARN_COLOR
				created.Range = 8
				created.Parent = blade
				light = created
			end
			local remaining = math.max(0, attackAt - t);
			(light :: PointLight).Brightness = 1 + (1 - math.clamp(remaining / 0.6, 0, 1)) * 4
		elseif light then
			light:Destroy()
		end
	end

	-- Poses.
	local animator = visual.animator
	if animator then
		local stunned = ((model:GetAttribute("StunnedUntil") :: number?) or 0) > t
		local striking = clock < visual.strikeUntil
		animator.setWeight("Stunned", if stunned then 1 else 0)
		animator.setWeight("Windup", if attackAt and not stunned then 1 else 0)
		animator.setWeight("Strike", if striking then 1 else 0)
		-- Tenue de l'arme, sauf pendant un coup (poses dédiées) ou un étourdissement.
		local holding = not stunned
			and not attackAt
			and not striking
			and updateHold(visual, animator, if aimAt then aimTarget else nil, dt)
		if not holding then
			visual.grip = nil
		end
		animator.setWeight("Hold", if holding then 1 else 0)
		animator.step(dt)
	end
end

local function consider(child: Instance)
	if child:IsA("Model") and child:GetAttribute("EnemyKind") ~= nil then
		task.spawn(attach, child)
	end
end

function EnemyVisuals.start()
	for _, child in workspace:GetChildren() do
		consider(child)
	end
	workspace.ChildAdded:Connect(function(child)
		-- L'attribut est posé avant que le modèle soit placé dans workspace.
		consider(child)
	end)
	-- Après l'Animator (comme CharacterAnimation) : nos poses s'ajoutent aux animations.
	RunService.Stepped:Connect(function(_, dt: number)
		for _, visual in visuals do
			update(visual, dt)
		end
	end)
end

-- Pour les tests dans Studio.
function EnemyVisuals.count(): number
	local n = 0
	for _ in visuals do
		n += 1
	end
	return n
end

return EnemyVisuals
