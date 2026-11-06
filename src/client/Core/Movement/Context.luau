--!strict
-- Contexte partagé par les modules de déplacement : références au personnage local.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Movement > Context

export type Context = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	attachment: Attachment,
	rayParams: RaycastParams,
}

-- Un mouvement spécial en cours (glissade, escalade, grappin).
export type Action = {
	-- Avance d'une image ; renvoie false quand le mouvement est terminé.
	update: (dt: number) -> boolean,
	-- Interrompt le mouvement et nettoie tout ce qu'il a créé.
	stop: (boost: boolean?) -> (),
}

local Context = {}

function Context.new(character: Model, humanoid: Humanoid, root: BasePart): Context
	local attachment = root:FindFirstChild("RootAttachment")
	if attachment == nil or not attachment:IsA("Attachment") then
		local created = Instance.new("Attachment")
		created.Name = "RootAttachment"
		created.Parent = root
		attachment = created
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.IgnoreWater = true

	return {
		character = character,
		humanoid = humanoid,
		root = root,
		attachment = attachment :: Attachment,
		rayParams = rayParams,
	}
end

-- Vitesse horizontale actuelle du personnage.
function Context.horizontalVelocity(ctx: Context): Vector3
	local v = ctx.root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z)
end

-- Hauteur des pieds (bas du personnage).
function Context.feetY(ctx: Context): number
	return ctx.root.Position.Y - ctx.root.Size.Y / 2 - ctx.humanoid.HipHeight
end

return table.freeze(Context)
