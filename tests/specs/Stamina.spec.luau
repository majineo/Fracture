local Stamina = require("../../src/shared/Movement/Stamina")

local CONFIG = {
	SPRINT_DURATION = 6,
	REGEN_DURATION = 4,
	REGEN_DELAY = 0.6,
	SPRINT_RESTART_MIN = 0.25,
}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(T)
	T.suite("Stamina")

	T.test("le sprint vide la jauge en SPRINT_DURATION secondes", function()
		local s = Stamina.new()
		for _ = 1, 60 do
			Stamina.step(s, 0.05, true, CONFIG) -- 3 s
		end
		T.truthy(near(s.value, 0.5), `valeur {s.value}`)
		for _ = 1, 60 do
			Stamina.step(s, 0.05, true, CONFIG)
		end
		T.equal(s.value, 0)
		T.truthy(s.exhausted, "à bout de souffle")
		T.falsy(Stamina.canSprint(s))
	end)

	T.test("pause avant la recharge, puis recharge en REGEN_DURATION", function()
		local s = Stamina.new()
		s.value = 0
		s.regenDelay = CONFIG.REGEN_DELAY
		Stamina.step(s, 0.5, false, CONFIG)
		T.equal(s.value, 0, "toujours en pause")
		Stamina.step(s, 0.1, false, CONFIG) -- fin de la pause
		Stamina.step(s, 2, false, CONFIG)
		T.truthy(near(s.value, 0.5), `valeur {s.value}`)
		Stamina.step(s, 10, false, CONFIG)
		T.equal(s.value, 1, "plafonnée à 1")
	end)

	T.test("à bout de souffle : resprint seulement après SPRINT_RESTART_MIN", function()
		local s = Stamina.new()
		Stamina.step(s, 6.1, true, CONFIG)
		T.truthy(s.exhausted)
		Stamina.step(s, 0.6, false, CONFIG) -- pause
		Stamina.step(s, 0.8, false, CONFIG) -- 0.2
		T.falsy(Stamina.canSprint(s), "à 20 %")
		Stamina.step(s, 0.4, false, CONFIG) -- 0.3
		T.truthy(Stamina.canSprint(s), "à 30 %")
	end)

	T.test("sprinter à bout de souffle ne vide rien et ne bloque pas la recharge", function()
		local s = Stamina.new()
		s.value = 0.1
		s.exhausted = true
		Stamina.step(s, 1, true, CONFIG)
		T.truthy(s.value > 0.1, "la jauge remonte")
	end)

	T.test("spend refuse si la jauge est insuffisante", function()
		local s = Stamina.new()
		T.truthy(Stamina.spend(s, 0.15, CONFIG))
		T.truthy(near(s.value, 0.85))
		s.value = 0.1
		T.falsy(Stamina.spend(s, 0.15, CONFIG))
		T.truthy(near(s.value, 0.1), "rien dépensé")
	end)
end
