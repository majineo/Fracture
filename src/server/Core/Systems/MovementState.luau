--!strict
-- Recopie le mode de déplacement annoncé par chaque client dans l'attribut "MoveMode" de son
-- personnage, pour que tous les clients affichent la bonne animation.
-- Studio : ServerScriptService > Server > Systems > MovementState
--
-- Purement visuel : ce mode ne donne aucun droit. La vitesse et les positions restent
-- contrôlées par MovementGuard, quel que soit le mode annoncé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)

local MODES = table.freeze({ Normal = true, Slide = true, Mantle = true, Grapple = true })

local MovementState = {}

function MovementState.init()
	Net.on("MovementMode", function(player: Player, mode: unknown)
		if not Guard.isKeyOf(mode, MODES) then
			return
		end
		local character = player.Character
		if character then
			character:SetAttribute("MoveMode", mode)
			character:SetAttribute("MoveModeAt", workspace:GetServerTimeNow())
		end
	end)
end

return MovementState
