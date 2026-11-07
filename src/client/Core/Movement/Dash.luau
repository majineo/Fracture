--!strict
-- Élan (dash, v0.4.11) : courte poussée dans la direction du mouvement, au sol ou en l'air.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Dash
--
-- Une contrainte LinearVelocity impose la vitesse (gravité neutralisée pendant l'élan, pour un
-- mouvement net) ; à la fin, on garde une partie de la vitesse pour enchaîner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local FORCE_PER_MASS = 3000

local Dash = {}

function Dash.start(ctx: Context.Context, direction: Vector3): Context.Action
	local cfg = MovementConfig
	local root = ctx.root
	local dir = Vector3.new(direction.X, 0, direction.Z)
	dir = if dir.Magnitude > 1e-3
		then dir.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = ctx.attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = root.AssemblyMass * FORCE_PER_MASS
	velocity.VectorVelocity = dir * cfg.DASH_SPEED
	velocity.Parent = root

	local elapsed = 0
	local stopped = false

	local function stop()
		if stopped then
			return
		end
		stopped = true
		velocity:Destroy()
		-- On garde de l'élan pour enchaîner (saut, glissade…).
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = dir * cfg.DASH_EXIT_SPEED
			+ Vector3.new(0, math.max(v.Y, 0), 0)
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		if elapsed >= cfg.DASH_TIME then
			stop()
			return false
		end
		-- Mur droit devant : on s'arrête net.
		if workspace:Raycast(root.Position, dir * 2.2, ctx.rayParams) then
			stop()
			return false
		end
		return true
	end

	local function progress(): number
		return math.clamp(elapsed / cfg.DASH_TIME, 0, 1)
	end

	return { update = update, stop = stop, progress = progress }
end

return table.freeze(Dash)
