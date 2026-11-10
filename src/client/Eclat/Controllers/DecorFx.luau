--!strict
-- Décor vivant de l'Éclat (v0.12) : feu des torches et braseros, fumée des cheminées, vapeur de la
-- chaudière, éclats cyan des cristaux et des failles, lumières qui vacillent ; rouages, balancier,
-- aiguilles du Donjon, cloche et bannières animés (le temps « accroche »). Tout est local au
-- client (aucun coût réseau) et seuls les effets proches de la caméra sont actifs.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > DecorFx
--
-- Repères posés sur les modèles du kit (ServerStorage > FortressKit, voir docs/ASSETS.md) :
--   Attachment « Fx_<Type> »    : effet (attributs size, radius, count) ;
--   Attachment « Pivot_<Clé> »  : axe d'animation (WorldAxis) des pièces « <Module>_Anim<Clé>_<Mat> »
--                                 (attributs mode, ratio) ;
--   pièces « _Lumiere » / « _Noyau » : lueur chaude / cyan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Client = script:FindFirstAncestor("Client")
assert(Client, "DecorFx doit être sous le LocalScript Client")
local WorldLighting =
	require(Client:WaitForChild("Controllers"):WaitForChild("WorldLighting") :: ModuleScript)
local DecorMotion = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Eclat"):WaitForChild("DecorMotion")
) :: any

local DecorFx = {}

local RANGE_FX = 150 -- distance d'activation des particules et lumières
local RANGE_ANIM = 110 -- distance d'activation des animations
local RANGE_GLOW = 90 -- lueurs des fenêtres et cristaux
local MAX_LIGHTS = 36 -- lumières dynamiques actives au plus (les plus proches)
local MAX_SHADOWS = 4 -- feux les plus proches qui projettent des ombres (coûteux)
local SCAN_PERIOD = 0.35

local TEX = {
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
}
local WARM = Color3.fromRGB(255, 160, 70)
local CYAN = Color3.fromRGB(110, 230, 255)
local VIOLET = Color3.fromRGB(165, 110, 255) -- anomalies rares, toujours discrètes

type Effect = {
	kind: string,
	anchor: Attachment | BasePart,
	seed: number,
	size: number,
	active: boolean,
	built: { Instance },
	light: PointLight?,
	baseBrightness: number,
	baseRange: number,
	warm: boolean, -- feu / lanterne (renforcé la nuit, ombres possibles)
	pulse: boolean, -- true : pulsation lente (cristal) ; false : vacillement (feu)
	nextPuff: number,
	orbit: { BasePart }?,
	radius: number,
	count: number,
}

type Anim = {
	pivot: Attachment,
	key: string,
	mode: string,
	ratio: number,
	seed: number,
	parts: { { part: BasePart, rel: CFrame } },
	active: boolean,
}

local effects: { [Instance]: Effect } = {}
local anims: { [Attachment]: Anim } = {}
local folder: Folder? = nil

