--!strict
-- Points d'extraction d'un Éclat (v0.6.0, GDD 02 §3). Module pur, calculé à partir de la graine
-- par le serveur et par les clients (rien n'est envoyé).
-- Studio : ReplicatedStorage > Shared > Eclat > ExtractionPlan
--
--   * 2 à 3 points secondaires, chacun ouvert pendant 90 s à un moment tiré entre la fin du
--     premier quart de la partie et le début de la Faille finale, sur une tuile qui tient
--     debout pendant toute sa fenêtre (et encore 20 s après) ; jamais sur un Bord d'apparition,
--     jamais deux sur la même tuile ;
--   * la Faille finale, au pied du Donjon, ouverte de la phase « Faille finale » à la fin.
-- Pour extraire, il faut rester HOLD secondes dans la zone sans subir de dégâts.

local EclatLayout = require("./EclatLayout")
local CollapseSchedule = require("./CollapseSchedule")

export type Point = {
	x: number,
	z: number,
	opensAt: number,
	closesAt: number,
	final: boolean,
}

local ExtractionPlan = {}

ExtractionPlan.HOLD = 8 -- secondes dans la zone, sans dégâts
ExtractionPlan.RADIUS = 7 -- rayon de la zone (studs)
ExtractionPlan.WINDOW = 90 -- durée d'ouverture d'un point secondaire (échelle 1)
ExtractionPlan.MARGIN = 20 -- la tuile doit tenir au moins ça après la fermeture

function ExtractionPlan.build(
	layout: EclatLayout.Layout,
	schedule: CollapseSchedule.Schedule
): { Point }
	local t = schedule.timing
	local scale = t.finish / CollapseSchedule.DEFAULT_TIMING.finish
	local window = math.max(ExtractionPlan.WINDOW * scale, ExtractionPlan.HOLD + 4)
	local margin = ExtractionPlan.MARGIN * scale
	local r = EclatLayout.rng(layout.seed * 11 + 5)
	-- Cité 7 × 7 (v0.11.0) : 3 ou 4 points secondaires (2 ou 3 dans la forteresse 5 × 5).
	local count = 3 + (if EclatLayout.nextFloat(r) < 0.5 then 1 else 0)
	local earliest = t.finish * 0.25
	local latest = t.finalRift - window
	local points: { Point } = {}
	local used: { [number]: boolean } = {}
	for _ = 1, count do
		-- Plusieurs essais : on cherche une tuile qui tient pendant la fenêtre tirée.
		for _ = 1, 40 do
			local opensAt = earliest + EclatLayout.nextFloat(r) * math.max(0, latest - earliest)
			local closesAt = opensAt + window
			local tile = layout.tiles[EclatLayout.nextInt(r, 1, #layout.tiles)]
			local index = EclatLayout.index(layout, tile.x, tile.z)
			if
				not tile.spawn
				and tile.kind ~= "Donjon"
				and not used[index]
				and CollapseSchedule.tileCollapseAt(schedule, tile.x, tile.z)
					>= closesAt + margin
			then
				used[index] = true
				table.insert(points, {
					x = tile.x,
					z = tile.z,
					opensAt = opensAt,
					closesAt = closesAt,
					final = false,
				})
				break
			end
		end
	end
	table.sort(points, function(a, b)
		return a.opensAt < b.opensAt
	end)
	local c = (layout.size - 1) / 2
	table.insert(points, { x = c, z = c, opensAt = t.finalRift, closesAt = t.finish, final = true })
	return points
end

function ExtractionPlan.isOpen(point: Point, elapsed: number): boolean
	return elapsed >= point.opensAt and elapsed < point.closesAt
end

-- Progression d'une extraction (pure) : `progress` monte de dt tant que le joueur est dans la
-- zone ouverte et n'a pas été touché ; elle retombe à 0 sinon.
function ExtractionPlan.step(progress: number, dt: number, inside: boolean, hurt: boolean): number
	if not inside or hurt then
		return 0
	end
	return progress + dt
end

return ExtractionPlan
