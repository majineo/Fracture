--!strict
-- Textures des particules (v0.4.9). Dessinées dans Blender (assets/blender/vfx/), importées
-- dans Roblox par l'utilisateur ; tant qu'un identifiant est vide, on utilise la texture
-- intégrée à Roblox indiquée en secours.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > VfxTextures

local IMPORTED = {
	Shard = "", -- éclat de Temps (bris, onde, ambiance)
	Spark = "", -- étincelle étirée (impacts, parade)
	Glow = "", -- halo doux (auras, noyau chargé)
	Dust = "", -- bouffée de poussière (pas de course, réception)
	Vignette = "", -- bords d'écran (santé basse, dégâts, soin)
}

local FALLBACK = {
	Shard = "rbxasset://textures/particles/sparkles_main.dds",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Glow = "rbxasset://textures/particles/sparkles_main.dds",
	Dust = "rbxasset://textures/particles/smoke_main.dds",
	Vignette = "", -- pas d'équivalent intégré : bordure en attendant (ScreenVignette)
}

local VfxTextures = {}

-- Texture à utiliser pour un type de particule.
function VfxTextures.get(name: string): string
	local id = (IMPORTED :: any)[name]
	if typeof(id) == "string" and id ~= "" then
		return id
	end
	return (FALLBACK :: any)[name] or ""
end

-- La texture a-t-elle été importée (identifiant renseigné) ?
function VfxTextures.isImported(name: string): boolean
	local id = (IMPORTED :: any)[name]
	return typeof(id) == "string" and id ~= ""
end

return table.freeze(VfxTextures)
