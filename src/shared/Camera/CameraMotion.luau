--!strict
-- Calculs purs de la caméra du joueur (Update 2.0, phase 2) : perspectives, perche de collision,
-- balancement de course, inclinaison, anticipation, fondu du personnage, correction des
-- déplacements en vue de face. Testé par tests/specs/CameraMotion.spec.luau.
-- Studio : ReplicatedStorage > Shared > Camera > CameraMotion
--
-- Règle de confort : tous les effets restent discrets (quelques centimètres, quelques dixièmes
-- de degré) et s'effacent en visée ; la rotation de la vue n'est JAMAIS lissée (aucun retard
-- sur la souris, le doigt ou le stick).

local CameraMotion = {}

export type Perspective = "Behind" | "Front" | "First"

-- Réglages centralisés (studs, secondes, degrés).
CameraMotion.CONFIG = table.freeze({
	-- distances
	DISTANCE_UNARMED = 10, -- vue de dos sans arme (molette : ZOOM_MIN à ZOOM_MAX)
	ZOOM_MIN = 5,
	ZOOM_MAX = 18,
	DISTANCE_ARMED = 8, -- arme en main
	DISTANCE_AIM = 5, -- en visée
	DISTANCE_FRONT = 8, -- vue de face
	EYE_HEIGHT = 1.6, -- point suivi au-dessus de la racine
	FIRST_PERSON_EYE = 1.5, -- hauteur des yeux en première personne
	FIRST_PERSON_FORWARD = 0.25, -- léger avancement pour ne pas voir l'intérieur du cou
	MAX_PITCH = 75,
	MAX_PITCH_FIRST = 85,
	-- suivi (ressorts : raideur, amortissement)
	FOLLOW_H_SPEED = 38, -- horizontal : très serré (≈ 0,5 stud de retard en marche)
	FOLLOW_H_DAMPING = 0.9, -- léger dépassement à l'arrêt
	FOLLOW_V_SPEED = 20, -- vertical : plus souple (sauts, marches)
	SNAP_DISTANCE = 12, -- au-delà (téléportation, réapparition) : on recale d'un coup
	LEAD_GAIN = 0.035, -- anticipation : studs par stud/s de vitesse
	LEAD_MAX = 0.7,
	-- balancement de course
	BOB_HEIGHT = 0.06, -- studs à pleine vitesse de sprint
	BOB_ROLL = 0.25, -- degrés
	STRIDE = 3.4, -- studs par pas
	-- inclinaison en pas chassé
	STRAFE_ROLL = 1.2, -- degrés à pleine vitesse latérale
	REFERENCE_SPEED = 22, -- vitesse de sprint (normalisation)
	-- collision
	PROBE_RADIUS = 0.5,
	WALL_MARGIN = 0.2,
	BOOM_OUT_RATE = 4, -- retour progressif (1/s) ; l'entrée est instantanée
	-- personnage trop proche de la caméra
	FADE_START = 2.0,
	FADE_END = 0.9,
	-- transitions de perspective (raideur des ressorts)
	TRANSITION_SPEED = 9,
})

local C = CameraMotion.CONFIG

-- Ordre du cycle (comme F5 dans Minecraft) : première personne → dos → face → première personne.
local CYCLE: { [Perspective]: Perspective } =
	{ First = "Behind", Behind = "Front", Front = "First" }

function CameraMotion.nextPerspective(current: Perspective): Perspective
	return CYCLE[current] or "Behind"
end

-- Perspective réellement utilisée : arme en main, la vue de face devient la vue de dos (on ne
-- vise jamais en regardant son propre visage) ; la préférence du joueur est conservée.
function CameraMotion.effective(preferred: Perspective, armed: boolean): Perspective
	if armed and preferred == "Front" then
		return "Behind"
	end
	return preferred
end

-- Longueur de perche voulue selon la perspective et l'état.
function CameraMotion.distanceFor(
	p: Perspective,
	armed: boolean,
	aiming: boolean,
	zoom: number
): number
	if p == "First" then
		return 0
	elseif p == "Front" then
		return C.DISTANCE_FRONT
	elseif aiming then
		return C.DISTANCE_AIM
	elseif armed then
		return C.DISTANCE_ARMED
	end
	return math.clamp(zoom, C.ZOOM_MIN, C.ZOOM_MAX)
end

-- Perche après collision : rentre instantanément (jamais l'intérieur d'un mur), ressort
-- progressivement (pas de « pompage » en longeant des piliers).
function CameraMotion.boom(current: number, free: number, dt: number): number
	if free <= current then
		return free
	end
	local k = 1 - math.exp(-C.BOOM_OUT_RATE * dt)
	return current + (free - current) * k
end

-- Distance libre derrière le pivot d'après un contact à `hitDistance` (nil : rien).
function CameraMotion.freeDistance(wanted: number, hitDistance: number?): number
	if hitDistance == nil then
		return wanted
	end
	return math.clamp(hitDistance - C.WALL_MARGIN, 0, wanted)
end

-- Phase de foulée : avance avec la distance parcourue au sol.
function CameraMotion.stride(phase: number, groundSpeed: number, dt: number): number
	return (phase + groundSpeed * dt / C.STRIDE * math.pi) % (math.pi * 2)
end

-- Balancement de course : (hauteur en studs, roulis en degrés). `weight` de 0 à 1 (s'efface en
-- visée, en l'air ou à l'arrêt).
function CameraMotion.bob(phase: number, groundSpeed: number, weight: number): (number, number)
	local k = math.clamp(groundSpeed / C.REFERENCE_SPEED, 0, 1) * math.clamp(weight, 0, 1)
	-- deux pas par cycle : hauteur au double de la fréquence du roulis
	local height = math.abs(math.sin(phase)) * 2 - 1
	return height * C.BOB_HEIGHT * k, math.sin(phase) * C.BOB_ROLL * k
end

-- Inclinaison en pas chassé (degrés) : vitesse latérale dans le repère de la caméra (+ = droite).
function CameraMotion.strafeRoll(lateralSpeed: number, weight: number): number
	local k = math.clamp(lateralSpeed / C.REFERENCE_SPEED, -1, 1)
	return -k * C.STRAFE_ROLL * math.clamp(weight, 0, 1)
end

-- Anticipation : décalage horizontal (x, z) dans le sens du mouvement, borné.
function CameraMotion.lead(vx: number, vz: number): (number, number)
	local x, z = vx * C.LEAD_GAIN, vz * C.LEAD_GAIN
	local m = math.sqrt(x * x + z * z)
	if m > C.LEAD_MAX then
		x, z = x / m * C.LEAD_MAX, z / m * C.LEAD_MAX
	end
	return x, z
end

-- Transparence locale du personnage selon la distance caméra-tête (0 visible, 1 caché).
function CameraMotion.fade(distance: number): number
	if distance >= C.FADE_START then
		return 0
	elseif distance <= C.FADE_END then
		return 1
	end
	return 1 - (distance - C.FADE_END) / (C.FADE_START - C.FADE_END)
end

-- Tourne un vecteur horizontal (x, z) de `angle` radians autour de la verticale (sens Roblox :
-- angle positif = rotation de +X vers -Z, comme CFrame.Angles(0, angle, 0)).
function CameraMotion.rotateFlat(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c + z * s, -x * s + z * c
end

-- Angle ramené dans ]-π, π].
function CameraMotion.wrap(angle: number): number
	local a = (angle + math.pi) % (math.pi * 2) - math.pi
	if a <= -math.pi then
		a += math.pi * 2
	end
	return a
end

return CameraMotion
