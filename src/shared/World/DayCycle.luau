--!strict
-- Cycle jour / nuit (Update 2.0, phase 4) : 15 minutes, dont 10 de jour et 5 de nuit. Module
-- pur : l'heure est calculée à partir de l'horloge du SERVEUR (workspace:GetServerTimeNow()),
-- donc tous les joueurs voient la même heure sans aucun message réseau. Le client
-- (Controllers/WorldLighting) applique l'éclairage ; c'est le seul script qui règle Lighting.
-- Testé par tests/specs/DayCycle.spec.luau.
-- Studio : ReplicatedStorage > Shared > World > DayCycle

local DayCycle = {}

DayCycle.CONFIG = table.freeze({
	DAY_SECONDS = 600, -- lever (6 h) → coucher (18 h)
	NIGHT_SECONDS = 300, -- coucher (18 h) → lever (6 h)
	SUNRISE = 6,
	SUNSET = 18,
	OFFSET = 120, -- décalage (s) : une partie commence rarement en pleine nuit
})

local C = DayCycle.CONFIG

function DayCycle.length(): number
	return C.DAY_SECONDS + C.NIGHT_SECONDS
end

-- Heure (Lighting.ClockTime, 0 à 24) à l'instant serveur `t`.
function DayCycle.clock(t: number): number
	local u = (t + C.OFFSET) % DayCycle.length()
	if u < C.DAY_SECONDS then
		return C.SUNRISE + (C.SUNSET - C.SUNRISE) * u / C.DAY_SECONDS
	end
	local night = (u - C.DAY_SECONDS) / C.NIGHT_SECONDS
	return (C.SUNSET + (24 - C.SUNSET + C.SUNRISE) * night) % 24
end

-- Fait-il jour à l'instant `t` ?
function DayCycle.isDay(t: number): boolean
	return (t + C.OFFSET) % DayCycle.length() < C.DAY_SECONDS
end

type Rgb = { number }
export type Look = {
	brightness: number,
	exposure: number,
	ambient: Rgb,
	outdoor: Rgb,
	shiftTop: Rgb, -- teinte de la lumière directe (soleil / lune)
	atmoColor: Rgb,
	atmoDecay: Rgb,
	atmoDensity: number,
	atmoHaze: number,
	atmoGlare: number,
	bloom: number,
	tint: Rgb,
	contrast: number,
	saturation: number,
	night: number, -- 0 jour → 1 nuit (lumières et cristaux plus présents la nuit)
}

