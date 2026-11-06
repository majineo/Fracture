--!strict
-- Valeurs de réglage du jeu. ATTENTION : répliqué aux clients, donc rien de secret ici.
-- Le serveur ne fait jamais confiance à une valeur envoyée par un client.
-- Placement Studio : ReplicatedStorage > Shared > Config (synchronisé par Rojo).

return table.freeze({
	GAME_VERSION = "0.1.0",
})
