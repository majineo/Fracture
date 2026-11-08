--!strict
-- Thème visuel unique de Fracture (v0.9.0) : toutes les fenêtres, boutons, emplacements et
-- messages se construisent ici, pour que le Refuge et l'Éclat aient exactement le même style.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Ui > Theme
--
-- Direction : steampunk / arcane. Encre sombre (fond), laiton (cadres, rivets), cuivre (titres),
-- parchemin (texte), néon cyan des Éclats (accent, sélection), violet (reliques, Codex).

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.INK = Color3.fromRGB(18, 16, 22)
Theme.INK_LIGHT = Color3.fromRGB(34, 30, 38)
Theme.BRASS = Color3.fromRGB(196, 150, 78)
Theme.BRASS_DARK = Color3.fromRGB(112, 82, 44)
Theme.COPPER = Color3.fromRGB(214, 128, 74)
Theme.PARCHMENT = Color3.fromRGB(238, 226, 200)
Theme.MUTED = Color3.fromRGB(150, 140, 126)
Theme.ARCANE = Color3.fromRGB(80, 230, 255)
Theme.VIOLET = Color3.fromRGB(190, 120, 255)
Theme.DANGER = Color3.fromRGB(255, 120, 70)
Theme.HEAL = Color3.fromRGB(120, 230, 140)

Theme.TITLE_FONT = Enum.Font.Bodoni
Theme.BODY_FONT = Enum.Font.SourceSansSemibold
Theme.BOLD_FONT = Enum.Font.SourceSansBold

-- Arrondis et bordures communs.
function Theme.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.BRASS
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.label(
	parent: Instance,
	text: string,
	size: number,
	color: Color3?,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Theme.BODY_FONT
	l.TextSize = size
	l.TextColor3 = color or Theme.PARCHMENT
	l.Text = text
	l.Parent = parent
	return l
end

-- Rivets de laiton aux quatre coins d'un cadre.
local function rivets(frame: Frame)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local r = Instance.new("Frame")
		r.Name = "Rivet"
		r.AnchorPoint = corner
		r.Position = UDim2.new(
			corner.X,
			if corner.X == 0 then 5 else -5,
			corner.Y,
			if corner.Y == 0 then 5 else -5
		)
		r.Size = UDim2.fromOffset(6, 6)
		r.BackgroundColor3 = Theme.BRASS
		r.BorderSizePixel = 0
		r.ZIndex = 3
		Theme.corner(r, 3)
		r.Parent = frame
	end
end

-- Panneau encre + cadre de laiton + rivets. `title` facultatif (bandeau en haut).
function Theme.panel(parent: Instance, title: string?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.INK
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	Theme.corner(f, 6)
	Theme.stroke(f, Theme.BRASS, 2)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Theme.INK_LIGHT, Theme.INK)
	g.Rotation = 90
	g.Parent = f
	rivets(f)
	if title then
		local t = Theme.label(f, string.upper(title), 24, Theme.BRASS, Theme.TITLE_FONT)
		t.Name = "Titre"
		t.Position = UDim2.fromOffset(0, 10)
		t.Size = UDim2.new(1, 0, 0, 30)
		local line = Instance.new("Frame")
		line.Name = "Filet"
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, 44)
		line.Size = UDim2.new(1, -40, 0, 1)
		line.BackgroundColor3 = Theme.BRASS_DARK
		line.BorderSizePixel = 0
		line.Parent = f
	end
	f.Parent = parent
	return f
end

export type ButtonKind = "Brass" | "Arcane" | "Violet" | "Muted" | "Danger"

local BUTTON_COLORS: { [ButtonKind]: Color3 } = {
	Brass = Theme.BRASS,
	Arcane = Theme.ARCANE,
	Violet = Theme.VIOLET,
	Muted = Theme.MUTED,
	Danger = Theme.DANGER,
}

