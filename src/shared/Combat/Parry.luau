--!strict
-- Parade et étourdissement. Module pur (temps fourni) : testé par tests/specs/Parry.spec.luau.
-- Studio : ReplicatedStorage > Shared > Combat > Parry
--
-- Règles (GDD 03-combat §5) :
--   * on lève sa lame : la parade est active pendant `window` secondes, puis temps de recharge ;
--   * un coup de mêlée qui arrive de face pendant la parade est annulé et l'attaquant est
--     étourdi (il ne peut plus frapper pendant STUN_DURATION) ;
--   * les tirs ne se parent pas.

export type State = {
	activeUntil: number,
	cooldownUntil: number,
	stunnedUntil: number,
}

local Parry = {}

Parry.COOLDOWN = 0.75 -- secondes entre deux parades (pas de parade permanente)
Parry.STUN_DURATION = 0.9
Parry.MAX_ANGLE = 75 -- le coup doit venir de face (degrés depuis l'avant)
Parry.NETWORK_TOLERANCE = 0.08 -- marge accordée à la latence côté serveur

function Parry.new(): State
	return { activeUntil = -math.huge, cooldownUntil = -math.huge, stunnedUntil = -math.huge }
end

-- Tente une parade. Renvoie false si en recharge ou étourdi.
function Parry.start(state: State, now: number, window: number): boolean
	if now < state.cooldownUntil or now < state.stunnedUntil then
		return false
	end
	state.activeUntil = now + window
	state.cooldownUntil = now + window + Parry.COOLDOWN
	return true
end

function Parry.isActive(state: State, now: number, tolerance: number?): boolean
	return now <= state.activeUntil + (tolerance or 0)
end

function Parry.stun(state: State, now: number, duration: number?)
	state.stunnedUntil = math.max(state.stunnedUntil, now + (duration or Parry.STUN_DURATION))
	state.activeUntil = -math.huge
end

function Parry.isStunned(state: State, now: number): boolean
	return now < state.stunnedUntil
end

-- Un coup de mêlée est-il paré ? `angle` = angle (degrés) entre l'avant du défenseur et la
-- direction vers l'attaquant.
function Parry.blocks(state: State, now: number, angle: number, tolerance: number?): boolean
	return Parry.isActive(state, now, tolerance) and angle <= Parry.MAX_ANGLE
end

return table.freeze(Parry)