local function seqColor(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

local function numSeq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function fire(parent: Instance, s: number): ParticleEmitter
	return emitter(parent, {
		Texture = TEX.fire,
		Color = seqColor(Color3.fromRGB(255, 196, 90), Color3.fromRGB(255, 70, 20)),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.9 * s }, { 0.6, 0.6 * s }, { 1, 0.1 } }),
		Transparency = numSeq({ { 0, 0.25 }, { 0.7, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Rate = 26,
		Speed = NumberRange.new(1.5 * s, 3 * s),
		SpreadAngle = Vector2.new(8, 8),
		RotSpeed = NumberRange.new(-90, 90),
	})
end

local function embers(parent: Instance, s: number, rate: number): ParticleEmitter
	return emitter(parent, {
		Texture = TEX.spark,
		Color = seqColor(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Size = numSeq({ { 0, 0.18 * s }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.2, 2.4),
		Rate = rate,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 1.5,
		Acceleration = Vector3.new(0, 1.5, 0),
	})
end

local function smoke(
	parent: Instance,
	s: number,
	color: Color3,
	rate: number,
	alpha: number
): ParticleEmitter
	return emitter(parent, {
		Texture = TEX.smoke,
		Color = seqColor(color, color),
		LightEmission = 0,
		LightInfluence = 1,
		Size = numSeq({ { 0, 0.8 * s }, { 1, 4 * s } }),
		Transparency = numSeq({ { 0, alpha }, { 0.3, alpha + 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(3, 5),
		Rate = rate,
		Speed = NumberRange.new(1.5, 2.8),
		SpreadAngle = Vector2.new(12, 12),
		RotSpeed = NumberRange.new(-20, 20),
		Acceleration = Vector3.new(0.6, 0.4, 0),
	})
end

local function sparkles(parent: Instance, s: number): ParticleEmitter
	return emitter(parent, {
		Texture = TEX.spark,
		Color = seqColor(Color3.fromRGB(170, 245, 255), CYAN),
		LightEmission = 1,
		Size = numSeq({ { 0, 0 }, { 0.2, 0.3 * s }, { 1, 0 } }),
		Transparency = numSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.8, 3.2),
		Rate = 3 + 3 * s,
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.6, 0),
	})
end

local function addLight(
	e: Effect,
	parent: Instance,
	color: Color3,
	range: number,
	brightness: number
)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = parent
	e.light = light
	e.baseBrightness = brightness
	e.baseRange = range
	e.warm = color.R > 0.9 and color.B < 0.4
	table.insert(e.built, light)
end

local function position(e: Effect): Vector3?
	local a = e.anchor
	if a:IsA("Attachment") then
		return if a.Parent then a.WorldPosition else nil
	end
	return if a.Parent then (a :: BasePart).Position else nil
end

-- Crée les instances de l'effet (au moment où il devient proche).
local function build(e: Effect)
	local at = e.anchor
	local s = e.size
	local k = e.kind
	if k == "Flamme" then
		table.insert(e.built, fire(at, 0.8 * s))
		table.insert(e.built, embers(at, s, 2))
		addLight(e, at, WARM, 14 * s, 1.6)
	elseif k == "Feu" then
		table.insert(e.built, fire(at, 1.3 * s))
		table.insert(e.built, embers(at, s, 6))
		table.insert(e.built, smoke(at, s, Color3.fromRGB(58, 60, 66), 2, 0.7))
		addLight(e, at, WARM, 18 * s, 2)
	elseif k == "Fumee" then
		table.insert(e.built, smoke(at, s, Color3.fromRGB(70, 74, 82), 2.5, 0.55))
	elseif k == "Vapeur" or k == "Soupape" then
		local steam =
			smoke(at, s * 0.8, Color3.fromRGB(225, 232, 238), if k == "Vapeur" then 3 else 0, 0.35)
		steam.Lifetime = NumberRange.new(1.6, 2.6)
		steam.Speed = NumberRange.new(4, 7)
		table.insert(e.built, steam)
	elseif k == "Braises" then
		table.insert(e.built, embers(at, s, 3))
		addLight(e, at, Color3.fromRGB(255, 110, 40), 8 * s, 1.2)
	elseif k == "Eclats" or k == "Faille" then
		table.insert(e.built, sparkles(at, s))
		addLight(e, at, CYAN, 9 + 5 * s, 1.1)
		e.pulse = true
	elseif k == "Lueur" then
		addLight(e, at, CYAN, 10 + 4 * s, 1.3)
		e.pulse = true
	elseif k == "Orbite" and folder then
		local shards = {}
		for i = 1, e.count do
			local p = Instance.new("Part")
			p.Name = "EclatOrbite"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = CYAN
			local sz = 0.35 + (i % 3) * 0.2
			p.Size = Vector3.new(sz, sz * 2.6, sz)
			p.Parent = folder
			table.insert(shards, p)
			table.insert(e.built, p)
		end
		e.orbit = shards
	elseif k == "GlowWarm" then
		addLight(e, at, WARM, 8, 0.7)
	elseif k == "GlowCyan" then
		addLight(e, at, CYAN, 8, 0.6)
		e.pulse = true
	elseif k == "GlowViolet" then
		addLight(e, at, VIOLET, 6, 0.35)
		e.pulse = true
	end
end

local function teardown(e: Effect)
	for _, inst in e.built do
		inst:Destroy()
	end
	table.clear(e.built)
	e.light = nil
	e.orbit = nil
	e.pulse = false
end

local function register(anchor: Attachment | BasePart, kind: string, size: number)
	if effects[anchor] then
		return
	end
	local p = if anchor:IsA("Attachment")
		then anchor.WorldPosition
		else (anchor :: BasePart).Position
	local radius = anchor:GetAttribute("radius")
	local count = anchor:GetAttribute("count")
	effects[anchor] = {
		kind = kind,
		anchor = anchor,
		seed = DecorMotion.seed(p.X, p.Y, p.Z),
		size = size,
		active = false,
		built = {},
		light = nil,
		baseBrightness = 1,
		baseRange = 8,
		warm = false,
		pulse = false,
		nextPuff = 0,
		orbit = nil,
		radius = if typeof(radius) == "number" then radius else 3,
		count = if typeof(count) == "number" then math.clamp(count, 1, 16) else 5,
	}
end

-- Pièces animées d'un pivot : « …_Anim<Clé>_… » dans le même modèle (repos mémorisé).
local function collectParts(a: Anim)
	local host = a.pivot.Parent
	local model = host and host.Parent
	if model == nil then
		return
	end
	local origin = CFrame.new(a.pivot.WorldPosition)
	local tag = "_Anim" .. a.key .. "_"
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.find(child.Name, tag, 1, true) then
			local known = false
			for _, entry in a.parts do
				if entry.part == child then
					known = true
				end
			end
			if not known then
				table.insert(a.parts, { part = child, rel = origin:ToObjectSpace(child.CFrame) })
			end
		end
	end
end

local function onDescendant(d: Instance)
	if d:IsA("Attachment") then
		local name = d.Name
		if string.sub(name, 1, 3) == "Fx_" then
			local size = d:GetAttribute("size")
			register(d, string.sub(name, 4), if typeof(size) == "number" then size else 1)
		elseif string.sub(name, 1, 6) == "Pivot_" and anims[d] == nil then
			local mode = d:GetAttribute("mode")
			local ratio = d:GetAttribute("ratio")
			local p = d.WorldPosition
			local a: Anim = {
				pivot = d,
				key = string.sub(name, 7),
				mode = if typeof(mode) == "string" then mode else "tick",
				ratio = if typeof(ratio) == "number" then ratio else 1,
				seed = DecorMotion.seed(p.X, p.Y, p.Z),
				parts = {},
				active = false,
			}
			anims[d] = a
			collectParts(a)
		end
	elseif d:IsA("BasePart") then
		local suffix = string.match(d.Name, "_(%a+)$")
		if suffix == "Lumiere" and string.sub(d.Name, 1, 5) == "Fort_" then
			register(d, "GlowWarm", 1)
		elseif suffix == "Noyau" and string.sub(d.Name, 1, 5) == "Fort_" then
			register(d, "GlowCyan", 1)
		elseif suffix == "Cristal" and string.sub(d.Name, 1, 5) == "Fort_" then
			register(d, "GlowViolet", 1)
		end
	end
end

local function onRemoving(d: Instance)
	local e = effects[d]
	if e then
		teardown(e)
		effects[d] = nil
	end
	if d:IsA("Attachment") and anims[d] then
		anims[d] = nil
	end
end

-- Active / désactive selon la distance (et garde les lumières les plus proches).
local function refresh()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local lit: { { e: Effect, d: number } } = {}
	for _, e in effects do
		local p = position(e)
		if p == nil then
			continue
		end
		local d = (p - eye).Magnitude
		local glow = e.kind == "GlowWarm" or e.kind == "GlowCyan"
		local want = d < (if glow then RANGE_GLOW else RANGE_FX)
		if want and not e.active then
			build(e)
		elseif not want and e.active then
			teardown(e)
		end
		e.active = want
		if want and e.light then
			table.insert(lit, { e = e, d = d })
		end
	end
	table.sort(lit, function(a, b)
		return a.d < b.d
	end)
	local shadows = 0
	for i, entry in lit do
		local light = entry.e.light
		if light then
			light.Enabled = i <= MAX_LIGHTS
			-- Ombres réalistes pour les quelques feux les plus proches seulement.
			local cast = entry.e.warm and shadows < MAX_SHADOWS and entry.d < 60
			if cast then
				shadows += 1
			end
			light.Shadows = cast
		end
	end
	for _, a in anims do
		if a.pivot.Parent == nil then
			continue
		end
		local d = (a.pivot.WorldPosition - eye).Magnitude
		a.active = d < RANGE_ANIM
		if a.active then
			collectParts(a)
		end
	end
end

local function step()
	local t = os.clock()
	local night = WorldLighting.night()
	for _, e in effects do
		if not e.active then
			continue
		end
		local light = e.light
		if light and light.Enabled then
			-- La nuit, feux et cristaux comptent davantage (Update 2.0, phase 4).
			local f = if e.pulse
				then DecorMotion.pulse(t, e.seed)
				else DecorMotion.flicker(t, e.seed)
			local boost = if e.warm then 1 + 0.9 * night elseif e.pulse then 1 + 0.6 * night else 1
			light.Brightness = e.baseBrightness * f * boost
			light.Range = e.baseRange * (1 + 0.35 * night)
		end
		if e.kind == "Vapeur" or e.kind == "Soupape" then
			if t >= e.nextPuff then
				local steam = e.built[1]
				if steam and steam:IsA("ParticleEmitter") then
					steam:Emit(if e.kind == "Soupape" then 14 else 6)
				end
				e.nextPuff = t
					+ (if e.kind == "Soupape" then 4 + (e.seed % 3) else 1.4 + (e.seed % 1.5))
			end
		end
		local shards = e.orbit
		if shards then
			local center = position(e)
			if center then
				for i, shard in shards do
					local x, y, z = DecorMotion.orbit(t, i, #shards, e.radius)
					shard.CFrame = CFrame.new(center + Vector3.new(x, y, z))
						* CFrame.Angles(t * 0.7 + i, t * 0.5 + i * 2, 0)
				end
			end
		end
	end
	for _, a in anims do
		if not a.active or #a.parts == 0 then
			continue
		end
		local axis = a.pivot.WorldAxis
		local angle = math.rad(DecorMotion.angle(a.mode, t, a.ratio, a.seed))
		local origin = CFrame.new(a.pivot.WorldPosition) * CFrame.fromAxisAngle(axis, angle)
		for _, entry in a.parts do
			if entry.part.Parent then
				entry.part.CFrame = origin * entry.rel
			end
		end
	end
end

function DecorFx.start()
	local f = Instance.new("Folder")
	f.Name = "DecorFx"
	f.Parent = workspace
	folder = f
	for _, d in workspace:GetDescendants() do
		onDescendant(d)
	end
	workspace.DescendantAdded:Connect(onDescendant)
	workspace.DescendantRemoving:Connect(onRemoving)
	task.spawn(function()
		while true do
			refresh()
			task.wait(SCAN_PERIOD)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return DecorFx
