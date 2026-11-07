local Ability = require("../../src/shared/Combat/Ability")

local REWIND = Ability.DEFS.Rewind

return function(T)
	T.suite("Ability")

	T.test("le noyau se remplit avec les dégâts, sans dépasser", function()
		local core = Ability.newCore()
		T.equal(Ability.addDamage(core, 60, REWIND), false)
		T.equal(Ability.isReady(core, REWIND, 10), false)
		T.equal(Ability.addDamage(core, 60, REWIND), true, "vient de se remplir")
		T.equal(core.charge, 100)
		T.equal(Ability.addDamage(core, 30, REWIND), false, "déjà plein")
		T.equal(Ability.fraction(core, REWIND), 1)
	end)

	T.test("dégâts invalides ignorés (NaN, négatifs)", function()
		local core = Ability.newCore()
		Ability.addDamage(core, 0 / 0, REWIND)
		Ability.addDamage(core, -50, REWIND)
		T.equal(core.charge, 0)
	end)

	T.test("utiliser vide le noyau ; impossible deux fois de suite", function()
		local core = Ability.newCore()
		Ability.addDamage(core, 100, REWIND)
		T.equal(Ability.consume(core, REWIND, 5), true)
		T.equal(core.charge, 0)
		Ability.addDamage(core, 100, REWIND)
		T.equal(Ability.consume(core, REWIND, 5.5), false, "délai minimal")
		T.equal(Ability.consume(core, REWIND, 6.1), true)
	end)

	T.test("capacité annulée : noyau rendu", function()
		local core = Ability.newCore()
		Ability.addDamage(core, 100, REWIND)
		Ability.consume(core, REWIND, 5)
		Ability.refund(core, REWIND)
		T.equal(Ability.isReady(core, REWIND, 5), true)
	end)

	T.test("Retour : santé récupérée, plafonnée, jamais perdue", function()
		T.equal(Ability.rewindHealth(40, 90, 35), 75, "plafond")
		T.equal(Ability.rewindHealth(40, 60, 35), 60, "santé d'avant")
		T.equal(Ability.rewindHealth(80, 50, 35), 80, "on ne perd jamais de santé")
	end)

	T.test("historique : retrouve l'échantillon d'il y a 2 s", function()
		local h = Ability.newHistory(2.5)
		for i = 0, 50 do
			Ability.record(h, i * 0.1, i)
		end
		T.equal(Ability.sampleAt(h, 5 - 2), 30)
		T.equal(Ability.sampleAt(h, 3.05), 30, "le plus récent au plus tard à t")
		T.truthy(#h.times <= 27, "les vieux échantillons sont oubliés")
		T.equal(Ability.sampleAt(h, -100), h.values[1], "trop ancien : le plus vieux connu")
	end)

	T.test("Garde du Temps : le noyau se vide en 3 s", function()
		local guard = Ability.DEFS.TimeGuard
		local core = Ability.newCore()
		Ability.addDamage(core, 100, guard)
		T.equal(Ability.drain(core, guard, 1.5), true)
		T.truthy(math.abs(core.charge - 50) < 1e-6, "moitié après 1,5 s")
		T.equal(Ability.drain(core, guard, 2), false, "vide")
		T.equal(core.charge, 0)
	end)
end
