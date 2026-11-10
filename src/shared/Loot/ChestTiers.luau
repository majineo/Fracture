--!strict
-- Raretés des coffres (Update 2.0, phase 5) : moins de conteneurs, mais chacun compte. Module
-- pur (le hasard est fourni par le serveur) ; testé par tests/specs/ChestTiers.spec.luau.
-- Studio : ReplicatedStorage > Shared > Loot > ChestTiers
--
--   * Commun : coffre de bois simple            * Peu commun : coffre renforcé de fer
--   * Rare : coffre décoré de laiton            * Épique : coffre gothique à cristaux
--   * Légendaire : reliquaire du Temps — au plus UN par carte
-- Les caisses (butin ordinaire) ne sont plus toutes posées : CRATE_KEEP d'entre elles.

local ChestTiers = {}

export type Tier = "Commun" | "Peu commun" | "Rare" | "Épique" | "Légendaire"

ChestTiers.ORDER =
	table.freeze({ "Commun", "Peu commun", "Rare", "Épique", "Légendaire" } :: { Tier })

-- Table de butin et suffixe du modèle Blender (« Fort_Coffre<Suffixe> ») de chaque rareté.
ChestTiers.TABLE = table.freeze({
	Commun = "CoffreCommun",
	["Peu commun"] = "CoffrePeuCommun",
	Rare = "CoffreRare",
	["Épique"] = "CoffreEpique",
	["Légendaire"] = "CoffreLegendaire",
} :: { [Tier]: string })
ChestTiers.MODEL = table.freeze({
	Commun = "Fort_CoffreCommun",
	["Peu commun"] = "Fort_CoffrePeuCommun",
	Rare = "Fort_CoffreRare",
	["Épique"] = "Fort_CoffreEpique",
	["Légendaire"] = "Fort_CoffreLegendaire",
} :: { [Tier]: string })

ChestTiers.CRATE_KEEP = 0.55 -- part des emplacements de caisse et de sac réellement garnis
ChestTiers.CHEST_KEEP = 0.7 -- part des emplacements de coffre garnis (chaque coffre compte)
ChestTiers.MAX_LEGENDARY = 1

-- Poids (Commun, Peu commun, Rare, Épique, Légendaire) selon le quartier : les lieux dangereux
-- ou difficiles d'accès (Donjon, Crypte, sommet des tours) cachent les meilleurs coffres.
local WEIGHTS: { [string]: { number } } = {
	Donjon = { 0, 15, 40, 33, 12 },
	Crypte = { 0, 15, 40, 35, 10 },
	TourGuet = { 10, 35, 40, 15, 0 },
	Remparts = { 25, 40, 28, 7, 0 },
	default = { 45, 33, 18, 4, 0 },
}

-- Rareté d'un coffre du quartier `district` ; `random()` renvoie un nombre dans [0, 1[.
function ChestTiers.pick(district: string, random: () -> number): Tier
	local weights = WEIGHTS[district] or WEIGHTS.default
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = random() * total
	for i, w in weights do
		roll -= w
		if roll < 0 then
			return ChestTiers.ORDER[i]
		end
	end
	return "Commun"
end

-- Plafonne les légendaires : au-delà de MAX_LEGENDARY, ils deviennent épiques (sur place).
function ChestTiers.limit(tiers: { Tier }): { Tier }
	local seen = 0
	for i, tier in tiers do
		if tier == "Légendaire" then
			seen += 1
			if seen > ChestTiers.MAX_LEGENDARY then
				tiers[i] = "Épique"
			end
		end
	end
	return tiers
end

-- Garde-t-on cet emplacement de caisse ou de sac ?
function ChestTiers.keepCrate(random: () -> number): boolean
	return random() < ChestTiers.CRATE_KEEP
end

-- Garde-t-on cet emplacement de coffre ?
function ChestTiers.keepChest(random: () -> number): boolean
	return random() < ChestTiers.CHEST_KEEP
end

return ChestTiers
