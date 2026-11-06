--!strict
-- Garde côté client le dernier instantané du profil envoyé par le serveur.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Controllers > ProfileController
--
-- Lecture seule : sert à l'affichage (interface). Modifier ces valeurs ne change rien côté serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal")) :: any
local Net = require(script.Parent.Parent.Lib.Net)

local ProfileController = {}

-- Déclenché à chaque nouvel instantané : (snapshot).
ProfileController.Changed = Signal.new()

local current: { [string]: any }? = nil

function ProfileController.get(): { [string]: any }?
	return current
end

function ProfileController.start()
	Net.on("ProfileSnapshot", function(snapshot: any)
		if typeof(snapshot) ~= "table" then
			return
		end
		current = snapshot
		ProfileController.Changed:Fire(snapshot)
		if RunService:IsStudio() then
			print(
				`[Profil] rang {snapshot.rank}, XP {snapshot.xp}, Grains {snapshot.grains}, coffre {snapshot.stashCount} objet(s)`
			)
		end
	end)
	-- Écouteur branché : on peut demander notre état.
	Net.fire("ClientReady")
end

return ProfileController
