--!strict
-- Validateurs d'arguments pour les remotes. Tout argument venant d'un client est hostile
-- tant qu'il n'est pas validé : NaN, infini, mauvais type, chaînes géantes, etc.
-- Studio : ReplicatedStorage > Shared > Util > Guard
-- Module pur (aucune dépendance Roblox) : testé hors Studio par tests/specs/Guard.spec.luau.

local Guard = {}

local HUGE = math.huge

-- Nombre réel fini (rejette NaN, +inf, -inf et tout ce qui n'est pas un nombre).
function Guard.isFiniteNumber(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= HUGE and n ~= -HUGE
end

-- Entier fini compris entre min et max (inclus).
function Guard.isIntegerInRange(value: unknown, min: number, max: number): boolean
	if not Guard.isFiniteNumber(value) then
		return false
	end
	local n = value :: number
	return n == math.floor(n) and n >= min and n <= max
end

-- Nombre fini compris entre min et max (inclus).
function Guard.isNumberInRange(value: unknown, min: number, max: number): boolean
	if not Guard.isFiniteNumber(value) then
		return false
	end
	local n = value :: number
	return n >= min and n <= max
end

-- Chaîne dont la longueur (en octets) est comprise entre minLen et maxLen.
function Guard.isStringOfLength(value: unknown, minLen: number, maxLen: number): boolean
	if typeof(value) ~= "string" then
		return false
	end
	local len = #(value :: string)
	return len >= minLen and len <= maxLen
end

-- Chaîne qui est une clé du tableau `allowed` (ex. identifiant d'objet du catalogue serveur).
function Guard.isKeyOf(value: unknown, allowed: { [string]: any }): boolean
	if typeof(value) ~= "string" then
		return false
	end
	return allowed[value :: string] ~= nil
end

-- Vector3 dont toutes les composantes sont finies.
function Guard.isFiniteVector3(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local v = value :: Vector3
	return Guard.isFiniteNumber(v.X) and Guard.isFiniteNumber(v.Y) and Guard.isFiniteNumber(v.Z)
end

return table.freeze(Guard)
