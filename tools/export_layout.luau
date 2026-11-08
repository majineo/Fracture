--!strict
-- Exporte le plan d'un Éclat (graine) en JSON pour la maquette Blender (v0.11.0).
-- Usage : lune run tools/export_layout [graine]  →  build/layout_<graine>.json
-- Même source que le jeu : Shared/Eclat/EclatLayout (grille, bords) et Shared/Eclat/Districts
-- (contenu de chaque tuile). Le script Blender assets/blender/fortress/blockout_eclat.py lit ce
-- fichier et construit la maquette grise.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local EclatLayout = require("../src/shared/Eclat/EclatLayout")
local Districts = require("../src/shared/Eclat/Districts")

local seed = tonumber(process.args[1]) or 42
local layout = EclatLayout.generate(seed)

local tiles = {}
for _, tile in layout.tiles do
	local cx, cz = EclatLayout.tileCenter(layout, tile.x, tile.z)
	local edges = {}
	for _, dir in EclatLayout.DIRECTIONS do
		edges[dir] = EclatLayout.edge(layout, tile.x, tile.z, dir)
	end
	table.insert(tiles, {
		x = tile.x,
		z = tile.z,
		kind = tile.kind,
		rotation = tile.rotation,
		ring = tile.ring,
		spawn = tile.spawn,
		center = { cx, cz },
		edges = edges,
	})
end

local out = {
	seed = seed,
	size = layout.size,
	tile = EclatLayout.TILE,
	tiles = tiles,
	districts = Districts.DEFS,
	modules = Districts.MODULES,
	block = Districts.BLOCK,
	ring = Districts.RING,
}

fs.writeDir("build")
local path = `build/layout_{seed}.json`
fs.writeFile(path, serde.encode("json", out, true))
print(`Plan exporté : {path} ({#tiles} tuiles)`)
