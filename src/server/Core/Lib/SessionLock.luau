--!strict
-- Verrou de session : un seul serveur à la fois peut posséder et écrire le profil d'un joueur.
-- C'est ce qui empêche la duplication d'objets quand un joueur passe du Refuge à un Éclat
-- (ou rejoint un autre serveur avant la fin de la sauvegarde du précédent).
-- Studio : ServerScriptService > Server > Lib > SessionLock
-- Module pur : testé par tests/specs/SessionLock.spec.luau.
--
-- Les fonctions ci-dessous sont des TRANSFORMATIONS pour DataStore:UpdateAsync :
-- elles reçoivent la valeur stockée et renvoient la nouvelle valeur, ou nil pour annuler
-- l'écriture. Elles sont synchrones (ne jamais attendre dans une transformation).
--
-- Format stocké : { data = ProfileData, lock = { jobId, at }?, savedAt = number }

export type Lock = { jobId: string, at: number }
export type Record = { data: any, lock: Lock?, savedAt: number }

export type ClaimOutcome = "Created" | "Claimed" | "Locked" | "Incompatible" | "Corrupt"
export type SaveOutcome = "Saved" | "Released" | "LockLost"

export type Schema = {
	default: (now: number) -> any,
	migrate: (stored: any) -> (any?, string?),
}

local SessionLock = {}

-- Revendique le profil pour le serveur `jobId`.
--  * Aucune donnée         -> "Created"   (nouveau profil, verrouillé)
--  * Verrou d'un autre serveur, récent -> "Locked" (on n'écrit rien ; réessayer plus tard)
--  * Verrou absent, périmé ou déjà à nous -> "Claimed" (données migrées, verrouillées)
--  * Données d'une version future -> "Incompatible" (on n'écrit rien)
--  * Données illisibles   -> "Corrupt" (on n'écrit rien : on n'écrase JAMAIS des données)
function SessionLock.claim(
	stored: any,
	jobId: string,
	now: number,
	staleAfter: number,
	schema: Schema
): (Record?, ClaimOutcome, any?)
	if stored == nil then
		local data = schema.default(now)
		return { data = data, lock = { jobId = jobId, at = now }, savedAt = now }, "Created", data
	end

	if typeof(stored) ~= "table" or typeof(stored.data) ~= "table" then
		return nil, "Corrupt", nil
	end

	local lock = stored.lock
	if typeof(lock) == "table" and lock.jobId ~= jobId then
		local at = lock.at
		local fresh = typeof(at) == "number" and (now - at) < staleAfter
		if fresh then
			return nil, "Locked", nil
		end
	end

	local data, reason = schema.migrate(stored.data)
	if data == nil then
		return nil, if reason == "Future" then "Incompatible" else "Corrupt", nil
	end

	local savedAt = if typeof(stored.savedAt) == "number" then stored.savedAt else now
	return { data = data, lock = { jobId = jobId, at = now }, savedAt = savedAt }, "Claimed", data
end

-- Sauvegarde `data` si et seulement si le serveur `jobId` détient toujours le verrou.
-- `release = true` libère le verrou (départ du joueur, arrêt du serveur).
-- Si le verrou a été perdu, renvoie "LockLost" et n'écrit rien.
function SessionLock.save(
	stored: any,
	jobId: string,
	data: any,
	now: number,
	release: boolean
): (Record?, SaveOutcome)
	if typeof(stored) ~= "table" then
		return nil, "LockLost"
	end
	local lock = stored.lock
	if typeof(lock) ~= "table" or lock.jobId ~= jobId then
		return nil, "LockLost"
	end
	local newLock: Lock? = if release then nil else { jobId = jobId, at = now }
	return { data = data, lock = newLock, savedAt = now }, if release then "Released" else "Saved"
end

return table.freeze(SessionLock)
