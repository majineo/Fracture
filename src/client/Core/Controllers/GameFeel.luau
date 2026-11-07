--!strict
-- Effets visuels « de ressenti » (v0.4.9) : tout ce qui rend le jeu agréable à l'œil sans
-- changer les règles. Ne décide rien : lit les attributs répliqués et réagit.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > GameFeel
--
--   * Flash blanc sur toute cible touchée (Échoués, mannequins, joueurs)
--   * Bris en éclats d'un mannequin ou d'un joueur éliminé ; bandeau « ÉLIMINÉ » pour le tireur
--   * Santé basse : vignette rouge qui bat, image désaturée, battements de cœur ; soin : flash
--   * Arme dégainée : l'arme se matérialise (particules cyan), petit son
--   * Noyau chargé : le cœur cyan de l'arme en main brille et scintille (visible par tous)
--   * Course : bouffées de poussière sous les pieds
--   * Ambiance : éclats de Temps qui flottent dans l'air autour de la caméra

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local CombatSounds = require(Client.Combat.CombatSounds)
local ScreenVignette = require(Client.Combat.ScreenVignette)
local VfxTextures = require(Client.Combat.VfxTextures)
local WeaponFx = require(Client.Combat.WeaponFx)
local CameraFeel = require(script.Parent.CameraFeel)
local CombatController = require(script.Parent.CombatController)

local CYAN = Color3.fromRGB(80, 230, 255)
local RED = Color3.fromRGB(220, 40, 40)
local LOW_HEALTH = 0.35
local SPRINT_DUST_FROM = 18
local DUST_INTERVAL = 0.22

local player = Players.LocalPlayer

local GameFeel = {}

type Watched = { lastHealth: number?, dead: boolean, flash: Highlight?, flashUntil: number }
local watched: { [Model]: Watched } = {}

-- Flash blanc ------------------------------------------------------------------------------

local function flash(model: Model, entry: Watched)
	local h = entry.flash
	if h == nil or h.Parent == nil then
		h = Instance.new("Highlight")
		h.Name = "HitFlash"
		h.FillColor = Color3.new(1, 1, 1)
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		entry.flash = h
	end
	entry.flashUntil = os.clock() + 0.12
end

-- Cibles : touchées, éliminées --------------------------------------------------------------

local function updateTargets()
	local clock = os.clock()
	local seen: { [Model]: boolean } = {}
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("MaxHealth") ~= nil then
			seen[model] = true
			local entry = watched[model]
			if entry == nil then
				entry = {
					lastHealth = nil,
					dead = model:GetAttribute("Dead") == true,
					flash = nil,
					flashUntil = 0,
				}
				watched[model] = entry
			end
			local health = model:GetAttribute("Health") :: number?
			if health and entry.lastHealth and health < entry.lastHealth - 0.5 then
				flash(model, entry)
			end
			entry.lastHealth = health
			-- Éliminé (les Échoués ont déjà leur bris dans EnemyVisuals).
			local dead = model:GetAttribute("Dead") == true
			if dead and not entry.dead and model:GetAttribute("EnemyKind") == nil then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					WeaponFx.shatter(root.Position)
					CombatSounds.playAt("EnemyShatter", root.Position, 1.1)
				end
			end
			entry.dead = dead
			local h = entry.flash
			if h then
				local remaining = entry.flashUntil - clock
				h.Enabled = remaining > 0
				h.FillTransparency = 1 - math.clamp(remaining / 0.12, 0, 1) * 0.7
			end
		end
	end
	for model, entry in watched do
		if not seen[model] then
			if entry.flash then
				entry.flash:Destroy()
			end
			watched[model] = nil
		end
	end
end

-- Bandeau « ÉLIMINÉ » --------------------------------------------------------------------------

local banner: TextLabel
local bannerScale: UIScale
local function buildBanner(gui: ScreenGui)
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.38)
	banner.Size = UDim2.fromOffset(420, 50)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 34
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.TextStrokeColor3 = RED
	banner.TextStrokeTransparency = 0.3
	banner.TextTransparency = 1
	banner.TextStrokeTransparency = 1
	banner.Parent = gui
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
end

