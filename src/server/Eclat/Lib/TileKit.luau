--!strict
-- Construction des tuiles de l'Éclat de forteresse (v0.5.0) — GREYBOX PROVISOIRE.
-- Studio : ServerScriptService > Server > Place > Lib > TileKit (place Éclat)
--
-- Chaque tuile (64 × 64 studs, GDD 06 §2) est bâtie en pièces simples pour valider le jeu :
-- sol, îlot de roche dessous, murs de bord selon le plan (Open / Gates / Rampart / Void) et un
-- intérieur propre à son type. Les vrais modules de décor (murs, escaliers, arches, toits) seront
-- modélisés dans Blender puis assemblés à la place de ces blocs (GDD 10, étape 5).
--
-- Repère local d'une tuile : origine au centre, sol à y = 0. Les intérieurs restent dans
-- |x|, |z| ≤ 22 (et tournent avec la tuile) pour ne jamais boucher les passages des bords.

local EclatLayout = require(game:GetService("ReplicatedStorage").Shared.Eclat.EclatLayout)

type Layout = EclatLayout.Layout
type Tile = EclatLayout.Tile
type Direction = EclatLayout.Direction

local HALF = EclatLayout.TILE / 2
local WALL_HEIGHT = 14

local C = {
	stone = Color3.fromRGB(128, 124, 116),
	darkStone = Color3.fromRGB(88, 86, 84),
	paleStone = Color3.fromRGB(170, 164, 150), -- surfaces escaladables, plus claires (GDD 06 §3)
	rock = Color3.fromRGB(74, 70, 72),
	wood = Color3.fromRGB(112, 80, 52),
	darkWood = Color3.fromRGB(78, 56, 38),
	roof = Color3.fromRGB(122, 54, 42),
	grass = Color3.fromRGB(86, 104, 62),
	dirt = Color3.fromRGB(108, 92, 70),
	water = Color3.fromRGB(46, 74, 96),
	banner = Color3.fromRGB(150, 32, 36),
}

type Builder = {
	model: Model,
	center: CFrame, -- centre de la tuile, sans rotation (bords)
	inner: CFrame, -- centre tourné (intérieur)
	rng: EclatLayout.Rng,
}

local TileKit = {}

local function make(
	b: Builder,
	className: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3
): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = b.model
	return part
end

-- Bloc posé : `x, y, z` = centre au sol de la base (y = bas du bloc), dans le repère `frame`.
local function block(
	b: Builder,
	frame: CFrame,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	material: Enum.Material,
	color: Color3,
	yaw: number?
): BasePart
	local cf = frame * CFrame.new(x, y + size.Y / 2, z) * CFrame.Angles(0, yaw or 0, 0)
	return make(b, "Part", size, cf, material, color)
end

-- Rampe droite de `from` (bas) à `to` (haut), largeur `width` (repère `frame`).
local function ramp(b: Builder, frame: CFrame, from: Vector3, to: Vector3, width: number): BasePart
	local a = frame:PointToWorldSpace(from)
	local c = frame:PointToWorldSpace(to)
	local length = (c - a).Magnitude
	local mid = (a + c) / 2
	-- La plaque est posée 0,5 stud sous la ligne pour que le dessus affleure la pente.
	local cf = CFrame.lookAt(mid, c) * CFrame.new(0, -0.5, 0)
	return make(
		b,
		"Part",
		Vector3.new(width, 1, length),
		cf,
		Enum.Material.Cobblestone,
		C.paleStone
	)
end

-- Créneaux sur un mur de longueur `length` (axe x local du repère `frame`).
local function crenels(b: Builder, frame: CFrame, length: number, top: number, thickness: number)
	local count = math.floor(length / 6)
	for i = 0, count - 1 do
		local x = -length / 2 + 3 + i * 6
		block(b, frame, Vector3.new(3, 2.5, thickness), x, top, 0, Enum.Material.Slate, C.stone)
	end
end

