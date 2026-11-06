--!strict
-- Combat du joueur local : choix de l'arme, visée, tir, mêlée, rechargement.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > CombatController
--
-- Le client tire immédiatement à l'écran (traçante, son, recul) pour la réactivité, puis
-- envoie au serveur l'origine, la direction et l'heure du tir. Le serveur décide seul de ce
-- qui est touché (voir Server > Systems > WeaponService) et renvoie la confirmation.
--
-- Contrôles (GDD 03-combat §1) :
--   Arme 1 / 2   : 1 / 2 (appuyer de nouveau = ranger) · manette croix ◀ / ▶ · bouton « Arme »
--   Tirer        : clic gauche · RT · bouton « Tirer »   (lame : maintenir = attaque chargée)
--   Viser        : clic droit (maintenir) · LT · bouton « Viser » (bascule)
--   Recharger    : R · X · bouton « Recharger »
-- Arme en main sur PC : la souris est verrouillée au centre (réticule), le personnage suit la
-- caméra, la caméra se place par-dessus l'épaule.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = Shared:WaitForChild("Combat")
local WeaponDefs = require(Combat:WaitForChild("WeaponDefs")) :: any
local WeaponState = require(Combat:WaitForChild("WeaponState")) :: any
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal")) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local CombatSounds = require(Client.Combat.CombatSounds)
local WeaponFx = require(Client.Combat.WeaponFx)
local CameraFeel = require(script.Parent.CameraFeel)
local MovementController = require(script.Parent.MovementController)
local ShoulderCamera = require(script.Parent.ShoulderCamera)

local LOADOUT = { "weapon.fracture_pistol", "weapon.short_blade" } -- miroir du serveur (v0.4.0)
local AIM_RANGE = 400
local MOVE_SPREAD = 1.2 -- degrés ajoutés en courant
local AIR_SPREAD = 2 -- degrés ajoutés en l'air
local SPREAD_RECOVERY = 10 -- vitesse de retour de la dispersion après un tir
local SHOT_BLOOM = 0.9 -- degrés ajoutés par tir
local FACE_SPEED = 20

local ACTIONS = {
	fire = "Fracture_Fire",
	aim = "Fracture_Aim",
	reload = "Fracture_Reload",
	weapon1 = "Fracture_Weapon1",
	weapon2 = "Fracture_Weapon2",
	cycle = "Fracture_WeaponCycle",
}

local player = Players.LocalPlayer

local CombatController = {}

-- (idArme ou nil)
CombatController.Equipped = Signal.new()
-- (informations de touche confirmée par le serveur)
CombatController.HitConfirmed = Signal.new()
-- (montant, position d'origine)
CombatController.Damaged = Signal.new()
-- ()
CombatController.Fired = Signal.new()

local equippedSlot = 0
local states: { [string]: any } = {}
local aimHeld = false -- souris / manette : maintenir
local aimToggled = false -- tactile : bascule
local meleeChargeStart: number? = nil
local bloom = 0
local lastSwing: { at: number, heavy: boolean }? = nil
local remoteSwings: { [Player]: { at: number, heavy: boolean } } = {}
local aimPoint: Vector3? = nil

for _, id in LOADOUT do
	states[id] = WeaponState.new(WeaponDefs[id])
end

local function character(): Model?
	return player.Character
end

local function currentDef(): any
	local id = LOADOUT[equippedSlot]
	return if id then WeaponDefs[id] else nil
end

local function isDowned(): boolean
	local c = character()
	return c ~= nil and c:GetAttribute("Downed") == true
end

-- Peut-on utiliser son arme dans le mode de déplacement actuel ?
local function canUseWeapon(): boolean
	if isDowned() then
		return false
	end
	local mode = MovementController.getMode()
	return mode == "Normal" or mode == "Slide"
end

local function isAiming(): boolean
	return (aimHeld or aimToggled) and equippedSlot ~= 0 and canUseWeapon()
end

local qaAimOverride: Vector3? = nil -- Studio uniquement (tests)

-- Point visé : rayon depuis le centre de l'écran.
local function computeAimPoint(): Vector3?
	if qaAimOverride then
		return qaAimOverride
	end
	local camera = workspace.CurrentCamera
	local c = character()
	if camera == nil or c == nil then
		return nil
	end
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * AIM_RANGE
end

local function muzzlePosition(): Vector3?
	local c = character()
	if c == nil then
		return nil
	end
	local held = c:FindFirstChild("HeldWeapon")
	local muzzle = held and held:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	local hand = c:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1, 0) else nil
