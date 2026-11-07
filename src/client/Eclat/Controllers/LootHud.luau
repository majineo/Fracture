--!strict
-- Interface du butin et de l'extraction (v0.6.0) : inventaire de partie (12 emplacements),
-- messages de ramassage, repères des zones d'extraction, jauge d'extraction, bilan.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Place > Controllers > LootHud
--
-- Le client ne décide de rien : il affiche ce que le serveur envoie (InventoryState, LootEvent,
-- ExtractionResult) et les attributs répliqués (zones, progression).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefs = require(Shared:WaitForChild("Loot"):WaitForChild("ItemDefs"))
local ExtractionPlan = require(Shared:WaitForChild("Eclat"):WaitForChild("ExtractionPlan"))

local Client = script.Parent.Parent.Parent
local Net = require(Client.Lib.Net)
local CombatSounds = require(Client.Combat.CombatSounds)

local player = Players.LocalPlayer

local CYAN = Color3.fromRGB(80, 230, 255)
local ORANGE = Color3.fromRGB(255, 140, 60)
local PANEL = Color3.fromRGB(16, 18, 24)

local LootHud = {}

local gui: ScreenGui
local slots: { Frame } = {}
local toastList: Frame
local progressFrame: Frame
local progressFill: Frame
local progressText: TextLabel
local result: Frame
local stacksShown: { any } = {}

local BANDAGE = "cons.bandage"

local function useBandage()
	Net.fire("UseConsumable", BANDAGE)
end

-- Relique : la première portée (touche T / Y manette), ou celle touchée dans la barre.
local function useRelic(index: number?)
	local slot = index
	if slot == nil then
		for i, stack in stacksShown do
			local def = ItemDefs.get(stack.id)
			if def and def.relic then
				slot = i
				break
			end
		end
	end
	if slot then
		local camera = workspace.CurrentCamera
		Net.fire("UseRelic", slot, camera and camera.CFrame.LookVector or nil)
	end
end

local function rarityColor(id: string): Color3
	local def = ItemDefs.get(id)
	local rgb = ItemDefs.RARITY_COLORS[def and def.rarity or "Commun"]
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function itemName(id: string): string
	local def = ItemDefs.get(id)
	return if def then def.name else id
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = value
	l.Parent = parent
	return l
end

local function buildInventory()
	local bar = Instance.new("Frame")
	bar.Name = "Inventaire"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -112)
	bar.Size = UDim2.fromOffset(12 * 34 + 11 * 4, 34)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = bar
	for i = 1, 12 do
		local slot = Instance.new("Frame")
		slot.Name = `Slot{i}`
		slot.Size = UDim2.fromOffset(34, 34)
		slot.BackgroundColor3 = PANEL
		slot.BackgroundTransparency = 0.45
		corner(slot, 5)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(70, 74, 84)
		stroke.Thickness = 1
		stroke.Parent = slot
		local name = text(slot, "", 11)
		name.Name = "Nom"
		name.Size = UDim2.new(1, -2, 0, 14)
		name.Position = UDim2.fromOffset(1, 3)
		name.TextScaled = false
		local qty = text(slot, "", 12)
		qty.Name = "Qte"
		qty.Size = UDim2.new(1, -4, 0, 14)
		qty.Position = UDim2.new(0, 2, 1, -16)
		qty.TextXAlignment = Enum.TextXAlignment.Right
		local tap = Instance.new("TextButton")
		tap.Name = "Toucher"
		tap.Size = UDim2.fromScale(1, 1)
		tap.BackgroundTransparency = 1
		tap.Text = ""
		tap.Parent = slot
		tap.Activated:Connect(function()
			local stack = stacksShown[i]
			local def = stack and ItemDefs.get(stack.id)
			if def and def.heal then
				Net.fire("UseConsumable", stack.id)
			elseif def and def.relic then
				useRelic(i)
			end
		end)
		slot.Parent = bar
		slots[i] = slot
	end
end

local function showInventory(state: any)
	if typeof(state) ~= "table" or typeof(state.stacks) ~= "table" then
		return
	end
	stacksShown = state.stacks
	for i, slot in slots do
		local stack = state.stacks[i]
		local name = slot:FindFirstChild("Nom") :: TextLabel
		local qty = slot:FindFirstChild("Qte") :: TextLabel
		local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
		if typeof(stack) == "table" and typeof(stack.id) == "string" then
			name.Text = string.sub(itemName(stack.id), 1, 5)
			name.TextColor3 = rarityColor(stack.id)
			qty.Text = tostring(stack.qty)
			stroke.Color = rarityColor(stack.id)
			slot.BackgroundTransparency = 0.25
		else
			name.Text = ""
			qty.Text = ""
			stroke.Color = Color3.fromRGB(70, 74, 84)
			slot.BackgroundTransparency = 0.45
		end
	end
end

