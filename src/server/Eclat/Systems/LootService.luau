--!strict
-- Butin de l'Éclat (v0.6.0, GDD 02 §4) : inventaire de partie de chaque joueur (le serveur seul
-- le modifie), caisses et coffres posés sur les tuiles, butin des Échoués, sac laissé à la mort.
-- Studio : ServerScriptService > Server > Place > Systems > LootService (place Éclat)
--
-- Sécurité : on fouille par ProximityPrompt (Roblox vérifie la distance côté serveur) ; le
-- contenu est tiré par le serveur à la première fouille ; aucun remote ne permet au client de
-- demander un objet. Les conteneurs sont rangés dans le modèle de leur tuile : ils tombent avec
-- elle quand elle s'effondre (« le sac reste jusqu'à l'effondrement de sa tuile », GDD 02 §4).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))
local RunInventory = require(Shared:WaitForChild("Loot"):WaitForChild("RunInventory"))
local LootTables = require(Shared.Loot:WaitForChild("LootTables"))
local ItemDefs = require(Shared.Loot:WaitForChild("ItemDefs"))

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local HealthService = require(Core.Systems.HealthService)
local PlayerData = require(Core.Systems.PlayerData)
local EclatService = require(script.Parent.EclatService)
local Kit = require(script.Parent.Parent.Lib.Kit)
local Districts = require(game:GetService("ReplicatedStorage").Shared.Eclat.Districts)

type Stack = RunInventory.Stack

-- Emplacements des conteneurs : Shared/Eclat/Districts (repère tourné de chaque quartier).

local LOOK: { [string]: { size: Vector3, color: Color3, hold: number, label: string } } = {
	Caisse = {
		size = Vector3.new(3, 2.4, 2.4),
		color = Color3.fromRGB(140, 100, 60),
		hold = 0.9,
		label = "Caisse",
	},
	Coffre = {
		size = Vector3.new(3.6, 2.6, 2.4),
		color = Color3.fromRGB(90, 60, 40),
		hold = 1.6,
		label = "Coffre",
	},
	Sac = {
		size = Vector3.new(2, 1.6, 2),
		color = Color3.fromRGB(110, 90, 70),
		hold = 1.2,
		label = "Sac",
	},
	Autel = {
		size = Vector3.new(3, 3.2, 3),
		color = Color3.fromRGB(110, 106, 120),
		hold = 2,
		label = "Autel",
	},
	Butin = {
		size = Vector3.new(1.4, 1.1, 1.4),
		color = Color3.fromRGB(120, 110, 150),
		hold = 0.5,
		label = "Butin",
	},
}

local LootService = {}

local inventories: { [Player]: RunInventory.Inventory } = {}
local rng = Random.new()

local function random(): number
	return rng:NextNumber()
end

function LootService.inventory(player: Player): RunInventory.Inventory
	local inv = inventories[player]
	if inv == nil then
		inv = RunInventory.new()
		inventories[player] = inv
	end
	return inv
end

function LootService.push(player: Player)
	Net.fire("InventoryState", player, RunInventory.snapshot(LootService.inventory(player)))
end

-- Vide l'inventaire (extraction, mort) et renvoie son contenu.
function LootService.drain(player: Player): { Stack }
	local items = RunInventory.drain(LootService.inventory(player))
	LootService.push(player)
	return items
end

local function tileModelAt(position: Vector3): Instance
	local folder = workspace:FindFirstChild("Eclat")
	local layout = EclatService.layout()
	if folder and layout then
		local x, z = EclatLayout.tileFromWorld(layout, position.X, position.Z)
		if x and z then
			local model = folder:FindFirstChild(`Tile_{x}_{z}`)
			if model then
				return model
			end
		end
	end
	return folder or workspace
end

local function alive(player: Player): boolean
	local character = player.Character
	return character ~= nil
		and character:GetAttribute("Dead") ~= true
		and character:GetAttribute("Downed") ~= true
end

