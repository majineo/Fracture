--!strict
-- Voyages entre les places (v0.6.1) : Refuge → Éclat par le portail, Éclat → Refuge après une
-- extraction. Commun aux deux places.
-- Studio : ServerScriptService > Server > Systems > Travel
--
-- ⚠ Non testable dans Studio (TeleportService n'y fonctionne pas) ni tant que les places ne sont
-- pas publiées : Config.PLACE_IDS vaut 0. Dans ces cas, `Travel.go` renvoie false et l'appelant
-- garde son comportement de repli (message au Refuge, bilan + « Repartir » dans l'Éclat).
-- Le profil suit tout seul : le serveur quitté l'enregistre et rend son verrou, le serveur
-- d'arrivée le recharge (SessionLock réessaie le temps que le verrou se libère).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Retry = require(script.Parent.Parent.Lib.Retry) :: any

local Travel = {}

-- La destination est-elle joignable depuis ce serveur ?
function Travel.available(destination: "Refuge" | "Eclat"): boolean
	local id = Config.PLACE_IDS[destination]
	return typeof(id) == "number" and id > 0 and not RunService:IsStudio()
end

-- Téléporte le joueur ; renvoie false si c'est impossible (le joueur reste où il est).
function Travel.go(player: Player, destination: "Refuge" | "Eclat"): boolean
	if not Travel.available(destination) then
		return false
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ from = game.PlaceId })
	local ok = Retry.run(3, 1, 4, task.wait, function()
		return TeleportService:TeleportAsync(Config.PLACE_IDS[destination], { player }, options)
	end)
	if not ok then
		warn(`[Travel] téléportation de {player.UserId} vers {destination} impossible`)
	end
	return ok
end

return Travel
