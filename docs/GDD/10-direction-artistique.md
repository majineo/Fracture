# 10 — Direction artistique et pipeline Blender

> Statut : 📋 Prévu. Aucun asset n'existe encore.

## 1. Style

- **Semi-stylisé** : formes simples et silhouettes lisibles, proportions légèrement exagérées,
  matériaux PBR sobres. Plus détaillé que le style Roblox de base, mais pas réaliste.
- Raison : lisible en combat sur petit écran, réalisable par un débutant, léger sur mobile.

## 2. Signature visuelle de la Brisure

Commune à toutes les époques, c'est l'identité du jeu :
- **Cyan électrique** = temps figé (reliques, Stase, Échoués).
- **Orange brûlé** = temps qui s'effondre (fissures, alertes, Faille).
- Fragments de décor qui flottent au bord des tuiles, objets figés en plein mouvement.
- Ces effets sont réalisés dans Roblox (Neon, particules, Beams), pas dans Blender.

## 3. Palette de la forteresse médiévale

Pierre gris-bleu, bois sombre, bannières rouge sang délavé, brume bleu pâle.
Les accents cyan et orange de la Brisure ressortent fortement sur cette base terne.

## 4. Normes techniques Blender → Roblox

| Règle | Valeur |
|---|---|
| Échelle | 1 stud = 0,28 m ; scène Blender réglée en conséquence |
| Grille des kits | 8 studs |
| Triangles par maillage | 20 000 maximum ; viser 500 à 3 000 pour un module de décor |
| Textures | 1024 px maximum, souvent 512 px ; atlas partagés par kit |
| Matériaux | SurfaceAppearance (couleur, normale, rugosité, métal) |
| Export | FBX, une pièce par module, origine en bas au centre |
| Collisions | Boîtes simples dans Roblox (CollisionFidelity Box ou Hull), jamais la précision par défaut |
| Personnages | Rig compatible R15 pour les Échoués |

## 5. Ordre d'apprentissage Blender

| Étape | Asset | Ce qu'on apprend |
|---|---|---|
| 1 | **Relique « Pas de Faille »** | Modélisation simple, matériaux, export, import dans Studio |
| 2 | Les deux autres reliques | Réutilisation, variété rapide |
| 3 | Lame courte, pistolet | Proportions, normal maps, prise en main |
| 4 | Kit de murs et sols | Modularité, grille, atlas de textures |
| 5 | Tuiles complètes | Assemblage dans Studio |
| 6 | Homme d'armes figé | Rig, skinning, animations |
| 7 | Gardien | Gros personnage, animations complexes |

## 6. Ce qui n'est pas fait dans Blender

- Les personnages des joueurs (avatars Roblox).
- Les effets visuels (particules, désintégration, lueurs).
- L'interface (créée dans Roblox, icônes éventuellement générées en image).
