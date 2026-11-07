local G = require("../../src/shared/Combat/GuardianBrain")

local function input(now, ratio, distance)
	return { now = now, healthRatio = ratio, hasTarget = distance ~= nil, distance = distance or 0 }
end

return function(T)
	T.suite("GuardianBrain")

	T.test("phases : 60 % et 25 %, jamais de retour en arrière", function()
		T.equal(G.phaseFor(1), 1)
		T.equal(G.phaseFor(0.6), 2)
		T.equal(G.phaseFor(0.25), 3)
		local b = G.new(0)
		G.step(b, input(0, 0.5, 30))
		T.equal(b.phase, 2)
		G.step(b, input(10, 0.9, 30))
		T.equal(b.phase, 2, "soigné : reste en phase 2")
	end)

	T.test("coup d'épée : préparation annoncée puis coup", function()
		local b = G.new(0)
		T.equal(G.step(b, input(0, 1, 8)), "BeginSwing")
		T.equal(G.step(b, input(0.5, 1, 8)), "Busy")
		T.equal(G.step(b, input(0.95, 1, 8)), "Swing")
		T.equal(G.step(b, input(1.0, 1, 8)), "Idle", "recharge du coup")
	end)

	T.test("charge à distance, puis étourdi si elle rate", function()
		local b = G.new(0)
		T.equal(G.step(b, input(1, 1, 40)), "Chase", "charge pas encore prête")
		T.equal(G.step(b, input(4, 1, 40)), "BeginCharge")
		T.equal(G.step(b, input(5.3, 1, 40)), "Charge")
		T.equal(G.step(b, input(5.6, 1, 40)), "Busy", "en pleine charge")
		G.chargeMissed(b, 6.2)
		T.equal(G.step(b, input(7, 1, 40)), "Stunned")
		T.equal(G.step(b, input(8.8, 1, 40)), "Chase", "réveillé")
	end)

	T.test("phase 2 : invocation une seule fois, puis onde de choc de près", function()
		local b = G.new(0)
		T.equal(G.step(b, input(5, 0.5, 15)), "Summon")
		T.equal(G.step(b, input(7, 0.5, 15)), "BeginShockwave")
		T.equal(G.step(b, input(8.1, 0.5, 15)), "Shockwave")
		local summons = 0
		for t = 9, 40 do
			if G.step(b, input(t, 0.5, 15)) == "Summon" then
				summons += 1
			end
		end
		T.equal(summons, 0, "pas de seconde invocation")
	end)

	T.test("phase 3 : gel des zones et préparations plus rapides", function()
		local b = G.new(0)
		b.summoned = true
		b.nextShockwave = 100
		T.equal(G.step(b, input(5, 0.2, 8)), "FreezeZones")
		T.equal(G.step(b, input(5.1, 0.2, 8)), "BeginSwing")
		T.equal(G.step(b, input(5.6, 0.2, 8)), "Busy")
		T.equal(G.step(b, input(5.75, 0.2, 8)), "Swing", "0,63 s au lieu de 0,9 s")
	end)

	T.test("sans cible : il attend", function()
		local b = G.new(0)
		T.equal(G.step(b, input(1, 1, nil)), "Idle")
	end)
end
