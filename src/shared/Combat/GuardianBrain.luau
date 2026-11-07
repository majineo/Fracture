--!strict
-- Cerveau du Gardien, le Roi Sans Heure (v0.8.0, GDD 07 §3). Module pur, testé hors Studio :
-- il choisit l'action ; le serveur (GuardianService) l'exécute.
-- Studio : ReplicatedStorage > Shared > Combat > GuardianBrain
--
--   Phase 1 « Le Roi »             (100 % → 60 %) : coups d'épée en arc, charge en ligne droite
--   Phase 2 « La Couronne brisée » (60 % → 25 %)  : + invoque 3 hommes d'armes (une fois),
--                                                    onde de choc temporelle
--   Phase 3 « Le Temps arrêté »    (25 % → 0 %)   : + gèle des zones de l'arène, tout plus rapide
-- Une charge qui ne touche personne laisse le Roi étourdi, couronne exposée (point faible).

export type Command =
	"Idle"
	| "Chase"
	| "BeginSwing"
	| "Swing"
	| "BeginCharge"
	| "Charge"
	| "Summon"
	| "BeginShockwave"
	| "Shockwave"
	| "FreezeZones"
	| "Stunned"
	| "Busy"

export type Input = {
	now: number,
	healthRatio: number, -- santé / santé maximale
	hasTarget: boolean,
	distance: number, -- au joueur ciblé
}

export type Brain = {
	phase: number,
	summoned: boolean,
	busyUntil: number, -- action en cours (préparation, coup, charge)
	pending: Command?, -- action déclenchée à la fin de la préparation
	stunnedUntil: number,
	nextSwing: number,
	nextCharge: number,
	nextShockwave: number,
	nextFreeze: number,
}

local GuardianBrain = {}

GuardianBrain.SWING_RANGE = 13
GuardianBrain.CHARGE_MIN = 18 -- charge seulement si la cible est assez loin
GuardianBrain.CHARGE_MAX = 60
GuardianBrain.SWING_WINDUP = 0.9
GuardianBrain.CHARGE_WINDUP = 1.2
GuardianBrain.CHARGE_TIME = 0.9
GuardianBrain.SHOCK_WINDUP = 1.0
GuardianBrain.STUN_TIME = 2.5
GuardianBrain.SWING_COOLDOWN = 2.2
GuardianBrain.CHARGE_COOLDOWN = 7
GuardianBrain.SHOCK_COOLDOWN = 9
GuardianBrain.FREEZE_COOLDOWN = 8
GuardianBrain.PHASE3_SPEED = 0.7 -- préparations et recharges ×0,7 en phase 3

function GuardianBrain.new(now: number): Brain
	return {
		phase = 1,
		summoned = false,
		busyUntil = now,
		pending = nil,
		stunnedUntil = 0,
		nextSwing = now,
		nextCharge = now + 4,
		nextShockwave = now + 3,
		nextFreeze = now + 2,
	}
end

function GuardianBrain.phaseFor(healthRatio: number): number
	if healthRatio <= 0.25 then
		return 3
	elseif healthRatio <= 0.6 then
		return 2
	end
	return 1
end

local function tempo(brain: Brain): number
	return if brain.phase >= 3 then GuardianBrain.PHASE3_SPEED else 1
end

-- Une charge n'a touché personne : étourdi, couronne exposée.
function GuardianBrain.chargeMissed(brain: Brain, now: number)
	brain.stunnedUntil = now + GuardianBrain.STUN_TIME
	brain.busyUntil = brain.stunnedUntil
end

function GuardianBrain.step(brain: Brain, input: Input): Command
	local now = input.now
	brain.phase = math.max(brain.phase, GuardianBrain.phaseFor(input.healthRatio))
	if now < brain.stunnedUntil then
		return "Stunned"
	end
	-- Fin d'une préparation : l'action part.
	if brain.pending and now >= brain.busyUntil then
		local action = brain.pending :: Command
		brain.pending = nil
		if action == "Charge" then
			brain.busyUntil = now + GuardianBrain.CHARGE_TIME
		end
		return action
	end
	if now < brain.busyUntil then
		return "Busy"
	end
	local t = tempo(brain)
	-- Phase 2 : invocation, une seule fois.
	if brain.phase >= 2 and not brain.summoned then
		brain.summoned = true
		brain.busyUntil = now + 1.5
		return "Summon"
	end
	if not input.hasTarget then
		return "Idle"
	end
	if brain.phase >= 3 and now >= brain.nextFreeze then
		brain.nextFreeze = now + GuardianBrain.FREEZE_COOLDOWN * t
		return "FreezeZones"
	end
	if brain.phase >= 2 and now >= brain.nextShockwave and input.distance <= 22 then
		brain.nextShockwave = now + GuardianBrain.SHOCK_COOLDOWN * t
		brain.pending = "Shockwave"
		brain.busyUntil = now + GuardianBrain.SHOCK_WINDUP * t
		return "BeginShockwave"
	end
	if input.distance <= GuardianBrain.SWING_RANGE then
		if now >= brain.nextSwing then
			brain.nextSwing = now + GuardianBrain.SWING_COOLDOWN * t
			brain.pending = "Swing"
			brain.busyUntil = now + GuardianBrain.SWING_WINDUP * t
			return "BeginSwing"
		end
		return "Idle"
	end
	if
		now >= brain.nextCharge
		and input.distance >= GuardianBrain.CHARGE_MIN
		and input.distance <= GuardianBrain.CHARGE_MAX
	then
		brain.nextCharge = now + GuardianBrain.CHARGE_COOLDOWN * t
		brain.pending = "Charge"
		brain.busyUntil = now + GuardianBrain.CHARGE_WINDUP * t
		return "BeginCharge"
	end
	return "Chase"
end

return GuardianBrain
