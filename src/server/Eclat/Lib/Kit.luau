--!strict
-- Kit de forteresse (v0.5.1) et de la Cité d'Horlogerie (v0.11.0) : pose les modules modélisés
-- dans Blender, avec repli sur la greybox tant qu'ils ne sont pas importés.
-- Studio : ServerScriptService > Server > Place > Lib > Kit (place Éclat)
--
-- Les modules s'importent dans ServerStorage > FortressKit > <Kit_Nom> ou CityKit > <Cite_Nom>
-- (un Model par module, une MeshPart par matériau nommée « <Module>_<Matériau> »), voir
-- docs/ASSETS.md. Repère d'un module : largeur X, hauteur Y, épaisseur Z ; origine en bas au
-- centre. Modules de la Cité : l'origine est le pivot du modèle (origine Blender) ; leur
-- empreinte est donnée par Shared/Eclat/Districts.MODULES (les balcons dépassent).

local ServerStorage = game:GetService("ServerStorage")

local Kit = {}

-- Rendu Roblox de chaque matériau Blender (suffixe du nom de la pièce).
-- Kit gothique (v0.12) : palette de l'Art-Direction, matériaux lisses (le relief vient de la
-- géométrie, pas des textures Roblox).
local LOOKS: { [string]: { material: Enum.Material, color: Color3 } } = {
	Pierre = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(80, 85, 93) },
	PierreSombre = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(50, 54, 61) },
	PierreClaire = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(148, 151, 157) },
	Lumiere = { material = Enum.Material.Neon, color = Color3.fromRGB(214, 118, 46) },
	Tissu = { material = Enum.Material.Fabric, color = Color3.fromRGB(122, 31, 36) },
	Mousse = { material = Enum.Material.Grass, color = Color3.fromRGB(78, 107, 58) },
	Toit = { material = Enum.Material.Slate, color = Color3.fromRGB(122, 54, 42) },
	Bois = { material = Enum.Material.Wood, color = Color3.fromRGB(104, 72, 46) },
	Fer = { material = Enum.Material.Metal, color = Color3.fromRGB(52, 55, 62) },
	Laiton = { material = Enum.Material.Metal, color = Color3.fromRGB(190, 150, 70) },
	Toile = { material = Enum.Material.Fabric, color = Color3.fromRGB(196, 178, 140) },
	Cuir = { material = Enum.Material.Fabric, color = Color3.fromRGB(110, 76, 50) },
	-- Cité d'Horlogerie (v0.11.0)
	Brique = { material = Enum.Material.Brick, color = Color3.fromRGB(150, 84, 64) },
	Enduit = { material = Enum.Material.Plaster, color = Color3.fromRGB(226, 212, 180) },
	Ardoise = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(47, 62, 87) },
	Cuivre = { material = Enum.Material.Metal, color = Color3.fromRGB(96, 160, 140) },
	Vitre = { material = Enum.Material.Glass, color = Color3.fromRGB(40, 62, 82) },
	Noyau = { material = Enum.Material.Neon, color = Color3.fromRGB(80, 230, 255) },
	Cristal = { material = Enum.Material.Neon, color = Color3.fromRGB(150, 90, 240) },
	Metal = { material = Enum.Material.Metal, color = Color3.fromRGB(42, 45, 52) },
	Acier = { material = Enum.Material.Metal, color = Color3.fromRGB(190, 198, 206) },
}
local DECOR: { [string]: boolean } = { Noyau = true, Cristal = true, Lumiere = true, Tissu = true }
local FOLDERS = { "FortressKit", "CityKit" }

local cache: { [string]: { model: Model, size: Vector3, offsets: { { part: BasePart, cf: CFrame } } } } =
	{}

local function source(name: string)
	-- Seuls les modules trouvés sont retenus : un kit importé plus tard est pris en compte.
	local entry = cache[name]
	if entry then
		return entry
	end
	local model: Instance? = nil
	for _, folderName in FOLDERS do
		local folder = ServerStorage:FindFirstChild(folderName)
		local found = folder and folder:FindFirstChild(name)
		if found and found:IsA("Model") then
			model = found
			break
		end
	end
	if model == nil or not model:IsA("Model") then
		return nil
	end
	local cf, size = model:GetBoundingBox()
	-- Repère du module : la pièce « <Module>_Origine » (origine Blender, kit gothique v0.12) ;
	-- sinon le pivot du modèle (Cité) ou le centre du bas de la boîte englobante (kit v0.6).
	local marker: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "_Origine$") then
			marker = d
		end
	end
	local base = if marker
		then CFrame.new(marker.Position) * cf.Rotation
		elseif string.sub(name, 1, 5) == "Cite_" then model.WorldPivot
		else cf * CFrame.new(0, -size.Y / 2, 0)
	local offsets = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= marker then
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
	return Kit.placeScaled(
		name,
		cframe,
		Vector3.new(size.X / src.size.X, size.Y / src.size.Y, size.Z / src.size.Z)
	)
end

-- Pose le module `name` à l'échelle `scale` (facteurs X, Y, Z ; 1 = taille modélisée), origine
-- du module sur `cframe` (Cité, v0.11.0). nil si le module n'est pas importé.
function Kit.placeScaled(name: string, cframe: CFrame, scale: Vector3): Model?
	local src = source(name)
	if src == nil then
		return nil
	end
	local out = Instance.new("Model")
	out.Name = name
	local poses: { Attachment } = {}
	for _, entry in src.offsets do
		local part = entry.part:Clone()
		for _, child in part:GetChildren() do
			if child:IsA("Attachment") then
				-- Repères d'effets (Fx_*), pivots d'animation (Pivot_*) et modules à poser (Pose_*),
				-- v0.12 : leur position suit l'étirement de la pièce.
				local q = child.Position
				child.Position = Vector3.new(q.X * scale.X, q.Y * scale.Y, q.Z * scale.Z)
				if string.sub(child.Name, 1, 5) == "Pose_" then
					table.insert(poses, child)
				end
			elseif not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.Anchored = true
		local p = entry.cf.Position
		part.Size = part.Size * scale
		part.CFrame = cframe
			* CFrame.new(p.X * scale.X, p.Y * scale.Y, p.Z * scale.Z)
			* entry.cf.Rotation
		-- Pièces animées par le client (rouages, balancier, aiguilles, cloche, bannière).
		if string.find(part.Name, "_Anim", 1, true) then
			part.CanCollide = false
			part.CanQuery = false
		end
		local suffix = string.match(part.Name, "_([%a]+)$")
		local look = suffix and LOOKS[suffix]
		if look then
			part.Material = look.material
			part.Color = look.color
		end
		-- Lumières, cristaux et tissus : décor traversable (on ne bute pas sur une lueur).
		if suffix and DECOR[suffix] then
			part.CanCollide = false
		end
		part.Parent = out
	end
	-- Torches, braseros… posés sur les repères « Pose_<Module> » (à l'échelle 1, jamais étirés).
	for _, att in poses do
		local child = string.sub(att.Name, 6)
		if child ~= name then
			local placed = Kit.placeScaled(child, att.WorldCFrame, Vector3.one)
			if placed then
				placed.Parent = out
			end
		end
		att:Destroy()
	end
	return out
end

return Kit
