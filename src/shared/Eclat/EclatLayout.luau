--!strict
-- Plan d'un Éclat (v0.5.0, GDD 02 §2 et 06 §2) : grille de tuiles tirée d'une graine.
-- v0.11.0 : forteresse agrandie — 7 × 7 tuiles de 96 studs (672 × 672, ≈ 4,4 fois la carte de
-- la v0.5), sur la grille de construction de 8 studs (96 = 12 × 8), pour une carte à explorer.
-- Module pur (aucune instance) : le serveur construit la carte à partir de ce plan, les clients
-- recalculent le même plan à partir de la même graine (rien d'autre n'a besoin d'être envoyé).
-- Studio : ReplicatedStorage > Shared > Eclat > EclatLayout
--
-- Repère : x vers +X (est), z vers +Z (sud) ; la tuile (0, 0) est au nord-ouest. Le centre de la
-- grille est à l'origine du monde. Directions des bords : N = -Z, E = +X, S = +Z, W = -X.
--
-- Règles :
--   * centre : toujours le Donjon ;
--   * milieu de chaque côté de la couronne extérieure : un Bord d'Éclat (apparition des escouades,
--     le plus loin possible les unes des autres) ;
--   * coins : Remparts ou Tour de guet ; reste : tirage dans des réserves remplies à la taille de
--     chaque couronne (chaque type de tuile apparaît, la Crypte une seule fois) ;
--   * chaque bord partagé entre deux tuiles offre toujours au moins deux passages (GDD 06 §3) :
--     « Open » (pas de mur), « Gates » (mur percé de deux portes) ou « Rampart » (une porte au sol
--     et un chemin de ronde avec escaliers). Le Donjon est toujours muré (Gates / Rampart). Les
--     bords extérieurs donnent sur le Vide (« Void »).

export type TileKind =
	"Donjon" -- centre, unique : Gardien, Faille finale
	| "CourArmes" -- combat ouvert
	| "Remparts" -- chemins en hauteur, tireurs
	| "TourGuet" -- point de vue, autel possible
	| "Village" -- village fortifié, combat rapproché
	| "PontLevis" -- pont-levis et douves, passage risqué
	| "Crypte" -- souterrain, butin rare (unique)
	| "Bord" -- bord d'Éclat : apparition des escouades
export type EdgeKind = "Open" | "Gates" | "Rampart" | "Void"
export type Direction = "N" | "E" | "S" | "W"

export type Tile = {
	x: number,
	z: number,
	kind: TileKind,
	rotation: number, -- quarts de tour (0 à 3), pour varier l'intérieur
	ring: number, -- 0 = centre, puis couronnes 1, 2… jusqu'à la couronne extérieure
	spawn: boolean, -- tuile d'apparition d'une escouade
}

export type Layout = {
	seed: number,
	size: number,
	tiles: { Tile }, -- indexées par (z * size + x) + 1
	edges: { [string]: EdgeKind },
}

local EclatLayout = {}

EclatLayout.SIZE = 7
EclatLayout.TILE = 96 -- studs (v0.11.0 ; 64 dans la forteresse de la v0.5)
EclatLayout.DIRECTIONS = table.freeze({ "N", "E", "S", "W" }) :: { Direction }

local OFFSETS: { [Direction]: { number } } = {
	N = { 0, -1 },
	E = { 1, 0 },
	S = { 0, 1 },
	W = { -1, 0 },
}
EclatLayout.OFFSETS = table.freeze(OFFSETS)

-- Générateur pseudo-aléatoire déterministe (xorshift32) : identique sur le serveur, les clients
-- et dans les tests Lune, quelle que soit la plateforme.
export type Rng = { state: number }

function EclatLayout.rng(seed: number): Rng
	local state = bit32.band(math.floor(seed), 0xFFFFFFFF)
	if state == 0 then
		state = 0x9E3779B9
	end
	return { state = state }
end

function EclatLayout.nextFloat(r: Rng): number
	local s = r.state
	s = bit32.bxor(s, bit32.lshift(s, 13))
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5))
	r.state = s
	return s / 4294967296
end

function EclatLayout.nextInt(r: Rng, low: number, high: number): number
	return low + math.floor(EclatLayout.nextFloat(r) * (high - low + 1))
end

