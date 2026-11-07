--!strict
-- Kit de forteresse (v0.5.1) : pose les modules modélisés dans Blender, avec repli sur la
-- greybox tant qu'ils ne sont pas importés.
-- Studio : ServerScriptService > Server > Place > Lib > Kit (place Éclat)
--
-- Les modules s'importent dans ServerStorage > FortressKit > <Kit_Nom> (un Model par module,
-- une MeshPart par matériau nommée « <Kit_Nom>_<Matériau> »), voir docs/ASSETS.md.
-- Repère d'un module : largeur X, hauteur Y, épaisseur Z ; origine en bas au centre.

local ServerStorage = game:GetService("ServerStorage")

local Kit = {}

-- Rendu Roblox de chaque matériau Blender (suffixe du nom de la pièce).
local LOOKS: { [string]: { material: Enum.Material, color: Color3 } } = {
	Pierre = { material = Enum.Material.Slate, color = Color3.fromRGB(150, 145, 134) },
	PierreSombre = { material = Enum.Material.Slate, color = Color3.fromRGB(86, 84, 82) },
	Toit = { material = Enum.Material.Slate, color = Color3.fromRGB(122, 54, 42) },
	Bois = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(140, 100, 62) },
	Fer = { material = Enum.Material.Metal, color = Color3.fromRGB(70, 70, 76) },
	Laiton = { material = Enum.Material.Metal, color = Color3.fromRGB(190, 150, 70) },
	Toile = { material = Enum.Material.Fabric, color = Color3.fromRGB(196, 178, 140) },
	Cuir = { material = Enum.Material.Fabric, color = Color3.fromRGB(110, 76, 50) },
}

local cache: { [string]: { model: Model, size: Vector3, offsets: { { part: BasePart, cf: CFrame } } } } =
	{}

local function source(name: string)
	-- Seuls les modules trouvés sont retenus : un kit importé plus tard est pris en compte.
	local entry = cache[name]
	if entry then
		return entry
	end
	local folder = ServerStorage:FindFirstChild("FortressKit")
	local model = folder and folder:FindFirstChild(name)
	if model == nil or not model:IsA("Model") then
		return nil
	end
	local cf, size = model:GetBoundingBox()
	-- Repère du module : centre en bas.
	local base = cf * CFrame.new(0, -size.Y / 2, 0)
	local offsets = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(offsets, { part = d, cf = base:ToObjectSpace(d.CFrame) })
		end
	end
	local made = { model = model, size = size, offsets = offsets }
	cache[name] = made
	return made
end

-- Le module est-il importé ?
function Kit.has(name: string): boolean
	return source(name) ~= nil
end

-- Pose le module `name` étiré à `size` (X, Y, Z), base centrée sur `cframe`. Renvoie le Model
-- (non rangé) ou nil si le module n'est pas importé.
function Kit.place(name: string, cframe: CFrame, size: Vector3): Model?
	local src = source(name)
	if src == nil then
		return nil
	end
	local scale = Vector3.new(size.X / src.size.X, size.Y / src.size.Y, size.Z / src.size.Z)
	local out = Instance.new("Model")
	out.Name = name
	for _, entry in src.offsets do
		local part = entry.part:Clone()
		for _, child in part:GetChildren() do
			if not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.Anchored = true
		local p = entry.cf.Position
		part.Size = part.Size * scale
		part.CFrame = cframe
			* CFrame.new(p.X * scale.X, p.Y * scale.Y, p.Z * scale.Z)
			* entry.cf.Rotation
		local suffix = string.match(part.Name, "_([%a]+)$")
		local look = suffix and LOOKS[suffix]
		if look then
			part.Material = look.material
			part.Color = look.color
		end
		part.Parent = out
	end
	return out
end

return Kit