-- Bouton : fond encre, cadre et texte de la couleur du type ; s'illumine au survol.
function Theme.button(
	parent: Instance,
	text: string,
	kind: ButtonKind?,
	onClick: (() -> ())?
): TextButton
	local color = BUTTON_COLORS[kind or "Brass"]
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.INK_LIGHT
	b.BackgroundTransparency = 0.1
	b.Font = Theme.BOLD_FONT
	b.TextSize = 17
	b.TextColor3 = color
	b.Text = text
	b.Size = UDim2.fromOffset(140, 34)
	Theme.corner(b, 4)
	Theme.stroke(b, color, 1.5)
	local info = TweenInfo.new(0.12)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, info, { BackgroundColor3 = color, TextColor3 = Theme.INK }):Play()
	end)
	b.MouseLeave:Connect(function()
		-- « Accent » : couleur imposée (onglet sélectionné), sinon celle du type de bouton.
		local accent = b:GetAttribute("Accent")
		local rest = if typeof(accent) == "Color3" then accent else color
		TweenService:Create(b, info, { BackgroundColor3 = Theme.INK_LIGHT, TextColor3 = rest })
			:Play()
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

export type Slot = {
	frame: Frame,
	button: TextButton,
	set: (id: string?, qty: number?, name: string?, color: Color3?) -> (),
	select: (on: boolean) -> (),
}

-- Emplacement d'objet carré (sac, coffre, barre) : nom abrégé, quantité, liseré de rareté.
function Theme.slot(parent: Instance, size: number): Slot
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = Theme.INK
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	Theme.corner(f, 4)
	local stroke = Theme.stroke(f, Theme.BRASS_DARK, 1.5)
	local name =
		Theme.label(f, "", math.max(11, math.floor(size / 4.2)), Theme.PARCHMENT, Theme.BOLD_FONT)
	name.Name = "Nom"
	name.Position = UDim2.fromOffset(2, 2)
	name.Size = UDim2.new(1, -4, 0.6, 0)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	local qty =
		Theme.label(f, "", math.max(11, math.floor(size / 3.6)), Theme.PARCHMENT, Theme.BOLD_FONT)
	qty.Name = "Qte"
	qty.AnchorPoint = Vector2.new(1, 1)
	qty.Position = UDim2.new(1, -3, 1, -1)
	qty.Size = UDim2.new(1, -6, 0, size / 3)
	qty.TextXAlignment = Enum.TextXAlignment.Right
	local button = Instance.new("TextButton")
	button.Name = "Toucher"
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 4
	button.Parent = f
	local filled = false
	local selected = false
	local rarity = Theme.BRASS_DARK
	local function paint()
		stroke.Color = if selected then Theme.ARCANE else rarity
		stroke.Thickness = if selected then 2.5 else 1.5
		f.BackgroundTransparency = if filled then 0.1 else 0.35
	end
	local slot: Slot = {
		frame = f,
		button = button,
		set = function(id: string?, q: number?, n: string?, color: Color3?)
			filled = id ~= nil
			name.Text = if filled then (n or id or "") else ""
			name.TextColor3 = color or Theme.PARCHMENT
			qty.Text = if filled and q and q > 1 then tostring(q) else ""
			rarity = if filled then (color or Theme.BRASS) else Theme.BRASS_DARK
			paint()
		end,
		select = function(on: boolean)
			selected = on
			paint()
		end,
	}
	button.MouseEnter:Connect(function()
		if not selected then
			stroke.Color = Theme.BRASS
		end
	end)
	button.MouseLeave:Connect(paint)
	f.Parent = parent
	return slot
end

-- Barre de progression fine (jauges d'extraction, de soin, vie du Gardien…).
function Theme.bar(parent: Instance, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Theme.INK
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	Theme.corner(back, 3)
	Theme.stroke(back, Theme.BRASS_DARK, 1)
	local fill = Instance.new("Frame")
	fill.Name = "Remplissage"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Theme.corner(fill, 3)
	fill.Parent = back
	back.Parent = parent
	return back, fill
end

return Theme
