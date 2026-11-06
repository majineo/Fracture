--!strict
-- Point d'entrée client de Fracture.
-- Placement Studio : StarterPlayer > StarterPlayerScripts > Client (LocalScript, synchronisé par Rojo).
-- Chaque contrôleur est un ModuleScript dans Client/Controllers.

local Controllers = script:FindFirstChild("Controllers")

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[Fracture] client démarré")
