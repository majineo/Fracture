--!strict
-- Couche réseau côté serveur. SEUL endroit où les remotes sont créés et écoutés.
-- Studio : ServerScriptService > Server > Lib > Net
--
-- Au premier require, crée ReplicatedStorage > Remotes avec un RemoteEvent par entrée de
-- Shared > Net > Definitions.
--
--   Net.on("ClientReady", function(player, ...) ... end)  -- remotes "ToServer"
--   Net.fire("ProfileSnapshot", player, payload)           -- remotes "ToClient"
--   Net.fireAll("...", payload)
--
-- Chaque requête entrante passe d'abord par le limiteur de fréquence du remote. Les
-- arguments arrivent en `unknown` : le gestionnaire DOIT les valider (Shared > Util > Guard).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.Net.Definitions)
local RateLimiter = require(script.Parent.RateLimiter)

type RemoteName = Definitions.RemoteName

local DEFAULT_RATE = 10
local DEFAULT_BURST = 20
local OFFENSE_LOG_EVERY = 50 -- journalise un joueur toutes les N requêtes refusées

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local remotes: { [string]: RemoteEvent } = {}
for name in Definitions do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end
folder.Parent = ReplicatedStorage

local limiter = RateLimiter.new()
local offenses: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player)
	limiter.forget(player)
	offenses[player] = nil
end)

local function getRemote(
	name: RemoteName,
	expected: Definitions.Direction
): (RemoteEvent, Definitions.RemoteDef)
	local def = Definitions[name]
	assert(def ~= nil, `[Net] remote inconnu : {name}`)
	assert(def.direction == expected, `[Net] {name} n'est pas un remote {expected}`)
	return remotes[name], def
end

-- Écoute un remote "ToServer". Le gestionnaire reçoit le joueur puis des arguments NON validés.
function Net.on(name: RemoteName, handler: (player: Player, ...unknown) -> ())
	local remote, def = getRemote(name, "ToServer")
	local rate = def.rate or DEFAULT_RATE
	local burst = def.burst or DEFAULT_BURST
	remote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		if not limiter.allow(player, name, rate, burst) then
			local count = (offenses[player] or 0) + 1
			offenses[player] = count
			if count % OFFENSE_LOG_EVERY == 1 then
				warn(`[Net] {player.UserId} dépasse la limite de {name} ({count} refus)`)
			end
			return
		end
		handler(player, ...)
	end)
end

-- Envoie un remote "ToClient" à un joueur.
function Net.fire(name: RemoteName, player: Player, ...: any)
	local remote = getRemote(name, "ToClient")
	remote:FireClient(player, ...)
end

-- Envoie un remote "ToClient" à tous les joueurs.
function Net.fireAll(name: RemoteName, ...: any)
	local remote = getRemote(name, "ToClient")
	remote:FireAllClients(...)
end

return table.freeze(Net)
