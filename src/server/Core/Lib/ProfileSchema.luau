--!strict
-- Schéma des données joueur, valeurs par défaut et migrations entre versions.
-- Studio : ServerScriptService > Server > Lib > ProfileSchema
-- Module pur : testé par tests/specs/ProfileSchema.spec.luau.
--
-- RÈGLES :
--  * Toute modification de la structure = CURRENT_VERSION + 1 et une migration ajoutée
--    dans MIGRATIONS[ancienne version]. Ne jamais supprimer un champ sans migration.
--  * Uniquement des données sérialisables en JSON (pas d'Instance, CFrame, Vector3…).
--  * Les objets possédés sont indexés par GUID (une seule copie possible de chaque objet).

export type ItemRecord = {
	id: string, -- identifiant du catalogue (ex. "weapon.crossbow_heavy")
	qty: number,
}

export type ProfileData = {
	version: number,
	createdAt: number,
	rank: { level: number, xp: number },
	grains: number,
	codex: { [string]: number }, -- relique -> niveau (permanent)
	mastery: { [string]: number }, -- catégorie d'arme -> XP (permanent)
	stash: { [string]: ItemRecord }, -- GUID -> objet (coffre du Refuge, en sécurité)
	stats: { extractions: number, deaths: number, sessions: number },
}

local CURRENT_VERSION = 1

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = CURRENT_VERSION

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

ProfileSchema.deepCopy = deepCopy

local TEMPLATE = {
	version = CURRENT_VERSION,
	createdAt = 0,
	rank = { level = 1, xp = 0 },
	grains = 0,
	codex = {},
	mastery = {},
	stash = {},
	stats = { extractions = 0, deaths = 0, sessions = 0 },
}

-- Nouveau profil (copie profonde : jamais de table partagée entre joueurs).
function ProfileSchema.default(now: number): ProfileData
	local data = deepCopy(TEMPLATE)
	data.createdAt = now
	return data :: ProfileData
end

-- Migrations : MIGRATIONS[n] transforme des données version n en version n + 1.
-- Exemple pour une future v2 :
--   [1] = function(data) data.loadout = {} return data end,
local MIGRATIONS: { [number]: (any) -> any } = {}

-- Ajoute les champs manquants du modèle sans toucher aux valeurs existantes.
-- Les tables vides du modèle (codex, stash…) sont des dictionnaires libres : on ne les
-- remplit pas, on garantit seulement qu'elles existent.
local function reconcile(data: any, template: any)
	for key, templateValue in template do
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(templateValue)
		elseif
			typeof(templateValue) == "table"
			and typeof(current) == "table"
			and next(templateValue) ~= nil
		then
			reconcile(current, templateValue)
		end
	end
end

-- Met des données stockées à la version courante.
-- Renvoie (données, nil) ou (nil, raison) avec raison = "Future" (données plus récentes que
-- ce serveur : il ne doit surtout pas les écraser) ou "Invalid".
function ProfileSchema.migrate(stored: any): (ProfileData?, string?)
	if typeof(stored) ~= "table" then
		return nil, "Invalid"
	end
	local data = deepCopy(stored)
	local version = data.version
	if typeof(version) ~= "number" or version ~= math.floor(version) or version < 1 then
		return nil, "Invalid"
	end
	if version > CURRENT_VERSION then
		return nil, "Future"
	end
	while data.version < CURRENT_VERSION do
		local step = MIGRATIONS[data.version]
		if step == nil then
			return nil, "Invalid"
		end
		data = step(data)
		data.version += 1
	end
	reconcile(data, TEMPLATE)
	return data :: ProfileData, nil
end

local MAX_DEPTH = 16

-- Vérifie qu'une valeur peut être stockée sans perte dans un DataStore (JSON).
-- Refuse : Instance, Vector3, CFrame, fonctions…, NaN et infini, clés non textuelles dans
-- un dictionnaire, tableaux à trous, mélange tableau/dictionnaire, imbrication excessive.
-- Renvoie (true, nil) ou (false, chemin du premier problème).
function ProfileSchema.validate(value: any): (boolean, string?)
	local function check(v: any, path: string, depth: number): (boolean, string?)
		local kind = typeof(v)
		if kind == "string" or kind == "boolean" then
			return true, nil
		elseif kind == "number" then
			if v ~= v or v == math.huge or v == -math.huge then
				return false, `{path} (nombre non fini)`
			end
			return true, nil
		elseif kind ~= "table" then
			return false, `{path} (type {kind} non stockable)`
		end
		if depth > MAX_DEPTH then
			return false, `{path} (imbrication trop profonde)`
		end
		local count = 0
		local hasNumberKeys, hasStringKeys = false, false
		for key, child in v do
			count += 1
			if typeof(key) == "number" then
				hasNumberKeys = true
			elseif typeof(key) == "string" then
				hasStringKeys = true
			else
				return false, `{path} (clé de type {typeof(key)})`
			end
			local ok, where = check(child, `{path}.{tostring(key)}`, depth + 1)
			if not ok then
				return false, where
			end
		end
		if hasNumberKeys and hasStringKeys then
			return false, `{path} (mélange tableau et dictionnaire)`
		end
		if hasNumberKeys and #v ~= count then
			return false, `{path} (tableau à trous)`
		end
		return true, nil
	end
	return check(value, "data", 0)
end

return table.freeze(ProfileSchema)
