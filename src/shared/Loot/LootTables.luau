--!strict
-- Tables de butin (v0.6.0, GDD 02 §4). Module pur : le tirage reçoit sa source de hasard, ce qui
-- le rend testable ; le serveur seul tire (le client ne voit que le résultat).
-- Studio : ReplicatedStorage > Shared > Loot > LootTables

export type Entry = { id: string, weight: number, min: number, max: number }
export type Table = { rolls: { number }, chance: number?, entries: { Entry } }
export type Drop = { id: string, qty: number }

local TABLES: { [string]: Table } = {
	-- Caisse : cours, villages, remparts.
	Caisse = {
		rolls = { 1, 2 },
		entries = {
			{ id = "mat.wood", weight = 30, min = 2, max = 5 },
			{ id = "mat.iron", weight = 25, min = 1, max = 4 },
			{ id = "mat.leather", weight = 20, min = 1, max = 3 },
			{ id = "currency.grains", weight = 20, min = 8, max = 25 },
			{ id = "cons.bandage", weight = 5, min = 1, max = 1 },
		},
	},
	-- Coffre : crypte, sommet des tours, donjon.
	Coffre = {
		rolls = { 2, 3 },
		entries = {
			{ id = "currency.grains", weight = 30, min = 20, max = 60 },
			{ id = "mat.iron", weight = 20, min = 3, max = 6 },
			{ id = "mat.ancient_steel", weight = 25, min = 1, max = 3 },
			{ id = "mat.leather", weight = 10, min = 2, max = 4 },
			{ id = "mat.rift_stone", weight = 10, min = 1, max = 1 },
			{ id = "cons.bandage", weight = 5, min = 1, max = 2 },
		},
	},
	-- Coffres par rareté (Update 2.0, phase 5) : plus le coffre est rare, plus il donne et plus
	-- l'arme est probable et puissante. Jamais d'arme garantie avant l'épique.
	CoffreCommun = {
		rolls = { 2, 2 },
		entries = {
			{ id = "currency.grains", weight = 40, min = 15, max = 35 },
			{ id = "mat.iron", weight = 25, min = 2, max = 4 },
			{ id = "mat.leather", weight = 15, min = 1, max = 3 },
			{ id = "cons.bandage", weight = 12, min = 1, max = 1 },
			{ id = "weapon.fracture_pistol", weight = 4, min = 1, max = 1 },
			{ id = "weapon.short_blade", weight = 4, min = 1, max = 1 },
		},
	},
	CoffrePeuCommun = {
		rolls = { 2, 3 },
		entries = {
			{ id = "currency.grains", weight = 35, min = 30, max = 60 },
			{ id = "mat.ancient_steel", weight = 20, min = 1, max = 2 },
			{ id = "cons.bandage", weight = 15, min = 1, max = 2 },
			{ id = "mat.iron", weight = 15, min = 3, max = 5 },
			{ id = "weapon.repeating_rifle", weight = 7, min = 1, max = 1 },
			{ id = "weapon.heavy_crossbow", weight = 7, min = 1, max = 1 },
			{ id = "weapon.fracture_pistol", weight = 3, min = 1, max = 1 },
		},
	},
	CoffreRare = {
		rolls = { 3, 3 },
		entries = {
			{ id = "currency.grains", weight = 30, min = 50, max = 90 },
			{ id = "mat.ancient_steel", weight = 22, min = 2, max = 3 },
			{ id = "cons.bandage", weight = 14, min = 2, max = 2 },
			{ id = "mat.rift_stone", weight = 10, min = 1, max = 1 },
			{ id = "weapon.longsword", weight = 8, min = 1, max = 1 },
			{ id = "weapon.steam_blunderbuss", weight = 8, min = 1, max = 1 },
			{ id = "weapon.piston_hammer", weight = 8, min = 1, max = 1 },
		},
	},
	CoffreEpique = {
		rolls = { 3, 4 },
		entries = {
			{ id = "currency.grains", weight = 28, min = 80, max = 140 },
			{ id = "mat.rift_stone", weight = 20, min = 1, max = 2 },
			{ id = "mat.ancient_steel", weight = 16, min = 2, max = 4 },
			{ id = "cons.bandage", weight = 10, min = 2, max = 3 },
			{ id = "weapon.crank_gatling", weight = 14, min = 1, max = 1 },
			{ id = "weapon.time_scythe", weight = 14, min = 1, max = 1 },
		},
	},
	CoffreLegendaire = {
		rolls = { 4, 4 },
		entries = {
			{ id = "weapon.zenith_rifle", weight = 60, min = 1, max = 1 },
			{ id = "currency.grains", weight = 30, min = 150, max = 250 },
			{ id = "mat.rift_stone", weight = 25, min = 2, max = 3 },
			{ id = "weapon.time_scythe", weight = 10, min = 1, max = 1 },
			{ id = "weapon.crank_gatling", weight = 10, min = 1, max = 1 },
			{ id = "cons.bandage", weight = 10, min = 3, max = 3 },
		},
	},
	-- Échoué brisé : petite chance de lâcher quelque chose.
	Echoue = {
		rolls = { 1, 1 },
		chance = 0.45,
		entries = {
			{ id = "currency.grains", weight = 40, min = 3, max = 10 },
			{ id = "mat.iron", weight = 35, min = 1, max = 2 },
			{ id = "mat.ancient_steel", weight = 15, min = 1, max = 1 },
			{ id = "mat.leather", weight = 10, min = 1, max = 2 },
		},
	},
}

local LootTables = {}

LootTables.TABLES = table.freeze(TABLES)

-- `random()` renvoie un nombre dans [0, 1[.
function LootTables.roll(name: string, random: () -> number): { Drop }
	local t = TABLES[name]
	if t == nil then
		return {}
	end
	if t.chance and random() >= t.chance then
		return {}
	end
	-- Sans remise (Update 2.0) : un même objet ne sort qu'une fois par conteneur, donc pas de
	-- doublons inutiles (deux fois la même arme, trois tas de fer…).
	local left: { Entry } = table.clone(t.entries)
	local count = t.rolls[1] + math.floor(random() * (t.rolls[2] - t.rolls[1] + 1))
	local out = {}
	for _ = 1, count do
		local total = 0
		for _, e in left do
			total += e.weight
		end
		if total <= 0 then
			break
		end
		local pick = random() * total
		for i, e in left do
			pick -= e.weight
			if pick < 0 then
				local qty = e.min + math.floor(random() * (e.max - e.min + 1))
				table.insert(out, { id = e.id, qty = qty })
				table.remove(left, i)
				break
			end
		end
	end
	return out
end

return LootTables
