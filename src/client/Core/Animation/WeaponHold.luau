--!strict
-- Tenue des armes : où se trouve l'arme par rapport au buste, et où vont les deux mains.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > WeaponHold
--
-- Principe (v0.4.4) : on place d'abord l'ARME (repère de sa poignée, dans le repère du haut
-- du torse : +X droite, +Y haut, -Z avant), puis les mains viennent la saisir par
-- cinématique inverse (ArmIK). Les deux mains restent donc collées à l'arme quel que soit
-- l'avatar. Trois états :
--   "Ready"  : garde / position basse prête (marche, immobile)
--   "Sprint" : course, arme tenue à deux mains contre la poitrine (« port d'arme » militaire)
--   "Aim"    : épaulée vers le point visé (armes à feu, en visée ou juste après un tir)
--
-- Pour retoucher une tenue : modifier HOLDS ci-dessous, relancer le test, regarder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponGrip = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("WeaponGrip")
) :: any
local ArmIK = require(script.Parent.ArmIK)

export type State = "Ready" | "Sprint" | "Aim"

export type Arms = { right: ArmIK.Arm, left: ArmIK.Arm }

type Placement = {
	-- Arme épaulée : direction du canon (repère du torse). Sinon : repère de poignée fixe.
	shoulder: Vector3?,
	grip: CFrame?,
}

type Hold = {
	twoHanded: boolean,
	extend: boolean?, -- visée bras tendus (pistolet) plutôt qu'épaulée
	ready: Placement,
	sprint: Placement,
	rightPole: Vector3,
	leftPole: Vector3,
}

-- Géométrie propre à chaque modèle d'arme (mesurée sur les modèles Blender, v0.4.4).
--   stock   : distance poignée → crosse (armes épaulées) ; remplacée par la mesure du
--             modèle réellement tenu quand il est disponible (WeaponHold.measureStock)
--   support : main gauche, dans le repère de la poignée
type Geometry = { stock: number?, support: CFrame? }

local GRIP_TO_HAND: CFrame = WeaponGrip.GRIP_TO_HAND
local HAND_TO_GRIP: CFrame = WeaponGrip.HAND_TO_GRIP

