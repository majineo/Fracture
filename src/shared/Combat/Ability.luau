--!strict
-- Capacités spéciales des armes (v0.4.5, D-038). Module pur : testé par
-- tests/specs/Ability.spec.luau. Le serveur fait foi ; le client lit les définitions pour
-- l'affichage (jauge, noms).
-- Studio : ReplicatedStorage > Shared > Combat > Ability
--
-- Principe : chaque arme a un NOYAU (fragment de Temps) qui se charge en infligeant des
-- dégâts avec cette arme. Noyau plein → la capacité active est utilisable (touche Q, bouton
-- « Capacité »). Chaque capacité est annoncée par un court temps de préparation.

export type AbilityId =
	"Rewind"
	| "ShadowStep"
	| "Volley"
	| "Ricochet"
	| "Stasis"
	| "FractureWave"
	| "TimeGuard"
	| "ZenithBeam"
	| "SteamBlast"
	| "Overdrive"
	| "Quake"
	| "Reap"

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
	-- Salve au levier (fusil)
	shots: number?, -- tirs de la salve
	interval: number?, -- secondes entre deux tirs
	extraSpread: number?, -- dispersion ajoutée (degrés)
	-- Carreau de stase (arbalète)
	radius: number?,
	duration: number?,
	slow: number?, -- vitesse conservée dans la bulle (0,5 = moitié)
	shotDamping: number?, -- dégâts conservés par un tir qui traverse la bulle
	-- Onde de fracture (épée longue)
	length: number?,
	halfWidth: number?,
	damage: number?,
	slowDuration: number?,
	-- Garde du Temps (épée longue)
	drainTime: number?, -- secondes pour vider un noyau plein
	frontAngle: number?, -- demi-angle protégé (degrés)
	-- Arsenal de la Fracture (v0.10.0)
	angle: number?, -- demi-angle du cône (Souffle de vapeur)
	push: number?, -- vitesse de recul donnée aux cibles
	selfPush: number?, -- recul du lanceur (propulsion)
	stun: number?, -- étourdissement des ennemis (secondes)
	lift: number?, -- vitesse verticale donnée aux cibles
	rateMultiplier: number?, -- Surchauffe : cadence
	lifesteal: number?, -- Moisson : part des dégâts rendue en santé
	healMax: number?, -- Moisson : santé rendue au maximum
	-- Commande
	hold: boolean?, -- capacité secondaire : appui long (fusil) ou maintien de la parade (épée)
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
	-- v0.4.7 ---------------------------------------------------------------------------
	Volley = table.freeze({
		id = "Volley",
		name = "Salve au levier",
		charge = 100,
		windup = 0,
		shots = 3,
		interval = 0.2,
		extraSpread = 2.5,
	} :: AbilityDef),
	Ricochet = table.freeze({
		id = "Ricochet",
		name = "Balle de rebond",
		charge = 100,
		windup = 0,
		hold = true,
	} :: AbilityDef),
	Stasis = table.freeze({
		id = "Stasis",
		name = "Carreau de stase",
		charge = 100,
		windup = 0,
		range = 60, -- portée du carreau (au-delà, la bulle tombe au sol)
		radius = 4,
		duration = 3,
		slow = 0.5,
		shotDamping = 0.5,
	} :: AbilityDef),
	FractureWave = table.freeze({
		id = "FractureWave",
		name = "Onde de fracture",
		charge = 100,
		windup = 0.5,
		length = 8,
		halfWidth = 1.75,
		damage = 35,
		slowDuration = 1.2,
		slow = 0.4,
	} :: AbilityDef),
	-- v0.4.12 -----------------------------------------------------------------------------
	ZenithBeam = table.freeze({
		id = "ZenithBeam",
		name = "Rayon du Zénith",
		charge = 120,
		windup = 1.2, -- cercles runiques visibles par tous avant la frappe
		range = 160, -- distance maximale du point visé
		radius = 7,
		damage = 70, -- au centre ; moitié au bord
	} :: AbilityDef),
	-- v0.10.0 ----------------------------------------------------------------------------
	SteamBlast = table.freeze({
		id = "SteamBlast",
		name = "Souffle de vapeur",
		charge = 90,
		windup = 0.15,
		length = 11,
		angle = 55,
		damage = 22,
		push = 55,
		lift = 22,
		selfPush = 46,
		stun = 1,
		slow = 0.5,
		slowDuration = 1,
	} :: AbilityDef),
	Overdrive = table.freeze({
		id = "Overdrive",
		name = "Surchauffe",
		charge = 140,
		windup = 0,
		duration = 4,
		rateMultiplier = 1.8,
	} :: AbilityDef),
	Quake = table.freeze({
		id = "Quake",
		name = "Frappe sismique",
		charge = 110,
		windup = 0.45,
		radius = 10,
		damage = 45, -- au centre ; moitié au bord
		lift = 38,
		stun = 1.5,
		slow = 0.35,
		slowDuration = 1.5,
	} :: AbilityDef),
	Reap = table.freeze({
		id = "Reap",
		name = "Moisson",
		charge = 100,
		windup = 0.25,
		radius = 10,
		damage = 32,
		lifesteal = 0.4,
		healMax = 45,
	} :: AbilityDef),
	TimeGuard = table.freeze({
		id = "TimeGuard",
		name = "Garde du Temps",
		charge = 100,
		windup = 0,
		drainTime = 3,
		frontAngle = 75,
		slow = 0.5,
		hold = true,
	} :: AbilityDef),
})

-- Traits passifs (arme → effet), appliqués par le serveur.
Ability.PASSIVES = table.freeze({
	-- Pistolet : chargeur plein dès qu'on élimine ou met à terre une cible.
	ReloadOnKill = "ReloadOnKill",
	-- Lame courte : après une parade réussie, le coup suivant fait ×2 (pendant 1,5 s).
	Riposte = "Riposte",
	-- Fusil : après 1 s immobile, le tir suivant fait +25 %.
	Steady = "Steady",
})
Ability.STEADY_TIME = 1
Ability.STEADY_MULTIPLIER = 1.25
-- Fusil du Zénith : après 0,8 s immobile, un tir dans la tête fait ×1,35 de plus (≈ ×2).
Ability.SCOPE_FOCUS_TIME = 0.8
Ability.SCOPE_FOCUS_HEADSHOT = 1.35
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

-- Garde du Temps : vide le noyau au fil du temps. Renvoie false quand il est vide.
function Ability.drain(core: Core, def: AbilityDef, dt: number): boolean
	local rate = def.charge / (def.drainTime or 1)
	core.charge = math.max(0, core.charge - rate * math.max(dt, 0))
	return core.charge > 0
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
