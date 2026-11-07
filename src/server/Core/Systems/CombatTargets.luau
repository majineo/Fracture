--!strict
-- Registre des cibles de combat (personnages des joueurs, mannequins, plus tard Échoués) et
-- historique de leurs positions pour la compensation de latence.
-- Studio : ServerScriptService > Server > Systems > CombatTargets
--
-- Chaque cible a une zone de touche simplifiée, mesurée sur son modèle à l'inscription :
--   * une sphère pour la tête ;
--   * une boîte pour le corps (torse + jambes).
-- Les tirs sont jugés sur ces zones « remontées dans le temps » à l'instant où le tireur a
-- vu la scène, pas sur les vraies pièces du personnage.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local PositionHistory = require(script.Parent.Parent.Lib.PositionHistory)

export type Hitbox = {
	headOffset: Vector3, -- centre de la tête dans le repère de la racine
	headRadius: number,
	bodyOffset: Vector3, -- centre de la boîte du corps dans le repère de la racine
	bodyHalfSize: Vector3,
}

export type Target = {
	model: Model,
	root: BasePart,
	player: Player?,
	kind: "Player" | "Dummy" | "Enemy",
	hitbox: Hitbox,
	history: PositionHistory.History,
}

local CombatTargets = {}

local targets: { [Model]: Target } = {}

local function measureHitbox(model: Model, root: BasePart): Hitbox
	local rootCFrame = root.CFrame
	local head = model:FindFirstChild("Head")
	local headOffset = Vector3.new(0, 1.5, 0)
	local headRadius = 0.75
	if head and head:IsA("BasePart") then
		headOffset = rootCFrame:PointToObjectSpace(head.Position)
		headRadius = math.max(head.Size.X, head.Size.Y, head.Size.Z) / 2
	end

	-- Boîte du corps : englobe toutes les pièces sauf la tête et les accessoires.
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= head and part ~= root then
			local localCenter = rootCFrame:PointToObjectSpace(part.Position)
			local half = part.Size / 2
			minV = minV:Min(localCenter - half)
			maxV = maxV:Max(localCenter + half)
		end
	end
	if minV.X == math.huge then
		minV, maxV = Vector3.new(-1, -3, -0.6), Vector3.new(1, 1, 0.6)
	end
	-- La tête a sa propre zone : on arrête le corps sous le menton.
	local top = math.min(maxV.Y, headOffset.Y - headRadius)
	maxV = Vector3.new(maxV.X, top, maxV.Z)
	return {
		headOffset = headOffset,
		headRadius = headRadius,
		bodyOffset = (minV + maxV) / 2,
		bodyHalfSize = (maxV - minV) / 2,
	}
end

local function yawOf(cframe: CFrame): number
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Inscrit une cible. `kind` décide des règles de dégâts (voir HealthService).
function CombatTargets.register(
	model: Model,
	kind: "Player" | "Dummy" | "Enemy",
	player: Player?
): Target?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local target: Target = {
		model = model,
		root = root,
		player = player,
		kind = kind,
		hitbox = measureHitbox(model, root),
		history = PositionHistory.new(CombatConfig.HISTORY_DURATION),
	}
	targets[model] = target
	return target
end

-- Remesure la zone de touche (modèle agrandi après l'inscription : le Gardien, v0.8.0).
function CombatTargets.remeasure(model: Model)
	local target = targets[model]
	if target then
		target.hitbox = measureHitbox(model, target.root)
	end
end

function CombatTargets.unregister(model: Model)
	targets[model] = nil
end

function CombatTargets.get(model: Model): Target?
	return targets[model]
end

function CombatTargets.all(): { [Model]: Target }
	return targets
end

-- CFrame de la racine de la cible au temps serveur `t` (interpolé dans l'historique).
function CombatTargets.rewind(target: Target, t: number): CFrame
	local sample = PositionHistory.at(target.history, t)
	if sample == nil then
		return target.root.CFrame
	end
	return CFrame.new(sample.x, sample.y, sample.z) * CFrame.Angles(0, sample.yaw, 0)
end

function CombatTargets.start()
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for model, target in targets do
			if model.Parent == nil then
				targets[model] = nil
				continue
			end
			local cf = target.root.CFrame
			local p = cf.Position
			PositionHistory.record(target.history, now, p.X, p.Y, p.Z, yawOf(cf))
		end
	end)
end

return CombatTargets