-- Main gauche SOUS un fût (paume vers le haut, doigts qui enveloppent vers la droite).
local UNDER_BARREL = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis, Vector3.zAxis)
-- Main gauche orientée comme la droite (poignée d'épée, prise du pistolet à deux mains).
local LIKE_RIGHT = GRIP_TO_HAND.Rotation

local GEOMETRY: { [string]: Geometry } = {
	-- Les bras d'un avatar Roblox sont courts : la main gauche tient le fût juste devant la
	-- carcasse (plus loin, elle n'atteint pas l'arme).
	["weapon.repeating_rifle"] = {
		stock = 1.0, -- crosse raccourcie dans Blender (v0.4.4 ; 1,55 avant)
		support = CFrame.new(0, -0.6, -0.85) * UNDER_BARREL,
	},
	["weapon.heavy_crossbow"] = {
		stock = 1.05,
		support = CFrame.new(0, -0.6, -0.7) * UNDER_BARREL,
	},
	["weapon.fracture_pistol"] = {
		support = CFrame.new(-0.6, -0.1, 0.05) * LIKE_RIGHT,
	},
	["weapon.longsword"] = {
		support = CFrame.new(0, 0, 0.66) * LIKE_RIGHT,
	},
}

local function frame(position: Vector3, forward: Vector3, up: Vector3): CFrame
	return CFrame.lookAt(position, position + forward.Unit, up)
end

local HOLDS: { [string]: Hold } = {
	LongGun = {
		twoHanded = true,
		-- Arme à l'épaule, canon baissé vers le sol devant soi.
		ready = { shoulder = Vector3.new(-0.12, -0.55, -0.83) },
		-- Port d'arme : en travers de la poitrine, canon vers le haut et la gauche.
		sprint = {
			grip = frame(
				Vector3.new(0.45, -0.35, -0.85),
				Vector3.new(-0.6, 0.72, -0.35),
				Vector3.new(0, 0.2, -1)
			),
		},
		rightPole = Vector3.new(1, -0.8, 0.4),
		leftPole = Vector3.new(-0.4, -1, 0.1),
	},
	Pistol = {
		twoHanded = true,
		extend = true,
		-- Position compacte : pistolet devant la poitrine, canon vers le bas et l'avant.
		ready = {
			grip = frame(
				Vector3.new(0.2, -0.15, -1.05),
				Vector3.new(-0.05, -0.45, -0.9),
				Vector3.yAxis
			),
		},
		sprint = {
			grip = frame(
				Vector3.new(0.25, -0.2, -0.85),
				Vector3.new(-0.05, -0.8, -0.6),
				Vector3.new(0, 0.6, -0.8)
			),
		},
		rightPole = Vector3.new(1, -1, 0.3),
		leftPole = Vector3.new(-1, -1, 0.3),
	},
	Blade = {
		twoHanded = false,
		-- Garde : lame devant soi, pointe relevée.
		ready = {
			grip = frame(
				Vector3.new(0.75, -0.55, -1.05),
				Vector3.new(-0.05, 0.6, -0.8),
				Vector3.new(-1, 0, 0)
			),
		},
		-- Course : lame tenue basse, pointe vers l'arrière, le long de la cuisse.
		sprint = {
			grip = frame(
				Vector3.new(1.05, -1.05, -0.35),
				Vector3.new(0.05, -0.45, 0.89),
				Vector3.new(0, 0, -1)
			),
		},
		rightPole = Vector3.new(1, -1, 0.5),
		leftPole = Vector3.new(-1, -1, 0.5),
	},
	Greatsword = {
		twoHanded = true,
		-- Garde haute « charrue » : deux mains, pointe vers l'avant et le haut.
		ready = {
			-- Assez haute et centrée pour que la main gauche atteigne le pommeau.
			grip = frame(
				Vector3.new(-0.02, -0.08, -1.1),
				Vector3.new(-0.05, 0.55, -0.83),
				Vector3.new(-1, 0, 0)
			),
		},
		-- Course : épée en travers de la poitrine, pointe vers le haut et la gauche.
		sprint = {
			grip = frame(
				Vector3.new(0.45, -0.45, -0.85),
				Vector3.new(-0.55, 0.75, -0.35),
				Vector3.new(0, 0.2, -1)
			),
		},
		rightPole = Vector3.new(1, -1, 0.4),
		leftPole = Vector3.new(-1, -1, 0.4),
	},
}

-- Point d'appui de la crosse (creux de l'épaule droite, repère du torse).
local SHOULDER_POCKET = Vector3.new(0.55, 0.62, -0.55)
-- Bras tendus (pistolet) : départ des bras, devant le haut de la poitrine.
local EXTEND_ORIGIN = Vector3.new(0.2, 0.5, -0.3)
local MAX_YAW = math.rad(45)
local MAX_PITCH = math.rad(70)
local REACH_RATIO = 0.94

local WeaponHold = {}

function WeaponHold.has(hold: string?): boolean
	return hold ~= nil and HOLDS[hold] ~= nil
end

-- Longueur poignée → crosse du modèle tenu (pièce « Grip » + toutes ses pièces), ou nil.
function WeaponHold.measureStock(held: Instance?): number?
	local grip = held and held:FindFirstChild("Grip", true)
	if grip == nil or not grip:IsA("BasePart") then
		return nil
	end
	local frameOfGrip = grip.CFrame
	local back = 0
	for _, part in (held :: Instance):GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			local cf = part.CFrame
			for _, corner in
				{
					Vector3.new(half.X, half.Y, half.Z),
					Vector3.new(-half.X, half.Y, half.Z),
					Vector3.new(half.X, -half.Y, half.Z),
					Vector3.new(-half.X, -half.Y, half.Z),
					Vector3.new(half.X, half.Y, -half.Z),
					Vector3.new(-half.X, half.Y, -half.Z),
					Vector3.new(half.X, -half.Y, -half.Z),
					Vector3.new(-half.X, -half.Y, -half.Z),
				}
			do
				back = math.max(back, frameOfGrip:PointToObjectSpace(cf * corner).Z)
			end
		end
	end
	return if back > 0.2 then back else nil
end

-- Mesure les deux bras du personnage (à refaire si sa morphologie change).
function WeaponHold.measureArms(rig: any): Arms?
	local right = ArmIK.measure(rig, "Right", HAND_TO_GRIP)
	local left = ArmIK.measure(rig, "Left", HAND_TO_GRIP)
	if right == nil or left == nil then
		return nil
	end
	return { right = right, left = left }
