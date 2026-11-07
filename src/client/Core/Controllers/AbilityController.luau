--!strict
-- Capacités spéciales côté client (v0.4.5, D-038) : touche, choix de la cible, jauge du noyau,
-- annonces et effets. Ne décide rien : le serveur (AbilityService) vérifie et applique.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > AbilityController
--
-- Commandes : Q (clavier), LB (manette), bouton « Capacité » (MobileControls).
-- Pas de l'ombre : la cible est l'ennemi le plus proche du centre de l'écran, à portée ; elle
-- est entourée en cyan tant que la capacité est prête.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ability = require(Shared:WaitForChild("Combat"):WaitForChild("Ability")) :: any
local WeaponDefs = require(Shared:WaitForChild("Combat"):WaitForChild("WeaponDefs")) :: any
local PlaceKind = require(Shared:WaitForChild("PlaceKind")) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local CombatSounds = require(Client.Combat.CombatSounds)
local WeaponFx = require(Client.Combat.WeaponFx)
local CameraFeel = require(script.Parent.CameraFeel)
local CombatController = require(script.Parent.CombatController)

local CYAN = Color3.fromRGB(80, 230, 255)
local SHADOW = Color3.fromRGB(150, 110, 255)
local WARN = Color3.fromRGB(255, 70, 40)
local AIM_CONE = math.rad(28) -- écart maximal au centre de l'écran pour choisir une cible
local MESSAGE_TIME = 1.4

local player = Players.LocalPlayer

local AbilityController = {}

-- Interface ------------------------------------------------------------------------------

local gui: ScreenGui
local gauge: Frame
local gaugeFill: Frame
local gaugeLabel: TextLabel
local message: TextLabel
local warning: TextLabel
local messageUntil = 0
local warningUntil = 0
local targetHighlight: Highlight
local castHighlights: { [Model]: Highlight } = {}

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Abilities"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Jauge du noyau, au-dessus des munitions (bas droite).
	gauge = Instance.new("Frame")
	gauge.Name = "Core"
	gauge.AnchorPoint = Vector2.new(1, 1)
	gauge.Position = UDim2.new(1, -56, 1, -118)
	gauge.Size = UDim2.fromOffset(170, 8)
	gauge.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	gauge.BackgroundTransparency = 0.3
	gauge.BorderSizePixel = 0
	gauge.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = gauge
	gaugeFill = Instance.new("Frame")
	gaugeFill.Size = UDim2.fromScale(0, 1)
	gaugeFill.BackgroundColor3 = CYAN
	gaugeFill.BorderSizePixel = 0
	gaugeFill.Parent = gauge
	corner:Clone().Parent = gaugeFill
	gaugeLabel = Instance.new("TextLabel")
	gaugeLabel.AnchorPoint = Vector2.new(1, 1)
	gaugeLabel.Position = UDim2.new(1, 0, 0, -3)
	gaugeLabel.Size = UDim2.fromOffset(220, 18)
	gaugeLabel.BackgroundTransparency = 1
	gaugeLabel.Font = Enum.Font.GothamBold
	gaugeLabel.TextSize = 14
	gaugeLabel.TextXAlignment = Enum.TextXAlignment.Right
	gaugeLabel.TextColor3 = Color3.new(1, 1, 1)
	gaugeLabel.TextStrokeTransparency = 0.5
	gaugeLabel.Parent = gauge

	-- Message bref (refus, passif déclenché).
	message = Instance.new("TextLabel")
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.62)
	message.Size = UDim2.fromOffset(420, 28)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.TextSize = 22
	message.TextColor3 = CYAN
	message.TextStrokeTransparency = 0.4
	message.Text = ""
	message.Parent = gui

	-- Avertissement « on arrive dans ton dos ».
	warning = Instance.new("TextLabel")
	warning.AnchorPoint = Vector2.new(0.5, 0.5)
	warning.Position = UDim2.fromScale(0.5, 0.3)
	warning.Size = UDim2.fromOffset(520, 46)
	warning.BackgroundTransparency = 1
	warning.Font = Enum.Font.GothamBlack
	warning.TextSize = 38
	warning.TextColor3 = WARN
	warning.TextStrokeTransparency = 0.2
	warning.Text = "DERRIÈRE TOI !"
	warning.Visible = false
	warning.Parent = gui

	targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "ShadowTarget"
	targetHighlight.FillTransparency = 1
	targetHighlight.OutlineColor = SHADOW
	targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	targetHighlight.Enabled = false
	targetHighlight.Parent = gui
