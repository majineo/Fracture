# FRACTURE

> Jeu Roblox d'extraction PvPvE dans un univers où le temps lui-même s'est brisé.
> Chaque **Éclat** est un fragment instable d'une époque : on y plonge, on y pille des reliques,
> et on s'en extrait avant qu'il ne s'effondre.

**Version actuelle : v0.2.0 « Fondations »** · Phase 3 (architecture et prototypage)

## État du projet

| Statut | Contenu |
|---|---|
| ✅ Implémenté | Deux places (Refuge, Éclat), démarrage modulaire, couche réseau sécurisée, données joueur avec verrou de session, tests automatiques |
| 🔧 En cours | — |
| 📋 Prévu | Déplacement (v0.3.0), puis combat, Éclats, extraction (voir [feuille de route](docs/ROADMAP.md)) |
| 💭 À l'étude | Éléments marqués 💭 dans le GDD |

Aucun gameplay n'est encore jouable : les places contiennent un sol et un point d'apparition.

## Documentation

- [Game Design Document](docs/GDD/README.md)
- [Architecture technique](docs/ARCHITECTURE.md)
- [Journal des décisions](docs/DECISIONS.md)
- [Feuille de route](docs/ROADMAP.md)
- [Suivi des modèles 3D et assets](docs/ASSETS.md)
- [Règles de versionnement](docs/VERSIONING.md)
- [Historique des versions](CHANGELOG.md)

## Développement

Outils gérés par [Rokit](https://github.com/rojo-rbx/rokit), versions figées dans `rokit.toml` :
Rojo, Wally, Selene, StyLua, Lune.

```bash
rokit install
```

**Travailler dans Studio (synchronisation en direct)**

```bash
rojo serve places/refuge.project.json
```

Puis dans Roblox Studio : onglet **Plugins** → **Rojo** → **Connect**. Remplacer `refuge` par
`eclat` pour la place d'Éclat.

**Construire une place sans Studio ouvert**

```bash
rojo build places/refuge.project.json -o build/Fracture-Refuge.rbxl
```

**Vérifications** (aussi exécutées par la CI GitHub à chaque envoi)

```bash
stylua src tests
selene src
lune run tests/run
```

Les données joueur dans Studio : sans « Enable Studio Access to API Services », elles sont
gardées en mémoire pendant le test seulement ; avec, elles vont dans un stockage séparé
réservé à Studio.