-- Images clés par heure (0 à 24 ; la dernière reboucle sur la première).
local KEYS: { { hour: number, look: Look } } = {
	{
		hour = 0,
		look = { -- minuit : clair de lune bleuté, jamais noir
			brightness = 1.3,
			exposure = 0.55,
			ambient = { 0.3, 0.34, 0.46 },
			outdoor = { 0.4, 0.46, 0.62 },
			shiftTop = { 0.55, 0.65, 0.95 },
			atmoColor = { 0.3, 0.38, 0.52 },
			atmoDecay = { 0.2, 0.26, 0.4 },
			atmoDensity = 0.3,
			atmoHaze = 1.0,
			atmoGlare = 0,
			bloom = 1.05,
			tint = { 0.86, 0.92, 1 },
			contrast = 0.14,
			saturation = -0.05,
			night = 1,
		},
	},
	{
		hour = 5.4,
		look = { -- avant l'aube
			brightness = 1.3,
			exposure = 0.45,
			ambient = { 0.3, 0.33, 0.43 },
			outdoor = { 0.42, 0.46, 0.58 },
			shiftTop = { 0.6, 0.65, 0.9 },
			atmoColor = { 0.27, 0.32, 0.42 },
			atmoDecay = { 0.2, 0.2, 0.3 },
			atmoDensity = 0.38,
			atmoHaze = 1.8,
			atmoGlare = 0.1,
			bloom = 1.0,
			tint = { 0.9, 0.93, 1 },
			contrast = 0.13,
			saturation = -0.03,
			night = 0.9,
		},
	},
	{
		hour = 6.5,
		look = { -- lever : rose orangé
			brightness = 1.6,
			exposure = 0,
			ambient = { 0.24, 0.22, 0.24 },
			outdoor = { 0.48, 0.42, 0.42 },
			shiftTop = { 1, 0.66, 0.42 },
			atmoColor = { 0.78, 0.6, 0.55 },
			atmoDecay = { 0.55, 0.38, 0.36 },
			atmoDensity = 0.36,
			atmoHaze = 1.9,
			atmoGlare = 0.5,
			bloom = 0.8,
			tint = { 1, 0.95, 0.9 },
			contrast = 0.1,
			saturation = 0.05,
			night = 0.25,
		},
	},
	{
		hour = 8.5,
		look = { -- matin
			brightness = 2.3,
			exposure = 0,
			ambient = { 0.26, 0.27, 0.3 },
			outdoor = { 0.52, 0.54, 0.58 },
			shiftTop = { 1, 0.92, 0.8 },
			atmoColor = { 0.72, 0.8, 0.9 },
			atmoDecay = { 0.42, 0.52, 0.68 },
			atmoDensity = 0.32,
			atmoHaze = 1.3,
			atmoGlare = 0.3,
			bloom = 0.6,
			tint = { 1, 0.99, 0.96 },
			contrast = 0.08,
			saturation = 0.08,
			night = 0,
		},
	},
	{
		hour = 13,
		look = { -- plein jour : ciel bleu, soleil franc mais maîtrisé
			brightness = 2.7,
			exposure = -0.1,
			ambient = { 0.28, 0.29, 0.32 },
			outdoor = { 0.55, 0.57, 0.62 },
			shiftTop = { 1, 0.97, 0.9 },
			atmoColor = { 0.74, 0.83, 0.94 },
			atmoDecay = { 0.44, 0.55, 0.72 },
			atmoDensity = 0.3,
			atmoHaze = 1.1,
			atmoGlare = 0.25,
			bloom = 0.5,
			tint = { 1, 1, 0.98 },
			contrast = 0.08,
			saturation = 0.1,
			night = 0,
		},
	},
	{
		hour = 16.3,
		look = { -- fin d'après-midi : lumière chaude
			brightness = 2.2,
			exposure = -0.05,
			ambient = { 0.27, 0.26, 0.27 },
			outdoor = { 0.54, 0.5, 0.48 },
			shiftTop = { 1, 0.82, 0.6 },
			atmoColor = { 0.78, 0.74, 0.74 },
			atmoDecay = { 0.5, 0.46, 0.5 },
			atmoDensity = 0.33,
			atmoHaze = 1.5,
			atmoGlare = 0.45,
			bloom = 0.65,
			tint = { 1, 0.97, 0.92 },
			contrast = 0.1,
			saturation = 0.08,
			night = 0,
		},
	},
	{
		hour = 17.7,
		look = { -- coucher : orange profond
			brightness = 1.4,
			exposure = -0.05,
			ambient = { 0.24, 0.2, 0.21 },
			outdoor = { 0.46, 0.36, 0.34 },
			shiftTop = { 1, 0.55, 0.3 },
			atmoColor = { 0.82, 0.55, 0.45 },
			atmoDecay = { 0.5, 0.3, 0.3 },
			atmoDensity = 0.37,
			atmoHaze = 2.0,
			atmoGlare = 0.7,
			bloom = 0.85,
			tint = { 1, 0.93, 0.86 },
			contrast = 0.12,
			saturation = 0.06,
			night = 0.3,
		},
	},
	{
		hour = 18.8,
		look = { -- crépuscule teal (l'ambiance de la v0.12)
			brightness = 1.0,
			exposure = 0,
			ambient = { 0.15, 0.18, 0.2 },
			outdoor = { 0.36, 0.44, 0.48 },
			shiftTop = { 0.7, 0.8, 0.95 },
			atmoColor = { 0.4, 0.56, 0.62 },
			atmoDecay = { 0.2, 0.3, 0.38 },
			atmoDensity = 0.38,
			atmoHaze = 2.0,
			atmoGlare = 0.2,
			bloom = 0.95,
			tint = { 0.92, 0.98, 1 },
			contrast = 0.12,
			saturation = 0,
			night = 0.75,
		},
	},
	{
		hour = 20.5,
		look = { -- nuit
			brightness = 1.3,
			exposure = 0.55,
			ambient = { 0.3, 0.34, 0.46 },
			outdoor = { 0.4, 0.46, 0.62 },
			shiftTop = { 0.55, 0.65, 0.95 },
			atmoColor = { 0.3, 0.38, 0.52 },
			atmoDecay = { 0.2, 0.26, 0.4 },
			atmoDensity = 0.3,
			atmoHaze = 1.0,
			atmoGlare = 0,
			bloom = 1.05,
			tint = { 0.86, 0.92, 1 },
			contrast = 0.14,
			saturation = -0.05,
			night = 1,
		},
	},
}

local NUMBERS = {
	"brightness",
	"exposure",
	"atmoDensity",
	"atmoHaze",
	"atmoGlare",
	"bloom",
	"contrast",
	"saturation",
	"night",
}
local COLORS = { "ambient", "outdoor", "shiftTop", "atmoColor", "atmoDecay", "tint" }

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- Éclairage à l'heure `clock` (0 à 24), interpolé en douceur entre les images clés.
function DayCycle.sample(clock: number): Look
	local h = clock % 24
	local a, b = KEYS[#KEYS], KEYS[1]
	local span, into
	for i = 1, #KEYS do
		local nextKey = KEYS[i + 1] or KEYS[1]
		local nextHour = if KEYS[i + 1] then nextKey.hour else nextKey.hour + 24
		if h >= KEYS[i].hour and h < nextHour then
			a, b = KEYS[i], nextKey
			span = nextHour - KEYS[i].hour
			into = h - KEYS[i].hour
			break
		end
	end
	if span == nil then
		-- avant la première clé (ne se produit pas : la première est à 0 h)
		a, b = KEYS[#KEYS], KEYS[1]
		span = 24 - a.hour + b.hour
		into = h + 24 - a.hour
	end
	local k = smooth(math.clamp(into / span, 0, 1))
	local out: any = {}
	for _, name in NUMBERS do
		out[name] = (a.look :: any)[name] + ((b.look :: any)[name] - (a.look :: any)[name]) * k
	end
	for _, name in COLORS do
		local ca, cb = (a.look :: any)[name], (b.look :: any)[name]
		out[name] = {
			ca[1] + (cb[1] - ca[1]) * k,
			ca[2] + (cb[2] - ca[2]) * k,
			ca[3] + (cb[3] - ca[3]) * k,
		}
	end
	return out :: Look
end

-- Part de « nuit » à l'instant serveur `t` (0 jour → 1 nuit).
function DayCycle.nightFactor(t: number): number
	return DayCycle.sample(DayCycle.clock(t)).night
end

return DayCycle
