local Damage = require("../../src/shared/Combat/Damage")
local WeaponState = require("../../src/shared/Combat/WeaponState")
local HitMath = require("../../src/shared/Combat/HitMath")
local PositionHistory = require("../../src/server/Core/Lib/PositionHistory")

local PISTOL = {
	damage = 24,
	falloffStart = 35,
	falloffEnd = 90,
	minDamageRatio = 0.55,
	fireRate = 5,
	magazine = 12,
	reloadTime = 1.4,
}

local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end

return function(T)
	T.suite("Damage")

	T.test("dégâts pleins avant la chute, minimum après", function()
		T.equal(Damage.atDistance(PISTOL, 10), 24)
		T.equal(Damage.atDistance(PISTOL, 35), 24)
		T.truthy(near(Damage.atDistance(PISTOL, 200), 24 * 0.55))
		local mid = Damage.atDistance(PISTOL, 62.5)
		T.truthy(near(mid, 24 * (1 - 0.5 * 0.45)), `milieu {mid}`)
	end)

	T.test("tête ×1,5 et multiplicateur libre", function()
		T.equal(Damage.compute(PISTOL, 10, true, 1.5), 36)
		T.equal(Damage.compute(PISTOL, 10, false, 1.5, 2), 48)
	end)

	T.test("l'armure absorbe en premier", function()
		local s = Damage.split(24, 15)
		T.equal(s.armor, 15)
		T.equal(s.health, 9)
		s = Damage.split(10, 15)
		T.equal(s.armor, 10)
		T.equal(s.health, 0)
		s = Damage.split(10, 0)
		T.equal(s.health, 10)
	end)

	T.test("temps pour tuer visé : 100 PV + 15 d'armure au pistolet", function()
		-- 115 / 24 = 5 balles au corps, soit 4 intervalles à 5 tirs/s = 0,8 s (GDD : 1 à 1,5 s
		-- entre joueurs mieux équipés ; l'équipement de base reste rapide à tuer).
		local shots = math.ceil(115 / Damage.compute(PISTOL, 20, false, 1.5))
		T.equal(shots, 5)
		local headShots = math.ceil(115 / Damage.compute(PISTOL, 20, true, 1.5))
		T.equal(headShots, 4)
	end)

	T.suite("WeaponState")

	T.test("cadence de tir respectée", function()
		local s = WeaponState.new(PISTOL)
		T.truthy(WeaponState.canFire(s, PISTOL, 10))
		WeaponState.fire(s, PISTOL, 10)
		T.falsy(WeaponState.canFire(s, PISTOL, 10.1), "trop tôt")
		T.truthy(WeaponState.canFire(s, PISTOL, 10.2), "intervalle 0,2 s")
		T.truthy(WeaponState.canFire(s, PISTOL, 10.17, 0.05), "tolérance réseau")
	end)

	T.test("chargeur vide puis rechargement", function()
		local s = WeaponState.new(PISTOL)
		for i = 1, 12 do
			WeaponState.fire(s, PISTOL, i)
		end
		T.equal(s.ammo, 0)
		T.falsy(WeaponState.canFire(s, PISTOL, 20), "vide")
		T.truthy(WeaponState.reload(s, PISTOL, 20))
		T.falsy(WeaponState.reload(s, PISTOL, 20.5), "déjà en cours")
		T.falsy(WeaponState.canFire(s, PISTOL, 21), "en rechargement")
		T.truthy(WeaponState.canFire(s, PISTOL, 21.5), "rechargé")
		T.equal(s.ammo, 12)
	end)

	T.test("recharger un chargeur plein ne fait rien", function()
		local s = WeaponState.new(PISTOL)
		T.falsy(WeaponState.reload(s, PISTOL, 1))
	end)

	T.suite("HitMath")

	T.test("rayon contre sphère", function()
		-- Rayon depuis (0,0,-10) vers +Z, sphère de rayon 1 en (0,0,0) : touche à t = 9.
		local t = HitMath.raySphere(0, 0, -10, 0, 0, 1, 0, 0, 0, 1, 100)
		T.truthy(t and near(t, 9), `t = {t}`)
		T.equal(HitMath.raySphere(0, 2, -10, 0, 0, 1, 0, 0, 0, 1, 100), nil, "passe au-dessus")
		T.equal(HitMath.raySphere(0, 0, 10, 0, 0, 1, 0, 0, 0, 1, 100), nil, "derrière l'origine")
		T.equal(HitMath.raySphere(0, 0, -10, 0, 0, 1, 0, 0, 0, 1, 5), nil, "hors de portée")
	end)

	T.test("rayon contre boîte", function()
		local t = HitMath.rayBox(0, 0, -10, 0, 0, 1, 1, 2.5, 0.6, 100)
		T.truthy(t and near(t, 9.4), `t = {t}`)
		T.equal(HitMath.rayBox(3, 0, -10, 0, 0, 1, 1, 2.5, 0.6, 100), nil, "à côté")
		local diag =
			HitMath.rayBox(-10, -10, 0, 1 / math.sqrt(2), 1 / math.sqrt(2), 0, 1, 1, 1, 100)
		T.truthy(diag ~= nil, "diagonale")
	end)

	T.test("angle entre directions", function()
		T.truthy(near(HitMath.angleBetween(1, 0, 0, 0, 1, 0), 90))
		T.truthy(near(HitMath.angleBetween(0, 0, 1, 0, 0, 1), 0))
	end)

	T.suite("PositionHistory")

	T.test("interpolation entre deux échantillons", function()
		local h = PositionHistory.new(1)
		PositionHistory.record(h, 0, 0, 0, 0, 0)
		PositionHistory.record(h, 0.1, 10, 0, 0, 0)
		local s = PositionHistory.at(h, 0.05)
		T.truthy(s and near(s.x, 5), `x = {s and s.x}`)
	end)

	T.test("bornes : avant le plus ancien, après le plus récent", function()
		local h = PositionHistory.new(1)
		PositionHistory.record(h, 1, 1, 0, 0, 0)
		PositionHistory.record(h, 2, 2, 0, 0, 0)
		T.equal(PositionHistory.at(h, 0).x, 1)
		T.equal(PositionHistory.at(h, 5).x, 2)
		T.equal(PositionHistory.at(PositionHistory.new(1), 1), nil, "vide")
	end)

	T.test("oublie les échantillons trop vieux", function()
		local h = PositionHistory.new(1)
		for i = 0, 40 do
			PositionHistory.record(h, i * 0.1, i, 0, 0, 0)
		end
		T.truthy(h.samples[1].t >= 3 - 1e-9, `plus ancien {h.samples[1].t}`)
	end)

	T.test("l'angle s'interpole par le plus court chemin", function()
		local h = PositionHistory.new(1)
		PositionHistory.record(h, 0, 0, 0, 0, math.rad(170))
		PositionHistory.record(h, 1, 0, 0, 0, math.rad(-170))
		local s = PositionHistory.at(h, 0.5)
		T.truthy(math.abs(math.abs(math.deg(s.yaw)) - 180) < 1e-3, `yaw {math.deg(s.yaw)}`)
	end)
end
