--!strict
-- Coffres par rareté côté client (Update 2.0, phase 5) : aura sobre selon la rareté, ouverture
-- du couvercle quand le serveur marque le coffre vidé (attribut « Opened »), éclat et son.
-- Purement visuel : le contenu est tiré et donné par le serveur (LootService).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > ChestFx
--
-- Repères posés sur les modèles Fort_Coffre* (FortressKit) : pièces « …_AnimCouvercle_… » et
-- attachement « Lid_Couvercle » sur la charnière (WorldAxis = axe de rotation).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Le LocalScript « Client » contient Combat et Controllers (voir Client/init.client).
local Client = script:FindFirstAncestor("Client")
assert(Client, "ChestFx doit être sous le LocalScript Client")
local CombatSounds =
	require(Client:WaitForChild("Combat"):WaitForChild("CombatSounds") :: ModuleScript)

local ChestFx = {}

local OPEN_ANGLE = math.rad(105)
local OPEN_TIME = 0.5
local AURA_RANGE = 90

-- Aura par rareté : lumière (couleur, portée, intensité) et particules ; rien pour les communs.
type Aura = { color: Color3, range: number, brightness: number, motes: number }
local AURAS: { [string]: Aura } = {
	["Peu commun"] = {
		color = Color3.fromRGB(110, 210, 120),
		range = 6,
		brightness = 0.35,
		motes = 0,
	},
	Rare = { color = Color3.fromRGB(80, 170, 255), range = 8, brightness = 0.55, motes = 2 },
	["Épique"] = {
		color = Color3.fromRGB(190, 110, 255),
		range = 10,
		brightness = 0.75,
		motes = 4,
	},
	["Légendaire"] = {
		color = Color3.fromRGB(255, 190, 70),
		range = 13,
		brightness = 1.0,
		motes = 7,
	},
}

type Chest = {
	part: BasePart,
	rarity: string,
	light: PointLight?,
	motes: ParticleEmitter?,
	opened: boolean,
}

local chests: { [BasePart]: Chest } = {}

local function lidParts(part: BasePart): ({ BasePart }, Attachment?)
	local parts: { BasePart } = {}
	local hinge: Attachment? = nil
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "_AnimCouvercle_", 1, true) then
			table.insert(parts, d)
		elseif d:IsA("Attachment") and d.Name == "Lid_Couvercle" then
			hinge = d
		end
	end
	return parts, hinge
end

-- Ouvre le couvercle autour de la charnière (sens choisi pour que l'avant se soulève).
local function openLid(chest: Chest)
	local parts, hinge = lidParts(chest.part)
	if #parts == 0 or hinge == nil then
		return
	end
	local pivot = hinge.WorldPosition
	local axis = hinge.WorldAxis
	local rest: { CFrame } = {}
	local center = Vector3.zero
	for i, p in parts do
		rest[i] = CFrame.new(pivot):ToObjectSpace(p.CFrame)
		center += p.Position
	end
	center /= #parts
	-- Le bon sens est celui qui fait monter le centre du couvercle.
	local test = CFrame.new(pivot)
		* CFrame.fromAxisAngle(axis, 0.3)
		* CFrame.new(pivot):ToObjectSpace(CFrame.new(center))
	local sign = if test.Position.Y > center.Y then 1 else -1
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / OPEN_TIME, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		local overshoot = math.sin(t * math.pi) * 0.08 * (1 - t)
		local angle = sign * OPEN_ANGLE * (eased + overshoot)
		local frame = CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle)
		for i, p in parts do
			if p.Parent then
				p.CFrame = frame * rest[i]
			end
		end
		if t >= 1 then
			conn:Disconnect()
		end
	end)
end

local function burst(chest: Chest)
	local aura = AURAS[chest.rarity]
	local color = if aura then aura.color else Color3.fromRGB(230, 210, 170)
	local a = Instance.new("Attachment")
	a.WorldPosition = chest.part.Position + Vector3.new(0, chest.part.Size.Y / 2 + 0.3, 0)
	a.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	p.LightEmission = 1
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(0.5, 1.1)
	p.Speed = NumberRange.new(4, 9)
	p.SpreadAngle = Vector2.new(35, 35)
	p.Acceleration = Vector3.new(0, -6, 0)
	p.EmissionDirection = Enum.NormalId.Top
	p.Enabled = false
	p.Parent = a
	p:Emit(if aura then 10 + aura.motes * 3 else 8)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if aura then aura.range + 4 else 8
	light.Brightness = 2
	light.Shadows = false
	light.Parent = a
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	task.delay(1.5, function()
		a:Destroy()
	end)
	CombatSounds.playAt("ChestOpen", chest.part.Position, 0.95 + math.random() * 0.1)
	if chest.rarity == "Rare" or chest.rarity == "Épique" or chest.rarity == "Légendaire" then
		CombatSounds.playAt(
			"ChestRare",
			chest.part.Position,
			if chest.rarity == "Légendaire" then 0.8 else 1
		)
	end
end

local function clearAura(chest: Chest)
	if chest.light then
		chest.light:Destroy()
		chest.light = nil
	end
	if chest.motes then
		chest.motes:Destroy()
		chest.motes = nil
	end
end

local function buildAura(chest: Chest)
	local aura = AURAS[chest.rarity]
	if aura == nil or chest.light then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = aura.color
	light.Range = aura.range
	light.Brightness = aura.brightness
	light.Shadows = false
	light.Parent = chest.part
	chest.light = light
	if aura.motes > 0 then
		local m = Instance.new("ParticleEmitter")
		m.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		m.Color = ColorSequence.new(aura.color)
		m.LightEmission = 1
		m.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		m.Lifetime = NumberRange.new(1.4, 2.2)
		m.Rate = aura.motes
		m.Speed = NumberRange.new(0.6, 1.4)
		m.SpreadAngle = Vector2.new(25, 25)
		m.EmissionDirection = Enum.NormalId.Top
		m.Parent = chest.part
		chest.motes = m
	end
end

local function register(part: BasePart)
	if chests[part] or part:GetAttribute("Loot") ~= "Coffre" then
		return
	end
	local rarity = part:GetAttribute("Rarity")
	if typeof(rarity) ~= "string" then
		return
	end
	local chest: Chest = {
		part = part,
		rarity = rarity,
		light = nil,
		motes = nil,
		opened = part:GetAttribute("Opened") == true,
	}
	chests[part] = chest
	if chest.opened then
		-- Déjà vidé à l'arrivée (streaming) : couvercle ouvert sans effet.
		task.defer(openLid, chest)
	end
	part:GetAttributeChangedSignal("Opened"):Connect(function()
		if part:GetAttribute("Opened") == true and not chest.opened then
			chest.opened = true
			clearAura(chest)
			openLid(chest)
			burst(chest)
		end
	end)
end

function ChestFx.start()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			register(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d:GetAttribute("Loot") == "Coffre" then
			task.defer(register, d)
		end
	end)
	workspace.DescendantRemoving:Connect(function(d)
		local chest = chests[d :: any]
		if chest then
			clearAura(chest)
			chests[d :: any] = nil
		end
	end)
	-- Auras actives près de la caméra seulement.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local camera = workspace.CurrentCamera
			if camera then
				local eye = camera.CFrame.Position
				for _, chest in chests do
					local near = (chest.part.Position - eye).Magnitude < AURA_RANGE
					if near and not chest.opened then
						buildAura(chest)
					elseif not near then
						clearAura(chest)
					end
				end
			end
		end
	end)
end

return ChestFx
