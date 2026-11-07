--!strict
-- Textures des particules (v0.4.9). Dessinées dans Blender (assets/blender/vfx/), importées
-- dans Roblox par l'utilisateur ; tant qu'un identifiant est vide, on utilise la texture
-- intégrée à Roblox indiquée en secours.
-- Studio : StarterPlayer > StarterPlayerScripts > Client > Combat > VfxTextures

local IMPORTED = {
	Shard = "rbxassetid://92144878672223", -- éclat de Temps (bris, onde, ambiance)
	Spark = "rbxassetid://132627852076050", -- étincelle étirée (impacts, parade)
	Glow = "rbxassetid://113971661677731", -- halo doux (auras, noyau chargé)
	Dust = "rbxassetid://128543269635465", -- bouffée de poussière (pas de course, réception)
	Vignette = "rbxassetid://135127213697813", -- bords d'écran (santé basse, dégâts, soin)
	Runes = "rbxassetid://114876894159248", -- cercle runique (Rayon du Zénith, v0.4.12)
	Beam = "rbxassetid://78828733565010", -- rayon de lumière vertical (v0.4.12)
}

local FALLBACK = {
	Shard = "rbxasset://textures/particles/sparkles_main.dds",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Glow = "rbxasset://textures/particles/sparkles_main.dds",
	Dust = "rbxasset://textures/particles/smoke_main.dds",
	Vignette = "", -- pas d'équivalent intégré : bordure en attendant (ScreenVignette)
	Runes = "rbxasset://textures/particles/sparkles_main.dds",
	Beam = "rbxasset://textures/particles/sparkles_main.dds",
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
