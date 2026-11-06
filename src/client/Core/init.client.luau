--!strict
-- Point d'entrée client UNIQUE de Fracture (le seul LocalScript du jeu).
-- Studio : StarterPlayer > StarterPlayerScripts > Client
--
-- Charge les contrôleurs communs (Client > Controllers) puis ceux de la place
-- (Client > Place > Controllers). Démarrage en deux phases : init() de tous, puis start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local PlaceKind = require(Shared:WaitForChild("PlaceKind")) :: any

type Controller = { init: (() -> ())?, start: (() -> ())? }

local controllers: { { name: string, module: Controller } } = {}

local function collect(folder: Instance?)
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(controllers, { name = child.Name, module = require(child) :: any })
		end
	end
end

collect(script:FindFirstChild("Controllers"))
local place = script:FindFirstChild("Place")
collect(place and place:FindFirstChild("Controllers"))

table.sort(controllers, function(a, b)
	return a.name < b.name
end)

for _, entry in controllers do
	local init = entry.module.init
	if init then
		local ok, err = pcall(init)
		if not ok then
			error(`[Boot] {entry.name}.init a échoué : {err}`)
		end
	end
end

for _, entry in controllers do
	local start = entry.module.start
	if start then
		task.spawn(start)
	end
end

print(
	`[Fracture] client v{Config.GAME_VERSION} démarré ({PlaceKind}, {#controllers} contrôleurs)`
)
