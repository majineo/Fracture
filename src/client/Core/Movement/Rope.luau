--!strict
-- Corde visuelle du grappin (pour soi et pour les autres joueurs).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Rope

export type Rope = { destroy: () -> () }

local ROPE_COLOR = Color3.fromRGB(80, 230, 255) -- cyan de la Brisure (GDD 10)

local Rope = {}

function Rope.attach(from: Attachment, target: Vector3): Rope
	local anchor = Instance.new("Attachment")
	anchor.Name = "GrappleAnchor"
	anchor.Parent = workspace.Terrain
	anchor.WorldPosition = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = anchor
	beam.Width0 = 0.15
	beam.Width1 = 0.15
	beam.FaceCamera = true
	beam.Segments = 1
	beam.LightEmission = 0.6
	beam.Color = ColorSequence.new(ROPE_COLOR)
	beam.Parent = anchor

	local destroyed = false
	return {
		destroy = function()
			if not destroyed then
				destroyed = true
				anchor:Destroy()
			end
		end,
	}
end

return table.freeze(Rope)
