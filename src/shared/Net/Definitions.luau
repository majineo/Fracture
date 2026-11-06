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

export type RemoteName = "ClientReady" | "ProfileSnapshot"

local Definitions: { [string]: RemoteDef } = {
	-- Le client signale qu'il est prêt à recevoir son état (demande un instantané du profil).
	ClientReady = { direction = "ToServer", rate = 0.5, burst = 3 },
	-- Le serveur envoie au joueur la vue publique de son profil.
	ProfileSnapshot = { direction = "ToClient" },
}

return table.freeze(Definitions)