end

-- Garde la direction de visée dans un cône devant le buste.
local function clampDirection(direction: Vector3): Vector3
	local d = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.new(0, 0, -1)
	local yaw = math.clamp(math.atan2(-d.X, -d.Z), -MAX_YAW, MAX_YAW)
	local pitch = math.clamp(math.asin(math.clamp(d.Y, -1, 1)), -MAX_PITCH, MAX_PITCH)
	return Vector3.new(
		-math.sin(yaw) * math.cos(pitch),
		math.sin(pitch),
		-math.cos(yaw) * math.cos(pitch)
	)
end

-- Distance s ≥ 0 le long de `direction` depuis `origin` où l'on se trouve à `radius` du
-- point `center` (nil si jamais).
local function alongToRadius(
	origin: Vector3,
	direction: Vector3,
	center: Vector3,
	radius: number
): number?
	local w = origin - center
	local b = w:Dot(direction)
	local discriminant = b * b - (w:Dot(w) - radius * radius)
	if discriminant < 0 then
		return nil
	end
	return -b + math.sqrt(discriminant)
end

local function maxGripDistance(arm: ArmIK.Arm): number
	return (arm.reach + arm.wristToGrip) * REACH_RATIO
end

-- Arme épaulée (crosse au creux de l'épaule) ou bras tendus, canon vers `direction`.
local function aimedGrip(arms: Arms, hold: Hold, direction: Vector3, stock: number): CFrame
	local d = clampDirection(direction)
	local shoulder = ArmIK.shoulderPosition(arms.right)
	local limit = maxGripDistance(arms.right)
	local origin = if hold.extend then EXTEND_ORIGIN else SHOULDER_POCKET
	local wanted = if hold.extend then limit else stock
	-- Si la main ne peut pas atteindre la poignée, la crosse recule (bras trop courts pour
	-- un long fût) : la main reste toujours sur l'arme.
	local s = alongToRadius(origin, d, shoulder, limit)
	local distance = if s then math.min(wanted, s) else wanted
	local position = origin + d * distance
	local up = Vector3.yAxis - d * d.Y
	return CFrame.lookAt(
		position,
		position + d,
		if up.Magnitude > 1e-3 then up.Unit else Vector3.zAxis
	)
end

-- Repère de la poignée voulu (repère du torse) pour une arme, un état, une direction de visée.
function WeaponHold.targetGrip(
	arms: Arms,
	hold: string,
	weaponId: string,
	state: State,
	aimDirection: Vector3?,
	measuredStock: number?
): CFrame?
	local config = HOLDS[hold]
	if config == nil then
		return nil
	end
	local geometry = GEOMETRY[weaponId] or {}
	local stock = measuredStock or geometry.stock or 1
	if state == "Aim" and aimDirection then
		return aimedGrip(arms, config, aimDirection, stock)
	end
	local placement = if state == "Sprint" then config.sprint else config.ready
	if placement.shoulder then
		return aimedGrip(arms, config, placement.shoulder, stock)
	end
	return placement.grip
end

-- Pose des bras (rotations d'articulations) pour tenir l'arme dont la poignée est en `grip`
-- (repère du torse). Renvoie aussi le repère de poignée réellement atteint.
function WeaponHold.solve(
	arms: Arms,
	hold: string,
	weaponId: string,
	grip: CFrame
): ({ [string]: CFrame }, CFrame)
	local config = HOLDS[hold]
	local pose: { [string]: CFrame } = {}
	local right = ArmIK.solve(arms.right, grip * GRIP_TO_HAND, config.rightPole)
	pose.RightShoulder = right.shoulder
	pose.RightElbow = right.elbow
	pose.RightWrist = right.wrist
	-- L'arme suit la main droite : la main gauche vise l'arme là où elle est vraiment.
	local reached = right.hand * HAND_TO_GRIP
	local support = (GEOMETRY[weaponId] or {}).support
	if config.twoHanded and support then
		local left = ArmIK.solve(arms.left, reached * support, config.leftPole)
		pose.LeftShoulder = left.shoulder
		pose.LeftElbow = left.elbow
		pose.LeftWrist = left.wrist
	end
	return pose, reached
end

return table.freeze(WeaponHold)
