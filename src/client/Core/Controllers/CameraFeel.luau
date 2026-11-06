--!strict
-- Retours de caméra : champ de vision qui s'élargit avec la vitesse, inclinaison pendant la
-- glissade, abaissement en glissade, choc à la réception, caméra par-dessus l'épaule et zoom
-- de visée en combat, recul des armes.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > CameraFeel
--
-- Tout passe par des ressorts : aucune valeur ne saute d'une image à l'autre.
-- S'applique après la caméra Roblox (priorité Camera + 1), qui recalcule sa position à
-- chaque image : on ajoute donc nos effets par-dessus sans la casser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig =
	require(Shared:WaitForChild("Movement"):WaitForChild("MovementConfig")) :: any
local Spring = require(Shared:WaitForChild("Util"):WaitForChild("Spring")) :: any
local MovementController = require(script.Parent.MovementController)

local BASE_FOV = 70
local FOV_BONUS = { Normal = 0, Sprint = 7, Slide = 11, Grapple = 15, Mantle = 3 }
local AIM_FOV_REDUCTION = 20
local SLIDE_ROLL = math.rad(4)
local LAND_DIP_PER_SPEED = 0.03 -- studs d'abaissement par stud/s de chute
local MAX_LAND_DIP = 1.4
local SHOULDER_OFFSET = 1.8 -- décalage vers la droite en combat
local SHOULDER_HEIGHT = 0.35
local AIM_SHOULDER_OFFSET = 1.4

local CameraFeel = {}

local fov = Spring.new(BASE_FOV, 7)
local roll = Spring.new(0, 9)
local drop = Spring.new(0, 12) -- abaissement de la caméra (glissade + réception)
local landDip = Spring.new(0, 14, 0.55) -- léger rebond
local shoulder = Spring.new(0, 10)
local shoulderUp = Spring.new(0, 10)
local kickPitch = Spring.new(0, 22, 0.6) -- recul : monte vite, redescend avec un léger rebond

local armed = false
local aiming = false

-- Appelé chaque image par CombatController.
function CameraFeel.setCombat(isArmed: boolean, isAiming: boolean)
	armed = isArmed
	aiming = isAiming
end

-- Recul : la caméra se lève de `degrees` puis revient (négatif = choc vers le bas).
function CameraFeel.kick(degrees: number)
	Spring.impulse(kickPitch, math.rad(degrees) * 22)
end

function CameraFeel.start()
	MovementController.Landed:Connect(function(fallSpeed: number)
		local dip = math.min(MAX_LAND_DIP, fallSpeed * LAND_DIP_PER_SPEED)
		Spring.impulse(landDip, -dip * 14)
	end)

	RunService:BindToRenderStep(
		"FractureCameraFeel",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			local camera = workspace.CurrentCamera
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if camera == nil or humanoid == nil then
				return
			end

			local mode = MovementController.getMode()
			local key = if mode == "Normal" and MovementController.isSprinting()
				then "Sprint"
				else mode
			fov.target = BASE_FOV
				+ (FOV_BONUS[key] or 0)
				- (if aiming then AIM_FOV_REDUCTION else 0)
			roll.target = if mode == "Slide" then SLIDE_ROLL else 0
			drop.target = if mode == "Slide" then -MovementConfig.SLIDE_CAMERA_DROP else 0
			shoulder.target = if armed
				then (if aiming then AIM_SHOULDER_OFFSET else SHOULDER_OFFSET)
				else 0
			shoulderUp.target = if armed then SHOULDER_HEIGHT else 0

			camera.FieldOfView = Spring.step(fov, dt)
			local r = Spring.step(roll, dt)
			local pitch = Spring.step(kickPitch, dt)
			if math.abs(r) > 1e-4 or math.abs(pitch) > 1e-4 then
				camera.CFrame = camera.CFrame * CFrame.Angles(pitch, 0, r)
			end
			humanoid.CameraOffset = Vector3.new(
				Spring.step(shoulder, dt),
				Spring.step(drop, dt) + Spring.step(landDip, dt) + Spring.step(shoulderUp, dt),
				0
			)
		end
	)
end

return CameraFeel
