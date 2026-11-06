local ProfileSchema = require("../../src/server/Core/Lib/ProfileSchema")
local SessionLock = require("../../src/server/Core/Lib/SessionLock")

local STALE = 150

return function(T)
	T.suite("SessionLock")

	T.test("crée et verrouille un nouveau profil", function()
		local record, outcome, data = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		T.equal(outcome, "Created")
		T.truthy(record and data)
		T.equal(record.lock.jobId, "A")
		T.equal(record.lock.at, 100)
	end)

	T.test("refuse un profil verrouillé récemment par un autre serveur", function()
		local stored = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		local record, outcome = SessionLock.claim(stored, "B", 200, STALE, ProfileSchema)
		T.equal(outcome, "Locked")
		T.equal(record, nil, "aucune écriture")
	end)

	T.test("reprend un verrou périmé (serveur planté)", function()
		local stored = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		local record, outcome =
			SessionLock.claim(stored, "B", 100 + STALE + 1, STALE, ProfileSchema)
		T.equal(outcome, "Claimed")
		T.equal(record.lock.jobId, "B")
	end)

	T.test("le même serveur peut revendiquer à nouveau (appel réessayé)", function()
		local stored = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		local _, outcome = SessionLock.claim(stored, "A", 101, STALE, ProfileSchema)
		T.equal(outcome, "Claimed")
	end)

	T.test(
		"un profil libéré peut être revendiqué par un autre serveur (Refuge -> Éclat)",
		function()
			local stored, _, data = SessionLock.claim(nil, "Refuge", 100, STALE, ProfileSchema)
			data.grains = 77
			local released, saveOutcome = SessionLock.save(stored, "Refuge", data, 110, true)
			T.equal(saveOutcome, "Released")
			T.equal(released.lock, nil, "verrou libéré")
			local record, outcome, claimed =
				SessionLock.claim(released, "Eclat", 111, STALE, ProfileSchema)
			T.equal(outcome, "Claimed")
			T.equal(record.lock.jobId, "Eclat")
			T.equal(claimed.grains, 77, "données conservées")
		end
	)

	T.test("la sauvegarde rafraîchit le verrou", function()
		local stored, _, data = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		local saved, outcome = SessionLock.save(stored, "A", data, 160, false)
		T.equal(outcome, "Saved")
		T.equal(saved.lock.at, 160)
	end)

	T.test("un serveur qui a perdu le verrou n'écrit rien (anti-duplication)", function()
		local stored, _, data = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		-- B reprend le profil après expiration du verrou de A
		local takenOver = SessionLock.claim(stored, "B", 100 + STALE + 1, STALE, ProfileSchema)
		data.grains = 999999
		local record, outcome = SessionLock.save(takenOver, "A", data, 400, false)
		T.equal(outcome, "LockLost")
		T.equal(record, nil)
	end)

	T.test("la sauvegarde échoue si le verrou a été libéré entre-temps", function()
		local stored, _, data = SessionLock.claim(nil, "A", 100, STALE, ProfileSchema)
		local released = SessionLock.save(stored, "A", data, 110, true)
		local record, outcome = SessionLock.save(released, "A", data, 120, false)
		T.equal(outcome, "LockLost")
		T.equal(record, nil)
	end)

	T.test("n'écrase jamais des données illisibles", function()
		for _, bad in { "texte", 12, { data = "x" }, {} } do
			local record, outcome = SessionLock.claim(bad, "A", 100, STALE, ProfileSchema)
			T.equal(outcome, "Corrupt")
			T.equal(record, nil)
		end
	end)

	T.test("refuse des données d'une version future", function()
		local stored = { data = { version = ProfileSchema.CURRENT_VERSION + 1 }, savedAt = 1 }
		local record, outcome = SessionLock.claim(stored, "A", 100, STALE, ProfileSchema)
		T.equal(outcome, "Incompatible")
		T.equal(record, nil)
	end)
end
