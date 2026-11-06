--!strict
-- Santé, armure, mise à terre et mort de toutes les cibles de combat. SEUL module qui modifie
-- la santé. Les valeurs sont publiées en attributs sur le modèle (lecture seule pour les
-- clients) : Health, MaxHealth, Armor, MaxArmor, Downed, DownedHealth, Dead.
-- Studio : ServerScriptService > Server > Systems > HealthService
--
-- Règles (GDD 02 §6, 03 §3) :
--   * l'armure absorbe les dégâts en premier ;
--   * un JOUEUR à 0 santé tombe « à terre » : il rampe, ne peut plus combattre, et meurt au
--     bout de DOWNED_DURATION secondes ou s'il reçoit encore DOWNED_HEALTH de dégâts ;
--   * un MANNEQUIN à 0 se brise puis se répare au bout de DUMMY_RESET_DELAY secondes ;
--   * PvP uniquement dans les Éclats (jamais au Refuge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Combat.CombatConfig)
local Damage = require(Shared.Combat.Damage)
local Signal = require(Shared.Util.Signal)
local PlaceKind = require(Shared.PlaceKind) :: any
local CombatTargets = require(script.Parent.CombatTargets)

export type DamageInfo = {
	attacker: Player?,
	weaponId: string?,
	headshot: boolean,
	origin: Vector3?, -- d'où vient le coup (pour l'indicateur de direction)
}

export type DamageResult = {
	applied: number, -- dégâts réellement infligés (armure + santé)
	armor: number,
	health: number,
	downed: boolean, -- la cible vient de tomber à terre
	killed: boolean, -- la cible vient de mourir / se briser
}

local PVP_ENABLED = PlaceKind == "Eclat"

local HealthService = {}

-- (model, result, info)
HealthService.Damaged = Signal.new()
-- (model, info)
HealthService.Killed = Signal.new()

local downedTokens: { [Model]: number } = {}

local function setup(model: Model, maxHealth: number, armor: number)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxArmor", armor)
	model:SetAttribute("Armor", armor)
	model:SetAttribute("Downed", false)
	model:SetAttribute("DownedHealth", 0)
	model:SetAttribute("Dead", false)
end

local function isAlive(model: Model): boolean
	return model:GetAttribute("Dead") ~= true
end

-- La cible peut-elle être blessée par cet attaquant ?
function HealthService.canDamage(attacker: Player?, model: Model): boolean
	local target = CombatTargets.get(model)
	if target == nil or not isAlive(model) then
		return false
	end
	if target.kind == "Player" then
		if not PVP_ENABLED then
			return false
		end
		if attacker ~= nil and target.player == attacker then
			return false
		end
	end
	return true
end

local function kill(model: Model, info: DamageInfo)
	model:SetAttribute("Dead", true)
	model:SetAttribute("Downed", false)
	downedTokens[model] = nil
	local target = CombatTargets.get(model)
	if target and target.kind == "Player" then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
	HealthService.Killed:Fire(model, info)
end

local function goDown(model: Model, info: DamageInfo)
	model:SetAttribute("Downed", true)
	model:SetAttribute("DownedHealth", CombatConfig.DOWNED_HEALTH)
	local token = (downedTokens[model] or 0) + 1
	downedTokens[model] = token
	task.delay(CombatConfig.DOWNED_DURATION, function()
		if downedTokens[model] == token and model.Parent and model:GetAttribute("Downed") then
			kill(model, info)
		end
	end)
end

-- Inflige des dégâts. Ne fait rien si canDamage refuse. Renvoie le détail de ce qui a été fait.
function HealthService.applyDamage(model: Model, amount: number, info: DamageInfo): DamageResult?
	if amount <= 0 or not HealthService.canDamage(info.attacker, model) then
		return nil
	end
	local target = CombatTargets.get(model)
	if target == nil then
		return nil
	end

	local result: DamageResult =
		{ applied = 0, armor = 0, health = 0, downed = false, killed = false }

	if model:GetAttribute("Downed") then
		-- À terre : les dégâts consomment la « santé à terre ».
		local remaining = (model:GetAttribute("DownedHealth") :: number?) or 0
		local applied = math.min(remaining, amount)
		model:SetAttribute("DownedHealth", remaining - applied)
		result.applied = applied
		result.health = applied
		if remaining - applied <= 0 then
			result.killed = true
			kill(model, info)
		end
		HealthService.Damaged:Fire(model, result, info)
		return result
	end

	local armor = (model:GetAttribute("Armor") :: number?) or 0
	local health = (model:GetAttribute("Health") :: number?) or 0
	local split = Damage.split(amount, armor)
	local healthLoss = math.min(health, split.health)
	model:SetAttribute("Armor", armor - split.armor)
	model:SetAttribute("Health", health - healthLoss)
	result.armor = split.armor
	result.health = healthLoss
	result.applied = split.armor + healthLoss

	if health - healthLoss <= 0 then
		if target.kind == "Player" then
			result.downed = true
			goDown(model, info)
		else
			result.killed = true
			kill(model, info)
		end
	end
	HealthService.Damaged:Fire(model, result, info)
	return result
end

-- Remet une cible en pleine forme (mannequins, réanimation plus tard).
function HealthService.restore(model: Model)
	local maxHealth = (model:GetAttribute("MaxHealth") :: number?) or CombatConfig.MAX_HEALTH
	local maxArmor = (model:GetAttribute("MaxArmor") :: number?) or 0
	downedTokens[model] = nil
	setup(model, maxHealth, maxArmor)
end

-- Inscrit une cible de combat (mannequin, ennemi).
function HealthService.registerTarget(
	model: Model,
	kind: "Dummy" | "Enemy",
	maxHealth: number,
	armor: number
)
	if CombatTargets.register(model, kind, nil) then
		setup(model, maxHealth, armor)
	end
end

function HealthService.init()
	local function onCharacter(player: Player, character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		if character.Parent == nil then
			return
		end
		CombatTargets.register(character, "Player", player)
		setup(character, CombatConfig.MAX_HEALTH, CombatConfig.BASE_ARMOR)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- La santé Roblox n'est utilisée que pour la mort finale.
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function(character)
			CombatTargets.unregister(character)
			downedTokens[character] = nil
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return HealthService
