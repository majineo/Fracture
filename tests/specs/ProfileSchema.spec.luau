local ProfileSchema = require("../../src/server/Core/Lib/ProfileSchema")

return function(T)
	T.suite("ProfileSchema")

	T.test("default crée un profil à la version courante", function()
		local data = ProfileSchema.default(1000)
		T.equal(data.version, ProfileSchema.CURRENT_VERSION)
		T.equal(data.createdAt, 1000)
		T.equal(data.rank.level, 1)
		T.equal(data.grains, 0)
	end)

	T.test("deux profils par défaut ne partagent aucune table", function()
		local a = ProfileSchema.default(0)
		local b = ProfileSchema.default(0)
		a.rank.level = 9
		a.stash["guid-1"] = { id = "x", qty = 1 }
		T.equal(b.rank.level, 1, "rang de b")
		T.equal(b.stash["guid-1"], nil, "coffre de b")
	end)

	T.test("migrate ajoute les champs manquants sans toucher aux existants", function()
		local stored = {
			version = 1,
			createdAt = 5,
			grains = 250,
			rank = { level = 4 }, -- xp manquant
			stash = { g1 = { id = "weapon.sword", qty = 1 } },
		}
		local data, reason = ProfileSchema.migrate(stored)
		T.equal(reason, nil)
		T.truthy(data)
		T.equal(data.grains, 250, "grains conservés")
		T.equal(data.rank.level, 4, "rang conservé")
		T.equal(data.rank.xp, 0, "xp ajouté")
		T.truthy(data.codex, "codex ajouté")
		T.equal(data.stats.deaths, 0, "stats ajoutées")
		T.equal(data.stash.g1.id, "weapon.sword", "objet conservé")
	end)

	T.test("migrate ne modifie pas la table d'origine", function()
		local stored = { version = 1, grains = 1 }
		ProfileSchema.migrate(stored)
		T.equal(stored.codex, nil)
	end)

	T.test(
		"migration v1 → v2 : capacités équipées ajoutées, Codex et coffre gardés",
		function()
			local v1 = {
				version = 1,
				createdAt = 10,
				rank = { level = 3, xp = 40 },
				grains = 120,
				codex = { ["relic.stase"] = 2 },
				mastery = {},
				stash = { abc = { id = "mat.iron", qty = 4 } },
				stats = { extractions = 2, deaths = 1, sessions = 5 },
			}
			local data, err = ProfileSchema.migrate(v1)
			T.equal(err, nil)
			T.equal(data.version, 2)
			T.equal(#data.equipped, 0)
			T.equal(data.codex["relic.stase"], 2)
			T.equal(data.stash.abc.qty, 4)
			T.equal(data.grains, 120)
			T.truthy(ProfileSchema.validate(data), "toujours stockable")
		end
	)

	T.test("migrate refuse des données d'une version future", function()
		local data, reason = ProfileSchema.migrate({ version = ProfileSchema.CURRENT_VERSION + 1 })
		T.equal(data, nil)
		T.equal(reason, "Future")
	end)

	T.test("validate accepte un profil normal", function()
		local data = ProfileSchema.default(0)
		data.stash["guid-1"] = { id = "weapon.sword", qty = 1 }
		data.codex["relic.stase"] = 2
		local ok, where = ProfileSchema.validate(data)
		T.truthy(ok, where)
	end)

	T.test("validate refuse ce qu'un DataStore ne peut pas stocker", function()
		local cases = {
			{ name = "NaN", value = { a = 0 / 0 } },
			{ name = "infini", value = { a = math.huge } },
			{ name = "fonction", value = { a = function() end } },
			{ name = "clé booléenne", value = { [true] = 1 } },
			{ name = "mélange tableau/dictionnaire", value = { 1, 2, x = 3 } },
			{ name = "tableau à trous", value = { [1] = "a", [3] = "c" } },
		}
		for _, case in cases do
			local ok = ProfileSchema.validate(case.value)
			T.falsy(ok, case.name)
		end
	end)

	T.test("validate indique le chemin du problème", function()
		local data = ProfileSchema.default(0)
		data.grains = 0 / 0
		local ok, where = ProfileSchema.validate(data)
		T.falsy(ok)
		T.truthy(string.find(where or "", "data.grains", 1, true), where)
	end)

	T.test("migrate refuse des données invalides", function()
		for _, bad in { "texte", 12, { version = "1" }, { version = 0 }, { version = 1.5 }, {} } do
			local data, reason = ProfileSchema.migrate(bad)
			T.equal(data, nil)
			T.equal(reason, "Invalid")
		end
	end)
end
