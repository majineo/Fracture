--!strict
-- Accès aux articulations d'un personnage R15, quel que soit le système de joints :
-- Motor6D (ancien) ou AnimationConstraint (nouveau système d'avatars Roblox).
-- Les deux exposent `Transform`, que l'Animator réécrit à chaque image.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > JointRig
--
-- Repère des articulations (vérifié visuellement en v0.3.1, personnage tourné vers -Z) :
--   rotation +X sur épaule / hanche = membre vers l'avant
--   rotation -X sur genou = jambe pliée ; +X sur coude = bras plié
--   rotation +X sur Waist / Root = buste penché en arrière
--   rotation +Z sur l'épaule droite = bras écarté vers l'extérieur (-Z pour la gauche)

export type Joint = Motor6D | AnimationConstraint

export type Rig = { [string]: Joint }

local JOINT_NAMES = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}

local JointRig = {}

JointRig.JOINT_NAMES = table.freeze(JOINT_NAMES)

-- Renvoie les articulations trouvées, ou nil si le personnage n'est pas un R15 complet.
function JointRig.find(character: Model): Rig?
	local wanted: { [string]: boolean } = {}
	for _, name in JOINT_NAMES do
		wanted[name] = true
	end
	local rig: Rig = {}
	local count = 0
	for _, descendant in character:GetDescendants() do
		if wanted[descendant.Name] and rig[descendant.Name] == nil then
			if descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") then
				rig[descendant.Name] = descendant :: any
				count += 1
			end
		end
	end
	if count < #JOINT_NAMES then
		return nil
	end
	return rig
end

return table.freeze(JointRig)
