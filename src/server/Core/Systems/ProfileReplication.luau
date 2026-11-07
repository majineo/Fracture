--!strict
-- Envoie à chaque joueur la vue publique de SON profil (jamais le profil brut ni celui des autres).
-- Studio : ServerScriptService > Server > Systems > ProfileReplication

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Net = require(script.Parent.Parent.Lib.Net)
local PlayerData = require(script.Parent.PlayerData)

local ProfileReplication = {}

local function snapshotOf(data: any): Types.ProfileSnapshot
	local stashCount = 0
	local stash = {}
	for guid, record in data.stash do
		stashCount += 1
		table.insert(stash, { id = record.id, qty = record.qty, guid = guid })
	end
	table.sort(stash, function(a, b)
		return a.id < b.id
	end)
	return {
		rank = data.rank.level,
		xp = data.rank.xp,
		grains = data.grains,
		codex = table.clone(data.codex),
		mastery = table.clone(data.mastery),
		stashCount = stashCount,
		stash = stash,
		equipped = table.clone(data.equipped),
		extractions = data.stats.extractions,
		deaths = data.stats.deaths,
	}
end

-- Renvoie l'instantané à jour d'un joueur (à appeler par les systèmes qui modifient le profil).
function ProfileReplication.push(player: Player)
	local data = PlayerData.get(player)
	if data then
		Net.fire("ProfileSnapshot", player, snapshotOf(data))
	end
end

function ProfileReplication.init()
	-- Le client demande son état quand il est prêt (ses écouteurs sont branchés).
	-- Aucun argument attendu : on ignore tout ce qui est envoyé.
	Net.on("ClientReady", function(player: Player)
		ProfileReplication.push(player)
	end)
	-- Et on l'envoie dès que le profil est chargé, au cas où le client était déjà prêt.
	PlayerData.ProfileLoaded:Connect(function(player: Player)
		ProfileReplication.push(player)
	end)
end

return ProfileReplication
