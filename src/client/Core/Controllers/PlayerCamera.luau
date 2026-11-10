--!strict
-- Caméra du joueur (Update 2.0, phase 2) : UNE caméra maison pour tous les cas — avec ou sans
-- arme, souris, écran tactile, manette — à la place de l'ancienne ShoulderCamera (arme en main
-- sur PC seulement) et de la caméra Roblox (le reste du temps).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > PlayerCamera
--
-- Trois vues (F5 sur PC, bouton « Vue » sur mobile), comme dans Minecraft :
--   première personne → vue de dos → vue de face → première personne…
-- Arme en main, la vue de face devient la vue de dos (on ne vise pas en regardant son visage) ;
-- la préférence est gardée pour la session.
--
-- Ressenti (calculs purs et réglages dans Shared/Camera/CameraMotion, testés) :
--   * la rotation suit l'entrée sans aucun lissage (pas de retard sur la visée) ;
--   * le point suivi est lissé par des ressorts (léger retard à l'accélération, léger
--     dépassement à l'arrêt, sauts amortis) avec une petite anticipation dans le sens du
--     mouvement ; balancement de course et inclinaison en pas chassé très discrets, effacés
--     en visée ;
--   * collision par sphère : la caméra rentre instantanément devant un mur, ressort doucement ;
--   * personnage estompé quand la caméra s'en approche, caché en première personne (bras et
--     arme visibles) et à la lunette — cette caméra est le SEUL script qui écrit
--     LocalTransparencyModifier sur son propre personnage.
--
-- Ordre d'exécution : cette caméra (priorité Camera) → CameraFeel (Camera + 1 : champ de
-- vision, roulis, recul) → CombatController (Camera + 2) qui appelle PlayerCamera.set().

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spring = require(Shared:WaitForChild("Util"):WaitForChild("Spring")) :: any
local CameraMotion = require(Shared:WaitForChild("Camera"):WaitForChild("CameraMotion")) :: any
local Menu = require(script.Parent.Parent.Ui.Menu)
local CameraFeel = require(script.Parent.CameraFeel)

type Perspective = "Behind" | "Front" | "First"

local C = CameraMotion.CONFIG
local MOUSE_DEGREES_PER_PIXEL = 0.25
local TOUCH_DEGREES_PER_PIXEL = 0.3
local GAMEPAD_DEGREES_PER_SECOND = 230
local GAMEPAD_DEADZONE = 0.15
local HEAD_PROBE_RADIUS = 0.4
local SCOPE_FOV = 40 -- en dessous : vue à la lunette, personnage caché

local player = Players.LocalPlayer

local PlayerCamera = {}

-- État
local preferred: Perspective = "Behind"
local armed = false
local aiming = false
local yaw = 0
local pitch = 0
local zoom = C.DISTANCE_UNARMED
local initialised = false
local boomCurrent = C.DISTANCE_UNARMED
local phase = 0
local rmbHeld = false
local cameraTouch: InputObject? = nil
local touchDelta = Vector2.zero
local stick = Vector2.zero

local focusX = Spring.new(0, C.FOLLOW_H_SPEED, C.FOLLOW_H_DAMPING)
local focusY = Spring.new(0, C.FOLLOW_V_SPEED)
local focusZ = Spring.new(0, C.FOLLOW_H_SPEED, C.FOLLOW_H_DAMPING)
local leadX = Spring.new(0, 5)
local leadZ = Spring.new(0, 5)
local distance = Spring.new(C.DISTANCE_UNARMED, C.TRANSITION_SPEED)
local yawOffset = Spring.new(0, C.TRANSITION_SPEED)
local shoulderWeight = Spring.new(1, C.TRANSITION_SPEED)
local strafe = Spring.new(0, 8)
local effectsWeight = Spring.new(1, 8) -- balancement / inclinaison (0 en visée)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true -- flammes, lueurs, cristaux : la caméra les traverse

-- Transparence locale du personnage (valeurs appliquées, pour n'écrire qu'aux changements).
local appliedBody = -1
local appliedArms = -1

local function usesMouse(): boolean
	local last = UserInputService:GetLastInputType()
	return UserInputService.MouseEnabled
		and last ~= Enum.UserInputType.Touch
		and not string.find(last.Name, "Gamepad", 1, true)
