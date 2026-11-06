--!strict
-- Contrôleur de déplacement du joueur local : sprint, glissade, escalade, grappin.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > MovementController
--
-- Un seul mouvement spécial à la fois (machine à états) :
--   Normal ──(glisser en courant)──▶ Slide ──(fin / saut)──▶ Normal
--   Normal ──(saut face à un rebord)──▶ Mantle ──(fin)──▶ Normal
--   Normal / Slide ──(grappin)──▶ Grapple ──(arrivée / saut = lâcher)──▶ Normal (ou Mantle)
--
-- Ressenti :
--   * la vitesse suit un ressort (accélération au démarrage, sortie de glissade sans à-coup) ;
--   * une commande pressée un peu trop tôt est retenue INPUT_BUFFER secondes ;
--   * on peut encore sauter COYOTE_TIME secondes après avoir quitté un rebord ;
--   * en arrivant au bout du grappin face à un rebord, on s'y hisse automatiquement.
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
local Spring = require(Shared.Util:WaitForChild("Spring")) :: any

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

local LANDING_MIN_SPEED = 8 -- vitesse de chute minimale pour signaler une réception

local player = Players.LocalPlayer

local MovementController = {}

-- (nouveauMode, ancienMode)
MovementController.ModeChanged = Signal.new()
-- (vitesse de chute en studs/s) : réception au sol après une chute.
MovementController.Landed = Signal.new()

local ctx: Context.Context? = nil
local mode: Mode = "Normal"
local action: Context.Action? = nil
local grappleTarget: Vector3? = nil
local stamina = Stamina.new()
local speedSpring = Spring.new(MovementConfig.WALK_SPEED, MovementConfig.ACCELERATION_STIFFNESS)
local sprintHeld = false -- clavier : maintenir
local sprintToggled = false -- tactile / manette : bascule
local sprinting = false
local lastSlide = -math.huge
local lastGrapple = -math.huge
local slideBufferedUntil = 0
local jumpBufferedUntil = 0
local lastGroundedAt = 0
local coyoteUsed = false
local wasGrounded = true
local peakFallSpeed = 0
local characterConnections: { RBXScriptConnection } = {}

local function setMode(newMode: Mode)
	if newMode == mode then
		return
	end
	local old = mode
	mode = newMode
	Net.fire("MovementMode", newMode)
	MovementController.ModeChanged:Fire(newMode, old)
end

local function endAction(boost: boolean?)
	local current = action
	local wasGrapple = mode == "Grapple"
	action = nil
	grappleTarget = nil
	setMode("Normal")
	if current then
		current.stop(boost)
	end
	if wasGrapple then
		Net.fire("GrappleEnd")
	end
	-- La vitesse repart de la vitesse réelle : pas d'à-coup en sortie de mouvement.
	local context = ctx
	if context then
		Spring.snap(
			speedSpring,
			math.max(MovementConfig.START_SPEED, Context.horizontalVelocity(context).Magnitude)
		)
	end
end

local function isMoving(context: Context.Context): boolean
	return context.humanoid.MoveDirection.Magnitude > 0.1
end

local function onGround(context: Context.Context): boolean
	return context.humanoid.FloorMaterial ~= Enum.Material.Air
end

-- Actions ------------------------------------------------------------------------------

local function startMantle(context: Context.Context, target: CFrame)
	context.humanoid.Jump = false
	action = Mantle.start(context, target)
	setMode("Mantle")
end

-- Renvoie true si la glissade a démarré.
local function trySlide(): boolean
	local context = ctx
	if context == nil or mode ~= "Normal" or not onGround(context) then
		return false
	end
	if os.clock() - lastSlide < MovementConfig.SLIDE_COOLDOWN then
		return false
	end
	local horizontal = Context.horizontalVelocity(context)
	if horizontal.Magnitude < MovementConfig.SLIDE_MIN_SPEED then
		return false
	end
	if not Stamina.spend(stamina, MovementConfig.SLIDE_STAMINA_COST, MovementConfig) then
		return false
	end
	lastSlide = os.clock()
	slideBufferedUntil = 0
	action = Slide.start(context, horizontal)
	setMode("Slide")
	return true
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
	grappleTarget = target
	action = Grapple.start(context, target)
	setMode("Grapple")
	Net.fire("GrappleStart", target)
end