-- Pièce de mur le long de l'axe x local, de x0 à x1.
local function wallSegment(
	b: Builder,
	frame: CFrame,
	x0: number,
	x1: number,
	height: number,
	thickness: number,
	withCrenels: boolean
)
	local length = x1 - x0
	if length <= 0.5 then
		return
	end
	local mid = (x0 + x1) / 2
	block(b, frame, Vector3.new(length, height, thickness), mid, 0, 0, Enum.Material.Slate, C.stone)
	if withCrenels then
		crenels(b, frame * CFrame.new(mid, 0, 0), length, height, thickness)
	end
end

local EDGE_YAW: { [Direction]: number } = {
	N = 0,
	W = math.pi / 2,
	S = math.pi,
	E = -math.pi / 2,
}

-- Bord de tuile : repère dont l'axe x longe le bord, -z vers l'extérieur, à z = 0 sur la ligne.
local function edgeFrame(b: Builder, dir: Direction): CFrame
	return b.center * CFrame.Angles(0, EDGE_YAW[dir], 0) * CFrame.new(0, 0, -HALF)
end

local function buildEdge(b: Builder, dir: Direction, kind: EclatLayout.EdgeKind)
	local frame = edgeFrame(b, dir)
	if kind == "Gates" then
		-- Deux portes de 10 studs.
		wallSegment(b, frame, -HALF, -21, WALL_HEIGHT, 4, true)
		wallSegment(b, frame, -11, 11, WALL_HEIGHT, 4, true)
		wallSegment(b, frame, 21, HALF, WALL_HEIGHT, 4, true)
		for _, x in { -16, 16 } do
			-- Linteau au-dessus de chaque porte.
			block(
				b,
				frame,
				Vector3.new(10, 3, 4),
				x,
				WALL_HEIGHT - 3,
				0,
				Enum.Material.Slate,
				C.darkStone
			)
		end
	elseif kind == "Rampart" then
		-- Une porte au sol et un chemin de ronde (mur épais) atteint par deux rampes.
		wallSegment(b, frame, -HALF, -5, WALL_HEIGHT, 6, false)
		wallSegment(b, frame, 5, HALF, WALL_HEIGHT, 6, false)
		block(
			b,
			frame,
			Vector3.new(10, 4, 6),
			0,
			WALL_HEIGHT - 4,
			0,
			Enum.Material.Slate,
			C.darkStone
		)
		-- Parapet côté extérieur seulement (le chemin reste praticable).
		for i = 0, 9 do
			local x = -HALF + 3 + i * 6.4
			block(
				b,
				frame,
				Vector3.new(3, 2.5, 1.5),
				x,
				WALL_HEIGHT,
				-2.25,
				Enum.Material.Slate,
				C.stone
			)
		end
		ramp(b, frame, Vector3.new(28, 0, 5.5), Vector3.new(7, WALL_HEIGHT, 5.5), 5)
		ramp(b, frame, Vector3.new(-28, 0, -5.5), Vector3.new(-7, WALL_HEIGHT, -5.5), 5)
	elseif kind == "Open" then
		-- Pas de mur : deux souches de mur effondrées marquent la limite.
		block(b, frame, Vector3.new(7, 3, 4), -HALF + 3.5, 0, 0, Enum.Material.Slate, C.darkStone)
		block(b, frame, Vector3.new(5, 2, 4), HALF - 2.5, 0, 0, Enum.Material.Slate, C.darkStone)
	else
		-- Le Vide : bord de roche qui s'effrite, quelques pierres.
		for i = 0, 5 do
			local x = -HALF + 5 + i * 10.8 + (EclatLayout.nextFloat(b.rng) - 0.5) * 4
			local h = 0.8 + EclatLayout.nextFloat(b.rng) * 1.6
			block(
				b,
				frame,
				Vector3.new(3 + EclatLayout.nextFloat(b.rng) * 3, h, 3),
				x,
				0,
				1.5,
				Enum.Material.Basalt,
				C.rock,
				EclatLayout.nextFloat(b.rng)
			)
		end
		-- Fragments figés qui flottent au-delà du bord (décor, GDD 10).
		for _ = 1, 3 do
			local s = 1.5 + EclatLayout.nextFloat(b.rng) * 3
			local piece = block(
				b,
				frame,
				Vector3.new(s, s, s),
				(EclatLayout.nextFloat(b.rng) - 0.5) * 56,
				-4 + EclatLayout.nextFloat(b.rng) * 10,
				-6 - EclatLayout.nextFloat(b.rng) * 12,
				Enum.Material.Basalt,
				C.rock,
				EclatLayout.nextFloat(b.rng) * 6
			)
			piece.CanCollide = false
			piece:SetAttribute("Floating", true)
		end
	end
