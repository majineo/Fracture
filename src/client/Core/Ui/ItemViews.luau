--!strict
-- Vues d'objets partagées (v0.9.0) : grille d'emplacements, fiche détaillée, cartes et page
-- d'aide. Le sac de l'Éclat et le coffre du Refuge sont construits avec les mêmes briques.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Ui > ItemViews

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemDefs =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loot"):WaitForChild("ItemDefs"))
local Theme = require(script.Parent.Theme)

local ItemViews = {}

export type Entry = { id: string, qty: number }

function ItemViews.rarityColor(id: string): Color3
	local def = ItemDefs.get(id)
	local rgb = ItemDefs.RARITY_COLORS[def and def.rarity or "Commun"]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function ItemViews.name(id: string): string
	local def = ItemDefs.get(id)
	return if def then def.name else id
end

-- Découpe le contenu en deux colonnes : grille à gauche (largeur `leftWidth`), fiche à droite.
function ItemViews.split(content: Frame, leftWidth: number): (Frame, Frame)
	local left = Instance.new("Frame")
	left.Name = "Gauche"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0, leftWidth, 1, 0)
	left.Parent = content
	local right = Theme.panel(content)
	right.Name = "Fiche"
	right.BackgroundTransparency = 0.35
	right.Position = UDim2.fromOffset(leftWidth + 14, 0)
	right.Size = UDim2.new(1, -(leftWidth + 14), 1, 0)
	return left, right
end

-- Grille d'emplacements (défilante si besoin). `count` emplacements, remplis par `entries`.
function ItemViews.grid(
	parent: Frame,
	entries: { Entry },
	count: number,
	slotSize: number,
	selected: number?,
	onSelect: (index: number) -> ()
): { Theme.Slot }
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grille"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.BRASS
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(slotSize, slotSize)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.Parent = scroll
	local slots = {}
	for i = 1, count do
		local slot = Theme.slot(scroll, slotSize)
		slot.frame.LayoutOrder = i
		local entry = entries[i]
		if entry then
			slot.set(entry.id, entry.qty, ItemViews.name(entry.id), ItemViews.rarityColor(entry.id))
		else
			slot.set(nil)
		end
		slot.select(i == selected and entry ~= nil)
		slot.button.Activated:Connect(function()
			if entries[i] then
				onSelect(i)
			end
		end)
		slots[i] = slot
	end
	return slots
end

-- Fiche d'un objet ; renvoie le conteneur des boutons d'action (en bas de la fiche).
function ItemViews.details(parent: Frame, entry: Entry?, extra: string?): Frame
	local inner = Instance.new("Frame")
	inner.Name = "Interieur"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(16, 14)
	inner.Size = UDim2.new(1, -32, 1, -28)
	inner.Parent = parent
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Position = UDim2.fromScale(0, 1)
	actions.Size = UDim2.new(1, 0, 0, 36)
	actions.Parent = inner
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.Parent = actions
	if entry == nil then
		local hint =
			Theme.label(inner, extra or "Choisis un objet pour voir sa fiche.", 17, Theme.MUTED)
		hint.Size = UDim2.new(1, 0, 1, -44)
		hint.TextWrapped = true
		return actions
	end
	local def = ItemDefs.get(entry.id)
	local color = ItemViews.rarityColor(entry.id)
	local title = Theme.label(inner, ItemViews.name(entry.id), 26, color, Theme.TITLE_FONT)
	title.Size = UDim2.new(1, 0, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = true
	local sub = Theme.label(
		inner,
		`{if def then def.rarity else "?"} · {if def and def.relic
			then `{entry.qty}/3 charges`
			else `quantité {entry.qty}`}`,
		16,
		Theme.MUTED
	)
	sub.Position = UDim2.fromOffset(0, 34)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	local body = Theme.label(inner, (def and def.description) or "", 17, Theme.PARCHMENT)
	body.Position = UDim2.fromOffset(0, 64)
	body.Size = UDim2.new(1, 0, 1, -64 - 80)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	if extra then
		local note = Theme.label(inner, extra, 15, Theme.BRASS)
		note.AnchorPoint = Vector2.new(0, 1)
		note.Position = UDim2.new(0, 0, 1, -42)
		note.Size = UDim2.new(1, 0, 0, 34)
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Left
	end
	return actions
end

-- Liste verticale défilante (cartes du Codex, statistiques, aide).
function ItemViews.list(parent: Frame): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Liste"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.BRASS
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 2)
	pad.Parent = scroll
	return scroll
