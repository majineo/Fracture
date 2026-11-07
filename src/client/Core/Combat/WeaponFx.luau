--!strict
-- Effets visuels des armes : traçante, lueur de bouche, impact sur le décor, chiffres de
-- dégâts. Purement visuel, côté client.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > WeaponFx

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local TRACER_COLOR = Color3.fromRGB(255, 225, 160)
local BRISURE_CYAN = Color3.fromRGB(80, 230, 255)
local HEAD_COLOR = Color3.fromRGB(255, 180, 60)
local KILL_COLOR = Color3.fromRGB(255, 80, 70)

local WeaponFx = {}

-- Traçante : trait lumineux bref entre la bouche du canon et le point d'arrivée.
function WeaponFx.tracer(origin: Vector3, finish: Vector3)
	local a0 = Instance.new("Attachment")
	a0.WorldPosition = origin
	a0.Parent = workspace.Terrain
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = finish
	a1.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Width0 = 0.08
	beam.Width1 = 0.05
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(TRACER_COLOR)
	beam.Transparency = NumberSequence.new(0.1)
	beam.Parent = a0
	TweenService:Create(beam, TweenInfo.new(0.09), { Width0 = 0, Width1 = 0 }):Play()
	Debris:AddItem(a0, 0.12)
	Debris:AddItem(a1, 0.12)
end

-- Lueur et étincelles à la bouche du canon.
function WeaponFx.muzzleFlash(origin: Vector3, direction: Vector3)
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.lookAt(origin, origin + direction)
	a.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = TRACER_COLOR
	light.Range = 10
	light.Brightness = 4
	light.Parent = a
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(TRACER_COLOR)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.04, 0.08)
	sparks.Speed = NumberRange.new(15, 30)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Parent = a
	sparks:Emit(8)
	Debris:AddItem(a, 0.12)
end

-- Impact sur le décor : petite gerbe de poussière à la couleur de la surface.
function WeaponFx.impact(position: Vector3, normal: Vector3, color: Color3)
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.lookAt(position, position + normal)
	a.Parent = workspace.Terrain
	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3))
	dust.LightInfluence = 1
	dust.Lifetime = NumberRange.new(0.2, 0.45)
	dust.Speed = NumberRange.new(4, 10)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.Acceleration = Vector3.new(0, -25, 0)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	dust.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Parent = a
	dust:Emit(10)
	Debris:AddItem(a, 0.6)
end

-- Chiffre de dégâts flottant au-dessus de la cible.
function WeaponFx.damageNumber(
	position: Vector3,
	amount: number,
	headshot: boolean,
	killed: boolean
)
	local a = Instance.new("Attachment")
	a.WorldPosition = position + Vector3.new(math.random() - 0.5, 3, math.random() - 0.5)
	a.Parent = workspace.Terrain
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 40)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = a
	billboard.Parent = a
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = if killed
		then KILL_COLOR
		elseif headshot then HEAD_COLOR
		else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	local scale = if headshot or killed then 1.25 else 1
	billboard.Size = UDim2.fromOffset(90 * scale, 40 * scale)
	TweenService:Create(a, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		WorldPosition = a.WorldPosition + Vector3.new(0, 2.5, 0),
	}):Play()
	TweenService
		:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		:Play()
	Debris:AddItem(a, 0.75)
end