end

-- Sol + îlot de roche suspendu dans le Vide.
local function ground(b: Builder, material: Enum.Material, color: Color3, split: boolean)
	local T = EclatLayout.TILE
	if not split then
		block(b, b.center, Vector3.new(T, 4, T), 0, -4, 0, material, color)
	end
	block(b, b.center, Vector3.new(T - 6, 14, T - 6), 0, -18, 0, Enum.Material.Basalt, C.rock)
	block(b, b.center, Vector3.new(T - 22, 16, T - 22), 0, -34, 0, Enum.Material.Basalt, C.rock)
end

local function crate(b: Builder, x: number, z: number, size: number?)
	local s = size or 4
	block(b, b.inner, Vector3.new(s, s, s), x, 0, z, Enum.Material.WoodPlanks, C.wood)
end

local function barricade(b: Builder, x: number, z: number, yaw: number)
	block(b, b.inner, Vector3.new(9, 3.2, 1.6), x, 0, z, Enum.Material.WoodPlanks, C.darkWood, yaw)
end

local function house(b: Builder, x: number, z: number, w: number, d: number, h: number, yaw: number)
	local base = block(
		b,
		b.inner,
		Vector3.new(w, h, d),
		x,
		0,
		z,
		Enum.Material.Plaster,
		Color3.fromRGB(196, 184, 160),
		yaw
	)
	-- Toit à deux pans : deux plaques inclinées.
	local top = base.CFrame * CFrame.new(0, h / 2, 0)
	local pitch = math.rad(32)
	local half = w / 2 + 0.8
	local slope = half / math.cos(pitch)
	for _, side in { -1, 1 } do
		local cf = top
			* CFrame.new(side * half / 2, math.tan(pitch) * half / 2, 0)
			* CFrame.Angles(0, 0, -side * pitch)
		make(b, "Part", Vector3.new(slope, 0.8, d + 1.2), cf, Enum.Material.WoodPlanks, C.roof)
	end
end

local function tower(b: Builder, x: number, z: number, w: number, h: number)
	block(b, b.inner, Vector3.new(w, h, w), x, 0, z, Enum.Material.Slate, C.stone)
	crenels(b, b.inner * CFrame.new(x, 0, z - w / 2 + 0.75), w, h, 1.5)
	crenels(b, b.inner * CFrame.new(x, 0, z + w / 2 - 0.75), w, h, 1.5)
end

local function banner(b: Builder, x: number, y: number, z: number, yaw: number)
	local pole =
		block(b, b.inner, Vector3.new(0.4, 7, 0.4), x, y, z, Enum.Material.Wood, C.darkWood)
	pole.CanCollide = false
	local cloth = make(
		b,
		"Part",
		Vector3.new(0.1, 4, 2.4),
		b.inner * CFrame.new(x, y + 4.5, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 1.3),
		Enum.Material.Fabric,
		C.banner
	)
	cloth.CanCollide = false
end

-- Intérieurs -------------------------------------------------------------------------------

local INTERIORS: { [string]: (Builder) -> () } = {}

