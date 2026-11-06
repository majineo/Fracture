--!strict
-- Garde de mouvement : détecte les déplacements impossibles et ramène le joueur en arrière.
-- Studio : ServerScriptService > Server > Systems > MovementGuard
--
-- Toutes les 0,2 s, la position de chaque personnage est passée au MovementValidator.
-- En cas de violation confirmée, le personnage est replacé à sa dernière position valide.
-- Aucun bannissement automatique : on journalise, on corrige, on n'accuse pas
-- (la latence mobile provoque parfois de fausses alertes isolées).
--
-- Les systèmes qui déplacent légitimement un joueur DOIVENT prévenir la garde :
--   MovementGuard.grace(player, secondes)               -- téléportation par le serveur
--   MovementGuard.allow(player, secondes, vitesse, montée) -- grappin, explosion, etc.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local MovementValidator = require(script.Parent.Parent.Lib.MovementValidator)

local SAMPLE_INTERVAL = 0.2
local SPAWN_GRACE = 2
local CORRECTION_GRACE = 0.5

local CONFIG: MovementValidator.Config = table.freeze({
	WINDOW = 1,
	-- Le mouvement normal le plus rapide est le départ de glissade.
	MAX_SPEED = math.max(MovementConfig.SPRINT_SPEED, MovementConfig.SLIDE_SPEED),
	-- Saut (~7,2) + escalade (7) + marge.
	MAX_RISE = 16,
	TOLERANCE = 1.25,
	SLACK = 4,
	THRESHOLD = 3,
	DECAY = 0.5,
})

local MovementGuard = {}

local states: { [Player]: MovementValidator.State } = {}
local corrections: { [Player]: number } = {}

local function stateFor(player: Player): MovementValidator.State
	local state = states[player]
	if state == nil then
		state = MovementValidator.new()
		states[player] = state
	end
	return state
end

-- Désactive le contrôle pendant `seconds` (ex. après une téléportation par le serveur).
function MovementGuard.grace(player: Player, seconds: number)
	MovementValidator.grace(stateFor(player), os.clock() + seconds)
end

-- Autorise pendant `seconds` une vitesse horizontale et une montée supérieures.
function MovementGuard.allow(player: Player, seconds: number, speed: number, rise: number)
	MovementValidator.allow(stateFor(player), os.clock(), seconds, speed, rise)
end

-- Nombre de corrections appliquées à ce joueur depuis sa connexion (diagnostic).
function MovementGuard.corrections(player: Player): number
	return corrections[player] or 0
end

local function correct(player: Player, root: BasePart, x: number, y: number, z: number)
	root.CFrame = CFrame.new(x, y, z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	MovementGuard.grace(player, CORRECTION_GRACE)
	local count = (corrections[player] or 0) + 1
	corrections[player] = count
	warn(
		`[MovementGuard] {player.Name} ({player.UserId}) ramené en arrière (correction n°{count})`
	)
end

local function sampleAll()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
			continue
		end
		if humanoid.SeatPart ~= nil then
			-- Véhicule ou siège : contrôle désactivé pour l'instant.
			MovementGuard.grace(player, SAMPLE_INTERVAL * 2)
			continue
		end
		local p = root.Position
		local verdict, x, y, z =
			MovementValidator.observe(stateFor(player), now, p.X, p.Y, p.Z, CONFIG)
		if verdict == "Violation" and x and y and z then
			correct(player, root, x, y, z)
		end
	end
end

function MovementGuard.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			MovementGuard.grace(player, SPAWN_GRACE)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		corrections[player] = nil
	end)
end

function MovementGuard.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= SAMPLE_INTERVAL then
			accumulator = 0
			sampleAll()
		end
	end)
end

return MovementGuard
