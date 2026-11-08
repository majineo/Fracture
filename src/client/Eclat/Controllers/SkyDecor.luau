--!strict
-- Ciel de l'Éclat (v0.11.0) : des dirigeables de siège tournent lentement autour de la forteresse,
-- loin des joueurs (décor local, aucun coût pour le serveur ni le réseau).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > SkyDecor
--
-- Modèle : ReplicatedStorage > Decor > Cite_Dirigeable (copié par le serveur depuis CityKit) ;
-- repli : ballon simple si le kit n'est pas importé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SkyDecor = {}

type Ship = {
	model: Model,
	radius: number,
	height: number,
	speed: number,
	angle: number,
	bob: number,
}

local ships: { Ship } = {}

local function fallback(): Model
	local model = Instance.new("Model")
	local balloon = Instance.new("Part")
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(12, 12, 12)
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.Color = Color3.fromRGB(226, 212, 180)
	balloon.Parent = model
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1, 3.2)
	mesh.Parent = balloon
	local gondola = Instance.new("Part")
	gondola.Size = Vector3.new(3.5, 2.5, 14)
	gondola.Material = Enum.Material.WoodPlanks
	gondola.Color = Color3.fromRGB(120, 86, 56)
	gondola.CFrame = CFrame.new(0, -8, 0)
	gondola.Parent = model
	model.PrimaryPart = balloon
	return model
end

local function template(): Model
	local decor = ReplicatedStorage:WaitForChild("Decor", 10)
	local found = decor and decor:FindFirstChild("Cite_Dirigeable")
	if found and found:IsA("Model") then
		return found
	end
	return fallback()
end

function SkyDecor.start()
	local base = template()
	local folder = Instance.new("Folder")
	folder.Name = "Ciel"
	folder.Parent = workspace
	local rng = Random.new(7)
	for i = 1, 7 do
		local model = base:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		-- Les plus lointains sont plus grands (silhouettes lisibles à travers la brume).
		local radius = rng:NextNumber(420, 620)
		model:ScaleTo(radius / 260)
		model.Parent = folder
		table.insert(ships, {
			model = model,
			radius = radius,
			height = rng:NextNumber(60, 150),
			speed = rng:NextNumber(0.006, 0.014) * (if i % 2 == 0 then 1 else -1),
			angle = i / 7 * math.pi * 2,
			bob = rng:NextNumber(0, 6),
		})
	end
	RunService.Heartbeat:Connect(function(dt: number)
		local t = os.clock()
		for _, ship in ships do
			ship.angle += ship.speed * dt
			local x, z = math.cos(ship.angle) * ship.radius, math.sin(ship.angle) * ship.radius
			local y = ship.height + math.sin(t * 0.3 + ship.bob) * 3
			-- Cap tangent à l'orbite (la proue, -Z du modèle, vers l'avant).
			local dir = Vector3.new(-math.sin(ship.angle), 0, math.cos(ship.angle))
				* math.sign(ship.speed)
			ship.model:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z) + dir))
		end
	end)
end

return SkyDecor
