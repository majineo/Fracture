--!strict
-- Catalogue des objets de butin (v0.6.0, GDD 05 §1). Module pur.
-- Studio : ReplicatedStorage > Shared > Loot > ItemDefs
--
-- Les Grains sont un objet comme les autres pendant la partie (ils prennent un emplacement et se
-- perdent à la mort) ; à l'extraction, ils sont versés au solde du profil.

export type Rarity = "Commun" | "Rare" | "Épique"

export type ItemDef = {
	id: string,
	name: string,
	rarity: Rarity,
	maxStack: number,
	value: number, -- valeur indicative en Grains (équilibrage, revente future)
	heal: number?, -- consommable de soin : santé rendue (v0.6.3)
	useTime: number?, -- durée d'utilisation (secondes), interrompue par les dégâts
}

local GRAINS = "currency.grains"

local defs: { [string]: ItemDef } = {
	[GRAINS] = { id = GRAINS, name = "Grains", rarity = "Commun", maxStack = 500, value = 1 },
	["mat.iron"] = { id = "mat.iron", name = "Fer", rarity = "Commun", maxStack = 20, value = 4 },
	["mat.wood"] = { id = "mat.wood", name = "Bois", rarity = "Commun", maxStack = 20, value = 3 },
	["mat.leather"] = {
		id = "mat.leather",
		name = "Cuir",
		rarity = "Commun",
		maxStack = 20,
		value = 5,
	},
	["mat.ancient_steel"] = {
		id = "mat.ancient_steel",
		name = "Acier ancien",
		rarity = "Rare",
		maxStack = 10,
		value = 18,
	},
	["mat.rift_stone"] = {
		id = "mat.rift_stone",
		name = "Pierre de Faille",
		rarity = "Épique",
		maxStack = 5,
		value = 60,
	},
	["cons.bandage"] = {
		id = "cons.bandage",
		name = "Bandage",
		rarity = "Commun",
		maxStack = 5,
		value = 8,
		heal = 30,
		useTime = 2.5,
	},
}

local ItemDefs = {}

ItemDefs.GRAINS = GRAINS
ItemDefs.ALL = table.freeze(defs)

function ItemDefs.get(id: string): ItemDef?
	return defs[id]
end

-- Couleur d'affichage selon la rareté (interface).
ItemDefs.RARITY_COLORS = table.freeze({
	["Commun"] = { 200, 200, 200 },
	["Rare"] = { 80, 170, 255 },
	["Épique"] = { 190, 110, 255 },
})

return ItemDefs
