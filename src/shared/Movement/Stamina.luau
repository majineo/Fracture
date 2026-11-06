--!strict
-- Modèle d'endurance (jauge de sprint). Module pur : testé par tests/specs/Stamina.spec.luau.
-- Studio : ReplicatedStorage > Shared > Movement > Stamina
--
-- La jauge va de 0 à 1. Le sprint la vide en SPRINT_DURATION secondes ; après une pause de
-- REGEN_DELAY, elle se remplit en REGEN_DURATION secondes. Une jauge vidée à 0 met le joueur
-- « à bout de souffle » : il ne peut resprinter qu'une fois remonté à SPRINT_RESTART_MIN.

export type Config = {
	SPRINT_DURATION: number,
	REGEN_DURATION: number,
	REGEN_DELAY: number,
	SPRINT_RESTART_MIN: number,
}

export type State = {
	value: number,
	regenDelay: number,
	exhausted: boolean,
}

local EPSILON = 1e-6

local Stamina = {}

function Stamina.new(): State
	return { value = 1, regenDelay = 0, exhausted = false }
end

-- Fait avancer la jauge de `dt` secondes. `draining` = le joueur sprinte en ce moment.
function Stamina.step(state: State, dt: number, draining: boolean, config: Config)
	if draining and not state.exhausted then
		state.value = state.value - dt / config.SPRINT_DURATION
		state.regenDelay = config.REGEN_DELAY
		-- Marge pour les erreurs d'arrondi (sinon la jauge peut rester à 1e-15 sans jamais
		-- atteindre 0).
		if state.value <= EPSILON then
			state.value = 0
			state.exhausted = true
		end
		return
	end
	if state.regenDelay > 0 then
		state.regenDelay = math.max(0, state.regenDelay - dt)
		return
	end
	state.value = math.min(1, state.value + dt / config.REGEN_DURATION)
	if state.exhausted and state.value >= config.SPRINT_RESTART_MIN then
		state.exhausted = false
	end
end

function Stamina.canSprint(state: State): boolean
	return not state.exhausted and state.value > 0
end

-- Dépense une quantité fixe (ex. glissade). Renvoie false si la jauge est insuffisante.
function Stamina.spend(state: State, amount: number, config: Config): boolean
	if state.exhausted or state.value < amount then
		return false
	end
	state.value -= amount
	state.regenDelay = config.REGEN_DELAY
	return true
end

return table.freeze(Stamina)
