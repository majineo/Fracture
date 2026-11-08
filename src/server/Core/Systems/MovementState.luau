--!strict
-- Recopie le mode de déplacement annoncé par chaque client dans l'attribut "MoveMode" de son
-- personnage, pour que tous les clients affichent la bonne animation.
-- Studio : ServerScriptService > Server > Systems > MovementState
--
-- Le mode ne donne presque aucun droit : la vitesse et les positions restent contrôlées par
-- MovementGuard. Exception bornée (v0.4.11) : l'élan et la course sur les murs dépassent la
-- vitesse de sprint ; le serveur les tolère brièvement, au plus une fois par recharge qu'il
-- mesure lui-même (un client qui annonce des élans en boucle est corrigé par la garde).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Movement.MovementConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Net = require(script.Parent.Parent.Lib.Net)
local MovementGuard = require(script.Parent.MovementGuard)

local MODES = table.freeze({
	Normal = true,
	Slide = true,
	Mantle = true,
	Grapple = true,
	Dash = true,
	WallRun = true,
	Roll = true,
	Flip = true,
})

-- Tolérance du serveur pour chaque mouvement rapide : durée, vitesse, montée, recharge.
local ALLOWANCES = table.freeze({
	Dash = {
		seconds = MovementConfig.DASH_TIME + 0.6,
		speed = MovementConfig.DASH_SPEED + 6,
		rise = 6,
		cooldown = MovementConfig.DASH_COOLDOWN * 0.8,
	},
	WallRun = {
		seconds = MovementConfig.WALLRUN_DURATION + 1.2, -- couvre le saut mural qui suit
		speed = MovementConfig.WALLRUN_SPEED + MovementConfig.WALLJUMP_PUSH + 8,
		rise = 22,
		cooldown = MovementConfig.WALLRUN_COOLDOWN * 0.8,
	},
	-- Roulade : vitesse de roulade (ou de réception, bornée à la vitesse de glissade).
	Roll = {
		seconds = MovementConfig.ROLL_TIME + 0.6,
		speed = math.max(MovementConfig.ROLL_SPEED, MovementConfig.SLIDE_SPEED) + 6,
		rise = 4,
		cooldown = MovementConfig.ROLL_COOLDOWN * 0.8,
	},
	-- Salto : second saut (montée supplémentaire ~4 studs) et petite poussée horizontale.
	Flip = {
		seconds = MovementConfig.FLIP_TIME + 1,
		speed = MovementConfig.SPRINT_SPEED + MovementConfig.FLIP_PUSH + 6,
		rise = 24,
		cooldown = 0.6,
	},
})

local MovementState = {}

local lastAllowed: { [Player]: { [string]: number } } = {}

function MovementState.init()
	Net.on("MovementMode", function(player: Player, mode: unknown)
		if not Guard.isKeyOf(mode, MODES) then
			return
		end
		local character = player.Character
		if character == nil then
			return
		end
		local name = mode :: string
		local allowance = (ALLOWANCES :: any)[name]
		if allowance then
			local times = lastAllowed[player]
			if times == nil then
				times = {}
				lastAllowed[player] = times
			end
			local now = os.clock()
			if now - (times[name] or -math.huge) >= allowance.cooldown then
				times[name] = now
				MovementGuard.allow(player, allowance.seconds, allowance.speed, allowance.rise)
			end
		end
		character:SetAttribute("MoveMode", name)
		character:SetAttribute("MoveModeAt", workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAllowed[player] = nil
	end)
end

return MovementState
