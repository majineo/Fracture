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

	-- Gel sur coup de mêlée reçu (WeaponService pose FrozenUntil, EnemyService fige les
	-- animations, les clients réagissent) : tout est réglable ici.
	MELEE_HIT_FREEZE = 0.1, -- secondes de gel de l'animation d'un ennemi touché en mêlée
	MELEE_FREEZE_SHAKE = 0.8, -- secousse caméra en plus de celle du coup (degrés, vers le bas)
	MELEE_FREEZE_FLASH = 0.2, -- durée du flash blanc renforcé sur l'ennemi gelé

	-- Mannequins d'entraînement
	DUMMY_HEALTH = 150,
	DUMMY_RESET_DELAY = 3,
})
