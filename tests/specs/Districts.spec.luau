local Districts = require("../../src/shared/Eclat/Districts")

local KINDS =
	{ "Donjon", "CourArmes", "Remparts", "TourGuet", "Village", "PontLevis", "Crypte", "Bord" }

local function points(def)
	local out = {}
	for _, p in def.loot do
		table.insert(out, { p, "butin " .. p.table })
	end
	for _, p in def.posts do
		table.insert(out, { p, "poste " .. p.id })
	end
	table.insert(out, { def.extract, "extraction" })
	if def.altar then
		table.insert(out, { def.altar, "autel" })
	end
	if def.spawn then
		table.insert(out, { def.spawn, "apparition" })
	end
	if def.throne then
		table.insert(out, { def.throne, "trône" })
	end
	return out
end

return function(T)
	T.suite("Districts (forteresse 7 × 7)")

	T.test("chaque quartier existe et n'utilise que des modules connus", function()
		for _, kind in KINDS do
			local def = Districts.get(kind)
			T.truthy(def ~= nil, kind)
			for _, b in def.buildings do
				T.truthy(Districts.MODULES[b.module] ~= nil, `{kind} : module {b.module}`)
			end
			for _, p in def.props do
				T.truthy(Districts.MODULES[p.module] ~= nil, `{kind} : module {p.module}`)
			end
		end
	end)

	T.test("aucun point de jeu dans un mur, dans l'eau ou dans le vide", function()
		for _, kind in KINDS do
			local def = Districts.get(kind)
			for _, entry in points(def) do
				local p, label = entry[1], entry[2]
				T.truthy(
					math.max(math.abs(p.x), math.abs(p.z)) <= Districts.RING - 2,
					`{kind} : {label} hors du quartier`
				)
				T.falsy(
					Districts.blocked(def, p.x, p.y, p.z, 1),
					`{kind} : {label} ({p.x}, {p.y}, {p.z}) bloqué`
				)
				T.truthy(Districts.supported(def, p.x, p.y, p.z), `{kind} : {label} dans le vide`)
			end
		end
	end)

	T.test("les bâtiments restent dans l'îlot et ne se chevauchent pas", function()
		for _, kind in KINDS do
			local def = Districts.get(kind)
			for i, a in def.buildings do
				local ax, az = Districts.footprint(a.module, a.turns)
				T.truthy(
					math.abs(a.x) + ax <= Districts.BLOCK + 0.5,
					`{kind} : {a.module} déborde en x`
				)
				T.truthy(
					math.abs(a.z) + az <= Districts.BLOCK + 0.5,
					`{kind} : {a.module} déborde en z`
				)
				for j, b in def.buildings do
					if j > i then
						local bx, bz = Districts.footprint(b.module, b.turns)
						local overlap = math.abs(a.x - b.x) < ax + bx
							and math.abs(a.z - b.z) < az + bz
						T.falsy(overlap, `{kind} : {a.module} et {b.module} se chevauchent`)
					end
				end
			end
		end
	end)

	T.test("le chemin de ronde reste praticable (aucun bâtiment ni bloc dessus)", function()
		for _, kind in KINDS do
			local def = Districts.get(kind)
			local probe = {
				buildings = def.buildings,
				props = {},
				stairs = def.stairs,
				solids = def.solids,
			}
			for t = -38, 38, 2 do
				for _, p in { { t, -34 }, { t, 34 }, { -34, t }, { 34, t } } do
					T.falsy(
						Districts.blocked(probe :: any, p[1], 0, p[2], 0),
						`{kind} : chemin de ronde bouché en ({p[1]}, {p[2]})`
					)
				end
			end
		end
	end)

	T.test(
		"rôles : trône au Donjon, apparition au Bord sans Échoué, autels ailleurs",
		function()
			T.truthy(Districts.get("Donjon").throne ~= nil)
			T.truthy(Districts.get("Bord").spawn ~= nil)
			T.equal(#Districts.get("Bord").posts, 0)
			local altars = 0
			for _, kind in KINDS do
				if Districts.get(kind).altar then
					altars += 1
				end
			end
			T.truthy(altars >= 3, `autels possibles : {altars}`)
		end
	)

	T.test("l'escalier de la tour de guet arrive au bord de la plateforme", function()
		local def = Districts.get("TourGuet")
		local stair = def.stairs[1]
		local platform = def.solids[1]
		local hx = Districts.stairFootprint(stair)
		T.equal(stair.x + hx, platform.x - platform.w / 2)
		T.equal(stair.rise, platform.top)
	end)

	T.test("chaque escalier du Donjon arrive sur une passerelle à hauteur du toit", function()
		local def = Districts.get("Donjon")
		local roof = Districts.MODULES.Fort_Donjon.roof
		for i, stair in def.stairs do
			T.equal(stair.rise, roof, `escalier {i}`)
			local bridge = def.solids[i]
			T.equal(bridge.top, roof, `passerelle {i}`)
			-- Le haut de l'escalier (bout -Z tourné) touche la passerelle.
			local dir = if stair.turns == 0 then -1 else 1
			local topZ = stair.z + dir * stair.run / 2
			T.truthy(
				math.abs(topZ - (bridge.z - dir * bridge.d / 2 + dir * bridge.d)) <= bridge.d,
				`raccord {i}`
			)
		end
	end)

	T.test("modules de bord alignés sur la grille de 8 studs", function()
		for _, name in { "Fort_Mur", "Fort_Rempart" } do
			T.equal(Districts.MODULES[name].w % 8, 0, name)
		end
		T.equal(96 % 8, 0, "tuile")
	end)
end
