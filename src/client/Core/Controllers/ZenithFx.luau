--!strict
-- Rayon du Zénith (Fusil du Zénith, v0.4.12) : annonce et impact, vus par tous.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > ZenithFx
--
-- Le serveur pose un marqueur (workspace > ZenithStrikes) avec l'heure d'impact. Pendant
-- l'annonce, des cercles runiques dorés s'empilent et tournent au-dessus du point, un rayon
-- descend du ciel et s'élargit ; à l'impact : éclair, gerbe de pointes, onde au sol.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local CombatSounds = require(Client.Combat.CombatSounds)
local VfxTextures = require(Client.Combat.VfxTextures)
local CameraFeel = require(script.Parent.CameraFeel)

local GOLD = Color3.fromRGB(255, 205, 90)
local HOT = Color3.fromRGB(255, 245, 220)
local VIOLET = Color3.fromRGB(170, 95, 255)
local LAYERS = 5
local LAYER_GAP = 7
local SKY = 70

type Strike = {
	marker: BasePart,
	impactAt: number,
	radius: number,
	discs: { { part: BasePart, decal: Decal, height: number, spin: number } },
	beamTop: Attachment,
	beamBottom: Attachment,
	beam: Beam,
	light: PointLight,
}

local ZenithFx = {}

local strikes: { [BasePart]: Strike } = {}

local function disc(position: Vector3, size: number): (BasePart, Decal)
	local part = Instance.new("Part")
	part.Name = "ZenithRune"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(size, 0.05, size)
	part.CFrame = CFrame.new(position)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = VfxTextures.get("Runes")
	decal.Color3 = GOLD
	decal.Transparency = 1
	decal.Parent = part
	local under = decal:Clone()
	under.Face = Enum.NormalId.Bottom
	under.Parent = part
	part.Parent = workspace.Terrain
	return part, decal
end

local function begin(marker: BasePart)
	if strikes[marker] then
		return
	end
	local impactAt = (marker:GetAttribute("ImpactAt") :: number?)
		or (workspace:GetServerTimeNow() + 1)
	local radius = (marker:GetAttribute("Radius") :: number?) or 7
	local origin = marker.Position
	local discs = {}
	for i = 1, LAYERS do
		local height = 0.15 + (i - 1) * LAYER_GAP
		local size = radius * 2 * (1 - (i - 1) * 0.12)
		local part, decal = disc(origin + Vector3.new(0, height, 0), size)
		table.insert(discs, {
			part = part,
			decal = decal,
			height = height,
			spin = (if i % 2 == 0 then -1 else 1) * (0.8 + i * 0.25),
		})
	end
	local top = Instance.new("Attachment")
	top.WorldPosition = origin + Vector3.new(0, SKY, 0)
	top.Parent = workspace.Terrain
	local bottom = Instance.new("Attachment")
	bottom.WorldPosition = origin
	bottom.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = top
	beam.Attachment1 = bottom
	beam.Texture = VfxTextures.get("Beam")
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(HOT, GOLD)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Transparency = NumberSequence.new(0.6)
	beam.Parent = top
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = radius * 3
	light.Brightness = 0
	light.Parent = bottom
	strikes[marker] = {
		marker = marker,
		impactAt = impactAt,
		radius = radius,
		discs = discs,
		beamTop = top,
		beamBottom = bottom,
		beam = beam,
		light = light,
	}
	CombatSounds.playAt("AbilityRewind", origin, 0.6)
end

