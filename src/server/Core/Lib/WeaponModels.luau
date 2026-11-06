--!strict
-- Modèles visuels des armes tenues en main (créés par le serveur, donc visibles par tous).
-- Studio : ServerScriptService > Server > Lib > WeaponModels
--
-- ⚠ PROVISOIRE : formes simples en attendant les modèles Blender (docs/ASSETS.md, #4 et #5).
-- Pour brancher un vrai modèle plus tard : le placer dans ServerStorage > WeaponModels avec
-- le même nom que l'identifiant d'arme (ex. "weapon.fracture_pistol") et une pièce « Grip »
-- (la poignée) : il sera utilisé à la place de la forme provisoire.

local ServerStorage = game:GetService("ServerStorage")

local METAL = Color3.fromRGB(45, 48, 56)
local BRISURE_CYAN = Color3.fromRGB(80, 230, 255)
local WOOD = Color3.fromRGB(92, 52, 30)
local BRASS = Color3.fromRGB(176, 128, 58)
local LEATHER = Color3.fromRGB(70, 40, 24)

local build: (id: string) -> Model?

-- Orientation de l'arme par rapport à la main (réglée par mesure en jeu, v0.4.1).
local GRIP_ROTATION = CFrame.Angles(math.rad(-90), 0, 0)

local WeaponModels = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	return p
end

local function weld(a: BasePart, b: BasePart, offset: CFrame)
	b.CFrame = a.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Formes provisoires. Repère de la poignée : -Z = vers l'avant (canon / lame).
local function placeholder(id: string): Model?
	local model = Instance.new("Model")
	model.Name = id
	if id == "weapon.fracture_pistol" then
		local grip = part("Grip", Vector3.new(0.25, 0.7, 0.35), METAL, Enum.Material.Metal)
		grip.Parent = model
		local slide = part("Slide", Vector3.new(0.3, 0.32, 1.25), METAL, Enum.Material.Metal)
		slide.Parent = model
		weld(grip, slide, CFrame.new(0, 0.42, -0.35))
		local core = part("Core", Vector3.new(0.12, 0.12, 0.6), BRISURE_CYAN, Enum.Material.Neon)
		core.Parent = model
		weld(grip, core, CFrame.new(0.17, 0.42, -0.35))
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 0.42, -1.0)
		muzzle.Parent = grip
		model.PrimaryPart = grip
	elseif id == "weapon.short_blade" then
		local grip = part("Grip", Vector3.new(0.22, 0.22, 0.6), METAL, Enum.Material.Metal)
		grip.Parent = model
		local guard = part("Guard", Vector3.new(0.55, 0.12, 0.12), METAL, Enum.Material.Metal)
		guard.Parent = model
		weld(grip, guard, CFrame.new(0, 0, -0.33))
		local blade = part(
			"Blade",
			Vector3.new(0.08, 0.3, 1.9),
			Color3.fromRGB(200, 210, 220),
			Enum.Material.Metal
		)
		blade.Parent = model
		weld(grip, blade, CFrame.new(0, 0, -1.3))
		local edge = part("Edge", Vector3.new(0.05, 0.06, 1.8), BRISURE_CYAN, Enum.Material.Neon)
		edge.Parent = model
		weld(grip, edge, CFrame.new(0, 0.15, -1.3))
		model.PrimaryPart = grip
	elseif id == "weapon.repeating_rifle" then
		local grip = part("Grip", Vector3.new(0.2, 0.3, 0.36), WOOD, Enum.Material.Wood)
		grip.Parent = model
		local stock = part("Stock", Vector3.new(0.22, 0.32, 1.2), WOOD, Enum.Material.Wood)
		stock.Parent = model
		weld(grip, stock, CFrame.new(0, -0.1, 0.95))
		local receiver = part("Receiver", Vector3.new(0.24, 0.3, 0.75), BRASS, Enum.Material.Metal)
		receiver.Parent = model
		weld(grip, receiver, CFrame.new(0, 0.13, -0.35))
		local barrel = part("Barrel", Vector3.new(0.12, 0.12, 2.2), METAL, Enum.Material.Metal)
		barrel.Parent = model
		weld(grip, barrel, CFrame.new(0, 0.21, -1.85))
		local tube = part("Core", Vector3.new(0.08, 0.08, 1.7), BRISURE_CYAN, Enum.Material.Neon)
		tube.Parent = model
		weld(grip, tube, CFrame.new(0, -0.07, -1.6))
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 0.21, -2.95)
		muzzle.Parent = grip
		model.PrimaryPart = grip
	elseif id == "weapon.heavy_crossbow" then
		local grip = part("Grip", Vector3.new(0.17, 0.4, 0.24), WOOD, Enum.Material.Wood)
		grip.Parent = model
		local tiller = part("Tiller", Vector3.new(0.18, 0.2, 2.2), WOOD, Enum.Material.Wood)
		tiller.Parent = model
		weld(grip, tiller, CFrame.new(0, 0.27, -0.55))
		local prod = part(
			"Prod",
			Vector3.new(2.4, 0.1, 0.1),
			Color3.fromRGB(190, 198, 206),
			Enum.Material.Metal
		)
		prod.Parent = model
		weld(grip, prod, CFrame.new(0, 0.32, -1.5))
		local bolt = part("Core", Vector3.new(0.06, 0.06, 1.3), BRISURE_CYAN, Enum.Material.Neon)
		bolt.Parent = model
		weld(grip, bolt, CFrame.new(0, 0.43, -1.0))
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 0.43, -1.75)
		muzzle.Parent = grip
		model.PrimaryPart = grip
	elseif id == "weapon.longsword" then
		local grip = part("Grip", Vector3.new(0.16, 0.16, 0.85), LEATHER, Enum.Material.Fabric)
		grip.Parent = model
		local guard = part("Guard", Vector3.new(1.1, 0.14, 0.1), BRASS, Enum.Material.Metal)
		guard.Parent = model
		weld(grip, guard, CFrame.new(0, 0, -0.47))
		local blade = part(
			"Blade",
			Vector3.new(0.07, 0.34, 3.3),
			Color3.fromRGB(190, 198, 206),
			Enum.Material.Metal
		)
		blade.Parent = model
		weld(grip, blade, CFrame.new(0, 0, -2.2))
		local edge = part("Edge", Vector3.new(0.075, 0.05, 2.6), BRISURE_CYAN, Enum.Material.Neon)
		edge.Parent = model
		weld(grip, edge, CFrame.new(0, 0, -2.0))
		model.PrimaryPart = grip
	else
		return nil
	end
	return model
