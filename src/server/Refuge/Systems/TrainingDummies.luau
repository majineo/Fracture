--!strict
-- Mannequins d'entraînement du Champ de tir du Refuge (GDD 06 §1).
-- Studio : ServerScriptService > Server > Place > Systems > TrainingDummies (place Refuge)
--
-- Trois mannequins : un proche, un lointain (chute des dégâts), un qui se déplace (tester la
-- compensation de latence). Brisés à 0, ils se réparent après quelques secondes.
-- ⚠ Apparence provisoire (avatar Roblox gris) en attendant un modèle Blender.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local HealthService = require(script.Parent.Parent.Parent.Systems.HealthService)

local DUMMY_COLOR = Color3.fromRGB(150, 140, 125)
local BROKEN_TRANSPARENCY = 0.7

type Spot = { name: string, position: Vector3, patrol: number? }

-- Champ de tir à l'ouest du point d'apparition. Les mannequins regardent vers l'est (+X).
local SPOTS: { Spot } = {
	{ name = "Mannequin_Proche", position = Vector3.new(-40, 3, -10) },
	{ name = "Mannequin_Lointain", position = Vector3.new(-95, 3, -10) },
	{ name = "Mannequin_Mobile", position = Vector3.new(-55, 3, 10), patrol = 12 },
}

local TrainingDummies = {}

local function makeDummy(spot: Spot): Model?
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = DUMMY_COLOR
		description.TorsoColor = DUMMY_COLOR
		description.LeftArmColor = DUMMY_COLOR
		description.RightArmColor = DUMMY_COLOR
		description.LeftLegColor = DUMMY_COLOR
		description.RightLegColor = DUMMY_COLOR
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or model == nil then
		warn(`[TrainingDummies] création impossible : {model}`)
		return nil
	end
	local dummy = model :: Model
	dummy.Name = spot.name
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
	end
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	dummy:PivotTo(CFrame.lookAt(spot.position, spot.position + Vector3.new(1, 0, 0)))
	dummy:SetAttribute("CombatDummy", true)
	dummy.Parent = workspace
	return dummy
end

local function setBroken(dummy: Model, broken: boolean)
	for _, d in dummy:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.LocalTransparencyModifier = 0
			d.Transparency = if broken then BROKEN_TRANSPARENCY else 0
		end
	end
end

function TrainingDummies.start()
	local movers: { { model: Model, origin: Vector3, amplitude: number } } = {}
	for _, spot in SPOTS do
		local dummy = makeDummy(spot)
		if dummy then
			HealthService.registerTarget(dummy, "Dummy", CombatConfig.DUMMY_HEALTH, 0)
			if spot.patrol then
				table.insert(
					movers,
					{ model = dummy, origin = spot.position, amplitude = spot.patrol }
				)
			end
		end
	end

	HealthService.Killed:Connect(function(model: Model)
		if model:GetAttribute("CombatDummy") then
			setBroken(model, true)
			task.delay(CombatConfig.DUMMY_RESET_DELAY, function()
				if model.Parent then
					HealthService.restore(model)
					setBroken(model, false)
				end
			end)
		end
	end)

	-- Le mannequin mobile fait des allers-retours latéraux à environ 12 studs/s.
	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		for _, mover in movers do
			local offset = math.sin(clock * 1.0) * mover.amplitude
			local position = mover.origin + Vector3.new(0, 0, offset)
			mover.model:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
		end
	end)
end

return TrainingDummies
