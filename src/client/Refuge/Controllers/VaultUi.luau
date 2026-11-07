--!strict
-- Coffre du Refuge (v0.6.1) : affiche le contenu du coffre et les statistiques du profil.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > VaultUi
--
-- Lecture seule : le contenu vient de l'instantané du profil envoyé par le serveur
-- (ProfileController). Rien ne se modifie ici.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemDefs =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot"):WaitForChild("ItemDefs"))

local Client = script.Parent.Parent.Parent
local Net = require(Client.Lib.Net)
local ProfileController = require(Client.Controllers.ProfileController)

local PANEL = Color3.fromRGB(16, 18, 24)
local GOLD = Color3.fromRGB(230, 190, 90)

local player = Players.LocalPlayer

local VaultUi = {}

local panel: Frame
local list: TextLabel
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

local function refresh()
	local snapshot = ProfileController.get()
	if snapshot == nil then
		list.Text = "Chargement du profil…"
		return
	end
	local lines = { `Grains : {snapshot.grains or 0}`, "" }
	local stash = snapshot.stash
	if typeof(stash) == "table" and #stash > 0 then
		for _, item in stash do
			local def = ItemDefs.get(item.id)
			table.insert(lines, `{item.qty} × {if def then def.name else item.id}`)
		end
	else
		table.insert(lines, "Le coffre est vide : rapporte du butin d'un Éclat.")
	end
	table.insert(lines, "")
	table.insert(
		lines,
		`Extractions : {snapshot.extractions or 0} · Morts : {snapshot.deaths or 0}`
	)
	list.Text = table.concat(lines, "\n")
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VaultUi"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 360)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	panel.Parent = gui
	local title = text(panel, "COFFRE DU REFUGE", 22, GOLD)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 10)
	list = text(panel, "", 15)
	list.Font = Enum.Font.Gotham
	list.Size = UDim2.new(1, -40, 1, -120)
	list.Position = UDim2.fromOffset(20, 56)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
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
	notice.TextStrokeTransparency = 0.4
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