INTERIORS.Donjon = function(b)
	-- Le donjon : un bloc massif à toit praticable, quatre tourelles, une rampe d'accès.
	block(b, b.inner, Vector3.new(24, 16, 24), 0, 0, 0, Enum.Material.Slate, C.darkStone)
	for _, p in { { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } } do
		tower(b, p[1], p[2], 6, 22)
	end
	ramp(b, b.inner, Vector3.new(-14.5, 0, 21), Vector3.new(-14.5, 16, -3), 5)
	ramp(b, b.inner, Vector3.new(14.5, 0, -21), Vector3.new(14.5, 16, 3), 5)
	banner(b, 0, 16, 0, 0)
	-- Emplacement de la future Faille finale (v0.6+).
	local rift = block(
		b,
		b.inner,
		Vector3.new(6, 0.2, 6),
		0,
		16,
		-8,
		Enum.Material.Neon,
		Color3.fromRGB(255, 140, 60)
	)
	rift.Name = "RiftMarker"
	rift.CanCollide = false
	rift.Transparency = 0.6
end

INTERIORS.CourArmes = function(b)
	-- Cour ouverte : couverts tous les ~16 studs (GDD 06 §3).
	for _, p in { { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } } do
		crate(b, p[1], p[2], 4)
		crate(b, p[1] + 3, p[2] + 1, 3)
	end
	barricade(b, 0, -9, 0)
	barricade(b, 0, 9, 0)
	barricade(b, -9, 0, math.pi / 2)
	barricade(b, 9, 0, math.pi / 2)
	block(b, b.inner, Vector3.new(8, 1.2, 8), 0, 0, 0, Enum.Material.Cobblestone, C.paleStone)
	for _, x in { -20, 20 } do
		-- Râteliers d'armes.
		block(b, b.inner, Vector3.new(1, 5, 6), x, 0, 0, Enum.Material.Wood, C.darkWood)
	end
	banner(b, -20, 0, -20, math.pi / 4)
end

INTERIORS.Remparts = function(b)
	-- Un mur intérieur en L avec chemin de ronde.
	local h = 12
	block(b, b.inner, Vector3.new(36, h, 6), -2, 0, -8, Enum.Material.Slate, C.stone)
	block(b, b.inner, Vector3.new(6, h, 22), 13, 0, 6, Enum.Material.Slate, C.stone)
	crenels(b, b.inner * CFrame.new(-2, 0, -10.25), 36, h, 1.5)
	ramp(b, b.inner, Vector3.new(-20, 0, -2.5), Vector3.new(-2, h, -2.5), 5)
	ramp(b, b.inner, Vector3.new(19.5, 0, 20), Vector3.new(19.5, h, 3), 5)
	block(b, b.inner, Vector3.new(8, 6, 8), -14, 0, 14, Enum.Material.WoodPlanks, C.wood)
	crate(b, 2, 12)
	banner(b, -2, h, -8, 0)
end

INTERIORS.TourGuet = function(b)
	-- Tour de guet : deux rampes en spirale jusqu'au sommet (verticalité très forte).
	local h = 24
	block(b, b.inner, Vector3.new(12, h, 12), 8, 0, 8, Enum.Material.Slate, C.stone)
	ramp(b, b.inner, Vector3.new(-1.5, 0, 22), Vector3.new(-1.5, 12, 2), 5)
	block(b, b.inner, Vector3.new(18, 1, 6), 5, 11, -1, Enum.Material.WoodPlanks, C.wood)
	ramp(b, b.inner, Vector3.new(16.5, 12, -1), Vector3.new(16.5, h, 18), 5)
	block(b, b.inner, Vector3.new(17, 1, 6), 10.5, h - 1, 17, Enum.Material.WoodPlanks, C.wood)
	crenels(b, b.inner * CFrame.new(8, 0, 2.75), 12, h, 1.5)
	local beacon = block(
		b,
		b.inner,
		Vector3.new(2, 2, 2),
		8,
		h,
		8,
		Enum.Material.Neon,
		Color3.fromRGB(255, 150, 70)
	)
	beacon.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = beacon
	crate(b, -14, -14)
	barricade(b, -12, -4, 0.4)
end

