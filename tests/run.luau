--!strict
-- Lance tous les tests unitaires hors Studio :  lune run tests/run
-- Exécuté aussi par la CI GitHub à chaque envoi.

local process = require("@lune/process")
local T = require("./TestKit")

local specs = {
	require("./specs/Guard.spec"),
	require("./specs/RateLimiter.spec"),
	require("./specs/Retry.spec"),
	require("./specs/ProfileSchema.spec"),
	require("./specs/SessionLock.spec"),
	require("./specs/Stamina.spec"),
	require("./specs/MovementValidator.spec"),
	require("./specs/Spring.spec"),
	require("./specs/Combat.spec"),
	require("./specs/Parry.spec"),
	require("./specs/EnemyBrain.spec"),
	require("./specs/Ability.spec"),
	require("./specs/Eclat.spec"),
	require("./specs/Loot.spec"),
	require("./specs/Codex.spec"),
	require("./specs/GuardianBrain.spec"),
	require("./specs/Arsenal.spec"),
	require("./specs/Districts.spec"),
	require("./specs/DecorMotion.spec"),
	require("./specs/CameraMotion.spec"),
}

for _, spec in specs do
	spec(T)
end

if not T.summary() then
	process.exit(1)
end