function EclatLayout.shuffle<T>(r: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = EclatLayout.nextInt(r, 1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function ringOf(x: number, z: number, size: number): number
	local c = (size - 1) / 2
	return math.max(math.abs(x - c), math.abs(z - c))
end

-- Clé canonique d'un bord : celui de la tuile au nord / à l'ouest des deux.
local function edgeKey(x: number, z: number, dir: Direction): string
	if dir == "S" then
		return `{x},{z + 1},N`
	elseif dir == "E" then
		return `{x + 1},{z},W`
	end
	return `{x},{z},{dir}`
end

function EclatLayout.index(layout: Layout, x: number, z: number): number
	return z * layout.size + x + 1
end

function EclatLayout.tileAt(layout: Layout, x: number, z: number): Tile?
	if x < 0 or z < 0 or x >= layout.size or z >= layout.size then
		return nil
	end
	return layout.tiles[EclatLayout.index(layout, x, z)]
end

function EclatLayout.edge(layout: Layout, x: number, z: number, dir: Direction): EdgeKind
	return layout.edges[edgeKey(x, z, dir)] or "Void"
end

-- Centre de la tuile dans le monde (x, z en studs).
function EclatLayout.tileCenter(layout: Layout, x: number, z: number): (number, number)
	local c = (layout.size - 1) / 2
	return (x - c) * EclatLayout.TILE, (z - c) * EclatLayout.TILE
end

-- Tuile qui contient un point du monde (nil hors de la grille).
function EclatLayout.tileFromWorld(layout: Layout, wx: number, wz: number): (number?, number?)
	local half = layout.size * EclatLayout.TILE / 2
	local x = math.floor((wx + half) / EclatLayout.TILE)
	local z = math.floor((wz + half) / EclatLayout.TILE)
	if x < 0 or z < 0 or x >= layout.size or z >= layout.size then
		return nil, nil
	end
	return x, z
end

-- Couronne extérieure dans le sens des aiguilles d'une montre, depuis le coin nord-ouest :
-- quatre côtés de `size - 1` tuiles (le coin de départ compris). Sert aussi à l'effondrement.
function EclatLayout.outerSides(size: number): { { { number } } }
	local last = size - 1
	local sides = { {}, {}, {}, {} }
	for i = 0, last - 1 do
		table.insert(sides[1], { i, 0 }) -- nord
		table.insert(sides[2], { last, i }) -- est
		table.insert(sides[3], { last - i, last }) -- sud
		table.insert(sides[4], { 0, last - i }) -- ouest
	end
	return sides
end

local CORNER_POOL: { TileKind } = { "Remparts", "Remparts", "TourGuet", "TourGuet" }
-- Réserves de base, répétées jusqu'à remplir chaque couronne.
local OUTER_BASE: { TileKind } =
	{ "Village", "CourArmes", "PontLevis", "Village", "Remparts", "TourGuet" }
local INNER_BASE: { TileKind } =
	{ "CourArmes", "Village", "Remparts", "TourGuet", "PontLevis", "CourArmes" }

local function copy<T>(list: { T }): { T }
	return table.clone(list)
end

-- `count` éléments tirés en cycle dans `base` (puis mélangés par l'appelant).
local function fill<T>(base: { T }, count: number): { T }
	local out = {}
	for i = 1, count do
		out[i] = base[(i - 1) % #base + 1]
	end
	return out
end

function EclatLayout.generate(seed: number): Layout
	local size = EclatLayout.SIZE
	local r = EclatLayout.rng(seed)
	local last = size - 1
	local mid = last / 2
	local outerRing = size // 2
	local corners = EclatLayout.shuffle(r, copy(CORNER_POOL))
	-- Couronne extérieure : 8 × outerRing tuiles, moins 4 coins et 4 Bords.
	local outer = EclatLayout.shuffle(r, fill(OUTER_BASE, 8 * outerRing - 8))
	-- Couronnes intérieures (1 … outerRing - 1) : la Crypte une seule fois.
	local innerCount = 0
	for ring = 1, outerRing - 1 do
		innerCount += 8 * ring
	end
	local middleList = fill(INNER_BASE, innerCount - 1)
	table.insert(middleList, "Crypte")
	local middle = EclatLayout.shuffle(r, middleList)
	local tiles: { Tile } = {}
	for z = 0, last do
		for x = 0, last do
			local ring = ringOf(x, z, size)
			local kind: TileKind
			local spawn = false
			if ring == 0 then
				kind = "Donjon"
			elseif ring == outerRing and (x == mid or z == mid) then
				kind = "Bord"
				spawn = true
			elseif ring == outerRing and (x == 0 or x == last) and (z == 0 or z == last) then
				kind = table.remove(corners) :: TileKind
			elseif ring == outerRing then
				kind = table.remove(outer) :: TileKind
			else
				kind = table.remove(middle) :: TileKind
			end
			local rotation = if kind == "Donjon" then 0 else EclatLayout.nextInt(r, 0, 3)
			tiles[z * size + x + 1] = {
				x = x,
				z = z,
				kind = kind,
				rotation = rotation,
				ring = ring,
				spawn = spawn,
			}
		end
	end
	local layout: Layout = { seed = seed, size = size, tiles = tiles, edges = {} }
	for z = 0, last do
		for x = 0, last do
			for _, dir in { "N", "W" } :: { Direction } do
				local offset = OFFSETS[dir]
				local neighbor = EclatLayout.tileAt(layout, x + offset[1], z + offset[2])
				local key = edgeKey(x, z, dir)
				if neighbor == nil then
					layout.edges[key] = "Void"
				else
					local here = tiles[z * size + x + 1]
					local walled = here.kind == "Donjon" or neighbor.kind == "Donjon"
					local roll = EclatLayout.nextFloat(r)
					local kind: EdgeKind
					if walled then
						kind = if roll < 0.5 then "Gates" else "Rampart"
					elseif roll < 0.35 then
						kind = "Open"
					elseif roll < 0.7 then
						kind = "Gates"
					else
						kind = "Rampart"
					end
					layout.edges[key] = kind
				end
			end
			-- Bords sud et est de la grille : le Vide.
			if z == last then
				layout.edges[edgeKey(x, z, "S")] = "Void"
			end
			if x == last then
				layout.edges[edgeKey(x, z, "E")] = "Void"
			end
		end
	end
	return layout
end

-- Tuiles d'apparition (une par escouade).
function EclatLayout.spawnTiles(layout: Layout): { Tile }
	local out = {}
	for _, tile in layout.tiles do
		if tile.spawn then
			table.insert(out, tile)
		end
	end
	return out
end

return EclatLayout
