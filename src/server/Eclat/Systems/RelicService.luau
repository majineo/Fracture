--!strict
-- Reliques de l'Éclat (v0.7.0, GDD 02 §5 et 04 §2) : autels, et pouvoirs des trois reliques de
-- la vertical slice. « Utiliser ou ramener » : chaque charge utilisée abîme la relique ; intacte
-- (3 charges), elle pourra être stabilisée au Refuge (Codex, v0.7.1).
-- Studio : ServerScriptService > Server > Place > Systems > RelicService (place Éclat)
--
-- Sécurité : le client désigne seulement l'emplacement de la relique (et une direction pour le
-- bond) ; le serveur vérifie la relique, l'état du joueur, la recharge, puis applique l'effet.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))
local ItemDefs = require(Shared:WaitForChild("Loot"):WaitForChild("ItemDefs"))
local RunInventory = require(Shared.Loot:WaitForChild("RunInventory"))
local Codex = require(Shared.Loot:WaitForChild("Codex"))

local Core = script.Parent.Parent.Parent
local Net = require(Core.Lib.Net)
local AbilityService = require(Core.Systems.AbilityService)
local CombatTargets = require(Core.Systems.CombatTargets)
local HealthService = require(Core.Systems.HealthService)
local PlayerData = require(Core.Systems.PlayerData)
local EclatService = require(script.Parent.EclatService)
local LootService = require(script.Parent.LootService)

local COOLDOWN = 1.2
local DASH_DISTANCE = 15
local PHASE_TIME = 0.35
local STASIS_RADIUS = 7
local STASIS_TIME = 2
local SHOCK_RADIUS = 10
local SHOCK_DAMAGE = 15
local SHOCK_STUN = 1.5
local VIOLET = Color3.fromRGB(170, 95, 255)

-- Emplacements possibles d'un autel (repère tourné de la tuile).
local ALTAR_SPOTS: { [string]: Vector3 } = {
	TourGuet = Vector3.new(4, 24, 13), -- au sommet de la tour
	Crypte = Vector3.new(0, 0, 3), -- entre les sarcophages
	CourArmes = Vector3.new(-16, 0, -4),
	Village = Vector3.new(-2, 0, 14),
}

local RelicService = {}

