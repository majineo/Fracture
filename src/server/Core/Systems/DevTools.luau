--!strict
-- Outils de test réservés à Roblox Studio (jamais actifs dans le jeu publié).
-- Studio : ServerScriptService > Server > Systems > DevTools
--
-- Utilisation depuis la barre de commande côté client pendant un test :
--   game.ReplicatedStorage.Remotes.DevCommand:FireServer("teleport", Vector3.new(0, 5, 0))
--
-- Commandes :
--   "teleport", position : téléporte le personnage en prévenant la garde de mouvement.
--
-- Sécurité : le gestionnaire n'est branché que si RunService:IsStudio() est vrai, et le
-- vérifie encore à chaque appel. Aucune commande ne touche aux données joueur.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local MovementGuard = require(script.Parent.MovementGuard)

local TELEPORT_GRACE = 1
local MAX_COORDINATE = 10000

local DevTools = {}

local function teleport(player: Player, position: unknown)
	if not Guard.isFiniteVector3(position) then
		return
	end
	local target = position :: Vector3
	if target.Magnitude > MAX_COORDINATE then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	MovementGuard.grace(player, TELEPORT_GRACE)
	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

-- Le mannequin le plus proche frappe le joueur à la lame (pour tester la parade).
local function dummyAttack(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local best: Model? = nil
	local bestDistance = 12
	for _, model in workspace:GetChildren() do
		local dummyRoot = model:IsA("Model")
			and model:GetAttribute("CombatDummy")
			and model:FindFirstChild("HumanoidRootPart")
		if dummyRoot and dummyRoot:IsA("BasePart") then
			local distance = (dummyRoot.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	if best == nil then
		return
	end
	local dummyRoot = best:FindFirstChild("HumanoidRootPart") :: BasePart
	local WeaponService = require(script.Parent.WeaponService) :: any
	local WeaponDefs = require(ReplicatedStorage.Shared.Combat.WeaponDefs)
	local result = WeaponService.meleeStrike(
		best,
		nil,
		WeaponDefs["weapon.short_blade"],
		root.Position - dummyRoot.Position,
		workspace:GetServerTimeNow()
	)
	player:SetAttribute("QA_LastDummyAttack", result or "Miss")
end

-- Place une arme dans un emplacement (comme l'armurerie) : ("setWeapon", emplacement, id).
local function setWeapon(player: Player, slot: unknown, id: unknown)
	if not Guard.isIntegerInRange(slot, 1, 2) or typeof(id) ~= "string" then
		return
	end
	local WeaponService = require(script.Parent.WeaponService) :: any
	WeaponService.setWeapon(player, slot, id)
end

-- Fait apparaître un ennemi devant le joueur : ("spawnEnemy", id, distance?).
local function spawnEnemy(player: Player, id: unknown, distance: unknown)
	local EnemyDefs = require(ReplicatedStorage.Shared.Combat.EnemyDefs)
	if not Guard.isKeyOf(id, EnemyDefs) then
		return
	end
	local d = if Guard.isFiniteNumber(distance) then math.clamp(distance :: number, 3, 120) else 20
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local position = root.Position + root.CFrame.LookVector * d
	local EnemyService = require(script.Parent.EnemyService) :: any
	local facing = Vector3.new(root.Position.X, position.Y, root.Position.Z)
	EnemyService.spawn(id, CFrame.lookAt(position, facing))
end

-- Retire tous les ennemis : ("clearEnemies").
local function clearEnemies(_player: Player)
	local EnemyService = require(script.Parent.EnemyService) :: any
	EnemyService.clear()
end

local COMMANDS: { [string]: (Player, ...unknown) -> () } = {
	teleport = teleport,
	dummyAttack = dummyAttack,
	setWeapon = setWeapon,
	spawnEnemy = spawnEnemy,
	clearEnemies = clearEnemies,
}

function DevTools.init()
	if not RunService:IsStudio() then
		return
	end
	Net.on("DevCommand", function(player: Player, command: unknown, ...: unknown)
		if not RunService:IsStudio() then
			return
		end
		if not Guard.isKeyOf(command, COMMANDS) then
			return
		end
		COMMANDS[command :: string](player, ...)
	end)
	print("[DevTools] commandes de test actives (Studio uniquement)")
end

return DevTools
