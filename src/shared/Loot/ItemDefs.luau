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
	unique: boolean?, -- jamais empilé (relique : la quantité est le nombre de charges)
	relic: boolean?, -- relique de l'Éclat (v0.7.0)
	description: string?, -- texte de la fiche d'objet (sac, coffre ; v0.9.0)
}

local GRAINS = "currency.grains"

local defs: { [string]: ItemDef } = {
	[GRAINS] = {
		id = GRAINS,
		name = "Grains",
		rarity = "Commun",
		maxStack = 500,
		value = 1,
		description = "Poussière de temps cristallisée, la monnaie du Refuge. Versée au solde à l'extraction, perdue à la mort.",
	},
	["mat.iron"] = {
		id = "mat.iron",
		name = "Fer",
		rarity = "Commun",
		maxStack = 20,
		value = 4,
		description = "Ferraille des engrenages de la ville. Sert à l'artisanat.",
	},
	["mat.wood"] = {
		id = "mat.wood",
		name = "Bois",
		rarity = "Commun",
		maxStack = 20,
		value = 3,
		description = "Planches et poutres de charpente. Sert à l'artisanat.",
	},
	["mat.leather"] = {
		id = "mat.leather",
		name = "Cuir",
		rarity = "Commun",
		maxStack = 20,
		value = 5,
		description = "Cuir tanné des sangles et des sacoches. Sert à l'artisanat.",
	},
	["mat.ancient_steel"] = {
		id = "mat.ancient_steel",
		name = "Acier ancien",
		rarity = "Rare",
		maxStack = 10,
		value = 18,
		description = "Acier forgé avant la Fracture. Nécessaire pour stabiliser une relique.",
	},
	["mat.rift_stone"] = {
		id = "mat.rift_stone",
		name = "Pierre de Faille",
		rarity = "Épique",
		maxStack = 5,
		value = 60,
		description = "Éclat de la Faille, encore tiède. Rare et précieux.",
	},
	["cons.bandage"] = {
		id = "cons.bandage",
		name = "Bandage",
		rarity = "Commun",
		maxStack = 5,
		value = 8,
		heal = 30,
		useTime = 2.5,
		description = "Rend 30 points de vie en 2,5 s. Un coup reçu interrompt le soin. Touche H.",
	},
	-- Reliques (v0.7.0, GDD 04 §2) : 3 charges, chacune l'abîme ; intacte, elle se stabilise au
	-- Refuge (Codex, à venir). Quantité = charges restantes.
	["relic.pas_de_faille"] = {
		id = "relic.pas_de_faille",
		name = "Pas de Faille",
		rarity = "Épique",
		maxStack = 3,
		value = 120,
		unique = true,
		relic = true,
		description = "Bond instantané vers l'avant, intouchable un court instant. 3 charges ; intacte, se stabilise au Refuge. Touche T.",
	},
	["relic.stase"] = {
		id = "relic.stase",
		name = "Stase",
		rarity = "Épique",
		maxStack = 3,
		value = 120,
		unique = true,
		relic = true,
		description = "Crée devant vous une bulle de temps figé qui ralentit tout, tirs compris. 3 charges. Touche T.",
	},
	["relic.onde_de_choc"] = {
		id = "relic.onde_de_choc",
		name = "Onde de choc",
		rarity = "Épique",
		maxStack = 3,
		value = 120,
		unique = true,
		relic = true,
		description = "Repousse, blesse et étourdit tout ce qui est à moins de 10 m. 3 charges. Touche T.",
	},
}

local ItemDefs = {}

ItemDefs.GRAINS = GRAINS
ItemDefs.RELICS = table.freeze({ "relic.pas_de_faille", "relic.stase", "relic.onde_de_choc" })
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
