--!strict
-- Interface de combat (GDD 09) : réticule, marqueur de touche, munitions, santé et armure,
-- indicateur de dégâts reçus, écran « à terre », barres de vie des mannequins.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > CombatHUD
--
-- Pensée pour le téléphone d'abord : tailles relatives à l'écran, rien dans les coins hauts.
-- ⚠ Style provisoire (formes simples) en attendant la direction artistique de l'interface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("Combat"):WaitForChild("CombatConfig")) :: any
local WeaponDefs = require(Shared.Combat:WaitForChild("WeaponDefs")) :: any
local CombatController = require(script.Parent.CombatController)
local ScreenVignette = require(script.Parent.Parent.Combat.ScreenVignette)

local WHITE = Color3.new(1, 1, 1)
local CYAN = Color3.fromRGB(80, 230, 255)
local ORANGE = Color3.fromRGB(255, 150, 50)
local RED = Color3.fromRGB(255, 70, 60)
local HEALTH_COLOR = Color3.fromRGB(235, 240, 245)
local ARMOR_COLOR = Color3.fromRGB(80, 200, 255)
local PIXELS_PER_DEGREE = 9

local player = Players.LocalPlayer

local CombatHUD = {}

local function frame(name: string, parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius or 1, 0)
	c.Parent = parent
end

local function label(name: string, parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.6
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- Barre horizontale (fond + remplissage) ; renvoie le remplissage.
local function bar(name: string, parent: Instance, position: UDim2, color: Color3): Frame
	local back = frame(name, parent, {
		AnchorPoint = Vector2.new(0, 1),
		Position = position,
		Size = UDim2.fromScale(1, 0.32),
		BackgroundColor3 = Color3.fromRGB(15, 17, 22),
		BackgroundTransparency = 0.35,
	})
	corner(back, 0.5)
	local fill = frame("Fill", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color })
	corner(fill, 0.5)
	return fill
end