local function toast(message: string, color: Color3)
	local l = text(toastList, message, 16, color)
	l.Size = UDim2.new(1, 0, 0, 20)
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.TextStrokeTransparency = 0.5
	task.delay(2.6, function()
		TweenService
			:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
		task.delay(0.6, function()
			l:Destroy()
		end)
	end)
end

local function onLoot(info: any)
	if typeof(info) ~= "table" then
		return
	end
	if info.type == "Taken" and typeof(info.items) == "table" then
		for _, item in info.items do
			toast(`+{item.qty} {itemName(item.id)}`, rarityColor(item.id))
		end
		if #info.items > 0 then
			CombatSounds.play2D("Holster", 1.4)
		elseif info.full then
			toast("Inventaire plein", ORANGE)
		elseif info.empty then
			toast("Vide", Color3.fromRGB(170, 170, 170))
		end
	elseif info.type == "Healed" then
		if info.full then
			toast("Santé déjà pleine", Color3.fromRGB(170, 170, 170))
		elseif typeof(info.amount) == "number" then
			toast(`Soigné +{math.floor(info.amount)}`, Color3.fromRGB(120, 230, 140))
		end
	elseif info.type == "RelicUsed" and typeof(info.id) == "string" then
		local name = itemName(info.id)
		if (info.left or 0) <= 0 then
			toast(`{name} s'est brisée`, ORANGE)
		else
			toast(
				`{name} — {info.left} charge(s) (intacte : 3, à ramener)`,
				rarityColor(info.id)
			)
		end
	elseif info.type == "Interrupted" then
		toast("Soin interrompu", ORANGE)
	elseif info.type == "Lost" and typeof(info.items) == "table" and #info.items > 0 then
		toast("Butin perdu — il reste dans votre sac", ORANGE)
	end
end

local function buildProgress()
	progressFrame = Instance.new("Frame")
	progressFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	progressFrame.Position = UDim2.fromScale(0.5, 0.62)
	progressFrame.Size = UDim2.fromOffset(300, 46)
	progressFrame.BackgroundTransparency = 1
	progressFrame.Visible = false
	progressFrame.Parent = gui
	progressText = text(progressFrame, "", 16, CYAN)
	progressText.Size = UDim2.new(1, 0, 0, 20)
	progressText.TextStrokeTransparency = 0.4
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 26)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = PANEL
	back.BackgroundTransparency = 0.3
	corner(back, 4)
	back.Parent = progressFrame
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = CYAN
	corner(progressFill, 4)
	progressFill.Parent = back
end

local function buildResult()
	result = Instance.new("Frame")
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.5)
	result.Size = UDim2.fromOffset(380, 330)
	result.BackgroundColor3 = PANEL
	result.BackgroundTransparency = 0.1
	result.Visible = false
	corner(result, 10)
	result.Parent = gui
	local title = text(result, "EXTRAIT", 30, CYAN)
	title.Name = "Titre"
	title.Size = UDim2.new(1, 0, 0, 44)
	title.Position = UDim2.fromOffset(0, 12)
	local list = text(result, "", 15)
	list.Name = "Liste"
	list.Size = UDim2.new(1, -40, 0, 190)
	list.Position = UDim2.fromOffset(20, 60)
	list.Font = Enum.Font.Gotham
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	local button = Instance.new("TextButton")
	button.Name = "Repartir"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -16)
	button.Size = UDim2.fromOffset(200, 42)
	button.BackgroundColor3 = CYAN
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = PANEL
	button.Text = "Repartir"
	corner(button, 8)
	button.Parent = result
	button.Activated:Connect(function()
		result.Visible = false
		Net.fire("RequestRedeploy")
	end)
end

local function onResult(info: any)
	if typeof(info) ~= "table" then
		return
	end
	local lines = {}
	if typeof(info.items) == "table" then
		for _, item in info.items do
			if item.id ~= ItemDefs.GRAINS then
				table.insert(lines, `{item.qty} × {itemName(item.id)}`)
			end
		end
	end
	if #lines == 0 and (info.grains or 0) == 0 then
		table.insert(lines, "Rien rapporté cette fois.")
	end
	table.insert(lines, "")
	table.insert(lines, `+{info.grains or 0} Grains (total : {info.totalGrains or 0})`)
	table.insert(lines, `Extractions réussies : {info.extractions or 0}`)
	local list = result:FindFirstChild("Liste") :: TextLabel
	list.Text = table.concat(lines, "\n")
	result.Visible = true
	CombatSounds.play2D("AbilityReady", 0.8)
end

-- Repères des zones d'extraction : colonne de lumière et étiquette visibles de loin.
type Marker = { part: BasePart, beam: BasePart, label: TextLabel, gui: BillboardGui }
local markers: { [BasePart]: Marker } = {}

