--!strict
-- Contrôleur de déplacement du joueur local : sprint, glissade, escalade, grappin.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > MovementController
--
-- Un seul mouvement spécial à la fois (machine à états) :
--   Normal ──(glisser en courant)──▶ Slide ──(fin / saut)──▶ Normal
--   Normal ──(saut face à un rebord)──▶ Mantle ──(fin)──▶ Normal
--   Normal / Slide ──(grappin)──▶ Grapple ──(arrivée / saut = lâcher)──▶ Normal
--
-- Contrôles (GDD 03-combat §1) :
--   Sprint   : Maj (maintenir) · manette L3 et bouton tactile (bascule)
--   Glisser  : C ou Ctrl pendant le sprint · manette B · bouton tactile
--   Escalade : Saut face à un rebord (automatique)
--   Grappin  : G (vise le curseur) · manette R3 et bouton tactile (visent le centre de l'écran)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig =
	require(Shared:WaitForChild("Movement"):WaitForChild("MovementConfig")) :: any
local Stamina = require(Shared.Movement:WaitForChild("Stamina")) :: any
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal")) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local Context = require(Client.Movement.Context)
local Grapple = require(Client.Movement.Grapple)
local Mantle = require(Client.Movement.Mantle)
local Slide = require(Client.Movement.Slide)

type Mode = "Normal" | "Slide" | "Mantle" | "Grapple"

local ACTION_SPRINT = "Fracture_Sprint"
local ACTION_SLIDE = "Fracture_Slide"
local ACTION_GRAPPLE = "Fracture_Grapple"

local player = Players.LocalPlayer

local MovementController = {}

-- Déclenché quand le mode change : (nouveauMode, ancienMode).
MovementController.ModeChanged = Signal.new()

local ctx: Context.Context? = nil
local mode: Mode = "Normal"
local action: Context.Action? = nil
local stamina = Stamina.new()
local sprintHeld = false -- clavier : maintenir
local sprintToggled = false -- tactile / manette : bascule
local sprinting = false
local lastSlide = -math.huge
local lastGrapple = -math.huge
local characterConnections: { RBXScriptConnection } = {}

local function setMode(newMode: Mode)
	if newMode == mode then
		return
	end
	local old = mode
	mode = newMode
	MovementController.ModeChanged:Fire(newMode, old)
end

local function endAction(boost: boolean?)
	local current = action
	local wasGrapple = mode == "Grapple"
	action = nil
	setMode("Normal")
	if current then
		current.stop(boost)
	end
	if wasGrapple then
		Net.fire("GrappleEnd")
	end
end

local function isMoving(context: Context.Context): boolean
	return context.humanoid.MoveDirection.Magnitude > 0.1
end

local function onGround(context: Context.Context): boolean
	return context.humanoid.FloorMaterial ~= Enum.Material.Air
end

-- Actions ------------------------------------------------------------------------------

local function trySlide()
	local context = ctx
	if context == nil or mode ~= "Normal" or not onGround(context) then
		return
	end
	if os.clock() - lastSlide < MovementConfig.SLIDE_COOLDOWN then
		return
	end
	local horizontal = Context.horizontalVelocity(context)
	if horizontal.Magnitude < MovementConfig.SLIDE_MIN_SPEED then
		return
	end
	if not Stamina.spend(stamina, MovementConfig.SLIDE_STAMINA_COST, MovementConfig) then
		return
	end
	lastSlide = os.clock()
	action = Slide.start(context, horizontal)
	setMode("Slide")
end

local function tryGrapple(useScreenCenter: boolean)
	local context = ctx
	if context == nil or mode == "Mantle" or mode == "Grapple" then
		return
	end
	if os.clock() - lastGrapple < MovementConfig.GRAPPLE_COOLDOWN then
		return
	end
	local target = Grapple.aim(context, useScreenCenter)
	if target == nil then
		return
	end
	if mode == "Slide" then
		endAction()
	end
	lastGrapple = os.clock()
	action = Grapple.start(context, target)
	setMode("Grapple")
	Net.fire("GrappleStart", target)
end

local function onJumpRequest()
	local context = ctx
	if context == nil or context.humanoid.Health <= 0 then
		return
	end
	if mode == "Grapple" then
		endAction(true) -- lâcher le grappin avec une petite impulsion
		return
	end
	if mode == "Slide" then
		endAction() -- le saut part avec l'élan de la glissade
		return
	end
	if mode == "Normal" then
		local target = Mantle.find(context)
		if target then
			context.humanoid.Jump = false
			action = Mantle.start(context, target)
			setMode("Mantle")
		end
	end
end

-- Entrées ------------------------------------------------------------------------------

local function isKeyboard(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Keyboard
end

local function handleSprint(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if isKeyboard(input) then
		sprintHeld = state == Enum.UserInputState.Begin
	elseif state == Enum.UserInputState.Begin then
		sprintToggled = not sprintToggled
	end
	return Enum.ContextActionResult.Sink
end

local function handleSlide(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		trySlide()
	end
	return Enum.ContextActionResult.Sink
end

local function handleGrapple(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		tryGrapple(not isKeyboard(input))
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	-- Le troisième argument `true` crée automatiquement un bouton tactile sur mobile.
	ContextActionService:BindAction(
		ACTION_SPRINT,
		handleSprint,
		true,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:BindAction(
		ACTION_SLIDE,
		handleSlide,
		true,
		Enum.KeyCode.C,
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindAction(
		ACTION_GRAPPLE,
		handleGrapple,
		true,
		Enum.KeyCode.G,
		Enum.KeyCode.ButtonR3
	)
	ContextActionService:SetTitle(ACTION_SPRINT, "Sprint")
	ContextActionService:SetTitle(ACTION_SLIDE, "Glisser")
	ContextActionService:SetTitle(ACTION_GRAPPLE, "Grappin")
	UserInputService.JumpRequest:Connect(onJumpRequest)
end

-- Personnage ---------------------------------------------------------------------------

local function clearCharacter()
	if action then
		endAction()
	end
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	ctx = nil
	sprintToggled = false
end

local function onCharacterAdded(character: Model)
	clearCharacter()
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if
		humanoid == nil
		or root == nil
		or not humanoid:IsA("Humanoid")
		or not root:IsA("BasePart")
	then
		return
	end
	humanoid.WalkSpeed = MovementConfig.WALK_SPEED
	ctx = Context.new(character, humanoid, root)
	stamina = Stamina.new()
	table.insert(characterConnections, humanoid.Died:Connect(clearCharacter))
end

-- Boucle -------------------------------------------------------------------------------

local function onHeartbeat(dt: number)
	local context = ctx
	if context == nil then
		return
	end

	if action and not action.update(dt) then
		endAction()
	end

	local wantsSprint = sprintHeld or sprintToggled
	sprinting = mode == "Normal"
		and wantsSprint
		and isMoving(context)
		and Stamina.canSprint(stamina)
	Stamina.step(stamina, dt, sprinting, MovementConfig)
	if stamina.exhausted then
		sprintToggled = false
	end

	if mode == "Normal" then
		context.humanoid.WalkSpeed = if sprinting
			then MovementConfig.SPRINT_SPEED
			else MovementConfig.WALK_SPEED
	end
end

-- API publique (lecture seule, pour l'interface) ---------------------------------------

function MovementController.getStamina(): number
	return stamina.value
end

function MovementController.isExhausted(): boolean
	return stamina.exhausted
end

function MovementController.getMode(): Mode
	return mode
end

function MovementController.isSprinting(): boolean
	return sprinting
end

-- Temps restant avant de pouvoir réutiliser le grappin (secondes).
function MovementController.grappleCooldown(): number
	return math.max(0, MovementConfig.GRAPPLE_COOLDOWN - (os.clock() - lastGrapple))
end

function MovementController.start()
	bindInputs()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MovementController
