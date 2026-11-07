local RunInventory = require("../../src/shared/Loot/RunInventory")
local LootTables = require("../../src/shared/Loot/LootTables")
local ItemDefs = require("../../src/shared/Loot/ItemDefs")
local EclatLayout = require("../../src/shared/Eclat/EclatLayout")
local CollapseSchedule = require("../../src/shared/Eclat/CollapseSchedule")
local ExtractionPlan = require("../../src/shared/Eclat/ExtractionPlan")

local function seeded(seed)
	local r = EclatLayout.rng(seed)
	return function()
		return EclatLayout.nextFloat(r)
	end
end

return function(T)
	T.suite("RunInventory")

	T.test("piles : remplit d'abord les piles existantes, respecte la taille maximale", function()
		local inv = RunInventory.new()
		T.equal(RunInventory.add(inv, "mat.iron", 15), 15)
		T.equal(RunInventory.add(inv, "mat.iron", 10), 10)
		T.equal(#inv.stacks, 2, "20 + 5")
		T.equal(inv.stacks[1].qty, 20)
		T.equal(RunInventory.count(inv, "mat.iron"), 25)
	end)

	T.test("12 emplacements : le surplus ne rentre pas", function()
		local inv = RunInventory.new()
		T.equal(RunInventory.add(inv, "mat.rift_stone", 100), 60, "12 piles de 5")
		T.equal(#inv.stacks, 12)
		T.equal(RunInventory.add(inv, "mat.wood", 1), 0, "plein")
	end)

	T.test("objets inconnus, quantités invalides refusés", function()
		local inv = RunInventory.new()
		T.equal(RunInventory.add(inv, "weapon.nuke", 1), 0)
		T.equal(RunInventory.add(inv, "mat.iron", 0 / 0), 0, "NaN")
		T.equal(RunInventory.add(inv, "mat.iron", -3), 0)
		T.truthy(RunInventory.isEmpty(inv))
	end)

	T.test("prendre dans un conteneur : le reste y demeure", function()
		local inv = RunInventory.new(1)
		local contents = { { id = "mat.wood", qty = 25 }, { id = "mat.iron", qty = 2 } }
		local taken = RunInventory.takeFrom(inv, contents)
		T.equal(#taken, 1)
		T.equal(RunInventory.count(inv, "mat.iron") + RunInventory.count(inv, "mat.wood"), 20)
		T.truthy(#contents >= 1, "il reste quelque chose dans le conteneur")
	end)

	T.test("vider : regroupe par objet et laisse l'inventaire vide", function()
		local inv = RunInventory.new()
		RunInventory.add(inv, "mat.iron", 30)
		RunInventory.add(inv, ItemDefs.GRAINS, 40)
		local out = RunInventory.drain(inv)
		T.equal(#out, 2)
		T.equal(out[1].id, "mat.iron")
		T.equal(out[1].qty, 30)
		T.truthy(RunInventory.isEmpty(inv))
	end)

	T.test("reliques : jamais fusionnées, une charge à la fois, disparaissent à 0", function()
		local inv = RunInventory.new()
		T.equal(RunInventory.add(inv, "relic.stase", 3), 3)
		T.equal(RunInventory.add(inv, "relic.stase", 3), 3)
		T.equal(#inv.stacks, 2, "deux reliques, deux emplacements")
		local id, left = RunInventory.useCharge(inv, 1)
		T.equal(id, "relic.stase")
		T.equal(left, 2)
		RunInventory.useCharge(inv, 1)
		local _, last = RunInventory.useCharge(inv, 1)
		T.equal(last, 0)
		T.equal(#inv.stacks, 1, "la relique épuisée a disparu")
		T.equal(RunInventory.useCharge(inv, 5), nil, "emplacement vide")
		RunInventory.add(inv, "mat.iron", 3)
		T.equal(RunInventory.useCharge(inv, 2), nil, "pas une relique")
		T.equal(RunInventory.useCharge(inv, 1.5), nil, "index invalide")
		local out = RunInventory.drain(inv)
		T.equal(#out, 2, "fer + relique, chacun à part")
	end)

	T.suite("LootTables")

	T.test("tirages valides : objets connus, quantités dans les bornes", function()
		local random = seeded(99)
		for _ = 1, 300 do
			for _, name in { "Caisse", "Coffre", "Echoue" } do
				for _, drop in LootTables.roll(name, random) do
					T.truthy(ItemDefs.get(drop.id), drop.id)
					T.truthy(drop.qty >= 1, "quantité")
				end
			end
		end
	end)

	T.test("un Échoué ne lâche rien environ une fois sur deux", function()
		local random = seeded(5)
		local empty = 0
		for _ = 1, 1000 do
			if #LootTables.roll("Echoue", random) == 0 then
				empty += 1
			end
		end
		T.truthy(empty > 450 and empty < 650, `vides : {empty}`)
	end)

	T.suite("ExtractionPlan")

	T.test(
		"2 ou 3 points secondaires + la Faille finale, tuiles debout pendant la fenêtre",
		function()
			for seed = 1, 200 do
				local layout = EclatLayout.generate(seed)
				local schedule = CollapseSchedule.build(layout)
				local points = ExtractionPlan.build(layout, schedule)
				local final = points[#points]
				T.truthy(final.final, "la dernière est la Faille")
				T.equal(final.x, 2)
				T.equal(final.opensAt, 720)
				local secondary = #points - 1
				T.truthy(secondary >= 2 and secondary <= 3, `secondaires : {secondary}`)
				local seen = {}
				for i = 1, secondary do
					local p = points[i]
					local tile = EclatLayout.tileAt(layout, p.x, p.z)
					T.falsy(tile.spawn, "pas sur une apparition")
					T.truthy(p.closesAt - p.opensAt == 90, "fenêtre de 90 s")
					T.truthy(p.closesAt <= 720, "fermé avant la Faille")
					T.truthy(
						CollapseSchedule.tileCollapseAt(schedule, p.x, p.z) >= p.closesAt + 20,
						"tuile debout"
					)
					local key = p.x .. "," .. p.z
					T.falsy(seen[key], "un point par tuile")
					seen[key] = true
				end
			end
		end
	)

	T.test("progression : il faut rester sans être touché", function()
		local p = 0
		for _ = 1, 7 do
			p = ExtractionPlan.step(p, 1, true, false)
		end
		T.equal(p, 7)
		T.equal(ExtractionPlan.step(p, 1, true, true), 0, "touché : on recommence")
		T.equal(ExtractionPlan.step(p, 1, false, false), 0, "sorti de la zone")
	end)
end
