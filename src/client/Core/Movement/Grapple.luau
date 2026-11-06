--!strict
-- Grappin : le crochet vole vers une surface (60 studs max), s'accroche, puis la corde tire.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Grapple
--
-- Phases : vol du crochet (corde molle) → traction qui accélère → ralentissement à l'arrivée.
-- Le mouvement est simulé localement (réactivité). Le serveur reçoit la cible dès le tir, la
-- vérifie (portée, recharge, ligne de vue) et autorise alors la vitesse correspondante ; un
-- grappin refusé est rattrapé par la garde de mouvement du serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local Context = require(script.Parent.Context)
local Rope = require(script.Parent.Rope)

local LINE_OF_SIGHT_TOLERANCE = 2
local FORCE_PER_MASS = 3000 -- doit dominer le Humanoid et la gravité (mesuré en v0.3.0)
local INITIAL_SLACK = 4

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
	local root, humanoid = ctx.root, ctx.humanoid

	local distance = (target - root.Position).Magnitude
	local flightTime = distance / cfg.GRAPPLE_HOOK_SPEED
	local rope = Rope.attach(ctx.attachment, root.Position)
	rope.setSlack(INITIAL_SLACK)

	local velocity: LinearVelocity? = nil
	local speed = Spring.new(0, cfg.GRAPPLE_ACCELERATION)
	local elapsed = 0
	local pullTime = 0
	local stopped = false

	local function stop(boost: boolean?)
		if stopped then
			return
		end
		stopped = true
		if velocity then
			velocity:Destroy()
		end
		rope.destroy()
		humanoid.AutoRotate = true
		if boost then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity =
				Vector3.new(v.X, math.max(v.Y, 0) + cfg.GRAPPLE_RELEASE_BOOST, v.Z)
		end
	end

	local function beginPull()
		local created = Instance.new("LinearVelocity")
		created.Name = "GrappleVelocity"
		created.Attachment0 = ctx.attachment
		created.RelativeTo = Enum.ActuatorRelativeTo.World
		created.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		created.MaxForce = root.AssemblyMass * FORCE_PER_MASS
		created.VectorVelocity = root.AssemblyLinearVelocity
		created.Parent = root
		velocity = created
		-- La traction part de la vitesse actuelle vers la cible.
		local toward = (target - root.Position).Unit
		Spring.snap(speed, math.max(0, root.AssemblyLinearVelocity:Dot(toward)))
		speed.target = cfg.GRAPPLE_SPEED
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt

		-- 1. Vol du crochet
		if elapsed < flightTime then
			local t = elapsed / flightTime
			rope.setEnd(root.Position:Lerp(target, t))
			rope.setSlack(INITIAL_SLACK * (1 - t))
			return true
		end
		if velocity == nil then
			rope.setEnd(target)
			rope.setSlack(0)
			beginPull()
		end

		-- 2. Traction
		pullTime += dt
		local offset = target - root.Position
		local remaining = offset.Magnitude
		if remaining <= cfg.GRAPPLE_STOP_DISTANCE or pullTime >= cfg.GRAPPLE_MAX_TIME then
			stop(false)
			return false
		end
		-- Ralentissement en approche : la vitesse visée baisse dans les derniers studs.
		local approach = math.clamp(
			(remaining - cfg.GRAPPLE_STOP_DISTANCE) / cfg.GRAPPLE_SLOWDOWN_DISTANCE,
			0,
			1
		)
		speed.target = cfg.GRAPPLE_ARRIVAL_SPEED
			+ (cfg.GRAPPLE_SPEED - cfg.GRAPPLE_ARRIVAL_SPEED) * approach
		local currentSpeed = Spring.step(speed, dt)
		local direction = offset.Unit;
		(velocity :: LinearVelocity).VectorVelocity = direction * currentSpeed

		-- Le corps se tourne vers la cible (horizontalement).
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.1 then
			local facing = CFrame.lookAt(root.Position, root.Position + flat)
			root.CFrame = root.CFrame:Lerp(facing, math.min(1, dt * 12))
		end
		return true
	end

	local function getProgress(): number
		if elapsed < flightTime then
			return 0
		end
		return math.clamp(pullTime / cfg.GRAPPLE_MAX_TIME, 0, 1)
	end

	return { update = update, stop = stop, progress = getProgress }
end

return table.freeze(Grapple)