end

-- Carte : titre coloré, texte, et un bouton facultatif à droite.
function ItemViews.card(
	list: ScrollingFrame,
	order: number,
	title: string,
	text: string,
	color: Color3,
	buttonText: string?,
	buttonKind: Theme.ButtonKind?,
	onClick: (() -> ())?
): Frame
	local card = Theme.panel(list)
	card.BackgroundTransparency = 0.3
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 72)
	local t = Theme.label(card, title, 20, color, Theme.TITLE_FONT)
	t.Position = UDim2.fromOffset(16, 8)
	t.Size = UDim2.new(1, -190, 0, 26)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local body = Theme.label(card, text, 16, Theme.PARCHMENT)
	body.Position = UDim2.fromOffset(16, 36)
	body.Size = UDim2.new(1, -190, 0, 30)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	if buttonText then
		local b = Theme.button(card, buttonText, buttonKind or "Brass", onClick)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -16, 0.5, 0)
	end
	return card
end

-- Page d'aide : toutes les commandes du jeu, regroupées.
local HELP: { { string } } = {
	{ "DÉPLACEMENT", "" },
	{ "Sprint", "Maj (maintenir)" },
	{ "Glissade", "C pendant le sprint" },
	{ "Roulade", "C en marchant, ou juste avant de toucher le sol après une chute" },
	{ "Salto", "Saut en l'air (une fois par saut ; recharge au sol ou sur un mur)" },
	{ "Élan", "F (au sol ou une fois en l'air)" },
	{ "Grappin", "G (vise le curseur)" },
	{ "Escalade / course murale", "automatiques (sauter face à un rebord, longer un mur)" },
	{ "COMBAT", "" },
	{ "Tirer / frapper", "Clic gauche (maintenir pour un coup chargé)" },
	{ "Viser / parer", "Clic droit" },
	{ "Recharger", "R" },
	{ "Armes", "1 et 2" },
	{ "Capacité de l'arme", "@Q" },
	{ "OBJETS", "" },
	{ "Sac / coffre", "Tab ou I" },
	{ "Bandage", "H" },
	{ "Relique", "T" },
	{ "Capacités du Codex", "V et B" },
	{ "Interagir", "E (ou clic sur l'invite)" },
}

function ItemViews.help(content: Frame)
	local list = ItemViews.list(content)
	list:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 2)
	for i, line in HELP do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, if line[2] == "" then 34 else 24)
		row.Parent = list
		local a = Theme.label(
			row,
			line[1],
			if line[2] == "" then 20 else 17,
			if line[2] == "" then Theme.BRASS else Theme.PARCHMENT,
			if line[2] == "" then Theme.TITLE_FONT else Theme.BODY_FONT
		)
		a.Size = UDim2.fromScale(0.38, 1)
		a.TextXAlignment = Enum.TextXAlignment.Left
		a.TextYAlignment = Enum.TextYAlignment.Bottom
		-- « @Q » : touche physique, affichée selon le clavier (Q = A sur un clavier AZERTY).
		local value = line[2]
		if string.sub(value, 1, 1) == "@" then
			local code = (Enum.KeyCode :: any)[string.sub(value, 2)]
			local ok, shown = pcall(function()
				return UserInputService:GetStringForKeyCode(code)
			end)
			value = if ok and shown ~= "" then shown else string.sub(value, 2)
		end
		local b = Theme.label(row, value, 17, Theme.ARCANE)
		b.Position = UDim2.fromScale(0.38, 0)
		b.Size = UDim2.fromScale(0.62, 1)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextYAlignment = Enum.TextYAlignment.Bottom
	end
end

return ItemViews
