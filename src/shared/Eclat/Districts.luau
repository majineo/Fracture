--!strict
-- Tuiles de la forteresse de l'Éclat (v0.11.0, carte agrandie 7 × 7) : TOUT ce qui se trouve dans
-- une tuile, au même endroit — bâtiments, escaliers, plateformes, décor de siège, et points de jeu
-- (butin, Échoués, extraction, autel, apparition, trône du Gardien). Module pur : testé par
-- tests/specs/Districts.spec.luau (aucun point de jeu dans un mur, chemins dégagés).
-- Studio : ReplicatedStorage > Shared > Eclat > Districts
--
-- Repère d'une tuile (96 × 96, grille de construction de 8 studs) : origine au centre, sol à
-- y = 0, coordonnées tournées avec la tuile. Plan type :
--   * un îlot central (|x|, |z| ≤ 26) propre à la tuile ;
--   * un chemin de ronde au sol tout autour (26 < max(|x|, |z|) ≤ 40), toujours praticable ;
--   * la bande des bords (40 à 48) appartient aux bords (courtines, portes, remparts, Vide).
-- Les modules (Fort_*) seront modélisés dans Blender ; MODULES donne leur empreinte de maquette
-- (repli greybox tant qu'ils ne sont pas importés).

local Districts = {}

export type Module = {
	w: number, -- largeur (x)
	d: number, -- profondeur (z)
	h: number, -- hauteur
	roof: number?, -- hauteur du toit praticable (donjon, tour)
	tower: { w: number, d: number, h: number }?, -- tour centrale au-dessus du toit (repère)
}
export type Placement = {
	module: string,
	x: number,
	z: number,
	y: number?,
	turns: number?, -- quarts de tour (sens trigonométrique vu du dessus)
	solid: boolean?, -- false : décor traversable (étendards…)
}
export type Stair =
	{ x: number, z: number, turns: number, rise: number, run: number, width: number }
export type Solid = {
	x: number,
	z: number,
	w: number,
	d: number,
	top: number,
	bottom: number?, -- dalle suspendue (toit de crypte, passerelle) ; 0 par défaut
	material: string,
}
export type Spot = { x: number, y: number, z: number }
export type LootSpot = Spot & { table: string }
export type Post = Spot & { id: string }

export type District = {
	ground: string, -- matériau du sol de l'îlot (le chemin de ronde est toujours pavé)
	buildings: { Placement },
	props: { Placement },
	stairs: { Stair },
	solids: { Solid },
	canal: boolean?, -- douve en travers (z ∈ [-6, 6]), sol coupé
	loot: { LootSpot },
	posts: { Post },
	extract: Spot, -- point d'extraction (centre de la zone)
	altar: Spot?, -- autel de relique possible ici
	spawn: Spot?, -- apparition d'escouade
	throne: Spot?, -- départ du Gardien
	light: { number }?, -- lueur d'ambiance (RGB 0–255)
}

Districts.HALF = 48
Districts.BLOCK = 26 -- demi-côté de l'îlot central
Districts.RING = 40 -- limite extérieure du chemin de ronde

-- Empreintes de maquette (studs) : origine en bas au centre, façade vers -Z.
Districts.MODULES = table.freeze({
	-- Bâtiments
	-- Terrasse praticable à 24 et grande tour centrale de 56 : le repère de toute la carte.
	Fort_Donjon = { w = 32, d = 32, h = 56, roof = 24, tower = { w = 12, d = 12, h = 56 } },
	Fort_TourGuet = { w = 12, d = 12, h = 28, roof = 24 },
	Fort_Maison = { w = 12, d = 10, h = 16 },
	Fort_GrandeMaison = { w = 16, d = 12, h = 18 },
	Fort_Corps = { w = 14, d = 10, h = 12 }, -- corps de garde
	-- Bords (8 studs de module)
	Fort_Mur = { w = 8, d = 4, h = 14 },
	Fort_Porte = { w = 10, d = 4, h = 14 },
	Fort_Rempart = { w = 8, d = 6, h = 14 },
	Fort_Tourelle = { w = 10, d = 10, h = 20 },
	Fort_Escalier = { w = 6, d = 12, h = 9 },
	-- Siège figé, machinerie, Brisure
	Fort_Trebuchet = { w = 10, d = 8, h = 12 },
	Fort_Belier = { w = 4, d = 10, h = 5 },
	Fort_Barricade = { w = 8, d = 2, h = 3 },
	Fort_Chaudiere = { w = 6, d = 6, h = 8 }, -- chaudière à vapeur, soupapes, manomètre
	Fort_Horloge = { w = 6, d = 4, h = 8 }, -- mécanisme d'horlogerie figé
	Fort_Cloche = { w = 5, d = 5, h = 8 },
	Fort_Puits = { w = 5, d = 5, h = 4 },
	Fort_Ratelier = { w = 6, d = 1, h = 4 },
	Fort_Sarcophage = { w = 3, d = 6, h = 2.2 },
	Fort_Cristal = { w = 4, d = 4, h = 6 }, -- fracture de cristal plantée dans la pierre
	Fort_Etendard = { w = 1, d = 1, h = 10 },
	Fort_Eboulis = { w = 5, d = 3, h = 2.5 }, -- éboulis : couvert bas du chemin de ronde
	Kit_Caisse = { w = 3, d = 2.6, h = 2.4 },
	Kit_Coffre = { w = 3.6, d = 2.6, h = 2.8 },
}) :: { [string]: Module }

local MAN = "enemy.man_at_arms"
local BOW = "enemy.crossbowman"

-- Étendards déchirés aux quatre coins de l'îlot (traversables).
local function cornerBanners(): { Placement }
	local out = {}
	for _, p in { { -28, -28 }, { 28, -28 }, { 28, 28 }, { -28, 28 } } do
		table.insert(out, { module = "Fort_Etendard", x = p[1], z = p[2], solid = false })
	end
	return out
end

-- Couverts du chemin de ronde : éboulis tous les ~20 studs, à l'écart des portes (x = ±17 et
-- 0 sur chaque bord) et des zones d'extraction (rayon 7).
local function ringCover(): { Placement }
	local out = {}
	for _, s in { -1, 1 } do
		table.insert(out, { module = "Fort_Eboulis", x = 12 * s, z = -33 })
		table.insert(out, { module = "Fort_Eboulis", x = 12 * s, z = 33 })
		table.insert(out, { module = "Fort_Eboulis", x = -33, z = 12 * s, turns = 1 })
		table.insert(out, { module = "Fort_Eboulis", x = 33, z = 12 * s, turns = 1 })
	end
	return out
