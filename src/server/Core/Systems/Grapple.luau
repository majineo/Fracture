--!strict
-- Validation serveur du grappin et diffusion de la corde aux autres joueurs.
-- Studio : ServerScriptService > Server > Systems > Grapple
--
-- Le client tire localement (réactivité) et annonce sa cible. Le serveur vérifie :
--   type → recharge → portée → ligne de vue.
-- Si tout est valide, la garde de mouvement autorise la vitesse du grappin. Sinon la
-- requête est ignorée et un éventuel déplacement trop rapide est corrigé par la garde.
--
-- À FAIRE (système d'équipement) : vérifier que le joueur porte bien un grappin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local MovementGuard = require(script.Parent.MovementGuard)

local RANGE_SLACK = 8 -- latence : le serveur voit le joueur légèrement en retard
local COOLDOWN_SLACK = 0.5
local LINE_OF_SIGHT_TOLERANCE = 4
local SPEED_MARGIN = 1.1

local Grapple = {}

local lastGrapple: { [Player]: number } = {}
local activeToken: { [Player]: number } = {}
local tokenCounter = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function finish(player: Player, token: number)
	if activeToken[player] ~= token then
		return
	end
	activeToken[player] = nil
	Net.fireAll("GrappleState", player, nil)
end

local function onGrappleStart(player: Player, target: unknown)
	-- 1. Type
	if not Guard.isFiniteVector3(target) then
		return
	end
	local targetPosition = target :: Vector3
	local root = rootOf(player)
	if root == nil then
		return
	end

	-- 2. Recharge
	local now = os.clock()
	local last = lastGrapple[player]
	if last and now - last < MovementConfig.GRAPPLE_COOLDOWN - COOLDOWN_SLACK then
		return
	end

	-- 3. Portée
	local offset = targetPosition - root.Position
	if offset.Magnitude > MovementConfig.GRAPPLE_RANGE + RANGE_SLACK then
		return
	end

	-- 4. Ligne de vue : il faut une vraie surface au point visé.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local hit = workspace:Raycast(root.Position, offset * 1.05, params)
	if hit == nil or (hit.Position - targetPosition).Magnitude > LINE_OF_SIGHT_TOLERANCE then
		return
	end

	lastGrapple[player] = now
	tokenCounter += 1
	local token = tokenCounter
	activeToken[player] = token

	-- Vol du crochet + traction + marge de latence.
	local hookFlight = offset.Magnitude / MovementConfig.GRAPPLE_HOOK_SPEED
	local duration = hookFlight + MovementConfig.GRAPPLE_MAX_TIME + 0.5
	MovementGuard.allow(
		player,
		duration,
		MovementConfig.GRAPPLE_SPEED * SPEED_MARGIN,
		offset.Magnitude + 10
	)
	Net.fireAll("GrappleState", player, targetPosition)
	task.delay(duration, finish, player, token)
end

local function onGrappleEnd(player: Player)
	local token = activeToken[player]
	if token then
		finish(player, token)
	end
end

function Grapple.init()
	Net.on("GrappleStart", onGrappleStart)
	Net.on("GrappleEnd", onGrappleEnd)
	Players.PlayerRemoving:Connect(function(player)
		lastGrapple[player] = nil
		activeToken[player] = nil
	end)
end

return Grapple
