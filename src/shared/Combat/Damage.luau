--!strict
-- Calcul des dégâts. Module pur : testé par tests/specs/Damage.spec.luau.
-- Studio : ReplicatedStorage > Shared > Combat > Damage
-- Le serveur fait foi ; le client s'en sert seulement pour prévoir l'affichage.

export type FalloffDef = {
	damage: number,
	falloffStart: number,
	falloffEnd: number,
	minDamageRatio: number,
}

export type Split = {
	armor: number, -- points d'armure retirés
	health: number, -- points de santé retirés
}

local Damage = {}

-- Dégâts de base selon la distance (avant tête et armure).
function Damage.atDistance(def: FalloffDef, distance: number): number
	if def.falloffEnd <= def.falloffStart or distance <= def.falloffStart then
		return def.damage
	end
	if distance >= def.falloffEnd then
		return def.damage * def.minDamageRatio
	end
	local t = (distance - def.falloffStart) / (def.falloffEnd - def.falloffStart)
	return def.damage * (1 - t * (1 - def.minDamageRatio))
end

-- Répartit des dégâts entre l'armure (absorbée en premier) et la santé.
function Damage.split(amount: number, armor: number): Split
	local absorbed = math.min(math.max(armor, 0), math.max(amount, 0))
	return { armor = absorbed, health = math.max(amount, 0) - absorbed }
end

-- Dégâts complets d'une touche : distance, multiplicateur de tête, multiplicateur libre
-- (ex. attaque chargée). Arrondi au dixième pour un affichage propre.
function Damage.compute(
	def: FalloffDef,
	distance: number,
	headshot: boolean,
	headMultiplier: number,
	extra: number?
): number
	local base = Damage.atDistance(def, distance) * (extra or 1)
	if headshot then
		base *= headMultiplier
	end
	return math.floor(base * 10 + 0.5) / 10
end

return table.freeze(Damage)
