--!strict
-- Salto (v0.9.0) : second saut en l'air, avec une rotation complète du corps. Avant si l'on
-- avance (ou à l'arrêt), arrière si l'on recule. Une fois par saut ; toucher le sol ou un mur
-- le recharge.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Flip
--
-- Physique simple : on donne une vitesse verticale et une petite poussée horizontale, puis le
-- joueur garde le contrôle en l'air. La rotation est seulement visuelle (couche « Flip »).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local Flip = {}

-- `sign` : 1 = salto avant, -1 = salto arrière (pour l'animation).
function Flip.start(ctx: Context.Context): (Context.Action, number)
	local cfg = MovementConfig
	local root = ctx.root
	local move = ctx.humanoid.MoveDirection
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local sign = if move.Magnitude > 0.1
			and look.Magnitude > 0.1
			and move:Dot(look.Unit) < -0.3
		then -1
		else 1

	local v = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(v.X, 0, v.Z)
	if move.Magnitude > 0.1 then
		horizontal += Vector3.new(move.X, 0, move.Z).Unit * cfg.FLIP_PUSH
	end
	local cap = cfg.SPRINT_SPEED + cfg.FLIP_PUSH
	if horizontal.Magnitude > cap then
		horizontal = horizontal.Unit * cap
	end
	root.AssemblyLinearVelocity = horizontal + Vector3.new(0, cfg.FLIP_UP_SPEED, 0)
	ctx.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local elapsed = 0
	local stopped = false

	local function stop()
		stopped = true
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		if elapsed >= cfg.FLIP_TIME then
			return false
		end
		-- Retombé au sol avant la fin : on s'arrête là.
		if elapsed > 0.15 and ctx.humanoid.FloorMaterial ~= Enum.Material.Air then
			return false
		end
		return true
	end

	local function progress(): number
		return math.clamp(elapsed / cfg.FLIP_TIME, 0, 1)
	end

	return { update = update, stop = stop, progress = progress }, sign
end

return table.freeze(Flip)
