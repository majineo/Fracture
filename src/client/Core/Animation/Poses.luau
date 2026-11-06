--!strict
-- Poses des animations procédurales. Une pose = rotation (et parfois décalage) par articulation.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > Poses
--
-- Les angles sont en degrés (voir le repère dans JointRig). Pour retoucher une pose :
-- modifier les valeurs ici, relancer le test. Les articulations absentes d'une pose gardent
-- l'animation Roblox de base.

export type Pose = { [string]: CFrame }

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local Poses = {}

-- Glissade, pieds devant : buste penché en arrière, jambe avant tendue, jambe arrière repliée,
-- main droite qui frôle le sol, bras gauche en avant pour l'équilibre.
Poses.Slide = table.freeze({
	-- Décalage vertical réglé pour que le point le plus bas touche le sol (mesuré : y ≈ 0).
	Root = CFrame.new(0, -0.38, 0.4) * A(34, 0, 0),
	Waist = A(10, 0, 0),
	Neck = A(-32, 0, 0),
	RightHip = A(48, 0, 4),
	RightKnee = A(-6, 0, 0),
	LeftHip = A(10, 0, -6),
	LeftKnee = A(-100, 0, 0),
	RightShoulder = A(-35, 0, 30),
	RightElbow = A(10, 0, 0),
	LeftShoulder = A(20, 0, -25),
	LeftElbow = A(40, 0, 0),
} :: Pose)

-- Escalade, phase 1 : on attrape le rebord, bras levés, jambes qui poussent.
Poses.MantleReach = table.freeze({
	Waist = A(-8, 0, 0),
	Neck = A(10, 0, 0),
	RightShoulder = A(165, 0, 8),
	RightElbow = A(15, 0, 0),
	LeftShoulder = A(165, 0, -8),
	LeftElbow = A(15, 0, 0),
	RightHip = A(35, 0, 0),
	RightKnee = A(-60, 0, 0),
	LeftHip = A(-10, 0, 0),
	LeftKnee = A(-25, 0, 0),
} :: Pose)

-- Escalade, phase 2 : on se hisse, bras qui poussent vers le bas, jambes ramenées.
Poses.MantleVault = table.freeze({
	Root = CFrame.new(0, -0.3, 0) * A(-12, 0, 0),
	Waist = A(-22, 0, 0),
	Neck = A(15, 0, 0),
	RightShoulder = A(-15, 0, 12),
	RightElbow = A(25, 0, 0),
	LeftShoulder = A(-15, 0, -12),
	LeftElbow = A(25, 0, 0),
	RightHip = A(85, 0, 0),
	RightKnee = A(-110, 0, 0),
	LeftHip = A(60, 0, 0),
	LeftKnee = A(-90, 0, 0),
} :: Pose)

-- Grappin : corps tiré, jambes qui traînent, bras gauche en arrière.
-- Le bras droit est orienté dynamiquement vers la cible (voir CharacterAnimation).
Poses.Grapple = table.freeze({
	Root = A(-8, 0, 0),
	Waist = A(-10, 0, 0),
	Neck = A(8, 0, 0),
	RightElbow = A(5, 0, 0),
	LeftShoulder = A(-35, 0, -22),
	LeftElbow = A(30, 0, 0),
	RightHip = A(-18, 0, 0),
	RightKnee = A(-45, 0, 0),
	LeftHip = A(12, 0, 0),
	LeftKnee = A(-70, 0, 0),
} :: Pose)

-- Saut, phase montante : jambe avant repliée, bras qui accompagnent vers le haut.
Poses.JumpRise = table.freeze({
	Waist = A(-6, 0, 0),
	RightShoulder = A(45, 0, 22),
	RightElbow = A(30, 0, 0),
	LeftShoulder = A(30, 0, -22),
	LeftElbow = A(30, 0, 0),
	RightHip = A(55, 0, 0),
	RightKnee = A(-75, 0, 0),
	LeftHip = A(-12, 0, 0),
	LeftKnee = A(-35, 0, 0),
} :: Pose)

-- Chute : bras écartés pour l'équilibre, jambes légèrement fléchies.
Poses.Fall = table.freeze({
	Waist = A(6, 0, 0),
	Neck = A(-8, 0, 0),
	RightShoulder = A(25, 0, 70),
	RightElbow = A(20, 0, 0),
	LeftShoulder = A(25, 0, -70),
	LeftElbow = A(20, 0, 0),
	RightHip = A(22, 0, 0),
	RightKnee = A(-35, 0, 0),
	LeftHip = A(8, 0, 0),
	LeftKnee = A(-20, 0, 0),
} :: Pose)

