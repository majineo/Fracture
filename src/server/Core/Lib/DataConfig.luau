--!strict
-- Réglages du système de données (serveur uniquement).
-- Studio : ServerScriptService > Server > Lib > DataConfig

return table.freeze({
	-- Nom du DataStore. Le suffixe de version permet de repartir de zéro si un jour c'est
	-- nécessaire, sans détruire l'ancien stockage.
	STORE_NAME = "PlayerProfiles_v1",
	-- Dans Studio (avec accès aux API activé), on utilise un stockage séparé pour ne jamais
	-- toucher aux données des vrais joueurs.
	STUDIO_STORE_SUFFIX = "_Studio",

	AUTOSAVE_INTERVAL = 60, -- secondes entre deux sauvegardes automatiques d'un joueur
	LOCK_STALE_AFTER = 150, -- un verrou plus vieux que ça est considéré comme abandonné (serveur planté)

	CALL_ATTEMPTS = 5, -- tentatives par appel DataStore
	CALL_BASE_DELAY = 1, -- attente initiale entre tentatives (doublée à chaque échec)
	CALL_MAX_DELAY = 8,

	LOCK_WAIT_ATTEMPTS = 8, -- tentatives quand le profil est verrouillé par un autre serveur
	LOCK_WAIT_DELAY = 3, -- secondes entre ces tentatives

	SHUTDOWN_TIMEOUT = 25, -- secondes maximum pour tout sauvegarder à l'arrêt du serveur
})
