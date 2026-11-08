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
local PlaceKind = require(Shared:WaitForChild("PlaceKind")) :: any

local Client = script.Parent.Parent
local Net = require(Client.Lib.Net)
local CombatSounds = require(Client.Combat.CombatSounds)
local WeaponFx = require(Client.Combat.WeaponFx)
local CameraFeel = require(script.Parent.CameraFeel)
local MovementController = require(script.Parent.MovementController)
local ShoulderCamera = require(script.Parent.ShoulderCamera)
local Menu = require(Client.Ui.Menu)

local DEFAULT_LOADOUT = { "weapon.fracture_pistol", "weapon.short_blade" }
local SLOT_COUNT = 2
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
-- () : on vient de parer un coup
CombatController.Parried = Signal.new()
-- ()
CombatController.Fired = Signal.new()

local equippedSlot = 0
local states: { [string]: any } = {}
local aimHeld = false -- souris / manette : maintenir
local aimToggled = false -- tactile : bascule
local meleeChargeStart: number? = nil
local bloom = 0
type Swing = { at: number, heavy: boolean, combo: number }
local lastSwing: Swing? = nil
local remoteSwings: { [Player]: Swing } = {}
-- Mêlée assistée (v0.4.6) : orientation forcée vers la cible et petite fente.
local COMBO_WINDOW = 0.9 -- secondes entre deux coups pour enchaîner (comme le serveur)
local MELEE_ASSIST_CONE = math.rad(55)
local LUNGE_DISTANCE = 2.5
local LUNGE_TIME = 0.12
local HIT_STOP = 0.06
local faceOverride: Vector3? = nil
local faceOverrideUntil = 0
local lunge: { direction: Vector3, remaining: number, speed: number }? = nil
local remoteParries: { [Player]: number } = {}
local lastParry = -math.huge
-- Dernier tir (soi et les autres) : l'arme reste épaulée un instant après un tir.
local lastFire = -math.huge
-- Tir automatique (mitrailleuse, v0.10.0) : détente maintenue.
local triggerHeld = false
-- Surchauffe (v0.10.0) : cadence accélérée, munitions gratuites, jusqu'à cette heure (os.clock).
local overdriveUntil = 0
local overdriveMultiplier = 1
local remoteFires: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local parryCooldownUntil = 0
local parryHeldSince: number? = nil -- bouton de parade maintenu (Garde du Temps, v0.4.7)
local stunnedUntil = 0
local aimPoint: Vector3? = nil

-- Arme d'un emplacement (1 = arme à feu, 2 = mêlée), d'après la charge publiée par le serveur.
local function weaponAt(slot: number): string?
	if slot < 1 or slot > SLOT_COUNT then
		return nil
	end
	local id = Players.LocalPlayer:GetAttribute(`Loadout{slot}`)
	if typeof(id) == "string" and WeaponDefs[id] then
		return id
	end
	return DEFAULT_LOADOUT[slot]
end

-- État local (prédiction) d'une arme, créé à la demande.
local function stateOf(id: string): any
	local state = states[id]
	if state == nil then
		state = WeaponState.new(WeaponDefs[id])
		states[id] = state
	end
	return state
end

local function character(): Model?
	return player.Character
end

local function currentDef(): any
	local id = weaponAt(equippedSlot)
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
	return mode == "Normal" or mode == "Slide" or mode == "WallRun"
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

local reloadSound: Sound? = nil

-- Balle qui frôle : distance du segment de tir à la caméra.
local function nearMiss(origin: Vector3, finish: Vector3): boolean
	local camera = workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local point = camera.CFrame.Position
	local segment = finish - origin
	local length = segment.Magnitude
	if length < 1 then
		return false
	end
	local along = math.clamp((point - origin):Dot(segment) / (length * length), 0, 1)
	local closest = origin + segment * along
	-- Seulement si la balle passe à côté sans finir sur nous, et pas à bout portant.
	return (closest - point).Magnitude < 7 and along > 0.05 and along < 0.97
end

