--!strict
-- Armurerie du Refuge : présentoirs où l'on choisit ses armes (en attendant l'inventaire).
-- Studio : ServerScriptService > Server > Place > Systems > Armory (place Refuge)
--
-- Chaque présentoir montre l'arme (modèle Blender s'il est importé, forme provisoire sinon)
-- et propose « Équiper » (ProximityPrompt : géré par le serveur, rien à valider côté client).
-- Le choix passe par WeaponService.setWeapon, le même point d'entrée que le futur inventaire.
-- ⚠ Présentoirs provisoires (blocs) en attendant leur modèle Blender (docs/ASSETS.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponDefs = require(ReplicatedStorage.Shared.Combat.WeaponDefs)
local Systems = script.Parent.Parent.Parent.Systems
local WeaponService = require(Systems.WeaponService)
local WeaponModels = require(script.Parent.Parent.Parent.Lib.WeaponModels)

-- Rangée de présentoirs au sud du point d'apparition, face au nord (+Z).
local ORIGIN = Vector3.new(-12, 0, -32)
local SPACING = 6
local ORDER = {
	"weapon.fracture_pistol",
	"weapon.repeating_rifle",
	"weapon.zenith_rifle",
	"weapon.heavy_crossbow",
	"weapon.short_blade",
	"weapon.longsword",
}

local Armory = {}

local function pedestal(index: number, id: string): BasePart
	local def = WeaponDefs[id]
	local position = ORIGIN + Vector3.new((index - 1) * SPACING, 0, 0)
	local stand = Instance.new("Part")
	stand.Name = "Presentoir_" .. id
	stand.Anchored = true
	stand.Size = Vector3.new(3, 3, 2)
	stand.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	stand.Material = Enum.Material.WoodPlanks
	stand.Color = Color3.fromRGB(92, 64, 40)
	stand.TopSurface = Enum.SurfaceType.Smooth

	local plaque = Instance.new("Part")
	plaque.Name = "Plaque"
	plaque.Anchored = true
	plaque.CanCollide = false
	plaque.Size = Vector3.new(2.6, 0.15, 1.6)
	plaque.CFrame = stand.CFrame * CFrame.new(0, 1.55, 0)
	plaque.Material = Enum.Material.Metal
	plaque.Color = Color3.fromRGB(176, 128, 58)
	plaque.Parent = stand

	-- L'arme posée, tournant lentement au-dessus du présentoir.
	local display = WeaponModels.build(id)
	if display then
		display.Name = "Exposition"
		for _, d in display:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		display:PivotTo(
			CFrame.new(position + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, math.rad(90), 0)
		)
		display.Parent = stand
		stand:SetAttribute("SpinOrigin", position + Vector3.new(0, 4.2, 0))
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Équiper"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.25
	-- Présentoirs à 6 studs les uns des autres : portée courte pour ne pas déclencher le voisin.
	prompt.MaxActivationDistance = 5
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
	prompt.Triggered:Connect(function(player: Player)
		local slot = if def.slot == "Firearm" then 1 else 2
		WeaponService.setWeapon(player, slot, id)
	end)
	return stand
end

function Armory.start()
	local folder = Instance.new("Folder")
	folder.Name = "Armurerie"
	local spinners: { Model } = {}
	for index, id in ORDER do
		local stand = pedestal(index, id)
		stand.Parent = folder
		local display = stand:FindFirstChild("Exposition")
		if display and display:IsA("Model") then
			table.insert(spinners, display)
		end
	end
	folder.Parent = workspace

	local angle = 0
	RunService.Heartbeat:Connect(function(dt: number)
		angle += dt * 0.8
		for _, display in spinners do
			local stand = display.Parent
			local origin = stand and stand:GetAttribute("SpinOrigin")
			if typeof(origin) == "Vector3" then
				display:PivotTo(
					CFrame.new(origin)
						* CFrame.Angles(0, angle, 0)
						* CFrame.Angles(0, 0, math.rad(-20))
				)
			end
		end
	end)
end

return Armory