local lastUse: { [Player]: number } = {}

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function placeAltars(layout: EclatLayout.Layout)
	local r = EclatLayout.rng(layout.seed * 17 + 3)
	local candidates = {}
	for _, tile in layout.tiles do
		if ALTAR_SPOTS[tile.kind] and not tile.spawn then
			table.insert(candidates, tile)
		end
	end
	EclatLayout.shuffle(r, candidates)
	local count = math.min(#candidates, EclatLayout.nextInt(r, 1, 3))
	for i = 1, count do
		local tile = candidates[i]
		local relicId = ItemDefs.RELICS[EclatLayout.nextInt(r, 1, #ItemDefs.RELICS)]
		local frame = EclatService.tileFrame(tile) * CFrame.new(ALTAR_SPOTS[tile.kind])
		local def = ItemDefs.get(relicId) :: ItemDefs.ItemDef
		local altar =
			LootService.spawnContainer("Autel", frame, { { id = relicId, qty = 3 } }, def.name)
		-- La relique flotte au-dessus de l'autel, visible de loin.
		local relic = Instance.new("Part")
		relic.Name = "Relique"
		relic.Shape = Enum.PartType.Ball
		relic.Size = Vector3.one * 1.2
		relic.Anchored = true
		relic.CanCollide = false
		relic.CanQuery = false
		relic.Material = Enum.Material.Neon
		relic.Color = VIOLET
		relic.CFrame = altar.CFrame * CFrame.new(0, altar.Size.Y / 2 + 1.6, 0)
		local light = Instance.new("PointLight")
		light.Color = VIOLET
		light.Range = 14
		light.Brightness = 2
		light.Parent = relic
		relic.Parent = altar
	end
end

-- Pas de Faille : bond de 15 studs, intouchable pendant le bond (les tirs le traversent).
local function phaseStep(
	player: Player,
	character: Model,
	root: BasePart,
	direction: unknown
): boolean
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if typeof(direction) == "Vector3" and direction.Magnitude == direction.Magnitude then
		local d = Vector3.new(direction.X, 0, direction.Z)
		if d.Magnitude > 0.1 then
			flat = d
		end
	end
	if flat.Magnitude < 0.1 then
		return false
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local start = root.Position
	local hit = workspace:Raycast(start, flat * DASH_DISTANCE, params)
	local distance = if hit then math.max(0, hit.Distance - 2) else DASH_DISTANCE
	local destination = start + flat * distance
	character:SetAttribute("PhaseUntil", workspace:GetServerTimeNow() + PHASE_TIME)
	AbilityService.teleport(player, root, CFrame.lookAt(destination, destination + flat))
	AbilityService.fx({
		shooter = player,
		kind = "ShadowStep",
		origin = start,
		finish = destination,
	})
	return true
end

-- Stase : bulle qui ralentit tout (tirs compris) devant le joueur.
local function stasis(root: BasePart): boolean
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local center = root.Position + (if flat.Magnitude > 0.1 then flat.Unit else Vector3.zero) * 6
	AbilityService.stasisAt(center, STASIS_RADIUS, STASIS_TIME, 0.25)
	return true
end

-- Onde de choc : repousse et étourdit dans 10 studs, petits dégâts (règles PvP respectées).
local function shockwave(player: Player, character: Model, root: BasePart): boolean
	local origin = root.Position
	for _, target in CombatTargets.all() do
		local model = target.model
		local other = rootOf(model)
		if model ~= character and other and model:GetAttribute("Dead") ~= true then
			local offset = other.Position - origin
			if offset.Magnitude <= SHOCK_RADIUS and HealthService.canDamage(player, model) then
				HealthService.applyDamage(model, SHOCK_DAMAGE, {
					attacker = player,
					weaponId = nil,
					headshot = false,
					origin = origin,
				})
				local push = Vector3.new(offset.X, 0, offset.Z)
				push = (if push.Magnitude > 0.1 then push.Unit else Vector3.new(0, 0, 1)) * 45
				other.AssemblyLinearVelocity = push + Vector3.new(0, 25, 0)
				if target.kind == "Player" then
					AbilityService.slow(model, 0.3, SHOCK_STUN)
				else
					model:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + SHOCK_STUN)
				end
			end
		end
	end
	AbilityService.fx({ shooter = player, kind = "ZenithImpact", origin = origin, finish = origin })
	return true
end

local POWERS: { [string]: (Player, Model, BasePart, unknown) -> boolean } = {
	["relic.pas_de_faille"] = phaseStep,
	["relic.stase"] = function(_, _, root)
		return stasis(root)
	end,
	["relic.onde_de_choc"] = function(player, character, root)
		return shockwave(player, character, root)
	end,
}

local function useRelic(player: Player, index: unknown, direction: unknown)
	if typeof(index) ~= "number" or index ~= index or index < 1 or index > RunInventory.SLOTS then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return
	end
	local character = player.Character
	local root = character and rootOf(character)
	if
		character == nil
		or root == nil
		or character:GetAttribute("Dead") == true
		or character:GetAttribute("Downed") == true
	then
		return
	end
	local inv = LootService.inventory(player)
	local stack = inv.stacks[math.floor(index)]
	local power = stack and POWERS[stack.id]
	if power == nil then
		return
	end
	lastUse[player] = now
	if not power(player, character, root, direction) then
		return
	end
	local id, left = RunInventory.useCharge(inv, math.floor(index))
	LootService.push(player)
	Net.fire("LootEvent", player, { type = "RelicUsed", id = id, left = left })
end

-- Capacités du Codex (v0.7.1) : à chaque apparition, les capacités équipées reçoivent leurs
-- utilisations (attributs « Codex1 », « Codex1Uses »… sur le personnage, lus par l'interface).
local function grantCodex(player: Player, character: Model)
	local data = PlayerData.get(player)
	for slot = 1, Codex.MAX_EQUIPPED do
		local id = data and data.equipped[slot]
		local level = id and data and data.codex[id] or 0
		if id and level > 0 and POWERS[id] then
			character:SetAttribute(`Codex{slot}`, id)
			character:SetAttribute(`Codex{slot}Uses`, Codex.usesFor(level))
		else
			character:SetAttribute(`Codex{slot}`, nil)
			character:SetAttribute(`Codex{slot}Uses`, nil)
		end
	end
end

local function useCodex(player: Player, slot: unknown, direction: unknown)
	if slot ~= 1 and slot ~= 2 then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return
	end
	local character = player.Character
	local root = character and rootOf(character)
	if
		character == nil
		or root == nil
		or character:GetAttribute("Dead") == true
		or character:GetAttribute("Downed") == true
	then
		return
	end
	local id = character:GetAttribute(`Codex{slot}`)
	local uses = character:GetAttribute(`Codex{slot}Uses`)
	local power = typeof(id) == "string" and POWERS[id] or nil
	if power == nil or typeof(uses) ~= "number" or uses <= 0 then
		return
	end
	lastUse[player] = now
	if power(player, character, root, direction) then
		character:SetAttribute(`Codex{slot}Uses`, uses - 1)
	end
end

function RelicService.init()
	Net.on("UseCodex", useCodex)
	-- Test dans Studio uniquement : équipe Stase (niv. 2) et Onde de choc (niv. 1) au premier joueur.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("QA_SeedCodex"):Connect(function()
			local player = Players:GetPlayers()[1]
			local data = player and PlayerData.get(player)
			if workspace:GetAttribute("QA_SeedCodex") ~= true or data == nil then
				return
			end
			data.codex["relic.stase"] = 2
			data.codex["relic.onde_de_choc"] = 1
			data.equipped = { "relic.stase", "relic.onde_de_choc" }
			if player.Character then
				grantCodex(player, player.Character)
			end
			workspace:SetAttribute("QA_SeedCodex", nil)
		end)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Le profil peut arriver un peu après le personnage.
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.5)
			end
			-- Le personnage peut être annoncé avant d'être placé dans le monde (voir HealthService).
			local since = os.clock()
			while
				character.Parent == nil
				and player.Character == character
				and os.clock() - since < 10
			do
				task.wait()
			end
			if character.Parent then
				grantCodex(player, character)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	EclatService.Built:Connect(function(layout: any)
		-- Après les caisses de LootService (même signal) : on attend la fin de la construction.
		task.defer(placeAltars, layout)
	end)
	Net.on("UseRelic", useRelic)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return RelicService
