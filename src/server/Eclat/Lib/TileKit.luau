--!strict
-- Construction des tuiles de la forteresse de l'Éclat (v0.11.0 : carte agrandie 7 × 7, tuiles de
-- 96 studs ; greybox de la v0.5 en 5 × 5).
-- Studio : ServerScriptService > Server > Place > Lib > TileKit (place Éclat)
--
-- Chaque tuile : un îlot pavé suspendu dans le Vide, le contenu décrit par Shared/Eclat/Districts
-- (bâtiments, escaliers, plateformes, décor de siège), et les bords (grille de 8 studs) :
--   * Gates   : courtine percée de deux portes de 10 studs ;
--   * Rampart : rempart épais (6) au chemin de ronde praticable à 14, une porte, deux escaliers ;
--   * Open    : brèche dans la courtine, éboulis bas ;
--   * Void    : bord de roche qui s'effrite, éclats figés qui flottent au-delà.
-- Une tourelle occupe chaque angle intérieur (les courtines s'arrêtent à 40 studs du centre).
-- Modules Blender dans ServerStorage > FortressKit (repli : blocs à leurs dimensions de maquette).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EclatLayout = require(Shared.Eclat.EclatLayout)
local Districts = require(Shared.Eclat.Districts)
local Kit = require(script.Parent.Kit)

type Layout = EclatLayout.Layout
type Tile = EclatLayout.Tile
type Direction = EclatLayout.Direction

local HALF = EclatLayout.TILE / 2
local ROW_END = 40 -- les rangées d'immeubles s'arrêtent avant le carrefour

local C = {
	street = Color3.fromRGB(122, 116, 108),
	paleStone = Color3.fromRGB(178, 170, 154),
	darkStone = Color3.fromRGB(92, 90, 88),
	rock = Color3.fromRGB(74, 70, 72),
	brick = Color3.fromRGB(150, 84, 64),
	iron = Color3.fromRGB(56, 58, 64),
	wood = Color3.fromRGB(120, 86, 56),
	water = Color3.fromRGB(46, 96, 112),
	grass = Color3.fromRGB(82, 108, 70),
	plaster = Color3.fromRGB(226, 212, 180),
}

-- Repli greybox d'un module (couleur et matériau dominants).
local FALLBACK: { [string]: { material: Enum.Material, color: Color3 } } = {
	Fort_Donjon = { material = Enum.Material.Slate, color = Color3.fromRGB(108, 112, 120) },
	Fort_TourGuet = { material = Enum.Material.Slate, color = C.paleStone },
	Fort_Maison = { material = Enum.Material.Plaster, color = C.plaster },
	Fort_GrandeMaison = { material = Enum.Material.Plaster, color = Color3.fromRGB(206, 192, 164) },
	Fort_Corps = { material = Enum.Material.Slate, color = C.darkStone },
	Fort_Mur = { material = Enum.Material.Slate, color = Color3.fromRGB(128, 130, 138) },
	Fort_Porte = { material = Enum.Material.Slate, color = C.darkStone },
	Fort_Rempart = { material = Enum.Material.Slate, color = Color3.fromRGB(120, 122, 130) },
	Fort_Tourelle = { material = Enum.Material.Slate, color = C.darkStone },
	Fort_Escalier = { material = Enum.Material.Slate, color = C.paleStone },
	Fort_Trebuchet = { material = Enum.Material.WoodPlanks, color = C.wood },
	Fort_Belier = { material = Enum.Material.WoodPlanks, color = C.wood },
	Fort_Barricade = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(96, 70, 46) },
	Fort_Chaudiere = { material = Enum.Material.Metal, color = Color3.fromRGB(176, 128, 58) },
	Fort_Horloge = { material = Enum.Material.Metal, color = Color3.fromRGB(176, 128, 58) },
	Fort_Cloche = { material = Enum.Material.Metal, color = Color3.fromRGB(150, 120, 60) },
	Fort_Puits = { material = Enum.Material.Cobblestone, color = C.paleStone },
	Fort_Ratelier = { material = Enum.Material.Wood, color = C.wood },
	Fort_Sarcophage = { material = Enum.Material.Marble, color = Color3.fromRGB(200, 196, 186) },
	Fort_Cristal = { material = Enum.Material.Neon, color = Color3.fromRGB(80, 230, 255) },
	Fort_Etendard = { material = Enum.Material.Fabric, color = Color3.fromRGB(140, 34, 36) },
	Fort_Eboulis = { material = Enum.Material.Slate, color = C.darkStone },
	Kit_Caisse = { material = Enum.Material.WoodPlanks, color = C.wood },
	Kit_Coffre = { material = Enum.Material.WoodPlanks, color = C.wood },
}

