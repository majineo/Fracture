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
	local total = 0
	for _, e in t.entries do
		total += e.weight
	end
	local count = t.rolls[1] + math.floor(random() * (t.rolls[2] - t.rolls[1] + 1))
	local merged: { [string]: number } = {}
	local order: { string } = {}
	for _ = 1, count do
		local pick = random() * total
		for _, e in t.entries do
			pick -= e.weight
			if pick < 0 then
				local qty = e.min + math.floor(random() * (e.max - e.min + 1))
				if merged[e.id] == nil then
					merged[e.id] = 0
					table.insert(order, e.id)
				end
				merged[e.id] += qty
				break
			end
		end
	end
	local out = {}
	for _, id in order do
		table.insert(out, { id = id, qty = merged[id] })
	end
	return out
end

return LootTables