end

-- Pièces des bras (R15 et R6). Liste exacte : « Handle » (pièce de chaque accessoire) contient
-- « Hand » et laissait les lunettes de l'avatar devant les yeux (trouvé en test, Update 2.0).
local ARM_PARTS: { [string]: boolean } = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
}

local function isArmPart(part: Instance): boolean
	return ARM_PARTS[part.Name] == true and part.Parent ~= nil and part.Parent:IsA("Model")
end

local function inWeapon(part: Instance, character: Model): boolean
	local held = character:FindFirstChild("HeldWeapon")
	return held ~= nil and part:IsDescendantOf(held)
end

-- Applique la transparence locale : `body` au corps, `arms` aux bras et à l'arme tenue.
local function applyTransparency(character: Model, body: number, arms: number)
	if math.abs(body - appliedBody) < 0.02 and math.abs(arms - appliedArms) < 0.02 then
		return
	end
	appliedBody, appliedArms = body, arms
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local keep = isArmPart(d) or inWeapon(d, character)
			d.LocalTransparencyModifier = if keep then arms else body
		end
	end
end

-- Exclusion de la sonde : son personnage, ceux des autres joueurs, les effets locaux.
local function refreshFilter(character: Model)
	local list: { Instance } = { character }
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(list, other.Character)
		end
	end
	local fx = workspace:FindFirstChild("DecorFx")
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
end

local function snapTo(root: BasePart)
	local p = root.Position + Vector3.new(0, C.EYE_HEIGHT, 0)
	Spring.snap(focusX, p.X)
	Spring.snap(focusY, p.Y)
	Spring.snap(focusZ, p.Z)
	Spring.snap(leadX, 0)
	Spring.snap(leadZ, 0)
end

-- Appelé chaque image par CombatController.
function PlayerCamera.set(isArmed: boolean, isAiming: boolean)
	armed = isArmed
	aiming = isAiming
end

-- La caméra maison est-elle aux commandes ? (toujours, une fois démarrée)
function PlayerCamera.isActive(): boolean
	return initialised
end

-- Vue réellement utilisée.
function PlayerCamera.perspective(): Perspective
	return CameraMotion.effective(preferred, armed)
end

-- Le personnage doit-il regarder où regarde la caméra (première personne) ?
function PlayerCamera.facesCamera(): boolean
	return PlayerCamera.perspective() == "First"
end

-- Passe à la vue suivante (F5, bouton mobile).
function PlayerCamera.cycle()
	preferred = CameraMotion.nextPerspective(preferred)
	player:SetAttribute("CameraPerspective", preferred) -- local : sert au HUD et aux tests
end

-- Choisit une vue (tests, réglages).
function PlayerCamera.setPerspective(p: Perspective)
	preferred = p
	player:SetAttribute("CameraPerspective", preferred)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		rmbHeld = true
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbHeld = false
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		if not armed and PlayerCamera.perspective() == "Behind" and not Menu.isOpen() then
			zoom = math.clamp(zoom - input.Position.Z * 1.5, C.ZOOM_MIN, C.ZOOM_MAX)
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.new(input.Position.X, input.Position.Y)
	end
end

-- Toucher : un doigt posé hors des boutons et du joystick tourne la vue.
local function onTouchStarted(touch: InputObject, processed: boolean)
	if not processed and cameraTouch == nil then
		cameraTouch = touch
	end
end

local function onTouchMoved(touch: InputObject)
	if touch == cameraTouch then
		touchDelta += Vector2.new(touch.Delta.X, touch.Delta.Y)
	end
end

local function onTouchEnded(touch: InputObject)
	if touch == cameraTouch then
		cameraTouch = nil
	end
end