end

local function with(list: { Placement }, extra: { Placement }): { Placement }
	for _, p in extra do
		table.insert(list, p)
	end
	return list
end

local DEFS: { [string]: District } = {}

-- Donjon (centre, unique) : bloc massif à toit praticable (24), deux grands escaliers et leurs
-- passerelles ; mécanisme d'horlogerie et fracture de cristal sur le toit. Gardien et Faille.
DEFS.Donjon = {
	ground = "Slate",
	buildings = { { module = "Fort_Donjon", x = 0, z = 0 } },
	props = with({
		{ module = "Fort_Horloge", x = 10, y = 24, z = 10 },
		{ module = "Fort_Cristal", x = -10, y = 24, z = 10 },
		{ module = "Fort_Cloche", x = -22, z = -22 },
		{ module = "Fort_Chaudiere", x = 22, z = -22 },
		{ module = "Fort_Barricade", x = -22, z = 22, turns = 1 },
		{ module = "Kit_Caisse", x = 22, z = 22 },
	}, with(cornerBanners(), ringCover())),
	-- Escaliers le long des faces ouest (monte vers -Z) et est (monte vers +Z).
	stairs = {
		{ x = -22, z = 0, turns = 0, rise = 24, run = 32, width = 6 },
		{ x = 22, z = 0, turns = 2, rise = 24, run = 32, width = 6 },
	},
	-- Passerelles entre le haut des escaliers et le toit.
	solids = {
		{ x = -17.5, z = -13, w = 3, d = 6, top = 24, bottom = 21, material = "WoodPlanks" },
		{ x = 17.5, z = 13, w = 3, d = 6, top = 24, bottom = 21, material = "WoodPlanks" },
	},
	loot = {
		{ table = "Coffre", x = 8, y = 24, z = -2 },
		{ table = "Coffre", x = 0, y = 0, z = -22 },
		{ table = "Caisse", x = 18, y = 0, z = 22 },
	},
	posts = {
		{ id = BOW, x = -8, y = 24, z = 0 },
		{ id = MAN, x = 0, y = 0, z = 21 },
		{ id = MAN, x = 8, y = 0, z = -21 },
	},
	extract = { x = 0, y = 24, z = -11 }, -- la Faille finale, sur la terrasse du Donjon
	throne = { x = 0, y = 0, z = 31 },
}