local function showBanner(text: string, color: Color3)
	banner.Text = text
	banner.TextStrokeColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	bannerScale.Scale = 1.6
	TweenService:Create(bannerScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 })
		:Play()
	task.delay(0.9, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(banner, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end)
end

-- Santé basse / soin ---------------------------------------------------------------------------

local lowVignette: ScreenVignette.Vignette
local healVignette: ScreenVignette.Vignette
local colorCorrection: ColorCorrectionEffect
local heartbeat: Sound?
local myLastHealth: number? = nil
local healFlash = 0

local function buildHealthFx(gui: ScreenGui)
	lowVignette = ScreenVignette.new(gui, RED, 0.2)
	healVignette = ScreenVignette.new(gui, CYAN, 0.16)
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "FractureLowHealth"
	colorCorrection.Parent = Lighting
	local id = CombatSounds.IDS.Heartbeat
	if id then
		local sound = Instance.new("Sound")
		sound.SoundId = id.id
		sound.Volume = 0
		sound.Looped = true
		sound.Parent = gui
		heartbeat = sound
	end
end

local function updateHealthFx(dt: number)
	local character = player.Character
	local health = character and character:GetAttribute("Health") :: number?
	local maxHealth = character and character:GetAttribute("MaxHealth") :: number?
	local fraction = if health and maxHealth and maxHealth > 0 then health / maxHealth else 1
	if character and character:GetAttribute("Downed") == true then
		fraction = 0
	end
	if health and myLastHealth and health > myLastHealth + 0.5 then
		healFlash = 1 -- soin (Retour…) : flash cyan
	end
	myLastHealth = health
	healFlash = math.max(0, healFlash - dt * 2.5)
	healVignette.set(healFlash * 0.6)

	local danger = math.clamp((LOW_HEALTH - fraction) / LOW_HEALTH, 0, 1)
	local beat = 0.5 + 0.5 * math.sin(os.clock() * (5 + danger * 4))
	lowVignette.set(danger * (0.35 + 0.35 * beat))
	colorCorrection.Saturation = -0.55 * danger
	colorCorrection.TintColor = Color3.new(1, 1 - danger * 0.12, 1 - danger * 0.12)
	local sound = heartbeat
	if sound then
		if danger > 0 then
			sound.Volume = 0.25 + 0.45 * danger
			sound.PlaybackSpeed = 1 + danger * 0.35
			if not sound.IsPlaying then
				sound:Play()
			end
		elseif sound.IsPlaying then
			sound:Stop()
		end
	end
end

-- Armes : matérialisation et noyau chargé -------------------------------------------------------

local function emitter(texture: string, color: Color3): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Enabled = false
	p.Texture = texture
	p.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Lifetime = NumberRange.new(0.25, 0.5)
	p.Speed = NumberRange.new(0.5, 2)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new(0, 1)
	return p
end

-- L'arme qui apparaît dans la main se matérialise.
local function materialize(held: Instance)
	for _, part in held:GetDescendants() do
		if part:IsA("BasePart") and part.Size.Magnitude > 0.3 then
			local p = emitter(VfxTextures.get("Shard"), CYAN)
			p.Shape = Enum.ParticleEmitterShape.Box
			p.Parent = part
			p:Emit(math.clamp(math.floor(part.Size.Magnitude * 4), 3, 14))
			Debris:AddItem(p, 0.8)
		end
	end
	local grip = held:FindFirstChild("Grip", true)
	if grip and grip:IsA("BasePart") then
		CombatSounds.playAt("Equip", grip.Position, 1.25)
	end
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "HeldWeapon" then
			task.defer(materialize, child)
		end
	end)
end

-- Noyau chargé : lueur et scintillement sur le cœur cyan de l'arme en main.
local glows: { [Model]: { light: PointLight, sparkle: ParticleEmitter, attachment: Attachment } } =
	{}

local function coreReady(owner: Player, character: Model): boolean
	local weapon = character:GetAttribute("EquippedWeapon")
	if typeof(weapon) ~= "string" or weapon == "" then
		return false
	end
	for slot = 1, 2 do
		if owner:GetAttribute(`Loadout{slot}`) == weapon then
			return ((owner:GetAttribute(`AbilityCharge{slot}`) :: number?) or 0) >= 1
		end
	end
	return false
end

local function corePart(held: Instance): BasePart?
	for _, part in held:GetDescendants() do
		if part:IsA("BasePart") and (part.Name:match("Noyau$") or part.Name == "Core") then
			return part
		end
	end
	return nil
end

