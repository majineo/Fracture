local DecorMotion = require("../../src/shared/Eclat/DecorMotion")

return function(T)
	T.suite("DecorMotion (décor animé de l'Éclat)")

	T.test("le vacillement d'une flamme reste borné", function()
		for i = 0, 400 do
			local f = DecorMotion.flicker(i * 0.037, 3.2)
			T.truthy(f >= 0.7 and f <= 1.15, `flicker({i}) = {f}`)
		end
	end)

	T.test("un rouage avance de deux crans par cycle (trois avant, un arrière)", function()
		local p = DecorMotion.TICK_PERIOD
		local step = DecorMotion.TICK_STEP
		local a0 = DecorMotion.tick(0.5 * p, 1, 0)
		local a4 = DecorMotion.tick(4.5 * p, 1, 0)
		T.truthy(math.abs((a4 - a0) - 2 * step) < 1e-6, `écart {a4 - a0}`)
		-- le quatrième cran recule
		local a3 = DecorMotion.tick(3.5 * p, 1, 0)
		local a2 = DecorMotion.tick(2.5 * p, 1, 0)
		T.truthy(a3 < a2, "le 4e cran recule")
		-- ratio négatif : sens inverse
		T.truthy(math.abs(DecorMotion.tick(4.5 * p, -1, 0) + a4) < 1e-6, "ratio -1 inverse le sens")
	end)

	T.test("le rouage est arrêté entre deux crans", function()
		local p = DecorMotion.TICK_PERIOD
		T.equal(DecorMotion.tick(1.5 * p, 1, 0), DecorMotion.tick(1.9 * p, 1, 0), "arrêt")
	end)

	T.test("balancier, cloche et bannière restent dans leurs amplitudes", function()
		for i = 0, 600 do
			local t = i * 0.05
			T.truthy(math.abs(DecorMotion.stutter(t, 1)) <= 14.5, "balancier")
			T.truthy(math.abs(DecorMotion.tremble(t, 1)) <= 4, "cloche")
			T.truthy(math.abs(DecorMotion.sway(t, 1)) <= 9.5, "bannière")
		end
	end)

	T.test("modes inconnus : immobile ; orbites sur le cercle", function()
		T.equal(DecorMotion.angle("inconnu", 3, 1, 0), 0, "mode inconnu")
		for i = 1, 6 do
			local x, y, z = DecorMotion.orbit(2.0, i, 6, 10)
			local r = math.sqrt(x * x + z * z)
			T.truthy(r >= 6.99 and r <= 10.01, `rayon {r}`)
			T.truthy(math.abs(y) <= 1.21, `hauteur {y}`)
		end
	end)

	T.test("graine stable et bornée", function()
		local s = DecorMotion.seed(12.5, 3, -40)
		T.equal(s, DecorMotion.seed(12.5, 3, -40), "stable")
		T.truthy(s >= 0 and s < 10, "bornée")
	end)
end