-- Cour d'armes : combat ouvert, couverts tous les ~15 studs (trébuchet brisé au centre).
DEFS.CourArmes = {
	ground = "Cobblestone",
	buildings = {},
	props = with({
		{ module = "Fort_Trebuchet", x = 0, z = 0 },
		{ module = "Fort_Barricade", x = -14, z = -8 },
		{ module = "Fort_Barricade", x = 14, z = 8 },
		{ module = "Fort_Barricade", x = -8, z = 14, turns = 1 },
		{ module = "Fort_Barricade", x = 8, z = -14, turns = 1 },
		{ module = "Fort_Ratelier", x = -20, z = 0, turns = 1 },
		{ module = "Fort_Ratelier", x = 20, z = 0, turns = 1 },
		{ module = "Fort_Puits", x = -16, z = 18 },
		{ module = "Fort_Chaudiere", x = 16, z = -18 },
		{ module = "Kit_Caisse", x = 18, z = 18 },
		{ module = "Kit_Caisse", x = -18, z = -18 },
		{ module = "Fort_Etendard", x = 0, z = -20, solid = false },
	}, with(cornerBanners(), ringCover())),
	stairs = {},
	solids = {},
	loot = {
		{ table = "Caisse", x = -20, y = 0, z = -14 },
		{ table = "Coffre", x = 0, y = 0, z = 9 },
		{ table = "Sac", x = 12, y = 0, z = -4 },
	},
	posts = { { id = MAN, x = -6, y = 0, z = -6 }, { id = MAN, x = 7, y = 0, z = 6 } },
	extract = { x = 0, y = 0, z = 33 },
	altar = { x = -20, y = 0, z = 8 },
}

-- Remparts : courtine intérieure en L avec chemin de ronde (12), deux escaliers, corps de garde.
DEFS.Remparts = {
	ground = "Cobblestone",
	buildings = { { module = "Fort_Corps", x = -14, z = 14 } },
	props = with({
		{ module = "Fort_Chaudiere", x = -21, z = 4 },
		{ module = "Fort_Etendard", x = 0, y = 12, z = -8, solid = false },
		{ module = "Kit_Caisse", x = 20, z = -18 },
		{ module = "Fort_Cristal", x = 20, z = 22 },
	}, with(cornerBanners(), ringCover())),
	stairs = {
		{ x = -10, z = -2, turns = 3, rise = 12, run = 16, width = 6 }, -- longe la courtine
		{ x = 7, z = 14, turns = 0, rise = 12, run = 16, width = 6 }, -- longe l'aile
	},
	solids = {
		{ x = -2, z = -8, w = 36, d = 6, top = 12, material = "Slate" },
		{ x = 13, z = 6, w = 6, d = 22, top = 12, material = "Slate" },
	},
	loot = {
		{ table = "Caisse", x = -14, y = 12, z = -8 },
		{ table = "Coffre", x = 2, y = 0, z = 12 },
		{ table = "Sac", x = 20, y = 0, z = -22 },
	},
	posts = { { id = BOW, x = -4, y = 12, z = -8 }, { id = MAN, x = 0, y = 0, z = 20 } },
	extract = { x = -33, y = 0, z = 0 },
}