-- Sols modélisés posés sur l'îlot selon son matériau (dessus des dalles ≈ 0,65 au-dessus de leur
-- origine : on les enfonce pour que le sol de jeu reste à y = 0).
local FLOORS: { [string]: string } = { Slate = "Fort_Dalle", Cobblestone = "Fort_Pave" }
local FLOOR_Y = -0.6

local GROUND: { [string]: { material: Enum.Material, color: Color3 } } = {
	Slate = { material = Enum.Material.Slate, color = C.paleStone },
	Cobblestone = { material = Enum.Material.Cobblestone, color = Color3.fromRGB(138, 130, 120) },
	Concrete = { material = Enum.Material.Concrete, color = Color3.fromRGB(110, 106, 100) },
	Grass = { material = Enum.Material.Grass, color = C.grass },
	Brick = { material = Enum.Material.Brick, color = C.brick },
	Ground = { material = Enum.Material.Ground, color = Color3.fromRGB(108, 92, 70) },
	Basalt = { material = Enum.Material.Basalt, color = C.rock },
	WoodPlanks = { material = Enum.Material.WoodPlanks, color = C.wood },
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
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3
): BasePart
	local part = Instance.new("Part")
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

-- Bloc posé : base au sol en (x, y, z) dans le repère `frame`.
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
	return make(b, size, cf, material, color)
end

-- Pose un module de la Cité (origine = bas au centre) avec un facteur d'étirement en X ; repli
-- greybox à la taille de son empreinte. `solid = false` : décor traversable.
local function module(
	b: Builder,
	frame: CFrame,
	name: string,
	x: number,
	y: number,
	z: number,
	yaw: number,
	stretchX: number?,
	solid: boolean?
)
	local cf = frame * CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local sx = stretchX or 1
	local placed = Kit.placeScaled(name, cf, Vector3.new(sx, 1, 1))
	if placed then
		for _, d in placed:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = d.CanCollide and solid ~= false
			end
		end
		placed.Parent = b.model
		return
	end
	local m = Districts.MODULES[name]
	local look = FALLBACK[name]
	if m == nil or look == nil then
		return
	end
	if name == "Fort_Porte" then
		-- Maquette d'une porte : seulement le linteau (le passage reste libre sous 11 studs).
		local lintel = make(
			b,
			Vector3.new(m.w * sx, 3, m.d + 0.4),
			cf * CFrame.new(0, m.h - 1.5, 0),
			look.material,
			look.color
		)
		lintel.Name = name
		return
	end
	-- Maquette : un bâtiment à toit praticable s'arrête à la hauteur de son toit.
	local height = m.roof or m.h
	local part = make(
		b,
		Vector3.new(m.w * sx, height, m.d),
		cf * CFrame.new(0, height / 2, 0),
		look.material,
		look.color
	)
	part.Name = name
	part.CanCollide = solid ~= false
	-- Tour centrale au-dessus de la terrasse (Donjon) : le repère de la carte.
	if m.tower then
		local tower = make(
			b,
			Vector3.new(m.tower.w, m.tower.h - height, m.tower.d),
			cf * CFrame.new(0, height + (m.tower.h - height) / 2, 0),
			look.material,
			look.color
		)
		tower.Name = name .. "_Tour"
	end