-- Renvoie true si une escalade a démarré.
local function tryMantle(reach: number?): boolean
	local context = ctx
	if context == nil or mode ~= "Normal" then
		return false
	end
	local target = Mantle.find(context, reach)
	if target then
		jumpBufferedUntil = 0
		startMantle(context, target)
		return true
	end
	return false
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
	if mode ~= "Normal" then
		return
	end
	if tryMantle() then
		return
	end
	-- Pas de rebord maintenant : on retient la commande un court instant (saut puis rebord).
	jumpBufferedUntil = os.clock() + MovementConfig.INPUT_BUFFER
	-- Saut « coyote » : juste après avoir quitté le sol, le saut reste possible.
	local airborneFor = os.clock() - lastGroundedAt
	if not onGround(context) and not coyoteUsed and airborneFor <= MovementConfig.COYOTE_TIME then
		coyoteUsed = true
		context.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
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
	if state == Enum.UserInputState.Begin and not trySlide() then
		slideBufferedUntil = os.clock() + MovementConfig.INPUT_BUFFER
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
	Spring.snap(speedSpring, MovementConfig.WALK_SPEED)
	table.insert(characterConnections, humanoid.Died:Connect(clearCharacter))
end

-- Boucle -------------------------------------------------------------------------------

local function updateGrounding(context: Context.Context)
	local grounded = onGround(context)
	local vy = context.root.AssemblyLinearVelocity.Y
	if grounded then
		if not wasGrounded and peakFallSpeed >= LANDING_MIN_SPEED and mode == "Normal" then
			MovementController.Landed:Fire(peakFallSpeed)
		end
		lastGroundedAt = os.clock()
		coyoteUsed = false
		peakFallSpeed = 0
	else
		peakFallSpeed = math.max(peakFallSpeed, -vy)
	end
	wasGrounded = grounded
end

local function onHeartbeat(dt: number)
	local context = ctx
	if context == nil then
		return
	end

	if action and not action.update(dt) then
		local finishedGrapple = mode == "Grapple"
		endAction()
		-- Arrivée au bout du grappin face à un rebord : on s'y hisse.
		if finishedGrapple then
			tryMantle(MovementConfig.GRAPPLE_MANTLE_REACH)
		end
	end

	updateGrounding(context)

	-- Commandes retenues
	local now = os.clock()
	if now < slideBufferedUntil then
		trySlide()
	end
	if now < jumpBufferedUntil and mode == "Normal" and not onGround(context) then
		tryMantle()
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
		if isMoving(context) then
			speedSpring.target = if sprinting
				then MovementConfig.SPRINT_SPEED
				else MovementConfig.WALK_SPEED
		else
			-- À l'arrêt, on « recharge » la vitesse de départ : le prochain pas accélère.
			Spring.snap(speedSpring, MovementConfig.START_SPEED)
		end
		context.humanoid.WalkSpeed = Spring.step(speedSpring, dt)
	end
end

-- API publique (lecture seule, pour l'interface, la caméra et les animations) ----------

function MovementController.getStamina(): number
	return stamina.value
end

function MovementController.isExhausted(): boolean
	return stamina.exhausted
end

function MovementController.getMode(): Mode
	return mode
end

function MovementController.getProgress(): number
	return if action then action.progress() else 0
end

function MovementController.getGrappleTarget(): Vector3?
	return grappleTarget
end

function MovementController.isSprinting(): boolean
	return sprinting
end

-- Temps restant avant de pouvoir réutiliser le grappin (secondes).
function MovementController.grappleCooldown(): number
	return math.max(0, MovementConfig.GRAPPLE_COOLDOWN - (os.clock() - lastGrapple))
end

-- Studio uniquement : point d'entrée de test qui simule les commandes du joueur
-- (la simulation de touches de Studio n'atteint pas le jeu). Jamais créé en jeu publié.
local function createStudioTestHook()
	local hook = Instance.new("BindableFunction")
	hook.Name = "FractureMovementQA"
	local forcedMove: Vector3? = nil
	-- Joystick simulé : appliqué juste APRÈS le module de contrôle Roblox (priorité Input + 1),
	-- sinon celui-ci remet la direction à zéro à chaque image.
	RunService:BindToRenderStep("FractureQAMove", Enum.RenderPriority.Input.Value + 1, function()
		local context = ctx
		if forcedMove and context then
			context.humanoid:Move(forcedMove, false)
		end
	end)
	hook.OnInvoke = function(command: string, argument: any): any
		if command == "move" then
			forcedMove = if typeof(argument) == "Vector3" then argument else nil
			if forcedMove == nil and ctx then
				ctx.humanoid:Move(Vector3.zero, false)
			end
		elseif command == "sprint" then
			sprintHeld = argument == true
		elseif command == "slide" then
			return trySlide()
		elseif command == "jump" then
			onJumpRequest()
		elseif command == "grapple" and typeof(argument) == "Vector3" then
			local context = ctx
			if context then
				lastGrapple = -math.huge
				grappleTarget = argument
				action = Grapple.start(context, argument)
				setMode("Grapple")
				Net.fire("GrappleStart", argument)
			end
		end
		return { mode = mode, stamina = stamina.value, walkSpeed = ctx and ctx.humanoid.WalkSpeed }
	end
	hook.Parent = player:WaitForChild("PlayerScripts")
end

function MovementController.start()
	if RunService:IsStudio() then
		createStudioTestHook()
	end
	bindInputs()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MovementController
