local DayCycle = require("../../src/shared/World/DayCycle")

local C = DayCycle.CONFIG

return function(T)
	T.suite("DayCycle (jour / nuit de 15 minutes)")

	T.test("cycle de 15 minutes : 10 de jour, 5 de nuit", function()
		T.equal(DayCycle.length(), 900)
		local day = 0
		for s = 0, 899 do
			if DayCycle.isDay(s) then
				day += 1
			end
		end
		T.equal(day, 600, "secondes de jour")
	end)

	T.test("l'heure va du lever au coucher le jour, du coucher au lever la nuit", function()
		local t0 = -C.OFFSET -- début du jour
		T.truthy(math.abs(DayCycle.clock(t0) - 6) < 1e-6, "lever à 6 h")
		T.truthy(math.abs(DayCycle.clock(t0 + 300) - 12) < 1e-6, "midi au milieu du jour")
		T.truthy(math.abs(DayCycle.clock(t0 + 600) - 18) < 1e-6, "coucher à 18 h")
		T.truthy(math.abs(DayCycle.clock(t0 + 750) - 0) < 1e-6, "minuit au milieu de la nuit")
		T.truthy(math.abs(DayCycle.clock(t0 + 900) - 6) < 1e-6, "le cycle reboucle")
	end)

	T.test("aucun saut d'éclairage : variations faibles d'une seconde à l'autre", function()
		local worst = 0
		local prev = DayCycle.sample(DayCycle.clock(0))
		for s = 1, 900 do
			local cur = DayCycle.sample(DayCycle.clock(s))
			worst = math.max(worst, math.abs(cur.brightness - prev.brightness))
			prev = cur
		end
		T.truthy(worst < 0.05, `saut maximal de luminosité par seconde : {worst}`)
	end)

	T.test("la nuit n'est jamais noire et reste plus sombre que le jour", function()
		local night = DayCycle.sample(0)
		local noon = DayCycle.sample(13)
		T.truthy(night.brightness >= 0.5, "luminosité de nuit")
		T.truthy(
			night.outdoor[1] + night.outdoor[2] + night.outdoor[3] > 0.6,
			"ambiance extérieure de nuit"
		)
		T.truthy(noon.brightness > night.brightness * 1.8, "le jour est nettement plus clair")
		T.equal(night.night, 1)
		T.equal(noon.night, 0)
	end)

	T.test("même instant serveur = même heure (synchronisé sans réseau)", function()
		T.equal(DayCycle.clock(123456.7), DayCycle.clock(123456.7))
	end)
end