end

local function showMessage(text: string, color: Color3?)
	message.Text = text
	message.TextColor3 = color or CYAN
	messageUntil = os.clock() + MESSAGE_TIME
end

-- État ---------------------------------------------------------------------------------

-- Arme en main, sa capacité, et le remplissage de son noyau (attribut publié par le serveur).
local function current(): (any, any, number)
	local weaponId = CombatController.getEquipped()
	local def = weaponId and WeaponDefs[weaponId]
	local adef = def and def.ability and Ability.DEFS[def.ability]
	if def == nil or adef == nil then
		return nil, nil, 0
	end
	for slot = 1, 2 do
		if player:GetAttribute(`Loadout{slot}`) == def.id then
			return def, adef, (player:GetAttribute(`AbilityCharge{slot}`) :: number?) or 0
		end
	end
	return def, adef, 0
end

local function isTargetable(model: Model): boolean
	if model == player.Character or model:GetAttribute("Dead") == true then
		return false
	end
	if model:GetAttribute("MaxHealth") == nil then
		return false -- pas une cible de combat
	end
	if Players:GetPlayerFromCharacter(model) and PlaceKind ~= "Eclat" then
		return false -- pas de PvP au Refuge
	end
	return true
end

-- Cible du Pas de l'ombre : la plus proche du centre de l'écran, à portée.
local function pickShadowTarget(range: number): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or camera == nil then
		return nil
	end
	local look = camera.CFrame.LookVector
	local best: Model? = nil
	local bestAngle = AIM_CONE
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and isTargetable(model) then
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if targetRoot and targetRoot:IsA("BasePart") then
				if (targetRoot.Position - root.Position).Magnitude <= range then
					local toTarget = (targetRoot.Position - camera.CFrame.Position).Unit
					local angle = math.acos(math.clamp(look:Dot(toTarget), -1, 1))
					if angle < bestAngle then
						best, bestAngle = model, angle
					end
				end
			end
		end
	end
	return best
end

-- Action -------------------------------------------------------------------------------

local HOLD_TIME = 0.35 -- appui long sur Q : seconde capacité (fusil)
local pressedAt: number? = nil
local guardRequested = false

-- Utilise une capacité de l'arme en main (`kind` : nil = capacité principale).
function AbilityController.use(kind: string?)
	local character = player.Character
	if character == nil or character:GetAttribute("Downed") == true then
		return
	end
	local def, adef, charge = current()
	if def == nil or adef == nil then
		showMessage("Pas de capacité avec cette arme", Color3.new(1, 1, 1))
		return
	end
	local chosen = if kind then Ability.DEFS[kind] else adef
	if chosen == nil or (chosen.id ~= def.ability and chosen.id ~= def.ability2) then
		return
	end
	if charge < 1 then
		showMessage("Noyau pas encore chargé", Color3.new(1, 1, 1))
		return
	end
	if chosen.id == "ShadowStep" then
		local target = pickShadowTarget(chosen.range)
		if target == nil then
			showMessage("Aucune cible à portée", Color3.new(1, 1, 1))
			return
		end
		Net.fire("UseAbility", chosen.id, target)
	elseif chosen.id == "Ricochet" or chosen.id == "Stasis" then
		-- Tir spécial : même origine et même visée qu'un tir normal (le serveur vérifie).
		local origin = CombatController.getMuzzle()
		local aim = CombatController.getAimPoint()
		if origin == nil or aim == nil then
			return
		end
		Net.fire("UseAbility", chosen.id, origin, (aim - origin).Unit, workspace:GetServerTimeNow())
		CombatSounds.play2D(def.sound, (def.soundPitch or 1) * 0.85)
		CameraFeel.kick(def.recoil * 1.3)
	else
		Net.fire("UseAbility", chosen.id)
	end
end

-- Touche Q / bouton « Capa. » : appui bref = capacité principale ; appui long = seconde
-- capacité quand elle se déclenche ainsi (fusil). La Garde du Temps se lève avec la parade.
local function secondaryOnHold(): string?
	local def = current()
	if def and def.ability2 and def.ability2 ~= "TimeGuard" then
		return def.ability2
	end
	return nil
