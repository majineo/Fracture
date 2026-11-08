local HitMath = require("../../src/shared/Combat/HitMath")
local WeaponState = require("../../src/shared/Combat/WeaponState")
local WeaponDefs = require("../../src/shared/Combat/WeaponDefs")
local Ability = require("../../src/shared/Combat/Ability")

return function(T)
	T.suite("Arsenal (v0.10.0)")

	T.test("plombs : nombre, gerbe bornée, premier au centre, déterministes", function()
		local a = HitMath.pelletOffsets(8, 5.5, 1234)
		local b = HitMath.pelletOffsets(8, 5.5, 1234)
		T.equal(#a, 8)
		T.equal(a[1][1], 0)
		T.equal(a[1][2], 0)
		for i, o in a do
			local r = math.sqrt(o[1] * o[1] + o[2] * o[2])
			T.truthy(r <= 5.5 + 1e-9, `plomb {i} hors gerbe : {r}`)
			T.equal(o[1], b[i][1])
		end
		local c = HitMath.pelletOffsets(8, 5.5, 99)
		T.truthy(c[2][1] ~= a[2][1], "graines différentes → gerbes différentes")
	end)

	T.test("plombs : pas tous du même côté", function()
		local o = HitMath.pelletOffsets(8, 5, 7)
		local left, right = 0, 0
		for i = 2, #o do
			if o[i][1] < 0 then
				left += 1
			else
				right += 1
			end
		end
		T.truthy(left >= 2 and right >= 2, `gauche {left}, droite {right}`)
	end)

	T.test("Surchauffe : cadence ×1,8 acceptée, cadence normale refusée plus vite", function()
		local def = WeaponDefs["weapon.crank_gatling"]
		local state = WeaponState.new(def)
		WeaponState.fire(state, def, 10)
		local quick = 10 + 1 / (def.fireRate * 1.8) + 1e-4
		T.falsy(WeaponState.canFire(state, def, quick), "trop tôt sans Surchauffe")
		T.truthy(WeaponState.canFire(state, def, quick, 0, 1.8), "permis en Surchauffe")
	end)

	T.test("nouvelles armes : capacités définies et emplacements cohérents", function()
		for _, id in
			{
				"weapon.steam_blunderbuss",
				"weapon.crank_gatling",
				"weapon.piston_hammer",
				"weapon.time_scythe",
			}
		do
			local def = WeaponDefs[id]
			T.truthy(def ~= nil, id)
			T.truthy(Ability.DEFS[def.ability] ~= nil, `capacité de {id}`)
			T.equal(def.slot, if def.kind == "Melee" then "Melee" else "Firearm")
		end
		T.equal(WeaponDefs["weapon.steam_blunderbuss"].pellets, 8)
		T.truthy(WeaponDefs["weapon.crank_gatling"].automatic)
	end)

	T.test("tromblon : redoutable au contact, faible de loin", function()
		local def = WeaponDefs["weapon.steam_blunderbuss"]
		T.equal(def.damage * def.pellets, 88)
		T.truthy(def.damage * def.minDamageRatio * def.pellets < 20, "à 30 studs et plus")
	end)
end
