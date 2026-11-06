--!strict
-- Jauge d'endurance provisoire (sera remplacée par l'interface de combat, GDD 09).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > StaminaBar
--
-- Visible seulement quand la jauge n'est pas pleine ; orange quand le joueur est à bout de
-- souffle. Taille relative à l'écran (lisible sur mobile).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MovementController = require(script.Parent.MovementController)

local COLOR_NORMAL = Color3.fromRGB(80, 230, 255) -- cyan de la Brisure
local COLOR_EXHAUSTED = Color3.fromRGB(255, 140, 50) -- orange de la Brisure
local FADE_SPEED = 4

local StaminaBar = {}

function StaminaBar.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StaminaBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local frame = Instance.new("CanvasGroup")
	frame.Name = "Frame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 0.86)
	frame.Size = UDim2.fromScale(0.22, 0.012)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.GroupTransparency = 1
	frame.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(140, 6)
	sizeLimit.MaxSize = Vector2.new(360, 12)
	sizeLimit.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = COLOR_NORMAL
	fill.BorderSizePixel = 0
	fill.Parent = frame
	corner:Clone().Parent = fill

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function(dt: number)
		local value = MovementController.getStamina()
		fill.Size = UDim2.fromScale(value, 1)
		fill.BackgroundColor3 = if MovementController.isExhausted()
			then COLOR_EXHAUSTED
			else COLOR_NORMAL
		local targetTransparency = if value >= 0.999 then 1 else 0
		local current = frame.GroupTransparency
		frame.GroupTransparency = current
			+ (targetTransparency - current) * math.min(1, dt * FADE_SPEED)
	end)
end

return StaminaBar
