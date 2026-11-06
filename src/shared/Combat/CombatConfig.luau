--!strict
-- Réglages généraux du combat (GDD 03-combat §3). Répliqué aux clients pour l'affichage ;
-- le serveur reste seul juge des dégâts.
-- Studio : ReplicatedStorage > Shared > Combat > CombatConfig

return table.freeze({
	MAX_HEALTH = 100,
	BASE_ARMOR = 15, -- armure légère de l'équipement de base
	HEADSHOT_MULTIPLIER = 1.5,

	-- Joueur à terre (players only)
	DOWNED_DURATION = 20, -- secondes avant la mort si personne ne relève
	DOWNED_HEALTH = 30, -- « santé à terre » : les dégâts reçus à terre la consomment
	DOWNED_WALK_SPEED = 4,

	-- Compensation de latence (serveur)
	HISTORY_DURATION = 1, -- secondes de positions conservées
	MAX_REWIND = 0.4, -- on ne remonte jamais plus loin dans le passé
	HITBOX_TOLERANCE = 0.5, -- studs ajoutés aux zones de touche pour absorber les écarts
	MAX_MUZZLE_OFFSET = 7, -- distance max entre l'origine annoncée d'un tir et le joueur

	-- Mannequins d'entraînement
	DUMMY_HEALTH = 150,
	DUMMY_RESET_DELAY = 3,
})
