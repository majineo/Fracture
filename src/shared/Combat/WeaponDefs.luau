--!strict
-- Catalogue des armes (GDD 03-combat §4). Le serveur lit ses statistiques ICI, jamais celles
-- envoyées par un client. Répliqué aux clients pour l'affichage et la prédiction.
-- Studio : ReplicatedStorage > Shared > Combat > WeaponDefs
--
-- v0.4.0 : équipement de base (pistolet de Fractureur, lame courte). Les autres armes
-- (fusil à répétition, arbalète lourde, épée longue) arrivent en v0.4.1.

export type WeaponKind = "Hitscan" | "Melee"

export type WeaponDef = {
	id: string,
	name: string,
	kind: WeaponKind,
	damage: number,
	-- Distance (studs) : dégâts pleins jusqu'à falloffStart, puis baisse linéaire jusqu'à
	-- falloffEnd où il reste minDamageRatio des dégâts.
	falloffStart: number,
	falloffEnd: number,
	minDamageRatio: number,
	range: number,
	fireRate: number, -- tirs (ou coups) par seconde
	magazine: number, -- 0 = pas de munitions (mêlée)
	reloadTime: number,
	spreadHip: number, -- dispersion en degrés, tir sans viser
	spreadAim: number, -- dispersion en degrés, en visée
	recoil: number, -- recul de caméra (degrés)
	-- Mêlée
	arcDegrees: number?, -- angle du cône de frappe
	heavyMultiplier: number?, -- dégâts de l'attaque chargée
	heavyChargeTime: number?,
}

local WeaponDefs: { [string]: WeaponDef } = {
	["weapon.fracture_pistol"] = {
		id = "weapon.fracture_pistol",
		name = "Pistolet de Fractureur",
		kind = "Hitscan",
		damage = 24,
		falloffStart = 35,
		falloffEnd = 90,
		minDamageRatio = 0.55,
		range = 250,
		fireRate = 5,
		magazine = 12,
		reloadTime = 1.4,
		spreadHip = 2.2,
		spreadAim = 0.35,
		recoil = 1.6,
	},
	["weapon.short_blade"] = {
		id = "weapon.short_blade",
		name = "Lame courte",
		kind = "Melee",
		damage = 30,
		falloffStart = 0,
		falloffEnd = 0,
		minDamageRatio = 1,
		range = 6.5,
		fireRate = 2.4,
		magazine = 0,
		reloadTime = 0,
		spreadHip = 0,
		spreadAim = 0,
		recoil = 0,
		arcDegrees = 75,
		heavyMultiplier = 1.8,
		heavyChargeTime = 0.6,
	},
}

for _, def in WeaponDefs do
	table.freeze(def)
end

return table.freeze(WeaponDefs)