local function addMarker(part: BasePart)
	if markers[part] then
		return
	end
	local final = part:GetAttribute("Final") == true
	local color = if final then ORANGE else CYAN
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(1.2, 120, 1.2)
	beam.CFrame = CFrame.new(part.Position + Vector3.new(0, 60, 0))
	beam.Transparency = 1
	beam.Parent = workspace.CurrentCamera
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = part
	billboard.Parent = gui
	local label = text(billboard, "", 14, color)
	label.Size = UDim2.fromScale(1, 1)
	label.TextStrokeTransparency = 0.4
	markers[part] = { part = part, beam = beam, label = label, gui = billboard }
end

local function removeMarker(part: BasePart)
	local m = markers[part]
	if m then
		markers[part] = nil
		m.beam:Destroy()
		m.gui:Destroy()
	end
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function update()
	local start = workspace:GetAttribute("EclatStart")
	local elapsed = if typeof(start) == "number" then workspace:GetServerTimeNow() - start else 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for part, m in markers do
		if part.Parent == nil then
			removeMarker(part)
			continue
		end
		local opensAt = (part:GetAttribute("OpensAt") :: number?) or 0
		local closesAt = (part:GetAttribute("ClosesAt") :: number?) or 0
		local final = part:GetAttribute("Final") == true
		local name = if final then "FAILLE" else "EXTRACTION"
		local distance = ""
		if root and root:IsA("BasePart") then
			distance = ` · {math.floor((root.Position - part.Position).Magnitude)} m`
		end
		if elapsed < opensAt then
			-- Annoncée 60 s avant (secondaires) ; la Faille se devine dès le début.
			local soon = opensAt - elapsed < 60 or final
			m.gui.Enabled = soon
			m.label.Text = `{name} dans {clock(opensAt - elapsed)}{distance}`
			m.label.TextTransparency = 0.35
			m.beam.Transparency = 1
			part.Transparency = 0.9
		elseif elapsed < closesAt then
			m.gui.Enabled = true
			m.label.Text = `{name} ouverte {clock(closesAt - elapsed)}{distance}`
			m.label.TextTransparency = 0
			m.beam.Transparency = 0.55 + 0.15 * math.sin(os.clock() * 3)
			part.Transparency = 0.45
		else
			m.gui.Enabled = false
			m.beam.Transparency = 1
			part.Transparency = 1
		end
	end
	-- Jauge de soin (bandage en cours).
	local useEnds = character and character.Parent and character:GetAttribute("UseEnds")
	if typeof(useEnds) == "number" and not result.Visible then
		local left = useEnds - workspace:GetServerTimeNow()
		local def = ItemDefs.get(BANDAGE)
		local total = (def and def.useTime) or 2.5
		progressFrame.Visible = true
		progressFill.BackgroundColor3 = Color3.fromRGB(120, 230, 140)
		progressFill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		progressText.TextColor3 = Color3.fromRGB(120, 230, 140)
		progressText.Text =
			string.format("BANDAGE — %.1f s (un coup l'interrompt)", math.max(0, left))
		return
	end
	progressFill.BackgroundColor3 = CYAN
	progressText.TextColor3 = CYAN
	-- Jauge d'extraction.
	local p = character and character.Parent and character:GetAttribute("ExtractProgress")
	if typeof(p) == "number" and p > 0 and not result.Visible then
		progressFrame.Visible = true
		local ratio = math.clamp(p / ExtractionPlan.HOLD, 0, 1)
		progressFill.Size = UDim2.fromScale(ratio, 1)
		progressText.Text = string.format(
			"EXTRACTION — %.1f s (ne vous faites pas toucher)",
			ExtractionPlan.HOLD - p
		)
	else
		progressFrame.Visible = false
	end
end

local function watchZones(folder: Instance)
	local function consider(d: Instance)
		if d:IsA("BasePart") and string.sub(d.Name, 1, 11) == "Extraction_" then
			addMarker(d)
		end
	end
	for _, d in folder:GetDescendants() do
		consider(d)
	end
	folder.DescendantAdded:Connect(consider)
end

function LootHud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "LootHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	buildInventory()
	toastList = Instance.new("Frame")
	toastList.AnchorPoint = Vector2.new(1, 0.5)
	toastList.Position = UDim2.new(1, -24, 0.55, 0)
	toastList.Size = UDim2.fromOffset(320, 200)
	toastList.BackgroundTransparency = 1
	toastList.Parent = gui
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = toastList
	buildProgress()
	buildResult()
	Net.on("InventoryState", showInventory)
	Net.on("LootEvent", onLoot)
	Net.on("ExtractionResult", onResult)
	local existing = workspace:FindFirstChild("Eclat")
	if existing then
		watchZones(existing)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Eclat" then
			watchZones(child)
		end
	end)
	RunService.RenderStepped:Connect(update)
	-- Bandage : H (clavier), croix bas (manette) ; sur mobile, toucher l'objet dans la barre.
	ContextActionService:BindAction("FractureBandage", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			useBandage()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H, Enum.KeyCode.DPadDown)
	ContextActionService:BindAction("FractureRelic", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			useRelic(nil)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonY)
end

return LootHud
