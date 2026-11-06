--!strict
-- Réessai avec attente exponentielle pour les appels qui peuvent échouer (DataStore, etc.).
-- Studio : ServerScriptService > Server > Lib > Retry
-- Module pur (fonction d'attente injectable) : testé par tests/specs/Retry.spec.luau.

local Retry = {}

-- Exécute `fn` jusqu'à `attempts` fois. Attend `baseDelay`, puis le double à chaque échec
-- (plafonné à `maxDelay`). Renvoie (true, résultat) au premier succès, sinon
-- (false, nil, dernier message d'erreur).
function Retry.run<T>(
	attempts: number,
	baseDelay: number,
	maxDelay: number,
	sleep: (number) -> any,
	fn: () -> T,
	onFailure: ((attempt: number, err: string) -> ())?
): (boolean, T?, string?)
	local delaySeconds = baseDelay
	local lastError = "aucune tentative"
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result, nil
		end
		lastError = tostring(result)
		if onFailure then
			onFailure(attempt, lastError)
		end
		if attempt < attempts then
			sleep(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, maxDelay)
		end
	end
	return false, nil, lastError
end

return table.freeze(Retry)
