--!strict
-- Historique des positions d'une cible pour la compensation de latence. Module pur (nombres,
-- temps fourni) : testé par tests/specs/PositionHistory.spec.luau.
-- Studio : ServerScriptService > Server > Lib > PositionHistory
--
-- Le serveur enregistre à chaque image la position et l'orientation (angle horizontal) de la
-- racine de chaque cible. Quand un tir arrive, il « remonte le temps » jusqu'au moment où le
-- tireur a vu la scène, pour juger le tir sur ce que le tireur voyait réellement.

export type Sample = { t: number, x: number, y: number, z: number, yaw: number }

export type History = {
	samples: { Sample },
	duration: number,
}

local PositionHistory = {}

function PositionHistory.new(duration: number): History
	return { samples = {}, duration = duration }
end

function PositionHistory.record(
	history: History,
	t: number,
	x: number,
	y: number,
	z: number,
	yaw: number
)
	local samples = history.samples
	table.insert(samples, { t = t, x = x, y = y, z = z, yaw = yaw })
	while #samples > 2 and t - samples[1].t > history.duration do
		table.remove(samples, 1)
	end
end

local function lerpAngle(a: number, b: number, alpha: number): number
	local diff = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + diff * alpha
end

-- Position interpolée au temps t (bornée au plus ancien / plus récent échantillon).
-- Renvoie nil si l'historique est vide.
function PositionHistory.at(history: History, t: number): Sample?
	local samples = history.samples
	local count = #samples
	if count == 0 then
		return nil
	end
	if t <= samples[1].t then
		return samples[1]
	end
	if t >= samples[count].t then
		return samples[count]
	end
	-- Recherche du segment [i, i+1] qui contient t.
	for i = count - 1, 1, -1 do
		local a = samples[i]
		if a.t <= t then
			local b = samples[i + 1]
			local span = b.t - a.t
			local alpha = if span > 0 then (t - a.t) / span else 0
			return {
				t = t,
				x = a.x + (b.x - a.x) * alpha,
				y = a.y + (b.y - a.y) * alpha,
				z = a.z + (b.z - a.z) * alpha,
				yaw = lerpAngle(a.yaw, b.yaw, alpha),
			}
		end
	end
	return samples[1]
end

return table.freeze(PositionHistory)
