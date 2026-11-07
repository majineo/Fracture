--!strict
-- Extraction (v0.6.0, GDD 02 §3 et 05 §5) : points secondaires ouverts 90 s, Faille finale sur
-- le Donjon. Rester 8 s dans une zone ouverte sans subir de dégâts : le butin porté passe dans
-- le coffre du profil en une seule opération serveur, puis le joueur quitte l'Éclat.
-- Studio : ServerScriptService > Server > Place > Systems > ExtractionService (place Éclat)
--
-- Répliqué : workspace > Eclat > Extraction_i (zone visible, attributs OpensAt / ClosesAt /
-- Final, en secondes de partie) ; attribut « ExtractProgress » (secondes) sur le personnage.
-- ⚠ En jeu publié, le joueur extrait devra être téléporté au Refuge (TeleportService) ; pour
-- l'instant il reçoit son bilan et peut repartir dans l'Éclat (places non encore publiées).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))
local ExtractionPlan = require(Shared.Eclat:WaitForChild("ExtractionPlan"))
local ItemDefs = require(Shared:WaitForChild("Loot"):WaitForChild("ItemDefs"))

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local HealthService = require(Core.Systems.HealthService)
local PlayerData = require(Core.Systems.PlayerData)
local ProfileReplication = require(Core.Systems.ProfileReplication)
local EclatService = require(script.Parent.EclatService)
local LootService = require(script.Parent.LootService)

local TICK = 0.1
local CYAN = Color3.fromRGB(80, 230, 255)
local ORANGE = Color3.fromRGB(255, 140, 60)

-- Où poser la zone dans chaque type de tuile (repère tourné, y = sol), à l'écart des décors.
local ZONE_OFFSETS: { [string]: Vector3 } = {
	CourArmes = Vector3.new(0, 1.2, 0),
	Village = Vector3.new(0, 0, 9),
	Remparts = Vector3.new(-4, 0, 10),
	TourGuet = Vector3.new(-12, 0, -10),
	PontLevis = Vector3.new(4, 0, 20),
	Crypte = Vector3.new(0, 0, 18),
	Donjon = Vector3.new(0, 16, -8), -- la Faille finale, sur le toit
}

type Zone = { point: ExtractionPlan.Point, position: Vector3, part: BasePart }

local ExtractionService = {}

local zones: { Zone } = {}
local progress: { [Player]: number } = {}
local lastHurt: { [Player]: number } = {}

local function buildZones(layout: EclatLayout.Layout)
	zones = {}
	local schedule = EclatService.schedule()
	local folder = workspace:FindFirstChild("Eclat")
	if schedule == nil or folder == nil then
		return
	end
	for i, point in ExtractionPlan.build(layout, schedule) do
		local tile = EclatLayout.tileAt(layout, point.x, point.z) :: EclatLayout.Tile
		local offset = ZONE_OFFSETS[tile.kind] or Vector3.zero
		local position = EclatService.tileFrame(tile):PointToWorldSpace(offset)
		local part = Instance.new("Part")
		part.Name = `Extraction_{i}`
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = if point.final then ORANGE else CYAN
		part.Transparency = 0.6
		part.Size = Vector3.new(0.3, ExtractionPlan.RADIUS * 2, ExtractionPlan.RADIUS * 2)
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		part:SetAttribute("OpensAt", point.opensAt)
		part:SetAttribute("ClosesAt", point.closesAt)
		part:SetAttribute("Final", point.final)
		-- La zone appartient à sa tuile (elle tombe avec elle).
		local tileModel = folder:FindFirstChild(`Tile_{point.x}_{point.z}`)
		part.Parent = tileModel or folder
		table.insert(zones, { point = point, position = position, part = part })
	end
end

local function openZoneAt(position: Vector3, elapsed: number): Zone?
	for _, zone in zones do
		if zone.part.Parent and ExtractionPlan.isOpen(zone.point, elapsed) then
			local d = position - zone.position
			if
				Vector3.new(d.X, 0, d.Z).Magnitude <= ExtractionPlan.RADIUS
				and math.abs(d.Y) < 6
			then
				return zone
			end
		end
	end
	return nil
end

-- Transaction d'extraction : inventaire de partie -> coffre du profil, en une fois.
local function extract(player: Player)
	local profile = PlayerData.get(player)
	if profile == nil then
		return -- profil indisponible : on n'extrait pas (le butin reste porté)
	end
	local items = LootService.drain(player)
	local grains = 0
	for _, item in items do
		if item.id == ItemDefs.GRAINS then
			grains += item.qty
		else
			-- Un seul enregistrement par type de matériau (GUID stable), quantités cumulées.
			local merged = false
			for _, record in profile.stash do
				if record.id == item.id then
					record.qty += item.qty
					merged = true
					break
				end
			end
			if not merged then
				profile.stash[HttpService:GenerateGUID(false)] = { id = item.id, qty = item.qty }
			end
		end
	end
	profile.grains += grains
	profile.stats.extractions += 1
	ProfileReplication.push(player)
	local stashCount = 0
	for _ in profile.stash do
		stashCount += 1
	end
	Net.fire("ExtractionResult", player, {
		items = items,
		grains = grains,
		totalGrains = profile.grains,
		extractions = profile.stats.extractions,
		stashTypes = stashCount,
	})
	print(`[Extraction] {player.Name} : {#items} pile(s), {grains} Grains`)
	player:SetAttribute("Extracted", true)
	progress[player] = nil
	local character = player.Character
	if character then
		-- Détruire le personnage ne vide pas Player.Character : on le fait nous-mêmes.
		player.Character = nil
		character:Destroy()
	end
end

local function step()
	local elapsed = EclatService.elapsed()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local zone = nil
			if
				character:GetAttribute("Dead") ~= true
				and character:GetAttribute("Downed") ~= true
			then
				zone = openZoneAt(root.Position, elapsed)
			end
			local hurt = now - (lastHurt[player] or 0) < TICK * 1.5
			local p = ExtractionPlan.step(progress[player] or 0, TICK, zone ~= nil, hurt)
			progress[player] = p
			character:SetAttribute("ExtractProgress", if p > 0 then p else nil)
			if p >= ExtractionPlan.HOLD then
				extract(player)
			end
		end
	end
end

function ExtractionService.init()
	EclatService.Built:Connect(function(layout: any)
		progress = {}
		-- Les tuiles viennent d'être construites dans le même appel : on pose les zones ensuite.
		task.defer(buildZones, layout)
	end)
	HealthService.Damaged:Connect(function(model: Model)
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			lastHurt[player] = os.clock()
		end
	end)
	Net.on("RequestRedeploy", function(player: Player)
		local character = player.Character
		if
			player:GetAttribute("Extracted") == true
			and (character == nil or character.Parent == nil)
		then
			player:SetAttribute("Extracted", nil)
			player:LoadCharacter()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
		lastHurt[player] = nil
	end)
end

function ExtractionService.start()
	while true do
		step()
		task.wait(TICK)
	end
end

return ExtractionService