-- Conteneur : une pièce avec une invite « Fouiller ». `contents` = nil : tiré à la première
-- fouille dans la table `tableName`.
local function container(
	kind: string,
	cframe: CFrame,
	contents: { Stack }?,
	tableName: string?,
	title: string?
)
	local look = LOOK[kind]
	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true
	part.Size = look.size
	part.CFrame = cframe * CFrame.new(0, look.size.Y / 2, 0)
	part.Material = if kind == "Sac" or kind == "Butin"
		then Enum.Material.Fabric
		elseif kind == "Autel" then Enum.Material.Slate
		else Enum.Material.WoodPlanks
	part.Color = look.color
	part:SetAttribute("Loot", kind)
	-- Modèle Blender du kit s'il est importé (v0.5.1) : la pièce devient la zone de fouille.
	local kitName = if kind == "Butin"
		then "Kit_Sac"
		elseif kind == "Autel" then ""
		else `Kit_{kind}`
	local model = Kit.place(kitName, part.CFrame * CFrame.new(0, -look.size.Y / 2, 0), look.size)
	if model then
		part.Transparency = 1
		model.Parent = part
	elseif kind == "Coffre" then
		local trim = Instance.new("Part")
		trim.Anchored = true
		trim.CanCollide = false
		trim.Size = Vector3.new(look.size.X + 0.1, 0.3, look.size.Z + 0.1)
		trim.CFrame = part.CFrame * CFrame.new(0, look.size.Y / 2 - 0.6, 0)
		trim.Material = Enum.Material.Metal
		trim.Color = Color3.fromRGB(190, 150, 70)
		trim.Parent = part
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if kind == "Autel" then "Prendre la relique" else "Fouiller"
	prompt.ObjectText = title or look.label
	prompt.HoldDuration = look.hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	-- Invite posée au-dessus du conteneur : au ras d'une caisse, Roblox ne l'affichait pas
	-- (constaté dans Studio, v0.6.0).
	local anchor = Instance.new("Attachment")
	anchor.Name = "Invite"
	anchor.Position = Vector3.new(0, look.size.Y / 2 + 1.5, 0)
	anchor.Parent = part
	prompt.Parent = anchor
	local stored = contents
	prompt.Triggered:Connect(function(player: Player)
		if not alive(player) then
			return
		end
		if stored == nil then
			stored = LootTables.roll(tableName or "Caisse", random)
		end
		local items = stored :: { Stack }
		local taken = RunInventory.takeFrom(LootService.inventory(player), items)
		if #taken > 0 then
			LootService.push(player)
		end
		Net.fire("LootEvent", player, {
			type = "Taken",
			items = taken,
			full = #items > 0 and #taken == 0,
			empty = #items == 0 and #taken == 0,
		})
		if #items == 0 then
			-- Vidé : la caisse reste (ouverte, plus sombre) ; un sac ou un butin disparaît.
			if kind == "Sac" or kind == "Butin" then
				part:Destroy()
			elseif kind == "Autel" then
				prompt.Enabled = false
				part:SetAttribute("Opened", true)
				local relic = part:FindFirstChild("Relique")
				if relic then
					relic:Destroy()
				end
			else
				prompt.Enabled = false
				part.Color = part.Color:Lerp(Color3.new(0, 0, 0), 0.45)
				part:SetAttribute("Opened", true)
			end
		end
	end)
	part.Parent = tileModelAt(part.Position)
	return part
end

-- Pose un conteneur pour un autre système (autels des reliques, v0.7.0).
function LootService.spawnContainer(
	kind: string,
	cframe: CFrame,
	contents: { Stack },
	title: string?
): BasePart
	return container(kind, cframe, contents, nil, title)
end

local function groundBelow(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, 3, 0)
end

local function placeContainers(layout: EclatLayout.Layout)
	for _, tile in layout.tiles do
		local def = Districts.get(tile.kind)
		if def then
			local frame = EclatService.tileFrame(tile)
			for _, spot in def.loot do
				local cf = frame
					* CFrame.new(spot.x, spot.y, spot.z)
					* CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
				container(spot.table, cf, nil, spot.table)
			end
		end
	end
end

