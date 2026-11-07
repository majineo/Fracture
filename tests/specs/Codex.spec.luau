local Codex = require("../../src/shared/Loot/Codex")

local function profile()
	return {
		grains = 100,
		codex = {},
		equipped = {},
		stash = {
			r1 = { id = "relic.stase", qty = 3 },
			r2 = { id = "relic.onde_de_choc", qty = 2 },
			m1 = { id = "mat.ancient_steel", qty = 1 },
			m2 = { id = "mat.iron", qty = 9 },
		},
	}
end

return function(T)
	T.suite("Codex")

	T.test("stabiliser une relique intacte : paie, retire la relique, niveau 1", function()
		local data = profile()
		local ok, level = Codex.stabilize(data, "r1")
		T.truthy(ok)
		T.equal(level, 1)
		T.equal(data.codex["relic.stase"], 1)
		T.equal(data.grains, 40)
		T.equal(data.stash.r1, nil, "relique consommée")
		T.equal(data.stash.m1, nil, "acier ancien consommé")
		T.equal(data.stash.m2.qty, 9, "le reste du coffre intact")
	end)

	T.test("refus : relique abîmée, pas une relique, Grains ou matériau manquants", function()
		local data = profile()
		T.equal(select(2, Codex.stabilize(data, "r2")), "Abimee")
		T.equal(select(2, Codex.stabilize(data, "m2")), "PasUneRelique")
		T.equal(select(2, Codex.stabilize(data, 42)), "Invalide")
		data.grains = 10
		T.equal(select(2, Codex.stabilize(data, "r1")), "Grains")
		data.grains = 100
		data.stash.m1 = nil
		T.equal(select(2, Codex.stabilize(data, "r1")), "Materiau")
		T.equal(data.grains, 100, "rien payé en cas de refus")
		T.truthy(data.stash.r1, "relique gardée en cas de refus")
	end)

	T.test("niveau 3 au plus", function()
		local data = profile()
		data.codex["relic.stase"] = 3
		T.equal(select(2, Codex.stabilize(data, "r1")), "NiveauMax")
	end)

	T.test("équiper : seulement ce qui est stabilisé, 2 au plus, retirer", function()
		local data = profile()
		T.equal(select(2, Codex.equip(data, "relic.stase", true)), "NonStabilisee")
		data.codex =
			{ ["relic.stase"] = 1, ["relic.onde_de_choc"] = 2, ["relic.pas_de_faille"] = 1 }
		T.truthy(Codex.equip(data, "relic.stase", true))
		T.truthy(Codex.equip(data, "relic.stase", true), "déjà équipée : sans doublon")
		T.truthy(Codex.equip(data, "relic.onde_de_choc", true))
		T.equal(#data.equipped, 2)
		T.equal(select(2, Codex.equip(data, "relic.pas_de_faille", true)), "Plein")
		T.truthy(Codex.equip(data, "relic.stase", false))
		T.equal(#data.equipped, 1)
		T.equal(select(2, Codex.equip(data, "relic.stase", "oui")), "Invalide")
	end)

	T.test("utilisations par vie selon le niveau", function()
		T.equal(Codex.usesFor(1), 2)
		T.equal(Codex.usesFor(2), 3)
		T.equal(Codex.usesFor(3), 3)
	end)
end