local function finish(marker: BasePart)
	local strike = strikes[marker]
	if strike == nil then
		return
	end
	strikes[marker] = nil
	for _, d in strike.discs do
		TweenService:Create(d.decal, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(d.part, 0.4)
	end
	TweenService:Create(strike.beam, TweenInfo.new(0.35), { Width0 = 0, Width1 = 0 }):Play()
	Debris:AddItem(strike.beamTop, 0.4)
	Debris:AddItem(strike.beamBottom, 0.6)
end

-- Impact : éclair, gerbe de pointes, onde au sol, secousse si l'on est proche.
local function impact(position: Vector3, radius: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = position + Vector3.new(0, 0.3, 0)
	a.Parent = workspace.Terrain
	local flash = Instance.new("PointLight")
	flash.Color = HOT
	flash.Range = radius * 5
	flash.Brightness = 10
	flash.Parent = a
	TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	local spikes = Instance.new("ParticleEmitter")
	spikes.Enabled = false
	spikes.Texture = VfxTextures.get("Spark")
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.6, GOLD),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	spikes.LightEmission = 1
	spikes.Lifetime = NumberRange.new(0.35, 0.6)
	spikes.Speed = NumberRange.new(30, 55)
	spikes.SpreadAngle = Vector2.new(35, 35)
	spikes.EmissionDirection = Enum.NormalId.Top
	spikes.Drag = 4
	spikes.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	spikes.Parent = a
	spikes:Emit(40)
	local shards = spikes:Clone()
	shards.Texture = VfxTextures.get("Shard")
	shards.Orientation = Enum.ParticleOrientation.FacingCamera
	shards.SpreadAngle = Vector2.new(180, 180)
	shards.Speed = NumberRange.new(10, 26)
	shards.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	shards.Acceleration = Vector3.new(0, -25, 0)
	shards.Parent = a
	shards:Emit(35)
	Debris:AddItem(a, 1.2)
	-- Onde au sol : disque runique qui s'élargit et s'efface.
	local part, decal = disc(position + Vector3.new(0, 0.2, 0), radius * 2)
	decal.Transparency = 0
	decal.Color3 = HOT
	TweenService:Create(
		part,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad),
		{ Size = Vector3.new(radius * 4.5, 0.05, radius * 4.5) }
	):Play()
	TweenService:Create(decal, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.6)
	CombatSounds.playAt("MeleeHitHeavy", position, 0.55)
	CombatSounds.playAt("EnemyShatter", position, 0.8)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local distance = (root.Position - position).Magnitude
		if distance < radius * 6 then
			CameraFeel.kick(-3 * (1 - distance / (radius * 6)))
		end
	end
end

function ZenithFx.start()
	local function watchFolder(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				begin(child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				begin(child)
			end
		end)
		folder.ChildRemoved:Connect(function(child)
			if child:IsA("BasePart") then
				finish(child)
			end
		end)
	end
	local existing = workspace:FindFirstChild("ZenithStrikes")
	if existing then
		watchFolder(existing)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ZenithStrikes" then
			watchFolder(child)
		end
	end)

	local Net = require(Client.Lib.Net)
	Net.on("ShotFx", function(info: any)
		if
			typeof(info) == "table"
			and info.kind == "ZenithImpact"
			and typeof(info.origin) == "Vector3"
		then
			local radius = 7
			for marker, strike in strikes do
				if (marker.Position - info.origin).Magnitude < 2 then
					radius = strike.radius
					finish(marker)
				end
			end
			impact(info.origin, radius)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()
		for marker, strike in strikes do
			if marker.Parent == nil then
				finish(marker)
				continue
			end
			-- Avancement de l'annonce (0 → 1 à l'impact).
			local total = 1.2
			local progress = 1 - math.clamp((strike.impactAt - now) / total, 0, 1)
			for i, d in strike.discs do
				-- Les cercles apparaissent l'un après l'autre, du sol vers le ciel.
				local appear = math.clamp(progress * LAYERS - (i - 1) * 0.6, 0, 1)
				d.decal.Transparency = 1 - appear * (0.85 - (i - 1) * 0.08)
				d.part.CFrame = CFrame.new(marker.Position + Vector3.new(0, d.height, 0))
					* CFrame.Angles(0, clock * d.spin, 0)
			end
			local width = 0.2 + progress * progress * strike.radius * 0.6
			strike.beam.Width0 = width
			strike.beam.Width1 = width * 1.3
			strike.beam.Transparency = NumberSequence.new(0.7 - progress * 0.6)
			strike.light.Brightness = progress * 4
		end
	end)
end

return ZenithFx
