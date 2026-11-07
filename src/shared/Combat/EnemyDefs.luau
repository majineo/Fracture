--!strict
-- Catalogue des ennemis (GDD 07). Le serveur fait foi ; le client lit les noms et les durées
-- de signal (préparation d'attaque, visée) pour l'affichage.
-- Studio : ReplicatedStorage > Shared > Combat > EnemyDefs
--
-- Règle de lisibilité (GDD 07 §1) : chaque attaque est annoncée avant de partir
-- (lame levée qui s'illumine pour la mêlée, trait rouge pour les tirs).

export type Behavior = "Melee" | "Ranged" | "Boss" -- Boss : piloté par son propre service

export type EnemyDef = {
	id: string,
	name: string,
	behavior: Behavior,
	health: number,
	armor: number,
	walkSpeed: number,
	chaseSpeed: number,
	aggroRange: number, -- repère un joueur à cette distance (avec ligne de vue)
	leashRange: number, -- abandonne au-delà et rentre à son poste
	attackRange: number, -- déclenche une attaque à cette distance
	keepDistance: number?, -- tireurs : recule si on s'approche trop
	windup: number, -- préparation (mêlée) ou visée (tir), en secondes
	cooldown: number,
	damage: number,
	strikeRange: number?, -- mêlée : portée réelle du coup (un peu plus que attackRange)
	arcDegrees: number?,
	spreadDegrees: number?, -- tir : dispersion
	aimLag: number?, -- tir : vise la position du joueur d'il y a aimLag s (on peut esquiver)
	weaponModel: string, -- modèle tenu (ServerStorage > WeaponModels)
	outfit: string, -- équipement (ServerStorage > EnemyOutfits), modélisé dans Blender
}

local EnemyDefs: { [string]: EnemyDef } = {
	["enemy.man_at_arms"] = {
		id = "enemy.man_at_arms",
		name = "Homme d'armes figé",
		behavior = "Melee",
		health = 120,
		armor = 0,
		walkSpeed = 8,
		chaseSpeed = 13,
		aggroRange = 55,
		leashRange = 90,
		attackRange = 6,
		windup = 0.6,
		cooldown = 1.5,
		damage = 22,
		strikeRange = 7.5,
		arcDegrees = 90,
		weaponModel = "enemy.rusty_sword",
		outfit = "Homme_Armes_Equipement",
	},
	["enemy.crossbowman"] = {
		id = "enemy.crossbowman",
		name = "Arbalétrier figé",
		behavior = "Ranged",
		health = 80,
		armor = 0,
		walkSpeed = 7,
		chaseSpeed = 11,
		aggroRange = 80,
		leashRange = 110,
		attackRange = 85,
		keepDistance = 16,
		windup = 1.1,
		cooldown = 2.8,
		damage = 28,
		spreadDegrees = 1.2,
		aimLag = 0.3,
		weaponModel = "weapon.heavy_crossbow",
		outfit = "Arbaletrier_Equipement",
	},
	-- Le Gardien, le Roi Sans Heure (v0.8.0, GDD 07 §3) : piloté par GuardianService (Éclat),
	-- cerveau dans Shared/Combat/GuardianBrain. Taille ×3, santé adaptée au nombre de joueurs.
	["enemy.guardian"] = {
		id = "enemy.guardian",
		name = "Le Roi Sans Heure",
		behavior = "Boss",
		health = 1500,
		armor = 0,
		walkSpeed = 12,
		chaseSpeed = 15,
		aggroRange = 90,
		leashRange = 140,
		attackRange = 13,
		windup = 0.9,
		cooldown = 2.2,
		damage = 35,
		strikeRange = 15,
		arcDegrees = 140,
		weaponModel = "weapon.longsword",
		outfit = "Guardian",
	},
}

for _, def in EnemyDefs do
	table.freeze(def)
end

return table.freeze(EnemyDefs)
