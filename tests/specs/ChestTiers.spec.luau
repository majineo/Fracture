local ChestTiers = require("../../src/shared/Loot/ChestTiers")
local LootTables = require("../../src/shared/Loot/LootTables")
local ItemDefs = require("../../src/shared/Loot/ItemDefs")
local WeaponDefs = require("../../src/shared/Combat/WeaponDefs")

local function seeded(seed: number)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return function(T)
	T.suite("ChestTiers (coffres par rareté)")

	T.test("chaque rareté a sa table de butin et son modèle", function()
		for _, tier in ChestTiers.ORDER do
			T.truthy(LootTables.TABLES[ChestTiers.TABLE[tier]] ~= nil, tier)
			T.truthy(ChestTiers.MODEL[tier] ~= nil, tier)
		end
	end)

	T.test("les coffres ordinaires sont surtout communs, le Donjon cache les meilleurs", function()
		local random = seeded(7)
		local common, legendary, donjonRich = 0, 0, 0
		for _ = 1, 2000 do
			local t = ChestTiers.pick("Village", random)
			if t == "Commun" then
				common += 1
			end
			if t == "Légendaire" then
				legendary += 1
			end
			local d = ChestTiers.pick("Donjon", random)
			if d == "Rare" or d == "Épique" or d == "Légendaire" then
				donjonRich += 1
			end
		end
		T.truthy(common > 700, `communs au village : {common}`)
		T.equal(legendary, 0, "pas de légendaire hors des lieux dangereux")
		T.truthy(donjonRich > 1400, `coffres riches au Donjon : {donjonRich}`)
	end)

	T.test("au plus un légendaire par carte", function()
		local tiers = ChestTiers.limit({ "Légendaire", "Rare", "Légendaire", "Légendaire" })
		local count = 0
		for _, t in tiers do
			if t == "Légendaire" then
				count += 1
			end
		end
		T.equal(count, 1)
		T.equal(tiers[3], "Épique", "rétrogradé")
	end)

	T.test("moins de caisses : environ 55 % gardées", function()
		local random = seeded(3)
		local kept = 0
		for _ = 1, 4000 do
			if ChestTiers.keepCrate(random) then
				kept += 1
			end
		end
		T.truthy(kept > 2000 and kept < 2400, `gardées : {kept}`)
	end)

	T.test("coffres : environ 70 % des emplacements garnis", function()
		local random = seeded(9)
		local kept = 0
		for _ = 1, 4000 do
			if ChestTiers.keepChest(random) then
				kept += 1
			end
		end
		T.truthy(kept > 2650 and kept < 2950, `gardés : {kept}`)
	end)

	T.test("aucun doublon dans un coffre ; les armes trouvées sont de vraies armes", function()
		local random = seeded(11)
		for _ = 1, 400 do
			for _, tier in ChestTiers.ORDER do
				local seen = {}
				for _, drop in LootTables.roll(ChestTiers.TABLE[tier], random) do
					T.truthy(not seen[drop.id], `doublon {drop.id} ({tier})`)
					seen[drop.id] = true
					local def = ItemDefs.get(drop.id)
					T.truthy(def ~= nil, drop.id)
					if def and def.weapon then
						T.truthy(WeaponDefs[def.weapon] ~= nil, def.weapon)
						T.equal(drop.qty, 1, "une arme à la fois")
					end
				end
			end
		end
	end)

	T.test("le légendaire contient presque toujours le Fusil du Zénith", function()
		local random = seeded(21)
		local zenith = 0
		for _ = 1, 500 do
			for _, drop in LootTables.roll("CoffreLegendaire", random) do
				if drop.id == "weapon.zenith_rifle" then
					zenith += 1
				end
			end
		end
		T.truthy(zenith > 400, `Zénith : {zenith}/500`)
	end)

	T.test("pas d'arme garantie dans un coffre commun", function()
		local random = seeded(4)
		local withWeapon = 0
		for _ = 1, 1000 do
			for _, drop in LootTables.roll("CoffreCommun", random) do
				local def = ItemDefs.get(drop.id)
				if def and def.weapon then
					withWeapon += 1
				end
			end
		end
		T.truthy(withWeapon < 300, `coffres communs avec arme : {withWeapon}/1000`)
	end)
end
