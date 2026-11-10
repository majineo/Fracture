--!strict
-- Boutons tactiles (mobile prioritaire, D-009) : disposition pensée pour le pouce droit,
-- autour du bouton de saut de Roblox (bas droite).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > MobileControls
--
--            [Arme]
--      [Grappin]   [Viser/Parer]
--  [Glisser]   [ TIRER ]   [Recharger]
--      [Sprint]        (Saut Roblox)
--
-- Les boutons s'adaptent à la situation : « Viser » devient « Parer » avec une arme de mêlée,
-- les boutons de combat s'estompent mains nues, Sprint s'allume quand il est actif.
-- Affiché seulement sur écran tactile (ou en test Studio avec l'attribut QA_ForceMobile).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AbilityController = require(script.Parent.AbilityController)
local CombatController = require(script.Parent.CombatController)
local MovementController = require(script.Parent.MovementController)
local PlayerCamera = require(script.Parent.PlayerCamera)

local CYAN = Color3.fromRGB(80, 230, 255)
local DARK = Color3.fromRGB(18, 20, 26)

local player = Players.LocalPlayer

local MobileControls = {}

type ButtonSpec = {
	name: string,
	text: string,
	position: UDim2, -- dans le cadre d'ancrage (bas droite de l'écran)
	size: number, -- part de la hauteur du cadre
	onPress: (() -> ())?,
	onRelease: (() -> ())?,
}

local function makeButton(parent: Frame, spec: ButtonSpec): TextButton
	local button = Instance.new("TextButton")
	button.Name = spec.name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = spec.position
	button.Size = UDim2.fromScale(spec.size, spec.size)
	button.SizeConstraint = Enum.SizeConstraint.RelativeYY
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.Text = spec.text
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = CYAN
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MinTextSize = 11
	textSize.MaxTextSize = 30
	textSize.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.16, 0)
	padding.PaddingRight = UDim.new(0.16, 0)
	padding.PaddingTop = UDim.new(0.3, 0)
	padding.PaddingBottom = UDim.new(0.3, 0)
	padding.Parent = button

	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			button.BackgroundTransparency = 0.1
			if spec.onPress then
				spec.onPress()
			end
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			button.BackgroundTransparency = 0.35
			if spec.onRelease then
				spec.onRelease()
			end
		end
	end)
	return button
end

local function shouldShow(): boolean
	return UserInputService.TouchEnabled or player:GetAttribute("QA_ForceMobile") == true
end

function MobileControls.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MobileControls"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = shouldShow()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Cadre d'ancrage : carré en bas à droite, taille relative à la hauteur de l'écran.
	local anchor = Instance.new("Frame")
	anchor.Name = "Cluster"
	anchor.BackgroundTransparency = 1
	anchor.AnchorPoint = Vector2.new(1, 1)
	anchor.Position = UDim2.new(1, -150, 1, -20) -- laisse la place au bouton de saut Roblox
	anchor.Size = UDim2.fromScale(0.5, 0.5)
	anchor.SizeConstraint = Enum.SizeConstraint.RelativeYY
	anchor.Parent = gui

	local fire = makeButton(anchor, {
		name = "Fire",
		text = "TIRER",
		position = UDim2.fromScale(0.62, 0.62),
		size = 0.34,
		onPress = function()
			CombatController.touchFire(true)
		end,
		onRelease = function()
			CombatController.touchFire(false)
		end,
	})
	local aim = makeButton(anchor, {
		name = "Aim",
		text = "Viser",
		position = UDim2.fromScale(0.86, 0.3),
		size = 0.22,
		onPress = CombatController.touchAim,
		onRelease = CombatController.touchAimRelease,
	})
	local reload = makeButton(anchor, {
		name = "Reload",
		text = "Rech.",
		position = UDim2.fromScale(0.98, 0.66),
		size = 0.2,
		onPress = CombatController.touchReload,
	})
	makeButton(anchor, {
		name = "Weapon",
		text = "Arme",
		position = UDim2.fromScale(0.6, 0.1),
		size = 0.2,
		onPress = CombatController.touchCycle,
	})
	local sprint = makeButton(anchor, {
		name = "Sprint",
		text = "Sprint",
		position = UDim2.fromScale(0.3, 0.9),
		size = 0.2,
		onPress = MovementController.touchSprint,
	})
	makeButton(anchor, {
		name = "Slide",
		text = "Glisser",
		position = UDim2.fromScale(0.18, 0.62),
		size = 0.2,
		onPress = MovementController.touchSlide,
	})
	makeButton(anchor, {
		name = "Grapple",
		text = "Grappin",
		position = UDim2.fromScale(0.32, 0.3),
		size = 0.2,
		onPress = MovementController.touchGrapple,
	})

	-- Élan (v0.4.11) : au sol ou en l'air.
	makeButton(anchor, {
		name = "Dash",
		text = "Élan",
		position = UDim2.fromScale(0.04, 0.36),
		size = 0.2,
		onPress = MovementController.touchDash,
	})

	-- Vue (Update 2.0) : première personne → dos → face, comme F5 sur PC.
	makeButton(anchor, {
		name = "View",
		text = "Vue",
		position = UDim2.fromScale(0.27, 0.04),
		size = 0.16,
		onPress = PlayerCamera.cycle,
	})

	-- Capacité de l'arme (v0.4.5) : le contour se remplit avec le noyau.
	local ability = makeButton(anchor, {
		name = "Ability",
		text = "Capa.",
		position = UDim2.fromScale(0.95, 0.04),
		size = 0.2,
		onPress = AbilityController.press,
		onRelease = AbilityController.release,
	})
	local abilityStroke = ability:FindFirstChildOfClass("UIStroke") :: UIStroke

	RunService.RenderStepped:Connect(function()
		gui.Enabled = shouldShow()
		if gui.Enabled then
			local charge, abilityName = AbilityController.getState()
			ability.Visible = abilityName ~= nil
			local ready = charge >= 1
			ability.Text = if ready then "PRÊT" else `{math.floor(charge * 100)}%`
			abilityStroke.Thickness = if ready then 4 else 2
			abilityStroke.Transparency = if ready then 0 else 0.8 - 0.6 * charge
			ability.TextColor3 = if ready then CYAN else Color3.new(1, 1, 1)
		end
		if not gui.Enabled then
			return
		end
		local armed = CombatController.isArmed()
		local melee = CombatController.isMeleeEquipped()
		-- Mains nues : le bouton de tir donne un coup de poing (Update 2.0).
		fire.Text = if melee or not armed then "FRAPPER" else "TIRER"
		aim.Text = if melee then "Parer" else "Viser"
		fire.TextTransparency = 0
		aim.TextTransparency = if armed then 0 else 0.6
		reload.Visible = armed and not melee
		local stroke = sprint:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if MovementController.isSprintToggled() then 0 else 0.5
		end
	end)
end

return MobileControls
