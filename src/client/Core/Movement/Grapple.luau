--!strict
-- Grappin : on vise une surface à 60 studs maximum, la corde nous tire vers elle.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Grapple
--
-- Le mouvement est simulé localement (réactivité immédiate). Le serveur reçoit la cible,
-- la vérifie (portée, recharge, ligne de vue) et autorise alors la vitesse correspondante ;
-- un grappin refusé est rattrapé par la garde de mouvement du serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)
local Rope = require(script.Parent.Rope)

local LINE_OF_SIGHT_TOLERANCE = 2

local Grapple = {}

-- Point visé : le curseur sur PC, le centre de l'écran sur mobile et manette.
-- Renvoie la position d'accroche si elle est valide (portée et ligne de vue).
function Grapple.aim(ctx: Context.Context, useScreenCenter: boolean): Vector3?
	local cfg = MovementConfig
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local screenPoint: Vector2
	if useScreenCenter then
		screenPoint = camera.ViewportSize / 2
	else
		screenPoint = UserInputService:GetMouseLocation()
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local cameraDistance = (camera.CFrame.Position - ctx.root.Position).Magnitude
	local hit = workspace:Raycast(
		ray.Origin,
		ray.Direction * (cfg.GRAPPLE_RANGE + cameraDistance),
		ctx.rayParams
	)
	if hit == nil then
		return nil
	end

	local offset = hit.Position - ctx.root.Position
	if offset.Magnitude > cfg.GRAPPLE_RANGE then
		return nil
	end

	-- Ligne de vue depuis le personnage (pas seulement depuis la caméra).
	local sight = workspace:Raycast(ctx.root.Position, offset * 1.02, ctx.rayParams)
	if sight == nil or (sight.Position - hit.Position).Magnitude > LINE_OF_SIGHT_TOLERANCE then
		return nil
	end
	return hit.Position
end

function Grapple.start(ctx: Context.Context, target: Vector3): Context.Action
	local cfg = MovementConfig
	local root = ctx.root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "GrappleVelocity"
	velocity.Attachment0 = ctx.attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	-- Doit dominer le Humanoid et la gravité (même mesure que la glissade).
	velocity.MaxForce = root.AssemblyMass * 3000
	velocity.VectorVelocity = (target - root.Position).Unit * cfg.GRAPPLE_SPEED
	velocity.Parent = root

	local rope = Rope.attach(ctx.attachment, target)
	ctx.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local elapsed = 0
	local stopped = false

	local function stop(boost: boolean?)
		if stopped then
			return
		end
		stopped = true
		velocity:Destroy()
		rope.destroy()
		if boost then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity =
				Vector3.new(v.X, math.max(v.Y, 0) + cfg.GRAPPLE_RELEASE_BOOST, v.Z)
		end
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		local offset = target - root.Position
		if offset.Magnitude <= cfg.GRAPPLE_STOP_DISTANCE or elapsed >= cfg.GRAPPLE_MAX_TIME then
			stop(false)
			return false
		end
		velocity.VectorVelocity = offset.Unit * cfg.GRAPPLE_SPEED
		return true
	end

	return { update = update, stop = stop }
end

return table.freeze(Grapple)
