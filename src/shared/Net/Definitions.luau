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

	-- Commandes de test. Écoutées UNIQUEMENT dans Studio (voir Server > Systems > DevTools) :
	-- en jeu publié, ce remote existe mais personne ne l'écoute.
	DevCommand = { direction = "ToServer", rate = 5, burst = 10 },
}

return table.freeze(Definitions)
