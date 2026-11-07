--!strict
-- Sons du combat. Comme Animation/SoundConfig : identifiants regroupés ici pour être
-- remplacés facilement. "rbxasset://" = sons intégrés à Roblox (toujours disponibles).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > CombatSounds
--
-- Chaque entrée : id, volume, et `maxTime` (facultatif) : le son est coupé en fondu après
-- ce nombre de secondes (pour les enregistrements trop longs).
-- ⚠ Choisis sans écoute (Creator Store, gratuits) : à valider à l'oreille. Pour en changer,
-- chercher dans la Boîte à outils de Studio (onglet Audio) et coller l'identifiant ici.
-- On évite les sons copiés de jeux commerciaux (droits d'auteur).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

type Entry = { id: string, volume: number, maxTime: number? }

local SOUNDS: { [string]: Entry } = table.freeze({
	-- Tirs ------------------------------------------------------------------------------
	PistolShot = { id = "rbxassetid://92011177452282", volume = 0.5 }, -- enregistrement original
	RifleShot = { id = "rbxassetid://6975483207", volume = 0.55 }, -- « Rifle Gunshot .50 Beowulf » (Siydge)
	SniperShot = { id = "rbxassetid://7700083911", volume = 0.7, maxTime = 2.4 }, -- « Bolt Action Fire » (libre)
	CrossbowShot = { id = "rbxassetid://9113166206", volume = 0.65, maxTime = 1.1 }, -- « Arrow Out » (ProSoundEffects)
	-- Mécanismes après le tir
	RifleLever = { id = "rbxassetid://6129190959", volume = 0.45 }, -- « Lever Action bolt sound »
	SniperBoltBack = { id = "rbxassetid://93265832279166", volume = 0.5 }, -- « Pull Action Bolt Back »
	SniperBoltForward = { id = "rbxassetid://133390161654321", volume = 0.5 }, -- « Pull Action Bolt Forward »
	-- Impacts et balles qui frôlent
	BulletImpact = { id = "rbxassetid://79671891898982", volume = 0.45 }, -- « Bullet Impact Concrete 01 »
	CrossbowImpact = { id = "rbxassetid://9113998001", volume = 0.6 }, -- « Crossbow Bolts Impact » (ProSoundEffects)
	BulletWhiz = { id = "rbxassetid://4874206222", volume = 0.55, maxTime = 1.1 }, -- « Supersonic Bullet Miss »
	-- Rechargements
	Reload = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6 }, -- générique
	PistolReload = { id = "rbxassetid://8302576808", volume = 0.55 }, -- « Pistol Reload Sound »
	RifleReload = { id = "rbxassetid://99473608044731", volume = 0.6 }, -- « Bullet Load Bolt Action »
	CrossbowReload = { id = "rbxassetid://9125656958", volume = 0.6 }, -- mécanisme en bois (ProSoundEffects)
	DryFire = { id = "rbxasset://sounds/clickfast.wav", volume = 0.3 },
	-- Dégainer / ranger
	Equip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.35 }, -- générique
	DrawGun = { id = "rbxassetid://7405483764", volume = 0.5 }, -- « Gun equip »
	DrawRifle = { id = "rbxassetid://9117889191", volume = 0.45, maxTime = 0.9 }, -- armement (ProSoundEffects)
	DrawCrossbow = { id = "rbxassetid://9125656958", volume = 0.5, maxTime = 0.7 }, -- mécanisme en bois
	DrawBlade = { id = "rbxassetid://9119744718", volume = 0.55 }, -- « Sword Draw » court (ProSoundEffects)
	DrawSword = { id = "rbxassetid://9119742466", volume = 0.6 }, -- « Sword Draw Clang » (ProSoundEffects)
	Holster = { id = "rbxassetid://7405483764", volume = 0.25 },
	-- Mêlée
	Swing = { id = "rbxassetid://5789211405", volume = 0.5 }, -- « sword swing fast whoosh blade ring »
	HeavySwing = { id = "rbxassetid://130317074796316", volume = 0.6, maxTime = 0.9 }, -- « Katana Slash Wind 7 »
	MeleeHit = { id = "rbxassetid://138293953015099", volume = 0.6 }, -- « SFX_Hit_Sword_Medium_01 »
	MeleeHitHeavy = { id = "rbxassetid://84636875169658", volume = 0.7 }, -- « Heavy Sword Hit 1 »
	Parry = { id = "rbxassetid://9116460378", volume = 0.55 }, -- « Manacles Metal Clangs » (ProSoundEffects)
	-- Retours de touche
	Hit = { id = "rbxassetid://133749572213659", volume = 0.45 }, -- « Hit Marker sound effect »
	Headshot = { id = "rbxassetid://118799613600209", volume = 0.5, maxTime = 0.9 }, -- « Headshot Ding »
	Kill = { id = "rbxassetid://1837950656", volume = 0.5, maxTime = 2.2 }, -- « Brute Force Sting 3 » (APM Music)
	Hurt = { id = "rbxassetid://127713737439439", volume = 0.6 }, -- « sfx_hit_body03 »
	-- Mort
	Death = { id = "rbxassetid://1845714598", volume = 0.55, maxTime = 4 }, -- « Fatal Thoughts K » (APM Music)
	BodyFall = { id = "rbxassetid://9113476945", volume = 0.6, maxTime = 1.6 }, -- « Body Fall » (ProSoundEffects)
	-- Échoués (v0.4.4)
	EnemyWindup = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6 }, -- lame levée : avertissement
	EnemyShatter = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.6 },
	-- Capacités (v0.4.5)
	AbilityRewind = { id = "rbxassetid://134583958662340", volume = 0.6 }, -- « Potion Summon »
	AbilityShadow = { id = "rbxassetid://88724017134214", volume = 0.7 }, -- « SuddenMovement »
	AbilityReady = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4 },
	ShadowWarning = { id = "rbxasset://sounds/unsheath.wav", volume = 0.8 },
	-- Mobilité et ambiance
	Dash = { id = "rbxassetid://120777847710409", volume = 0.55 }, -- « momentum dash whoosh »
	Heartbeat = { id = "rbxassetid://176554627", volume = 0.6 }, -- « Slow Heartbeat » (en boucle)
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

