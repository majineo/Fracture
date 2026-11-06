--!strict
-- Point d'entrée serveur de Fracture.
-- Placement Studio : ServerScriptService > Server (Script, synchronisé par Rojo).
-- Démarrage en deux phases : init() de tous les systèmes, puis start() de tous les systèmes.
-- Chaque système est un ModuleScript dans Server/Systems.

local Systems = script:FindFirstChild("Systems")

local loaded: { [string]: any } = {}
if Systems then
	for _, child in Systems:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, system in loaded do
	if typeof(system.init) == "function" then
		system.init()
	end
end

for _, system in loaded do
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end

print("[Fracture] serveur démarré")
