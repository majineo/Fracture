local MovementValidator = require("../../src/server/Core/Lib/MovementValidator")

local CONFIG = {
	WINDOW = 1,
	MAX_SPEED = 30,
	MAX_RISE = 16,
	TOLERANCE = 1.25,
	SLACK = 4,
	THRESHOLD = 3,
	DECAY = 0.5,
}

local DT = 0.2

-- Simule un joueur qui avance à `speed` studs/s pendant `seconds` à partir de (x, y, z).
local function run(state, t0: number, x: number, y: number, speed: number, seconds: number)
	local verdicts = {}
	local t = t0
	for _ = 1, math.floor(seconds / DT + 0.5) do
		t += DT
		x += speed * DT
		local verdict = MovementValidator.observe(state, t, x, y, 0, CONFIG)
		table.insert(verdicts, verdict)
	end
	return verdicts, t, x
end

local function count(list, value)
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

return function(T)
	T.suite("MovementValidator")

	T.test("un sprint ou une glissade normale ne déclenche rien", function()
		local state = MovementValidator.new()
		local verdicts = run(state, 0, 0, 0, 22, 5)
		T.equal(count(verdicts, "Ok"), #verdicts, "sprint")
		verdicts = run(state, 5, 110, 0, 30, 0.8)
		T.equal(count(verdicts, "Violation"), 0, "glissade")
	end)

	T.test("un à-coup réseau isolé n'est pas sanctionné", function()
		local state = MovementValidator.new()
		local _, t, x = run(state, 0, 0, 0, 14, 2)
		-- Une mesure saute de 20 studs (paquets regroupés), puis tout redevient normal.
		MovementValidator.observe(state, t + DT, x + 20, 0, 0, CONFIG)
		local verdicts = run(state, t + DT, x + 20, 0, 14, 2)
		T.equal(count(verdicts, "Violation"), 0)
	end)

	T.test("un speedhack est ramené à la dernière position valide", function()
		local state = MovementValidator.new()
		local _, t, x = run(state, 0, 0, 0, 14, 2)
		local lastLegit = x
		local verdict, bx
		for _ = 1, 10 do
			t += DT
			x += 100 * DT -- 100 studs/s
			local v, rx = MovementValidator.observe(state, t, x, 0, 0, CONFIG)
			if v == "Violation" then
				verdict, bx = v, rx
				break
			end
		end
		T.equal(verdict, "Violation")
		T.truthy(bx ~= nil and bx <= lastLegit + 30 * 1.25 + 4, `ramené à x = {bx}`)
	end)

	T.test("une téléportation est détectée", function()
		local state = MovementValidator.new()
		local _, t = run(state, 0, 0, 0, 14, 1)
		local violation = false
		for i = 1, 5 do
			local v = MovementValidator.observe(state, t + i * DT, 500 + i, 0, 0, CONFIG)
			if v == "Violation" then
				violation = true
			end
		end
		T.truthy(violation)
	end)

	T.test("monter trop haut (vol) est détecté, chuter ne l'est pas", function()
		local state = MovementValidator.new()
		local t = 0
		local violation = false
		for i = 1, 15 do
			t += DT
			local v = MovementValidator.observe(state, t, 0, i * 10, 0, CONFIG) -- 50 studs/s vers le haut
			if v == "Violation" then
				violation = true
			end
		end
		T.truthy(violation, "vol")

		local falling = MovementValidator.new()
		local fallViolation = false
		for i = 1, 15 do
			local v = MovementValidator.observe(falling, i * DT, 0, 500 - i * 40, 0, CONFIG)
			if v ~= "Ok" then
				fallViolation = true
			end
		end
		T.falsy(fallViolation, "chute")
	end)

	T.test("le grappin autorisé par le serveur n'est pas sanctionné", function()
		local state = MovementValidator.new()
		local _, t, x = run(state, 0, 0, 0, 14, 1)
		MovementValidator.allow(state, t, 1.6, 75, 60)
		local verdicts, t2, x2 = run(state, t, x, 0, 70, 1.6)
		T.equal(count(verdicts, "Violation"), 0, "pendant")
		verdicts = run(state, t2, x2, 0, 14, 1.5)
		T.equal(count(verdicts, "Violation"), 0, "juste après")
	end)

	T.test("la période de grâce ignore les déplacements (apparition)", function()
		local state = MovementValidator.new()
		MovementValidator.grace(state, 1)
		T.equal(MovementValidator.observe(state, 0.5, 9999, 0, 0, CONFIG), "Ok")
		local verdicts = run(state, 1, 9999, 0, 14, 2)
		T.equal(count(verdicts, "Violation"), 0)
	end)
end
