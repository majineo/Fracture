--!strict
-- Géométrie des touches en nombres purs (aucun type Roblox) : rayon contre sphère (tête) et
-- rayon contre boîte (corps), dans le repère local de la cible. Module pur : testé par
-- tests/specs/HitMath.spec.luau.
-- Studio : ReplicatedStorage > Shared > Combat > HitMath
--
-- Le serveur convertit le rayon dans le repère de la cible (CFrame:PointToObjectSpace…) puis
-- appelle ces fonctions. Elles renvoient la distance le long du rayon (direction unitaire),
-- ou nil si le rayon manque.

local HitMath = {}

-- Rayon (o + t·d, d unitaire, 0 ≤ t ≤ maxT) contre sphère (centre c, rayon r).
function HitMath.raySphere(
	ox: number,
	oy: number,
	oz: number,
	dx: number,
	dy: number,
	dz: number,
	cx: number,
	cy: number,
	cz: number,
	r: number,
	maxT: number
): number?
	local lx, ly, lz = ox - cx, oy - cy, oz - cz
	local b = lx * dx + ly * dy + lz * dz
	local c = lx * lx + ly * ly + lz * lz - r * r
	if c <= 0 then
		return 0 -- origine déjà dans la sphère
	end
	local disc = b * b - c
	if disc < 0 then
		return nil
	end
	local t = -b - math.sqrt(disc)
	if t < 0 or t > maxT then
		return nil
	end
	return t
end

-- Rayon contre boîte alignée centrée sur l'origine, de demi-tailles (hx, hy, hz).
function HitMath.rayBox(
	ox: number,
	oy: number,
	oz: number,
	dx: number,
	dy: number,
	dz: number,
	hx: number,
	hy: number,
	hz: number,
	maxT: number
): number?
	local tMin, tMax = 0, maxT
	local origin = { ox, oy, oz }
	local direction = { dx, dy, dz }
	local half = { hx, hy, hz }
	for axis = 1, 3 do
		local o, d, h = origin[axis], direction[axis], half[axis]
		if math.abs(d) < 1e-9 then
			if o < -h or o > h then
				return nil
			end
		else
			local t1 = (-h - o) / d
			local t2 = (h - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	return tMin
end

-- Angle (degrés) entre deux directions unitaires.
function HitMath.angleBetween(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number
): number
	local dot = math.clamp(ax * bx + ay * by + az * bz, -1, 1)
	return math.deg(math.acos(dot))
end

return table.freeze(HitMath)