INTERIORS.Village = function(b)
	house(b, -13, -13, 12, 10, 8, 0)
	house(b, 13, -14, 10, 12, 7, math.pi / 2)
	house(b, -14, 13, 10, 10, 7, math.pi / 2)
	house(b, 13, 13, 12, 10, 9, 0)
	-- Puits.
	block(b, b.inner, Vector3.new(5, 3, 5), 0, 0, 0, Enum.Material.Cobblestone, C.paleStone)
	crate(b, 5, -4, 3)
	crate(b, -5, 5, 3)
	block(b, b.inner, Vector3.new(6, 3.5, 3), 4, 0, 6, Enum.Material.WoodPlanks, C.wood) -- étal
end

INTERIORS.PontLevis = function(b)
	-- Douve en travers de la tuile : le pont-levis et une planche étroite (deux passages).
	local T = EclatLayout.TILE
	block(b, b.inner, Vector3.new(T, 4, 27), 0, -4, -18.5, Enum.Material.Cobblestone, C.stone)
	block(b, b.inner, Vector3.new(T, 4, 27), 0, -4, 18.5, Enum.Material.Cobblestone, C.stone)
	block(b, b.inner, Vector3.new(T, 2, 10), 0, -10, 0, Enum.Material.Mud, C.dirt)
	local water = block(b, b.inner, Vector3.new(T, 3, 10), 0, -8, 0, Enum.Material.Glass, C.water)
	water.Transparency = 0.35
	water.CanCollide = false
	-- Remontée depuis la douve.
	ramp(b, b.inner, Vector3.new(14, -8, 0), Vector3.new(26, 0, 0), 6)
	-- Pont-levis.
	block(b, b.inner, Vector3.new(8, 1, 12), -12, -1, 0, Enum.Material.WoodPlanks, C.wood)
	for _, x in { -16.5, -7.5 } do
		tower(b, x, -8.5, 4, 10)
	end
	block(b, b.inner, Vector3.new(13, 3, 4), -12, 10, -8.5, Enum.Material.Slate, C.darkStone)
	-- Planche étroite.
	block(b, b.inner, Vector3.new(3, 0.6, 12), 16, -0.6, 0, Enum.Material.WoodPlanks, C.darkWood)
	crate(b, -18, 16)
	barricade(b, 8, 14, 0.2)
end

INTERIORS.Crypte = function(b)
	-- Mausolée creux : deux entrées, piliers, sarcophages ; toit praticable.
	local w, d, h, t = 30, 22, 10, 2
	block(b, b.inner, Vector3.new(w, h, t), 0, 0, -d / 2 + t / 2, Enum.Material.Slate, C.darkStone)
	block(b, b.inner, Vector3.new(w, h, t), 0, 0, d / 2 - t / 2, Enum.Material.Slate, C.darkStone)
	for _, x in { -w / 2 + t / 2, w / 2 - t / 2 } do
		block(b, b.inner, Vector3.new(t, h, 8), x, 0, -7, Enum.Material.Slate, C.darkStone)
		block(b, b.inner, Vector3.new(t, h, 8), x, 0, 7, Enum.Material.Slate, C.darkStone)
		block(b, b.inner, Vector3.new(t, 3, 6), x, h - 3, 0, Enum.Material.Slate, C.darkStone)
	end
	block(b, b.inner, Vector3.new(w, 1.5, d), 0, h, 0, Enum.Material.Slate, C.stone)
	for _, p in { { -7, -4 }, { 7, -4 }, { -7, 4 }, { 7, 4 } } do
		block(b, b.inner, Vector3.new(1.6, h, 1.6), p[1], 0, p[2], Enum.Material.Slate, C.stone)
	end
	block(b, b.inner, Vector3.new(3, 2.2, 6), -2.5, 0, 0, Enum.Material.Marble, C.paleStone)
	block(b, b.inner, Vector3.new(3, 2.2, 6), 2.5, 0, 0, Enum.Material.Marble, C.paleStone)
	ramp(b, b.inner, Vector3.new(-21, 0, 15), Vector3.new(-6, h + 1.5, 15), 5)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 90, 255)
	glow.Range = 16
	glow.Brightness = 1
	local holder = block(
		b,
		b.inner,
		Vector3.new(1, 1, 1),
		0,
		5,
		0,
		Enum.Material.Neon,
		Color3.fromRGB(150, 90, 255)
	)
	holder.CanCollide = false
	holder.Transparency = 0.5
	glow.Parent = holder
