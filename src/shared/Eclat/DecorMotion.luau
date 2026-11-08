--!strict
-- Mouvements du décor de l'Éclat (v0.12) : fonctions pures du temps, utilisées par le client
-- (Client > Place > Controllers > DecorFx) pour animer torches, cristaux et mécanismes figés.
-- Le temps est « fracturé » : les rouages avancent par à-coups et reculent parfois d'un cran,
-- le balancier se fige puis repart. Testé par tests/specs/DecorMotion.spec.luau.
-- Studio : ReplicatedStorage > Shared > Eclat > DecorMotion

local DecorMotion = {}

local TAU = math.pi * 2

-- Cran d'un rouage (degrés) et durée d'un cran (secondes).
DecorMotion.TICK_STEP = 12
DecorMotion.TICK_PERIOD = 1.1
local TICK_EASE = 0.14 -- part du cran consacrée au mouvement (le reste : arrêt)

-- Motif des crans : trois en avant, un en arrière.
local PATTERN = { 1, 1, 1, -1 }
local PREFIX = { 0, 1, 2, 3 } -- somme du motif avant chaque cran

-- Vacillement d'une flamme : facteur de luminosité autour de 1 (0,7 à 1,15).
function DecorMotion.flicker(t: number, seed: number): number
	local v = math.sin(t * 13.1 + seed * 1.7) * 0.07
		+ math.sin(t * 7.3 + seed * 3.1) * 0.06
		+ math.sin(t * 23.7 + seed) * 0.04
	return math.clamp(0.95 + v, 0.7, 1.15)
end

-- Pulsation lente d'un cristal : 0,6 à 1.
function DecorMotion.pulse(t: number, seed: number): number
	return 0.8 + 0.2 * math.sin(t * 1.9 + seed * 2.3)
end

-- Angle (degrés) d'un rouage qui avance par crans ; `ratio` : sens et vitesse relative.
function DecorMotion.tick(t: number, ratio: number, seed: number): number
	local u = (t + seed * 0.37) / DecorMotion.TICK_PERIOD
	local n = math.floor(u)
	local frac = u - n
	local cycles = n // 4
	local r = n % 4 + 1
	local ease = math.clamp(frac / TICK_EASE, 0, 1)
	ease = ease * ease * (3 - 2 * ease)
	local steps = cycles * 2 + PREFIX[r] + PATTERN[r] * ease
	return steps * DecorMotion.TICK_STEP * ratio
end

-- Balancier qui oscille puis se fige (le temps accroche) : angle en degrés, ±14.
function DecorMotion.stutter(t: number, seed: number): number
	local cycle = 3.4
	local u = (t + seed) % cycle
	local swing = math.min(u, 2.4)
	local angle = 14 * math.sin(TAU * swing / 1.6)
	if u > 2.4 then
		-- figé : léger tremblement
		angle += 0.4 * math.sin(t * 41)
	end
	return angle
end

-- Cloche figée en pleine volée : tremble, avec un à-coup toutes les 5 s (degrés).
function DecorMotion.tremble(t: number, seed: number): number
	local base = 0.6 * math.sin(t * 37 + seed) + 0.3 * math.sin(t * 23)
	local u = (t + seed) % 5
	if u < 0.25 then
		base += 3 * math.sin(u / 0.25 * math.pi)
	end
	return base
end

-- Bannière au vent : balancement autour du mât (degrés).
function DecorMotion.sway(t: number, seed: number): number
	return 7 * math.sin(t * 1.3 + seed) + 2.5 * math.sin(t * 2.9 + seed * 2)
end

-- Angle selon le mode d'un pivot (« tick », « stutter », « tremble », « sway »).
function DecorMotion.angle(mode: string, t: number, ratio: number, seed: number): number
	if mode == "tick" then
		return DecorMotion.tick(t, ratio, seed)
	elseif mode == "stutter" then
		return DecorMotion.stutter(t, seed)
	elseif mode == "tremble" then
		return DecorMotion.tremble(t, seed)
	elseif mode == "sway" then
		return DecorMotion.sway(t, seed)
	end
	return 0
end

-- Position d'un éclat en orbite (repère local : x, y, z) ; i de 1 à count.
function DecorMotion.orbit(
	t: number,
	i: number,
	count: number,
	radius: number
): (number, number, number)
	local a = TAU * (i - 1) / count + t * 0.25
	local r = radius * (0.85 + 0.15 * math.sin(i * 1.7))
	local y = math.sin(t * 0.9 + i * 2.1) * radius * 0.12
	return math.cos(a) * r, y, math.sin(a) * r
end

-- Graine stable tirée d'une position (pour désynchroniser les effets voisins).
function DecorMotion.seed(x: number, y: number, z: number): number
	return (math.abs(x * 12.9898 + y * 78.233 + z * 37.719) % 100) / 10
end

return DecorMotion
