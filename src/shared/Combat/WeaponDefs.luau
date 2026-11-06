--!strict
-- Catalogue des armes (GDD 03-combat §4). Le serveur lit ses statistiques ICI, jamais celles
-- envoyées par un client. Répliqué aux clients pour l'affichage et la prédiction.
-- Studio : ReplicatedStorage > Shared > Combat > WeaponDefs
--
-- Emplacements : 1 = arme à feu (« Firearm »), 2 = arme de mêlée (« Melee »).
-- Équilibrage (GDD 03) : l'équipement de base doit rester viable ; les autres armes offrent
-- un autre style, pas une puissance écrasante.

export type WeaponKind = "Hitscan" | "Melee"
export type Slot = "Firearm" | "Melee"
export type Hold = "Pistol" | "LongGun" | "Blade" | "Greatsword"

export type WeaponDef = {
	id: string,
	name: string,
	kind: WeaponKind,
	slot: Slot,
	hold: Hold, -- posture des bras (animations)
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
	pierce: number?, -- cibles supplémentaires traversées (perforation)
	sound: string, -- nom du son de tir / de coup (Combat/CombatSounds)
	soundPitch: number?,
	-- Mêlée
	arcDegrees: number?, -- angle du cône de frappe
	heavyMultiplier: number?, -- dégâts de l'attaque chargée
	heavyChargeTime: number?,
	parryWindow: number?, -- durée de la parade (secondes)
	swingTime: number?, -- durée visuelle d'un coup simple
}

local WeaponDefs: { [string]: WeaponDef } = {
	-- Équipement de base -----------------------------------------------------------------
	["weapon.fracture_pistol"] = {
		id = "weapon.fracture_pistol",
		name = "Pistolet de Fractureur",
		kind = "Hitscan",
		slot = "Firearm",
		hold = "Pistol",
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
		sound = "PistolShot",
	},
	["weapon.short_blade"] = {
		id = "weapon.short_blade",
		name = "Lame courte",
		kind = "Melee",
		slot = "Melee",
		hold = "Blade",
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
		sound = "Swing",
		arcDegrees = 75,
		heavyMultiplier = 1.8,
		heavyChargeTime = 0.6,
		parryWindow = 0.22,
		swingTime = 0.2,
	},

	-- Armes de l'Arsenal (v0.4.3) --------------------------------------------------------
	-- Fusil à répétition : peu de coups, très précis en visée, punit à longue distance.
	["weapon.repeating_rifle"] = {
		id = "weapon.repeating_rifle",
		name = "Fusil à répétition",
		kind = "Hitscan",
		slot = "Firearm",
		hold = "LongGun",
		damage = 48,
		falloffStart = 80,
		falloffEnd = 220,
		minDamageRatio = 0.7,
		range = 350,
		fireRate = 1.5,
		magazine = 6,
		reloadTime = 2.4,
		spreadHip = 3.5,
		spreadAim = 0.12,
		recoil = 4,
		sound = "PistolShot",
		soundPitch = 0.72,
	},
	-- Arbalète lourde : un carreau, gros dégâts, traverse une première cible.
	["weapon.heavy_crossbow"] = {
		id = "weapon.heavy_crossbow",
		name = "Arbalète lourde",
		kind = "Hitscan",
		slot = "Firearm",
		hold = "LongGun",
		damage = 75,
		falloffStart = 60,
		falloffEnd = 150,
		minDamageRatio = 0.6,
		range = 250,
		fireRate = 0.55,
		magazine = 1,
		reloadTime = 1.9,
		spreadHip = 1.5,
		spreadAim = 0.2,
		recoil = 2.5,
		pierce = 1,
		sound = "CrossbowShot",
	},
	-- Épée longue : coups amples et lents, longue portée de mêlée, parade généreuse.
	["weapon.longsword"] = {
		id = "weapon.longsword",
		name = "Épée longue",
		kind = "Melee",
		slot = "Melee",
		hold = "Greatsword",
		damage = 42,
		falloffStart = 0,
		falloffEnd = 0,
		minDamageRatio = 1,
		range = 8.5,
		fireRate = 1.5,
		magazine = 0,
		reloadTime = 0,
		spreadHip = 0,
		spreadAim = 0,
		recoil = 0,
		sound = "HeavySwing",
		soundPitch = 0.9,
		arcDegrees = 100,
		heavyMultiplier = 2.0,
		heavyChargeTime = 0.8,
		parryWindow = 0.3,
		swingTime = 0.3,
	},
}

for _, def in WeaponDefs do
	table.freeze(def)
end

return table.freeze(WeaponDefs)
