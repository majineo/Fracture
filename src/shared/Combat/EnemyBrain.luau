--!strict
-- Cerveau d'un ennemi : décide quoi faire à partir de ce qu'il perçoit. Module pur (temps et
-- perceptions fournis) : testé par tests/specs/EnemyBrain.spec.luau. Le serveur l'appelle
-- quelques fois par seconde puis exécute la commande (déplacement, attaque…).
-- Studio : ReplicatedStorage > Shared > Combat > EnemyBrain
--
-- Commandes renvoyées :
--   "Idle"        rester à son poste            "Return"     rentrer à son poste
--   "Chase"       poursuivre la cible           "Retreat"    reculer (tireurs trop pressés)
--   "Hold"        rester sur place face à la cible
--   "BeginWindup" commencer à préparer un coup  "Windup"     préparation en cours
--   "Strike"      porter le coup (fin de préparation)
--   "BeginAim"    commencer à viser             "Aim"        visée en cours
--   "Fire"        tirer (fin de visée)          "Stunned"    étourdi (coup paré)

export type Perception = {
	now: number,
	hasTarget: boolean,
	distance: number, -- distance à la cible (si hasTarget)
	lineOfSight: boolean,
	homeDistance: number, -- distance à son poste
	stunnedUntil: number,
}

export type Def = {
	behavior: "Melee" | "Ranged",
	attackRange: number,
	leashRange: number,
	keepDistance: number?,
	windup: number,
	cooldown: number,
}

export type Brain = {
	phase: "Free" | "Windup" | "Aim",
	phaseEndsAt: number,
	cooldownUntil: number,
}

local HOME_TOLERANCE = 4

local EnemyBrain = {}

function EnemyBrain.new(): Brain
	return { phase = "Free", phaseEndsAt = 0, cooldownUntil = 0 }
end

function EnemyBrain.step(brain: Brain, p: Perception, def: Def): string
	local now = p.now

	-- Étourdi : tout est interrompu.
	if now < p.stunnedUntil then
		brain.phase = "Free"
		brain.cooldownUntil = math.max(brain.cooldownUntil, p.stunnedUntil)
		return "Stunned"
	end

	-- Préparation d'un coup : rien ne l'interrompt sauf la parade (étourdissement).
	if brain.phase == "Windup" then
		if now >= brain.phaseEndsAt then
			brain.phase = "Free"
			brain.cooldownUntil = now + def.cooldown
			return "Strike"
		end
		return "Windup"
	end

	-- Visée : annulée si la cible disparaît ou se cache.
	if brain.phase == "Aim" then
		if not p.hasTarget or not p.lineOfSight then
			brain.phase = "Free"
			brain.cooldownUntil = now + def.cooldown * 0.5
		elseif now >= brain.phaseEndsAt then
			brain.phase = "Free"
			brain.cooldownUntil = now + def.cooldown
			return "Fire"
		else
			return "Aim"
		end
	end

	-- Pas de cible (ou trop loin) : retour au poste.
	if not p.hasTarget or p.distance > def.leashRange then
		return if p.homeDistance > HOME_TOLERANCE then "Return" else "Idle"
	end

	local ready = now >= brain.cooldownUntil

	if def.behavior == "Melee" then
		if p.distance <= def.attackRange and p.lineOfSight and ready then
			brain.phase = "Windup"
			brain.phaseEndsAt = now + def.windup
			return "BeginWindup"
		end
		if p.distance <= def.attackRange * 0.7 then
			return "Hold" -- déjà au contact, en attendant la fin de la recharge
		end
		return "Chase"
	end

	-- Tireur
	if p.distance < (def.keepDistance or 0) then
		return "Retreat"
	end
	if not p.lineOfSight or p.distance > def.attackRange then
		return "Chase"
	end
	if ready then
		brain.phase = "Aim"
		brain.phaseEndsAt = now + def.windup
		return "BeginAim"
	end
	return "Hold"
end

return table.freeze(EnemyBrain)
