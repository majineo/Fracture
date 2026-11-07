--!strict
-- Bestiaire de test du Refuge (v0.4.12) : les bêtes modélisées dans Blender, exposées pour
-- juger leur allure en jeu. Aucune IA : ce sont des statues animées (respiration, vol).
-- Studio : ServerScriptService > Server > Place > Systems > Bestiary (place Refuge)
--
-- Modèles : ServerStorage > Beasts > <nom> (importés depuis assets/blender/beasts/).
-- Une bête absente est simplement ignorée.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

type Spot = { name: string, label: string, position: Vector3, flying: boolean }

-- Au nord de l'armurerie, tournées vers le point d'apparition (+Z).
local SPOTS: { Spot } = {
	{
		name = "Loup_Cristal",
		label = "Loup de Cristal",
		position = Vector3.new(-10, 0.5, -54),
		flying = false,
	},
	{
		name = "Scarabee_Horloge",
		label = "Scarabée-Horloge",
		position = Vector3.new(4, 0.5, -54),
		flying = false,
	},
	{
		name = "Raie_Temps",
		label = "Raie du Temps",
		position = Vector3.new(18, 0.5, -54),
		flying = true,
	},
}

local Bestiary = {}

local function pedestal(spot: Spot): BasePart
	local slab = Instance.new("Part")
	slab.Name = "Socle_" .. spot.name
	slab.Anchored = true
	slab.Size = Vector3.new(9, 0.5, 9)
	slab.CFrame = CFrame.new(spot.position - Vector3.new(0, 0.25, 0))
	slab.Material = Enum.Material.Slate
	slab.Color = Color3.fromRGB(70, 72, 84)
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(220, 40)
	label.StudsOffset = Vector3.new(0, 6.5, 0)
	label.AlwaysOnTop = false
	label.MaxDistance = 80
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(80, 230, 255)
	text.TextStrokeTransparency = 0.4
	text.Text = spot.label .. " (test)"
	text.Parent = label
	label.Parent = slab
	return slab
end

function Bestiary.start()
	local folder = ServerStorage:FindFirstChild("Beasts")
	if folder == nil then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "Bestiaire"
	root.Parent = workspace
	local animated: { { model: Model, base: CFrame, flying: boolean, phase: number } } = {}
	for index, spot in SPOTS do
		local source = folder:FindFirstChild(spot.name)
		if source and source:IsA("Model") then
			pedestal(spot).Parent = root
			local model = source:Clone()
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
			-- L'avant des bêtes est -Z : on les tourne vers le point d'apparition.
			local base = CFrame.new(spot.position) * CFrame.Angles(0, math.pi, 0)
			model:PivotTo(base)
			model.Parent = root
			table.insert(
				animated,
				{ model = model, base = base, flying = spot.flying, phase = index }
			)
		end
	end
	local t = 0
	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		for _, entry in animated do
			local p = t + entry.phase
			local offset = if entry.flying
				then CFrame.new(0, 0.6 * math.sin(p * 1.4), 0) * CFrame.Angles(
					0,
					0,
					math.rad(6) * math.sin(p * 0.9)
				)
				else CFrame.new(0, 0.05 * math.sin(p * 2.2), 0)
			entry.model:PivotTo(entry.base * offset)
		end
	end)
end

return Bestiary
