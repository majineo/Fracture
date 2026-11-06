--!strict
-- Glissade : impulsion horizontale qui ralentit en douceur (plus lentement en descente).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Slide
--
-- Une contrainte LinearVelocity en mode « plan » pilote la vitesse horizontale seulement :
-- la gravité continue d'agir, donc la glissade suit les pentes et peut tomber d'un rebord.
-- L'abaissement de la caméra et la pose sont gérés par CameraFeel et CharacterAnimation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local BLOCKED_AFTER = 0.15 -- secondes avant de vérifier si on a heurté un obstacle
local BLOCKED_RATIO = 0.35 -- vitesse réelle < 35 % de la vitesse visée = bloqué
-- Doit dominer le freinage du Humanoid au sol (mesuré : ×600 insuffisant, ×3000 suffisant).
local FORCE_PER_MASS = 3000

local Slide = {}

function Slide.start(ctx: Context.Context, direction: Vector3): Context.Action
	local cfg = MovementConfig
	local root, humanoid = ctx.root, ctx.humanoid
	local dir = Vector3.new(direction.X, 0, direction.Z)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else root.CFrame.LookVector

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SlideVelocity"
	velocity.Attachment0 = ctx.attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.MaxForce = root.AssemblyMass * FORCE_PER_MASS
	velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * cfg.SLIDE_SPEED
	velocity.Parent = root

	local progress = 0 -- de 0 à SLIDE_DURATION (ralenti en descente)
	local elapsed = 0
	local stopped = false
	local currentSpeed = cfg.SLIDE_SPEED

	local function stop()
		if stopped then
			return
		end
		stopped = true
		velocity:Destroy()
	end

	local function isDownhill(): boolean
		local hit = workspace:Raycast(
			root.Position,
			Vector3.new(0, -(root.Size.Y + humanoid.HipHeight + 2), 0),
			ctx.rayParams
		)
		-- Une normale de sol penchée vers l'avant signifie qu'on descend.
		return hit ~= nil and hit.Normal:Dot(dir) > 0.15
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		progress += dt * (if isDownhill() then cfg.SLIDE_DOWNHILL_TIME_SCALE else 1)
		local alpha = math.clamp(progress / cfg.SLIDE_DURATION, 0, 1)
		-- Ralentissement « ease-out » : vite au début, puis on glisse doucement vers la fin.
		local eased = 1 - (1 - alpha) * (1 - alpha)
		currentSpeed = cfg.SLIDE_SPEED + (cfg.SLIDE_END_SPEED - cfg.SLIDE_SPEED) * eased
		velocity.PlaneVelocity = Vector2.new(dir.X, dir.Z) * currentSpeed

		if alpha >= 1 then
			stop()
			return false
		end
		if
			elapsed > BLOCKED_AFTER
			and Context.horizontalVelocity(ctx).Magnitude < currentSpeed * BLOCKED_RATIO
		then
			stop() -- mur ou obstacle
			return false
		end
		return true
	end

	local function getProgress(): number
		return math.clamp(progress / cfg.SLIDE_DURATION, 0, 1)
	end

	return { update = update, stop = stop, progress = getProgress }
end

return table.freeze(Slide)
