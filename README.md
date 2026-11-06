# FRACTURE

> Jeu Roblox d'extraction PvPvE dans un univers où le temps lui-même s'est brisé.
> Chaque **Éclat** est un fragment instable d'une époque : on y plonge, on y pille des reliques,
> et on s'en extrait avant qu'il ne s'effondre.

**Version actuelle : v0.1.0 « Initialisation »** · Phase : 1 → 2 (concept validé, GDD à rédiger)

## État du projet

| Statut | Contenu |
|---|---|
| ✅ Implémenté | Structure du projet, chaîne d'outils, documentation initiale |
| 🔧 En cours | — |
| 📋 Prévu | Game Design Document complet (phase 2), architecture technique (phase 3) |
| 💭 À l'étude | Voir [docs/GDD/00-concept.md](docs/GDD/00-concept.md), section « Questions ouvertes » |

## Documentation

- [Concept du jeu](docs/GDD/00-concept.md)
- [Journal des décisions](docs/DECISIONS.md)
- [Feuille de route](docs/ROADMAP.md)
- [Architecture technique](docs/ARCHITECTURE.md)
- [Suivi des modèles 3D et assets](docs/ASSETS.md)
- [Règles de versionnement](docs/VERSIONING.md)
- [Historique des versions](CHANGELOG.md)

## Développement

Outils gérés par [Rokit](https://github.com/rojo-rbx/rokit) (versions figées dans `rokit.toml`) :
Rojo, Wally, Selene, StyLua.

1. Installer les outils : `rokit install`
2. Lancer la synchronisation : `rojo serve`
3. Dans Roblox Studio : onglet **Plugins** → **Rojo** → **Connect**.

Le code vit dans `src/` et est synchronisé dans Studio par Rojo :

| Dossier | Destination dans Studio | Rôle |
|---|---|---|
| `src/shared` | ReplicatedStorage > Shared | Types, configuration, utilitaires purs |
| `src/server` | ServerScriptService > Server | Systèmes serveur (autorité) |
| `src/client` | StarterPlayer > StarterPlayerScripts > Client | Entrées, rendu, interface |
| `assets/` | — (non synchronisé) | Sources Blender, textures, audio |

Vérifications : `stylua src` (formatage) · `selene src` (lint). La CI GitHub les exécute à chaque push.
