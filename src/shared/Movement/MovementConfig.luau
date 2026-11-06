--!strict
-- Réglages du déplacement (GDD 03-combat §2). Répliqué aux clients : le serveur s'en sert
-- seulement pour BORNER ce qu'il accepte, jamais pour croire le client.
-- Studio : ReplicatedStorage > Shared > Movement > MovementConfig

return table.freeze({
	-- Marche et sprint (studs/s)
	WALK_SPEED = 14,
	SPRINT_SPEED = 22,

	-- Endurance (0 à 1)
	SPRINT_DURATION = 6, -- secondes de sprint avec une jauge pleine
	REGEN_DURATION = 4, -- secondes pour remplir la jauge
	REGEN_DELAY = 0.6, -- pause avant la recharge après un effort
	SPRINT_RESTART_MIN = 0.25, -- jauge vidée : il faut remonter à 25 % pour resprinter
	SLIDE_STAMINA_COST = 0.15,

	-- Glissade
	SLIDE_SPEED = 30, -- vitesse au départ
	SLIDE_END_SPEED = 15, -- vitesse à la fin
	SLIDE_DURATION = 0.8,
	SLIDE_DOWNHILL_TIME_SCALE = 0.4, -- en descente, la glissade ralentit 2,5 fois moins vite
	SLIDE_COOLDOWN = 0.5,
	SLIDE_MIN_SPEED = 16, -- il faut déjà courir pour glisser
	SLIDE_CAMERA_DROP = 1.6, -- abaissement de la caméra pendant la glissade

	-- Escalade de rebord
	MANTLE_MIN_HEIGHT = 2.5, -- en dessous : un simple saut suffit
	MANTLE_MAX_HEIGHT = 7,
	MANTLE_REACH = 2.5, -- distance maximale du mur devant le joueur
	MANTLE_DURATION = 0.35,

	-- Grappin (outil d'équipement)
	GRAPPLE_RANGE = 60,
	GRAPPLE_SPEED = 70,
	GRAPPLE_COOLDOWN = 8,
	GRAPPLE_MAX_TIME = 1.6,
	GRAPPLE_STOP_DISTANCE = 6,
	GRAPPLE_RELEASE_BOOST = 18, -- petite impulsion vers le haut en lâchant (saut)
})
