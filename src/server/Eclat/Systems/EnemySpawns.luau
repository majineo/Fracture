--!strict
-- Postes des Échoués dans l'Éclat de la forteresse (GDD 07 §3) — v0.5.0 : posés sur les tuiles
-- générées (EclatService), selon le type de tuile.
-- Studio : ServerScriptService > Server > Place > Systems > EnemySpawns (place Éclat)
--
-- Chaque poste garde un ennemi ; un ennemi tué revient au bout de RESPAWN_DELAY secondes
-- (le Temps « recolle » les figés), tant que sa tuile tient debout et que la partie est la même.
-- Positions dans le repère tourné de la tuile (y = hauteur du sol du poste), à ajuster quand les
-- vrais modules de décor remplaceront la greybox.

local EnemyService = require(script.Parent.Parent.Parent.Systems.EnemyService)
local EclatService = require(script.Parent.EclatService)

local RESPAWN_DELAY = 90
local MAN = "enemy.man_at_arms"
local BOW = "enemy.crossbowman"

type Post = { id: string, x: number, y: number, z: number }

local POSTS: { [string]: { Post } } = {
	Donjon = {
		{ id = BOW, x = 6, y = 16, z = 6 }, -- sur le toit du donjon
		{ id = MAN, x = 0, y = 0, z = 18 },
		{ id = MAN, x = 18, y = 0, z = 0 },
	},
	CourArmes = { { id = MAN, x = -6, y = 0, z = 4 }, { id = MAN, x = 6, y = 0, z = -4 } },
	Remparts = { { id = BOW, x = -6, y = 12, z = -8 }, { id = MAN, x = 0, y = 0, z = 8 } },
	TourGuet = { { id = BOW, x = 8, y = 24, z = 8 } },
	Village = { { id = MAN, x = 0, y = 0, z = -6 }, { id = BOW, x = 0, y = 0, z = 8 } },
	PontLevis = { { id = MAN, x = -12, y = 0, z = -14 } },
	Crypte = { { id = MAN, x = 0, y = 0, z = -5 }, { id = MAN, x = 0, y = 0, z = 5 } },
}

local EnemySpawns = {}

local generation = 0

local function occupy(tile: any, post: Post, frame: CFrame, token: number)
	if token ~= generation or not EclatService.isStanding(tile.x, tile.z) then
		return
	end
	local position = frame:PointToWorldSpace(Vector3.new(post.x, post.y + 3, post.z))
	-- Regard vers le centre de l'Éclat.
	local look = Vector3.new(0, position.Y, 0)
	if (look - position).Magnitude < 1 then
		look = position + Vector3.new(0, 0, 1)
	end
	EnemyService.spawn(post.id, CFrame.lookAt(position, look), function()
		task.delay(RESPAWN_DELAY, occupy, tile, post, frame, token)
	end)
end

function EnemySpawns.init()
	EclatService.Built:Connect(function(layout: any)
		generation += 1
		local token = generation
		-- Densité (GDD 02 §2 : Échoués faibles pendant l'exploration, ≈ 15) : tous les postes au
		-- Donjon et sur les tuiles du milieu, un poste sur chaque tuile extérieure.
		-- Pas de poste à côté d'une tuile d'apparition : on n'arrive pas sous le feu.
		local rng = Random.new(layout.seed)
		local function nearSpawn(tile: any): boolean
			for _, other in layout.tiles do
				if other.spawn and math.abs(other.x - tile.x) + math.abs(other.z - tile.z) <= 1 then
					return true
				end
			end
			return false
		end
		for _, tile in layout.tiles do
			local posts = POSTS[tile.kind]
			if posts and not nearSpawn(tile) then
				local frame = EclatService.tileFrame(tile)
				if tile.ring <= 1 then
					for _, post in posts do
						occupy(tile, post, frame, token)
					end
				else
					occupy(tile, posts[rng:NextInteger(1, #posts)], frame, token)
				end
			end
		end
	end)
end

return EnemySpawns
