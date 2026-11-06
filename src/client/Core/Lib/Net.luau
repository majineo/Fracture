--!strict
-- Couche réseau côté client. N'accède qu'aux remotes créés par le serveur.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Lib > Net
--
--   Net.fire("ClientReady")                              -- remotes "ToServer"
--   Net.on("ProfileSnapshot", function(payload) ... end) -- remotes "ToClient"
--
-- Le client ne fait que DEMANDER : le serveur valide et décide de tout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Definitions")
)

type RemoteName = Definitions.RemoteName

local WAIT_TIMEOUT = 30

local Net = {}

local folder = ReplicatedStorage:WaitForChild("Remotes", WAIT_TIMEOUT)
assert(folder ~= nil, "[Net] dossier Remotes introuvable (le serveur n'a pas démarré ?)")

local function getRemote(name: RemoteName, expected: Definitions.Direction): RemoteEvent
	local def = Definitions[name]
	assert(def ~= nil, `[Net] remote inconnu : {name}`)
	assert(def.direction == expected, `[Net] {name} n'est pas un remote {expected}`)
	local remote = (folder :: Instance):WaitForChild(name, WAIT_TIMEOUT)
	assert(remote ~= nil and remote:IsA("RemoteEvent"), `[Net] remote {name} introuvable`)
	return remote
end

-- Envoie une requête au serveur (remote "ToServer").
function Net.fire(name: RemoteName, ...: any)
	getRemote(name, "ToServer"):FireServer(...)
end

-- Écoute un message du serveur (remote "ToClient").
function Net.on(name: RemoteName, handler: (...any) -> ()): RBXScriptConnection
	return getRemote(name, "ToClient").OnClientEvent:Connect(handler)
end

return table.freeze(Net)
