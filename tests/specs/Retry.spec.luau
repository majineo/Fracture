local Retry = require("../../src/server/Core/Lib/Retry")

return function(T)
	T.suite("Retry")

	T.test("réussit au premier essai sans attendre", function()
		local waits = {}
		local ok, result = Retry.run(3, 1, 8, function(d)
			table.insert(waits, d)
		end, function()
			return 42
		end)
		T.truthy(ok)
		T.equal(result, 42)
		T.equal(#waits, 0, "nombre d'attentes")
	end)

	T.test("réessaie avec attente exponentielle plafonnée", function()
		local waits = {}
		local calls = 0
		local ok, result = Retry.run(5, 1, 3, function(d)
			table.insert(waits, d)
		end, function()
			calls += 1
			if calls < 4 then
				error("panne")
			end
			return "ok"
		end)
		T.truthy(ok)
		T.equal(result, "ok")
		T.equal(calls, 4, "appels")
		T.equal(#waits, 3, "attentes")
		T.equal(waits[1], 1)
		T.equal(waits[2], 2)
		T.equal(waits[3], 3, "plafonnée à maxDelay")
	end)

	T.test("abandonne après le nombre maximal de tentatives", function()
		local failuresSeen = 0
		local ok, result, err = Retry.run(3, 1, 8, function() end, function()
			error("toujours en panne")
		end, function()
			failuresSeen += 1
		end)
		T.falsy(ok)
		T.equal(result, nil)
		T.truthy(string.find(err or "", "toujours en panne"), "message d'erreur conservé")
		T.equal(failuresSeen, 3, "callback d'échec")
	end)
end