end

-- Lueur d'un lampadaire (même s'il est en greybox).
local function lampLight(b: Builder, frame: CFrame, x: number, y: number, z: number)
	local glow = make(
		b,
		Vector3.new(0.6, 0.6, 0.6),
		frame * CFrame.new(x, y + 7.5, z),
		Enum.Material.Neon,
		Color3.fromRGB(80, 230, 255)
	)
	glow.Name = "Lueur"
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 230, 255)
	light.Range = 16
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = glow
end

-- Escalier : le module étiré pour monter de `rise` sur `run` (vers -Z du repère tourné).
local function stair(
	b: Builder,
	frame: CFrame,
	x: number,
	z: number,
	yaw: number,
	rise: number,
	run: number,
	width: number,
	y: number?
)
	local m = Districts.MODULES.Fort_Escalier
	local cf = frame * CFrame.new(x, y or 0, z) * CFrame.Angles(0, yaw, 0)
	local placed =
		Kit.placeScaled("Fort_Escalier", cf, Vector3.new(width / m.w, rise / m.h, run / m.d))
	if placed then
		-- Les marches étirées sont trop hautes pour être gravies : on marche sur une rampe
		-- invisible, les marches ne servent qu'au rendu.
		for _, d in placed:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		placed.Parent = b.model
	end
	local a = cf:PointToWorldSpace(Vector3.new(0, 0, run / 2))
	local c = cf:PointToWorldSpace(Vector3.new(0, rise, -run / 2))
	local length = (c - a).Magnitude
	local ramp = make(
		b,
		Vector3.new(width, 1, length),
		CFrame.lookAt((a + c) / 2, c) * CFrame.new(0, -0.5, 0),
		Enum.Material.Slate,
		C.paleStone
	)
	ramp.Name = "Rampe"
	if placed then
		ramp.Transparency = 1
	end
end

-- Bords ------------------------------------------------------------------------------------

local EDGE_YAW: { [Direction]: number } = {
	N = 0,
	W = math.pi / 2,
	S = math.pi,
	E = -math.pi / 2,
}

-- Repère d'un bord : x longe le bord, -z vers l'extérieur de la tuile, z = 0 sur la ligne.
local function edgeFrame(b: Builder, dir: Direction): CFrame
	return b.center * CFrame.Angles(0, EDGE_YAW[dir], 0) * CFrame.new(0, 0, -HALF)
end