-- Tour de guet : tour à toit praticable (24) et grand escalier ; cloche figée au sommet.
DEFS.TourGuet = {
	ground = "Grass",
	buildings = {
		{ module = "Fort_Maison", x = -14, z = -17 },
		{ module = "Fort_Maison", x = 14, z = 18, turns = 2 },
	},
	props = with({
		{ module = "Fort_Cloche", x = 12, y = 24, z = 4 },
		{ module = "Fort_Barricade", x = -14, z = 8 },
		{ module = "Fort_Cristal", x = 0, z = 16 },
	}, with(cornerBanners(), ringCover())),
	-- Escalier de 30 de long, de x = -25 (sol) à x = 5 (haut), vers +X.
	stairs = { { x = -10, z = 0, turns = 3, rise = 24, run = 30, width = 6 } },
	solids = { { x = 12, z = -1, w = 14, d = 14, top = 24, material = "Slate" } },
	loot = {
		{ table = "Coffre", x = 16, y = 24, z = -4 },
		{ table = "Caisse", x = -6, y = 0, z = 12 },
	},
	posts = { { id = BOW, x = 10, y = 24, z = -6 }, { id = MAN, x = -4, y = 0, z = 18 } },
	extract = { x = 0, y = 0, z = 33 },
	altar = { x = 8, y = 24, z = -5 },
}

-- Village fortifié : quatre maisons serrées, deux ruelles en croix, puits, bélier abandonné.
DEFS.Village = {
	ground = "Ground",
	buildings = {
		{ module = "Fort_Maison", x = -14, z = -14 },
		{ module = "Fort_GrandeMaison", x = 14, z = -14, turns = 1 },
		{ module = "Fort_Maison", x = -14, z = 15, turns = 3 },
		{ module = "Fort_GrandeMaison", x = 14, z = 15, turns = 2 },
	},
	props = with({
		{ module = "Fort_Puits", x = 0, z = 0 },
		{ module = "Fort_Belier", x = 23, z = 0 },
		{ module = "Fort_Cristal", x = -22, z = 0 },
		{ module = "Fort_Etendard", x = 0, z = -8, solid = false },
	}, with(cornerBanners(), ringCover())),
	stairs = {},
	solids = {},
	loot = {
		{ table = "Caisse", x = 4, y = 0, z = 4 },
		{ table = "Sac", x = -14, y = 0, z = 2 },
		{ table = "Coffre", x = 14, y = 0, z = 0 },
	},
	posts = { { id = MAN, x = 0, y = 0, z = -14 }, { id = MAN, x = -20, y = 0, z = 4 } },
	extract = { x = 33, y = 0, z = 33 },
	altar = { x = 0, y = 0, z = -22 },
}