local function equip(slot: number)
	if slot == equippedSlot then
		slot = 0 -- même touche = ranger l'arme
	end
	local previous = weaponAt(equippedSlot)
	if previous then
		WeaponState.cancelReload(stateOf(previous))
	end
	CombatSounds.stop(reloadSound)
	reloadSound = nil
	equippedSlot = slot
	meleeChargeStart = nil
	Net.fire("EquipWeapon", slot)
	CombatController.Equipped:Fire(weaponAt(slot))
end

local function reload()
	local def = currentDef()
	if def == nil or def.magazine <= 0 or not canUseWeapon() then
		return
	end
	if WeaponState.reload(stateOf(def.id), def, os.clock()) then
		Net.fire("ReloadWeapon")
		CombatSounds.stop(reloadSound)
		reloadSound = CombatSounds.play2D(def.reloadSound or "Reload", nil, def.reloadTime)
	end
end

-- `volleyShot` : tir d'une salve au levier (cadence ignorée, dispersion ajoutée).
local function fireHitscan(def: any, volleyShot: number?)
	local state = stateOf(def.id)
	local now = os.clock()
	if WeaponState.isReloading(state, now, def) then
		return
	end
	if state.ammo <= 0 then
		CombatSounds.play2D("DryFire")
		reload()
		return
	end
	local boosted = def.automatic == true and now < overdriveUntil
	if
		volleyShot == nil
		and not WeaponState.canFire(state, def, now, 0, if boosted then overdriveMultiplier else 1)
	then
		return
	end
	local origin = muzzlePosition()
	local target = computeAimPoint()
	if origin == nil or target == nil then
		return
	end
	WeaponState.fire(state, def, now)
	if boosted then
		state.ammo += 1 -- Surchauffe : la balle ne coûte rien (le serveur fait de même)
	end
	lastFire = now

	local direction =
		applySpread((target - origin).Unit, CombatController.getSpread() + (volleyShot or 0))
	-- Tromblon : gerbe affichée tout de suite (le serveur tire la sienne et juge les touches).
	if def.pellets and def.pellets > 1 then
		local frame = CFrame.lookAt(Vector3.zero, direction)
		local pelletParams = RaycastParams.new()
		pelletParams.FilterType = Enum.RaycastFilterType.Exclude
		pelletParams.FilterDescendantsInstances = { character() :: Model }
		for _ = 2, def.pellets do
			local spread = def.pelletSpread or 5
			local a = math.random() * math.pi * 2
			local r = spread * (0.45 + 0.55 * math.sqrt(math.random()))
			local d = (frame * CFrame.Angles(
				math.rad(math.sin(a) * r),
				math.rad(math.cos(a) * r),
				0
			)).LookVector
			local h = workspace:Raycast(origin, d * def.range, pelletParams)
			WeaponFx.tracer(origin, if h then h.Position else origin + d * def.range)
			if h and not h.Instance:FindFirstAncestorOfClass("Model") then
				WeaponFx.impact(h.Position, h.Normal, h.Instance.Color)
			end
		end
	end
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
		CombatSounds.playAt(
			def.impactSound or "BulletImpact",
			hit.Position,
			0.9 + math.random() * 0.2
		)
	elseif hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Health") == nil then
			WeaponFx.impact(hit.Position, hit.Normal, hit.Instance.Color)
			CombatSounds.playAt(
				def.impactSound or "BulletImpact",
				hit.Position,
				0.9 + math.random() * 0.2
			)
		end
	end
	CombatSounds.play2D(def.sound, (def.soundPitch or 1) * (0.95 + math.random() * 0.1))
	if def.cycleSounds and volleyShot == nil then
		for _, step in def.cycleSounds do
			task.delay(step.delay, CombatSounds.play2D, step.sound)
		end
	end
	CameraFeel.kick(def.recoil)
	CombatController.Fired:Fire()

	Net.fire("FireWeapon", origin, direction, workspace:GetServerTimeNow())

	if state.ammo <= 0 then
		task.delay(0.15, reload)
	end
end

