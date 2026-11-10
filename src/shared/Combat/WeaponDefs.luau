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
export type Hold = "Pistol" | "LongGun" | "Blade" | "Greatsword" | "Fists"

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
	pellets: number?, -- plombs par tir (tromblon, v0.10.0) : `damage` est PAR plomb
	pelletSpread: number?, -- rayon de la gerbe (degrés)
	automatic: boolean?, -- tir continu tant que la détente est maintenue (v0.10.0)
	sound: string, -- nom du son de tir / de coup (Combat/CombatSounds)
	soundPitch: number?,
	-- Sons (v0.4.14) : noms de Combat/CombatSounds. Absents = sons génériques.
	drawSound: string?, -- arme dégainée (apparaît dans la main)
	reloadSound: string?,
	impactSound: string?, -- balle / carreau qui touche le décor
	cycleSounds: { { sound: string, delay: number } }?, -- mécanisme après le tir (levier, culasse)
	-- Mêlée
	arcDegrees: number?, -- angle du cône de frappe
	heavyMultiplier: number?, -- dégâts de l'attaque chargée
	heavyChargeTime: number?,
	parryWindow: number?, -- durée de la parade (secondes)
	swingTime: number?, -- durée visuelle d'un coup simple
	-- Capacités (v0.4.5, Combat/Ability)
	ability: string?, -- capacité active (touche Q / bouton « Capacité »)
	ability2: string?, -- seconde capacité (appui long sur Q, ou maintien de la parade)
	passive: string?, -- trait passif
	scopeFov: number?, -- lunette : champ de vision en visée (degrés)
}

local WeaponDefs: { [string]: WeaponDef } = {
	-- Fusil du Zénith (v0.4.12) : sniper. Énormes dégâts à longue distance, lunette, très
	-- imprécis sans viser. Capacité : Rayon du Zénith (frappe annoncée par des cercles runiques).
	["weapon.zenith_rifle"] = {
		id = "weapon.zenith_rifle",
		name = "Fusil du Zénith",
		kind = "Hitscan",
		slot = "Firearm",
		hold = "LongGun",
		damage = 82,
		falloffStart = 140,
		falloffEnd = 320,
		minDamageRatio = 0.8,
		range = 500,
		fireRate = 0.6,
		magazine = 4,
		reloadTime = 2.8,
		spreadHip = 7,
		spreadAim = 0.04,
		recoil = 4.5,
		sound = "SniperShot",
		drawSound = "DrawRifle",
		reloadSound = "RifleReload",
		cycleSounds = {
			{ sound = "SniperBoltBack", delay = 0.55 },
			{ sound = "SniperBoltForward", delay = 0.85 },
		},
		ability = "ZenithBeam",
		passive = "ScopeFocus",
		scopeFov = 22,
	},

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
		drawSound = "DrawGun",
		reloadSound = "PistolReload",
		ability = "Rewind",
		passive = "ReloadOnKill",
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
		drawSound = "DrawBlade",
		arcDegrees = 75,
		heavyMultiplier = 1.8,
		heavyChargeTime = 0.6,
		parryWindow = 0.22,
		swingTime = 0.2,
		ability = "ShadowStep",
		passive = "Riposte",
	},

	-- Poings nus (v0.12.1) : arme implicite mains nues, jamais placée dans la charge.
	-- Clic gauche = coup de poing rapide, courte portée, faible dégât.
	["weapon.poing"] = {
		id = "weapon.poing",
		name = "Poings nus",
		kind = "Melee",
		slot = "Melee",
		hold = "Fists", -- pas de modèle tenu : bras animés par Animation/PunchMotion
		damage = 14,
		falloffStart = 0,
		falloffEnd = 0,
		minDamageRatio = 1,
		range = 4,
		fireRate = 2.8,
		magazine = 0,
		reloadTime = 0,
		spreadHip = 0,
		spreadAim = 0,
		recoil = 0,
		sound = "Swing",
		soundPitch = 0.85,
		arcDegrees = 60,
		heavyMultiplier = 1.5,
		heavyChargeTime = 0.45,
		parryWindow = 0.15,
		swingTime = 0.16,
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
		sound = "RifleShot",
		drawSound = "DrawRifle",
		reloadSound = "RifleReload",
		cycleSounds = { { sound = "RifleLever", delay = 0.22 } },
		ability = "Volley",
		ability2 = "Ricochet",
		passive = "Steady",
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
		drawSound = "DrawCrossbow",
		reloadSound = "CrossbowReload",
		impactSound = "CrossbowImpact",
		ability = "Stasis",
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
		drawSound = "DrawSword",
		arcDegrees = 100,
		heavyMultiplier = 2.0,
		heavyChargeTime = 0.8,
		parryWindow = 0.3,
		swingTime = 0.3,
		ability = "FractureWave",
		ability2 = "TimeGuard",
	},
}