end

-- Construit le modèle d'une arme (modèle importé s'il existe, forme provisoire sinon).
-- Utilisé aussi par l'armurerie pour les présentoirs.
function WeaponModels.build(id: string): Model?
	return build(id)
end

function build(id: string): Model?
	local folder = ServerStorage:FindFirstChild("WeaponModels")
	local custom = folder and folder:FindFirstChild(id)
	if custom and custom:IsA("Model") then
		local clone = custom:Clone()
		local grip = clone:FindFirstChild("Grip", true)
		if grip and grip:IsA("BasePart") then
			clone.PrimaryPart = grip
			-- Toutes les pièces du modèle (importé depuis Blender) suivent la poignée.
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.Massless = true
					d.CastShadow = false
					if d ~= grip then
						local w = Instance.new("WeldConstraint")
						w.Part0 = grip
						w.Part1 = d
						w.Parent = d
					end
				end
			end
			return clone
		end
	end
	return placeholder(id)
end

-- Place l'arme `id` dans la main droite du personnage (ou retire l'arme si id = nil).
function WeaponModels.equip(character: Model, id: string?)
	local existing = character:FindFirstChild("HeldWeapon")
	if existing then
		existing:Destroy()
	end
	if id == nil then
		return
	end
	local hand = character:FindFirstChild("RightHand")
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	local model = build(id)
	if model == nil or model.PrimaryPart == nil then
		return
	end
	local container = Instance.new("Model")
	container.Name = "HeldWeapon"
	model.Parent = container
	-- Poignée dans la paume, canon / lame dans le prolongement du bras (-Z de la poignée vers
	-- l'avant), dessus de l'arme vers le haut.
	model:PivotTo(hand.CFrame * CFrame.new(0, -0.15, -0.1) * GRIP_ROTATION)
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = model.PrimaryPart
	w.Parent = model.PrimaryPart
	container.Parent = character
end

return table.freeze(WeaponModels)
