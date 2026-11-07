--!strict
-- Course sur les murs et saut mural (v0.4.11).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > WallRun
--
-- Démarre seule : en l'air, en mouvement assez vite, avec un mur quasi vertical juste sur le
-- côté. On court le long du mur (petite montée puis lente descente) jusqu'à la fin du mur, du
-- temps imparti, ou d'un saut : le saut mural pousse loin du mur, vers le haut et vers l'avant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local FORCE_PER_MASS = 3000
local MAX_WALL_SLOPE = 0.3 -- |normale.Y| au-delà : ce n'est pas un mur

export type Wall = { normal: Vector3, side: number } -- side : 1 = mur à droite, -1 = à gauche

local WallRun = {}

-- Mur sur le côté (dans le sens du mouvement), ou nil.
function WallRun.find(ctx: Context.Context, moveDirection: Vector3): Wall?
	local root = ctx.root
	local flat = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if flat.Magnitude < 0.1 then
		return nil
	end
	flat = flat.Unit
	local right = flat:Cross(Vector3.yAxis).Unit
	for _, side in { 1, -1 } do
		local hit = workspace:Raycast(
			root.Position,
			right * side * MovementConfig.WALLRUN_REACH,
			ctx.rayParams
		)
		if hit and math.abs(hit.Normal.Y) < MAX_WALL_SLOPE then
			-- Le mur doit longer la course (pas un mur droit devant).
			if math.abs(hit.Normal:Dot(flat)) < 0.6 then
				return { normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit, side = side }
			end
		end
	end
	return nil
end

function WallRun.start(ctx: Context.Context, wall: Wall): (Context.Action, () -> Vector3)
	local cfg = MovementConfig
	local root = ctx.root
	local normal = wall.normal
	local v = root.AssemblyLinearVelocity
	local along = Vector3.new(v.X, 0, v.Z) - normal * Vector3.new(v.X, 0, v.Z):Dot(normal)
	along = if along.Magnitude > 1e-3 then along.Unit else normal:Cross(Vector3.yAxis).Unit
	local speed = math.max(cfg.WALLRUN_SPEED, Context.horizontalVelocity(ctx).Magnitude)

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "WallRunVelocity"
	velocity.Attachment0 = ctx.attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = root.AssemblyMass * FORCE_PER_MASS
	velocity.Parent = root

	local elapsed = 0
	local stopped = false

	local function stop(jump: boolean?)
		if stopped then
			return
		end
		stopped = true
		velocity:Destroy()
		if jump then
			-- Saut mural : loin du mur, vers le haut, en gardant l'élan le long du mur.
			root.AssemblyLinearVelocity = along * speed
				+ normal * cfg.WALLJUMP_PUSH
				+ Vector3.new(0, cfg.WALLJUMP_UP, 0)
		else
			root.AssemblyLinearVelocity = along * speed * 0.8
		end
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / cfg.WALLRUN_DURATION, 0, 1)
		if alpha >= 1 then
			stop()
			return false
		end
		-- Le mur continue-t-il ? (rayon vers le mur)
		local hit =
			workspace:Raycast(root.Position, -normal * (cfg.WALLRUN_REACH + 0.6), ctx.rayParams)
		if hit == nil or math.abs(hit.Normal.Y) >= MAX_WALL_SLOPE then
			stop()
			return false
		end
		-- Obstacle droit devant : fin de course.
		if workspace:Raycast(root.Position, along * 2, ctx.rayParams) then
			stop()
			return false
		end
		local rise = cfg.WALLRUN_START_RISE
			+ (cfg.WALLRUN_END_SINK - cfg.WALLRUN_START_RISE) * alpha
		-- Légère attraction vers le mur pour rester collé.
		velocity.VectorVelocity = along * speed + Vector3.new(0, rise, 0) - normal * 2
		return true
	end

	local function progress(): number
		return math.clamp(elapsed / cfg.WALLRUN_DURATION, 0, 1)
	end

	local function wallNormal(): Vector3
		return normal
	end

	return { update = update, stop = stop, progress = progress }, wallNormal
end

return table.freeze(WallRun)
