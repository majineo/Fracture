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
| 6 | Fusil à répétition | Arme | ✅ Intégré (v0.4.3, crosse raccourcie en v0.4.4) | `Fusil_Repetition.fbx` — 2 036 triangles, 4 pièces (bois, laiton, métal, tube cyan) ; jauge cyan côté visible. Crosse ramenée de 1,55 à 1,0 stud (v0.4.4) : les bras d'un avatar Roblox ne pouvaient pas tenir l'arme. Ancienne version archivée dans `ServerStorage > ArchiveModels` |
| 7 | Arbalète lourde | Arme | ✅ Intégrée (v0.4.3) | `Arbalete_Lourde.fbx` — 1 232 triangles, 6 pièces (bois, acier, cuir, laiton, métal, carreau cyan) ; manivelle côté visible |
| 8 | Épée longue | Arme | ✅ Intégrée (v0.4.3) | `Epee_Longue.fbx` — 1 208 triangles, 4 pièces (acier, cuir, laiton, gorge cyan) |
| 23 | Présentoir d'armurerie | Décor | 📋 À créer (bloc provisoire) | Refuge, 5 exemplaires |
| 9 | Grappin | Outil | 📋 À créer | Animation de lancer |
| 10 | Harnais et ancre de Fractureur | Accessoire avatar | 📋 À créer | Compatible avatars R15 |
| 11 | Kit modulaire médiéval (murs, sols, escaliers, arches, toits) | Décor | 📋 À créer | Grille 8 studs, atlas partagé |
| 12 | 8 tuiles médiévales | Décor | 📋 À assembler | Assemblées dans Studio à partir du kit |
| 13 | Homme d'armes figé | Créature | ✅ Intégré (v0.4.4) | Équipement sur le corps R15 standard : `assets/blender/enemies/Homme_Armes_Equipement.fbx` — 1 222 triangles, 13 pièces (fer rouillé, cuir, laiton, fissures cyan) ; épée rouillée `Epee_Rouillee.fbx` — 268 triangles, 4 pièces. Source : `echoues.blend` |
| 14 | Arbalétrier figé | Créature | ✅ Intégré (v0.4.4) | `assets/blender/enemies/Arbaletrier_Equipement.fbx` — 692 triangles, 11 pièces (tissu rouge, cuir, laiton, bois, éclats cyan) ; tient l'arbalète lourde |
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
| weapon.repeating_rifle | Fusil_Repetition_Bois | rbxassetid://102644175117053 | Wood #704224 |
| weapon.repeating_rifle | Fusil_Repetition_Laiton | rbxassetid://76392487805945 | Metal #b0803a |
| weapon.repeating_rifle | Fusil_Repetition_Metal | rbxassetid://132747657906035 | Metal #2a2d34 |
| weapon.repeating_rifle | Fusil_Repetition_Noyau | rbxassetid://82732534525727 | Neon #50e6ff |
| weapon.heavy_crossbow | Arbalete_Lourde_Acier | rbxassetid://112649187551456 | Metal #bec6ce |
| weapon.heavy_crossbow | Arbalete_Lourde_Bois | rbxassetid://72894353011037 | Wood #704224 |
| weapon.heavy_crossbow | Arbalete_Lourde_Cuir | rbxassetid://104004205600598 | Fabric #5c341e |
| weapon.heavy_crossbow | Arbalete_Lourde_Laiton | rbxassetid://98408635731593 | Metal #b0803a |
| weapon.heavy_crossbow | Arbalete_Lourde_Metal | rbxassetid://133037587155497 | Metal #2a2d34 |
| weapon.heavy_crossbow | Arbalete_Lourde_Noyau | rbxassetid://73814119236423 | Neon #50e6ff |
| enemy.rusty_sword | Epee_Rouillee_Cuir | rbxassetid://73770220924004 | Fabric #5c341e |
| enemy.rusty_sword | Epee_Rouillee_Fer | rbxassetid://113003109992848 | CorrodedMetal #745c48 |
| enemy.rusty_sword | Epee_Rouillee_Metal | rbxassetid://133447753616193 | Metal #2a2d34 |
| enemy.rusty_sword | Epee_Rouillee_Noyau | rbxassetid://139267997302155 | Neon #50e6ff |
| weapon.longsword | Epee_Longue_Acier | rbxassetid://119407037791299 | Metal #bec6ce |
| weapon.longsword | Epee_Longue_Cuir | rbxassetid://123406162985384 | Fabric #5c341e |
| weapon.longsword | Epee_Longue_Laiton | rbxassetid://96705191657164 | Metal #b0803a |
| weapon.longsword | Epee_Longue_Noyau | rbxassetid://102522485897363 | Neon #50e6ff |

