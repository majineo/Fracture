--!strict
-- Fenêtre du sac dans l'Éclat (v0.9.0) : Tab / I. Même fenêtre, mêmes briques que le coffre du
-- Refuge (Ui/Menu, Ui/ItemViews). La souris est libre tant qu'elle est ouverte.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > SacUi
--
-- Onglets : Sac (12 emplacements + fiche, bouton Utiliser), Codex (2 capacités emportées),
-- Aide (toutes les commandes). Le serveur décide de tout : les boutons ne font que demander.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefs =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot"):WaitForChild("ItemDefs"))

local Client = script.Parent.Parent.Parent
local Menu = require(Client.Ui.Menu)
local Theme = require(Client.Ui.Theme)
local ItemViews = require(Client.Ui.ItemViews)
local LootHud = require(script.Parent.LootHud)

local player = Players.LocalPlayer

local SacUi = {}

local selected: number? = nil

local function entries(): { ItemViews.Entry }
	local out = {}
	for i, stack in LootHud.stacks() do
		if typeof(stack) == "table" and typeof(stack.id) == "string" then
			out[i] = { id = stack.id, qty = stack.qty }
		end
	end
	return out
end

local function buildSac(window: Menu.Window, content: Frame)
	local items = entries()
	if selected and items[selected] == nil then
		selected = nil
	end
	local left, right = ItemViews.split(content, 4 * 80 + 3 * 8 + 8)
	ItemViews.grid(left, items, 12, 80, selected, function(i)
		selected = i
		window.refresh()
	end)
	local entry = if selected then items[selected] else nil
	local def = entry and ItemDefs.get(entry.id)
	local usable = def ~= nil and (def.heal ~= nil or def.relic == true)
	local actions = ItemViews.details(
		right,
		entry,
		if entry == nil
			then "Choisis un objet pour voir sa fiche. Tout ce qui est dans le sac est perdu à la mort : extrais-toi pour le garder."
			elseif usable then nil
			else "Se rapporte au Refuge pour l'artisanat et la stabilisation."
	)
	if entry and usable then
		local index = selected :: number
		Theme.button(actions, "Utiliser", "Arcane", function()
			LootHud.useSlot(index)
			if def and def.heal then
				Menu.close() -- le soin prend 2,5 s : on rend la main au joueur
			end
		end)
	end
end

local function buildCodex(content: Frame)
	local list = ItemViews.list(content)
	local character = player.Character
	local any = false
	for slot = 1, 2 do
		local id = character and character:GetAttribute(`Codex{slot}`)
		local uses = character and character:GetAttribute(`Codex{slot}Uses`)
		if typeof(id) == "string" and typeof(uses) == "number" then
			any = true
			local key = if slot == 1 then "V" else "B"
			ItemViews.card(
				list,
				slot,
				`[{key}] {ItemViews.name(id)}`,
				`{uses} utilisation(s) restante(s) pour cette vie.`,
				Theme.VIOLET,
				"Utiliser",
				"Violet",
				function()
					LootHud.useCodex(slot)
					Menu.close()
				end
			)
		end
	end
	if not any then
		ItemViews.card(
			list,
			1,
			"Aucune capacité emportée",
			"Stabilise une relique intacte au Refuge, puis équipe-la dans le Codex.",
			Theme.MUTED
		)
	end
end

function SacUi.start()
	local window = Menu.window("Sac", "Sac", Vector2.new(760, 480), { "Sac", "Codex", "Aide" })
	window.onTab = function(tab: string, content: Frame)
		if tab == "Sac" then
			buildSac(window, content)
		elseif tab == "Codex" then
			buildCodex(content)
		else
			ItemViews.help(content)
		end
	end
	Menu.setMain("Sac")
end

return SacUi
