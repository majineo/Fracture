--!strict
-- Gestionnaire des fenêtres (v0.9.0) : une seule fenêtre ouverte à la fois, toutes au même style
-- (Ui/Theme), et la souris LIBÉRÉE tant qu'une fenêtre est ouverte (la caméra d'épaule la
-- verrouillait au centre : on ne pouvait rien cliquer, arme en main).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Ui > Menu
--
--   local w = Menu.window("Sac", "Sac", Vector2.new(720, 460), { "Sac", "Codex" })
--   w.onTab = function(tab, content) ... end   -- construit le contenu de l'onglet
--   Menu.setMain("Sac")                         -- Tab / I (et bouton tactile) l'ouvrent
--
-- Fermer : Tab / I, le bouton X, ou un clic hors de la fenêtre.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

export type Window = {
	id: string,
	frame: Frame,
	content: Frame,
	tab: string?,
	tabs: { string },
	setTab: (name: string) -> (),
	refresh: () -> (),
	onTab: ((tab: string, content: Frame) -> ())?,
	onClose: (() -> ())?,
}

local Menu = {}

local gui: ScreenGui? = nil
local backdrop: Frame
local windows: { [string]: Window } = {}
local openId: string? = nil
local mainId: string? = nil
local listeners: { (open: boolean) -> () } = {}

local function root(): ScreenGui
	if gui then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "FractureMenus"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 20
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	-- Voile : un clic HORS de la fenêtre la ferme. On compare la position du clic au cadre de
	-- la fenêtre : Roblox transmet aussi au voile les clics faits dans la fenêtre (v0.9.0).
	local veil = Instance.new("Frame")
	veil.Name = "Voile"
	veil.Active = true
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.5
	veil.Visible = false
	veil.Parent = g
	veil.InputBegan:Connect(function(input: InputObject)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		-- Le clic touche-t-il la fenêtre ? On demande à Roblox les objets sous le clic, dans le
		-- même repère que le clic (comparer à AbsolutePosition échoue avec la mise à l'échelle
		-- de Windows dans Studio).
		local w = openId and windows[openId]
		if w then
			local playerGui = player:FindFirstChildOfClass("PlayerGui")
			local hits = if playerGui
				then playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
				else {}
			for _, hit in hits do
				if hit == w.frame or hit:IsDescendantOf(w.frame) then
					return
				end
			end
		end
		Menu.close()
	end)
	backdrop = veil
	gui = g
	return g
end

local function notify()
	local open = openId ~= nil
	for _, f in listeners do
		task.spawn(f, open)
	end
end

-- Libère la souris (la caméra d'épaule lit Menu.isOpen() à chaque image).
local function releaseCursor()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

-- Crée (une fois) une fenêtre centrée de taille `size`, avec des onglets facultatifs.
function Menu.window(id: string, title: string, size: Vector2, tabs: { string }?): Window
	local existing = windows[id]
	if existing then
		return existing
	end
	local g = root()
	local frame = Theme.panel(g, title)
	frame.Name = id
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Visible = false
	frame.Active = true
	frame.ZIndex = 2
	-- Petits écrans : la fenêtre se réduit pour tenir.
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(size.X, size.Y)
	fit.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			local v = camera.ViewportSize
			scale.Scale = math.min(1, (v.X - 24) / size.X, (v.Y - 24) / size.Y)
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local close = Theme.button(frame, "X", "Muted", function()
		Menu.close()
	end)
	close.Name = "Fermer"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(32, 28)

	local content = Instance.new("Frame")
	content.Name = "Contenu"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(18, 54)
	content.Size = UDim2.new(1, -36, 1, -70)
	content.Parent = frame

	local window: Window
	local tabButtons: { [string]: TextButton } = {}
	local tabList = tabs or {}
	if #tabList > 1 then
		local bar = Instance.new("Frame")
		bar.Name = "Onglets"
		bar.BackgroundTransparency = 1
		bar.Position = UDim2.fromOffset(18, 54)
		bar.Size = UDim2.new(1, -36, 0, 32)
		bar.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.Parent = bar
		for _, name in tabList do
			local b = Theme.button(bar, name, "Brass", function()
				window.setTab(name)
			end)
			b.Size = UDim2.fromOffset(120, 30)
			tabButtons[name] = b
		end
		content.Position = UDim2.fromOffset(18, 96)
		content.Size = UDim2.new(1, -36, 1, -112)
	end

	window = {
		id = id,
		frame = frame,
		content = content,
		tab = tabList[1],
		tabs = tabList,
		setTab = function(name: string)
			window.tab = name
			for n, b in tabButtons do
				local stroke = b:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if n == name then Theme.ARCANE else Theme.BRASS
				end
				b.TextColor3 = if n == name then Theme.ARCANE else Theme.BRASS
				b.BackgroundColor3 = Theme.INK_LIGHT
				b:SetAttribute("Accent", if n == name then Theme.ARCANE else nil)
			end
			window.refresh()
		end,
		refresh = function()
			for _, child in content:GetChildren() do
				child:Destroy()
			end
			if window.onTab then
				window.onTab(window.tab or "", content)
			end
		end,
		onTab = nil,
		onClose = nil,
	}
	windows[id] = window
	return window
end

function Menu.isOpen(): boolean
	return openId ~= nil
end

function Menu.current(): string?
	return openId
end

function Menu.get(id: string): Window?
	return windows[id]
end

function Menu.open(id: string)
	local w = windows[id]
	if w == nil then
		return
	end
	if openId and openId ~= id then
		Menu.close()
	end
	root()
	openId = id
	backdrop.Visible = true
	w.frame.Visible = true
	if w.tab then
		w.setTab(w.tab)
	else
		w.refresh()
	end
	releaseCursor()
	notify()
end

function Menu.close()
	local id = openId
	if id == nil then
		return
	end
	openId = nil
	local w = windows[id]
	if w then
		w.frame.Visible = false
		if w.onClose then
			task.spawn(w.onClose)
		end
	end
	backdrop.Visible = false
	notify()
end

function Menu.toggle(id: string)
	if openId == id then
		Menu.close()
	else
		Menu.open(id)
	end
end

-- Rafraîchit la fenêtre si elle est ouverte (nouvelles données du serveur).
function Menu.refresh(id: string)
	local w = windows[id]
	if w and openId == id then
		w.refresh()
	end
end

-- Appelé à chaque ouverture / fermeture d'une fenêtre.
function Menu.onChanged(callback: (open: boolean) -> ())
	table.insert(listeners, callback)
end

-- Fenêtre principale de la place : Tab / I au clavier, bouton « Sac » sur écran tactile.
function Menu.setMain(id: string)
	local first = mainId == nil
	mainId = id
	if not first then
		return
	end
	-- La liste des joueurs (Tab) est masquée : Tab ouvre le sac, comme dans les jeux d'extraction.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	ContextActionService:BindAction("FractureMenu", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin and mainId then
			Menu.toggle(mainId)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.I)
	if UserInputService.TouchEnabled or player:GetAttribute("QA_ForceMobile") == true then
		local g = root()
		local b = Theme.button(g, "Sac", "Brass", function()
			if mainId then
				Menu.toggle(mainId)
			end
		end)
		b.Name = "BoutonSac"
		b.AnchorPoint = Vector2.new(0, 0)
		b.Position = UDim2.fromOffset(12, 64)
		b.Size = UDim2.fromOffset(72, 34)
	end
end

return Menu