local function readRotation(dt: number)
	local menuOpen = Menu.isOpen()
	local view = PlayerCamera.perspective()
	local fov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
	local zoomFactor = math.clamp(fov / 70, 0.2, 1)
	local dx, dy = 0, 0

	if menuOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	elseif usesMouse() then
		local locked = armed or view == "First"
		local behavior = if locked
			then Enum.MouseBehavior.LockCenter
			elseif rmbHeld then Enum.MouseBehavior.LockCurrentPosition
			else Enum.MouseBehavior.Default
		UserInputService.MouseBehavior = behavior
		UserInputService.MouseIconEnabled = not locked
		if behavior ~= Enum.MouseBehavior.Default then
			local delta = UserInputService:GetMouseDelta()
			local k = MOUSE_DEGREES_PER_PIXEL * UserGameSettings.MouseSensitivity * zoomFactor
			dx += delta.X * k
			dy += delta.Y * k
		end
	end

	if not menuOpen then
		local k = TOUCH_DEGREES_PER_PIXEL * zoomFactor
		dx += touchDelta.X * k
		dy += touchDelta.Y * k
		local s = stick
		if s.Magnitude > GAMEPAD_DEADZONE then
			local g = GAMEPAD_DEGREES_PER_SECOND * dt * zoomFactor
			dx += s.X * math.abs(s.X) * g
			dy -= s.Y * math.abs(s.Y) * g
		end
	end
	touchDelta = Vector2.zero

	local maxPitch = math.rad(if view == "First" then C.MAX_PITCH_FIRST else C.MAX_PITCH)
	yaw -= math.rad(dx)
	pitch = math.clamp(pitch - math.rad(dy), -maxPitch, maxPitch)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		camera == nil
		or character == nil
		or root == nil
		or not root:IsA("BasePart")
		or humanoid == nil
	then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if not initialised then
		local look = root.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.rad(-12)
		snapTo(root)
		initialised = true
	end

	readRotation(dt)

	local view = PlayerCamera.perspective()
	local velocity = root.AssemblyLinearVelocity
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

	-- Transitions entre vues.
	distance.target = CameraMotion.distanceFor(view, armed, aiming, zoom)
	yawOffset.target = if view == "Front" then math.pi else 0
	shoulderWeight.target = if view == "Behind" then 1 else 0
	effectsWeight.target = if aiming or view == "Front" then 0 else 1
	local d = math.max(0, Spring.step(distance, dt))
	local off = Spring.step(yawOffset, dt)
	local sw = Spring.step(shoulderWeight, dt)
	local ew = Spring.step(effectsWeight, dt)
	local firstWeight = math.clamp(1 - d / 1.5, 0, 1)

	-- Point suivi : ressorts (souples en vertical), recalés après une téléportation.
	local eye = root.Position + Vector3.new(0, C.EYE_HEIGHT, 0)
	local current = Vector3.new(focusX.position, focusY.position, focusZ.position)
	if (eye - current).Magnitude > C.SNAP_DISTANCE then
		snapTo(root)
	end
	local speedBoost = if aiming then 1.6 else 1
	focusX.speed = C.FOLLOW_H_SPEED * speedBoost
	focusZ.speed = C.FOLLOW_H_SPEED * speedBoost
	focusX.target, focusY.target, focusZ.target = eye.X, eye.Y, eye.Z
	local smoothed =
		Vector3.new(Spring.step(focusX, dt), Spring.step(focusY, dt), Spring.step(focusZ, dt))
	-- En première personne, pas de retard : on suit les yeux directement.
	local focus = smoothed:Lerp(eye, firstWeight)

	-- Anticipation dans le sens du mouvement (vue de dos seulement).
	local lx, lz = CameraMotion.lead(velocity.X, velocity.Z)
	leadX.target = lx * sw * ew
	leadZ.target = lz * sw * ew
	local lead = Vector3.new(Spring.step(leadX, dt), 0, Spring.step(leadZ, dt))

	-- Rotation de la vue (aucun lissage) ; en vue de face, la caméra tourne autour du personnage.
	local pitchSign = math.cos(off)
	local rotation = CFrame.Angles(0, yaw + off, 0) * CFrame.Angles(pitch * pitchSign, 0, 0)

	-- Balancement de course et inclinaison en pas chassé.
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local groundSpeed = if grounded then horizontal.Magnitude else 0
	phase = CameraMotion.stride(phase, groundSpeed, dt)
	local bobHeight, bobRoll = CameraMotion.bob(phase, groundSpeed, ew)
	local lateral = horizontal:Dot(rotation.RightVector)
	strafe.target = CameraMotion.strafeRoll(lateral, ew)
	local roll = Spring.step(strafe, dt) + bobRoll

	-- Pivot : épaule (vue de dos, décalage fourni par CameraFeel), yeux en première personne.
	local offset = humanoid.CameraOffset
	local thirdPivot = focus
		+ rotation:VectorToWorldSpace(Vector3.new(offset.X * sw, 0, 0))
		+ Vector3.new(0, offset.Y + bobHeight, 0)
		+ lead
	local look = rotation.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.zero
	local eyePivot = root.Position
		+ Vector3.new(0, C.FIRST_PERSON_EYE + offset.Y * 0.5 + bobHeight * 0.5, 0)
		+ flatLook * C.FIRST_PERSON_FORWARD
	local pivot = thirdPivot:Lerp(eyePivot, firstWeight)

	-- Collision 1 : le pivot ne doit pas entrer dans un mur (épaule contre une paroi).
	refreshFilter(character)
	local head = eye
	local toPivot = pivot - head
	if toPivot.Magnitude > 0.05 then
		local hit = workspace:Spherecast(head, HEAD_PROBE_RADIUS, toPivot, params)
		if hit then
			pivot = head + toPivot.Unit * math.max(0, hit.Distance - 0.1)
		end
	end

	-- Collision 2 : perche de la caméra derrière le pivot.
	local back = rotation:VectorToWorldSpace(Vector3.new(0, 0, 1))
	if d > 0.3 then
		local hit = workspace:Spherecast(pivot, C.PROBE_RADIUS, back * d, params)
		local free = CameraMotion.freeDistance(d, if hit then hit.Distance else nil)
		boomCurrent = math.min(CameraMotion.boom(boomCurrent, free, dt), d)
	else
		boomCurrent = d
	end

	local position = pivot + back * boomCurrent
	camera.CFrame = CFrame.new(position) * rotation * CFrame.Angles(0, 0, math.rad(roll))
	camera.Focus = CFrame.new(pivot)

	-- Personnage : caché à la lunette, en première personne (bras et arme visibles), estompé
	-- quand la caméra le frôle.
	local scoped = CameraFeel.isScoped() and camera.FieldOfView < SCOPE_FOV
	local near = CameraMotion.fade((position - eye).Magnitude)
	local body, arms
	if scoped then
		body, arms = 1, 1
	elseif firstWeight > 0.6 then
		body, arms = 1, 0
	else
		body, arms = near, near
	end
	applyTransparency(character, body, arms)
