--!strict
-- Codex au Refuge (v0.7.1) : stabiliser une relique intacte du coffre, équiper 2 capacités.
-- Studio : ServerScriptService > Server > Place > Systems > CodexService (place Refuge)
--
-- Les règles (coût, niveaux, limite d'équipement) sont dans Shared/Loot/Codex (testées). Le
-- serveur applique sur le profil du joueur puis renvoie l'instantané ; le client ne décide rien.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Codex =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot"):WaitForChild("Codex"))
local ItemDefs = require(ReplicatedStorage.Shared.Loot:WaitForChild("ItemDefs"))

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local PlayerData = require(Core.Systems.PlayerData)
local ProfileReplication = require(Core.Systems.ProfileReplication)

local REASONS: { [string]: string } = {
	Invalide = "Demande invalide.",
	PasUneRelique = "Ce n'est pas une relique.",
	Abimee = "Seule une relique intacte (3 charges) peut être stabilisée.",
	NiveauMax = "Cette capacité est déjà au niveau maximal.",
	Grains = `Il faut {Codex.COST_GRAINS} Grains.`,
	Materiau = "Il faut 1 Acier ancien dans le coffre.",
	NonStabilisee = "Stabilise d'abord cette relique.",
	Plein = `{Codex.MAX_EQUIPPED} capacités au plus : retires-en une.`,
}

local CodexService = {}

function CodexService.init()
	-- Test dans Studio uniquement : workspace:SetAttribute("QA_SeedCodex", true) donne au premier
	-- joueur une Stase intacte, une Onde de choc abîmée, 2 Aciers anciens et 150 Grains.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("QA_SeedCodex"):Connect(function()
			local player = Players:GetPlayers()[1]
			local data = player and PlayerData.get(player)
			if workspace:GetAttribute("QA_SeedCodex") ~= true or data == nil then
				return
			end
			data.stash[HttpService:GenerateGUID(false)] = { id = "relic.stase", qty = 3 }
			data.stash[HttpService:GenerateGUID(false)] = { id = "relic.onde_de_choc", qty = 1 }
			data.stash[HttpService:GenerateGUID(false)] = { id = "mat.ancient_steel", qty = 2 }
			data.grains += 150
			ProfileReplication.push(player :: Player)
			workspace:SetAttribute("QA_SeedCodex", nil)
		end)
	end
	Net.on("StabilizeRelic", function(player: Player, guid: unknown)
		local data = PlayerData.get(player)
		if data == nil then
			return
		end
		local id = typeof(guid) == "string" and data.stash[guid] and data.stash[guid].id or nil
		local ok, result = Codex.stabilize(data :: any, guid)
		if ok then
			local def = id and ItemDefs.get(id)
			Net.fire(
				"Notice",
				player,
				`{def and def.name or "Relique"} stabilisée — niveau {result} au Codex`
			)
			ProfileReplication.push(player)
		else
			Net.fire("Notice", player, REASONS[result :: string] or "Impossible.")
		end
	end)
	Net.on("EquipCodex", function(player: Player, id: unknown, on: unknown)
		local data = PlayerData.get(player)
		if data == nil then
			return
		end
		local ok, reason = Codex.equip(data :: any, id, on)
		if ok then
			ProfileReplication.push(player)
		else
			Net.fire("Notice", player, REASONS[reason :: string] or "Impossible.")
		end
	end)
end

return CodexService
