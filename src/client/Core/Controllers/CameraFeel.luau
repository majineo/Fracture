--!strict
-- Retours de caméra du déplacement : champ de vision qui s'élargit avec la vitesse,
-- inclinaison pendant la glissade, abaissement en glissade, petit choc à la réception.
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
local SLIDE_ROLL = math.rad(4)
local LAND_DIP_PER_SPEED = 0.03 -- studs d'abaissement par stud/s de chute
local MAX_LAND_DIP = 1.4

local CameraFeel = {}

local fov = Spring.new(BASE_FOV, 7)
local roll = Spring.new(0, 9)
local drop = Spring.new(0, 12) -- abaissement de la caméra (glissade + réception)
local landDip = Spring.new(0, 14, 0.55) -- léger rebond

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
			fov.target = BASE_FOV + (FOV_BONUS[key] or 0)
			roll.target = if mode == "Slide" then SLIDE_ROLL else 0
			drop.target = if mode == "Slide" then -MovementConfig.SLIDE_CAMERA_DROP else 0

			camera.FieldOfView = Spring.step(fov, dt)
			local r = Spring.step(roll, dt)
			if math.abs(r) > 1e-4 then
				camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, r)
			end
			humanoid.CameraOffset =
				Vector3.new(0, Spring.step(drop, dt) + Spring.step(landDip, dt), 0)
		end
	)
end

return CameraFeel
