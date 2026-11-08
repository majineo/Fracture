--!strict
-- Contrôleur de déplacement du joueur local : sprint, glissade, escalade, grappin.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > MovementController
--
-- Un seul mouvement spécial à la fois (machine à états) :
--   Normal ──(glisser en courant)──▶ Slide ──(fin / saut)──▶ Normal
--   Normal ──(saut face à un rebord)──▶ Mantle ──(fin)──▶ Normal
--   Normal / Slide ──(grappin)──▶ Grapple ──(arrivée / saut = lâcher)──▶ Normal (ou Mantle)
--   Normal / Slide ──(élan)──▶ Dash ──(fin)──▶ Normal          (v0.4.11, sol ou air)
--   Normal (en l'air, le long d'un mur) ──▶ WallRun ──(saut = saut mural / fin)──▶ Normal
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
--   Élan     : F · manette croix ▲ · bouton tactile « Élan »
--   Course sur les murs : automatique ; saut pendant la course = saut mural
--   Roulade  : C en marchant (v0.9.0) ; C juste avant l'atterrissage = roulade de réception
--   Salto    : saut en l'air (v0.9.0), une fois par saut ; recharge au sol ou sur un mur

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
local CombatConfig = require(Shared:WaitForChild("Combat"):WaitForChild("CombatConfig")) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local Context = require(Client.Movement.Context)
local Grapple = require(Client.Movement.Grapple)
local Mantle = require(Client.Movement.Mantle)
local Slide = require(Client.Movement.Slide)
local Dash = require(Client.Movement.Dash)
local WallRun = require(Client.Movement.WallRun)
local Roll = require(Client.Movement.Roll)
local Flip = require(Client.Movement.Flip)

type Mode = "Normal" | "Slide" | "Mantle" | "Grapple" | "Dash" | "WallRun" | "Roll" | "Flip"

local ACTION_SPRINT = "Fracture_Sprint"
local ACTION_SLIDE = "Fracture_Slide"
local ACTION_GRAPPLE = "Fracture_Grapple"
local ACTION_DASH = "Fracture_Dash"

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
local lastDash = -math.huge
local airDashes = MovementConfig.DASH_AIR_CHARGES
local lastWallRunEnd = -math.huge
local wallSide = 0 -- 1 = mur à droite, -1 = à gauche (animations)
local lastRoll = -math.huge
local rollBufferedUntil = 0 -- roulade de réception demandée en l'air
local flips = MovementConfig.FLIP_CHARGES
local flipSign = 1 -- 1 = salto avant, -1 = arrière (animations)

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
	if mode == "WallRun" then
		lastWallRunEnd = os.clock()
		wallSide = 0
	end
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

-- À terre (attribut publié par le serveur) : on rampe, aucun mouvement spécial.
local function isDowned(context: Context.Context?): boolean
	return context ~= nil and context.character:GetAttribute("Downed") == true
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
	if context == nil or mode ~= "Normal" or not onGround(context) or isDowned(context) then
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

-- Élan : direction du mouvement (ou du regard), au sol ou une fois en l'air.
local function tryDash(): boolean
	local context = ctx
	if context == nil or isDowned(context) then
		return false
	end
	if mode ~= "Normal" and mode ~= "Slide" and mode ~= "Flip" and mode ~= "Roll" then
		return false
	end
	if os.clock() - lastDash < MovementConfig.DASH_COOLDOWN then
		return false
	end
	local airborne = not onGround(context)
	if airborne and airDashes <= 0 then
		return false
	end
	if not Stamina.spend(stamina, MovementConfig.DASH_STAMINA_COST, MovementConfig) then
		return false
	end
	if mode == "Slide" or mode == "Flip" or mode == "Roll" then
		endAction()
	end
	lastDash = os.clock()
	if airborne then
		airDashes -= 1
	end
	local direction = context.humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		local camera = workspace.CurrentCamera
		direction = if camera then camera.CFrame.LookVector else context.root.CFrame.LookVector
	end
	action = Dash.start(context, direction)
	setMode("Dash")
	return true
end