-- Pont-levis et douves : la douve coupe la tuile (z ∈ [-6, 6]) ; pont-levis et planche étroite.
DEFS.PontLevis = {
	ground = "Cobblestone",
	canal = true,
	buildings = {
		{ module = "Fort_Corps", x = -15, z = -18 },
		{ module = "Fort_Maison", x = 16, z = 18, turns = 2 },
	},
	props = with({
		{ module = "Fort_Barricade", x = 4, z = -10 },
		{ module = "Fort_Chaudiere", x = 22, z = -14 },
		{ module = "Fort_Etendard", x = -20, z = -8, solid = false },
		{ module = "Kit_Caisse", x = 6, z = 12 },
	}, with(cornerBanners(), ringCover())),
	stairs = {},
	-- Pont-levis (10 de large) et planche étroite (3 de large), au niveau des berges.
	solids = {
		{ x = -14, z = 0, w = 10, d = 14, top = 0, material = "WoodPlanks" },
		{ x = 18, z = 0, w = 3, d = 14, top = 0, material = "WoodPlanks" },
	},
	loot = {
		{ table = "Caisse", x = 9, y = 0, z = -10 },
		{ table = "Coffre", x = -2, y = 0, z = 14 },
	},
	posts = { { id = MAN, x = 0, y = 0, z = -12 } },
	extract = { x = 0, y = 0, z = -33 },
}

-- Crypte (unique) : mausolée creux (deux portes), piliers, sarcophages, butin rare ; toit
-- praticable par un escalier extérieur ; lueur violette.
DEFS.Crypte = {
	ground = "Slate",
	buildings = {},
	props = with({
		{ module = "Fort_Sarcophage", x = -2.5, z = 0 },
		{ module = "Fort_Sarcophage", x = 2.5, z = 0 },
		{ module = "Fort_Cristal", x = 9, z = -6 },
		{ module = "Fort_Cristal", x = -20, z = -20 },
	}, with(cornerBanners(), ringCover())),
	-- Escalier le long du mur sud, de x = 2 (sol) à x = -14 (toit), vers -X.
	stairs = { { x = -6, z = 14, turns = 1, rise = 11.5, run = 16, width = 6 } },
	solids = {
		{ x = 0, z = -10, w = 30, d = 2, top = 10, material = "Slate" },
		{ x = 0, z = 10, w = 30, d = 2, top = 10, material = "Slate" },
		{ x = -14, z = -7, w = 2, d = 8, top = 10, material = "Slate" },
		{ x = -14, z = 7, w = 2, d = 8, top = 10, material = "Slate" },
		{ x = 14, z = -7, w = 2, d = 8, top = 10, material = "Slate" },
		{ x = 14, z = 7, w = 2, d = 8, top = 10, material = "Slate" },
		{ x = -7, z = -4, w = 1.6, d = 1.6, top = 10, material = "Slate" },
		{ x = 7, z = -4, w = 1.6, d = 1.6, top = 10, material = "Slate" },
		{ x = -7, z = 4, w = 1.6, d = 1.6, top = 10, material = "Slate" },
		{ x = 7, z = 4, w = 1.6, d = 1.6, top = 10, material = "Slate" },
		{ x = 0, z = 0, w = 30, d = 22, top = 11.5, bottom = 10, material = "Slate" },
	},
	loot = {
		{ table = "Coffre", x = 0, y = 0, z = 6 },
		{ table = "Sac", x = -10, y = 0, z = -6 },
	},
	posts = { { id = MAN, x = -9, y = 0, z = 0 }, { id = MAN, x = 20, y = 0, z = 0 } },
	extract = { x = -33, y = 0, z = -33 },
	altar = { x = 0, y = 0, z = -6 },
	light = { 170, 110, 255 },
}

-- Bord d'Éclat : apparition des escouades, restes d'un campement de siège (aucun Échoué).
DEFS.Bord = {
	ground = "Basalt",
	buildings = {},
	props = with({
		{ module = "Fort_Belier", x = -16, z = -14 },
		{ module = "Fort_Barricade", x = 14, z = -14 },
		{ module = "Kit_Caisse", x = 16, z = -10 },
		{ module = "Kit_Caisse", x = -14, z = 15 },
		{ module = "Fort_Cristal", x = 18, z = 16 },
	}, with(cornerBanners(), ringCover())),
	stairs = {},
	solids = {},
	loot = {
		{ table = "Caisse", x = 10, y = 0, z = -18 },
		{ table = "Sac", x = -18, y = 0, z = 12 },
	},
	posts = {},
	extract = { x = 0, y = 0, z = 33 },
	spawn = { x = 0, y = 0, z = 0 },
}

