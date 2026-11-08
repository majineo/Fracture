--!strict
-- Interface et effets de l'Éclat (v0.5.0) : chrono de la partie, alertes d'effondrement,
-- fissures et poussière sur les tuiles qui vont tomber, bord d'écran orange (GDD 09 §2).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > EclatHud
--
-- Le client recalcule le plan et le calendrier à partir des attributs du workspace (graine,
-- heure de début, échelle de temps) : aucun message réseau n'est nécessaire.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))
local CollapseSchedule = require(Shared.Eclat:WaitForChild("CollapseSchedule"))

local Client = script.Parent.Parent.Parent
local CombatSounds = require(Client.Combat.CombatSounds)
local ScreenVignette = require(Client.Combat.ScreenVignette)
local VfxTextures = require(Client.Combat.VfxTextures)
local CameraFeel = require(Client.Controllers.CameraFeel)

local ORANGE = Color3.fromRGB(255, 130, 40)
local PHASE_NAMES: { [string]: string } = {
	Exploration = "EXPLORATION",
	Collapse = "EFFONDREMENT",
	FinalRift = "FAILLE FINALE",
	Ended = "L'ÉCLAT S'EFFONDRE",
}

local player = Players.LocalPlayer

local EclatHud = {}

type TileFx = { folder: Folder, cracks: { BasePart }, rumble: Sound? }

local layout: EclatLayout.Layout? = nil
local schedule: CollapseSchedule.Schedule? = nil
local seedSeen: number? = nil
local scaleSeen: number? = nil
local fx: { [Model]: TileFx } = {}

local phaseLabel: TextLabel
local timerLabel: TextLabel
local alertLabel: TextLabel
local vignette: ScreenVignette.Vignette

local function refreshPlan()
	local seed = workspace:GetAttribute("EclatSeed")
	local scale = workspace:GetAttribute("EclatTimeScale")
	if typeof(seed) ~= "number" then
		return
	end
	local s = if typeof(scale) == "number" then scale else 1
	if seed == seedSeen and s == scaleSeen then
		return
	end
	seedSeen, scaleSeen = seed, s
	layout = EclatLayout.generate(seed)
	schedule = CollapseSchedule.build(layout :: EclatLayout.Layout, CollapseSchedule.scaled(s))
end

local function elapsed(): number?
	local start = workspace:GetAttribute("EclatStart")
	if typeof(start) ~= "number" then
		return nil
	end
	return workspace:GetServerTimeNow() - start
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Côté de l'Éclat (« nord »…) des tuiles qui tombent à l'heure `at`.
local function sideName(at: number): string?
	local current, plan = layout, schedule
	if current == nil or plan == nil then
		return nil
	end
	local sx, sz, n = 0, 0, 0
	local mid = (current.size - 1) / 2 -- centre de la grille (et numéro de la couronne extérieure)
	for _, tile in current.tiles do
		if CollapseSchedule.tileCollapseAt(plan, tile.x, tile.z) == at and tile.ring == mid then
			sx += tile.x - mid
			sz += tile.z - mid
			n += 1
		end
	end
	if n == 0 then
		return nil
	end
	if math.abs(sx) > math.abs(sz) then
		return if sx > 0 then "est" else "ouest"
	end
	return if sz > 0 then "sud" else "nord"
end

local function label(parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	return l
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EclatHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	vignette = ScreenVignette.new(gui, ORANGE, 0.18)
	phaseLabel = label(gui, UDim2.fromOffset(320, 22), UDim2.new(0.5, 0, 0, 52), 16)
	phaseLabel.TextColor3 = Color3.fromRGB(230, 220, 200)
	timerLabel = label(gui, UDim2.fromOffset(320, 20), UDim2.new(0.5, 0, 0, 74), 14)
	timerLabel.Font = Enum.Font.Gotham
	alertLabel = label(gui, UDim2.fromOffset(560, 30), UDim2.new(0.5, 0, 0, 100), 22)
	alertLabel.TextColor3 = ORANGE
	alertLabel.TextTransparency = 1
	alertLabel.TextStrokeTransparency = 1
end

local function showAlert(text: string)
	alertLabel.Text = text
	alertLabel.TextTransparency = 0
	alertLabel.TextStrokeTransparency = 0.4
	local scale = alertLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = alertLabel
	scale.Scale = 1.3
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(4, function()
		if alertLabel.Text == text then
			TweenService:Create(
				alertLabel,
				TweenInfo.new(0.8),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
		end
	end)
end

-- Plus grande pièce plate de la tuile : son sol.
local function floorOf(model: Model): BasePart?
	local best: BasePart? = nil
	local area = 0
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Size.Y <= 4.5 then
			local a = d.Size.X * d.Size.Z
			if a > area then
				best, area = d, a
			end
		end
	end
	return best
end

local function startWarning(model: Model)
	if fx[model] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CollapseFx"
	folder.Parent = workspace.CurrentCamera
	local entry: TileFx = { folder = folder, cracks = {}, rumble = nil }
	fx[model] = entry
	local floor = floorOf(model)
	local center = model:GetPivot().Position
	local top = if floor then floor.Position.Y + floor.Size.Y / 2 else 0
	local cx, cz = center.X, center.Z
	if floor then
		cx, cz = floor.Position.X, floor.Position.Z
	end
	-- Fissures orange qui partent du centre et se ramifient.
	local rng = Random.new(cx * 13 + cz)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local length = rng:NextNumber(10, 26)
		local from = Vector3.new(cx, top + 0.06, cz)
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0, 6)
		local to = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * length
		local crack = Instance.new("Part")
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.CanTouch = false
		crack.CastShadow = false
		crack.Material = Enum.Material.Neon
		crack.Color = ORANGE
		crack.Size = Vector3.new(rng:NextNumber(0.25, 0.5), 0.1, length)
		crack.CFrame = CFrame.lookAt((from + to) / 2, to)
		crack.Transparency = 1
		crack.Parent = folder
		table.insert(entry.cracks, crack)
	end
	-- Poussière qui s'échappe du sol.
	local dustAnchor = Instance.new("Part")
	dustAnchor.Anchored = true
	dustAnchor.CanCollide = false
	dustAnchor.CanQuery = false
	dustAnchor.Transparency = 1
	dustAnchor.Size = Vector3.new(56, 0.2, 56)
	dustAnchor.CFrame = CFrame.new(cx, top + 0.2, cz)
	dustAnchor.Parent = folder
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = VfxTextures.get("Dust")
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 140, 120))
	dust.LightEmission = 0
	dust.Rate = 14
	dust.Lifetime = NumberRange.new(1, 2)
	dust.Speed = NumberRange.new(1, 3)
	dust.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	dust.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	dust.Parent = dustAnchor
	-- Grondement qui monte (son 3D au centre de la tuile, en boucle).
	local id = CombatSounds.IDS.CollapseRumble
	if id then
		local rumble = Instance.new("Sound")
		rumble.SoundId = id.id
		rumble.Volume = id.volume
		rumble.Looped = true
		rumble.RollOffMaxDistance = 220
		rumble.RollOffMode = Enum.RollOffMode.InverseTapered
		rumble.Parent = dustAnchor
		rumble:Play()
		entry.rumble = rumble
	end
