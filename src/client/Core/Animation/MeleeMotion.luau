--!strict
-- Trajectoires des coups de lame (v0.4.6). Un coup = la POIGNÉE de l'arme qui suit une courbe
-- dans le repère du haut du torse (+X droite, +Y haut, -Z avant) ; les mains suivent par
-- cinématique inverse (WeaponHold.solve). La lame décrit donc un vrai arc, et les deux mains
-- restent sur une arme tenue à deux mains.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > MeleeMotion
--
-- Enchaînement (combo) : 1 = taille de droite à gauche, 2 = revers de gauche à droite,
-- 3 = estoc. « Heavy » = coup chargé de haut en bas. « Parry » = lame levée en travers.
-- Chaque image clé : instant (0 à 1), position de la poignée, direction de la lame, rotation
-- du buste (degrés : x = penché en arrière, y = tourné vers la gauche).

type Key = { t: number, pos: Vector3, dir: Vector3, up: Vector3?, lean: number, yaw: number }

export type Kind = "Slash1" | "Slash2" | "Thrust" | "Heavy" | "Parry"

local UP = Vector3.yAxis

local function key(
	t: number,
	pos: Vector3,
	dir: Vector3,
	lean: number,
	yaw: number,
	up: Vector3?
): Key
	return { t = t, pos = pos, dir = dir.Unit, up = up, lean = lean, yaw = yaw }
end

local MOTIONS: { [string]: { Key } } = {
	-- Taille : la lame part armée sur la droite et balaie vers la gauche.
	Slash1 = {
		key(0, Vector3.new(0.95, 0.5, -0.55), Vector3.new(0.85, 0.3, -0.45), 0, -28),
		key(0.45, Vector3.new(0.35, 0.25, -1.25), Vector3.new(0.05, 0.05, -1), 0, 0),
		key(1, Vector3.new(-0.4, 0.05, -0.95), Vector3.new(-0.9, -0.1, -0.4), 0, 28),
	},
	-- Revers : de la gauche vers la droite, un peu plus bas.
	Slash2 = {
		key(0, Vector3.new(-0.3, 0.55, -0.85), Vector3.new(-0.85, 0.3, -0.4), 0, 24),
		key(0.45, Vector3.new(0.35, 0.3, -1.25), Vector3.new(0.05, 0, -1), 0, 0),
		key(1, Vector3.new(1.05, 0.0, -0.6), Vector3.new(0.9, -0.15, -0.35), 0, -28),
	},
	-- Estoc : le bras se détend droit devant.
	Thrust = {
		key(0, Vector3.new(0.75, 0.05, -0.35), Vector3.new(-0.05, 0.05, -1), 0, -18),
		key(0.4, Vector3.new(0.3, 0.25, -1.6), Vector3.new(-0.08, 0, -1), -8, 10),
		key(1, Vector3.new(0.35, 0.2, -1.4), Vector3.new(-0.05, 0, -1), -4, 6),
	},
	-- Coup chargé : de haut en bas, buste qui accompagne.
	Heavy = {
		key(
			0,
			Vector3.new(0.4, 1.25, -0.25),
			Vector3.new(0.05, 0.75, 0.65),
			12,
			-10,
			Vector3.new(0, 0, 1)
		),
		key(
			0.4,
			Vector3.new(0.3, 0.85, -1.2),
			Vector3.new(0, 0.35, -1),
			0,
			0,
			Vector3.new(0, 1, 0)
		),
		key(
			1,
			Vector3.new(0.2, -0.45, -1.15),
			Vector3.new(0, -0.75, -0.65),
			-14,
			6,
			Vector3.new(0, 0, -1)
		),
	},
	-- Parade : lame en travers devant le visage, pointe vers la gauche.
	Parry = {
		key(
			0,
			Vector3.new(0.55, 0.85, -0.95),
			Vector3.new(-0.95, 0.25, -0.15),
			-4,
			10,
			Vector3.new(0, 0, -1)
		),
		key(
			1,
			Vector3.new(0.55, 0.85, -0.95),
			Vector3.new(-0.95, 0.25, -0.15),
			-4,
			10,
			Vector3.new(0, 0, -1)
		),
	},
}

local COMBO: { Kind } = { "Slash1", "Slash2", "Thrust" }

local MeleeMotion = {}

-- Nombre de coups dans un enchaînement.
MeleeMotion.COMBO_LENGTH = #COMBO

-- Type de coup pour le n-ième coup d'un enchaînement (1, 2, 3).
function MeleeMotion.comboKind(index: number): Kind
	return COMBO[math.clamp(index, 1, #COMBO)]
end

local function ease(x: number): number
	-- Départ vif, fin amortie : le coup « claque » puis se pose.
	return 1 - (1 - x) * (1 - x) * (1 - x)
end

local function frameOf(k: Key, dir: Vector3, up: Vector3?): CFrame
	local hint = up or k.up or UP
	if math.abs(dir:Dot(hint)) > 0.98 then
		hint = Vector3.zAxis
	end
	return CFrame.lookAt(k.pos, k.pos + dir, hint)
end

-- Repère de la poignée (repère du torse) et rotation du buste à l'instant t (0 à 1).
function MeleeMotion.sample(kind: string, t: number): (CFrame, CFrame)
	local keys = MOTIONS[kind]
	local x = ease(math.clamp(t, 0, 1))
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if x <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(b.t - a.t, 1e-3)
	local u = math.clamp((x - a.t) / span, 0, 1)
	local position = a.pos:Lerp(b.pos, u)
	local direction = a.dir:Lerp(b.dir, u)
	if direction.Magnitude < 1e-3 then
		direction = b.dir
	end
	local upA = a.up or UP
	local upB = b.up or UP
	local grip = frameOf(
		{ t = 0, pos = position, dir = direction, lean = 0, yaw = 0 },
		direction.Unit,
		upA:Lerp(upB, u)
	)
	local lean = a.lean + (b.lean - a.lean) * u
	local yaw = a.yaw + (b.yaw - a.yaw) * u
	return grip, CFrame.Angles(math.rad(lean), math.rad(yaw), 0)
end

return table.freeze(MeleeMotion)
