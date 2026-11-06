--!strict
-- Affiche les cordes de grappin des AUTRES joueurs (la sienne est gérée par Movement/Grapple).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > GrappleVisuals

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Movement"):WaitForChild("MovementConfig")
) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local Rope = require(Client.Movement.Rope)

local SAFETY_LIFETIME = MovementConfig.GRAPPLE_MAX_TIME + 1

local GrappleVisuals = {}

local ropes: { [Player]: Rope.Rope } = {}

local function clear(player: Player)
	local rope = ropes[player]
	if rope then
		rope.destroy()
		ropes[player] = nil
	end
end

local function onGrappleState(player: any, target: any)
	if
		typeof(player) ~= "Instance"
		or not player:IsA("Player")
		or player == Players.LocalPlayer
	then
		return
	end
	clear(player)
	if typeof(target) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local attachment = root and root:FindFirstChild("RootAttachment")
	if attachment == nil or not attachment:IsA("Attachment") then
		return
	end
	local rope = Rope.attach(attachment, target)
	ropes[player] = rope
	-- Sécurité : la corde disparaît même si le message de fin se perd.
	task.delay(SAFETY_LIFETIME, function()
		if ropes[player] == rope then
			clear(player)
		end
	end)
end

function GrappleVisuals.start()
	Net.on("GrappleState", onGrappleState)
	Players.PlayerRemoving:Connect(clear)
end

return GrappleVisuals
