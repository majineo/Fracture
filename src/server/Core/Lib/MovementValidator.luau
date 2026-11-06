--!strict
-- Détection des déplacements impossibles (vitesse, téléportation, vol).
-- Studio : ServerScriptService > Server > Lib > MovementValidator
-- Module pur (positions en nombres, horloge fournie) : testé par
-- tests/specs/MovementValidator.spec.luau.
--
-- Le client simule son personnage : un tricheur peut se déplacer trop vite. Le serveur ne
-- peut pas l'empêcher, mais il peut le détecter et le ramener à sa dernière position valide.
--
-- Principe : on garde les positions de la dernière seconde. Si la distance horizontale
-- parcourue (ou la montée) dépasse ce que le jeu permet, le score de suspicion augmente.
-- Une seule mesure anormale ne suffit pas (latence, à-coups du réseau) : il faut
-- `THRESHOLD` anomalies proches pour déclencher un retour en arrière.

export type Config = {
	WINDOW: number, -- secondes de positions conservées
	MAX_SPEED: number, -- vitesse horizontale maximale légitime (studs/s)
	MAX_RISE: number, -- montée maximale légitime dans la fenêtre (studs)
	TOLERANCE: number, -- multiplicateur de marge (ex. 1.25)
	SLACK: number, -- marge fixe en studs
	THRESHOLD: number, -- anomalies avant retour en arrière
	DECAY: number, -- score retiré par mesure normale
}

type Sample = { t: number, x: number, y: number, z: number }

export type State = {
	samples: { Sample },
	score: number,
	lastValid: Sample?,
	graceUntil: number,
	allowUntil: number,
	allowSpeed: number,
	allowRise: number,
}

export type Verdict = "Ok" | "Suspicious" | "Violation"

local MovementValidator = {}

function MovementValidator.new(): State
	return {
		samples = {},
		score = 0,
		lastValid = nil,
		graceUntil = 0,
		allowUntil = 0,
		allowSpeed = 0,
		allowRise = 0,
	}
end

-- Période sans contrôle (apparition, téléportation par le serveur, retour en arrière).
function MovementValidator.grace(state: State, untilTime: number)
	state.graceUntil = math.max(state.graceUntil, untilTime)
	table.clear(state.samples)
	state.score = 0
end

-- Autorise pendant `duration` secondes plus de vitesse / de montée (ex. grappin validé par
-- le serveur). Les autorisations simultanées se cumulent au maximum.
function MovementValidator.allow(
	state: State,
	now: number,
	duration: number,
	speed: number,
	rise: number
)
	if now >= state.allowUntil then
		state.allowSpeed = 0
		state.allowRise = 0
	end
	state.allowUntil = math.max(state.allowUntil, now + duration)
	state.allowSpeed = math.max(state.allowSpeed, speed)
	state.allowRise = math.max(state.allowRise, rise)
end

-- Enregistre une position. Renvoie le verdict et, en cas de violation, la dernière position
-- valide (x, y, z) où ramener le joueur.
function MovementValidator.observe(
	state: State,
	t: number,
	x: number,
	y: number,
	z: number,
	config: Config
): (Verdict, number?, number?, number?)
	local sample: Sample = { t = t, x = x, y = y, z = z }

	if t < state.graceUntil then
		state.lastValid = sample
		return "Ok", nil, nil, nil
	end

	local samples = state.samples
	table.insert(samples, sample)
	while #samples > 1 and t - samples[1].t > config.WINDOW do
		table.remove(samples, 1)
	end

	local oldest = samples[1]
	local elapsed = t - oldest.t
	if elapsed <= 0 then
		if state.lastValid == nil then
			state.lastValid = sample
		end
		return "Ok", nil, nil, nil
	end

	local dx, dz = x - oldest.x, z - oldest.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local minY = oldest.y
	for _, s in samples do
		minY = math.min(minY, s.y)
	end
	local rise = y - minY

	-- La fenêtre contient encore les positions de l'autorisation pendant WINDOW secondes
	-- après sa fin : on prolonge d'autant pour ne pas sanctionner un grappin légitime.
	local boosted = t < state.allowUntil + config.WINDOW
	local speed = if boosted then math.max(config.MAX_SPEED, state.allowSpeed) else config.MAX_SPEED
	local maxRise = if boosted then math.max(config.MAX_RISE, state.allowRise) else config.MAX_RISE
	local allowedDistance = speed * elapsed * config.TOLERANCE + config.SLACK

	if distance <= allowedDistance and rise <= maxRise then
		state.score = math.max(0, state.score - config.DECAY)
		state.lastValid = sample
		return "Ok", nil, nil, nil
	end

	state.score += 1
	if state.score >= config.THRESHOLD then
		state.score = 0
		table.clear(state.samples)
		local back = state.lastValid or oldest
		return "Violation", back.x, back.y, back.z
	end
	return "Suspicious", nil, nil, nil
end

return table.freeze(MovementValidator)