end

local function stopWarning(model: Model, collapsed: boolean)
	local entry = fx[model]
	if entry == nil then
		return
	end
	fx[model] = nil
	local position = model:GetPivot().Position
	for _, part in entry.folder:GetChildren() do
		if part:IsA("BasePart") and part.Size.X > 40 then
			position = part.Position
			local dust = part:FindFirstChildOfClass("ParticleEmitter")
			if dust and collapsed then
				dust.Rate = 0
				dust.Speed = NumberRange.new(4, 12)
				dust:Emit(80)
			end
		end
	end
	if collapsed then
		CombatSounds.playAt("CollapseHit", position)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < 120 then
				CameraFeel.kick(-2.5 * (1 - distance / 120))
			end
		end
	end
	for _, crack in entry.cracks do
		crack:Destroy()
	end
	if entry.rumble then
		TweenService:Create(entry.rumble, TweenInfo.new(1), { Volume = 0 }):Play()
	end
	Debris:AddItem(entry.folder, 3)
end

local function onTileState(model: Model)
	local state = model:GetAttribute("State")
	if state == "Warning" then
		startWarning(model)
	elseif state == "Collapsed" then
		stopWarning(model, true)
	end
end

local function watchFolder(folder: Instance)
	local function add(child: Instance)
		if child:IsA("Model") then
			child:GetAttributeChangedSignal("State"):Connect(function()
				onTileState(child)
			end)
			onTileState(child)
		end
	end
	for _, child in folder:GetChildren() do
		add(child)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			stopWarning(child, false)
		end
	end)
end

local lastWarnedWave: number? = nil

local function update()
	refreshPlan()
	local t = elapsed()
	local plan = schedule
	if t == nil or plan == nil or layout == nil then
		phaseLabel.Text = ""
		timerLabel.Text = ""
		vignette.set(0)
		return
	end
	local phase = CollapseSchedule.phase(plan, t)
	phaseLabel.Text = PHASE_NAMES[phase] or ""
	local nextAt = CollapseSchedule.nextCollapse(plan, t)
	if phase == "Ended" or nextAt == nil then
		timerLabel.Text = ""
	elseif nextAt == plan.timing.finish then
		timerLabel.Text = `Effondrement total dans {clock(nextAt - t)}`
	else
		local side = sideName(nextAt)
		timerLabel.Text = `Chute du côté {side or "?"} dans {clock(nextAt - t)}`
	end
	-- Alerte 30 s avant chaque chute.
	if nextAt and nextAt - t <= plan.timing.warning and lastWarnedWave ~= nextAt then
		lastWarnedWave = nextAt
		if nextAt == plan.timing.finish then
			showAlert("L'ÉCLAT VA S'EFFONDRER — EXTRAYEZ-VOUS")
		else
			showAlert(`LE CÔTÉ {string.upper(sideName(nextAt) or "?")} VA S'EFFONDRER`)
		end
	end
	-- Bord d'écran orange tant que l'on se tient sur une tuile en alerte.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local intensity = 0
	if root and root:IsA("BasePart") then
		local x, z = EclatLayout.tileFromWorld(
			layout :: EclatLayout.Layout,
			root.Position.X,
			root.Position.Z
		)
		if x and z and CollapseSchedule.tileState(plan, x, z, t) == "Warning" then
			local left = CollapseSchedule.tileCollapseAt(plan, x, z) - t
			intensity = 0.45 + 0.35 * (1 - left / plan.timing.warning)
			intensity *= 0.85 + 0.15 * math.sin(os.clock() * 6)
		end
	end
	vignette.set(intensity)
	-- Fissures qui pulsent et s'élargissent à l'approche de la chute.
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 5)
	for _, entry in fx do
		for _, crack in entry.cracks do
			crack.Transparency = 0.15 + 0.5 * pulse
		end
	end
end

function EclatHud.start()
	buildGui()
	local existing = workspace:FindFirstChild("Eclat")
	if existing then
		watchFolder(existing)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Eclat" and child:IsA("Folder") then
			watchFolder(child)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return EclatHud
