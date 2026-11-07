--!strict
-- Règles du Codex (v0.7.1, GDD 04 §2). Module pur : opère sur les données du profil (tables
-- simples), appelé par le serveur ; les tests le vérifient hors Studio.
-- Studio : ReplicatedStorage > Shared > Loot > Codex
--
--   * stabiliser : une relique INTACTE du coffre (3/3) + 60 Grains + 1 Acier ancien → la relique
--     devient une capacité permanente (niveau +1, 3 au plus) ;
--   * équiper : 2 capacités du Codex au plus, emportées dans chaque Éclat ;
--   * en partie : chaque capacité équipée a 2 utilisations par vie (3 à partir du niveau 2).

local ItemDefs = require("./ItemDefs")

local Codex = {}

Codex.COST_GRAINS = 60
Codex.COST_MATERIAL = "mat.ancient_steel"
Codex.COST_MATERIAL_QTY = 1
Codex.MAX_LEVEL = 3
Codex.MAX_EQUIPPED = 2

export type Data = {
	grains: number,
	codex: { [string]: number },
	equipped: { string },
	stash: { [string]: { id: string, qty: number } },
}

function Codex.usesFor(level: number): number
	return if level >= 2 then 3 else 2
end

local function materialRecord(data: Data): (string?, number)
	for guid, record in data.stash do
		if record.id == Codex.COST_MATERIAL then
			return guid, record.qty
		end
	end
	return nil, 0
end

-- Renvoie (true, nouveau niveau) ou (false, raison).
function Codex.stabilize(data: Data, guid: unknown): (boolean, number | string)
	if typeof(guid) ~= "string" then
		return false, "Invalide"
	end
	local record = data.stash[guid]
	local def = record and ItemDefs.get(record.id)
	if record == nil or def == nil or not def.relic then
		return false, "PasUneRelique"
	end
	if record.qty < 3 then
		return false, "Abimee"
	end
	local level = data.codex[record.id] or 0
	if level >= Codex.MAX_LEVEL then
		return false, "NiveauMax"
	end
	if data.grains < Codex.COST_GRAINS then
		return false, "Grains"
	end
	local materialGuid, materialQty = materialRecord(data)
	if materialGuid == nil or materialQty < Codex.COST_MATERIAL_QTY then
		return false, "Materiau"
	end
	-- Tout est vérifié : on paie et on stabilise d'un coup.
	data.grains -= Codex.COST_GRAINS
	local material = data.stash[materialGuid]
	material.qty -= Codex.COST_MATERIAL_QTY
	if material.qty <= 0 then
		data.stash[materialGuid] = nil
	end
	data.stash[guid] = nil
	data.codex[record.id] = level + 1
	return true, level + 1
end

-- Équipe (on = true) ou retire une capacité. Renvoie (true, nil) ou (false, raison).
function Codex.equip(data: Data, id: unknown, on: unknown): (boolean, string?)
	if typeof(id) ~= "string" or typeof(on) ~= "boolean" then
		return false, "Invalide"
	end
	local index = table.find(data.equipped, id)
	if not on then
		if index then
			table.remove(data.equipped, index)
		end
		return true, nil
	end
	if (data.codex[id] or 0) <= 0 then
		return false, "NonStabilisee"
	end
	if index then
		return true, nil
	end
	if #data.equipped >= Codex.MAX_EQUIPPED then
		return false, "Plein"
	end
	table.insert(data.equipped, id)
	return true, nil
end

return Codex