-- Courtine de x0 à x1 (modules de 8 studs, étirés juste ce qu'il faut).
local function curtain(b: Builder, frame: CFrame, x0: number, x1: number, name: string)
	local length = x1 - x0
	if length <= 0.5 then
		return
	end
	local m = Districts.MODULES[name]
	local count = math.max(1, math.floor(length / m.w + 0.5))
	local width = length / count
	for i = 1, count do
		module(b, frame, name, x0 + width * (i - 0.5), 0, 0, 0, width / m.w)
	end
end

local RAMPART_TOP = Districts.MODULES.Fort_Rempart.h

local function buildEdge(b: Builder, dir: Direction, kind: EclatLayout.EdgeKind)
	local frame = edgeFrame(b, dir)
	if kind == "Gates" then
		-- Deux portes de 10 studs (x ∈ [-22, -12] et [12, 22]).
		curtain(b, frame, -ROW_END, -22, "Fort_Mur")
		curtain(b, frame, -12, 12, "Fort_Mur")
		curtain(b, frame, 22, ROW_END, "Fort_Mur")
		for _, x in { -17, 17 } do
			module(b, frame, "Fort_Porte", x, 0, 0, 0)
		end
	elseif kind == "Rampart" then
		-- Rempart épais : une porte au centre, chemin de ronde praticable, deux escaliers (un de
		-- chaque côté) collés aux extrémités pour ne pas gêner la porte.
		curtain(b, frame, -ROW_END, -5, "Fort_Rempart")
		curtain(b, frame, 5, ROW_END, "Fort_Rempart")
		module(b, frame, "Fort_Porte", 0, 0, 0, 0)
		stair(b, frame, -30, 3 + 8, 0, RAMPART_TOP, 16, 6)
		stair(b, frame, 30, -(3 + 8), math.pi, RAMPART_TOP, 16, 6)
	elseif kind == "Open" then
		-- Brèche : la courtine s'est effondrée ; éboulis bas aux extrémités (couverts).
		for _, x in { -34, 34 } do
			block(
				b,
				frame,
				Vector3.new(10, 3, 5),
				x,
				0,
				0,
				Enum.Material.Slate,
				C.darkStone,
				x * 0.004
			)
			block(
				b,
				frame,
				Vector3.new(5, 2, 4),
				x * 0.8,
				0,
				2,
				Enum.Material.Slate,
				C.darkStone,
				0.4
			)
		end
	else
		-- Le Vide : roche qui s'effrite, éclats figés au-delà.
		for i = 0, 7 do
			local x = -HALF + 6 + i * 12 + (EclatLayout.nextFloat(b.rng) - 0.5) * 4
			local h = 0.8 + EclatLayout.nextFloat(b.rng) * 1.8
			block(
				b,
				frame,
				Vector3.new(3 + EclatLayout.nextFloat(b.rng) * 4, h, 3),
				x,
				0,
				1.5,
				Enum.Material.Basalt,
				C.rock,
				EclatLayout.nextFloat(b.rng)
			)
		end
		for _ = 1, 4 do
			local s = 1.5 + EclatLayout.nextFloat(b.rng) * 3.5
			local piece = block(
				b,
				frame,
				Vector3.new(s * 1.3, s, s),
				(EclatLayout.nextFloat(b.rng) - 0.5) * 84,
				-6 + EclatLayout.nextFloat(b.rng) * 14,
				-8 - EclatLayout.nextFloat(b.rng) * 18,
				Enum.Material.Basalt,
				C.rock,
				EclatLayout.nextFloat(b.rng) * 6
			)
			piece.CanCollide = false
			piece:SetAttribute("Floating", true)
		end
	end
end

-- Sol : rue pavée, îlot central au sol du quartier, roche suspendue dessous ; canal éventuel.
local function ground(b: Builder, def: Districts.District)
	local T = EclatLayout.TILE
	local cobble = Enum.Material.Cobblestone
	if def.canal then
		-- Deux berges (le canal coupe la tuile en z ∈ [-6, 6] du repère tourné).
		local bank = (T - 12) / 2
		block(b, b.inner, Vector3.new(T, 4, bank), 0, -4, -6 - bank / 2, cobble, C.street)
		block(b, b.inner, Vector3.new(T, 4, bank), 0, -4, 6 + bank / 2, cobble, C.street)
		block(b, b.inner, Vector3.new(T, 2, 12), 0, -10, 0, Enum.Material.Slate, C.darkStone)
		local water =
			block(b, b.inner, Vector3.new(T, 4, 12), 0, -8, 0, Enum.Material.Glass, C.water)
		water.Name = "Eau"
		water.Transparency = 0.3
		water.CanCollide = false
		-- Murs des quais et remontées (escaliers) aux deux bouts.
		for _, side in { -1, 1 } do
			block(
				b,
				b.inner,
				Vector3.new(T, 8, 0.8),
				0,
				-8,
				side * 6.4,
				Enum.Material.Slate,
				C.darkStone
			)
		end
		-- Un escalier dans le canal à chaque bout : il remonte du fond (-8) vers une berge.
		stair(b, b.inner, -36, 0, 0, 8, 11, 4, -8)
		stair(b, b.inner, 36, 0, math.pi, 8, 11, 4, -8)
	else
		block(b, b.center, Vector3.new(T, 4, T), 0, -4, 0, cobble, C.street)
	end
	local look = GROUND[def.ground] or GROUND.Cobblestone
	if not def.canal then
		local plaza = block(
			b,
			b.inner,
			Vector3.new(Districts.BLOCK * 2, 0.2, Districts.BLOCK * 2),
			0,
			0,
			0,
			look.material,
			look.color
		)
		plaza.Name = "Ilot"
		-- Dallage ou pavage modélisé (v0.12) : dessus à fleur du sol de jeu (y ≈ 0).
		local floor = FLOORS[def.ground]
		if floor and Kit.has(floor) then
			for i = -3, 3 do
				for j = -3, 3 do
					local name = floor
					if floor == "Fort_Dalle" and (i * 5 + j * 3) % 7 == 0 then
						name = "Fort_DalleFissure"
					end
					local turn = ((i * 7 + j * 13) % 4) * math.pi / 2
					local cf = b.inner
						* CFrame.new(i * 8, FLOOR_Y, j * 8)
						* CFrame.Angles(0, turn, 0)
					local placed = Kit.placeScaled(name, cf, Vector3.one)
					if placed then
						placed.Parent = b.model
					end
				end
			end
		end
	end
	-- Trottoirs : bordures autour de l'îlot.
	block(b, b.center, Vector3.new(T - 6, 14, T - 6), 0, -18, 0, Enum.Material.Basalt, C.rock)
	block(b, b.center, Vector3.new(T - 26, 18, T - 26), 0, -36, 0, Enum.Material.Basalt, C.rock)
	block(b, b.center, Vector3.new(T - 50, 14, T - 50), 0, -50, 0, Enum.Material.Basalt, C.rock)
end

-- Intérieur du quartier ----------------------------------------------------------------------

-- Habille une plateforme avec son module (v0.12) : tour de guet posée telle quelle, remparts
-- alignés sur la longueur et étirés à la hauteur du dessus. false si le module manque.
local function dressSolid(b: Builder, s: Districts.Solid): boolean
	local name = s.module :: string
	local m = Districts.MODULES[name]
	if m == nil or not Kit.has(name) then
		return false
	end
	if name == "Fort_Rempart" then
		local along = s.w >= s.d
		local length = if along then s.w else s.d
		local count = math.max(1, math.floor(length / m.w + 0.5))
		local width = length / count
		for i = 1, count do
			local t = -length / 2 + width * (i - 0.5)
			local x = if along then s.x + t else s.x
			local z = if along then s.z else s.z + t
			-- Façade (-Z du module) vers l'extérieur de l'îlot.
			local yaw = if along
				then (if s.z < 0 then 0 else math.pi)
				else (if s.x < 0 then math.pi / 2 else -math.pi / 2)
			local cf = b.inner * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
			local placed = Kit.placeScaled(name, cf, Vector3.new(width / m.w, s.top / m.h, 1))
			if placed then
				placed.Parent = b.model
			end
		end
		return true
	end
	local placed = Kit.placeScaled(
		name,
		b.inner * CFrame.new(s.x, 0, s.z),
		Vector3.new(s.w / m.w, s.top / (m.roof or m.h), s.d / m.d)
	)
	if placed then
		placed.Parent = b.model
		return true
	end
	return false
end

local function interior(b: Builder, def: Districts.District)
	for _, p in def.buildings do
		module(b, b.inner, p.module, p.x, p.y or 0, p.z, (p.turns or 0) * math.pi / 2)
	end
	for _, p in def.props do
		module(b, b.inner, p.module, p.x, p.y or 0, p.z, (p.turns or 0) * math.pi / 2, nil, p.solid)
		if p.module == "Fort_Cristal" then
			lampLight(b, b.inner, p.x, p.y or 0, p.z)
		end
	end
	for _, s in def.stairs do
		stair(b, b.inner, s.x, s.z, s.turns * math.pi / 2, s.rise, s.run, s.width)
	end
	for _, s in def.solids do
		local look = GROUND[s.material] or GROUND.Slate
		local bottom = s.bottom or 0
		if s.module and bottom == 0 and dressSolid(b, s) then
			continue
		end
		if s.top > 0 and bottom > 0 then
			-- Dalle suspendue (toit de crypte, passerelle).
			block(
				b,
				b.inner,
				Vector3.new(s.w, s.top - bottom, s.d),
				s.x,
				bottom,
				s.z,
				look.material,
				look.color
			)
		elseif s.top > 0 then
			block(b, b.inner, Vector3.new(s.w, s.top, s.d), s.x, 0, s.z, look.material, look.color)
			-- Rebord de pierre autour du sommet (sauf côté escalier : -X).
			for _, e in { { 0, -1 }, { 0, 1 }, { 1, 0 } } do
				local w = if e[1] == 0 then s.w else 0.6
				local d = if e[1] == 0 then 0.6 else s.d
				block(
					b,
					b.inner,
					Vector3.new(w, 1.2, d),
					s.x + e[1] * (s.w / 2 - 0.3),
					s.top,
					s.z + e[2] * (s.d / 2 - 0.3),
					Enum.Material.Slate,
					C.paleStone
				)
			end
		else
			-- Pont : tablier au niveau des quais.
			block(b, b.inner, Vector3.new(s.w, 1, s.d), s.x, -1, s.z, look.material, look.color)
			for _, side in { -1, 1 } do
				block(
					b,
					b.inner,
					Vector3.new(0.3, 1.2, s.d),
					s.x + side * (s.w / 2 - 0.15),
					0,
					s.z,
					Enum.Material.Metal,
					C.iron
				)
			end
		end
	end
	if def.light then
		local holder = block(
			b,
			b.inner,
			Vector3.new(1, 1, 1),
			0,
			8,
			0,
			Enum.Material.Neon,
			Color3.fromRGB(def.light[1], def.light[2], def.light[3])
		)
		holder.Transparency = 1
		holder.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = holder.Color
		light.Range = 40
		light.Brightness = 1.2
		light.Parent = holder
	end
	if def.spawn then
		local pad = block(
			b,
			b.inner,
			Vector3.new(10, 0.3, 10),
			def.spawn.x,
			0,
			def.spawn.z,
			Enum.Material.Slate,
			C.paleStone
		)
		pad.Name = "SquadSpawn"
	end
	if def.extract and def.throne then
		-- Emplacement de la Faille finale (repère visuel).
		local rift = block(
			b,
			b.inner,
			Vector3.new(6, 0.2, 6),
			def.extract.x,
			def.extract.y + 0.25,
			def.extract.z,
			Enum.Material.Neon,
			Color3.fromRGB(255, 140, 60)
		)
		rift.Name = "RiftMarker"
		rift.CanCollide = false
		rift.Transparency = 0.6
	end
end

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
	local def = Districts.get(tile.kind) :: Districts.District
	ground(b, def)
	-- Bords nord et ouest (le bord appartient à la tuile au nord / à l'ouest) ; sud et est
	-- seulement sur le pourtour de la grille.
	for _, dir in EclatLayout.DIRECTIONS do
		local kind = EclatLayout.edge(layout, tile.x, tile.z, dir)
		local owner = dir == "N" or dir == "W" or kind == "Void"
		if owner then
			buildEdge(b, dir, kind)
		end
	end
	-- Tourelle à l'angle nord-ouest (sauf sur le pourtour de la grille).
	if tile.x > 0 and tile.z > 0 then
		module(b, b.center, "Fort_Tourelle", -HALF, 0, -HALF, 0)
	end
	interior(b, def)
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	return model
end

return TileKit