for _, def in DEFS do
	table.freeze(def)
end
Districts.DEFS = table.freeze(DEFS)

function Districts.get(kind: string): District?
	return DEFS[kind]
end

-- Empreinte au sol d'un module tourné de `turns` quarts de tour : demi-largeurs (x, z).
function Districts.footprint(module: string, turns: number?): (number, number)
	local m = Districts.MODULES[module]
	if m == nil then
		return 0, 0
	end
	if (turns or 0) % 2 == 1 then
		return m.d / 2, m.w / 2
	end
	return m.w / 2, m.d / 2
end

-- Empreinte d'un escalier (rectangle au sol, demi-largeurs x, z).
function Districts.stairFootprint(stair: Stair): (number, number)
	if stair.turns % 2 == 1 then
		return stair.run / 2, stair.width / 2
	end
	return stair.width / 2, stair.run / 2
end

-- Le point (x, y, z) est-il dans un obstacle plein ? (un toit, une plateforme ou un escalier au
-- même niveau ou plus bas compte comme sol).
function Districts.blocked(def: District, x: number, y: number, z: number, margin: number?): boolean
	local m = margin or 0
	for _, b in def.buildings do
		local hx, hz = Districts.footprint(b.module, b.turns)
		local module = Districts.MODULES[b.module]
		local onRoof = module ~= nil and module.roof ~= nil and y >= module.roof - 0.5
		if not onRoof and math.abs(x - b.x) < hx + m and math.abs(z - b.z) < hz + m then
			return true
		end
		local tower = module and module.tower
		if
			onRoof
			and tower
			and math.abs(x - b.x) < tower.w / 2 + m
			and math.abs(z - b.z) < tower.d / 2 + m
		then
			return true
		end
	end
	for _, p in def.props do
		if p.solid ~= false then
			local hx, hz = Districts.footprint(p.module, p.turns)
			local base = p.y or 0
			if
				math.abs(base - y) < 1
				and math.abs(x - p.x) < hx + m
				and math.abs(z - p.z) < hz + m
			then
				return true
			end
		end
	end
	for _, s in def.solids do
		local bottom = s.bottom or 0
		local inside = math.abs(x - s.x) < s.w / 2 + m and math.abs(z - s.z) < s.d / 2 + m
		if inside and y + 0.5 < s.top and y + 2 > bottom then
			return true
		end
	end
	for _, st in def.stairs do
		local hx, hz = Districts.stairFootprint(st)
		if y < 0.5 and math.abs(x - st.x) < hx + m and math.abs(z - st.z) < hz + m then
			return true
		end
	end
	if def.canal and y < 0.5 and math.abs(z) < 6 + m then
		-- Dans l'eau, sauf sur un pont.
		for _, s in def.solids do
			if math.abs(x - s.x) < s.w / 2 and math.abs(z - s.z) < s.d / 2 then
				return false
			end
		end
		return true
	end
	return false
end

-- Un point en hauteur repose-t-il sur un toit ou une plateforme ?
function Districts.supported(def: District, x: number, y: number, z: number): boolean
	if y < 0.5 then
		return true
	end
	for _, s in def.solids do
		if
			math.abs(s.top - y) < 0.5
			and math.abs(x - s.x) <= s.w / 2
			and math.abs(z - s.z) <= s.d / 2
		then
			return true
		end
	end
	for _, b in def.buildings do
		local module = Districts.MODULES[b.module]
		local hx, hz = Districts.footprint(b.module, b.turns)
		if
			module
			and module.roof
			and math.abs(module.roof - y) < 0.5
			and math.abs(x - b.x) <= hx
			and math.abs(z - b.z) <= hz
		then
			return true
		end
	end
	return false
end

return Districts
