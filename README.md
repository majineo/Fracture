# FRACTURE

> Jeu Roblox d'extraction PvPvE dans un univers où le temps lui-même s'est brisé.
> Chaque **Éclat** est un fragment instable d'une époque : on y plonge, on y pille des reliques,
> et on s'en extrait avant qu'il ne s'effondre.

**Version actuelle : v0.4.3 « Arsenal »** · Phase 3 (architecture et prototypage)

## État du projet

| Statut | Contenu |
|---|---|
| ✅ Implémenté | Deux places (Refuge, Éclat), couche réseau sécurisée, données joueur avec verrou de session, déplacement avec animations et garde anti-triche, combat (5 armes, parade, santé, à terre, compensation de latence), premiers ennemis (homme d'armes, arbalétrier), capacités du pistolet et de la lame, champ de tir, armurerie, tests automatiques |
| 🔧 En cours | — |
| 📋 Prévu | Capacités des trois autres armes, puis Éclats, extraction (voir [feuille de route](docs/ROADMAP.md)) |
| 💭 À l'étude | Éléments marqués 💭 dans le GDD |

Jouable pour l'instant : se déplacer sur le parcours de test du Refuge.

| Action | PC | Mobile | Manette |
|---|---|---|---|
| Sprint | Maj (maintenir) | Bouton Sprint | L3 |
| Glisser (en courant) | C ou Ctrl | Bouton Glisser | B |
| Escalader | Saut face à un rebord | Saut | A |
| Grappin | G (vise le curseur) | Bouton Grappin (centre de l'écran) | R3 |
| Pistolet / lame (même touche = ranger) | 1 / 2 | Bouton Arme | Croix ◀ / ▶ |
| Tirer / frapper (lame : maintenir = coup chargé) | Clic gauche | Bouton Tirer | RT |
| Viser (arme à feu) / Parer (mêlée) | Clic droit | Bouton Viser / Parer | LT |
| Recharger | R | Bouton Recharger | X |
| Capacité de l'arme (noyau plein) | Q | Bouton Capa. | LB |

Champ de tir : à l'ouest du point d'apparition (3 mannequins, dont un mobile).
Armurerie : au sud du point d'apparition (5 armes, maintenir la touche d'interaction pour équiper).

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
