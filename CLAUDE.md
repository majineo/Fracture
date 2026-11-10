# Règles de travail — projet FRACTURE

Jeu Roblox d'extraction PvPvE (univers des Éclats temporels). Développeur solo débutant ;
Claude est l'associé technique et créatif. Tout échange avec l'utilisateur se fait **en français**.

## Méthode
- Prendre les décisions techniques et de détail de façon autonome, explications courtes ;
  faire « le meilleur possible ». Les décisions de direction (concept, règles majeures,
  actions irréversibles ou publiques, dépenses) restent soumises à validation (D-013).
- Ne jamais valider une idée par complaisance : signaler ce qui est mauvais ou risqué.
- Distinguer toujours : ✅ implémenté · 🔧 en cours · 📋 prévu · 💭 à l'étude.
- Ne jamais prétendre avoir testé, sauvegardé ou envoyé quelque chose sans l'avoir fait.
- Tester chaque système dans Studio (outils MCP Roblox Studio) avant de le déclarer terminé ;
  le ressenti au clavier / tactile reste à valider par l'utilisateur.

## 3D : Blender systématiquement
- **Dès qu'un objet 3D est nécessaire (arme, décor, objet, créature…), le modéliser dans
  Blender** (serveur MCP Blender connecté), sans attendre qu'on le demande. Les formes
  provisoires faites en code ne servent qu'en attendant le modèle.
- Normes : 1 unité Blender = 1 stud ; style semi-stylisé lisible ; peu de polygones (arme
  < 3 000 triangles) ; une pièce séparée par matériau (métal, cuir, cuivre, néon cyan…) pour
  pouvoir régler couleur et matériau dans Studio ; origine à la poignée pour les objets tenus.
- Sources `.blend` et exports `.fbx` dans `assets/blender/` ; suivre l'état dans `docs/ASSETS.md`.
- Intégration des armes : `ServerStorage > WeaponModels > <id de l'arme>` avec une pièce
  « Grip » et, pour les armes à feu, un attachement « Muzzle » (voir `src/server/Core/Lib/WeaponModels.luau`).
- Leçons du premier import (v0.4.2) : l'importeur Studio lit les FBX Blender en centimètres
  (réduire à 0,01) ; canon / lame vers -Y dans Blender = -Z dans Roblox ; le +X de Blender
  devient le côté GAUCHE de l'arme tenue en main droite → placer les détails à montrer à la
  caméra d'épaule (droite) du côté -X dans Blender. L'utilisateur doit faire l'import
  (Fichier → Importer) : le reste se fait via Studio MCP. Procédure : `docs/ASSETS.md`.
- Régler une pose difficile (deux mains sur une arme…) par **recherche automatique** sur un
  clone figé du personnage (sans Animator) plutôt qu'à l'œil : voir GreatswordGuard, v0.4.3.
- Vérifier l'orientation en main en mesurant `LookVector` (= -Z, l'avant) et `UpVector` de la
  poignée dans le repère du corps — attention à ne pas inverser le signe.
- Ne jamais présenter une greybox comme un résultat : l'utilisateur juge l'ambiance et la qualité
  visuelle (style : forteresse gothique sombre, énergie cyan intégrée — voir le coffre Obsidian).

## Documentation Obsidian (obligatoire)
- Le coffre `C:/Users/neost/Documents/fracture vault` est la base de connaissance centrale.
  `Fracture/Environment/*` (Overview, Art-Direction, Map-Layout, Tile-Documentation, Asset-Library,
  Gameplay-Readability, Technical-Specifications, Progress-Log, Issues-and-Decisions,
  Export-Manifest) : notes **tenues à la main**, à mettre à jour après chaque étape importante.
- Statuts : NOT STARTED · IN PROGRESS · NEEDS REVIEW · APPROVED · COMPLETED. Séparer le confirmé
  des hypothèses ; ne jamais noter un export non vérifié comme testé ; ne rien effacer sans le dire.
- Notes générées (`généré: true`) : `lune run tools/export_catalog` puis `python tools/obsidian_sync.py`.
- Fin de séance : rapport court (créé / modifié, notes mises à jour, inachevé, à approuver, limites).

## Versions et Git
- Chaque version : entrée complète dans `CHANGELOG.md` (10 rubriques), `Config.GAME_VERSION`,
  commit, tag annoté `vX.Y.Z`, push, release GitHub (préversion tant que < 1.0).
- Ne jamais réécrire l'historique publié ni forcer un push sur `main`.
- Décisions importantes dans `docs/DECISIONS.md` (on ajoute, on n'efface pas).

## Code
- Luau `--!strict`, un seul Script serveur et un seul LocalScript, tout le reste en
  ModuleScripts (voir `docs/ARCHITECTURE.md`). Remotes déclarés dans
  `src/shared/Net/Definitions.luau` ; tout argument client validé côté serveur.
- Logique critique en modules purs testés par Lune (`lune run tests/run`).
- Avant chaque commit : `stylua src tests`, `selene src`, `lune run tests/run`, `rojo build`.
- Dans PowerShell, écrire les fichiers en UTF-8 **sans BOM** (le BOM casse StyLua/Selene).
- Rojo : positions des pièces toujours via `CFrame` explicite, jamais `Position`.

## Environnement
- Rojo : `rojo serve places/refuge.project.json` depuis le dossier du projet.
- Outils (Rokit) : `%USERPROFILE%\.rokit\bin` ; Git / gh : recharger le PATH machine dans les
  commandes PowerShell si besoin.
- Le module caméra Roblox (`PlayerModule`) n'est pas accessible aux scripts dans cette version :
  la caméra est faite maison pour tous les cas (`Controllers/PlayerCamera`, calculs dans
  `Shared/Camera/CameraMotion`).
