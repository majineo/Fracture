--!strict
-- Coffre du Refuge et Codex (v0.6.1, v0.7.1 ; fenêtre commune en v0.9.0) : même fenêtre et
-- mêmes briques que le sac de l'Éclat (Ui/Menu, Ui/ItemViews). Ouverte par le coffre (invite)
-- ou Tab / I n'importe où dans le Refuge ; la souris est libre tant qu'elle est ouverte.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > VaultUi
--
-- Affichage à partir de l'instantané du profil (ProfileController) ; les boutons envoient une
-- demande au serveur (StabilizeRelic, EquipCodex), qui vérifie tout et renvoie l'instantané.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Loot = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot")
local ItemDefs = require(Loot:WaitForChild("ItemDefs"))
local Codex = require(Loot:WaitForChild("Codex"))

local Client = script.Parent.Parent.Parent
local Net = require(Client.Lib.Net)
local ProfileController = require(Client.Controllers.ProfileController)
local Menu = require(Client.Ui.Menu)
local Theme = require(Client.Ui.Theme)
local ItemViews = require(Client.Ui.ItemViews)

local player = Players.LocalPlayer

local VaultUi = {}

local notice: TextLabel
local selected: number? = nil
local SLOTS = 40

local function buildCoffre(window: Menu.Window, content: Frame, snapshot: any)
	local stash = if typeof(snapshot.stash) == "table" then snapshot.stash else {}
	local items: { ItemViews.Entry } = {}
	for i, item in stash do
		items[i] = { id = item.id, qty = item.qty }
	end
	if selected and items[selected] == nil then
		selected = nil
	end
	local left, right = ItemViews.split(content, 5 * 64 + 4 * 8 + 14)
	ItemViews.grid(left, items, math.max(SLOTS, #items), 64, selected, function(i)
		selected = i
		window.refresh()
	end)
	local entry = if selected then items[selected] else nil
	local def = entry and ItemDefs.get(entry.id)
	if entry and def and def.relic then
		local intact = entry.qty >= 3
		local actions = ItemViews.details(
			right,
			entry,
			if intact
				then `Intacte : stabilise-la pour l'ajouter au Codex ({Codex.COST_GRAINS} Grains + 1 Acier ancien).`
				else "Abîmée : une relique utilisée ne peut plus être stabilisée."
		)
		if intact then
			local guid = stash[selected :: number].guid
			Theme.button(actions, "Stabiliser", "Violet", function()
				Net.fire("StabilizeRelic", guid)
			end)
		end
	else
		ItemViews.details(
			right,
			entry,
			if entry
				then nil
				else `Coffre : tout ce que tu as extrait. Grains : {snapshot.grains or 0}.`
		)
	end
end

local function buildCodex(content: Frame, snapshot: any)
	local list = ItemViews.list(content)
	local equipped = if typeof(snapshot.equipped) == "table" then snapshot.equipped else {}
	local order = 0
	for _, id in ItemDefs.RELICS do
		local level = typeof(snapshot.codex) == "table" and snapshot.codex[id] or nil
		if level then
			order += 1
			local def = ItemDefs.get(id) :: ItemDefs.ItemDef
			local on = table.find(equipped, id) ~= nil
			ItemViews.card(
				list,
				order,
				`{def.name} — niveau {level}`,
				`{Codex.usesFor(level)} utilisations par vie. {if on
					then "Emportée dans l'Éclat."
					else ""}`,
				if on then Theme.ARCANE else Theme.VIOLET,
				if on then "Retirer" else "Équiper",
				if on then "Muted" else "Violet",
				function()
					Net.fire("EquipCodex", id, not on)
				end
			)
		end
	end
	if order == 0 then
		ItemViews.card(
			list,
			1,
			"Codex vide",
			"Rapporte une relique intacte (3 charges) d'un Éclat, puis stabilise-la au coffre.",
			Theme.MUTED
		)
	else
		ItemViews.card(
			list,
			order + 1,
			`Équipées : {#equipped}/{Codex.MAX_EQUIPPED}`,
			"Touches V et B dans l'Éclat.",
			Theme.BRASS
		)
	end
end

local function buildProfil(content: Frame, snapshot: any)
	local list = ItemViews.list(content)
	ItemViews.card(list, 1, "Grains", `{snapshot.grains or 0}`, Theme.BRASS)
	ItemViews.card(list, 2, "Extractions réussies", `{snapshot.extractions or 0}`, Theme.ARCANE)
	ItemViews.card(list, 3, "Morts dans l'Éclat", `{snapshot.deaths or 0}`, Theme.DANGER)
end

local function build()
	local window = Menu.window(
		"Coffre",
		"Coffre du Refuge",
		Vector2.new(820, 500),
		{ "Coffre", "Codex", "Profil", "Aide" }
	)
	window.onTab = function(tab: string, content: Frame)
		local snapshot = ProfileController.get()
		if tab == "Aide" then
			ItemViews.help(content)
			return
		end
		if snapshot == nil then
			local l = Theme.label(content, "Chargement du profil…", 18, Theme.MUTED)
			l.Size = UDim2.fromScale(1, 1)
			return
		end
		if tab == "Coffre" then
			buildCoffre(window, content, snapshot)
		elseif tab == "Codex" then
			buildCodex(content, snapshot)
		else
			buildProfil(content, snapshot)
		end
	end
	Menu.setMain("Coffre")

	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultNotice"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")
	notice = Theme.label(gui, "", 20, Theme.COPPER, Theme.BOLD_FONT)
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, 10) -- au-dessus des fenêtres (v0.9.0)
	notice.Size = UDim2.fromOffset(700, 30)
	notice.TextTransparency = 1
	notice.TextStrokeTransparency = 1
end

local function showNotice(message: any)
	if typeof(message) ~= "string" then
		return
	end
	notice.Text = message
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = 0.4
	task.delay(4, function()
		if notice.Text == message then
			TweenService:Create(
				notice,
				TweenInfo.new(0.8),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
		end
	end)
end

function VaultUi.start()
	build()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("Vault") == true then
			local window = Menu.get("Coffre")
			if window then
				window.tab = "Coffre"
			end
			Menu.toggle("Coffre")
		end
	end)
	ProfileController.Changed:Connect(function()
		Menu.refresh("Coffre")
	end)
	Net.on("Notice", showNotice)
end

return VaultUi
