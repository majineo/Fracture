--!strict
-- Roulade (v0.9.0) : courte roulade au sol dans la direction du mouvement. Sert à esquiver
-- (sortir d'une zone annoncée) et, juste avant de toucher le sol après une chute, à garder son
-- élan au lieu de s'arrêter net (roulade de réception).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Roll
--
-- Une LinearVelocity limitée aux axes horizontaux impose la vitesse : la gravité reste active,
-- la roulade suit donc les pentes et les escaliers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local FORCE_PER_MASS = 2500

local Roll = {}

-- `speed` : vitesse de départ (au moins ROLL_SPEED ; plus en réception de chute rapide).
function Roll.start(ctx: Context.Context, direction: Vector3, speed: number?): Context.Action
	local cfg = MovementConfig
	local root = ctx.root
	local dir = Vector3.new(direction.X, 0, direction.Z)
	dir = if dir.Magnitude > 1e-3
		then dir.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local startSpeed = math.max(cfg.ROLL_SPEED, speed or 0)

	-- Le personnage se tourne dans le sens de la roulade.
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "RollVelocity"
	velocity.Attachment0 = ctx.attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = root.AssemblyMass * FORCE_PER_MASS
	velocity.MaxAxesForce = Vector3.new(force, 0, force)
	velocity.VectorVelocity = dir * startSpeed
	velocity.Parent = root

	local elapsed = 0
	local stopped = false

	local function stop()
		if stopped then
			return
		end
		stopped = true
		velocity:Destroy()
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = dir * cfg.ROLL_EXIT_SPEED + Vector3.new(0, v.Y, 0)
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		local t = elapsed / cfg.ROLL_TIME
		if t >= 1 then
			stop()
			return false
		end
		-- Ralentit doucement jusqu'à la vitesse de sortie.
		local s = startSpeed + (cfg.ROLL_EXIT_SPEED - startSpeed) * t * t
		velocity.VectorVelocity = dir * s
		if workspace:Raycast(root.Position, dir * 2, ctx.rayParams) then
			stop()
			return false
		end
		return true
	end

	local function progress(): number
		return math.clamp(elapsed / cfg.ROLL_TIME, 0, 1)
	end

	return { update = update, stop = stop, progress = progress }
end

return table.freeze(Roll)
