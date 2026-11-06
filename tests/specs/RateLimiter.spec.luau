local RateLimiter = require("../../src/server/Core/Lib/RateLimiter")

return function(T)
	T.suite("RateLimiter")

	local function fakeClock()
		local t = 0
		return function()
			return t
		end, function(dt: number)
			t += dt
		end
	end

	T.test("autorise jusqu'à la réserve puis refuse", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(clock)
		for i = 1, 3 do
			T.truthy(limiter.allow("p1", "remote", 1, 3), `requête {i}`)
		end
		T.falsy(limiter.allow("p1", "remote", 1, 3), "4e requête immédiate")
	end)

	T.test("se recharge avec le temps", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(clock)
		T.truthy(limiter.allow("p1", "r", 2, 1))
		T.falsy(limiter.allow("p1", "r", 2, 1))
		advance(0.5) -- 2 jetons/s × 0,5 s = 1 jeton
		T.truthy(limiter.allow("p1", "r", 2, 1))
	end)

	T.test("ne dépasse jamais la réserve même après une longue attente", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(clock)
		T.truthy(limiter.allow("p1", "r", 1, 2))
		advance(1000)
		T.truthy(limiter.allow("p1", "r", 1, 2))
		T.truthy(limiter.allow("p1", "r", 1, 2))
		T.falsy(limiter.allow("p1", "r", 1, 2))
	end)

	T.test("les joueurs et les remotes sont indépendants", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(clock)
		T.truthy(limiter.allow("p1", "a", 1, 1))
		T.falsy(limiter.allow("p1", "a", 1, 1))
		T.truthy(limiter.allow("p2", "a", 1, 1), "autre joueur")
		T.truthy(limiter.allow("p1", "b", 1, 1), "autre remote")
	end)

	T.test("forget remet à zéro un joueur", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(clock)
		T.truthy(limiter.allow("p1", "a", 1, 1))
		T.falsy(limiter.allow("p1", "a", 1, 1))
		limiter.forget("p1")
		T.truthy(limiter.allow("p1", "a", 1, 1))
	end)
end
