# 06 — Environnements

> Statut : 📋 Prévu. Tous les modèles sont **à créer** (voir [ASSETS](../ASSETS.md)).

## 1. Le Refuge (place hub)

Une tour d'horlogerie flottant dans le Vide, entourée d'engrenages géants en rotation lente.

| Zone | Fonction |
|---|---|
| **Le Portail** | Choix de l'Éclat, départ des escouades |
| **La Forge** | Fabrication |
| **Le Sanctuaire** | Stabilisation des reliques, consultation du Codex |
| **Le Coffre** | Stockage personnel |
| **Le Champ de tir** | Essai des armes et capacités, sans risque |
| **La Place** | Lieu social, tableau des meilleurs Fractureurs |

Le Refuge est compact (on traverse tout en 30 s) : c'est un lieu de passage, pas une zone à explorer.

## 2. L'Éclat de forteresse médiévale (vertical slice)

Une forteresse sur un éperon rocheux, arrachée au moment d'un siège. Brume, bannières
déchirées, flèches figées en plein vol, cloches qui sonnent sans raison.

### Grille et tuiles
- Une **tuile** = un carré de **96 × 96 studs** au sol (64 jusqu'à la v0.10), assemblé à partir
  d'un **kit modulaire** sur une grille de 8 studs (murs, sols, escaliers, arches, toits).
- Un Éclat = grille de **7 × 7 tuiles** (5 × 5 jusqu'à la v0.10 ; carte ≈ 4,4 fois plus grande,
  décision D-052). Le centre est toujours le Donjon.
- Plan type d'une tuile (`Shared/Eclat/Districts`) : un îlot central (±26), un chemin de ronde
  au sol tout autour (26 à 40, éboulis-couverts tous les ~20 studs), la bande des bords (40 à 48).
- Direction : forteresse arrachée à un siège, machinerie steampunk sobre (laiton, chaudières,
  mécanismes d'horlogerie), fractures de cristal cyan, rares cristaux violets.
- Les bords de tuiles respectent des **connecteurs** standard (passage au sol, passage sur
  rempart, mur plein) pour que n'importe quelle tuile se raccorde à ses voisines.

### Tuiles de la vertical slice

| Tuile | Rôle de gameplay | Verticalité |
|---|---|---|
| **Donjon** (centre, unique) | Gardien, Faille finale | Forte |
| **Cour d'armes** | Combat ouvert | Faible |
| **Remparts** | Chemins en hauteur, tireurs | Forte |
| **Tour de guet** | Point de vue, autel de relique possible | Très forte |
| **Village fortifié** | Pillage, combat rapproché | Moyenne |
| **Pont-levis et douves** | Passage risqué | Moyenne |
| **Crypte** | Souterrain, butin rare | Intérieur |
| **Bord d'Éclat** | Apparition des escouades, roche qui s'effrite | Faible |

### Génération (✅ v0.5.0)
- Plan pur `Shared/Eclat/EclatLayout` (graine → grille, testé) : Donjon au centre, Bords d'Éclat
  au milieu de chaque côté (apparition des escouades), Remparts / Tour de guet aux coins, le reste
  tiré dans des réserves fixes (les 8 types toujours présents, une seule Crypte).
- Bords partagés : `Open` (pas de mur), `Gates` (mur à deux portes) ou `Rampart` (une porte et
  un chemin de ronde à deux rampes) : toujours au moins deux passages. Le Donjon est toujours muré.
- Construction : `Server/Place/Lib/TileKit` (greybox provisoire, ≈ 1 000 pièces pour 25 tuiles),
  intérieur tourné d'un quart de tour aléatoire. Les clients recalculent le plan à partir de la
  graine (attributs du workspace) : rien d'autre n'est envoyé.

### Effondrement
Une tuile qui s'effondre se fissure (lueur et bruit d'alerte 30 s avant), puis se désagrège en
morceaux qui tombent dans le Vide. Effet réalisé dans Roblox (pièces détachées, particules),
**pas** dans Blender.

## 3. Règles de conception des niveaux

- Toujours **au moins deux chemins** entre deux tuiles voisines.
- Couverts réguliers (tous les 15 à 20 studs) pour que le combat à distance reste jouable.
- Des surfaces escaladables lisibles (rebords clairs, pierre plus claire) : le joueur doit
  voir où il peut grimper.
- Budget mobile : un Éclat complet sous environ 60 000 pièces et maillages, StreamingEnabled activé.
