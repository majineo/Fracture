--!strict
-- Effets visuels et sonores liés au déplacement d'un personnage. Créés côté client pour
-- chaque personnage visible (aucun coût serveur). Les sons sont en 3D, attachés au personnage.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Animation > MovementEffects
--
-- Glissade (couleur adaptée au sol sous le joueur) :
--   * nuage de poussière continu, plus dense au début de la glissade ;
--   * petits débris (graviers) projetés vers l'arrière, retombant avec la gravité ;
--   * traînée de frottement au sol ;
--   * bouffée de poussière au démarrage.
-- Réception : anneau de poussière proportionnel à la hauteur de chute.

local SoundConfig = require(script.Parent.SoundConfig)

export type Effects = {
	setSliding: (enabled: boolean, groundColor: Color3?) -> (),
	landingImpact: (strength: number, groundColor: Color3?) -> (),
	grappleFire: () -> (),
	grappleLatch: () -> (),
	destroy: () -> (),
}

local DEFAULT_DUST = Color3.fromRGB(190, 195, 205)
local SOUND_MAX_DISTANCE = 120
local DUST_RATE = 80
local DEBRIS_RATE = 30
local START_BURST = 22

local MovementEffects = {}

-- Teinte de poussière : couleur du sol éclaircie (la poussière est toujours plus claire).
local function dustColor(ground: Color3?): Color3
	if ground == nil then
		return DEFAULT_DUST
	end
	return ground:Lerp(Color3.new(1, 1, 1), 0.45)
end

local function makeDust(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SlideDust"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(DEFAULT_DUST)
	emitter.LightInfluence = 0.8
	emitter.LightEmission = 0.05
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = DUST_RATE
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(60, 25)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Drag = 3.5
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.4, 1.6),
		NumberSequenceKeypoint.new(1, 2.6),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.EmissionDirection = Enum.NormalId.Back
	return emitter
end

local function makeDebris(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SlideDebris"
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(DEFAULT_DUST)
	emitter.LightInfluence = 1
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Rate = DEBRIS_RATE
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(35, 40)
	emitter.Acceleration = Vector3.new(0, -70, 0) -- retombent comme des graviers
	emitter.Drag = 1
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
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
	local feetY = -feetOffset + 0.2

	local feet = Instance.new("Attachment")
	feet.Name = "FeetFX"
	feet.Position = Vector3.new(0, feetY, 0.6)
	feet.Parent = root

	-- Traînée de frottement : ruban entre deux points au ras du sol.
	local trailLeft = Instance.new("Attachment")
	trailLeft.Name = "SlideTrailL"
	trailLeft.Position = Vector3.new(-0.7, feetY - 0.1, 0.8)
	trailLeft.Parent = root
	local trailRight = Instance.new("Attachment")
	trailRight.Name = "SlideTrailR"
	trailRight.Position = Vector3.new(0.7, feetY - 0.1, 0.8)
	trailRight.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailLeft
	trail.Attachment1 = trailRight
	trail.Enabled = false
	trail.Lifetime = 0.45
	trail.MinLength = 0.1
	trail.FaceCamera = false
	trail.LightInfluence = 1
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = root

	local dust = makeDust()
	dust.Parent = feet
	local debris = makeDebris()
	debris.Parent = feet

	local burst = makeDust()
	burst.Name = "LandingDust"
	burst.EmissionDirection = Enum.NormalId.Top
	burst.SpreadAngle = Vector2.new(180, 10)
	burst.Speed = NumberRange.new(6, 12)
	burst.Parent = feet

	local slideSound = makeSound(feet, SoundConfig.Slide)
	local landSound = makeSound(feet, SoundConfig.Land)
	local fireSound = makeSound(feet, SoundConfig.GrappleFire)
	local latchSound = makeSound(feet, SoundConfig.GrappleLatch)
	local sliding = false

	local function tint(color: Color3)
		local sequence = ColorSequence.new(color)
		dust.Color = sequence
		debris.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.25))
		burst.Color = sequence
		trail.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.15))
	end

	return {
		setSliding = function(enabled: boolean, groundColor: Color3?)
			if enabled then
				tint(dustColor(groundColor))
			end
			dust.Enabled = enabled
			debris.Enabled = enabled
			trail.Enabled = enabled
			if enabled and not sliding then
				dust:Emit(START_BURST)
				if slideSound then
					slideSound.TimePosition = 0
					slideSound:Play()
				end
			elseif not enabled and sliding and slideSound then
				slideSound:Stop()
			end
			sliding = enabled
		end,
		landingImpact = function(strength: number, groundColor: Color3?)
			local s = math.clamp(strength, 0, 1)
			tint(dustColor(groundColor))
			burst:Emit(math.floor(8 + 26 * s))
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
			trailLeft:Destroy()
			trailRight:Destroy()
			trail:Destroy()
		end,
	}
end

return table.freeze(MovementEffects)