local function onKilled(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		-- Mort : tout ce qui était porté reste dans un sac, là où l'on est tombé.
		local items = LootService.drain(player)
		local profile = PlayerData.get(player)
		if profile then
			profile.stats.deaths += 1
		end
		Net.fire("LootEvent", player, { type = "Lost", items = items })
		if #items > 0 and root.Position.Y > -20 then
			local ground = groundBelow(root.Position, { model })
			container("Sac", CFrame.new(ground), items, nil, `Sac de {player.DisplayName}`)
		end
	elseif model:GetAttribute("EnemyKind") then
		local drops = LootTables.roll("Echoue", random)
		if #drops > 0 and root.Position.Y > -20 then
			local ground = groundBelow(root.Position, { model })
			container("Butin", CFrame.new(ground), drops, nil, "Butin d'Échoué")
		end
	end
end

-- Consommables (v0.6.3) : soin après un temps d'utilisation, annulé si l'on est touché.
local using: { [Player]: number } = {} -- jeton de l'utilisation en cours

local function useConsumable(player: Player, id: unknown)
	if typeof(id) ~= "string" then
		return
	end
	local def = ItemDefs.get(id)
	if def == nil or def.heal == nil or using[player] ~= nil then
		return
	end
	local character = player.Character
	if character == nil or not alive(player) then
		return
	end
	local health = (character:GetAttribute("Health") :: number?) or 0
	local maxHealth = (character:GetAttribute("MaxHealth") :: number?) or 100
	if health >= maxHealth then
		Net.fire("LootEvent", player, { type = "Healed", amount = 0, full = true })
		return
	end
	if RunInventory.count(LootService.inventory(player), id) <= 0 then
		return
	end
	local duration = def.useTime or 0
	local token = os.clock()
	using[player] = token
	character:SetAttribute("UsingItem", id)
	character:SetAttribute("UseEnds", workspace:GetServerTimeNow() + duration)
	local hurt = false
	local conn = HealthService.Damaged:Connect(function(model: Model)
		if model == character then
			hurt = true
		end
	end)
	local start = os.clock()
	while
		os.clock() - start < duration
		and not hurt
		and alive(player)
		and player.Character == character
	do
		task.wait(0.1)
	end
	conn:Disconnect()
	using[player] = nil
	if character.Parent then
		character:SetAttribute("UsingItem", nil)
		character:SetAttribute("UseEnds", nil)
	end
	if hurt or not alive(player) or player.Character ~= character then
		Net.fire("LootEvent", player, { type = "Interrupted", id = id })
		return
	end
	-- L'objet n'est retiré qu'une fois le soin réussi (et s'il est toujours porté).
	if RunInventory.remove(LootService.inventory(player), id, 1) == 1 then
		local healed = HealthService.heal(character, def.heal :: number)
		LootService.push(player)
		Net.fire("LootEvent", player, { type = "Healed", amount = healed })
	end
end

function LootService.init()
	Net.on("UseConsumable", function(player: Player, id: unknown)
		task.spawn(useConsumable, player, id)
	end)
	-- Test dans Studio uniquement : workspace:SetAttribute("QA_GiveItem", "cons.bandage:2")
	-- donne l'objet au premier joueur.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("QA_GiveItem"):Connect(function()
			local value = workspace:GetAttribute("QA_GiveItem")
			local player = Players:GetPlayers()[1]
			if typeof(value) ~= "string" or player == nil then
				return
			end
			local id, qty = string.match(value, "^([%w%._]+):(%d+)")
			if id and qty then
				RunInventory.add(LootService.inventory(player), id, tonumber(qty) :: number)
				LootService.push(player)
			end
			workspace:SetAttribute("QA_GiveItem", nil)
		end)
	end
	EclatService.Built:Connect(function(layout: any)
		-- Nouvelle partie : inventaires vidés (ce qui n'a pas été extrait est perdu).
		for player, inv in inventories do
			RunInventory.drain(inv)
			LootService.push(player)
		end
		placeContainers(layout)
	end)
	HealthService.Killed:Connect(onKilled)
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
		using[player] = nil
	end)
	-- Inventaire envoyé à chaque apparition (le client a eu le temps de se brancher).
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.delay(1, LootService.push, player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return LootService
