--!strict
-- Limiteur de fréquence par « seau à jetons ».
-- Studio : ServerScriptService > Server > Lib > RateLimiter
-- Module pur (horloge injectable) : testé par tests/specs/RateLimiter.spec.luau.
--
-- Chaque clé (ex. un Player) possède un seau par nom (ex. un remote). Le seau contient au
-- plus `burst` jetons et se recharge de `rate` jetons par seconde. Une requête consomme un
-- jeton ; sans jeton, elle est refusée.

export type RateLimiter = {
	allow: (key: any, bucket: string, rate: number, burst: number) -> boolean,
	forget: (key: any) -> (),
}

type Bucket = { tokens: number, last: number }

local RateLimiter = {}

function RateLimiter.new(clock: (() -> number)?): RateLimiter
	local now = clock or os.clock
	local buckets: { [any]: { [string]: Bucket } } = {}

	local function allow(key: any, bucketName: string, rate: number, burst: number): boolean
		local t = now()
		local perKey = buckets[key]
		if perKey == nil then
			perKey = {}
			buckets[key] = perKey
		end
		local bucket = perKey[bucketName]
		if bucket == nil then
			bucket = { tokens = burst, last = t }
			perKey[bucketName] = bucket
		end
		bucket.tokens = math.min(burst, bucket.tokens + (t - bucket.last) * rate)
		bucket.last = t
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	local function forget(key: any)
		buckets[key] = nil
	end

	return { allow = allow, forget = forget }
end

return table.freeze(RateLimiter)