### Équipements des Échoués (`ServerStorage > EnemyOutfits`, v0.4.4)

Chaque pièce est nommée `PartieDuCorps__Pièce__Matériau` : le serveur la soude à la partie du
corps indiquée (`EnemyService`). Repère du modèle : racine du personnage à l'origine.

| Équipement | Pièce | MeshId | Matériau Roblox |
|---|---|---|---|
| Homme_Armes_Equipement | Head__Bord__Fer | rbxassetid://114261346330204 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | Head__Casque__Fer | rbxassetid://118728370524120 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | Head__Fissure__Noyau | rbxassetid://96528245734788 | Neon #50e6ff |
| Homme_Armes_Equipement | LeftUpperArm__Epauliere__Fer | rbxassetid://108251813118877 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | RightUpperArm__Epauliere__Fer | rbxassetid://78386511751580 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | LowerTorso__Boucle__Laiton | rbxassetid://89543029447631 | Metal #b0803a |
| Homme_Armes_Equipement | LowerTorso__Ceinture__Cuir | rbxassetid://80237460874594 | Fabric #5c341e |
| Homme_Armes_Equipement | UpperTorso__Dossiere__Fer | rbxassetid://139136452687119 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | UpperTorso__Plastron__Fer | rbxassetid://132985266726614 | CorrodedMetal #745c48 |
| Homme_Armes_Equipement | UpperTorso__FissurePlastron__Noyau | rbxassetid://76705548898603 | Neon #50e6ff |
| Homme_Armes_Equipement | UpperTorso__Eclat1__Noyau | rbxassetid://116533437334484 | Neon #50e6ff |
| Homme_Armes_Equipement | UpperTorso__Eclat2__Noyau | rbxassetid://135778174466468 | Neon #50e6ff |
| Homme_Armes_Equipement | UpperTorso__Eclat3__Noyau | rbxassetid://99448566042369 | Neon #50e6ff |
| Arbaletrier_Equipement | Head__Capuche__Tissu | rbxassetid://109335685550614 | Fabric #7b231b |
| Arbaletrier_Equipement | Head__Pan__Tissu | rbxassetid://85474362491758 | Fabric #7b231b |
| Arbaletrier_Equipement | Head__Queue__Tissu | rbxassetid://72664513560886 | Fabric #7b231b |
| Arbaletrier_Equipement | LeftUpperArm__Eclat1__Noyau | rbxassetid://129981994807214 | Neon #50e6ff |
| Arbaletrier_Equipement | UpperTorso__Carquois__Cuir | rbxassetid://125320135334169 | Fabric #5c341e |
| Arbaletrier_Equipement | UpperTorso__Carreau1__Bois | rbxassetid://76055159599200 | Wood #704224 |
| Arbaletrier_Equipement | UpperTorso__Carreau2__Bois | rbxassetid://135546012327485 | Wood #704224 |
| Arbaletrier_Equipement | UpperTorso__Carreau3__Bois | rbxassetid://122001051930426 | Wood #704224 |
| Arbaletrier_Equipement | UpperTorso__Eclat2__Noyau | rbxassetid://97841030846391 | Neon #50e6ff |
| Arbaletrier_Equipement | UpperTorso__Pourpoint__Cuir | rbxassetid://128310612555875 | Fabric #5c341e |
| Arbaletrier_Equipement | UpperTorso__Sangle__Laiton | rbxassetid://76912599458458 | Metal #b0803a |

## Procédure d'import (vérifiée en v0.4.2)

1. Studio → **Fichier → Importer** (Ctrl+M) → choisir le `.fbx` → **Importer**.
2. L'importeur lit les fichiers Blender en **centimètres** : réduire le modèle à l'échelle
   0,01 (fait par Claude via Studio).
3. Matériaux par suffixe de pièce (`_Metal`, `_Laiton`, `_Cuir`, `_Noyau`, `_Acier`),
   poignée invisible « Grip » à l'origine (-Z = avant), attachement « Muzzle » au canon,
   rangement dans `ServerStorage > WeaponModels > <id>` (fait par Claude).
4. N'importer que les fichiers nouveaux ou modifiés : réimporter une arme déjà intégrée
   crée un doublon (v0.4.4 : quatre doublons supprimés).