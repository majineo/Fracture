--!strict
-- Corde visuelle du grappin (pour soi et pour les autres joueurs).
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Rope
--
-- La corde peut suivre un crochet en vol (setEnd) et montrer du mou (setSlack) avant de
-- se tendre au moment où le crochet s'accroche.

export type Rope = {
	setEnd: (position: Vector3) -> (),
	setSlack: (amount: number) -> (),
	destroy: () -> (),
}

local ROPE_COLOR = Color3.fromRGB(80, 230, 255) -- cyan de la Brisure (GDD 10)
local HOOK_COLOR = Color3.fromRGB(220, 250, 255)

local Rope = {}

function Rope.attach(from: Attachment, target: Vector3): Rope
	local anchor = Instance.new("Attachment")
	anchor.Name = "GrappleAnchor"
	anchor.Parent = workspace.Terrain
	anchor.WorldPosition = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = anchor
	beam.Width0 = 0.12
	beam.Width1 = 0.18
	beam.FaceCamera = true
	beam.Segments = 12
	beam.LightEmission = 0.7
	beam.LightInfluence = 0.2
	beam.Color = ColorSequence.new(ROPE_COLOR)
	beam.Parent = anchor

	-- Petit point lumineux au bout : le crochet.
	local hook = Instance.new("PointLight")
	hook.Color = HOOK_COLOR
	hook.Range = 6
	hook.Brightness = 2
	hook.Parent = anchor

	local destroyed = false
	return {
		setEnd = function(position: Vector3)
			if not destroyed then
				anchor.WorldPosition = position
			end
		end,
		setSlack = function(amount: number)
			if not destroyed then
				beam.CurveSize0 = -amount
				beam.CurveSize1 = amount * 0.5
			end
		end,
		destroy = function()
			if not destroyed then
				destroyed = true
				anchor:Destroy()
			end
		end,
	}
end

return table.freeze(Rope)