-- Roulade au sol (v0.9.0). `speed` : vitesse de départ (réception de chute).
local function tryRoll(speed: number?): boolean
	local context = ctx
	if context == nil or isDowned(context) or mode ~= "Normal" or not onGround(context) then
		return false
	end
	if os.clock() - lastRoll < MovementConfig.ROLL_COOLDOWN then
		return false
	end
	if not Stamina.spend(stamina, MovementConfig.ROLL_STAMINA_COST, MovementConfig) then
		return false
	end
	lastRoll = os.clock()
	rollBufferedUntil = 0
	slideBufferedUntil = 0
	local direction = context.humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		local horizontal = Context.horizontalVelocity(context)
		direction = if horizontal.Magnitude > 2 then horizontal else context.root.CFrame.LookVector
	end
	action = Roll.start(context, direction, speed)
	setMode("Roll")
	return true
end

-- Salto (v0.9.0) : second saut en l'air.
local function tryFlip(): boolean
	local context = ctx
	if context == nil or isDowned(context) or onGround(context) then
		return false
	end
	if mode ~= "Normal" or flips <= 0 then
		return false
	end
	if not Stamina.spend(stamina, MovementConfig.FLIP_STAMINA_COST, MovementConfig) then
		return false
	end
	flips -= 1
	local flipAction, sign = Flip.start(context)
	flipSign = sign
	action = flipAction
	setMode("Flip")
	return true
end

-- Course sur les murs : démarre seule quand on longe un mur en l'air, assez vite.
local function tryWallRun(context: Context.Context)
	if mode ~= "Normal" or onGround(context) or isDowned(context) then
		return
	end
	if os.clock() - lastWallRunEnd < MovementConfig.WALLRUN_COOLDOWN then
		return
	end
	if not isMoving(context) then
		return
	end
	if Context.horizontalVelocity(context).Magnitude < MovementConfig.WALLRUN_MIN_SPEED then
		return
	end
	local wall = WallRun.find(context, context.humanoid.MoveDirection)
	if wall == nil then
		return
	end
	airDashes = MovementConfig.DASH_AIR_CHARGES -- toucher un mur rend l'élan aérien
	flips = MovementConfig.FLIP_CHARGES -- et le salto
	wallSide = wall.side
	action = WallRun.start(context, wall)
	setMode("WallRun")
end

local function tryGrapple(useScreenCenter: boolean)
	local context = ctx
	if context == nil or mode == "Mantle" or mode == "Grapple" or isDowned(context) then
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
	if context == nil or mode ~= "Normal" or isDowned(context) then
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
	if mode == "WallRun" then
		endAction(true) -- saut mural
		airDashes = MovementConfig.DASH_AIR_CHARGES
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
		return
	end
	-- En l'air (après le coyote) : salto.
	if not onGround(context) and airborneFor > MovementConfig.COYOTE_TIME then
		tryFlip()
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

-- C : glissade si l'on court, roulade si l'on marche ; en l'air, roulade de réception.
local function pressSlide()
	local context = ctx
	if context and not onGround(context) then
		rollBufferedUntil = os.clock() + MovementConfig.ROLL_LANDING_WINDOW
		return
	end
	if trySlide() then
		return
	end
	if context ~= nil and isMoving(context) and tryRoll() then
		return
	end
	slideBufferedUntil = os.clock() + MovementConfig.INPUT_BUFFER
end

