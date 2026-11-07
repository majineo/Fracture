--!strict
-- Caméra par-dessus l'épaule quand une arme est en main sur PC (souris).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > ShoulderCamera
--
-- Pourquoi une caméra à nous : le module de caméra Roblox n'est plus accessible aux scripts,
-- et forcer la souris au centre empêchait la rotation au clic droit. Ici :
--   * arme en main (PC) : souris verrouillée et cachée, ses mouvements tournent la vue,
--     la caméra évite les murs ;
--   * arme rangée : on rend la main à la caméra Roblox telle quelle (clic droit = tourner).
-- Mobile et manette gardent la caméra Roblox (rotation au doigt / au stick).
--
-- Ordre d'exécution : cette caméra (priorité Camera) → CameraFeel (Camera + 1 : champ de
-- vision, inclinaison, recul) → CombatController (Camera + 2).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spring = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Spring")
) :: any

local DISTANCE = 8
local AIM_DISTANCE = 5
local FOCUS_HEIGHT = 1.6 -- au-dessus de la racine (hauteur des yeux)
local DEGREES_PER_PIXEL = 0.25
local MAX_PITCH = math.rad(75)
local COLLISION_MARGIN = 0.6

local player = Players.LocalPlayer

local ShoulderCamera = {}

local active = false
local aiming = false
local yaw = 0
local pitch = 0
local distance = Spring.new(DISTANCE, 14)

-- Le joueur a-t-il une souris (et pas un écran tactile seul) ?
local function usesMouse(): boolean
	return UserInputService.MouseEnabled
		and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch
end

local function enter(camera: Camera)
	-- On part de l'orientation actuelle pour ne pas faire sauter la vue.
	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseIconEnabled = false
end

local function leave(camera: Camera)
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

-- Appelé chaque image par CombatController.
function ShoulderCamera.set(armed: boolean, isAiming: boolean)
	local wanted = armed and usesMouse()
	aiming = isAiming
	if wanted == active then
		return
	end
	active = wanted
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if active then
		enter(camera)
	else
		leave(camera)
	end
end

function ShoulderCamera.isActive(): boolean
	return active
end

function ShoulderCamera.start()
	RunService:BindToRenderStep(
		"FractureShoulderCamera",
		Enum.RenderPriority.Camera.Value,
		function(dt: number)
			if not active then
				return
			end
			local camera = workspace.CurrentCamera
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if camera == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
				return
			end
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Scriptable
			end

			-- La souris reste au centre ; ses déplacements font tourner la vue.
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			local delta = UserInputService:GetMouseDelta()
			-- Plus le champ de vision est serré (lunette), plus la souris est fine.
			local fov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
			local zoom = math.clamp(fov / 70, 0.2, 1)
			local sensitivity = math.rad(DEGREES_PER_PIXEL)
				* UserGameSettings.MouseSensitivity
				* zoom
			yaw -= delta.X * sensitivity
			pitch = math.clamp(pitch - delta.Y * sensitivity, -MAX_PITCH, MAX_PITCH)

			distance.target = if aiming then AIM_DISTANCE else DISTANCE
			local d = Spring.step(distance, dt)

			local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			local focus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
			-- Décalage d'épaule et abaissements fournis par CameraFeel via CameraOffset.
			local offset = humanoid.CameraOffset
			local pivot = focus + rotation:VectorToWorldSpace(Vector3.new(offset.X, offset.Y, 0))
			local desired = pivot + rotation:VectorToWorldSpace(Vector3.new(0, 0, d))

			-- La caméra ne traverse pas les murs.
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character :: Model }
			local toCamera = desired - focus
			local hit = workspace:Raycast(focus, toCamera, params)
			local position = desired
			if hit then
				position = focus + toCamera.Unit * math.max(0.5, hit.Distance - COLLISION_MARGIN)
			end
			camera.CFrame = CFrame.new(position) * rotation
			camera.Focus = CFrame.new(pivot)
		end
	)

	player.CharacterAdded:Connect(function()
		if active then
			active = false
			local camera = workspace.CurrentCamera
			if camera then
				leave(camera)
			end
		end
	end)
end

return ShoulderCamera
