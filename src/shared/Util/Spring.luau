--!strict
-- Ressort amorti : fait tendre une valeur vers une cible de façon fluide et naturelle
-- (caméra, poids des animations, vitesse). Module pur : testé par tests/specs/Spring.spec.luau.
-- Studio : ReplicatedStorage > Shared > Util > Spring
--
--   local fov = Spring.new(70, 12)     -- valeur initiale, raideur (plus haut = plus rapide)
--   fov.target = 80
--   Spring.step(fov, dt)               -- à chaque image ; renvoie la nouvelle valeur
--
-- damping = 1 : amortissement critique (aucun dépassement). < 1 : léger rebond.

export type Spring = {
	position: number,
	velocity: number,
	target: number,
	speed: number,
	damping: number,
}

local MAX_SUBSTEP = 1 / 120

local Spring = {}

function Spring.new(initial: number, speed: number, damping: number?): Spring
	return {
		position = initial,
		velocity = 0,
		target = initial,
		speed = speed,
		damping = damping or 1,
	}
end

-- Avance de `dt` secondes (découpé en petits pas pour rester stable même à bas FPS).
function Spring.step(spring: Spring, dt: number): number
	local remaining = math.clamp(dt, 0, 0.25)
	local w = spring.speed
	local z = spring.damping
	while remaining > 0 do
		local h = math.min(remaining, MAX_SUBSTEP)
		local offset = spring.position - spring.target
		local acceleration = -w * w * offset - 2 * z * w * spring.velocity
		spring.velocity += acceleration * h
		spring.position += spring.velocity * h
		remaining -= h
	end
	return spring.position
end

-- Place immédiatement la valeur (sans transition).
function Spring.snap(spring: Spring, value: number)
	spring.position = value
	spring.target = value
	spring.velocity = 0
end

-- Donne une impulsion (ex. secousse à l'atterrissage).
function Spring.impulse(spring: Spring, velocity: number)
	spring.velocity += velocity
end

return table.freeze(Spring)
