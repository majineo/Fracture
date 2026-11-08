--!strict
-- Exporte les données du jeu (armes, capacités, objets, ennemis, tuiles) en JSON pour la base de
-- connaissance Obsidian (v0.11.0). Usage : lune run tools/export_catalog → build/catalogue.json
-- Lu par tools/obsidian_sync.py.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Config = require("../src/shared/Config")
local WeaponDefs = require("../src/shared/Combat/WeaponDefs")
local Ability = require("../src/shared/Combat/Ability")
local EnemyDefs = require("../src/shared/Combat/EnemyDefs")
local ItemDefs = require("../src/shared/Loot/ItemDefs")
local Districts = require("../src/shared/Eclat/Districts")
local EclatLayout = require("../src/shared/Eclat/EclatLayout")

local out = {
	version = Config.GAME_VERSION,
	weapons = WeaponDefs,
	abilities = Ability.DEFS,
	passives = Ability.PASSIVES,
	enemies = EnemyDefs,
	items = ItemDefs.ALL,
	districts = Districts.DEFS,
	modules = Districts.MODULES,
	grid = { size = EclatLayout.SIZE, tile = EclatLayout.TILE },
}

fs.writeDir("build")
fs.writeFile("build/catalogue.json", serde.encode("json", out, true))
print("Catalogue exporté : build/catalogue.json")
