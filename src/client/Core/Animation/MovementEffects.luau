--!strict
-- Effets visuels et sonores liés au déplacement d'un personnage : poussière et son de
-- glissade, impact de réception, sons du grappin. Créés côté client pour chaque personnage
-- visible (aucun coût serveur). Les sons sont en 3D, attachés au personnage.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > MovementEffects

local SoundConfig = require(script.Parent.SoundConfig)

export type Effects = {
	setSliding: (enabled: boolean) -> (),
	landingImpact: (strength: number) -> (),
	grappleFire: () -> (),
	grappleLatch: () -> (),
	destroy: () -> (),
}

local DUST_COLOR = Color3.fromRGB(190, 195, 205)
local SOUND_MAX_DISTANCE = 120

local MovementEffects = {}

local function makeDust(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MovementDust"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(DUST_COLOR)
	emitter.LightInfluence = 1
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Rate = 45
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(70, 20)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.EmissionDirection = Enum.NormalId.Back
	return emitter
end

local function makeSound(parent: Instance, entry: { id: string, volume: number }): Sound?
	if entry.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.id
	sound.Volume = entry.volume
	sound.RollOffMaxDistance = SOUND_MAX_DISTANCE
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = parent
	return sound
end

function MovementEffects.new(root: BasePart, feetOffset: number): Effects
	local feet = Instance.new("Attachment")
	feet.Name = "FeetFX"
	feet.Position = Vector3.new(0, -feetOffset + 0.2, 0)
	feet.Parent = root

	local dust = makeDust()
	dust.Parent = feet

	local burst = makeDust()
	burst.Name = "LandingDust"
	burst.EmissionDirection = Enum.NormalId.Top
	burst.SpreadAngle = Vector2.new(180, 15)
	burst.Speed = NumberRange.new(4, 9)
	burst.Parent = feet

	local slideSound = makeSound(feet, SoundConfig.Slide)
	local landSound = makeSound(feet, SoundConfig.Land)
	local fireSound = makeSound(feet, SoundConfig.GrappleFire)
	local latchSound = makeSound(feet, SoundConfig.GrappleLatch)
	local sliding = false

	return {
		setSliding = function(enabled: boolean)
			dust.Enabled = enabled
			if enabled and not sliding and slideSound then
				slideSound.TimePosition = 0
				slideSound:Play()
			elseif not enabled and sliding and slideSound then
				slideSound:Stop()
			end
			sliding = enabled
		end,
		landingImpact = function(strength: number)
			local s = math.clamp(strength, 0, 1)
			burst:Emit(math.floor(6 + 18 * s))
			if landSound then
				landSound.Volume = SoundConfig.Land.volume * (0.4 + 0.6 * s)
				landSound.PlaybackSpeed = 1.1 - 0.2 * s
				landSound:Play()
			end
		end,
		grappleFire = function()
			if fireSound then
				fireSound:Play()
			end
		end,
		grappleLatch = function()
			if latchSound then
				latchSound:Play()
			end
		end,
		destroy = function()
			feet:Destroy()
		end,
	}
end

return table.freeze(MovementEffects)
