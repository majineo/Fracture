local Spring = require("../../src/shared/Util/Spring")

return function(T)
	T.suite("Spring")

	T.test("atteint la cible sans la dépasser (amortissement critique)", function()
		local s = Spring.new(0, 12)
		s.target = 10
		local maxValue = 0
		for _ = 1, 120 do
			maxValue = math.max(maxValue, Spring.step(s, 1 / 60))
		end
		T.truthy(math.abs(s.position - 10) < 0.01, `position {s.position}`)
		T.truthy(maxValue <= 10.001, `dépassement {maxValue}`)
	end)

	T.test("plus de raideur = plus rapide", function()
		local slow, fast = Spring.new(0, 4), Spring.new(0, 16)
		slow.target, fast.target = 1, 1
		for _ = 1, 15 do
			Spring.step(slow, 1 / 60)
			Spring.step(fast, 1 / 60)
		end
		T.truthy(fast.position > slow.position)
	end)

	T.test("stable même avec une image très longue", function()
		local s = Spring.new(0, 30)
		s.target = 1
		Spring.step(s, 2) -- gel du jeu
		T.truthy(s.position == s.position and math.abs(s.position) < 10, `position {s.position}`)
	end)

	T.test("le résultat ne dépend presque pas du nombre d'images par seconde", function()
		local a, b = Spring.new(0, 10), Spring.new(0, 10)
		a.target, b.target = 1, 1
		for _ = 1, 30 do
			Spring.step(a, 1 / 30)
		end
		for _ = 1, 144 do
			Spring.step(b, 1 / 144)
		end
		T.truthy(math.abs(a.position - b.position) < 0.01, `{a.position} contre {b.position}`)
	end)

	T.test("impulse et snap", function()
		local s = Spring.new(0, 10)
		Spring.impulse(s, 5)
		Spring.step(s, 1 / 60)
		T.truthy(s.position > 0, "l'impulsion déplace")
		Spring.snap(s, 3)
		T.equal(s.position, 3)
		T.equal(s.velocity, 0)
	end)
end
