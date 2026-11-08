--!strict
-- Invites d'interaction au style du jeu (v0.9.0) : coffres, caisses, autels, râtelier, portail…
-- remplacent l'invite grise de Roblox par un cartouche encre et laiton, cliquable (souris ou
-- doigt) en plus de la touche E.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > PromptStyle
--
-- Le style « Custom » est appliqué côté client à chaque ProximityPrompt : le serveur n'a rien à
-- changer, et Roblox continue de gérer distance, ligne de vue et durée de maintien.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)

local player = Players.LocalPlayer

local PromptStyle = {}

local shown: { [ProximityPrompt]: { gui: BillboardGui, fill: Frame, tween: Tween? } } = {}

local function adopt(d: Instance)
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "Toucher"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return string.gsub(prompt.GamepadKeyCode.Name, "^Button", "")
	end
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	end)
	return if ok and text ~= "" then text else prompt.KeyboardKeyCode.Name
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if entry then
		shown[prompt] = nil
		entry.gui:Destroy()
	end
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	hide(prompt)
	local adornee = prompt.Parent
	if adornee == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Invite"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(250, 56)
	gui.SizeOffset = Vector2.new(0, 0.6)
	gui.Active = true
	gui.Adornee = adornee
	gui.ResetOnSpawn = false

	local panel = Theme.panel(gui)
	panel.Size = UDim2.fromScale(1, 1)
	local key = Instance.new("Frame")
	key.Name = "Touche"
	key.Position = UDim2.fromOffset(8, 8)
	key.Size =
		UDim2.fromOffset(if inputType == Enum.ProximityPromptInputType.Touch then 64 else 40, 40)
	key.BackgroundColor3 = Theme.INK_LIGHT
	key.BorderSizePixel = 0
	Theme.corner(key, 4)
	Theme.stroke(key, Theme.ARCANE, 1.5)
	key.Parent = panel
	local keyLabel = Theme.label(key, keyText(prompt, inputType), 18, Theme.ARCANE, Theme.BOLD_FONT)
	keyLabel.Size = UDim2.fromScale(1, 1)
	local _, fill = Theme.bar(key, Theme.ARCANE)
	local back = fill.Parent :: Frame
	back.AnchorPoint = Vector2.new(0, 1)
	back.Position = UDim2.new(0, 3, 1, -3)
	back.Size = UDim2.new(1, -6, 0, 4)
	back.Visible = prompt.HoldDuration > 0

	local textX = key.Size.X.Offset + 18
	local action = Theme.label(panel, prompt.ActionText, 19, Theme.PARCHMENT, Theme.BOLD_FONT)
	action.Position = UDim2.fromOffset(textX, 6)
	action.Size = UDim2.new(1, -textX - 10, 0, 24)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextTruncate = Enum.TextTruncate.AtEnd
	local object = Theme.label(panel, prompt.ObjectText, 15, Theme.BRASS)
	object.Position = UDim2.fromOffset(textX, 30)
	object.Size = UDim2.new(1, -textX - 10, 0, 18)
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextTruncate = Enum.TextTruncate.AtEnd

	-- Clic / toucher : équivaut à maintenir la touche.
	local click = Instance.new("TextButton")
	click.Name = "Cliquer"
	click.BackgroundTransparency = 1
	click.Text = ""
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = 5
	click.Parent = panel
	click.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			prompt:InputHoldBegin()
		end
	end)
	click.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			prompt:InputHoldEnd()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	shown[prompt] = { gui = gui, fill = fill, tween = nil }
end

function PromptStyle.start()
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		local entry = shown[prompt]
		if entry then
			entry.fill.Size = UDim2.fromScale(0, 1)
			entry.tween = TweenService:Create(
				entry.fill,
				TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			)
			entry.tween:Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		local entry = shown[prompt]
		if entry then
			if entry.tween then
				entry.tween:Cancel()
			end
			entry.fill.Size = UDim2.fromScale(0, 1)
		end
	end)
end

return PromptStyle
