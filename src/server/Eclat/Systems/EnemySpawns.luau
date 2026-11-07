--!strict
-- Postes des Échoués dans l'Éclat de la forteresse (greybox, GDD 07 §3).
-- Studio : ServerScriptService > Server > Place > Systems > EnemySpawns (place Éclat)
--
-- Chaque poste garde un groupe ; un ennemi tué revient au bout de RESPAWN_DELAY secondes
-- (le Temps « recolle » les figés), ce qui garde l'Éclat dangereux pendant toute la partie.
-- ⚠ Postes provisoires sur le sol de test, à replacer quand la carte sera construite.

local EnemyService = require(script.Parent.Parent.Parent.Systems.EnemyService)

local RESPAWN_DELAY = 90

type Post = { id: string, position: Vector3, facing: Vector3 }

local POSTS: { Post } = {
	-- Cour nord : deux hommes d'armes et un arbalétrier en retrait.
	{
		id = "enemy.man_at_arms",
		position = Vector3.new(-12, 3, -70),
		facing = Vector3.new(0, 0, 1),
	},
	{ id = "enemy.man_at_arms", position = Vector3.new(12, 3, -70), facing = Vector3.new(0, 0, 1) },
	{ id = "enemy.crossbowman", position = Vector3.new(0, 3, -100), facing = Vector3.new(0, 0, 1) },
	-- Flanc est : patrouille isolée.
	{ id = "enemy.man_at_arms", position = Vector3.new(90, 3, 20), facing = Vector3.new(-1, 0, 0) },
	{
		id = "enemy.crossbowman",
		position = Vector3.new(120, 3, -20),
		facing = Vector3.new(-1, 0, 0),
	},
	-- Ouest : groupe lourd près de la future salle du trésor.
	{
		id = "enemy.man_at_arms",
		position = Vector3.new(-100, 3, 60),
		facing = Vector3.new(1, 0, 0),
	},
	{
		id = "enemy.man_at_arms",
		position = Vector3.new(-100, 3, 76),
		facing = Vector3.new(1, 0, 0),
	},
	{
		id = "enemy.crossbowman",
		position = Vector3.new(-128, 3, 68),
		facing = Vector3.new(1, 0, 0),
	},
}

local EnemySpawns = {}

local function occupy(post: Post)
	local cframe = CFrame.lookAt(post.position, post.position + post.facing)
	EnemyService.spawn(post.id, cframe, function()
		task.delay(RESPAWN_DELAY, occupy, post)
	end)
end

function EnemySpawns.start()
	for _, post in POSTS do
		occupy(post)
	end
end

return EnemySpawns