-- Réception : accroupi un court instant (poids réglé par la force de l'impact).
Poses.Land = table.freeze({
	Root = CFrame.new(0, -0.45, 0), -- pieds au sol (mesuré)
	Waist = A(-20, 0, 0),
	Neck = A(12, 0, 0),
	RightShoulder = A(25, 0, 15),
	LeftShoulder = A(25, 0, -15),
	RightHip = A(55, 0, 0),
	RightKnee = A(-80, 0, 0),
	LeftHip = A(55, 0, 0),
	LeftKnee = A(-80, 0, 0),
	RightAnkle = A(25, 0, 0),
	LeftAnkle = A(25, 0, 0),
} :: Pose)

-- Pistolet en main (bras droit orienté dynamiquement vers le point visé) : bras gauche en
-- soutien quand on vise.
Poses.AimSupport = table.freeze({
	-- Bras gauche vers l'avant et vers l'intérieur (+Z = vers le centre pour le bras gauche)
	-- pour venir soutenir la main droite.
	LeftShoulder = A(85, 0, 62),
	LeftElbow = A(22, 0, 0),
	RightElbow = A(5, 0, 0),
} :: Pose)

-- Arme longue (fusil, arbalète) : main gauche loin devant, sous le canon.
Poses.AimLongGun = table.freeze({
	LeftShoulder = A(92, 0, 48),
	LeftElbow = A(6, 0, 0),
	RightElbow = A(10, 0, 0),
} :: Pose)

-- Épée longue tenue à deux mains, pointe vers l'avant et un peu vers le haut.
-- Valeurs trouvées par recherche automatique sur un personnage figé (v0.4.3) : lame droit
-- devant et un peu relevée, main gauche à 0,14 stud de la poignée derrière la main droite.
Poses.GreatswordGuard = table.freeze({
	RightShoulder = A(50, 0, -40), -- main droite ramenée vers le centre du corps
	RightElbow = A(40, 0, 0),
	RightWrist = A(20, 10, 40), -- redresse la lame vers l'avant
	LeftShoulder = A(52, 0, 80),
	LeftElbow = A(0, 0, 0),
	Waist = A(0, 18, 0),
} :: Pose)

-- Parade : lame levée en travers devant soi.
Poses.Parry = table.freeze({
	RightShoulder = A(115, 0, -28),
	RightElbow = A(70, 0, 0),
	RightWrist = A(0, 0, 35),
	LeftShoulder = A(60, 0, 30),
	LeftElbow = A(50, 0, 0),
	Waist = A(-6, 14, 0),
} :: Pose)

-- Lame en main, en garde.
Poses.BladeGuard = table.freeze({
	-- Bras à 50° + coude 35° ≈ avant-bras horizontal : la lame pointe vers l'avant.
	-- (v0.4.0 : 35° + 65° dépassait la verticale, la lame pointait vers l'arrière.)
	RightShoulder = A(50, 0, 14),
	RightElbow = A(35, 0, 0),
	RightWrist = A(-10, 0, 0),
	LeftShoulder = A(20, 0, -15),
	LeftElbow = A(30, 0, 0),
} :: Pose)

-- À terre : allongé sur le ventre, appuyé sur les avant-bras (on rampe).
Poses.Downed = table.freeze({
	Root = CFrame.new(0, -2.3, 0) * A(-78, 0, 0),
	Waist = A(-8, 0, 0),
	Neck = A(55, 0, 0),
	RightShoulder = A(150, 0, 20),
	RightElbow = A(70, 0, 0),
	LeftShoulder = A(150, 0, -20),
	LeftElbow = A(70, 0, 0),
	RightHip = A(-5, 0, 6),
	LeftHip = A(10, 0, -6),
	LeftKnee = A(-25, 0, 0),
} :: Pose)

-- Sprint (additif, s'ajoute à l'animation de course) : buste penché vers l'avant.
Poses.SprintLean = table.freeze({
	Root = A(-7, 0, 0),
	Waist = A(-9, 0, 0),
	Neck = A(10, 0, 0),
} :: Pose)

return table.freeze(Poses)
