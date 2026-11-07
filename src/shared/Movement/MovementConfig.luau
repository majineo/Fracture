--!strict
-- Réglages du déplacement (GDD 03-combat §2). Répliqué aux clients : le serveur s'en sert
-- seulement pour BORNER ce qu'il accepte, jamais pour croire le client.
-- Studio : ReplicatedStorage > Shared > Movement > MovementConfig

return table.freeze({
	-- Marche et sprint (studs/s)
	WALK_SPEED = 14,
	SPRINT_SPEED = 22,
	START_SPEED = 9, -- vitesse au premier pas (on accélère ensuite jusqu'à la marche)
	ACCELERATION_STIFFNESS = 9, -- raideur du ressort de vitesse (plus haut = plus nerveux)

	-- Tolérance des commandes
	INPUT_BUFFER = 0.18, -- une commande pressée un peu trop tôt est retenue ce temps-là
	COYOTE_TIME = 0.12, -- on peut encore sauter ce temps-là après avoir quitté un rebord

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
	GRAPPLE_STOP_DISTANCE = 3.5,
	GRAPPLE_MANTLE_REACH = 5, -- en fin de grappin, on cherche un rebord jusqu'à cette distance
	GRAPPLE_RELEASE_BOOST = 18, -- petite impulsion vers le haut en lâchant (saut)
	GRAPPLE_HOOK_SPEED = 320, -- vitesse du crochet avant qu'il s'accroche
	GRAPPLE_ACCELERATION = 5, -- raideur de la mise en traction
	GRAPPLE_SLOWDOWN_DISTANCE = 12, -- on ralentit en approchant de la cible
	GRAPPLE_ARRIVAL_SPEED = 28,

	-- Élan (dash, v0.4.11) : sol et air (une fois par saut)
	DASH_SPEED = 62,
	DASH_TIME = 0.16,
	DASH_EXIT_SPEED = 26, -- vitesse conservée à la sortie
	DASH_COOLDOWN = 1.1,
	DASH_STAMINA_COST = 0.2,
	DASH_AIR_CHARGES = 1,

	-- Course sur les murs (automatique : en l'air, en mouvement, le long d'un mur)
	WALLRUN_MIN_SPEED = 13,
	WALLRUN_SPEED = 24,
	WALLRUN_DURATION = 1.3,
	WALLRUN_REACH = 2.6, -- distance maximale du mur sur le côté
	WALLRUN_START_RISE = 6, -- petite montée au début
	WALLRUN_END_SINK = -7, -- descente en fin de course
	WALLRUN_COOLDOWN = 0.35, -- avant de pouvoir reprendre un mur
	WALLJUMP_PUSH = 24, -- saut mural : éloignement du mur
	WALLJUMP_UP = 42, -- saut mural : vers le haut
})
