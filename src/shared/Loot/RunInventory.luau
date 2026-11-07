--!strict
-- Inventaire de partie (v0.6.0, GDD 02 §4) : 12 emplacements, piles par type d'objet.
-- Module pur : le serveur en garde un par joueur (le client n'en reçoit qu'une copie).
-- Studio : ReplicatedStorage > Shared > Loot > RunInventory

local ItemDefs = require("./ItemDefs")

export type Stack = { id: string, qty: number }
export type Inventory = { capacity: number, stacks: { Stack } }

local RunInventory = {}

RunInventory.SLOTS = 12

function RunInventory.new(capacity: number?): Inventory
	return { capacity = capacity or RunInventory.SLOTS, stacks = {} }
end

local function maxStack(id: string): number
	local def = ItemDefs.get(id)
	return if def then def.maxStack else 1
end

-- Ajoute jusqu'à `qty` objets (remplit les piles existantes, puis de nouveaux emplacements).
-- Renvoie la quantité réellement ajoutée (le reste ne rentre pas).
function RunInventory.add(inv: Inventory, id: string, qty: number): number
	if ItemDefs.get(id) == nil or qty ~= qty or qty <= 0 then
		return 0
	end
	qty = math.floor(qty)
	local cap = maxStack(id)
	local added = 0
	for _, stack in inv.stacks do
		if stack.id == id and stack.qty < cap then
			local n = math.min(cap - stack.qty, qty - added)
			stack.qty += n
			added += n
			if added >= qty then
				return added
			end
		end
	end
	while added < qty and #inv.stacks < inv.capacity do
		local n = math.min(cap, qty - added)
		table.insert(inv.stacks, { id = id, qty = n })
		added += n
	end
	return added
end

function RunInventory.count(inv: Inventory, id: string): number
	local n = 0
	for _, stack in inv.stacks do
		if stack.id == id then
			n += stack.qty
		end
	end
	return n
end

-- Retire `qty` objets ; renvoie la quantité réellement retirée.
function RunInventory.remove(inv: Inventory, id: string, qty: number): number
	local removed = 0
	for i = #inv.stacks, 1, -1 do
		local stack = inv.stacks[i]
		if stack.id == id and removed < qty then
			local n = math.min(stack.qty, qty - removed)
			stack.qty -= n
			removed += n
			if stack.qty <= 0 then
				table.remove(inv.stacks, i)
			end
		end
	end
	return removed
end

-- Vide l'inventaire et renvoie son contenu (regroupé par type d'objet).
function RunInventory.drain(inv: Inventory): { Stack }
	local totals: { [string]: number } = {}
	local order: { string } = {}
	for _, stack in inv.stacks do
		if totals[stack.id] == nil then
			totals[stack.id] = 0
			table.insert(order, stack.id)
		end
		totals[stack.id] += stack.qty
	end
	inv.stacks = {}
	local out = {}
	for _, id in order do
		table.insert(out, { id = id, qty = totals[id] })
	end
	return out
end

function RunInventory.isEmpty(inv: Inventory): boolean
	return #inv.stacks == 0
end

-- Transfère le contenu d'un conteneur (liste de piles, modifiée sur place) vers l'inventaire.
-- Renvoie ce qui a été pris ; ce qui ne rentre pas reste dans le conteneur.
function RunInventory.takeFrom(inv: Inventory, contents: { Stack }): { Stack }
	local taken = {}
	local i = 1
	while i <= #contents do
		local item = contents[i]
		local n = RunInventory.add(inv, item.id, item.qty)
		if n > 0 then
			table.insert(taken, { id = item.id, qty = n })
			item.qty -= n
		end
		if item.qty <= 0 then
			table.remove(contents, i)
		else
			i += 1
		end
	end
	return taken
end

-- Copie sérialisable (envoi au client).
function RunInventory.snapshot(inv: Inventory): { capacity: number, stacks: { Stack } }
	local stacks = {}
	for _, stack in inv.stacks do
		table.insert(stacks, { id = stack.id, qty = stack.qty })
	end
	return { capacity = inv.capacity, stacks = stacks }
end

return RunInventory