end

INTERIORS.Bord = function(b)
	-- Bord d'Éclat : roche à nu, murets brisés ; une escouade apparaît ici.
	for _ = 1, 6 do
		local s = 2 + EclatLayout.nextFloat(b.rng) * 3
		block(
			b,
			b.inner,
			Vector3.new(s * 1.4, s, s),
			(EclatLayout.nextFloat(b.rng) - 0.5) * 40,
			0,
			(EclatLayout.nextFloat(b.rng) - 0.5) * 40,
			Enum.Material.Basalt,
			C.rock,
			EclatLayout.nextFloat(b.rng) * 6
		)
	end
	block(b, b.inner, Vector3.new(14, 4, 2), -10, 0, -16, Enum.Material.Slate, C.darkStone, 0.2)
	block(b, b.inner, Vector3.new(10, 3, 2), 12, 0, 14, Enum.Material.Slate, C.darkStone, -0.3)
	local spawn =
		block(b, b.inner, Vector3.new(8, 0.2, 8), 0, 0, 0, Enum.Material.Slate, C.paleStone)
	spawn.Name = "SquadSpawn"
end

local GROUND: { [string]: { material: Enum.Material, color: Color3 } } = {
	Donjon = { material = Enum.Material.Slate, color = C.stone },
	CourArmes = { material = Enum.Material.Cobblestone, color = C.stone },
	Remparts = { material = Enum.Material.Cobblestone, color = C.darkStone },
	TourGuet = { material = Enum.Material.Grass, color = C.grass },
	Village = { material = Enum.Material.Ground, color = C.dirt },
	PontLevis = { material = Enum.Material.Cobblestone, color = C.stone },
	Crypte = { material = Enum.Material.Slate, color = C.darkStone },
	Bord = { material = Enum.Material.Basalt, color = C.rock },
}

-- Construit une tuile (Model) sans la ranger dans le monde.
function TileKit.build(layout: Layout, tile: Tile): Model
	local cx, cz = EclatLayout.tileCenter(layout, tile.x, tile.z)
	local model = Instance.new("Model")
	model.Name = `Tile_{tile.x}_{tile.z}`
	model:SetAttribute("Kind", tile.kind)
	model:SetAttribute("TileX", tile.x)
	model:SetAttribute("TileZ", tile.z)
	local center = CFrame.new(cx, 0, cz)
	local b: Builder = {
		model = model,
		center = center,
		inner = center * CFrame.Angles(0, tile.rotation * math.pi / 2, 0),
		rng = EclatLayout.rng(layout.seed * 31 + EclatLayout.index(layout, tile.x, tile.z)),
	}
	local g = GROUND[tile.kind]
	ground(b, g.material, g.color, tile.kind == "PontLevis")
	-- Bords nord et ouest (le bord appartient à la tuile au nord / à l'ouest) ; sud et est
	-- seulement sur le pourtour de la grille.
	for _, dir in EclatLayout.DIRECTIONS do
		local kind = EclatLayout.edge(layout, tile.x, tile.z, dir)
		local owner = dir == "N" or dir == "W" or kind == "Void"
		if owner then
			buildEdge(b, dir, kind)
		end
	end
	-- Pilier au coin nord-ouest si un mur y arrive.
	local n = EclatLayout.edge(layout, tile.x, tile.z, "N")
	local w = EclatLayout.edge(layout, tile.x, tile.z, "W")
	if n == "Gates" or n == "Rampart" or w == "Gates" or w == "Rampart" then
		block(
			b,
			b.center,
			Vector3.new(7, WALL_HEIGHT + 4, 7),
			-HALF,
			0,
			-HALF,
			Enum.Material.Slate,
			C.darkStone
		)
	end
	local interior = INTERIORS[tile.kind]
	if interior then
		interior(b)
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	return model
end

return TileKit