-- Parade : lever la lame pendant la fenêtre de l'arme (le serveur juge si un coup est paré).
local function parry(def: any)
	local now = os.clock()
	if now < stunnedUntil or now < parryCooldownUntil then
		return
	end
	local window = def.parryWindow or 0.2
	lastParry = now
	parryCooldownUntil = now + window + 0.75 -- même recharge que le serveur (Combat/Parry)
	meleeChargeStart = nil
	CombatSounds.play2D("Swing", 1.4)
	Net.fire("Parry")
end

-- Aide à la mêlée (v0.4.6) : cible la plus proche du centre de l'écran, devant soi et à portée
-- (+ marge de fente). Le serveur revérifie portée, cône et ligne de vue.
local function meleeTarget(def: any, root: BasePart): BasePart?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		return nil
	end
	look = look.Unit
	local best: BasePart? = nil
	local bestScore = math.huge
	for _, model in workspace:GetChildren() do
		if
			model:IsA("Model")
			and model ~= character()
			and model:GetAttribute("MaxHealth") ~= nil
		then
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if
				targetRoot
				and targetRoot:IsA("BasePart")
				and model:GetAttribute("Dead") ~= true
				and not (Players:GetPlayerFromCharacter(model) and PlaceKind ~= "Eclat")
			then
				local offset = targetRoot.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				if
					distance <= def.range + LUNGE_DISTANCE
					and math.abs(offset.Y) < 5
					and distance > 0.1
				then
					local angle = math.acos(math.clamp(look:Dot(flat.Unit), -1, 1))
					if angle <= MELEE_ASSIST_CONE then
						local score = angle * 4 + distance * 0.1
						if score < bestScore then
							best, bestScore = targetRoot, score
						end
					end
				end
			end
		end
	end
	return best
end

-- Petite fente vers la cible (jamais à travers un mur), et le personnage se tourne vers elle.
local function lungeToward(root: BasePart, target: BasePart, def: any)
	local offset = target.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	faceOverride = flat.Unit
	faceOverrideUntil = os.clock() + 0.3
	local wanted = math.clamp(flat.Magnitude - def.range * 0.55, 0, LUNGE_DISTANCE)
	if wanted < 0.3 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character() :: Model, target.Parent :: Instance }
	local blocked = workspace:Raycast(root.Position, flat.Unit * (wanted + 1), params)
	if blocked then
		wanted = math.max(0, blocked.Distance - 1)
	end
	lunge = { direction = flat.Unit, remaining = wanted, speed = wanted / LUNGE_TIME }
end

local function swing(def: any, heavy: boolean)
	local state = stateOf(def.id)
	local now = os.clock()
	if now < stunnedUntil or not WeaponState.canFire(state, def, now) then
		return
	end
	WeaponState.fire(state, def, now)
	if heavy then
		state.lastShot = now + (2.2 - 1) / def.fireRate
	end
	-- Enchaînement : 1 → 2 → 3 (estoc) si les coups s'enchaînent vite ; le coup chargé le coupe.
	-- Même calcul que le serveur (WeaponService), qui seul applique les dégâts.
	local combo = 1
	if not heavy and lastSwing and not lastSwing.heavy and now - lastSwing.at <= COMBO_WINDOW then
		combo = (lastSwing.combo or 1) % 3 + 1
	end
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	local direction = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	if root and root:IsA("BasePart") then
		local target = meleeTarget(def, root)
		if target then
			direction = (target.Position - root.Position).Unit
			lungeToward(root, target, def)
		end
	end
	lastSwing = { at = now, heavy = heavy, combo = combo }
	if c then
		WeaponFx.bladeTrail(c, (def.swingTime or 0.2) * (if heavy then 1.6 else 1) + 0.08, heavy)
	end
	CombatSounds.play2D(
		if heavy then "HeavySwing" else def.sound,
		(def.soundPitch or 1) * (0.95 + math.random() * 0.1) * (if combo == 3 then 0.9 else 1)
	)
	CameraFeel.kick(if heavy then 1.2 elseif combo == 3 then 0.8 else 0.5)
	Net.fire("MeleeSwing", heavy, direction, workspace:GetServerTimeNow())
end

-- Entrées ------------------------------------------------------------------------------

