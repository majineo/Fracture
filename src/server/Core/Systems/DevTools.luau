--!strict
-- Outils de test réservés à Roblox Studio (jamais actifs dans le jeu publié).
-- Studio : ServerScriptService > Server > Systems > DevTools
--
-- Utilisation depuis la barre de commande côté client pendant un test :
--   game.ReplicatedStorage.Remotes.DevCommand:FireServer("teleport", Vector3.new(0, 5, 0))
--
-- Commandes :
--   "teleport", position : téléporte le personnage en prévenant la garde de mouvement.
--
-- Sécurité : le gestionnaire n'est branché que si RunService:IsStudio() est vrai, et le
-- vérifie encore à chaque appel. Aucune commande ne touche aux données joueur.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local MovementGuard = require(script.Parent.MovementGuard)

local TELEPORT_GRACE = 1
local MAX_COORDINATE = 10000

local DevTools = {}

local function teleport(player: Player, position: unknown)
	if not Guard.isFiniteVector3(position) then
		return
	end
	local target = position :: Vector3
	if target.Magnitude > MAX_COORDINATE then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	MovementGuard.grace(player, TELEPORT_GRACE)
	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

local COMMANDS: { [string]: (Player, ...unknown) -> () } = {
	teleport = teleport,
}

function DevTools.init()
	if not RunService:IsStudio() then
		return
	end
	Net.on("DevCommand", function(player: Player, command: unknown, ...: unknown)
		if not RunService:IsStudio() then
			return
		end
		if not Guard.isKeyOf(command, COMMANDS) then
			return
		end
		COMMANDS[command :: string](player, ...)
	end)
	print("[DevTools] commandes de test actives (Studio uniquement)")
end

return DevTools
