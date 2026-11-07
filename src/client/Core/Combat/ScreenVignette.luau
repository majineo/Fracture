--!strict
-- Vignette d'écran colorée (dégâts, santé basse, soin), v0.4.9.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > ScreenVignette
--
-- Avec la texture « Vignette » importée (dessinée dans Blender) : dégradé radial plein écran.
-- Sinon : quatre bords en dégradé (opaques au bord de l'écran, transparents vers le centre).
-- (Avant v0.4.9, un UIStroke sur un cadre plein écran se dessinait hors de l'écran.)

local VfxTextures = require(script.Parent.VfxTextures)

export type Vignette = {
	set: (intensity: number) -> (),
	setColor: (color: Color3) -> (),
}

local ScreenVignette = {}

-- `depth` : profondeur des bords, en part de l'écran (0,15 = 15 %).
function ScreenVignette.new(parent: Instance, color: Color3, depth: number): Vignette
	if VfxTextures.isImported("Vignette") then
		local image = Instance.new("ImageLabel")
		image.Name = "Vignette"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = VfxTextures.get("Vignette")
		image.ImageColor3 = color
		image.ImageTransparency = 1
		image.Parent = parent
		return {
			set = function(intensity: number)
				image.ImageTransparency = 1 - math.clamp(intensity, 0, 1)
			end,
			setColor = function(c: Color3)
				image.ImageColor3 = c
			end,
		}
	end
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	-- (position, taille, rotation du dégradé : 0 = de gauche à droite)
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, depth), 90 }, -- haut
		{ UDim2.fromScale(0, 1 - depth), UDim2.fromScale(1, depth), -90 }, -- bas
		{ UDim2.fromScale(0, 0), UDim2.fromScale(depth * 0.6, 1), 0 }, -- gauche
		{ UDim2.fromScale(1 - depth * 0.6, 0), UDim2.fromScale(depth * 0.6, 1), 180 }, -- droite
	}
	local frames: { Frame } = {}
	for _, side in sides do
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 1
		frame.Position = side[1]
		frame.Size = side[2]
		frame.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side[3]
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		table.insert(frames, frame)
	end
	return {
		set = function(intensity: number)
			local t = 1 - math.clamp(intensity, 0, 1)
			for _, frame in frames do
				frame.BackgroundTransparency = t
			end
		end,
		setColor = function(c: Color3)
			for _, frame in frames do
				frame.BackgroundColor3 = c
			end
		end,
	}
end

return table.freeze(ScreenVignette)
