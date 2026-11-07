--!strict
-- Coffre du Refuge et Codex (v0.6.1, v0.7.1) : contenu du coffre, statistiques, stabilisation
-- des reliques intactes et choix des 2 capacités emportées.
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

local PANEL = Color3.fromRGB(16, 18, 24)
local GOLD = Color3.fromRGB(230, 190, 90)
local VIOLET = Color3.fromRGB(190, 110, 255)
local GREY = Color3.fromRGB(170, 170, 170)

local player = Players.LocalPlayer

local VaultUi = {}

local panel: Frame
local list: ScrollingFrame
local notice: TextLabel

local function text(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	l.Parent = parent
	return l
end

local function button(parent: Instance, label: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -4, 0.5, 0)
	b.Size = UDim2.fromOffset(110, 26)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = PANEL
	b.Text = label
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

local order = 0
local function row(value: string, color: Color3?, height: number?): Frame
	order += 1
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, -8, 0, height or 28)
	r.LayoutOrder = order
	local l = text(r, value, 14, color)
	l.Font = Enum.Font.Gotham
	l.Size = UDim2.new(1, -120, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	r.Parent = list
	return r
end

local function refresh()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	order = 0
	local snapshot = ProfileController.get()
	if snapshot == nil then
		row("Chargement du profil…", GREY)
		return
	end
	row(`Grains : {snapshot.grains or 0}`, GOLD)
	-- Codex.
	row("CODEX", VIOLET, 24)
	local equipped = if typeof(snapshot.equipped) == "table" then snapshot.equipped else {}
	local any = false
	for _, id in ItemDefs.RELICS do
		local level = typeof(snapshot.codex) == "table" and snapshot.codex[id] or nil
		if level then
			any = true
			local def = ItemDefs.get(id) :: ItemDefs.ItemDef
			local on = table.find(equipped, id) ~= nil
			local r =
				row(`{def.name} — niveau {level} ({Codex.usesFor(level)} utilisations / vie)`)
			button(r, if on then "Retirer" else "Équiper", if on then GREY else VIOLET, function()
				Net.fire("EquipCodex", id, not on)
			end)
		end
	end
	if not any then
		row("Vide : stabilise une relique intacte rapportée d'un Éclat.", GREY, 40)
	else
		row(`Équipées : {#equipped}/{Codex.MAX_EQUIPPED} (touches V et B dans l'Éclat)`, GREY)
	end
	-- Coffre.
	row("COFFRE", GOLD, 24)
	local stash = snapshot.stash
	if typeof(stash) == "table" and #stash > 0 then
		for _, item in stash do
			local def = ItemDefs.get(item.id)
			if def and def.relic then
				local intact = item.qty >= 3
				local r = row(
					`Relique {def.name} ({item.qty}/3{if intact then ", intacte" else ", abîmée"})`,
					VIOLET
				)
				if intact then
					button(r, "Stabiliser", GOLD, function()
						Net.fire("StabilizeRelic", item.guid)
					end)
				end
			else
				row(`{item.qty} × {if def then def.name else item.id}`)
			end
		end
		row(`Stabiliser : {Codex.COST_GRAINS} Grains + 1 Acier ancien`, GREY)
	else
		row("Le coffre est vide : rapporte du butin d'un Éclat.", GREY)
	end
	row(`Extractions : {snapshot.extractions or 0} · Morts : {snapshot.deaths or 0}`, GREY)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultUi"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 420)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	panel.Parent = gui
	local title = text(panel, "COFFRE DU REFUGE", 22, GOLD)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 8)
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -112)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	list.Parent = panel
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -14)
	close.Size = UDim2.fromOffset(160, 38)
	close.BackgroundColor3 = GOLD
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = PANEL
	close.Text = "Fermer"
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 8)
	c2.Parent = close
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	notice = text(gui, "", 18, Color3.fromRGB(255, 160, 80))
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, 120)
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
			refresh()
			panel.Visible = not panel.Visible
		end
	end)
	ProfileController.Changed:Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	Net.on("Notice", showNotice)
end

return VaultUi