-- Parade réussie : gerbe d'étincelles cyan et lueur brève à la position donnée.
function WeaponFx.parrySparks(position: Vector3)
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = BRISURE_CYAN
	light.Range = 12
	light.Brightness = 5
	light.Parent = a
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(BRISURE_CYAN, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(12, 26)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Drag = 2
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = a
	sparks:Emit(28)
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	Debris:AddItem(a, 0.5)
end

-- Bris d'un Échoué : éclats cyan projetés et lueur qui s'éteint (le Temps le relâche).
function WeaponFx.shatter(position: Vector3)
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = BRISURE_CYAN
	light.Range = 16
	light.Brightness = 4
	light.Parent = a
	local shards = Instance.new("ParticleEmitter")
	shards.Enabled = false
	shards.Color = ColorSequence.new(BRISURE_CYAN, Color3.fromRGB(150, 160, 175))
	shards.LightEmission = 0.6
	shards.Lifetime = NumberRange.new(0.5, 1.1)
	shards.Speed = NumberRange.new(8, 20)
	shards.SpreadAngle = Vector2.new(180, 180)
	shards.Acceleration = Vector3.new(0, -30, 0)
	shards.Drag = 1.5
	shards.Rotation = NumberRange.new(0, 360)
	shards.RotSpeed = NumberRange.new(-300, 300)
	shards.Shape = Enum.ParticleEmitterShape.Box
	shards.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	shards.Parent = a
	shards:Emit(45)
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(a, 1.3)
end

-- Capacité de déplacement (Retour, Pas de l'ombre) : bouffée au départ et à l'arrivée, trait
-- lumineux qui s'efface entre les deux.
function WeaponFx.abilityTrail(origin: Vector3, finish: Vector3, color: Color3)
	local ends: { Attachment } = {}
	for _, position in { origin, finish } do
		local a = Instance.new("Attachment")
		a.WorldPosition = position
		a.Parent = workspace.Terrain
		local puff = Instance.new("ParticleEmitter")
		puff.Enabled = false
		puff.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		puff.LightEmission = 0.8
		puff.Lifetime = NumberRange.new(0.3, 0.6)
		puff.Speed = NumberRange.new(3, 9)
		puff.SpreadAngle = Vector2.new(180, 180)
		puff.Drag = 3
		puff.Shape = Enum.ParticleEmitterShape.Cylinder
		puff.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		puff.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		puff.Transparency = NumberSequence.new(0.2, 1)
		puff.Parent = a
		puff:Emit(30)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 3
		light.Parent = a
		TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
		Debris:AddItem(a, 1)
		table.insert(ends, a)
	end
	local beam = Instance.new("Beam")
	beam.Attachment0 = ends[1]
	beam.Attachment1 = ends[2]
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.15
	beam.Segments = 1
	beam.Parent = ends[1]
	local start = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / 0.45, 0, 1)
		beam.Transparency = NumberSequence.new(0.2 + 0.8 * t)
		if t >= 1 or beam.Parent == nil then
			connection:Disconnect()
		end
	end)
end

-- Traînée qui suit la VRAIE lame pendant un coup (v0.4.6) : de la garde à la pointe.
function WeaponFx.bladeTrail(character: Model, duration: number, heavy: boolean)
	local held = character:FindFirstChild("HeldWeapon")
	local grip = held and held:FindFirstChild("Grip", true)
	if grip == nil or not grip:IsA("BasePart") then
		return
	end
	-- Longueur de la lame : pièce la plus en avant (-Z) dans le repère de la poignée.
	local tip = 0
	for _, part in (held :: Instance):GetDescendants() do
		if part:IsA("BasePart") then
			local local_ = grip.CFrame:PointToObjectSpace(part.Position)
			tip = math.min(tip, local_.Z - part.Size.Magnitude / 2)
		end
	end
	tip = math.max(tip, -4.5)
	if tip > -0.8 then
		return
	end
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0, tip * 0.25)
	base.Parent = grip
	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, 0, tip * 0.95)
	point.Parent = grip
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = point
	trail.Lifetime = if heavy then 0.2 else 0.13
	trail.LightEmission = 0.9
	trail.FaceCamera = false
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), BRISURE_CYAN)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if heavy then 0.05 else 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.4)
	trail.Parent = grip
	task.delay(duration, function()
		trail.Enabled = false
		task.delay(0.3, function()
			trail:Destroy()
			base:Destroy()
			point:Destroy()
		end)
	end)
end

-- Coup de lame qui porte : gerbe d'étincelles blanches et cyan, éclair bref.
function WeaponFx.meleeImpact(position: Vector3, heavy: boolean)
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), BRISURE_CYAN)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.12, 0.3)
	sparks.Speed = NumberRange.new(10, if heavy then 30 else 20)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Drag = 3
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if heavy then 0.3 else 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = a
	sparks:Emit(if heavy then 30 else 16)
	local light = Instance.new("PointLight")
	light.Color = Color3.new(1, 1, 1)
	light.Range = if heavy then 10 else 6
	light.Brightness = 4
	light.Parent = a
	TweenService:Create(light, TweenInfo.new(0.15), { Brightness = 0 }):Play()
	Debris:AddItem(a, 0.5)
end

-- Traînée de lame (coup de mêlée) le long d'un arc devant le personnage.
function WeaponFx.swingArc(root: BasePart, heavy: boolean, color: Color3?)
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.Parent = root
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.15
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color or BRISURE_CYAN)
	trail.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = root
	local duration = if heavy then 0.28 else 0.18
	local start = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local angle = math.rad(70 - 140 * t) -- de droite à gauche devant le personnage
		local dir = Vector3.new(math.sin(angle), 0.15, -math.cos(angle))
		a0.Position = dir * 1.5 + Vector3.new(0, 0.6, 0)
		a1.Position = dir * 4.2 + Vector3.new(0, 0.6, 0)
		if t >= 1 then
			connection:Disconnect()
			task.delay(0.2, function()
				trail:Destroy()
				a0:Destroy()
				a1:Destroy()
			end)
		end
	end)
end

return WeaponFx
