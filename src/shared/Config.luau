--!strict
-- Valeurs de réglage partagées. ATTENTION : répliqué aux clients, donc rien de secret ici.
-- Le serveur ne fait jamais confiance à une valeur envoyée par un client.
-- Studio : ReplicatedStorage > Shared > Config

return table.freeze({
	GAME_VERSION = "0.4.0",
})