-- Coupe le son en fondu après `maxTime` secondes (durée réelle, vitesse de lecture comprise),
-- puis détruit `owner` (le son lui-même, ou son attache 3D).
local function schedule(name: string, sound: Sound, owner: Instance, maxTime: number?)
	local limit = maxTime or SOUNDS[name].maxTime
	local life = 6
	if limit then
		local fadeAt = math.max(0, limit / math.max(sound.PlaybackSpeed, 0.1) - 0.15)
		task.delay(fadeAt, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0 }):Play()
			end
		end)
		life = fadeAt + 0.2
	end
	task.delay(life, function()
		if owner.Parent then
			owner:Destroy()
		end
	end)
end

-- Son 2D (le sien : tir, rechargement, retour de touche…). Renvoie le son pour pouvoir
-- l'arrêter (rechargement interrompu). `maxTime` remplace celui de l'entrée.
function CombatSounds.play2D(name: string, pitch: number?, maxTime: number?): Sound?
	local base = template(name)
	if base == nil then
		return nil
	end
	local sound = base:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	schedule(name, sound, sound, maxTime)
	return sound
end

-- Son 3D placé à une position du monde (tirs des autres joueurs, impacts…).
function CombatSounds.playAt(
	name: string,
	position: Vector3,
	pitch: number?,
	volumeScale: number?
): ()
	local base = template(name)
	if base == nil then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = base:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Volume *= volumeScale or 1
	sound.RollOffMaxDistance = 300
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = anchor
	sound:Play()
	schedule(name, sound, anchor, nil)
end

-- Arrête un son lancé par play2D (fondu court).
function CombatSounds.stop(sound: Sound?)
	if sound and sound.Parent then
		TweenService:Create(sound, TweenInfo.new(0.1), { Volume = 0 }):Play()
		task.delay(0.12, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
end

return CombatSounds