local function handleFire(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	local def = currentDef()
	-- Fenêtre ouverte (sac, coffre…) : le clic sert à l'interface, pas à tirer.
	if def == nil or (Menu.isOpen() and state == Enum.UserInputState.Begin) then
		return Enum.ContextActionResult.Pass -- mains nues : le clic garde son rôle normal
	end
	if not canUseWeapon() then
		meleeChargeStart = nil
		return Enum.ContextActionResult.Sink
	end
	if def.automatic then
		-- Arme automatique : on tire tant que la détente est maintenue (la cadence limite).
		if state == Enum.UserInputState.Begin then
			if not triggerHeld then
				triggerHeld = true
				task.spawn(function()
					while triggerHeld do
						local current = currentDef()
						if current == nil or current.id ~= def.id or not canUseWeapon() then
							break
						end
						if not Menu.isOpen() then
							fireHitscan(current)
						end
						task.wait()
					end
					triggerHeld = false
				end)
			end
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			triggerHeld = false
		end
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
	local def = currentDef()
	if def == nil or (Menu.isOpen() and state == Enum.UserInputState.Begin) then
		return Enum.ContextActionResult.Pass
	end
	-- Arme de mêlée : le bouton de visée sert à parer (le maintenir lève la Garde du Temps).
	if def.kind == "Melee" then
		if state == Enum.UserInputState.Begin and canUseWeapon() then
			parry(def)
			parryHeldSince = os.clock()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			parryHeldSince = nil
		end
		return Enum.ContextActionResult.Sink
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
		if nextSlot > SLOT_COUNT then
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
		false,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(
		ACTIONS.aim,
		handleAim,
		false,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.ButtonL2
	)
	ContextActionService:BindAction(
		ACTIONS.reload,
		handleReload,
		false,
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
	-- Écrans tactiles : boutons dédiés dans Controllers/MobileControls.
end

-- Réseau -------------------------------------------------------------------------------

local function onWeaponState(id: any, ammo: any, reloadRemaining: any)
	local state = typeof(id) == "string" and WeaponDefs[id] and stateOf(id)
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
		CombatSounds.play2D("Hit", if info.killed then 0.85 else 1)
		if info.headshot then
			CombatSounds.play2D("Headshot")
		end
		if info.killed then
			CombatSounds.play2D("Kill")
		end
		-- Coup de lame qui porte : étincelles, son d'impact, micro-arrêt du coup (« hit stop »).
		local swingNow = lastSwing
		local def = currentDef()
		if swingNow and def and def.kind == "Melee" and os.clock() - swingNow.at < 0.6 then
			if typeof(info.position) == "Vector3" then
				WeaponFx.meleeImpact(info.position + Vector3.new(0, 0.8, 0), swingNow.heavy)
			end
			CombatSounds.play2D(
				if swingNow.heavy then "MeleeHitHeavy" else "MeleeHit",
				0.95 + math.random() * 0.1
			)
			swingNow.at += HIT_STOP
			CameraFeel.kick(if swingNow.heavy then -2 else -1)
		end
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
		CombatSounds.play2D("Hurt", 0.9 + math.random() * 0.2)
		CameraFeel.kick(-1.5)
	elseif info.type == "ParrySuccess" then
		-- Coup paré : étincelles, son métallique, petite secousse.
		CombatController.Parried:Fire()
		CombatSounds.play2D("Parry")
		CameraFeel.kick(0.8)
		local c = character()
		local hand = c and c:FindFirstChild("RightHand")
		if hand and hand:IsA("BasePart") then
			WeaponFx.parrySparks(hand.Position)
		end
	elseif info.type == "Stunned" then
		-- Notre coup a été paré : on est étourdi.
		stunnedUntil = os.clock()
			+ (if typeof(info.duration) == "number" then info.duration else 0.9)
		meleeChargeStart = nil
		CombatSounds.play2D("Parry", 0.8)
		CameraFeel.kick(-2.5)
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
		remoteFires[info.shooter] = os.clock()
		WeaponFx.tracer(info.origin, info.finish)
		WeaponFx.muzzleFlash(info.origin, (info.finish - info.origin).Unit)
		local def = typeof(info.weapon) == "string" and WeaponDefs[info.weapon]
		CombatSounds.playAt(
			if def then def.sound else "PistolShot",
			info.origin,
			if def then def.soundPitch else nil
		)
		local range = if def then def.range else 300
		if (info.finish - info.origin).Magnitude < range - 1 then
			CombatSounds.playAt(
				if def and def.impactSound then def.impactSound else "BulletImpact",
				info.finish,
				0.9 + math.random() * 0.2,
				0.8
			)
		end
		if info.shooter ~= player and nearMiss(info.origin, info.finish) then
			CombatSounds.play2D("BulletWhiz", 0.9 + math.random() * 0.25)
		end
	elseif info.kind == "FractureWave" then
		-- Onde de fracture : coup chargé (animation et traînée) pour le lanceur.
		local wave = { at = os.clock(), heavy = true, combo = 1 }
		if info.shooter == player then
			lastSwing = wave
		elseif info.shooter:IsA("Player") then
			remoteSwings[info.shooter] = wave
		end
		local c = if info.shooter:IsA("Player") then info.shooter.Character else nil
		if c then
			WeaponFx.bladeTrail(c, 0.6, true)
		end
	elseif info.kind == "Parry" then
		remoteParries[info.shooter] = os.clock()
	elseif info.kind == "ParrySuccess" then
		local c = info.shooter.Character
		local hand = c and c:FindFirstChild("RightHand")
		if hand and hand:IsA("BasePart") then
			WeaponFx.parrySparks(hand.Position)
			CombatSounds.playAt("Parry", hand.Position)
		end
	elseif info.kind == "Swing" or info.kind == "HeavySwing" then
		local heavy = info.kind == "HeavySwing"
		local combo = if typeof(info.combo) == "number" then math.clamp(info.combo, 1, 3) else 1
		remoteSwings[info.shooter] = { at = os.clock(), heavy = heavy, combo = combo }
		local c = info.shooter.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local def = typeof(info.weapon) == "string" and WeaponDefs[info.weapon]
		if c and root and root:IsA("BasePart") then
			local swingTime = if def then def.swingTime or 0.2 else 0.2
			WeaponFx.bladeTrail(c, swingTime * (if heavy then 1.6 else 1) + 0.08, heavy)
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
				-- Coup de lame assisté : on se tourne un instant vers la cible.
				if faceOverride and os.clock() < faceOverrideUntil then
					flat = faceOverride
				end
				if flat.Magnitude > 0.1 then
					local target = CFrame.lookAt(root.Position, root.Position + flat)
					root.CFrame = root.CFrame:Lerp(target, math.min(1, dt * FACE_SPEED))
				end
			end
			-- Fente : quelques studs vers la cible en un éclair.
			local current = lunge
			if current then
				local step = math.min(current.remaining, current.speed * dt)
				root.CFrame += current.direction * step
				current.remaining -= step
				if current.remaining <= 1e-3 then
					lunge = nil
				end
			end
		else
			humanoid.AutoRotate = true
		end
	end

	local scopeDef = currentDef()
	CameraFeel.setCombat(armed, isAiming(), if scopeDef then scopeDef.scopeFov else nil)

	-- Arme rangée de force si le joueur tombe à terre.
	if equippedSlot ~= 0 and isDowned() then
		equip(equippedSlot)
	end
end

-- API publique (lecture seule) ----------------------------------------------------------

function CombatController.getEquipped(): string?
	return weaponAt(equippedSlot)
end

function CombatController.getAmmo(): (number, number, boolean)
	local def = currentDef()
	if def == nil or def.magazine <= 0 then
		return 0, 0, false
	end
	local state = stateOf(def.id)
	return state.ammo, def.magazine, WeaponState.isReloading(state, os.clock(), def)
end

-- Avancement du rechargement en cours (0 à 1), ou nil.
function CombatController.getReloadProgress(): number?
	local def = currentDef()
	if def == nil or def.magazine <= 0 then
		return nil
	end
	local state = stateOf(def.id)
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

-- Heure (os.clock) du dernier tir : soi (`other` nil) ou un autre tireur (joueur ou ennemi).
function CombatController.getLastFire(other: Instance?): number
	if other == nil or other == player then
		return lastFire
	end
	return remoteFires[other] or -math.huge
end

-- Dernier coup de mêlée (soi : `player` nil ; autre joueur : son objet Player).
function CombatController.getSwing(other: Player?): Swing?
	if other == nil or other == player then
		return lastSwing
	end
	return remoteSwings[other]
end

-- Commandes tactiles (appelées par MobileControls) --------------------------------------

local TOUCH_INPUT = { UserInputType = Enum.UserInputType.Touch } :: any

-- Bouton « Tirer » : began = doigt posé (true) ou levé (false).
function CombatController.touchFire(began: boolean)
	handleFire("", if began then Enum.UserInputState.Begin else Enum.UserInputState.End)
end

-- Bouton « Viser » (bascule) ou « Parer » avec une arme de mêlée.
function CombatController.touchAim()
	handleAim("", Enum.UserInputState.Begin, TOUCH_INPUT)
end

-- Fin d'appui sur le bouton Viser / Parer (tactile) : baisse la Garde du Temps.
function CombatController.touchAimRelease()
	parryHeldSince = nil
end

-- Depuis combien de secondes le bouton de parade est maintenu (nil s'il est relâché).
function CombatController.getParryHeld(): number?
	return if parryHeldSince then os.clock() - parryHeldSince else nil
end

-- Position du canon de l'arme en main (tirs spéciaux des capacités).
function CombatController.getMuzzle(): Vector3?
	return muzzlePosition()
end

-- Surchauffe (mitrailleuse) : cadence ×`multiplier` et munitions gratuites pendant `duration`.
function CombatController.overdrive(duration: number, multiplier: number)
	overdriveUntil = os.clock() + duration
	overdriveMultiplier = multiplier
end

function CombatController.isOverdriven(): boolean
	return os.clock() < overdriveUntil
end

-- Salve au levier (fusil) : `shots` tirs espacés de `interval`, dispersion ajoutée.
function CombatController.volley(shots: number, interval: number, extraSpread: number)
	task.spawn(function()
		for _ = 1, shots do
			local def = currentDef()
			if def == nil or def.kind ~= "Hitscan" or not canUseWeapon() then
				return
			end
			fireHitscan(def, extraSpread)
			task.wait(interval)
		end
	end)
end

function CombatController.touchReload()
	reload()
end

-- Bouton « Arme » : mains nues → arme 1 → arme 2 → mains nues.
function CombatController.touchCycle()
	handleCycle("", Enum.UserInputState.Begin)
end

-- L'arme en main est-elle de mêlée ? (le bouton Viser devient « Parer »)
function CombatController.isMeleeEquipped(): boolean
	local def = currentDef()
	return def ~= nil and def.kind == "Melee"
end

-- Moment de la dernière parade (soi : `other` nil ; autre joueur : son objet Player).
function CombatController.getParry(other: Player?): number
	if other == nil or other == player then
		return lastParry
	end
	return remoteParries[other] or -math.huge
end

-- Secondes d'étourdissement restantes (0 = libre).
function CombatController.getStun(): number
	return math.max(0, stunnedUntil - os.clock())
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
		table.clear(states)
		CombatController.Equipped:Fire(nil)
	end)
	Players.PlayerRemoving:Connect(function(other)
		remoteSwings[other] = nil
		remoteFires[other] = nil
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
			elseif command == "parry" then
				local def = currentDef()
				if def and def.kind == "Melee" then
					parry(def)
				end
			elseif command == "aimAt" then
				-- Point visé imposé (nil pour revenir au centre de l'écran).
				qaAimOverride = if typeof(argument) == "Vector3" then argument else nil
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
				equipped = weaponAt(equippedSlot),
				ammo = ammo,
				magazine = mag,
				shoulderCamera = ShoulderCamera.isActive(),
			}
		end
		hook.Parent = player:WaitForChild("PlayerScripts")
	end
end

return CombatController
