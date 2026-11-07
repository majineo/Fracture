--!strict
-- Position d'une arme dans la main droite. Partagé : le serveur soude l'arme à la main avec
-- ce décalage (WeaponModels), le client place la main là où l'arme doit être (WeaponHold).
-- Studio : ReplicatedStorage > Shared > Combat > WeaponGrip
--
-- Repère de la poignée (pièce « Grip ») : -Z = vers l'avant (canon / lame), +Y = dessus.

local WeaponGrip = {}

-- Poignée exprimée dans le repère de la main droite (réglé par mesure en jeu, v0.4.1).
WeaponGrip.HAND_TO_GRIP = CFrame.new(0, -0.15, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)

-- Main droite exprimée dans le repère de la poignée.
WeaponGrip.GRIP_TO_HAND = WeaponGrip.HAND_TO_GRIP:Inverse()

return table.freeze(WeaponGrip)
