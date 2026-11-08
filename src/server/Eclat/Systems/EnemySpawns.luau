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
local Districts = require(game:GetService("ReplicatedStorage").Shared.Eclat.Districts)

local RESPAWN_DELAY = 90

type Post = Districts.Post

-- Postes de garde : Shared/Eclat/Districts (champ « posts »).

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
		-- Densité (carte 7 × 7, v0.11.0) : tous les postes au Donjon et sur la première
		-- couronne, un poste par quartier de la deuxième, un quartier sur deux à l'extérieur
		-- (≈ 30 Échoués pour une carte 4,4 fois plus grande que la forteresse).
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
			local district = Districts.get(tile.kind)
			local posts = district and district.posts
			if posts and #posts > 0 and not nearSpawn(tile) then
				local frame = EclatService.tileFrame(tile)
				local outer = tile.ring >= (layout.size - 1) / 2
				if tile.ring <= 1 then
					for _, post in posts do
						occupy(tile, post, frame, token)
					end
				elseif not outer or rng:NextNumber() < 0.5 then
					occupy(tile, posts[rng:NextInteger(1, #posts)], frame, token)
				end
			end
		end
	end)
end

return EnemySpawns
