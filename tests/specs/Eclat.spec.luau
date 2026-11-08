local EclatLayout = require("../../src/shared/Eclat/EclatLayout")
local CollapseSchedule = require("../../src/shared/Eclat/CollapseSchedule")

local function signature(layout)
	local parts = {}
	for _, tile in layout.tiles do
		table.insert(parts, tile.kind .. tile.rotation)
	end
	local keys = {}
	for key in layout.edges do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		table.insert(parts, key .. "=" .. layout.edges[key])
	end
	return table.concat(parts, ";")
end

return function(T)
	T.suite("EclatLayout")

	T.test("même graine, même Éclat ; graines différentes, Éclats différents", function()
		T.equal(signature(EclatLayout.generate(42)), signature(EclatLayout.generate(42)))
		local distinct = 0
		local first = signature(EclatLayout.generate(1))
		for seed = 2, 20 do
			if signature(EclatLayout.generate(seed)) ~= first then
				distinct += 1
			end
		end
		T.equal(distinct, 19, "graines 2 à 20 toutes différentes de la graine 1")
	end)

	local SIZE = EclatLayout.SIZE
	local MID = (SIZE - 1) / 2
	local LAST = SIZE - 1

	T.test("Donjon au centre, 4 Bords d'apparition au milieu de chaque côté", function()
		for seed = 1, 200 do
			local layout = EclatLayout.generate(seed)
			T.equal(EclatLayout.tileAt(layout, MID, MID).kind, "Donjon")
			local spawns = EclatLayout.spawnTiles(layout)
			T.equal(#spawns, 4, "apparitions")
			for _, tile in spawns do
				T.equal(tile.kind, "Bord")
				T.equal(tile.ring, MID)
			end
		end
	end)

	T.test("les 8 types de tuiles sont présents, la Crypte une seule fois", function()
		for seed = 1, 200 do
			local counts = {}
			for _, tile in EclatLayout.generate(seed).tiles do
				counts[tile.kind] = (counts[tile.kind] or 0) + 1
			end
			for _, kind in
				{
					"Donjon",
					"CourArmes",
					"Remparts",
					"TourGuet",
					"Village",
					"PontLevis",
					"Crypte",
					"Bord",
				}
			do
				T.truthy(counts[kind], `{kind} présent (graine {seed})`)
			end
			T.equal(counts.Crypte, 1)
			T.equal(counts.Donjon, 1)
			T.equal(counts.Bord, 4)
		end
	end)

	T.test(
		"chaque bord partagé a au moins deux passages, le Donjon est muré, le tour est le Vide",
		function()
			for seed = 1, 200 do
				local layout = EclatLayout.generate(seed)
				local shared, void = 0, 0
				for z = 0, LAST do
					for x = 0, LAST do
						for _, dir in EclatLayout.DIRECTIONS do
							local o = EclatLayout.OFFSETS[dir]
							local neighbor = EclatLayout.tileAt(layout, x + o[1], z + o[2])
							local kind = EclatLayout.edge(layout, x, z, dir)
							if neighbor then
								shared += 1
								T.truthy(
									kind == "Open" or kind == "Gates" or kind == "Rampart",
									kind
								)
								local here = EclatLayout.tileAt(layout, x, z)
								if here.kind == "Donjon" or neighbor.kind == "Donjon" then
									T.truthy(kind ~= "Open", "Donjon muré")
								end
								-- Le bord vu des deux côtés est le même.
								local back = ({ N = "S", S = "N", E = "W", W = "E" })[dir]
								T.equal(EclatLayout.edge(layout, x + o[1], z + o[2], back), kind)
							else
								void += 1
								T.equal(kind, "Void")
							end
						end
					end
				end
				T.equal(shared, 4 * SIZE * (SIZE - 1), "bords partagés vus des deux côtés")
				T.equal(void, 4 * SIZE, "bords extérieurs")
			end
		end
	)

	T.test("conversion monde ↔ tuile", function()
		local layout = EclatLayout.generate(7)
		local cx, cz = EclatLayout.tileCenter(layout, MID, MID)
		T.equal(cx, 0)
		T.equal(cz, 0)
		local half = SIZE * EclatLayout.TILE / 2
		local x, z = EclatLayout.tileFromWorld(layout, -half + 1, half - 1)
		T.equal(x, 0)
		T.equal(z, LAST)
		local nx = EclatLayout.tileFromWorld(layout, half + 1, 0)
		T.equal(nx, nil, "hors de la grille")
	end)

	T.suite("CollapseSchedule")

	T.test("4 vagues d'un côté chacune de la couronne extérieure, le reste à la fin", function()
		for seed = 1, 100 do
			local layout = EclatLayout.generate(seed)
			local schedule = CollapseSchedule.build(layout)
			T.equal(#schedule.waves, 4)
			local perWave = {}
			for z = 0, LAST do
				for x = 0, LAST do
					local at = CollapseSchedule.tileCollapseAt(schedule, x, z)
					local tile = EclatLayout.tileAt(layout, x, z)
					if tile.ring == MID then
						perWave[at] = (perWave[at] or 0) + 1
						T.truthy(at < 720, "extérieur tombé avant la Faille")
					else
						T.equal(at, 960, "milieu et centre tombent à la fin")
					end
				end
			end
			for _, at in schedule.waves do
				T.equal(perWave[at], SIZE - 1, `vague à {at}`)
			end
		end
	end)

	T.test("phases, alerte 30 s avant, prochaine chute", function()
		local layout = EclatLayout.generate(3)
		local s = CollapseSchedule.build(layout)
		T.equal(CollapseSchedule.phase(s, 0), "Exploration")
		T.equal(CollapseSchedule.phase(s, 300), "Collapse")
		T.equal(CollapseSchedule.phase(s, 720), "FinalRift")
		T.equal(CollapseSchedule.phase(s, 960), "Ended")
		T.equal(CollapseSchedule.nextCollapse(s, 0), 300)
		T.equal(CollapseSchedule.nextCollapse(s, 300), 420)
		T.equal(CollapseSchedule.nextCollapse(s, 700), 960)
		T.equal(CollapseSchedule.nextCollapse(s, 960), nil)
		-- Une tuile de la première vague.
		for z = 0, LAST do
			for x = 0, LAST do
				if CollapseSchedule.tileCollapseAt(s, x, z) == 300 then
					T.equal(CollapseSchedule.tileState(s, x, z, 269), "Stable")
					T.equal(CollapseSchedule.tileState(s, x, z, 270), "Warning")
					T.equal(CollapseSchedule.tileState(s, x, z, 300), "Collapsed")
				end
			end
		end
		T.equal(
			CollapseSchedule.tileState(s, MID, MID, 959),
			"Warning",
			"Donjon en alerte juste avant la fin"
		)
	end)

	T.test("durées réduites pour les tests", function()
		local layout = EclatLayout.generate(3)
		local s = CollapseSchedule.build(layout, CollapseSchedule.scaled(0.1))
		T.equal(s.waves[1], 30)
		T.equal(s.timing.finish, 96)
	end)
end