local function handleSlide(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		pressSlide()
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

local function handleDash(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		tryDash()
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	ContextActionService:BindAction(
		ACTION_DASH,
		handleDash,
		false,
		Enum.KeyCode.F,
		Enum.KeyCode.DPadUp
	)
	ContextActionService:BindAction(
		ACTION_SPRINT,
		handleSprint,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)
	-- Glissade : C, Ctrl, B. Dans Studio, Ctrl est retiré : Ctrl + A / Ctrl + D (en se
	-- déplaçant) y déclenchent « tout sélectionner » et « dupliquer » dans la fenêtre de test,
	-- ce qui copiait personnages et décor (v0.4.9). Le jeu publié garde Ctrl.
	if RunService:IsStudio() then
		ContextActionService:BindAction(
			ACTION_SLIDE,
			handleSlide,
			false,
			Enum.KeyCode.C,
			Enum.KeyCode.ButtonB
		)
	else
		ContextActionService:BindAction(
			ACTION_SLIDE,
			handleSlide,
			false,
			Enum.KeyCode.C,
			Enum.KeyCode.LeftControl,
			Enum.KeyCode.ButtonB
		)
	end
	ContextActionService:BindAction(
		ACTION_GRAPPLE,
		handleGrapple,
		false,
		Enum.KeyCode.G,
		Enum.KeyCode.ButtonR3
	)
	-- Écrans tactiles : boutons dédiés dans Controllers/MobileControls (pas de boutons Roblox).
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
		if not wasGrounded and mode == "Normal" then
			-- Roulade de réception : C pressé juste avant de toucher le sol après une chute.
			local rolled = false
			if
				os.clock() < rollBufferedUntil
				and peakFallSpeed >= MovementConfig.ROLL_LANDING_MIN_FALL
			then
				local keep = math.min(
					Context.horizontalVelocity(context).Magnitude,
					MovementConfig.SLIDE_SPEED
				)
				rolled = tryRoll(keep)
			end
			if not rolled and peakFallSpeed >= LANDING_MIN_SPEED then
				MovementController.Landed:Fire(peakFallSpeed)
			end
		end
		lastGroundedAt = os.clock()
		coyoteUsed = false
		airDashes = MovementConfig.DASH_AIR_CHARGES
		flips = MovementConfig.FLIP_CHARGES
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

	-- À terre : on interrompt tout mouvement spécial, on rampe, on ne saute plus.
	local downed = isDowned(context)
	if downed then
		if action then
			endAction()
		end
		sprintToggled = false
		sprinting = false
		context.humanoid.JumpHeight = 0
		context.humanoid.WalkSpeed = CombatConfig.DOWNED_WALK_SPEED
		Stamina.step(stamina, dt, false, MovementConfig)
		return
	elseif context.humanoid.JumpHeight == 0 then
		context.humanoid.JumpHeight = 7.2
	end

	-- Commandes retenues
	local now = os.clock()
	if now < slideBufferedUntil then
		trySlide()
	end
	if now < jumpBufferedUntil and mode == "Normal" and not onGround(context) then
		tryMantle()
	end
	tryWallRun(context)

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
		-- Ralenti par une capacité (bulle de stase, onde, Garde du Temps) : attributs serveur.
		local character = context.humanoid.Parent
		local slowedUntil = (character and character:GetAttribute("SlowUntil") :: number?) or 0
		local scale = if slowedUntil > workspace:GetServerTimeNow()
			then (character and character:GetAttribute("SlowFactor") :: number?) or 1
			else 1
		context.humanoid.WalkSpeed = Spring.step(speedSpring, dt) * scale
	end
end

-- API publique (lecture seule, pour l'interface, la caméra et les animations) ----------

-- Commandes tactiles (appelées par MobileControls) --------------------------------------

function MovementController.touchSprint()
	sprintToggled = not sprintToggled
end

function MovementController.touchSlide()
	pressSlide()
end

function MovementController.touchDash()
	tryDash()
end

-- Sens du salto en cours (1 = avant, -1 = arrière).
function MovementController.getFlipSign(): number
	return flipSign
end

-- Côté du mur pendant une course sur les murs (1 = droite, -1 = gauche, 0 = aucun).
function MovementController.getWallSide(): number
	return wallSide
end

-- Temps restant avant le prochain élan (secondes).
function MovementController.dashCooldown(): number
	return math.max(0, MovementConfig.DASH_COOLDOWN - (os.clock() - lastDash))
end

function MovementController.touchGrapple()
	tryGrapple(true) -- vise le centre de l'écran
end

function MovementController.isSprintToggled(): boolean
	return sprintToggled
end

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
		elseif command == "dash" then
			return tryDash()
		elseif command == "roll" then
			return tryRoll()
		elseif command == "slideKey" then
			pressSlide()
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
