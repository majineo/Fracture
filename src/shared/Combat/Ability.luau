--!strict
-- Capacités spéciales des armes (v0.4.5, D-038). Module pur : testé par
-- tests/specs/Ability.spec.luau. Le serveur fait foi ; le client lit les définitions pour
-- l'affichage (jauge, noms).
-- Studio : ReplicatedStorage > Shared > Combat > Ability
--
-- Principe : chaque arme a un NOYAU (fragment de Temps) qui se charge en infligeant des
-- dégâts avec cette arme. Noyau plein → la capacité active est utilisable (touche Q, bouton
-- « Capacité »). Chaque capacité est annoncée par un court temps de préparation.

export type AbilityId = "Rewind" | "ShadowStep"

export type AbilityDef = {
	id: AbilityId,
	name: string,
	charge: number, -- dégâts à infliger pour remplir le noyau
	windup: number, -- annonce avant l'effet (secondes)
	-- Retour (pistolet)
	rewindSeconds: number?, -- revient à la position d'il y a N secondes
	healCap: number?, -- santé rendue au maximum
	-- Pas de l'ombre (lame courte)
	range: number?, -- distance maximale de la cible
	behind: number?, -- distance derrière la cible où l'on réapparaît
	backstabMultiplier: number?, -- bonus du premier coup qui suit
	backstabWindow: number?, -- durée pendant laquelle ce bonus attend
}

export type Core = {
	charge: number,
	lastUse: number,
}

local Ability = {}

-- Délai minimal entre deux capacités (anti-répétition, en plus du noyau).
Ability.MIN_INTERVAL = 1

Ability.DEFS = table.freeze({
	Rewind = table.freeze({
		id = "Rewind",
		name = "Retour",
		charge = 100,
		windup = 0.25,
		rewindSeconds = 2,
		healCap = 35,
	} :: AbilityDef),
	ShadowStep = table.freeze({
		id = "ShadowStep",
		name = "Pas de l'ombre",
		charge = 100,
		windup = 0.3,
		range = 12,
		behind = 2.6,
		backstabMultiplier = 1.5,
		backstabWindow = 1.5,
	} :: AbilityDef),
})

-- Traits passifs (arme → effet), appliqués par le serveur.
Ability.PASSIVES = table.freeze({
	-- Pistolet : chargeur plein dès qu'on élimine ou met à terre une cible.
	ReloadOnKill = "ReloadOnKill",
	-- Lame courte : après une parade réussie, le coup suivant fait ×2 (pendant 1,5 s).
	Riposte = "Riposte",
})
Ability.RIPOSTE_MULTIPLIER = 2
Ability.RIPOSTE_WINDOW = 1.5

function Ability.newCore(): Core
	return { charge = 0, lastUse = -math.huge }
end

-- Ajoute des dégâts infligés au noyau. Renvoie true si le noyau vient de se remplir.
function Ability.addDamage(core: Core, amount: number, def: AbilityDef): boolean
	if amount ~= amount or amount <= 0 then
		return false
	end
	local wasFull = core.charge >= def.charge
	core.charge = math.min(def.charge, core.charge + amount)
	return not wasFull and core.charge >= def.charge
end

-- Remplissage entre 0 et 1 (affichage).
function Ability.fraction(core: Core, def: AbilityDef): number
	return math.clamp(core.charge / def.charge, 0, 1)
end

function Ability.isReady(core: Core, def: AbilityDef, now: number): boolean
	return core.charge >= def.charge and now - core.lastUse >= Ability.MIN_INTERVAL
end

-- Vide le noyau. Renvoie false si la capacité n'était pas prête.
function Ability.consume(core: Core, def: AbilityDef, now: number): boolean
	if not Ability.isReady(core, def, now) then
		return false
	end
	core.charge = 0
	core.lastUse = now
	return true
end

-- Capacité annulée pendant sa préparation (mis à terre, cible disparue…) : noyau rendu.
function Ability.refund(core: Core, def: AbilityDef)
	core.charge = def.charge
	core.lastUse = -math.huge
end

-- Retour : santé après le retour. On récupère la santé d'il y a N secondes, jamais moins que
-- l'actuelle, et au plus `healCap` de plus.
function Ability.rewindHealth(current: number, past: number, healCap: number): number
	return math.max(current, math.min(past, current + healCap))
end

-- Historique court (horodaté) : position et santé du joueur pour le Retour.
export type History<T> = { times: { number }, values: { T }, duration: number }

function Ability.newHistory<T>(duration: number): History<T>
	return { times = {}, values = {}, duration = duration }
end

function Ability.record<T>(history: History<T>, t: number, value: T)
	table.insert(history.times, t)
	table.insert(history.values, value)
	-- On garde un échantillon plus vieux que `duration` pour pouvoir y remonter exactement.
	while #history.times > 2 and history.times[2] < t - history.duration do
		table.remove(history.times, 1)
		table.remove(history.values, 1)
	end
end

-- Échantillon le plus récent pris au plus tard à l'heure `t` (le plus ancien sinon).
function Ability.sampleAt<T>(history: History<T>, t: number): T?
	local found: T? = nil
	for i, time in history.times do
		if time <= t then
			found = history.values[i]
		else
			break
		end
	end
	if found == nil then
		return history.values[1]
	end
	return found
end

return table.freeze(Ability)
