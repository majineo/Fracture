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
- Une **tuile** = un carré de **64 × 64 studs** au sol, assemblé à partir d'un **kit modulaire**
  sur une grille de 8 studs (murs, sols, escaliers, arches, toits).
- Un Éclat de la vertical slice = grille de **5 × 5 tuiles**. Le centre est toujours le Donjon.
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
