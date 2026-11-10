local CameraMotion = require("../../src/shared/Camera/CameraMotion")

local C = CameraMotion.CONFIG

return function(T)
	T.suite("CameraMotion (caméra du joueur)")

	T.test("le cycle F5 passe par les trois vues et revient au départ", function()
		local p = "Behind"
		local seen = {}
		for _ = 1, 3 do
			p = CameraMotion.nextPerspective(p)
			seen[p] = true
		end
		T.equal(p, "Behind", "retour au départ")
		T.truthy(seen.First and seen.Front and seen.Behind, "trois vues")
	end)

	T.test("arme en main : la vue de face devient la vue de dos, la préférence reste", function()
		T.equal(CameraMotion.effective("Front", true), "Behind")
		T.equal(CameraMotion.effective("Front", false), "Front")
		T.equal(CameraMotion.effective("First", true), "First")
	end)

	T.test("distances selon la vue et l'état", function()
		T.equal(CameraMotion.distanceFor("First", true, true, 10), 0)
		T.equal(CameraMotion.distanceFor("Behind", true, true, 10), C.DISTANCE_AIM)
		T.equal(CameraMotion.distanceFor("Behind", true, false, 10), C.DISTANCE_ARMED)
		T.equal(CameraMotion.distanceFor("Behind", false, false, 99), C.ZOOM_MAX)
		T.equal(CameraMotion.distanceFor("Front", false, false, 3), C.DISTANCE_FRONT)
	end)

	T.test("la perche rentre d'un coup et ressort progressivement", function()
		T.equal(CameraMotion.boom(8, 2, 1 / 60), 2, "entrée instantanée")
		local d = CameraMotion.boom(2, 8, 1 / 60)
		T.truthy(d > 2 and d < 2.5, `sortie progressive : {d}`)
		local x = 2
		for _ = 1, 120 do
			x = CameraMotion.boom(x, 8, 1 / 60)
		end
		T.truthy(math.abs(x - 8) < 0.01, `rejoint la cible : {x}`)
	end)

	T.test("distance libre : marge au mur, jamais négative", function()
		T.equal(CameraMotion.freeDistance(8, nil), 8)
		T.truthy(math.abs(CameraMotion.freeDistance(8, 3) - (3 - C.WALL_MARGIN)) < 1e-9)
		T.equal(CameraMotion.freeDistance(8, 0.1), 0)
		T.equal(CameraMotion.freeDistance(8, 50), 8)
	end)

	T.test("balancement discret, nul à l'arrêt ou sans poids", function()
		for i = 0, 200 do
			local h, r = CameraMotion.bob(i * 0.1, 30, 1)
			T.truthy(
				math.abs(h) <= C.BOB_HEIGHT + 1e-9 and math.abs(r) <= C.BOB_ROLL + 1e-9,
				"borné"
			)
		end
		local h0, r0 = CameraMotion.bob(1.2, 0, 1)
		T.equal(h0, 0)
		T.equal(r0, 0)
		local h1 = CameraMotion.bob(1.2, 22, 0)
		T.equal(h1, 0, "s'efface en visée")
	end)

	T.test("la foulée avance avec la vitesse et reste dans [0, 2π[", function()
		local p = CameraMotion.stride(6.2, 22, 1)
		T.truthy(p >= 0 and p < math.pi * 2, "borné")
		T.equal(CameraMotion.stride(1, 0, 1), 1, "immobile")
	end)

	T.test("inclinaison latérale opposée au déplacement et bornée", function()
		T.truthy(CameraMotion.strafeRoll(10, 1) < 0, "vers la droite : roulis négatif")
		T.equal(CameraMotion.strafeRoll(500, 1), -C.STRAFE_ROLL)
		T.equal(CameraMotion.strafeRoll(10, 0), 0)
	end)

	T.test("anticipation bornée et dans le sens du mouvement", function()
		local x, z = CameraMotion.lead(100, 0)
		T.truthy(math.abs(x - C.LEAD_MAX) < 1e-9 and z == 0, "bornée")
		local a, b = CameraMotion.lead(0, -10)
		T.truthy(a == 0 and b < 0, "même sens")
	end)

	T.test("fondu du personnage près de la caméra", function()
		T.equal(CameraMotion.fade(5), 0)
		T.equal(CameraMotion.fade(0.5), 1)
		local mid = CameraMotion.fade((C.FADE_START + C.FADE_END) / 2)
		T.truthy(mid > 0.4 and mid < 0.6, `milieu {mid}`)
	end)

	T.test("rotation horizontale : un demi-tour inverse la direction", function()
		local x, z = CameraMotion.rotateFlat(0, -1, math.pi)
		T.truthy(math.abs(x) < 1e-9 and math.abs(z - 1) < 1e-9, `({x}, {z})`)
		-- sens Roblox : +90° envoie +X vers -Z
		local a, b = CameraMotion.rotateFlat(1, 0, math.pi / 2)
		T.truthy(math.abs(a) < 1e-9 and math.abs(b + 1) < 1e-9, `({a}, {b})`)
	end)

	T.test("angles ramenés dans ]-π, π]", function()
		T.truthy(math.abs(CameraMotion.wrap(3 * math.pi) - math.pi) < 1e-9)
		T.truthy(math.abs(CameraMotion.wrap(-math.pi / 2) + math.pi / 2) < 1e-9)
		T.truthy(math.abs(CameraMotion.wrap(2 * math.pi)) < 1e-9)
	end)
end
