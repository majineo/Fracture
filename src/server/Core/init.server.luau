--!strict
-- Point d'entrée serveur UNIQUE de Fracture (le seul Script serveur du jeu).
-- Studio : ServerScriptService > Server
--
-- Charge les systèmes communs (Server > Systems) puis ceux de la place
-- (Server > Place > Systems : Refuge ou Éclat selon le fichier de projet Rojo).
-- Démarrage en deux phases : init() de TOUS les systèmes, puis start() de tous.
--   init()  : synchrone ; connexions, remotes, dépendances. Ne doit pas bloquer.
--   start() : boucles et travail long, chacun dans son propre thread.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local PlaceKind = require(Shared:WaitForChild("PlaceKind")) :: any

type System = { init: (() -> ())?, start: (() -> ())? }

local systems: { { name: string, module: System } } = {}

local function collect(folder: Instance?)
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(systems, { name = child.Name, module = require(child) :: any })
		end
	end
end

collect(script:FindFirstChild("Systems"))
local place = script:FindFirstChild("Place")
collect(place and place:FindFirstChild("Systems"))

-- Ordre stable (alphabétique) pour un démarrage reproductible.
table.sort(systems, function(a, b)
	return a.name < b.name
end)

for _, entry in systems do
	local init = entry.module.init
	if init then
		local ok, err = pcall(init)
		if not ok then
			error(`[Boot] {entry.name}.init a échoué : {err}`)
		end
	end
end

for _, entry in systems do
	local start = entry.module.start
	if start then
		task.spawn(start)
	end
end

print(`[Fracture] serveur v{Config.GAME_VERSION} démarré ({PlaceKind}, {#systems} systèmes)`)