local function updateGlows()
	local seen: { [Model]: boolean } = {}
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 7)
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local held = character and character:FindFirstChild("HeldWeapon")
		if character and held and coreReady(owner, character) then
			local part = corePart(held)
			if part then
				seen[character] = true
				local glow = glows[character]
				if glow == nil or glow.attachment.Parent ~= part then
					if glow then
						glow.attachment:Destroy()
					end
					local attachment = Instance.new("Attachment")
					attachment.Name = "CoreGlow"
					attachment.Parent = part
					local light = Instance.new("PointLight")
					light.Color = CYAN
					light.Range = 7
					light.Parent = attachment
					local sparkle = emitter(VfxTextures.get("Glow"), CYAN)
					sparkle.Shape = Enum.ParticleEmitterShape.Box
					sparkle.Rate = 14
					sparkle.Enabled = true
					sparkle.Parent = part
					glow = { light = light, sparkle = sparkle, attachment = attachment }
					glows[character] = glow
				end
				glow.light.Brightness = 1 + pulse * 2.5
			end
		end
	end
	for character, glow in glows do
		if not seen[character] then
			glow.attachment:Destroy()
			glow.sparkle:Destroy()
			glows[character] = nil
		end
	end
end

-- Poussière de course ------------------------------------------------------------------------

local dustNext: { [Model]: number } = {}

local function updateDust()
	local clock = os.clock()
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and root and root:IsA("BasePart") then
			local v = root.AssemblyLinearVelocity
			local running = Vector3.new(v.X, 0, v.Z).Magnitude > SPRINT_DUST_FROM
				and humanoid.FloorMaterial ~= Enum.Material.Air
			if running and clock >= (dustNext[character] or 0) then
				dustNext[character] = clock + DUST_INTERVAL
				local feet = root.Position
					- Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight - 0.1, 0)
				local a = Instance.new("Attachment")
				a.WorldPosition = feet
				a.Parent = workspace.Terrain
				local p = emitter(VfxTextures.get("Dust"), Color3.fromRGB(200, 205, 215))
				p.LightEmission = 0
				p.LightInfluence = 1
				p.Color = ColorSequence.new(Color3.fromRGB(190, 195, 205))
				p.Lifetime = NumberRange.new(0.4, 0.7)
				p.Speed = NumberRange.new(1, 3)
				p.SpreadAngle = Vector2.new(60, 10)
				p.EmissionDirection = Enum.NormalId.Top
				p.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 1.2),
				})
				p.Transparency = NumberSequence.new(0.55, 1)
				p.Parent = a
				p:Emit(3)
				Debris:AddItem(a, 0.9)
			end
		end
	end
	for character in dustNext do
		if character.Parent == nil then
			dustNext[character] = nil
		end
	end
end

-- Ambiance : éclats de Temps en suspension --------------------------------------------------------

local function buildAmbience(): BasePart
	local volume = Instance.new("Part")
	volume.Name = "FractureAmbience"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.Transparency = 1
	volume.Size = Vector3.new(90, 30, 90)
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = VfxTextures.get("Shard")
	motes.Color = ColorSequence.new(CYAN, Color3.new(1, 1, 1))
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Rate = 18
	motes.Lifetime = NumberRange.new(6, 10)
	motes.Speed = NumberRange.new(0.2, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-30, 30)
	motes.Acceleration = Vector3.new(0, 0.15, 0)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.14),
		NumberSequenceKeypoint.new(0.8, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Parent = volume
	volume.Parent = workspace.CurrentCamera
	return volume
end

-- Démarrage ------------------------------------------------------------------------------------

function GameFeel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GameFeel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1 -- sous le reste de l'interface
	gui.Parent = player:WaitForChild("PlayerGui")
	buildBanner(gui)
	buildHealthFx(gui)
	local ambience = buildAmbience()

	CombatController.HitConfirmed:Connect(function(info: any)
		if typeof(info) ~= "table" then
			return
		end
		if info.killed then
			showBanner("ÉLIMINÉ", RED)
			CameraFeel.kick(-1.2)
		elseif info.downed then
			showBanner("À TERRE", Color3.fromRGB(255, 160, 40))
		end
	end)

	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(watchCharacter)
		if other.Character then
			watchCharacter(other.Character)
		end
	end
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if camera then
			if ambience.Parent ~= camera then
				ambience.Parent = camera
			end
			ambience.CFrame = CFrame.new(camera.CFrame.Position)
		end
		updateTargets()
		updateHealthFx(dt)
		updateGlows()
		updateDust()
	end)
end

return GameFeel
