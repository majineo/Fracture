--!strict
-- État d'une arme : munitions, cadence, rechargement. Module pur (temps fourni) : testé par
-- tests/specs/WeaponState.spec.luau. Utilisé par le serveur (qui fait foi) et par le client
-- (prédiction de l'affichage).
-- Studio : ReplicatedStorage > Shared > Combat > WeaponState

export type Def = {
	fireRate: number,
	magazine: number,
	reloadTime: number,
}

export type State = {
	ammo: number,
	lastShot: number,
	reloadEndsAt: number?, -- nil = pas en rechargement
}

local WeaponState = {}

function WeaponState.new(def: Def): State
	return { ammo = def.magazine, lastShot = -math.huge, reloadEndsAt = nil }
end

-- Termine un rechargement arrivé à son terme.
local function settle(state: State, def: Def, now: number)
	if state.reloadEndsAt and now >= state.reloadEndsAt then
		state.ammo = def.magazine
		state.reloadEndsAt = nil
	end
end

function WeaponState.isReloading(state: State, now: number, def: Def): boolean
	settle(state, def, now)
	return state.reloadEndsAt ~= nil
end

-- Le tir est-il permis maintenant ? `tolerance` (secondes) absorbe la gigue réseau côté
-- serveur : un client honnête qui tire à cadence max ne doit jamais être refusé.
function WeaponState.canFire(state: State, def: Def, now: number, tolerance: number?): boolean
	settle(state, def, now)
	if state.reloadEndsAt ~= nil then
		return false
	end
	if def.magazine > 0 and state.ammo <= 0 then
		return false
	end
	local interval = 1 / def.fireRate
	-- Marge infime contre les erreurs d'arrondi (10,2 - 10 = 0,19999…).
	return now - state.lastShot >= interval - (tolerance or 0) - 1e-6
end

-- Enregistre un tir (à appeler seulement si canFire a répondu oui).
function WeaponState.fire(state: State, def: Def, now: number)
	state.lastShot = now
	if def.magazine > 0 then
		state.ammo -= 1
	end
end

-- Démarre un rechargement. Renvoie false s'il est inutile ou déjà en cours.
function WeaponState.reload(state: State, def: Def, now: number): boolean
	settle(state, def, now)
	if def.magazine <= 0 or state.reloadEndsAt ~= nil or state.ammo >= def.magazine then
		return false
	end
	state.reloadEndsAt = now + def.reloadTime
	return true
end

-- Annule un rechargement en cours (changement d'arme).
function WeaponState.cancelReload(state: State)
	state.reloadEndsAt = nil
end

return table.freeze(WeaponState)
