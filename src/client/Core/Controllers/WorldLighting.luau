--!strict
-- Éclairage du monde (Update 2.0, phases 3 et 4) : SEUL script qui règle Lighting (heure,
-- luminosité, ambiances, brume, bloom, correction des couleurs). L'heure vient du cycle de
-- 15 minutes (Shared/World/DayCycle) calculé sur l'horloge du serveur : tous les joueurs ont
-- la même heure, sans message réseau. Mise à jour 10 fois par seconde, transitions continues.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > WorldLighting
--
-- Les autres scripts lisent WorldLighting.night() (0 jour → 1 nuit) : DecorFx renforce torches,
-- lanternes et cristaux la nuit. GameFeel garde son propre effet de couleur (santé basse).
-- Test : workspace:SetAttribute("QA_ClockTime", 0 à 24) fige l'heure (Studio seulement).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayCycle = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("DayCycle")
) :: any

local WorldLighting = {}

local UPDATE_PERIOD = 0.1
local nightValue = 0
local clockValue = 12

local function rgb(c: { number }): Color3
	return Color3.new(c[1], c[2], c[3])
end

-- Effets d'ambiance : ceux de la place s'ils existent, sinon créés (Refuge).
local function effect(className: string, name: string): Instance
	for _, child in Lighting:GetChildren() do
		if child.ClassName == className and child.Name ~= "FractureLowHealth" then
			return child
		end
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = Lighting
	return made
end

local atmosphere: Atmosphere
local bloom: BloomEffect
local grade: ColorCorrectionEffect

local function currentTime(): number
	return workspace:GetServerTimeNow()
end

local function apply()
	local forced = if RunService:IsStudio() then workspace:GetAttribute("QA_ClockTime") else nil
	local clock = if typeof(forced) == "number" then forced % 24 else DayCycle.clock(currentTime())
	local look = DayCycle.sample(clock)
	clockValue = clock
	nightValue = look.night
	Lighting.ClockTime = clock
	Lighting.Brightness = look.brightness
	Lighting.ExposureCompensation = look.exposure
	Lighting.Ambient = rgb(look.ambient)
	Lighting.OutdoorAmbient = rgb(look.outdoor)
	Lighting.ColorShift_Top = rgb(look.shiftTop)
	atmosphere.Color = rgb(look.atmoColor)
	atmosphere.Decay = rgb(look.atmoDecay)
	atmosphere.Density = look.atmoDensity
	atmosphere.Haze = look.atmoHaze
	atmosphere.Glare = look.atmoGlare
	bloom.Intensity = look.bloom
	grade.TintColor = rgb(look.tint)
	grade.Contrast = look.contrast
	grade.Saturation = look.saturation
end

-- Part de nuit (0 jour → 1 nuit), pour les lumières du décor.
function WorldLighting.night(): number
	return nightValue
end

-- Heure affichée (0 à 24).
function WorldLighting.clock(): number
	return clockValue
end

function WorldLighting.start()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	atmosphere = effect("Atmosphere", "Atmosphere") :: Atmosphere
	bloom = effect("BloomEffect", "Bloom") :: BloomEffect
	bloom.Threshold = 1.1
	bloom.Size = 28
	grade = effect("ColorCorrectionEffect", "Couleurs") :: ColorCorrectionEffect
	apply()
	task.spawn(function()
		while true do
			task.wait(UPDATE_PERIOD)
			apply()
		end
	end)
end

return WorldLighting
