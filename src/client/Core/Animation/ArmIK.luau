--!strict
-- Cinématique inverse d'un bras R15 : on donne où doit être la MAIN (position et orientation),
-- on obtient les rotations de l'épaule, du coude et du poignet. Sert à poser les mains sur
-- les armes quelle que soit la morphologie de l'avatar (les longueurs sont mesurées sur le
-- personnage lui-même).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > ArmIK
--
-- Tout est exprimé dans le repère du HAUT DU TORSE (UpperTorso) : la pose ne dépend pas de
-- l'image précédente et suit naturellement les inclinaisons du buste.
-- Rappel (AnimationConstraint comme Motor6D) : Part1 = Part0 * C0 * Transform * C1⁻¹.

local JointRig = require(script.Parent.JointRig)

export type Arm = {
	shoulderC0: CFrame,
	upperToElbow: CFrame, -- repère du coude, dans le repère de l'épaule après sa rotation
	elbowC1Inv: CFrame,
	wristC0: CFrame,
	wristC1: CFrame,
	wristC1Inv: CFrame,
	lowerToWrist: Vector3, -- articulation du poignet, dans le repère du coude après sa rotation
	reach: number, -- distance maximale épaule → poignet
	wristToGrip: number, -- distance poignet → centre de la paume (prise de l'arme)
}

export type Solution = {
	shoulder: CFrame,
	elbow: CFrame,
	wrist: CFrame,
	hand: CFrame, -- main réellement atteinte (repère du torse)
}

local MAX_BEND = math.rad(155)
local ITERATIONS = 18

local ArmIK = {}

local function frames(joint: JointRig.Joint): (CFrame?, CFrame?)
	if joint:IsA("Motor6D") then
		return joint.C0, joint.C1
	end
	local constraint = joint :: AnimationConstraint
	local a0, a1 = constraint.Attachment0, constraint.Attachment1
	if a0 == nil or a1 == nil then
		return nil, nil
	end
	return a0.CFrame, a1.CFrame
end

-- Mesure un bras ("Right" ou "Left") sur le personnage. nil si une articulation manque.
function ArmIK.measure(rig: JointRig.Rig, side: string, handToGrip: CFrame): Arm?
	local shoulder, elbow, wrist =
		rig[side .. "Shoulder"], rig[side .. "Elbow"], rig[side .. "Wrist"]
	if shoulder == nil or elbow == nil or wrist == nil then
		return nil
	end
	local s0, s1 = frames(shoulder)
	local e0, e1 = frames(elbow)
	local w0, w1 = frames(wrist)
	if s0 == nil or s1 == nil or e0 == nil or e1 == nil or w0 == nil or w1 == nil then
		return nil
	end
	local upperToElbow = s1:Inverse() * e0
	local lowerToWrist = (e1:Inverse() * w0).Position
	return {
		shoulderC0 = s0,
		upperToElbow = upperToElbow,
		elbowC1Inv = e1:Inverse(),
		wristC0 = w0,
		wristC1 = w1,
		wristC1Inv = w1:Inverse(),
		lowerToWrist = lowerToWrist,
		reach = upperToElbow.Position.Magnitude + lowerToWrist.Magnitude,
		wristToGrip = (w1.Position - handToGrip.Position).Magnitude,
	}
end

-- Position de l'épaule (articulation) dans le repère du torse.
function ArmIK.shoulderPosition(arm: Arm): Vector3
	return arm.shoulderC0.Position
end

local function perpendicular(v: Vector3): Vector3
	local other = if math.abs(v.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
	return v:Cross(other).Unit
end

local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local dot = math.clamp(from:Dot(to), -1, 1)
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		return if dot > 0
			then CFrame.identity
			else CFrame.fromAxisAngle(perpendicular(from), math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Place la main en `hand` (repère du torse). `pole` (repère du torse) : direction vers
-- laquelle le coude doit pointer (ex. vers le bas et l'extérieur).
function ArmIK.solve(arm: Arm, hand: CFrame, pole: Vector3): Solution
	local wristJoint = hand * arm.wristC1
	local target = arm.shoulderC0:PointToObjectSpace(wristJoint.Position)
	local distance = target.Magnitude

	-- 1. Pliure du coude (rotation +X) pour que la distance épaule → poignet soit la bonne.
	local function reachAt(theta: number): number
		return (arm.upperToElbow * CFrame.Angles(theta, 0, 0) * arm.lowerToWrist).Magnitude
	end
	local theta: number
	if distance >= reachAt(0) then
		theta = 0
	elseif distance <= reachAt(MAX_BEND) then
		theta = MAX_BEND
	else
		local lo, hi = 0, MAX_BEND
		for _ = 1, ITERATIONS do
			local mid = (lo + hi) / 2
			if reachAt(mid) > distance then
				lo = mid
			else
				hi = mid
			end
		end
		theta = (lo + hi) / 2
	end
	local elbowT = CFrame.Angles(theta, 0, 0)

	-- 2. Épaule : oriente le bras vers la cible, puis tourne autour de cet axe pour que le
	-- coude pointe vers `pole`.
	local reached = arm.upperToElbow * elbowT * arm.lowerToWrist
	local direction = if distance > 1e-4 then target.Unit else reached.Unit
	local swing = rotationBetween(reached.Unit, direction)
	local elbowPosition = swing * arm.upperToElbow.Position
	local localPole = arm.shoulderC0:VectorToObjectSpace(pole)
	local e = elbowPosition - direction * elbowPosition:Dot(direction)
	local p = localPole - direction * localPole:Dot(direction)
	local twist = CFrame.identity
	if e.Magnitude > 1e-4 and p.Magnitude > 1e-4 then
		twist = CFrame.fromAxisAngle(direction, math.atan2(direction:Dot(e:Cross(p)), e:Dot(p)))
	end
	local shoulderT = twist * swing

	-- 3. Poignet : oriente la main exactement comme demandé.
	local lowerArm = arm.shoulderC0 * shoulderT * arm.upperToElbow * elbowT * arm.elbowC1Inv
	local wristFrame = lowerArm * arm.wristC0
	local wristT = (wristFrame:Inverse() * hand * arm.wristC1).Rotation
	return {
		shoulder = shoulderT,
		elbow = elbowT,
		wrist = wristT,
		hand = wristFrame * wristT * arm.wristC1Inv,
	}
end

return table.freeze(ArmIK)