end

-- Dispersion actuelle (degrés) : base de l'arme + mouvement + saut + tirs récents.
function CombatController.getSpread(): number
	local def = currentDef()
	if def == nil or def.kind ~= "Hitscan" then
		return 0
	end
	local base = if isAiming() then def.spreadAim else def.spreadHip
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local extra = 0
	if root and root:IsA("BasePart") then
		local v = root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > 15 then
			extra += MOVE_SPREAD
		end
	end
	if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
		extra += AIR_SPREAD
	end
	local aimFactor = if isAiming() then 0.4 else 1
	return base + (extra + bloom) * aimFactor
end

-- Direction au hasard dans un cône de `degrees` autour de `direction`.
local function applySpread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Actions -----------------------------------------------------------------------------

local function equip(slot: number)
	if slot == equippedSlot then
		slot = 0 -- même touche = ranger l'arme
	end
	local previous = LOADOUT[equippedSlot]
	if previous then
		WeaponState.cancelReload(states[previous])
	end
	equippedSlot = slot
	meleeChargeStart = nil
	Net.fire("EquipWeapon", slot)
	CombatController.Equipped:Fire(LOADOUT[slot])
end

local function reload()
	local def = currentDef()
	if def == nil or def.magazine <= 0 or not canUseWeapon() then
		return
	end
	if WeaponState.reload(states[def.id], def, os.clock()) then
		Net.fire("ReloadWeapon")
		CombatSounds.play2D("Reload")
	end
end

local function fireHitscan(def: any)
	local state = states[def.id]
	local now = os.clock()
	if WeaponState.isReloading(state, now, def) then
		return
	end
	if state.ammo <= 0 then
		CombatSounds.play2D("DryFire")
		reload()
		return
	end
	if not WeaponState.canFire(state, def, now) then
		return
	end
	local origin = muzzlePosition()
	local target = computeAimPoint()
	if origin == nil or target == nil then
		return
	end
	WeaponState.fire(state, def, now)

	local direction = applySpread((target - origin).Unit, CombatController.getSpread())
	bloom = math.min(bloom + SHOT_BLOOM, 4)

	-- Affichage immédiat (le serveur confirmera les touches).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character() :: Model }
	local hit = workspace:Raycast(origin, direction * def.range, params)
	local finish = if hit then hit.Position else origin + direction * def.range
	WeaponFx.tracer(origin, finish)
	WeaponFx.muzzleFlash(origin, direction)
	if hit and not hit.Instance:FindFirstAncestorOfClass("Model") then
		WeaponFx.impact(hit.Position, hit.Normal, hit.Instance.Color)
	elseif hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Health") == nil then
			WeaponFx.impact(hit.Position, hit.Normal, hit.Instance.Color)
		end
	end
	CombatSounds.play2D("PistolShot", 0.95 + math.random() * 0.1)
	CameraFeel.kick(def.recoil)
	CombatController.Fired:Fire()

	Net.fire("FireWeapon", origin, direction, workspace:GetServerTimeNow())

	if state.ammo <= 0 then
		task.delay(0.15, reload)
	end
end

local function swing(def: any, heavy: boolean)
	local state = states[def.id]
	local now = os.clock()
	if not WeaponState.canFire(state, def, now) then
		return
	end
	WeaponState.fire(state, def, now)
	if heavy then
		state.lastShot = now + (2.2 - 1) / def.fireRate
	end
	local camera = workspace.CurrentCamera
	local direction = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	lastSwing = { at = now, heavy = heavy }
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		WeaponFx.swingArc(root, heavy)
	end
	CombatSounds.play2D(if heavy then "HeavySwing" else "Swing", 0.95 + math.random() * 0.1)
	CameraFeel.kick(if heavy then 1.2 else 0.5)
	Net.fire("MeleeSwing", heavy, direction, workspace:GetServerTimeNow())
end

-- Entrées ------------------------------------------------------------------------------

local function handleFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local def = currentDef()
	if def == nil then
		return Enum.ContextActionResult.Pass -- mains nues : le clic garde son rôle normal
	end
	if not canUseWeapon() then
		meleeChargeStart = nil
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		if def.kind == "Hitscan" then
			fireHitscan(def) -- arme semi-automatique : un tir par pression
		else
			meleeChargeStart = os.clock()
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if def.kind == "Melee" and meleeChargeStart then
			local held = os.clock() - meleeChargeStart
			meleeChargeStart = nil
			swing(def, held >= (def.heavyChargeTime or 0.6))
		end
	end
	return Enum.ContextActionResult.Sink
