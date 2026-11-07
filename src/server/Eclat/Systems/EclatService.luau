--!strict
-- L'Éclat (v0.5.0) : génération de la carte à partir d'une graine, horloge de la partie,
-- effondrement des tuiles, mort dans le Vide, puis nouvelle partie.
-- Studio : ServerScriptService > Server > Place > Systems > EclatService (place Éclat)
--
-- Répliqué aux clients (ils recalculent le plan et le calendrier eux-mêmes) :
--   workspace attributs : EclatSeed, EclatStart (heure serveur du début), EclatTimeScale
--   workspace > Eclat > Tile_x_z : attributs Kind, TileX, TileZ, State (Stable/Warning/Collapsed)
--
-- Tests dans Studio : depuis la barre de commande serveur,
--   workspace:SetAttribute("EclatRestart", "<graine>:<échelle de temps>")   ex. "42:0.1"
-- relance une partie (échelle 0,1 = 1 min 36 s au lieu de 16 min). Ignoré hors Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EclatLayout = require(Shared:WaitForChild("Eclat"):WaitForChild("EclatLayout"))
local CollapseSchedule = require(Shared.Eclat:WaitForChild("CollapseSchedule"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal")) :: any

local Core = script.Parent.Parent.Parent
local HealthService = require(Core.Systems.HealthService)
local MovementGuard = require(Core.Systems.MovementGuard)
local EnemyService = require(Core.Systems.EnemyService)
local TileKit = require(script.Parent.Parent.Lib.TileKit)

local VOID_DEPTH = -30 -- en dessous : tombé dans le Vide
local NEXT_MATCH_DELAY = 12
local CRUMBLE_TIME = 4 -- durée de la désagrégation d'une tuile

local EclatService = {}

-- (layout) : une nouvelle carte vient d'être construite.
EclatService.Built = Signal.new()

local folder: Folder
local layout: EclatLayout.Layout? = nil
local schedule: CollapseSchedule.Schedule? = nil
local startTime = 0
local models: { [number]: Model } = {}
local states: { [number]: string } = {}
local squadOf: { [Player]: number } = {}
local nextSquad = 1
local matchId = 0

function EclatService.layout(): EclatLayout.Layout?
	return layout
end

function EclatService.schedule(): CollapseSchedule.Schedule?
	return schedule
end

function EclatService.elapsed(): number
	return workspace:GetServerTimeNow() - startTime
end

-- La tuile (x, z) est-elle encore debout ?
function EclatService.isStanding(x: number, z: number): boolean
	if layout == nil then
		return false
	end
	return states[EclatLayout.index(layout, x, z)] ~= "Collapsed"
end

-- Repère tourné d'une tuile (pour poser des choses dans son intérieur).
function EclatService.tileFrame(tile: EclatLayout.Tile): CFrame
	local current = layout :: EclatLayout.Layout
	local cx, cz = EclatLayout.tileCenter(current, tile.x, tile.z)
	return CFrame.new(cx, 0, cz) * CFrame.Angles(0, tile.rotation * math.pi / 2, 0)
end

-- Désagrégation : les pièces se détachent du centre vers les bords et tombent dans le Vide.
local function crumble(model: Model)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local pivot = model:GetPivot().Position
	local origin = pivot + Vector3.new((math.random() - 0.5) * 40, 0, (math.random() - 0.5) * 40)
	table.sort(parts, function(a, b)
		return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
	end)
	local maxDistance = 1
	for _, part in parts do
		maxDistance = math.max(maxDistance, (part.Position - origin).Magnitude)
	end
	for _, part in parts do
		local delay = (part.Position - origin).Magnitude / maxDistance * CRUMBLE_TIME
			+ math.random() * 0.3
		task.delay(delay, function()
			if part.Parent == nil then
				return
			end
			part.Anchored = false
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
			local mass = part.AssemblyMass
			part:ApplyImpulse(Vector3.new(
				(math.random() - 0.5) * 8,
				math.random() * 5 - 1, -- léger soulèvement : la chute se voit mieux
				(math.random() - 0.5) * 8
			) * mass)
			part:ApplyAngularImpulse(
				Vector3.new(
					(math.random() - 0.5) * 4,
					(math.random() - 0.5) * 4,
					(math.random() - 0.5) * 4
				) * mass
			)
		end)
	end
	task.delay(CRUMBLE_TIME + 8, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function spawnFrame(player: Player): CFrame?
	local current = layout
	if current == nil then
		return nil
	end
	local spawns = EclatLayout.spawnTiles(current)
	local squad = squadOf[player]
	if squad == nil then
		squad = nextSquad
		squadOf[player] = squad
		nextSquad = nextSquad % #spawns + 1
	end
	-- Tuile d'apparition de l'escouade, ou la tuile debout la plus proche si elle est tombée.
	local wanted = spawns[squad]
	local best: EclatLayout.Tile? = nil
	local bestDistance = math.huge
	for _, tile in current.tiles do
		if EclatService.isStanding(tile.x, tile.z) then
			local d = math.abs(tile.x - wanted.x) + math.abs(tile.z - wanted.z)
			if d < bestDistance then
				best, bestDistance = tile, d
			end
		end
	end
	if best == nil then
		return nil
	end
	local cx, cz = EclatLayout.tileCenter(current, best.x, best.z)
	-- Face au centre de l'Éclat.
	local position = Vector3.new(cx, 4, cz)
	local look = Vector3.new(-cx, 4, -cz)
	if (look - position).Magnitude < 1 then
		look = position + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, look)
end

local function placeCharacter(player: Player, character: Model)
	task.spawn(function()
		-- Le personnage peut être annoncé avant d'être placé dans le monde : on l'attend.
		local root = character:WaitForChild("HumanoidRootPart", 5)
		local since = os.clock()
		while
			character.Parent == nil
			and player.Character == character
			and os.clock() - since < 10
		do
			task.wait()
		end
		local frame = spawnFrame(player)
		if root == nil or frame == nil or not root:IsA("BasePart") then
			return
		end
		-- Roblox peut reposer le personnage sur le point d'apparition juste après : on vérifie
		-- pendant une seconde et on le replace s'il n'est plus sur sa tuile.
		for _ = 1, 6 do
			if character.Parent == nil or player.Character ~= character then
				return
			end
			if (root.Position - frame.Position).Magnitude > 40 then
				MovementGuard.grace(player, 1.5) -- téléportation voulue, pas une triche
				character:PivotTo(frame)
			end
			task.wait(0.2)
		end
	end)
end

local function build(seed: number, timeScale: number)
	matchId += 1
	EnemyService.clear()
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Eclat"
	folder.Parent = workspace
	local current = EclatLayout.generate(seed)
	layout = current
	schedule = CollapseSchedule.build(current, CollapseSchedule.scaled(timeScale))
	models = {}
	states = {}
	for i, tile in current.tiles do
		local model = TileKit.build(current, tile)
		model:SetAttribute("State", "Stable")
		model.Parent = folder
		models[i] = model
		states[i] = "Stable"
	end
	startTime = workspace:GetServerTimeNow()
	workspace:SetAttribute("EclatSeed", seed)
	workspace:SetAttribute("EclatTimeScale", timeScale)
	workspace:SetAttribute("EclatStart", startTime)
	EclatService.Built:Fire(current)
	-- Tout le monde repart de sa tuile d'apparition.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local extracted = player:GetAttribute("Extracted") == true
		player:SetAttribute("Extracted", nil)
		if character == nil or character.Parent == nil then
			if extracted then
				-- Extrait lors de la partie précédente : il repart.
				player:LoadCharacter()
			end
		else
			if character:GetAttribute("Dead") == true then
				player:LoadCharacter()
			else
				HealthService.restore(character)
				placeCharacter(player, character)
			end
		end
	end
	print(`[Éclat] partie {matchId} : graine {seed}, échelle de temps {timeScale}`)
end

local function voidCheck(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and root.Position.Y < VOID_DEPTH then
		HealthService.killNow(model, { attacker = nil, headshot = false })
	end
end

local function step()
	local current, plan = layout, schedule
	if current == nil or plan == nil then
		return
	end
	local elapsed = EclatService.elapsed()
	for i, tile in current.tiles do
		local state = CollapseSchedule.tileState(plan, tile.x, tile.z, elapsed)
		if state ~= states[i] and states[i] ~= "Collapsed" then
			states[i] = state
			local model = models[i]
			if model and model.Parent then
				model:SetAttribute("State", state)
				if state == "Collapsed" then
					crumble(model)
				end
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			voidCheck(player.Character)
		end
	end
	for _, enemy in EnemyService.models() do
		voidCheck(enemy)
	end
end

local function newSeed(): number
	return Random.new():NextInteger(1, 2 ^ 30)
end

function EclatService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			placeCharacter(player, character)
		end)
	end
	-- Dans Studio, le joueur peut être entré avant le démarrage des scripts.
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		squadOf[player] = nil
	end)
end

function EclatService.start()
	-- La carte de test de la v0.4 est remplacée par l'Éclat.
	local greybox = workspace:FindFirstChild("Greybox")
	local floor = greybox and greybox:FindFirstChild("Sol")
	if floor then
		floor:Destroy()
	end
	build(newSeed(), 1)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("EclatRestart"):Connect(function()
			local value = workspace:GetAttribute("EclatRestart")
			if typeof(value) ~= "string" then
				return
			end
			local seedText, scaleText = string.match(value, "^(%d*):?([%d%.]*)$")
			local seed = tonumber(seedText) or newSeed()
			local scale = math.clamp(tonumber(scaleText) or 1, 0.02, 1)
			build(seed, scale)
		end)
	end
	local endedFor = 0
	while true do
		step()
		local plan = schedule
		if plan and CollapseSchedule.phase(plan, EclatService.elapsed()) == "Ended" then
			-- Tout est tombé : ceux qui restent meurent, puis une nouvelle partie commence.
			if endedFor ~= matchId then
				endedFor = matchId
				local ending = matchId
				for _, player in Players:GetPlayers() do
					if player.Character then
						HealthService.killNow(
							player.Character,
							{ attacker = nil, headshot = false }
						)
					end
				end
				task.delay(NEXT_MATCH_DELAY, function()
					if matchId == ending then
						build(newSeed(), (workspace:GetAttribute("EclatTimeScale") :: number?) or 1)
					end
				end)
			end
		end
		task.wait(0.25)
	end
end

return EclatService