end

-- Vue de face : les commandes de déplacement (relatives à la caméra pour Roblox) sont
-- ramenées dans le repère de la vue du joueur, sinon avancer ferait reculer vers la caméra.
local function correctMove()
	if math.abs(yawOffset.position) < 0.02 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local move = humanoid.MoveDirection
	if move.Magnitude < 0.01 then
		return
	end
	local x, z = CameraMotion.rotateFlat(move.X, move.Z, -yawOffset.position)
	humanoid:Move(Vector3.new(x, 0, z), false)
end

function PlayerCamera.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.TouchStarted:Connect(onTouchStarted)
	UserInputService.TouchMoved:Connect(onTouchMoved)
	UserInputService.TouchEnded:Connect(onTouchEnded)

	ContextActionService:BindAction("FracturePerspective", function(_, state)
		if state == Enum.UserInputState.Begin and not Menu.isOpen() then
			PlayerCamera.cycle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F5)

	RunService:BindToRenderStep(
		"FractureViewMove",
		Enum.RenderPriority.Input.Value + 2,
		correctMove
	)
	RunService:BindToRenderStep("FracturePlayerCamera", Enum.RenderPriority.Camera.Value, update)

	local function watch(character: Model)
		initialised = false
		appliedBody, appliedArms = -1, -1
		boomCurrent = distance.position
		-- Arme dégainée, armure ajoutée… : on réapplique la transparence aux nouvelles pièces.
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Decal") then
				appliedBody, appliedArms = -1, -1
			end
		end)
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	player:SetAttribute("CameraPerspective", preferred)
end

return PlayerCamera