end

function AbilityController.press()
	if secondaryOnHold() then
		pressedAt = os.clock()
	else
		AbilityController.use()
	end
end

function AbilityController.release()
	local started = pressedAt
	pressedAt = nil
	local second = secondaryOnHold()
	if started == nil or second == nil then
		return
	end
	if os.clock() - started >= HOLD_TIME then
		AbilityController.use(second)
	else
		AbilityController.use()
	end
end

local function onAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		AbilityController.press()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		AbilityController.release()
	end
	return Enum.ContextActionResult.Sink
end

-- Texte d'aide de la jauge.
local function hint(def: any, adef: any, ready: boolean): string
	local second = def.ability2 and Ability.DEFS[def.ability2]
	if not ready then
		return if second then `{adef.name} / {second.name}` else adef.name
	end
	if second and def.ability2 == "TimeGuard" then
		return `[Q] {adef.name} · parade maintenue : {second.name}`
	elseif second then
		return `[Q] {adef.name} · maintenir : {second.name}`
	end
	return `[Q] {adef.name}`
end

-- Pour MobileControls : remplissage (0 à 1) et nom de la capacité en main.
function AbilityController.getState(): (number, string?)
	local _, adef, charge = current()
	return charge, if adef then adef.name else nil
end

-- Réseau -------------------------------------------------------------------------------

local function onCombatEvent(info: any)
	if typeof(info) ~= "table" then
		return
	end
	if info.type == "ShadowWarning" then
		warningUntil = os.clock()
			+ (if typeof(info.duration) == "number" then info.duration else 0.3)
			+ 0.4
		CombatSounds.play2D("ShadowWarning", 1.3)
		CameraFeel.kick(-1)
	elseif info.type == "AbilityReady" then
		CombatSounds.play2D("AbilityReady", 0.7)
	elseif info.type == "AbilityRefused" then
		showMessage(
			if info.reason == "NoAmmo" then "Rechargement en cours" else "Cible hors d'atteinte",
			Color3.new(1, 1, 1)
		)
	elseif info.type == "Passive" then
		if info.passive == "Riposte" then
			showMessage("RIPOSTE ×2", CYAN)
		elseif info.passive == "ReloadOnKill" then
			showMessage("Rechargé !", CYAN)
		elseif info.passive == "Steady" then
			showMessage("SOUFFLE +25 %", CYAN)
		end
	elseif info.type == "Volley" then
		CombatController.volley(
			if typeof(info.shots) == "number" then math.clamp(info.shots, 1, 6) else 3,
			if typeof(info.interval) == "number" then math.clamp(info.interval, 0.05, 1) else 0.2,
			if typeof(info.extraSpread) == "number" then info.extraSpread else 2.5
		)
		showMessage("SALVE !", CYAN)
	end
end