function CombatHUD.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Réticule : quatre traits qui s'écartent avec la dispersion, un point central.
	local crosshair = frame("Crosshair", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local dot = frame("Dot", crosshair, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = WHITE,
	})
	corner(dot)
	local ticks: { { frame: Frame, dir: Vector2 } } = {}
	for _, dir in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local vertical = dir.X == 0
		local tick = frame("Tick", crosshair, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if vertical then UDim2.fromOffset(2, 9) else UDim2.fromOffset(9, 2),
			BackgroundColor3 = WHITE,
		})
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Transparency = 0.6
		stroke.Parent = tick
		table.insert(ticks, { frame = tick, dir = dir })
	end
	-- Jauge d'attaque chargée (lame), sous le réticule.
	local chargeBack = frame("Charge", crosshair, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 22),
		Size = UDim2.fromOffset(40, 4),
		BackgroundColor3 = Color3.fromRGB(15, 17, 22),
		BackgroundTransparency = 0.4,
		Visible = false,
	})
	local chargeFill =
		frame("Fill", chargeBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN })

	-- Marqueur de touche : croix en X.
	local hitmarker = frame("Hitmarker", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
	})
	local hitLines: { Frame } = {}
	for i, angle in { 45, 135, 225, 315 } do
		local line = frame("Line" .. i, hitmarker, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(
				0.5,
				math.cos(math.rad(angle)) * 11,
				0.5,
				math.sin(math.rad(angle)) * 11
			),
			Size = UDim2.fromOffset(10, 2),
			Rotation = angle,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
		})
		table.insert(hitLines, line)
	end

	-- Munitions (bas droite).
	local ammoPanel = frame("Ammo", gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.97, 0.95),
		Size = UDim2.fromScale(0.16, 0.09),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local ammoSize = Instance.new("UISizeConstraint")
	ammoSize.MinSize = Vector2.new(130, 50)
	ammoSize.Parent = ammoPanel
	local ammoText = label("Count", ammoPanel, {
		Size = UDim2.fromScale(1, 0.62),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
	})
	-- Compteur qui « saute » à chaque tir (v0.4.9).
	local ammoScale = Instance.new("UIScale")
	ammoScale.Parent = ammoText
	CombatController.Fired:Connect(function()
		ammoScale.Scale = 1.18
		game:GetService("TweenService")
			:Create(ammoScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 })
			:Play()
	end)
	local weaponName = label("Weapon", ammoPanel, {
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.38),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.25,
		Font = Enum.Font.Gotham,
	})

	-- Santé et armure (bas gauche).
	local vitals = frame("Vitals", gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.03, 0.95),
		Size = UDim2.fromScale(0.2, 0.045),
		BackgroundTransparency = 1,
	})
	local vitalsSize = Instance.new("UISizeConstraint")
	vitalsSize.MinSize = Vector2.new(160, 22)
	vitalsSize.Parent = vitals
	local armorFill = bar("Armor", vitals, UDim2.fromScale(0, 0.32), ARMOR_COLOR)
	local healthFill = bar("Health", vitals, UDim2.fromScale(0, 1), HEALTH_COLOR)

	-- Bords rouges quand on est touché + flèche de direction.
	-- (v0.4.9) L'ancienne bordure était dessinée hors de l'écran : voir Combat/ScreenVignette.
	local vignette = ScreenVignette.new(gui, RED, 0.14)
	local indicator = frame("DamageDirection", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 220),
		BackgroundTransparency = 1,
	})
	local arrow = frame("Arrow", indicator, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(34, 8),
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
	})
	corner(arrow, 0.5)

	-- Écran « à terre ».
	local downedLabel = label("Downed", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromScale(0.5, 0.07),
		TextScaled = true,
		TextColor3 = ORANGE,
		Font = Enum.Font.GothamBlack,
		Visible = false,
	})

	-- Étourdi (coup paré par l'adversaire) / parade réussie.
	local stunLabel = label("Stunned", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(0.3, 0.045),
		TextScaled = true,
		TextColor3 = ORANGE,
		Font = Enum.Font.GothamBlack,
		Text = "ÉTOURDI",
		Visible = false,
	})
	local parryFlash = label("Parried", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.3, 0.05),
		TextScaled = true,
		TextColor3 = CYAN,
		Font = Enum.Font.GothamBlack,
		Text = "PARADE !",
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local parryFade = 0
	CombatController.Parried:Connect(function()
		parryFade = 1
	end)

	-- Réactions --------------------------------------------------------------------------
	local hitFade = 0
	CombatController.HitConfirmed:Connect(function(info: any)
		local color = if info.killed then RED elseif info.headshot then ORANGE else WHITE
		for _, line in hitLines do
			line.BackgroundColor3 = color
		end
		hitFade = if info.killed then 1.3 else 1
		hitmarker.Size = UDim2.fromOffset(44, 44)
	end)

	local damageFade = 0
	local damageFrom: Vector3? = nil
	CombatController.Damaged:Connect(function(amount: number, from: any)
		damageFade = math.clamp(0.4 + (amount or 0) / 60, 0.4, 1)
		damageFrom = if typeof(from) == "Vector3" then from else nil
	end)

	-- Barres de vie au-dessus des mannequins (et plus tard des ennemis).
	local overheads: { [Model]: { gui: BillboardGui, fill: Frame } } = {}
	local function overheadFor(model: Model)
		if overheads[model] then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if root == nil then
			return
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(70, 7)
		billboard.StudsOffset = Vector3.new(0, 3.8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 120
		billboard.Adornee = root :: BasePart
		billboard.Parent = gui
		local back = frame("Back", billboard, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(15, 17, 22),
			BackgroundTransparency = 0.3,
		})
		corner(back, 0.5)
		local fill =
			frame("Fill", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HEALTH_COLOR })
		corner(fill, 0.5)
		overheads[model] = { gui = billboard, fill = fill }
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local weaponId = CombatController.getEquipped()
		local def = weaponId and WeaponDefs[weaponId]
		local armed = CombatController.isArmed()

		-- Réticule
		crosshair.Visible = armed
		if armed and def then
			local gap = 6 + CombatController.getSpread() * PIXELS_PER_DEGREE
			if def.kind == "Melee" then
				gap = 0
			end
			for _, tick in ticks do
				tick.frame.Visible = def.kind ~= "Melee"
				tick.frame.Position = UDim2.new(0.5, tick.dir.X * gap, 0.5, tick.dir.Y * gap)
			end
			local charge = CombatController.getMeleeCharge()
			chargeBack.Visible = charge ~= nil
			chargeFill.Size = UDim2.fromScale(charge or 0, 1)
			chargeFill.BackgroundColor3 = if charge and charge >= 1 then ORANGE else CYAN
		end

		-- Étourdi / parade
		stunLabel.Visible = CombatController.getStun() > 0
		parryFade = math.max(0, parryFade - dt * 1.6)
		parryFlash.TextTransparency = 1 - parryFade
		parryFlash.TextStrokeTransparency = 1 - parryFade * 0.6

		-- Marqueur de touche
		hitFade = math.max(0, hitFade - dt * 4)
		for _, line in hitLines do
			line.BackgroundTransparency = 1 - math.min(1, hitFade)
		end
		local size = hitmarker.Size.X.Offset + (34 - hitmarker.Size.X.Offset) * math.min(1, dt * 18)
		hitmarker.Size = UDim2.fromOffset(size, size)

		-- Munitions (sur écran tactile : au-dessus des boutons, hors du bouton de saut Roblox)
		local touchLayout = UserInputService.TouchEnabled
			or player:GetAttribute("QA_ForceMobile") == true
		ammoPanel.Position = if touchLayout
			then UDim2.fromScale(0.97, 0.42)
			else UDim2.fromScale(0.97, 0.95)
		ammoPanel.Visible = def ~= nil
		if def then
			weaponName.Text = def.name
			if def.magazine > 0 then
				local ammo, magazine, reloading = CombatController.getAmmo()
				local progress = CombatController.getReloadProgress()
				ammoText.Text = if reloading and progress
					then `{math.floor(progress * 100)} %`
					else `{ammo} / {magazine}`
				ammoText.TextColor3 = if reloading then CYAN elseif ammo <= 3 then ORANGE else WHITE
			else
				ammoText.Text = "—"
				ammoText.TextColor3 = WHITE
			end
		end

		-- Santé et armure
		if character then
			local health = (character:GetAttribute("Health") :: number?) or CombatConfig.MAX_HEALTH
			local maxHealth = (character:GetAttribute("MaxHealth") :: number?)
				or CombatConfig.MAX_HEALTH
			local armor = (character:GetAttribute("Armor") :: number?) or 0
			local maxArmor = math.max(1, (character:GetAttribute("MaxArmor") :: number?) or 1)
			healthFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
			healthFill.BackgroundColor3 = if health / maxHealth < 0.3 then RED else HEALTH_COLOR
			armorFill.Size = UDim2.fromScale(math.clamp(armor / maxArmor, 0, 1), 1)
			armorFill.Parent.Visible = (character:GetAttribute("MaxArmor") :: number? or 0) > 0

			local downed = character:GetAttribute("Downed") == true
			downedLabel.Visible = downed
			if downed then
				local remaining = (character:GetAttribute("DownedHealth") :: number?) or 0
				downedLabel.Text = `À TERRE — {math.ceil(remaining)}`
			end
		end

		-- Dégâts reçus
		damageFade = math.max(0, damageFade - dt * 1.8)
		vignette.set(damageFade * 0.55)
		local camera = workspace.CurrentCamera
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if damageFrom and camera and root and root:IsA("BasePart") and damageFade > 0 then
			local offset = camera.CFrame:VectorToObjectSpace(damageFrom - root.Position)
			local angle = math.atan2(offset.X, -offset.Z)
			indicator.Rotation = math.deg(angle)
			arrow.BackgroundTransparency = 1 - damageFade
		else
			arrow.BackgroundTransparency = 1
		end

		-- Mannequins et Échoués : barres de vie
		for _, model in workspace:GetChildren() do
			if
				model:IsA("Model")
				and (model:GetAttribute("CombatDummy") or model:GetAttribute("EnemyKind"))
			then
				overheadFor(model)
			end
		end
		for model, entry in overheads do
			if model.Parent == nil then
				entry.gui:Destroy()
				overheads[model] = nil
			else
				local h = (model:GetAttribute("Health") :: number?) or 0
				local m = math.max(1, (model:GetAttribute("MaxHealth") :: number?) or 1)
				entry.fill.Size = UDim2.fromScale(math.clamp(h / m, 0, 1), 1)
				entry.gui.Enabled = h < m or model:GetAttribute("Dead") == true
			end
		end
	end)
end

return CombatHUD
