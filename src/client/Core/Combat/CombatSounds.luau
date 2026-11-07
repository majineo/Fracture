--!strict
-- Sons du combat. Comme Animation/SoundConfig : identifiants regroupés ici pour être
-- remplacés facilement. "rbxasset://" = sons intégrés à Roblox (toujours disponibles).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > CombatSounds
-- ⚠ Provisoires, choisis sans écoute : à valider à l'oreille.

local SoundService = game:GetService("SoundService")

local SOUNDS = table.freeze({
	PistolShot = { id = "rbxassetid://92011177452282", volume = 0.5 }, -- enregistrement original (Creator Store)
	Reload = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6 },
	DryFire = { id = "rbxasset://sounds/clickfast.wav", volume = 0.3 },
	Swing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.5 },
	HeavySwing = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.55 },
	Hit = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
	Kill = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6 },
	-- v0.4.3
	CrossbowShot = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.6 }, -- détente + corde (provisoire)
	Parry = { id = "rbxassetid://9116460378", volume = 0.55 }, -- « Manacles Metal Clangs » (ProSoundEffects)
	-- v0.4.4 (Échoués)
	EnemyWindup = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6 }, -- lame levée : avertissement
	EnemyShatter = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.6 },
})

local CombatSounds = {}

CombatSounds.IDS = SOUNDS

local templates: { [string]: Sound } = {}

local function template(name: string): Sound?
	local entry = SOUNDS[name]
	if entry == nil or entry.id == "" then
		return nil
	end
	local existing = templates[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = entry.id
	sound.Volume = entry.volume
	templates[name] = sound
	return sound
end

-- Son 2D (interface : touche confirmée, rechargement de son arme…).
function CombatSounds.play2D(name: string, pitch: number?)
	local base = template(name)
	if base == nil then
		return
	end
	local sound = base:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Son 3D placé à une position du monde (tirs des autres joueurs).
function CombatSounds.playAt(name: string, position: Vector3, pitch: number?): ()
	local base = template(name)
	if base == nil then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = base:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 300
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = anchor
	sound:Play()
	task.delay(4, function()
		anchor:Destroy()
	end)
end

return CombatSounds
