--!strict
-- Coups de poing (Update 2.0, repris et refait après l'essai Lemonade) : trajectoires des DEUX
-- poings dans le repère du haut du torse (+X droite, +Y haut, -Z avant) ; les bras suivent par
-- cinématique inverse (ArmIK), comme pour les armes. Les positions sont exprimées à partir de
-- l'épaule et en fraction de l'allonge mesurée : la pose tient sur toutes les morphologies.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > PunchMotion
--
-- Enchaînement : 1 = jab (gauche, direct et vif), 2 = direct (droite, épaule qui tourne),
-- 3 = crochet (gauche, bras plié en arc). Coup chargé : uppercut (droite, de bas en haut).
-- « Guard » : poings levés devant le menton (entre deux coups et pendant la charge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponGrip = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("WeaponGrip")
) :: any
local ArmIK = require(script.Parent.ArmIK)

export type Kind = "Jab" | "Cross" | "Hook" | "Uppercut" | "Guard"

-- Une image clé : instant (0 à 1), poing droit et poing gauche (décalage depuis l'épaule, en
-- fraction de l'allonge ; direction du poing), rotation du buste (degrés : yaw = tourné vers
-- la gauche, lean = penché en arrière).
type Fist = { offset: Vector3, dir: Vector3, roll: number }
type Key = { t: number, right: Fist, left: Fist, yaw: number, lean: number }

local GRIP_TO_HAND: CFrame = WeaponGrip.GRIP_TO_HAND

local function fist(x: number, y: number, z: number, dir: Vector3, roll: number?): Fist
	return { offset = Vector3.new(x, y, z), dir = dir.Unit, roll = roll or 0 }
end

-- Garde : poings devant le menton, coudes rentrés.
local GUARD_R = fist(-0.3, 0.32, -0.55, Vector3.new(-0.15, 0.35, -1), -20)
local GUARD_L = fist(0.3, 0.3, -0.6, Vector3.new(0.15, 0.35, -1), 20)

local FORWARD = Vector3.new(0, 0, -1)

local MOTIONS: { [Kind]: { Key } } = {
	Guard = {
		{ t = 0, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
	},
	-- Jab : le poing gauche part droit vers l'avant, le buste tourne un peu vers la droite.
	Jab = {
		{ t = 0, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
		{
			t = 0.35,
			right = GUARD_R,
			left = fist(0.22, 0.22, -0.98, FORWARD, 75),
			yaw = -14,
			lean = -3,
		},
		{
			t = 0.55,
			right = GUARD_R,
			left = fist(0.22, 0.22, -0.98, FORWARD, 75),
			yaw = -14,
			lean = -3,
		},
		{ t = 1, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
	},
	-- Direct : le poing droit traverse, l'épaule droite avance (rotation franche du buste).
	Cross = {
		{ t = 0, right = GUARD_R, left = GUARD_L, yaw = 6, lean = 0 },
		{
			t = 0.38,
			right = fist(-0.28, 0.2, -1.0, FORWARD, -75),
			left = GUARD_L,
			yaw = 28,
			lean = -5,
		},
		{
			t = 0.58,
			right = fist(-0.28, 0.2, -1.0, FORWARD, -75),
			left = GUARD_L,
			yaw = 28,
			lean = -5,
		},
		{ t = 1, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
	},
	-- Crochet : bras gauche plié à l'horizontale, balayage de la gauche vers le centre.
	Hook = {
		{
			t = 0,
			right = GUARD_R,
			left = fist(-0.05, 0.25, -0.45, Vector3.new(0.6, 0.1, -0.8), 85),
			yaw = 16,
			lean = 0,
		},
		{
			t = 0.25,
			right = GUARD_R,
			left = fist(-0.15, 0.28, -0.55, Vector3.new(0.85, 0.05, -0.5), 90),
			yaw = 22,
			lean = 0,
		},
		{
			t = 0.5,
			right = GUARD_R,
			left = fist(0.55, 0.25, -0.7, Vector3.new(0.9, 0, -0.3), 90),
			yaw = -26,
			lean = -4,
		},
		{
			t = 0.65,
			right = GUARD_R,
			left = fist(0.6, 0.22, -0.62, Vector3.new(0.9, 0, -0.2), 90),
			yaw = -28,
			lean = -4,
		},
		{ t = 1, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
	},
	-- Uppercut : poing droit armé bas (genoux fléchis par le buste penché), remonte sous le menton.
	Uppercut = {
		{
			t = 0,
			right = fist(-0.1, -0.35, -0.45, Vector3.new(0, 0.6, -0.8), -10),
			left = GUARD_L,
			yaw = -12,
			lean = -12,
		},
		{
			t = 0.45,
			right = fist(-0.3, 0.45, -0.78, Vector3.new(0, 0.95, -0.3), -10),
			left = GUARD_L,
			yaw = 22,
			lean = 10,
		},
		{
			t = 0.62,
			right = fist(-0.3, 0.5, -0.75, Vector3.new(0, 1, -0.2), -10),
			left = GUARD_L,
			yaw = 22,
			lean = 10,
		},
		{ t = 1, right = GUARD_R, left = GUARD_L, yaw = 0, lean = 0 },
	},
}

local PunchMotion = {}

-- Durée de l'animation de chaque coup (secondes ; la cadence réelle est fixée par le serveur).
local DURATIONS: { [Kind]: number } =
	{ Jab = 0.26, Cross = 0.3, Hook = 0.36, Uppercut = 0.46, Guard = 0 }

function PunchMotion.duration(kind: Kind): number
	return DURATIONS[kind] or 0.3
end

-- Coup de l'enchaînement (1 à 3).
function PunchMotion.comboKind(combo: number): Kind
	return if combo == 2 then "Cross" elseif combo == 3 then "Hook" else "Jab"
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerpFist(a: Fist, b: Fist, k: number): Fist
	return {
		offset = a.offset:Lerp(b.offset, k),
		dir = a.dir:Lerp(b.dir, k).Unit,
		roll = a.roll + (b.roll - a.roll) * k,
	}
end

-- Image interpolée à l'instant t (0 à 1).
local function sampleKey(kind: Kind, t: number): Key
	local keys = MOTIONS[kind]
	if #keys == 1 or t <= keys[1].t then
		return keys[1]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local k = smooth((t - a.t) / math.max(b.t - a.t, 1e-3))
			return {
				t = t,
				right = lerpFist(a.right, b.right, k),
				left = lerpFist(a.left, b.left, k),
				yaw = a.yaw + (b.yaw - a.yaw) * k,
				lean = a.lean + (b.lean - a.lean) * k,
			}
		end
	end
	return keys[#keys]
end

-- Repère de la main (repère du torse) pour un poing : la « poignée » imaginaire est le poing
-- fermé, -Z vers la cible ; `roll` tourne le poing autour de sa direction (0 = poing vertical).
local function handFrame(arm: ArmIK.Arm, f: Fist): CFrame
	local shoulder = ArmIK.shoulderPosition(arm)
	local position = shoulder + f.offset * arm.reach
	local grip = CFrame.lookAt(position, position + f.dir, Vector3.yAxis)
		* CFrame.Angles(0, 0, math.rad(f.roll))
	return grip * GRIP_TO_HAND
end

-- Pose des deux bras (rotations d'articulations) et rotation du buste à l'instant t.
function PunchMotion.solve(
	arms: { right: ArmIK.Arm, left: ArmIK.Arm },
	kind: Kind,
	t: number,
	blend: number?
): ({ [string]: CFrame }, CFrame)
	local key = sampleKey(kind, t)
	local amount = math.clamp(blend or 1, 0, 1)
	if amount < 1 then
		local guard = MOTIONS.Guard[1]
		key = {
			t = t,
			right = lerpFist(guard.right, key.right, amount),
			left = lerpFist(guard.left, key.left, amount),
			yaw = key.yaw * amount,
			lean = key.lean * amount,
		}
	end
	local right = ArmIK.solve(arms.right, handFrame(arms.right, key.right), Vector3.new(1, -1, 0.6))
	local left = ArmIK.solve(arms.left, handFrame(arms.left, key.left), Vector3.new(-1, -1, 0.6))
	local pose = {
		RightShoulder = right.shoulder,
		RightElbow = right.elbow,
		RightWrist = right.wrist,
		LeftShoulder = left.shoulder,
		LeftElbow = left.elbow,
		LeftWrist = left.wrist,
	}
	local twist = CFrame.Angles(math.rad(key.lean), math.rad(key.yaw), 0)
	return pose, twist
end

return table.freeze(PunchMotion)
