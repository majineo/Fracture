--!strict
-- Accès au stockage des profils : DataStore Roblox, ou stockage en mémoire dans Studio
-- quand l'accès aux API n'est pas activé.
-- Studio : ServerScriptService > Server > Lib > ProfileStore
--
-- Seul PlayerData utilise ce module. Le reste du jeu ne touche jamais aux DataStores.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DataConfig = require(script.Parent.DataConfig)

export type StoreKind = "DataStore" | "Memory"

export type Store = {
	kind: StoreKind,
	-- Équivalent de UpdateAsync : `transform` reçoit la valeur stockée et renvoie la nouvelle
	-- valeur, ou nil pour ne rien écrire. Peut lever une erreur (à appeler via Retry).
	update: (key: string, transform: (stored: any) -> any) -> (),
}

local ProfileStore = {}

local function fromDataStore(dataStore: DataStore): Store
	return {
		kind = "DataStore",
		update = function(key: string, transform: (any) -> any)
			dataStore:UpdateAsync(key, function(stored: any)
				return transform(stored)
			end)
		end,
	}
end

-- Stockage en mémoire pour Studio. Passe chaque valeur par JSON pour reproduire les
-- contraintes des vrais DataStores (une donnée non sérialisable provoque une erreur ici aussi).
local function memory(): Store
	local entries: { [string]: string } = {}
	return {
		kind = "Memory",
		update = function(key: string, transform: (any) -> any)
			local raw = entries[key]
			local stored = if raw then HttpService:JSONDecode(raw) else nil
			local newValue = transform(stored)
			if newValue ~= nil then
				entries[key] = HttpService:JSONEncode(newValue)
			end
		end,
	}
end

-- Choisit le stockage. En jeu publié : DataStore obligatoire (nil si indisponible, et
-- PlayerData refusera alors les connexions plutôt que de faire jouer sans sauvegarde).
function ProfileStore.open(): Store?
	local isStudio = RunService:IsStudio()
	local name = DataConfig.STORE_NAME .. (if isStudio then DataConfig.STUDIO_STORE_SUFFIX else "")

	local ok, dataStore = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)

	if isStudio then
		local probeOk = ok
			and pcall(function()
				(dataStore :: DataStore):GetAsync("__studio_probe")
			end)
		if not probeOk then
			warn(
				"[PlayerData] Accès aux API désactivé dans Studio : stockage EN MÉMOIRE utilisé"
					.. " (rien n'est conservé après l'arrêt du test)."
			)
			return memory()
		end
	end

	if not ok then
		warn(`[PlayerData] DataStore indisponible : {dataStore}`)
		return nil
	end
	return fromDataStore(dataStore :: DataStore)
end

return table.freeze(ProfileStore)
