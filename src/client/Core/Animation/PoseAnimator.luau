--!strict
-- Mélange des poses procédurales par-dessus les animations Roblox d'un personnage.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > PoseAnimator
--
-- Chaque couche a une pose et un poids (0 à 1) qui évolue par ressort, donc les transitions
-- sont toujours fluides. Deux types de couches :
--   « override » : remplace progressivement l'animation de base (glissade, chute…)
--   « additive » : s'ajoute à l'animation de base (inclinaison du sprint)
-- Les couches sont appliquées dans l'ordre de leur déclaration.
--
-- À appeler chaque image APRÈS l'Animator (RunService.Stepped) : `animator.step(dt)`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spring = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Spring")
) :: any
local JointRig = require(script.Parent.JointRig)

type Pose = { [string]: CFrame }

type Layer = {
	name: string,
	pose: Pose,
	additive: boolean,
	weight: any, -- Spring
}

export type PoseAnimator = {
	addLayer: (name: string, pose: Pose, additive: boolean, speed: number) -> (),
	setWeight: (name: string, target: number) -> (),
	setPose: (name: string, pose: Pose) -> (),
	snapWeight: (name: string, value: number) -> (),
	impulse: (name: string, velocity: number) -> (),
	getWeight: (name: string) -> number,
	step: (dt: number) -> (),
	destroy: () -> (),
}

local EPSILON = 1e-3
local IDENTITY = CFrame.new()

local PoseAnimator = {}

function PoseAnimator.new(rig: JointRig.Rig): PoseAnimator
	local layers: { Layer } = {}
	local byName: { [string]: Layer } = {}
	-- Pour ne pas cumuler nos modifications si l'Animator n'a pas réécrit une articulation.
	local lastWritten: { [any]: CFrame } = {}
	local lastBase: { [any]: CFrame } = {}
	local alive = true

	local function addLayer(name: string, pose: Pose, additive: boolean, speed: number)
		local layer: Layer =
			{ name = name, pose = pose, additive = additive, weight = Spring.new(0, speed) }
		table.insert(layers, layer)
		byName[name] = layer
	end

	local function setWeight(name: string, target: number)
		local layer = byName[name]
		if layer then
			layer.weight.target = math.clamp(target, 0, 1)
		end
	end

	local function setPose(name: string, pose: Pose)
		local layer = byName[name]
		if layer then
			layer.pose = pose
		end
	end

	local function snapWeight(name: string, value: number)
		local layer = byName[name]
		if layer then
			Spring.snap(layer.weight, value)
		end
	end

	local function impulse(name: string, velocity: number)
		local layer = byName[name]
		if layer then
			Spring.impulse(layer.weight, velocity)
		end
	end

	local function getWeight(name: string): number
		local layer = byName[name]
		return if layer then math.clamp(layer.weight.position, 0, 1) else 0
	end

	local function step(dt: number)
		if not alive then
			return
		end
		local active = false
		for _, layer in layers do
			Spring.step(layer.weight, dt)
			if layer.weight.position > EPSILON then
				active = true
			end
		end

		for jointName, joint in rig do
			local current = joint.Transform
			if lastWritten[joint] ~= nil and current == lastWritten[joint] then
				-- L'Animator n'a pas touché cette articulation : on repart de la base d'origine.
				current = lastBase[joint]
			end
			lastBase[joint] = current

			if not active then
				lastWritten[joint] = nil
				continue
			end

			local result = current
			for _, layer in layers do
				local w = math.clamp(layer.weight.position, 0, 1)
				local target = layer.pose[jointName]
				if w > EPSILON and target ~= nil then
					if layer.additive then
						result = result * IDENTITY:Lerp(target, w)
					else
						result = result:Lerp(target, w)
					end
				end
			end
			joint.Transform = result
			lastWritten[joint] = result
		end
	end

	local function destroy()
		alive = false
		table.clear(layers)
		table.clear(byName)
	end

	return {
		addLayer = addLayer,
		setWeight = setWeight,
		setPose = setPose,
		snapWeight = snapWeight,
		impulse = impulse,
		getWeight = getWeight,
		step = step,
		destroy = destroy,
	}
end

return table.freeze(PoseAnimator)
