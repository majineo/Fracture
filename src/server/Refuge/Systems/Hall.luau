--!strict
-- Le coffre du Refuge et le portail vers l'Éclat (v0.6.1) — GREYBOX PROVISOIRE.
-- Studio : ServerScriptService > Server > Place > Systems > Hall (place Refuge)
--
-- Coffre : invite « Ouvrir » ; c'est le client qui affiche son contenu (lecture seule, à partir
-- de l'instantané du profil). Portail : le serveur téléporte vers l'Éclat (Travel) ; tant que les
-- places ne sont pas publiées, il prévient le joueur de lancer la place Éclat dans Studio.

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local Travel = require(Core.Systems.Travel)

local VAULT_POSITION = Vector3.new(22, 0, 6)
local PORTAL_POSITION = Vector3.new(0, 0, 34)
local ORANGE = Color3.fromRGB(255, 140, 60)

local Hall = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function buildVault(parent: Instance)
	local chest = part({
		Name = "CoffreDuRefuge",
		Size = Vector3.new(5, 3.2, 3.2),
		CFrame = CFrame.lookAt(VAULT_POSITION + Vector3.new(0, 1.6, 0), Vector3.new(0, 1.6, 0)),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(96, 64, 40),
	})
	local trim = part({
		Size = Vector3.new(5.1, 0.4, 3.3),
		CFrame = chest.CFrame * CFrame.new(0, 0.7, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(190, 150, 70),
		CanCollide = false,
	})
	trim.Parent = chest
	local anchor = Instance.new("Attachment")
	anchor.Position = Vector3.new(0, 3, 0)
	anchor.Parent = chest
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ouvrir"
	prompt.ObjectText = "Coffre"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Vault", true)
	prompt.Parent = anchor
	chest.Parent = parent
end

local function buildPortal(parent: Instance)
	local frame = CFrame.lookAt(PORTAL_POSITION, Vector3.new(0, 0, 0))
	for _, x in { -6, 6 } do
		part({
			Size = Vector3.new(2, 14, 2),
			CFrame = frame * CFrame.new(x, 7, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(88, 86, 84),
		}).Parent =
			parent
	end
	part({
		Size = Vector3.new(14, 2, 2),
		CFrame = frame * CFrame.new(0, 15, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(88, 86, 84),
	}).Parent =
		parent
	local veil = part({
		Name = "PortailEclat",
		Size = Vector3.new(10, 13, 0.4),
		CFrame = frame * CFrame.new(0, 7, 0),
		Material = Enum.Material.Neon,
		Color = ORANGE,
		Transparency = 0.45,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 20
	light.Brightness = 2
	light.Parent = veil
	local anchor = Instance.new("Attachment")
	anchor.Position = Vector3.new(0, -3, 0)
	anchor.Parent = veil
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Partir"
	prompt.ObjectText = "Éclat de la forteresse"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player: Player)
		if not Travel.go(player, "Eclat") then
			Net.fire(
				"Notice",
				player,
				"Le portail s'ouvrira quand le jeu sera publié. Dans Studio : tools\\ouvrir-eclat.ps1"
			)
		end
	end)
	veil.Parent = parent
end

function Hall.start()
	local folder = Instance.new("Folder")
	folder.Name = "Hall"
	folder.Parent = workspace
	buildVault(folder)
	buildPortal(folder)
end

return Hall