local function onShotFx(info: any)
	if typeof(info) ~= "table" then
		return
	end
	-- Tirs spéciaux : trajectoire en plusieurs points (rebond).
	if (info.kind == "Ricochet" or info.kind == "Stasis") and typeof(info.points) == "table" then
		local points = info.points
		for i = 1, #points - 1 do
			if typeof(points[i]) == "Vector3" and typeof(points[i + 1]) == "Vector3" then
				WeaponFx.abilityTrail(
					points[i],
					points[i + 1],
					if info.kind == "Stasis" then CYAN else Color3.new(1, 0.85, 0.5)
				)
			end
		end
		local last = points[#points]
		if typeof(last) == "Vector3" then
			CombatSounds.playAt(if info.kind == "Stasis" then "AbilityRewind" else "Hit", last, 0.6)
		end
		return
	end
	if typeof(info.origin) ~= "Vector3" or typeof(info.finish) ~= "Vector3" then
		return
	end
	if info.kind == "FractureWave" then
		WeaponFx.groundWave(info.origin, info.finish)
		CombatSounds.playAt("MeleeHitHeavy", info.origin, 0.7)
		CameraFeel.kick(-1.5)
		return
	elseif info.kind == "GuardBlock" then
		WeaponFx.parrySparks(info.origin)
		CombatSounds.playAt("Parry", info.origin, 1.15)
		return
	end
	if info.kind == "Rewind" then
		WeaponFx.abilityTrail(info.origin, info.finish, CYAN)
		CombatSounds.playAt("AbilityRewind", info.finish)
	elseif info.kind == "ShadowStep" then
		WeaponFx.abilityTrail(info.origin, info.finish, SHADOW)
		CombatSounds.playAt("AbilityShadow", info.finish)
	end
end

-- Annonces visibles par tous : lanceur qui se prépare (cyan), cible marquée (violet).
local function updateCastHighlights()
	local now = workspace:GetServerTimeNow()
	local seen: { [Model]: boolean } = {}
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") then
			local castEnd = model:GetAttribute("AbilityCastEnd") :: number?
			local marked = model:GetAttribute("ShadowMarkedAt") :: number?
			local guarding = model:GetAttribute("TimeGuard") == true
			local active = guarding or (castEnd and castEnd > now) or (marked and marked > now)
			if active then
				seen[model] = true
				local h = castHighlights[model]
				if h == nil then
					h = Instance.new("Highlight")
					h.FillTransparency = 0.55
					h.OutlineTransparency = 0
					h.Parent = model
					castHighlights[model] = h
				end
				local color = if marked and marked > now then SHADOW else CYAN
				h.FillColor = color
				h.OutlineColor = color
			end
		end
	end
	for model, h in castHighlights do
		if not seen[model] then
			h:Destroy()
			castHighlights[model] = nil
		end
	end
end

function AbilityController.start()
	buildGui()
	ContextActionService:BindAction(
		"FractureAbility",
		onAction,
		false,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	Net.on("CombatEvent", onCombatEvent)
	Net.on("ShotFx", onShotFx)

	local wasReady = false
	RunService.RenderStepped:Connect(function()
		local clock = os.clock()
		local _, adef, charge = current()
		local touch = UserInputService.TouchEnabled or player:GetAttribute("QA_ForceMobile") == true

		-- Jauge (sur mobile, c'est le bouton « Capacité » qui l'affiche).
		gauge.Visible = adef ~= nil and not touch
		if adef then
			gaugeFill.Size = UDim2.fromScale(charge, 1)
			local ready = charge >= 1
			gaugeFill.BackgroundColor3 = if ready
				then Color3.new(1, 1, 1):Lerp(CYAN, 0.5 + 0.5 * math.sin(clock * 6))
				else CYAN
			local def = current()
			gaugeLabel.Text = hint(def, adef, ready)
			gaugeLabel.TextColor3 = if ready then CYAN else Color3.fromRGB(200, 200, 200)
			if ready and not wasReady then
				CameraFeel.kick(0.4)
			end
			wasReady = ready
		end

		-- Cible du Pas de l'ombre, entourée tant que la capacité est prête.
		local target = if adef
				and adef.id == "ShadowStep"
				and charge >= 1
			then pickShadowTarget(adef.range)
			else nil
		targetHighlight.Adornee = target
		targetHighlight.Enabled = target ~= nil

		-- Garde du Temps (épée longue) : parade maintenue avec un noyau plein.
		local def = current()
		if def and def.ability2 == "TimeGuard" then
			local held = CombatController.getParryHeld()
			if held and held >= HOLD_TIME and not guardRequested and charge >= 1 then
				guardRequested = true
				Net.fire("UseAbility", "TimeGuard", true)
			elseif held == nil and guardRequested then
				guardRequested = false
				Net.fire("UseAbility", "TimeGuard", false)
			end
		elseif guardRequested then
			guardRequested = false
			Net.fire("UseAbility", "TimeGuard", false)
		end

		message.Visible = clock < messageUntil
		warning.Visible = clock < warningUntil
		if warning.Visible then
			warning.TextTransparency = 0.5 - 0.5 * math.sin(clock * 30)
		end
		updateCastHighlights()
	end)

	-- Studio : point de test (la simulation de touches de Studio n'atteint pas le jeu).
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "FractureAbilityQA"
		hook.OnInvoke = function(command: string, argument: any): any
			if command == "use" then
				AbilityController.use(argument)
			elseif command == "target" then
				local _, adef = current()
				return if adef then pickShadowTarget(adef.range or 12) else nil
			end
			return nil
		end
		hook.Parent = player:WaitForChild("PlayerScripts")
	end
end

return AbilityController
