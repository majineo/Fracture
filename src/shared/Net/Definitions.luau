--!strict
-- Liste UNIQUE de tous les remotes du jeu.
-- Studio : ReplicatedStorage > Shared > Net > Definitions
--
-- Ajouter un remote = ajouter une ligne ici. Le serveur crée tous les remotes au démarrage
-- dans ReplicatedStorage > Remotes ; le client ne crée jamais de remote.
--
-- direction : "ToServer" (le client demande) ou "ToClient" (le serveur informe).
-- rate / burst : limite de fréquence par joueur pour les remotes ToServer
--   (rate = requêtes par seconde rechargées, burst = réserve maximale).

export type Direction = "ToServer" | "ToClient"

export type RemoteDef = {
	direction: Direction,
	rate: number?,
	burst: number?,
}

export type RemoteName =
	"ClientReady"
	| "ProfileSnapshot"
	| "GrappleStart"
	| "GrappleEnd"
	| "GrappleState"
	| "DevCommand"
	| "MovementMode"
	| "EquipWeapon"
	| "FireWeapon"
	| "ReloadWeapon"
	| "MeleeSwing"
	| "WeaponState"
	| "CombatEvent"
	| "ShotFx"
	| "Parry"
	| "UseAbility"
	| "InventoryState"
	| "LootEvent"
	| "ExtractionResult"
	| "RequestRedeploy"
	| "Notice"

local Definitions: { [string]: RemoteDef } = {
	-- Le client signale qu'il est prêt à recevoir son état (demande un instantané du profil).
	ClientReady = { direction = "ToServer", rate = 0.5, burst = 3 },
	-- Le serveur envoie au joueur la vue publique de son profil.
	ProfileSnapshot = { direction = "ToClient" },

	-- Grappin : le client annonce sa cible (Vector3) ; le serveur vérifie portée, recharge et
	-- ligne de vue avant d'autoriser la vitesse correspondante.
	GrappleStart = { direction = "ToServer", rate = 1, burst = 2 },
	GrappleEnd = { direction = "ToServer", rate = 2, burst = 3 },
	-- Le serveur informe tous les clients d'un grappin (joueur, cible ou nil) pour la corde.
	GrappleState = { direction = "ToClient" },

	-- Mode de déplacement du joueur ("Normal", "Slide", "Mantle", "Grapple") : purement visuel,
	-- recopié par le serveur dans l'attribut "MoveMode" du personnage pour que tous les clients
	-- jouent la bonne animation. Ne donne aucun droit (la garde de mouvement reste seule juge).
	MovementMode = { direction = "ToServer", rate = 10, burst = 20 },

	-- Combat. Le client annonce ce qu'il fait ; le serveur vérifie tout (arme équipée, cadence,
	-- munitions, origin du tir, ligne de vue) et calcule lui-même les touches et les dégâts.
	EquipWeapon = { direction = "ToServer", rate = 6, burst = 8 }, -- (emplacement)
	FireWeapon = { direction = "ToServer", rate = 15, burst = 15 }, -- (origine, direction, heure)
	ReloadWeapon = { direction = "ToServer", rate = 2, burst = 3 },
	MeleeSwing = { direction = "ToServer", rate = 5, burst = 5 }, -- (chargée, direction, heure)
	Parry = { direction = "ToServer", rate = 3, burst = 3 }, -- lever sa lame (aucun argument)
	-- Capacité de l'arme en main (v0.4.5). Argument : la cible visée (Model) pour le Pas de
	-- l'ombre, rien pour le Retour. Le serveur vérifie noyau, distance, ligne de vue, règles PvP.
	UseAbility = { direction = "ToServer", rate = 2, burst = 3 },
	-- Le serveur envoie au joueur l'état réel de son arme : (idArme, munitions, rechargeFin?)
	WeaponState = { direction = "ToClient" },
	-- Au tireur : touche confirmée ; à la victime : dégâts reçus. (table d'informations)
	CombatEvent = { direction = "ToClient" },
	-- À tous : effet visuel d'un tir ou d'un coup d'un autre joueur.
	ShotFx = { direction = "ToClient" },

	-- Butin et extraction (v0.6.0, place Éclat). Les fouilles passent par des ProximityPrompt
	-- (distance vérifiée par Roblox côté serveur) : aucun remote ToServer pour ramasser.
	-- Le serveur envoie au joueur son inventaire de partie : { capacity, stacks = {{id, qty}} }.
	InventoryState = { direction = "ToClient" },
	-- Au joueur : ce qu'il vient de ramasser, ou ce qu'il a perdu en mourant. (table)
	LootEvent = { direction = "ToClient" },
	-- Au joueur extrait : le bilan (objets versés au coffre, Grains, nombre d'extractions).
	ExtractionResult = { direction = "ToClient" },
	-- Le joueur extrait demande à repartir dans l'Éclat (aucun argument).
	RequestRedeploy = { direction = "ToServer", rate = 0.5, burst = 2 },

	-- Message court à afficher au joueur (portail indisponible, etc.) : (texte).
	Notice = { direction = "ToClient" },

	-- Commandes de test. Écoutées UNIQUEMENT dans Studio (voir Server > Systems > DevTools) :
	-- en jeu publié, ce remote existe mais personne ne l'écoute.
	DevCommand = { direction = "ToServer", rate = 5, burst = 10 },
}

return table.freeze(Definitions)
