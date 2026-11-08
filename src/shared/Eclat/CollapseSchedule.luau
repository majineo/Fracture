--!strict
-- Calendrier d'un Éclat (v0.5.0, GDD 02 §2) : phases de la partie et effondrement des tuiles.
-- Module pur : le serveur et les clients le calculent à partir de la même graine et de l'heure
-- de début de la partie (attribut répliqué) ; rien d'autre n'est envoyé.
-- Studio : ReplicatedStorage > Shared > Eclat > CollapseSchedule
--
--   0 – 5 min   Exploration
--   5 – 12 min  Effondrement : un côté de la couronne extérieure (4 tuiles) tombe toutes les
--               2 min, alerte 30 s avant ; l'ordre des côtés dépend de la graine
--   12 – 16 min Faille finale (le Gardien s'éveille, la Faille s'ouvre au pied du Donjon)
--   16 min      Fin : tout ce qui reste s'effondre, tout joueur encore présent meurt

-- Chemin relatif : fonctionne dans Roblox (frère du module) et dans les tests Lune.
local EclatLayout = require("./EclatLayout")

export type Phase = "Exploration" | "Collapse" | "FinalRift" | "Ended"
export type TileState = "Stable" | "Warning" | "Collapsed"

export type Timing = {
	exploration: number, -- début de la première vague
	waveInterval: number,
	warning: number, -- durée de l'alerte avant une chute
	finalRift: number,
	finish: number,
}

export type Schedule = {
	timing: Timing,
	collapseAt: { [number]: number }, -- index de tuile -> heure de chute (secondes de partie)
	waves: { number }, -- heures des vagues, dans l'ordre
	size: number,
}

local CollapseSchedule = {}

CollapseSchedule.DEFAULT_TIMING = table.freeze({
	exploration = 300,
	waveInterval = 120,
	warning = 30,
	finalRift = 720,
	finish = 960,
}) :: Timing

-- Toutes les durées multipliées par `factor` (tests rapides dans Studio).
function CollapseSchedule.scaled(factor: number): Timing
	local base = CollapseSchedule.DEFAULT_TIMING
	return {
		exploration = base.exploration * factor,
		waveInterval = base.waveInterval * factor,
		warning = base.warning * factor,
		finalRift = base.finalRift * factor,
		finish = base.finish * factor,
	}
end

function CollapseSchedule.build(layout: EclatLayout.Layout, timing: Timing?): Schedule
	local t = timing or CollapseSchedule.DEFAULT_TIMING
	-- Flux pseudo-aléatoire séparé de celui du plan (changer le plan ne change pas l'ordre).
	local r = EclatLayout.rng(layout.seed * 7 + 13)
	local sides = EclatLayout.outerSides(layout.size)
	local order = EclatLayout.shuffle(r, { 1, 2, 3, 4 })
	local schedule: Schedule = { timing = t, collapseAt = {}, waves = {}, size = layout.size }
	for wave, sideIndex in order do
		local at = t.exploration + (wave - 1) * t.waveInterval
		table.insert(schedule.waves, at)
		for _, cell in sides[sideIndex] do
			schedule.collapseAt[EclatLayout.index(layout, cell[1], cell[2])] = at
		end
	end
	-- Le reste tombe à la fin.
	for i = 1, layout.size * layout.size do
		if schedule.collapseAt[i] == nil then
			schedule.collapseAt[i] = t.finish
		end
	end
	return schedule
end

function CollapseSchedule.tileCollapseAt(schedule: Schedule, x: number, z: number): number
	return schedule.collapseAt[z * schedule.size + x + 1]
end

function CollapseSchedule.tileState(
	schedule: Schedule,
	x: number,
	z: number,
	elapsed: number
): TileState
	local at = CollapseSchedule.tileCollapseAt(schedule, x, z)
	if elapsed >= at then
		return "Collapsed"
	elseif elapsed >= at - schedule.timing.warning then
		return "Warning"
	end
	return "Stable"
end

function CollapseSchedule.phase(schedule: Schedule, elapsed: number): Phase
	local t = schedule.timing
	if elapsed >= t.finish then
		return "Ended"
	elseif elapsed >= t.finalRift then
		return "FinalRift"
	elseif elapsed >= t.exploration then
		return "Collapse"
	end
	return "Exploration"
end

-- Prochaine chute à venir (vague ou fin), nil s'il n'y en a plus.
function CollapseSchedule.nextCollapse(schedule: Schedule, elapsed: number): number?
	for _, at in schedule.waves do
		if at > elapsed then
			return at
		end
	end
	if schedule.timing.finish > elapsed then
		return schedule.timing.finish
	end
	return nil
end

return CollapseSchedule