-- Arsenal de la Fracture (v0.10.0) ------------------------------------------------------
-- Tromblon à vapeur : gerbe de plombs dévastatrice de près, inutile de loin. Sa capacité
-- repousse tout devant soi… et propulse son porteur en arrière (mobilité en l'air).
WeaponDefs["weapon.steam_blunderbuss"] = {
	id = "weapon.steam_blunderbuss",
	name = "Tromblon à vapeur",
	kind = "Hitscan",
	slot = "Firearm",
	hold = "LongGun",
	damage = 11, -- par plomb (8 plombs : 88 au contact)
	falloffStart = 8,
	falloffEnd = 30,
	minDamageRatio = 0.2,
	range = 60,
	fireRate = 1.1,
	magazine = 2,
	reloadTime = 2.2,
	spreadHip = 1.5,
	spreadAim = 1,
	recoil = 6,
	pellets = 8,
	pelletSpread = 5.5,
	sound = "BlunderbussShot",
	drawSound = "DrawRifle",
	reloadSound = "RifleReload",
	ability = "SteamBlast",
}
-- Mitrailleuse à manivelle : tir continu, faibles dégâts par balle, gros chargeur. Capacité :
-- Surchauffe (cadence ×1,8 sans consommer de munitions pendant 4 s).
WeaponDefs["weapon.crank_gatling"] = {
	id = "weapon.crank_gatling",
	name = "Mitrailleuse à manivelle",
	kind = "Hitscan",
	slot = "Firearm",
	hold = "LongGun",
	damage = 12,
	falloffStart = 30,
	falloffEnd = 110,
	minDamageRatio = 0.5,
	range = 220,
	fireRate = 9,
	magazine = 45,
	reloadTime = 3.2,
	spreadHip = 4,
	spreadAim = 1.4,
	recoil = 0.55,
	automatic = true,
	sound = "GatlingShot",
	soundPitch = 1.05,
	drawSound = "DrawRifle",
	reloadSound = "RifleReload",
	ability = "Overdrive",
}
-- Marteau-piston : lent et lourd, gros coups chargés. Capacité : Frappe sismique (onde
-- circulaire qui soulève et étourdit).
WeaponDefs["weapon.piston_hammer"] = {
	id = "weapon.piston_hammer",
	name = "Marteau-piston",
	kind = "Melee",
	slot = "Melee",
	hold = "Greatsword",
	damage = 50,
	falloffStart = 0,
	falloffEnd = 0,
	minDamageRatio = 1,
	range = 7.5,
	fireRate = 1.1,
	magazine = 0,
	reloadTime = 0,
	spreadHip = 0,
	spreadAim = 0,
	recoil = 0,
	sound = "HeavySwing",
	soundPitch = 0.75,
	drawSound = "DrawSword",
	arcDegrees = 80,
	heavyMultiplier = 2.2,
	heavyChargeTime = 0.9,
	parryWindow = 0.25,
	swingTime = 0.34,
	ability = "Quake",
}
-- Faux du Temps : grande allonge et coups larges. Capacité : Moisson (tourbillon à 360° qui
-- rend une partie des dégâts en santé).
WeaponDefs["weapon.time_scythe"] = {
	id = "weapon.time_scythe",
	name = "Faux du Temps",
	kind = "Melee",
	slot = "Melee",
	hold = "Greatsword",
	damage = 36,
	falloffStart = 0,
	falloffEnd = 0,
	minDamageRatio = 1,
	range = 9.5,
	fireRate = 1.6,
	magazine = 0,
	reloadTime = 0,
	spreadHip = 0,
	spreadAim = 0,
	recoil = 0,
	sound = "HeavySwing",
	soundPitch = 1.15,
	drawSound = "DrawSword",
	arcDegrees = 140,
	heavyMultiplier = 1.8,
	heavyChargeTime = 0.7,
	parryWindow = 0.22,
	swingTime = 0.28,
	ability = "Reap",
}

for _, def in WeaponDefs do
	table.freeze(def)
end

return table.freeze(WeaponDefs)
