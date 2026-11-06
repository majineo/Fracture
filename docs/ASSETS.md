# Suivi des modèles 3D et assets

> Aucun modèle n'existe encore. Chaque asset passe par les étapes ci-dessous.

**Étapes** : 💭 À concevoir → 📋 À créer (Blender) → 🔧 En création → 📦 À intégrer (Studio) → ✅ Intégré

## Normes techniques pour Blender → Roblox

- **Échelle** : 1 stud = 0,28 m. Régler l'échelle d'unités de la scène Blender en conséquence.
- **Budget** : 20 000 triangles maximum par MeshPart (viser beaucoup moins pour les décors répétés).
- **Textures** : 1024 px maximum (Roblox réduit au-delà), PBR via SurfaceAppearance
  (couleur, normale, rugosité, métal).
- **Modularité** : décors en kits sur une grille fixe (8 studs à confirmer) pour les tuiles d'Éclat.
- **Fichiers** : sources `.blend` dans `assets/blender/`, textures dans `assets/textures/`.
- Les effets (désintégration, particules) se font dans Roblox, pas dans Blender.

## Liste des assets

Ordre de création : voir [GDD 10 — Direction artistique](GDD/10-direction-artistique.md), §5.

| # | Asset | Catégorie | Statut | Notes |
|---|---|---|---|---|
| 1 | Relique « Pas de Faille » | Objet | 📋 À créer | Premier modèle : valide le pipeline Blender → Studio |
| 2 | Relique « Stase » | Objet | 📋 À créer | |
| 3 | Relique « Onde de choc » | Objet | 📋 À créer | |
| 4 | Lame courte | Arme | ✅ Intégrée (v0.4.2) | `assets/blender/weapons/Lame_Courte.fbx` — 1 064 triangles, 4 pièces (acier, cuir, laiton, noyau cyan). Intégration : `ServerStorage > WeaponModels > weapon.short_blade` avec une pièce « Grip » |
| 5 | Pistolet de Fractureur | Arme | ✅ Intégré (v0.4.2) | `assets/blender/weapons/Pistolet_Fractureur.fbx` — 1 928 triangles, 4 pièces (métal sombre, laiton, cuir, noyau temporel cyan en cage). `ServerStorage > WeaponModels > weapon.fracture_pistol`, pièce « Grip », attachement « Muzzle » |
| 21 | Mannequin d'entraînement | Décor | 📋 À créer (avatar gris provisoire) | Champ de tir du Refuge |
| 22 | Sons de combat (tir, rechargement, coups, touche) | Audio | 📦 Provisoires | `src/client/Core/Combat/CombatSounds.luau` ; à valider à l'oreille |
| 6 | Fusil à répétition | Arme | 📋 À créer | |
| 7 | Arbalète lourde | Arme | 📋 À créer | Époque médiévale |
| 8 | Épée longue | Arme | 📋 À créer | Époque médiévale |
| 9 | Grappin | Outil | 📋 À créer | Animation de lancer |
| 10 | Harnais et ancre de Fractureur | Accessoire avatar | 📋 À créer | Compatible avatars R15 |
| 11 | Kit modulaire médiéval (murs, sols, escaliers, arches, toits) | Décor | 📋 À créer | Grille 8 studs, atlas partagé |
| 12 | 8 tuiles médiévales | Décor | 📋 À assembler | Assemblées dans Studio à partir du kit |
| 13 | Homme d'armes figé | Créature | 📋 À créer | Rig humanoïde partagé |
| 14 | Arbalétrier figé | Créature | 📋 À créer | Même rig que #13 |
| 15 | Le Roi Sans Heure | Gardien | 📋 À créer | En dernier ; rig dédié, ~10 animations |
| 16 | Refuge (tour d'horlogerie, engrenages) | Décor | 📋 À créer | Compact |
| 17 | Animation de glissade | Animation (R15) | ✅ Procédurale (v0.3.1) | Remplaçable plus tard par une animation faite main |
| 18 | Animation d'escalade de rebord | Animation (R15) | ✅ Procédurale (v0.3.1) | Deux poses : attraper, se hisser |
| 19 | Pose de traction au grappin | Animation (R15) | ✅ Procédurale (v0.3.1) | Bras orienté dynamiquement vers la cible |
| 20 | Sons de déplacement (glissade, grappin, réception) | Audio | 📦 Provisoires | Sons gratuits du Creator Store choisis sans écoute : à valider (`Animation/SoundConfig.luau`) |


## Maillages importés sur Roblox

Les modèles intégrés vivent dans la place de travail (`ServerStorage > WeaponModels`) :
**enregistrer la place** pour ne pas les perdre. Identifiants (pour les retrouver ou les
réassembler) :

| Arme | Pièce | MeshId | Matériau Roblox |
|---|---|---|---|
| weapon.fracture_pistol | Pistolet_Fractureur_Metal | rbxassetid://136727715410671 | Metal #2a2d34 |
| weapon.fracture_pistol | Pistolet_Fractureur_Laiton | rbxassetid://75505052139731 | Metal #b0803a |
| weapon.fracture_pistol | Pistolet_Fractureur_Cuir | rbxassetid://107858234220332 | Fabric #5c341e |
| weapon.fracture_pistol | Pistolet_Fractureur_Noyau | rbxassetid://99942161871311 | Neon #50e6ff |
| weapon.short_blade | Lame_Courte_Acier | rbxassetid://130473401108498 | Metal #bec6ce |
| weapon.short_blade | Lame_Courte_Laiton | rbxassetid://84430999824243 | Metal #b0803a |
| weapon.short_blade | Lame_Courte_Cuir | rbxassetid://105872046578087 | Fabric #5c341e |
| weapon.short_blade | Lame_Courte_Noyau | rbxassetid://109126005441182 | Neon #50e6ff |

## Procédure d'import (vérifiée en v0.4.2)

1. Studio → **Fichier → Importer** (Ctrl+M) → choisir le `.fbx` → **Importer**.
2. L'importeur lit les fichiers Blender en **centimètres** : réduire le modèle à l'échelle
   0,01 (fait par Claude via Studio).
3. Matériaux par suffixe de pièce (`_Metal`, `_Laiton`, `_Cuir`, `_Noyau`, `_Acier`),
   poignée invisible « Grip » à l'origine (-Z = avant), attachement « Muzzle » au canon,
   rangement dans `ServerStorage > WeaponModels > <id>` (fait par Claude).