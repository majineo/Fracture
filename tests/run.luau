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
}

for _, spec in specs do
	spec(T)
end

if not T.summary() then
	process.exit(1)
end
