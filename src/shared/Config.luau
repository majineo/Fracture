--!strict
-- Valeurs de réglage partagées. ATTENTION : répliqué aux clients, donc rien de secret ici.
-- Le serveur ne fait jamais confiance à une valeur envoyée par un client.
-- Studio : ReplicatedStorage > Shared > Config

return table.freeze({
	GAME_VERSION = "0.6.1",
	-- Identifiants des places publiées (même expérience). 0 = pas encore publiée : le portail du
	-- Refuge et le retour après l'extraction restent désactivés (v0.6.1).
	PLACE_IDS = table.freeze({
		Refuge = 0,
		Eclat = 0,
	}),
})
