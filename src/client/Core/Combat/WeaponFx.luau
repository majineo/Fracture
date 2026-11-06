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

-- Traînée de lame (coup de mêlée) le long d'un arc devant le personnage.
function WeaponFx.swingArc(root: BasePart, heavy: boolean)
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
	trail.Color = ColorSequence.new(BRISURE_CYAN)
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
