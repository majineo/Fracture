local EnemyBrain = require("../../src/shared/Combat/EnemyBrain")

local MELEE = { behavior = "Melee", attackRange = 6, leashRange = 90, windup = 0.6, cooldown = 1.5 }
local RANGED = {
	behavior = "Ranged",
	attackRange = 85,
	leashRange = 110,
	keepDistance = 16,
	windup = 1.1,
	cooldown = 2.8,
}

local function see(now, distance, los, home)
	return {
		now = now,
		hasTarget = true,
		distance = distance,
		lineOfSight = los ~= false,
		homeDistance = home or 0,
		stunnedUntil = 0,
	}
end

return function(T)
	T.suite("EnemyBrain")

	T.test("mêlée : poursuit, prépare, frappe, puis recharge", function()
		local b = EnemyBrain.new()
		T.equal(EnemyBrain.step(b, see(0, 30), MELEE), "Chase")
		T.equal(EnemyBrain.step(b, see(1, 5), MELEE), "BeginWindup")
		T.equal(EnemyBrain.step(b, see(1.3, 5), MELEE), "Windup", "préparation en cours")
		T.equal(EnemyBrain.step(b, see(1.6, 5), MELEE), "Strike", "fin de préparation")
		T.equal(EnemyBrain.step(b, see(2.0, 3), MELEE), "Hold", "en recharge au contact")
		T.equal(EnemyBrain.step(b, see(3.2, 5), MELEE), "BeginWindup", "recharge terminée")
	end)

	T.test(
		"le coup part même si la cible recule pendant la préparation (esquive par le mouvement)",
		function()
			local b = EnemyBrain.new()
			EnemyBrain.step(b, see(0, 5), MELEE)
			T.equal(EnemyBrain.step(b, see(0.7, 12), MELEE), "Strike")
		end
	)

	T.test("étourdi par une parade : préparation annulée", function()
		local b = EnemyBrain.new()
		EnemyBrain.step(b, see(0, 5), MELEE)
		local p = see(0.3, 5)
		p.stunnedUntil = 1.2
		T.equal(EnemyBrain.step(b, p, MELEE), "Stunned")
		T.equal(
			EnemyBrain.step(b, see(1.0, 5), MELEE) == "Stunned",
			false,
			"lecture sans étourdissement"
		)
		T.truthy(b.cooldownUntil >= 1.2, "pas d'attaque avant la fin de l'étourdissement")
	end)

	T.test("sans cible : rentre au poste puis attend", function()
		local b = EnemyBrain.new()
		local p = {
			now = 0,
			hasTarget = false,
			distance = 0,
			lineOfSight = false,
			homeDistance = 20,
			stunnedUntil = 0,
		}
		T.equal(EnemyBrain.step(b, p, MELEE), "Return")
		p.homeDistance = 2
		T.equal(EnemyBrain.step(b, p, MELEE), "Idle")
	end)

	T.test("cible trop loin (laisse) : abandon", function()
		local b = EnemyBrain.new()
		T.equal(EnemyBrain.step(b, see(0, 120, true, 30), MELEE), "Return")
	end)

	T.test("tireur : vise, tire, recule si on s'approche", function()
		local b = EnemyBrain.new()
		T.equal(EnemyBrain.step(b, see(0, 40), RANGED), "BeginAim")
		T.equal(EnemyBrain.step(b, see(0.5, 40), RANGED), "Aim")
		T.equal(EnemyBrain.step(b, see(1.2, 40), RANGED), "Fire")
		T.equal(EnemyBrain.step(b, see(1.5, 40), RANGED), "Hold", "recharge")
		T.equal(EnemyBrain.step(b, see(1.6, 8), RANGED), "Retreat", "trop près")
	end)

	T.test("tireur : se cacher annule la visée", function()
		local b = EnemyBrain.new()
		EnemyBrain.step(b, see(0, 40), RANGED)
		T.equal(EnemyBrain.step(b, see(0.5, 40, false), RANGED), "Chase", "plus de ligne de vue")
		T.equal(b.phase, "Free")
	end)
end