end

local function handleAim(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if currentDef() == nil then
		return Enum.ContextActionResult.Pass
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Enum.UserInputState.Begin then
			aimToggled = not aimToggled
		end
	else
		aimHeld = state == Enum.UserInputState.Begin
	end
	return Enum.ContextActionResult.Sink
end

local function handleReload(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		reload()
	end
	return Enum.ContextActionResult.Sink
end

local function slotHandler(slot: number)
	return function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin and not isDowned() then
			equip(slot)
		end
		return Enum.ContextActionResult.Sink
	end
end

local function handleCycle(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and not isDowned() then
		-- Mains nues → arme 1 → arme 2 → … → mains nues.
		local nextSlot = equippedSlot + 1
		if nextSlot > #LOADOUT then
			equip(equippedSlot) -- même emplacement = ranger
		else
			equip(nextSlot)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	ContextActionService:BindAction(
		ACTIONS.fire,
		handleFire,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(
		ACTIONS.aim,
		handleAim,
		true,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindAction(
		ACTIONS.reload,
		handleReload,
		true,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:BindAction(
		ACTIONS.weapon1,
		slotHandler(1),
		false,
		Enum.KeyCode.One,
		Enum.KeyCode.DPadLeft
	)
	ContextActionService:BindAction(
		ACTIONS.weapon2,
		slotHandler(2),
		false,
		Enum.KeyCode.Two,
		Enum.KeyCode.DPadRight
	)
	-- Mobile : un bouton qui fait défiler pistolet → lame → mains nues.
	ContextActionService:BindAction(ACTIONS.cycle, handleCycle, true)
	ContextActionService:SetTitle(ACTIONS.fire, "Tirer")
	ContextActionService:SetTitle(ACTIONS.aim, "Viser")
	ContextActionService:SetTitle(ACTIONS.reload, "Recharger")
	ContextActionService:SetTitle(ACTIONS.cycle, "Arme")
end

-- Réseau -------------------------------------------------------------------------------

local function onWeaponState(id: any, ammo: any, reloadRemaining: any)
	local state = typeof(id) == "string" and states[id]
	local def = typeof(id) == "string" and WeaponDefs[id]
	if not state or not def or typeof(ammo) ~= "number" then
		return
	end
	-- Le serveur fait foi : on se recale sur lui.
	state.ammo = ammo
	if typeof(reloadRemaining) == "number" and reloadRemaining > 0 then
		state.reloadEndsAt = os.clock() + reloadRemaining
	end
end

local function onCombatEvent(info: any)
	if typeof(info) ~= "table" then
		return
	end
	if info.type == "Hit" then
		CombatController.HitConfirmed:Fire(info)
		CombatSounds.play2D(
			if info.killed then "Kill" else "Hit",
			if info.headshot then 1.35 else 1
		)
		if typeof(info.position) == "Vector3" and typeof(info.amount) == "number" then
			WeaponFx.damageNumber(
				info.position,
				info.amount,
				info.headshot == true,
				info.killed == true
			)
		end
	elseif info.type == "Damaged" then
		CombatController.Damaged:Fire(info.amount, info.from)
		CameraFeel.kick(-1.5)
	end
end

local function onShotFx(info: any)
	if typeof(info) ~= "table" or typeof(info.shooter) ~= "Instance" then
		return
	end
	if
		info.kind == "Shot"
		and typeof(info.origin) == "Vector3"
		and typeof(info.finish) == "Vector3"
	then
		WeaponFx.tracer(info.origin, info.finish)
		WeaponFx.muzzleFlash(info.origin, (info.finish - info.origin).Unit)
		CombatSounds.playAt("PistolShot", info.origin)
	elseif info.kind == "Swing" or info.kind == "HeavySwing" then
		local heavy = info.kind == "HeavySwing"
		remoteSwings[info.shooter] = { at = os.clock(), heavy = heavy }
		local c = info.shooter.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			WeaponFx.swingArc(root, heavy)
			CombatSounds.playAt(if heavy then "HeavySwing" else "Swing", root.Position)
		end
	end
end

-- Boucle -------------------------------------------------------------------------------

local function onRender(dt: number)
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local armed = equippedSlot ~= 0 and canUseWeapon()

	bloom = math.max(0, bloom - SPREAD_RECOVERY * dt * 0.5)
	aimPoint = if armed then computeAimPoint() else nil

	-- PC : caméra d'épaule à nous quand l'arme est en main (voir ShoulderCamera).
	ShoulderCamera.set(armed, isAiming())

	-- Le personnage suit la caméra quand l'arme est en main (mode Normal uniquement).
	if humanoid and root and root:IsA("BasePart") and MovementController.getMode() == "Normal" then
		if armed then
			humanoid.AutoRotate = false
			local camera = workspace.CurrentCamera
			if camera then
				local look = camera.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude > 0.1 then
					local target = CFrame.lookAt(root.Position, root.Position + flat)
					root.CFrame = root.CFrame:Lerp(target, math.min(1, dt * FACE_SPEED))
				end
			end
		else
			humanoid.AutoRotate = true
		end
	end

	CameraFeel.setCombat(armed, isAiming())

	-- Arme rangée de force si le joueur tombe à terre.
	if equippedSlot ~= 0 and isDowned() then
		equip(equippedSlot)
	end
end

-- API publique (lecture seule) ----------------------------------------------------------

function CombatController.getEquipped(): string?
	return LOADOUT[equippedSlot]
end

function CombatController.getAmmo(): (number, number, boolean)
	local def = currentDef()
	if def == nil or def.magazine <= 0 then
		return 0, 0, false
	end
	local state = states[def.id]
	return state.ammo, def.magazine, WeaponState.isReloading(state, os.clock(), def)
end

-- Avancement du rechargement en cours (0 à 1), ou nil.
function CombatController.getReloadProgress(): number?
	local def = currentDef()
	if def == nil or def.magazine <= 0 then
		return nil
	end
	local state = states[def.id]
	if state.reloadEndsAt == nil then
		return nil
	end
	return 1 - math.clamp((state.reloadEndsAt - os.clock()) / def.reloadTime, 0, 1)
end

function CombatController.isAiming(): boolean
	return isAiming()
end

function CombatController.isArmed(): boolean
	return equippedSlot ~= 0 and canUseWeapon()
end

function CombatController.getAimPoint(): Vector3?
	return aimPoint
end

-- Dernier coup de mêlée (soi : `player` nil ; autre joueur : son objet Player).
function CombatController.getSwing(other: Player?): { at: number, heavy: boolean }?
	if other == nil or other == player then
		return lastSwing
	end
	return remoteSwings[other]
end

-- Charge de l'attaque lourde en cours (0 à 1), ou nil.
function CombatController.getMeleeCharge(): number?
	local def = currentDef()
	if meleeChargeStart == nil or def == nil then
		return nil
	end
	return math.clamp((os.clock() - meleeChargeStart) / (def.heavyChargeTime or 0.6), 0, 1)
end

function CombatController.start()
	bindInputs()
	Net.on("WeaponState", onWeaponState)
	Net.on("CombatEvent", onCombatEvent)
	Net.on("ShotFx", onShotFx)
	RunService:BindToRenderStep("FractureCombat", Enum.RenderPriority.Camera.Value + 2, onRender)
	player.CharacterAdded:Connect(function()
		equippedSlot = 0
		aimToggled = false
		for _, id in LOADOUT do
			states[id] = WeaponState.new(WeaponDefs[id])
		end
		CombatController.Equipped:Fire(nil)
	end)
	Players.PlayerRemoving:Connect(function(other)
		remoteSwings[other] = nil
	end)
	-- Studio : point de test (la simulation de clics de Studio n'atteint pas le jeu).
	if RunService:IsStudio() then
		local hook = Instance.new("BindableFunction")
		hook.Name = "FractureCombatQA"
		hook.OnInvoke = function(command: string, argument: any): any
			if command == "equip" then
				equip(argument)
			elseif command == "fire" then
				local def = currentDef()
				if def and def.kind == "Hitscan" then
					fireHitscan(def)
				elseif def then
					swing(def, argument == true)
				end
			elseif command == "reload" then
				reload()
			elseif command == "aim" then
				aimHeld = argument == true
			elseif command == "fireAt" and typeof(argument) == "Vector3" then
				qaAimOverride = argument
				local def = currentDef()
				if def and def.kind == "Hitscan" then
					fireHitscan(def)
				end
				qaAimOverride = nil
			end
			local ammo, mag = CombatController.getAmmo()
			return {
				equipped = LOADOUT[equippedSlot],
				ammo = ammo,
				magazine = mag,
				shoulderCamera = ShoulderCamera.isActive(),
			}
		end
		hook.Parent = player:WaitForChild("PlayerScripts")
	end
end

return CombatController
