--!strict
-- Interface du Gardien (v0.8.0) : barre de vie et phase, zones annonçant chaque attaque (règle de
-- lisibilité, GDD 07 §1), couronne exposée, et messages courts (« Notice ») dans l'Éclat.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > GuardianHud
--
-- Tout vient des attributs du modèle du Gardien (Guardian, Health, MaxHealth, GuardianPhase,
-- GuardianAction, GuardianActionEnd, CrownExposedUntil) : le client ne fait qu'afficher.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent.Parent
local Net = require(Client.Lib.Net)
local CombatSounds = require(Client.Combat.CombatSounds)

local RED = Color3.fromRGB(255, 70, 50)
local GOLD = Color3.fromRGB(240, 200, 80)
local PHASES = { "Le Roi", "La Couronne brisée", "Le Temps arrêté" }

local player = Players.LocalPlayer

local GuardianHud = {}

local bar: Frame
local fill: Frame
local title: TextLabel
local crownLabel: TextLabel
local notice: TextLabel
local marker: BasePart
local highlight: Highlight
local lastAction: string? = nil

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.Text = text
	l.Parent = parent
	return l
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuardianHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 140)
	bar.Size = UDim2.fromOffset(460, 12)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	bar.BackgroundTransparency = 0.2
	bar.Visible = false
	bar.Parent = gui
	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = bar
	title = label(bar, "", 16, GOLD)
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0, -2)
	title.Size = UDim2.fromOffset(460, 20)
	crownLabel = label(bar, "COURONNE EXPOSÉE — visez la tête (×2)", 15, GOLD)
	crownLabel.AnchorPoint = Vector2.new(0.5, 0)
	crownLabel.Position = UDim2.new(0.5, 0, 1, 4)
	crownLabel.Size = UDim2.fromOffset(460, 20)
	crownLabel.Visible = false
	notice = label(gui, "", 22, GOLD)
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, 180)
	notice.Size = UDim2.fromOffset(700, 30)
	notice.TextTransparency = 1
	notice.TextStrokeTransparency = 1
	marker = Instance.new("Part")
	marker.Name = "GuardianTelegraph"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = RED
	marker.Transparency = 1
	marker.Parent = workspace.CurrentCamera
	highlight = Instance.new("Highlight")
	highlight.FillColor = GOLD
	highlight.OutlineColor = GOLD
	highlight.FillTransparency = 0.4
	highlight.Enabled = false
	highlight.Parent = gui
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

local function findGuardian(): Model?
	for _, m in workspace:GetChildren() do
		if
			m:IsA("Model")
			and m:GetAttribute("Guardian") == true
			and m:GetAttribute("Dead") ~= true
		then
			return m
		end
	end
	return nil
end

-- Zone au sol de l'attaque annoncée : arc devant, bande de charge, cercle d'onde.
local function telegraph(model: Model, action: string?, endsAt: number?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if action == nil or endsAt == nil or root == nil or not root:IsA("BasePart") then
		marker.Transparency = 1
		return
	end
	local left = endsAt - workspace:GetServerTimeNow()
	local _, size = model:GetBoundingBox()
	local floorY = root.Position.Y - size.Y / 2 + 0.15
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local base = Vector3.new(root.Position.X, floorY, root.Position.Z)
	local pulse = 0.35 + 0.25 * math.sin(os.clock() * 12)
	if action == "Swing" then
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.2, 30, 30)
		marker.CFrame = CFrame.new(base + flat * 6) * CFrame.Angles(0, 0, math.pi / 2)
	elseif action == "Charge" then
		marker.Shape = Enum.PartType.Block
		marker.Size = Vector3.new(10, 0.2, 60)
		marker.CFrame = CFrame.lookAt(base + flat * 30, base + flat * 60)
	elseif action == "Shockwave" then
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.2, 40, 40)
		marker.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2)
	else
		marker.Transparency = 1
		return
	end
	marker.Transparency = if left > 0 then pulse else 1
end

local function update()
	local model = findGuardian()
	if model == nil then
		bar.Visible = false
		marker.Transparency = 1
		highlight.Enabled = false
		return
	end
	local health = (model:GetAttribute("Health") :: number?) or 0
	local maxHealth = (model:GetAttribute("MaxHealth") :: number?) or 1
	local phase = (model:GetAttribute("GuardianPhase") :: number?) or 1
	bar.Visible = true
	fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	title.Text = `LE ROI SANS HEURE — {PHASES[phase] or ""}`
	local action = model:GetAttribute("GuardianAction") :: string?
	local endsAt = model:GetAttribute("GuardianActionEnd") :: number?
	telegraph(model, action, endsAt)
	if action ~= lastAction then
		lastAction = action
		local root = model:FindFirstChild("HumanoidRootPart")
		if action and root and root:IsA("BasePart") then
			CombatSounds.playAt("EnemyWindup", root.Position, 0.6)
		end
	end
	local exposed = ((model:GetAttribute("CrownExposedUntil") :: number?) or 0)
		> workspace:GetServerTimeNow()
	crownLabel.Visible = exposed
	local crown = model:FindFirstChild("Couronne") or model:FindFirstChild("Head__Laiton", true)
	highlight.Adornee = crown or model:FindFirstChild("Head")
	highlight.Enabled = exposed
end

function GuardianHud.start()
	build()
	Net.on("Notice", showNotice)
	RunService.RenderStepped:Connect(update)
end

return GuardianHud
