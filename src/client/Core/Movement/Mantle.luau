--!strict
-- Escalade de rebord : en sautant face à un rebord de 2,5 à 7 studs, le personnage s'y hisse.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Mantle
--
-- Détection : un rayon vers l'avant trouve le mur, un rayon vers le bas (depuis au-dessus du
-- mur) trouve le dessus du rebord, puis on vérifie qu'il y a la place de s'y tenir debout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Context = require(script.Parent.Context)

local WALKABLE_NORMAL_Y = 0.7 -- dessus du rebord assez plat pour s'y tenir
local LEDGE_INSET = 1.2 -- on se pose à cette distance derrière le bord
local BODY_SIZE = Vector3.new(2, 4.5, 2) -- volume à libérer pour se tenir debout
local RISE_SHARE = 0.6 -- part du temps passée à monter (le reste : avancer)

local Mantle = {}

-- Cherche un rebord escaladable devant le joueur. Renvoie la position finale de la racine.
function Mantle.find(ctx: Context.Context): CFrame?
	local cfg = MovementConfig
	local root = ctx.root
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		return nil
	end
	forward = forward.Unit

	local feetY = Context.feetY(ctx)
	local rootToFeet = root.Position.Y - feetY

	-- 1. Un mur devant, à hauteur de poitrine ou de genoux.
	local wall = workspace:Raycast(root.Position, forward * cfg.MANTLE_REACH, ctx.rayParams)
		or workspace:Raycast(
			Vector3.new(root.Position.X, feetY + 1, root.Position.Z),
			forward * cfg.MANTLE_REACH,
			ctx.rayParams
		)
	if wall == nil or math.abs(wall.Normal.Y) > 0.3 then
		return nil -- pas de mur vertical
	end

	-- 2. Le dessus du rebord, juste derrière la face du mur.
	local probeTop = Vector3.new(
		wall.Position.X,
		feetY + cfg.MANTLE_MAX_HEIGHT + 0.5,
		wall.Position.Z
	) + forward * LEDGE_INSET
	local ledge = workspace:Raycast(
		probeTop,
		Vector3.new(0, -(cfg.MANTLE_MAX_HEIGHT + 0.5), 0),
		ctx.rayParams
	)
	if ledge == nil or ledge.Normal.Y < WALKABLE_NORMAL_Y then
		return nil
	end
	local height = ledge.Position.Y - feetY
	if height < cfg.MANTLE_MIN_HEIGHT or height > cfg.MANTLE_MAX_HEIGHT then
		return nil
	end

	-- 3. De la place pour se tenir debout sur le rebord.
	local standPosition = ledge.Position + Vector3.new(0, rootToFeet + 0.05, 0)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { ctx.character }
	local bodyCenter = CFrame.new(ledge.Position + Vector3.new(0, BODY_SIZE.Y / 2 + 0.1, 0))
	if #workspace:GetPartBoundsInBox(bodyCenter, BODY_SIZE, overlap) > 0 then
		return nil
	end

	return CFrame.lookAt(standPosition, standPosition + forward)
end

function Mantle.start(ctx: Context.Context, target: CFrame): Context.Action
	local cfg = MovementConfig
	local root, humanoid = ctx.root, ctx.humanoid
	local startCFrame = root.CFrame
	local rotation = target.Rotation
	local from = startCFrame.Position
	local top = Vector3.new(from.X, target.Position.Y, from.Z)
	local to = target.Position

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local elapsed = 0
	local stopped = false

	local function stop()
		if stopped then
			return
		end
		stopped = true
		humanoid.AutoRotate = true
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end

	local function update(dt: number): boolean
		if stopped then
			return false
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / cfg.MANTLE_DURATION, 0, 1)
		local position
		if alpha < RISE_SHARE then
			position = from:Lerp(top, alpha / RISE_SHARE)
		else
			position = top:Lerp(to, (alpha - RISE_SHARE) / (1 - RISE_SHARE))
		end
		root.CFrame = CFrame.new(position) * rotation
		root.AssemblyLinearVelocity = Vector3.zero
		if alpha >= 1 then
			stop()
			return false
		end
		return true
	end

	return { update = update, stop = stop }
end

return table.freeze(Mantle)
