# Historique des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), numérotation
décrite dans [docs/VERSIONING.md](docs/VERSIONING.md). Chaque version porte un tag Git `vX.Y.Z`.

---

## [v0.10.0] — 2026-11-08 — « Arsenal de la Fracture »

### Description générale
Quatre nouvelles armes steampunk / arcanes modélisées dans Blender, chacune avec une capacité
inédite, disponibles à l'Arsenal du Refuge.

### Nouvelles fonctionnalités
- **Tromblon à vapeur** (arme à feu) : 8 plombs par tir (88 dégâts au contact, presque rien
  au-delà de 30 studs), 2 coups. Capacité **Souffle de vapeur** : cône de 11 studs qui blesse,
  repousse et étourdit ; le tireur est projeté en arrière (propulsion, utile en l'air).
- **Mitrailleuse à manivelle** (arme à feu) : **tir automatique** (9 balles/s, chargeur de 45),
  bloc de 6 canons qui tourne. Capacité **Surchauffe** : cadence ×1,8 et munitions gratuites
  pendant 4 s.
- **Marteau-piston** (mêlée) : coups lents et lourds, attaque chargée ×2,2. Capacité
  **Frappe sismique** : onde circulaire de 10 studs qui soulève, blesse (45 au centre) et étourdit.
- **Faux du Temps** (mêlée) : grande allonge, coups larges (140°). Capacité **Moisson** :
  tourbillon à 360° (32 dégâts par cible) qui rend 40 % des dégâts en santé (45 au plus).
- Effets : cône de vapeur, onde au sol avec anneau lumineux, sons de tir dédiés.
- Arsenal du Refuge : 10 présentoirs.

### Modifications
- Plombs tirés par le serveur ; tir continu côté client ; projection des joueurs par le serveur.
- `WeaponState.canFire` accepte un multiplicateur de cadence.
- `assets/roblox/WeaponModels.rbxm` mis à jour (les 4 armes dans la place Éclat).

### Corrections de bugs
- Alerte de l'analyseur de code (Selene) dans l'animation de roulade de la v0.9.0
  (`Vector3.yAxis`, valide en jeu mais inconnu de Selene).

### Vérifications
- Studio (Refuge) : 10 présentoirs ; mitrailleuse : 9 balles en 1 s en maintenant le clic ;
  Surchauffe : 1,5 s de tir sans perdre de munition ; Frappe sismique : 2 ennemis
  120 → 80 et 82, étourdis ; Souffle : 2 ennemis touchés et étourdis, tireur projeté ; Moisson
  (vraie touche) : les deux ennemis touchés.
- 117 tests Lune (5 nouveaux : gerbe de plombs, Surchauffe, cohérence des nouvelles armes).

### Problèmes connus
- Sons de tir du tromblon, de la mitrailleuse et du souffle choisis sans écoute.
- Tenue du marteau et de la faux : posture de l'épée longue ; à valider à l'écran.
- Équilibrage à affiner après des parties réelles.

### Fichiers
- **Ajoutés** : `assets/blender/weapons/{build_arsenal.py,arsenal.blend,Tromblon_Vapeur.fbx,Mitrailleuse_Manivelle.fbx,Marteau_Piston.fbx,Faux_Temps.fbx}`,
  `tests/specs/Arsenal.spec.luau`
- **Modifiés** : `src/shared/Combat/{WeaponDefs,Ability,WeaponState,HitMath}.luau`,
  `src/server/Core/Systems/{WeaponService,AbilityService}.luau`,
  `src/server/Refuge/Systems/Armory.luau`,
  `src/client/Core/Controllers/{CombatController,AbilityController,CharacterAnimation}.luau`,
  `src/client/Core/Combat/{WeaponFx,CombatSounds}.luau`, `assets/roblox/WeaponModels.rbxm`,
  `tests/run.luau`, `src/shared/Config.luau`, `docs/{ASSETS,DECISIONS}.md`, `CHANGELOG.md`
- **Supprimés** : —

### Prochaines étapes
- Ville steampunk / arcane modélisée dans Blender ; carte de l'Éclat plus grande et fermée.

---

## [v0.9.0] — 2026-11-08 — « Laiton et voltige »

### Description générale
Une seule interface pour tout le jeu, enfin cliquable, et deux nouveaux mouvements : la roulade
et le salto. Les vrais modèles Blender (armes, armure du Roi, kit de forteresse) sont aussi dans
la place Éclat de test.

### Nouvelles fonctionnalités
- **Fenêtre unique** (Tab ou I) : le **sac** dans l'Éclat (12 emplacements, fiche détaillée,
  bouton Utiliser, onglets Codex et Aide) et le **coffre** au Refuge (onglets Coffre, Codex,
  Profil, Aide) ont exactement le même style : encre, cadres de laiton à rivets, néon cyan.
- **Souris libre** dans toute fenêtre ouverte, même arme en main ; un clic dans la fenêtre ne tire
  plus ; un clic hors de la fenêtre la ferme.
- **Fiches d'objets** : description de chaque objet et relique.
- **Page d'aide** : toutes les commandes (la touche de capacité s'affiche selon le clavier :
  « A » en AZERTY).
- **Invites au style du jeu** (« E Fouiller · Caisse ») : cartouche laiton, jauge de maintien,
  cliquables à la souris ou au doigt.
- **Roulade** : C en marchant (28 studs/s, 0,42 s) ; C juste avant d'atterrir après une chute
  rapide = roulade de réception qui garde l'élan.
- **Salto** : saut en l'air, une fois par saut (rechargé au sol ou sur un mur), avant ou arrière
  selon la direction ; rotation complète du corps.
- Bouton « Sac » sur écran tactile.

### Modifications
- Barre d'objets, jauges, bilan d'extraction, pastilles du Codex : thème commun ; le bilan est
  une fenêtre (la fermer = repartir).
- Place Éclat de test : armes, tenues et kit de forteresse importés depuis `assets/roblox/*.rbxm`.
- La liste des joueurs de Roblox est masquée (Tab ouvre le sac).

### Corrections de bugs
- **Impossible de cliquer dans le coffre, le sac ou le bilan arme en main** : la caméra d'épaule
  reverrouillait la souris au centre à chaque image.
- Pendant les tests : un clic dans une zone vide d'une fenêtre la fermait.

### Vérifications
- Studio (Éclat) : sac ouvert par Tab arme en main → souris libre, clic sur un objet → fiche et
  « Utiliser », clic dans la fenêtre → aucun tir (12/12), clic dehors → fermeture.
- Studio (Refuge) : coffre → sélection d'une relique intacte → « Stabiliser » → Codex niveau 1 →
  « Équiper » (1/2).
- Salto : vitesse verticale 48, rotation mesurée sur l'articulation de la racine ; roulade :
  9 studs, vitesse 28 ; roulade de réception déclenchée après une chute de 30 studs.
- Invite personnalisée affichée devant une caisse ; 112 tests Lune.

### Problèmes connus
- Ressenti de la roulade et du salto à valider au clavier et au tactile.
- Manette : pas encore de bouton pour ouvrir le sac.
- Quelques sons choisis sans écoute renvoient une erreur de chargement (identifiants à remplacer).

### Fichiers
- **Ajoutés** : `src/client/Core/Ui/{Theme,Menu,ItemViews}.luau`,
  `src/client/Core/Controllers/PromptStyle.luau`, `src/client/Eclat/Controllers/SacUi.luau`,
  `src/client/Core/Movement/{Roll,Flip}.luau`, `assets/roblox/*.rbxm`
- **Modifiés** : `src/client/Core/Controllers/{ShoulderCamera,CombatController,MovementController,CharacterAnimation,CameraFeel}.luau`,
  `src/client/Eclat/Controllers/LootHud.luau`, `src/client/Refuge/Controllers/VaultUi.luau`,
  `src/server/Core/Systems/MovementState.luau`, `src/shared/Movement/MovementConfig.luau`,
  `src/shared/Loot/ItemDefs.luau`, `src/shared/Config.luau`, `places/eclat.project.json`,
  `docs/{DECISIONS,ASSETS}.md`, `CHANGELOG.md`
- **Supprimés** : —

### Prochaines étapes
- Nouvelles armes à capacités spéciales ; ville steampunk / arcane modélisée dans Blender ; carte
  de l'Éclat plus grande, à explorer.

---

## [v0.8.1] — 2026-11-08 — « Armure du Roi »

### Description générale
L'armure du Roi Sans Heure est modélisée dans Blender ; le jeu la porte automatiquement dès
qu'elle est importée, à la place de la couronne provisoire.

### Nouvelles fonctionnalités
- **Armure du Roi** (`assets/blender/enemies/build_roi.py`, 1 264 triangles, 17 pièces) :
  couronne dorée à fleurons sertie de cristaux, plastron d'acier à arête dorée, col, cape royale
  indigo, épaulières bordées de laiton, ceinture et tassettes, jambières et genouillères.
- Pose automatique : pièces soudées à la partie du corps de leur nom, agrandies ×3 avec le Roi,
  couleurs et matériaux d'après le suffixe ; la couronne importée reste le point faible
  (surbrillance quand elle est exposée).

### Modifications
- `docs/ASSETS.md` : procédure d'import de l'armure.

### Corrections de bugs
- —

### Vérifications
- Blender : deux rendus (épaulières reprises : bordures couchées, dômes lissés).
- Studio, avec une armure de test aux bons noms : soudée à la tête, agrandie ×3, métal doré,
  pas de couronne provisoire.
- 112 tests Lune.

### Problèmes connus
- **Armure pas encore importée** (import FBX par l'utilisateur) : couronne provisoire jusque-là.

### Fichiers
- **Ajoutés** : `assets/blender/enemies/{build_roi.py,Roi_Equipement.fbx}`
- **Modifiés** : `src/server/Eclat/Systems/GuardianService.luau`,
  `src/client/Eclat/Controllers/GuardianHud.luau`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/ASSETS.md`
- **Supprimés** : —

### Prochaines étapes
- Importer le kit de forteresse et l'armure ; tests à plusieurs joueurs ; Signature.

---

## [v0.8.0] — 2026-11-08 — « Le Roi Sans Heure »

### Description générale
Le Gardien de la vertical slice : au début de la Faille finale, le Roi Sans Heure s'éveille dans
la cour du Donjon. Trois phases, des attaques toutes annoncées, un point faible, et un trésor.

### Nouvelles fonctionnalités
- **Le Roi Sans Heure** : trois fois la taille d'un joueur, 1 500 PV (+50 % par joueur
  supplémentaire présent), épée longue, couronne dorée (point faible).
- **Phase 1 « Le Roi »** : coups d'épée en arc (35 dégâts) et charge en ligne droite (45 dégâts,
  projette) ; une charge qui ne touche personne le laisse **étourdi 2,5 s, couronne exposée** :
  tirs à la tête ×2.
- **Phase 2 « La Couronne brisée »** (60 %) : invoque 3 hommes d'armes (une fois) ; onde de choc
  temporelle (25 dégâts + ralentissement, 20 studs).
- **Phase 3 « Le Temps arrêté »** (25 %) : gèle une zone sous chaque joueur de l'arène ; toutes
  les préparations et recharges ×0,7.
- **Arène** : la tuile du Donjon (il ne passe pas les portes) ; il ne vise que les joueurs entrés,
  et retourne à son trône sinon.
- **Lisibilité** : zone rouge au sol pendant chaque préparation (arc, bande de charge, cercle
  d'onde), son d'alerte, barre de vie et phase en haut de l'écran, couronne en surbrillance et
  « COURONNE EXPOSÉE » quand elle est vulnérable ; annonces (réveil, phases, invocation, chute).
- **Trésor du Roi** à sa mort : une relique intacte, 3 Pierres de Faille, 4 Aciers anciens,
  150 Grains.
- Test dans Studio : attribut `QA_SummonGuardian`.

### Modifications
- Cerveau du Gardien en module pur testé (`Shared/Combat/GuardianBrain`) ; EnemyService ne
  pilote pas les ennemis « Boss » ; `CombatTargets.remeasure` (zone de touche après agrandissement) ;
  HealthService : tirs à la tête ×2 sur une couronne exposée.

### Corrections de bugs
- Pendant les tests : zone de touche du Roi mesurée avant l'agrandissement (tirs qui ne portaient
  pas) ; Roi tombé du toit du donjon et bloqué contre l'enceinte (arène et trône déplacés dans la cour).

### Vérifications (Studio)
- 6 tests du cerveau (phases sans retour, coup annoncé, charge puis étourdi, invocation unique,
  phase 3 plus rapide, sans cible) ; 112 tests au total.
- Réveil : 17,5 studs, 1 500 PV, couronne ; charge → « Charging » → étourdi, couronne exposée ;
  coups qui portent ; barre de vie affichée (capture).
- Phase 2 : 3 gardes invoqués ; phase 3 : onde, coups, zone gelée sous le joueur.
- Mort : « Trésor du Roi » posé, annonce reçue.

### Problèmes connus
- Corps R15 agrandi avec poses procédurales : le rig dédié et ses animations (GDD 07 §4) restent
  à faire, ainsi que son armure Blender (couronne provisoire en pièces).
- Équilibrage à jouer : dégâts, santé, fréquence des attaques ; non testé à plusieurs joueurs.
- La Faille finale reste sur le toit du donjon, sans obstacle particulier.

### Fichiers
- **Ajoutés** : `src/shared/Combat/GuardianBrain.luau`,
  `src/server/Eclat/Systems/GuardianService.luau`, `src/client/Eclat/Controllers/GuardianHud.luau`,
  `tests/specs/GuardianBrain.spec.luau`
- **Modifiés** : `src/shared/Combat/EnemyDefs.luau`,
  `src/server/Core/Systems/{EnemyService,HealthService,CombatTargets}.luau`, `tests/run.luau`,
  `src/shared/Config.luau`, `CHANGELOG.md`, `docs/ROADMAP.md`, `docs/GDD/07-ennemis.md`
- **Supprimés** : —

### Prochaines étapes
- Tests à plusieurs joueurs (PvP, partage de l'arène) ; armure Blender du Roi ; Signature.

---

## [v0.7.1] — 2026-11-08 — « Codex »

### Description générale
Ramener une relique intacte paie enfin : au Refuge, on la stabilise dans le Codex, et elle devient
une capacité permanente, emportée dans chaque Éclat sans risque de la perdre.

### Nouvelles fonctionnalités
- **Stabiliser** (coffre du Refuge) : relique intacte (3/3) + 60 Grains + 1 Acier ancien → la
  capacité entre au Codex (niveau 1, puis 2 et 3 en stabilisant de nouveau la même relique).
- **Équiper** 2 capacités du Codex (boutons Équiper / Retirer).
- **Dans l'Éclat** : chaque capacité équipée a 2 utilisations par vie (3 dès le niveau 2) ;
  touches **V** et **B** (R1 / Select à la manette) ou toucher les pastilles au-dessus de
  l'inventaire ; rechargées à chaque réapparition.
- Fenêtre du coffre refaite : liste défilante, sections Codex et Coffre, boutons, messages.

### Modifications
- **Profil en version 2** : champ `equipped` (migration v1 → v2 testée, rien n'est perdu).
- Règles du Codex en module pur testé (`Shared/Loot/Codex`).
- Remotes `StabilizeRelic`, `EquipCodex`, `UseCodex` (limités) ; l'instantané du profil contient
  les GUID du coffre et les capacités équipées.
- Test dans Studio : attribut `QA_SeedCodex` (remplit le coffre au Refuge, équipe dans l'Éclat).

### Corrections de bugs
- —

### Vérifications (Studio)
- Tests Lune : 6 nouveaux (stabiliser, refus sans rien payer, niveau maximal, équiper 2 au plus,
  utilisations par niveau, migration du profil v1 → v2) ; 106 au total.
- Refuge : coffre rempli (Stase intacte, Onde de choc abîmée, 2 Aciers anciens, 150 Grains) ;
  Stase stabilisée (90 Grains et 1 Acier restants, relique retirée, Codex niveau 1) puis équipée ;
  Onde de choc non stabilisée : équipement refusé avec message (capture de la fenêtre).
- Éclat : pastilles « [V] Stase · 3 » et « [B] Onde de choc · 2 » ; V crée la bulle et retire une
  utilisation, bloqué à 0 ; utilisations rendues à la réapparition.
- Corrigé pendant le test : utilisations non rendues à la réapparition (personnage annoncé avant
  d'être dans le monde, même piège qu'en v0.5.0).

### Problèmes connus
- Variantes de niveau 3 (écho, mur, saut) pas encore faites : le niveau 3 donne 3 utilisations.
- Touches V / B et boutons manette non essayés avec de vraies pressions.
- Revente des reliques abîmées : plus tard.

### Fichiers
- **Ajoutés** : `src/shared/Loot/Codex.luau`, `src/server/Refuge/Systems/CodexService.luau`,
  `tests/specs/Codex.spec.luau`
- **Modifiés** : `src/server/Core/Lib/ProfileSchema.luau`,
  `src/server/Core/Systems/ProfileReplication.luau`, `src/server/Eclat/Systems/RelicService.luau`,
  `src/client/Refuge/Controllers/VaultUi.luau`, `src/client/Eclat/Controllers/LootHud.luau`,
  `src/shared/{Types,Config}.luau`, `src/shared/Net/Definitions.luau`,
  `tests/{run.luau,specs/ProfileSchema.spec.luau}`, `CHANGELOG.md`, `docs/ROADMAP.md`,
  `docs/GDD/04-progression.md`
- **Supprimés** : —

### Prochaines étapes
- Variantes de niveau 3 ; Signature et boussole ; Gardien du Donjon.

---

## [v0.7.0] — 2026-11-08 — « Reliques »

### Description générale
La mécanique signature arrive : « utiliser ou ramener ». Des autels portent des reliques à trois
charges ; chaque utilisation donne un pouvoir immédiat mais abîme la relique, alors qu'une relique
ramenée intacte pourra entrer au Codex.

### Nouvelles fonctionnalités
- **Autels** : 1 à 3 par Éclat (sommet des tours de guet, crypte, cours, villages ; tirés de la
  graine), avec une relique violette qui flotte et éclaire ; invite « Prendre la relique ».
- **Pas de Faille** : bond de 15 studs (arrêté par les murs), intouchable pendant le bond (les
  tirs le traversent).
- **Stase** : bulle de 2 s devant soi qui ralentit fortement ennemis, joueurs et tirs.
- **Onde de choc** : repousse et étourdit tout ce qui est à moins de 10 studs (15 dégâts, règles
  PvP respectées).
- **3 charges** par relique (touche **T**, **Y** à la manette, ou toucher la relique dans la
  barre) ; message des charges restantes ; à 0, la relique se brise.
- **Au coffre** : chaque relique extraite garde son identifiant et ses charges ; le coffre du
  Refuge indique « intacte — à stabiliser » ou « abîmée ».

### Modifications
- Inventaire : objets uniques (jamais empilés) et `useCharge` ; tests ajoutés.
- AbilityService expose ses effets (téléportation surveillée, bulle de stase, ralentissement,
  effets visuels) ; HealthService ignore les dégâts pendant un bond de Pas de Faille.
- LootService : conteneur « Autel » et `spawnContainer` ; remote `UseRelic` (limité).

### Corrections de bugs
- —

### Vérifications (Studio)
- 2 autels ; relique Onde de choc prise (3 charges), autel vidé, orbe retirée.
- Onde de choc près d'un Échoué : 120 → 105 PV, étourdi ; Stase : bulle créée ; Pas de Faille :
  bond de 15,1 studs, intouchable ; une charge retirée à chaque usage (3 → 2).
- Extraction avec Stase (3/3) et Onde de choc (1/3) : deux enregistrements au coffre.
- 100 tests Lune.

### Problèmes connus
- Stabilisation au Codex et capacités équipables : v0.7.1. Revente des reliques abîmées : plus tard.
- Signature (repérage des porteurs de reliques) : reportée (boussole à faire).
- Touches T / Y non essayées avec de vraies pressions (validé par le remote).
- Autels et reliques en blocs provisoires.

### Fichiers
- **Ajoutés** : `src/server/Eclat/Systems/RelicService.luau`
- **Modifiés** : `src/server/Core/Systems/{AbilityService,HealthService}.luau`,
  `src/server/Eclat/Systems/{LootService,ExtractionService}.luau`,
  `src/client/Eclat/Controllers/LootHud.luau`, `src/client/Refuge/Controllers/VaultUi.luau`,
  `src/shared/Loot/{ItemDefs,RunInventory}.luau`, `src/shared/Net/Definitions.luau`,
  `tests/specs/Loot.spec.luau`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/{ROADMAP,DECISIONS}.md`, `docs/GDD/02-gameplay.md`
- **Supprimés** : —

### Prochaines étapes
- v0.7.1 : Codex (stabiliser une relique intacte au Refuge contre Grains et matériau d'époque),
  2 capacités équipables emportées en partie.

---

## [v0.6.3] — 2026-11-08 — « Bandages »

### Description générale
Les Bandages trouvés dans l'Éclat servent enfin : on se soigne en quelques secondes, à condition
de ne pas se faire toucher pendant ce temps.

### Nouvelles fonctionnalités
- **Bandage** : +30 santé après 2,5 s ; touche **H** (clavier), **croix bas** (manette), ou
  toucher le bandage dans la barre d'inventaire (mobile). Jauge verte pendant le soin.
- Interrompu par le moindre dégât (le bandage est gardé) ; refusé si la santé est pleine, si l'on
  est à terre ou mort, ou si un soin est déjà en cours.

### Modifications
- Remote `UseConsumable` (vers le serveur, limité) ; objets : champs `heal` et `useTime`.
- Cases de l'inventaire touchables (consommables).
- Test dans Studio : attribut `QA_GiveItem` = « id:quantité » (donne un objet au premier joueur).

### Corrections de bugs
- —

### Vérifications (Studio)
- Santé 50, 2 bandages : soin → 80, 1 bandage restant, jauge affichée pendant le soin.
- Soin commencé au contact d'un homme d'armes : « Soin interrompu », bandage gardé.
- 99 tests Lune.

### Problèmes connus
- Touches H et croix bas non essayées avec de vraies pressions (validé par le remote).

### Fichiers
- **Modifiés** : `src/server/Eclat/Systems/LootService.luau`,
  `src/client/Eclat/Controllers/LootHud.luau`, `src/shared/Loot/ItemDefs.luau`,
  `src/shared/Net/Definitions.luau`, `src/shared/Config.luau`, `CHANGELOG.md`
- **Ajoutés / Supprimés** : —

### Prochaines étapes
- v0.7.0 : reliques (utiliser ou ramener), autels.

---

## [v0.6.2] — 2026-11-08 — « Kit de forteresse »

### Description générale
Les premiers modules de décor de la forteresse sont modélisés dans Blender (murs, créneaux,
piliers, linteaux, caisses, coffres, sacs) et le jeu sait les utiliser à la place des blocs
provisoires dès qu'ils sont importés dans Studio.

### Nouvelles fonctionnalités
- **Kit de forteresse** (`assets/blender/fortress/build_kit.py`, 7 modules, 88 à 2 092
  triangles) : mur à pierres de taille en saillie, socle et chaperon ; créneau ; pilier d'angle à
  assises et toit en pyramide ; linteau de porte à clé de voûte et consoles ; caisse à planches,
  croisillon et ferrures ; coffre bombé à bandes de laiton et serrure ; sac de toile lié.
- **Pose automatique** (`Server/Place/Lib/Kit`) : murs découpés en modules d'environ 8 studs
  (étirés juste ce qu'il faut), créneaux, linteaux et piliers ; caisses, coffres, sacs et butins
  en modèles (la pièce de fouille devient invisible). Couleur et matériau Roblox d'après le nom
  de la pièce (Pierre, PierreSombre, Toit, Bois, Fer, Laiton, Toile, Cuir).
- Repli automatique sur la greybox tant que le kit n'est pas dans `ServerStorage > FortressKit`.

### Modifications
- `docs/ASSETS.md` : tableau du kit et procédure d'import.

### Corrections de bugs
- —

### Vérifications
- Blender : rendus de contrôle des 7 modules (pilier et linteau repris deux fois : pierres
  d'angle détachées, voussoirs désordonnés).
- Studio, avec un kit de test aux dimensions des modules : 147 modules de mur, 113 créneaux,
  42 linteaux, 20 piliers, 25 caisses et coffres posés ; hauteurs exactes ; vue d'ensemble
  (capture) ; zone de fouille invisible sur les caisses.
- 99 tests Lune.

### Problèmes connus
- **Le kit n'est pas encore importé** (import FBX par l'utilisateur) : le jeu reste en greybox
  jusque-là. Le rendu réel (proportions, collisions des MeshParts) est à vérifier après l'import.
- Pas encore de modules pour les maisons, la tour, le donjon, les rampes et escaliers.

### Fichiers
- **Ajoutés** : `assets/blender/fortress/{build_kit.py,fortress_kit.blend,Kit_*.fbx}`,
  `src/server/Eclat/Lib/Kit.luau`
- **Modifiés** : `src/server/Eclat/Lib/TileKit.luau`, `src/server/Eclat/Systems/LootService.luau`,
  `src/shared/Config.luau`, `CHANGELOG.md`, `docs/{ASSETS,ROADMAP}.md`
- **Supprimés** : —

### Prochaines étapes
- Importer le kit (utilisateur), vérifier en jeu ; deuxième série de modules (maisons, tour,
  donjon, escaliers).

---

## [v0.6.1] — 2026-11-08 — « Refuge »

### Description générale
Le Refuge accueille le butin rapporté : un coffre affiche ce que l'on possède, et un portail mène
vers l'Éclat. Le voyage entre les places est prêt côté code, et s'activera dès que les places
seront publiées.

### Nouvelles fonctionnalités
- **Coffre du Refuge** (à l'est de l'apparition) : invite « Ouvrir », fenêtre avec les Grains, le
  contenu du coffre et les statistiques (extractions, morts). Lecture seule.
- **Portail vers l'Éclat** (au sud) : arche lumineuse, invite « Partir ».
- **Voyages** (`Server/Systems/Travel`) : Refuge → Éclat par le portail, Éclat → Refuge 4 s
  après une extraction (le temps de lire le bilan), avec réessais. Le profil suit grâce au verrou
  de session.

### Modifications
- L'instantané du profil envoyé au joueur contient le contenu de son coffre et ses statistiques.
- `Config.PLACE_IDS` (identifiants des places, à remplir après publication) ; remote `Notice`.

### Corrections de bugs
- —

### Vérifications (Studio)
- Refuge : coffre ouvert par son invite, fenêtre affichée avec Grains, contenu et statistiques ;
  portail : message de repli reçu (places non publiées).
- 99 tests Lune ; constructions Refuge et Éclat.

### Problèmes connus
- **Téléportations non testées** : impossibles dans Studio et tant que `Config.PLACE_IDS` vaut 0.
  À vérifier après la première publication (Refuge et Éclat dans la même expérience).
- Dans Studio, les données sont en mémoire : le coffre est vide à chaque nouveau test.
- Coffre et portail en blocs provisoires.

### Fichiers
- **Ajoutés** : `src/server/Core/Systems/Travel.luau`, `src/server/Refuge/Systems/Hall.luau`,
  `src/client/Refuge/Controllers/VaultUi.luau`
- **Modifiés** : `src/server/Core/Systems/ProfileReplication.luau`,
  `src/server/Eclat/Systems/ExtractionService.luau`, `src/shared/{Config,Types}.luau`,
  `src/shared/Net/Definitions.luau`, `CHANGELOG.md`, `docs/ROADMAP.md`
- **Supprimés** : —

### Prochaines étapes
- Publier les deux places (décision et action de l'utilisateur), renseigner `Config.PLACE_IDS`,
  tester le voyage.
- v0.5.1 : kit de forteresse dans Blender.

---

## [v0.6.0] — 2026-11-07 — « Extraction »

### Description générale
La boucle d'extraction existe : on fouille l'Éclat, on remplit son inventaire de partie, et il
faut rejoindre un point d'extraction et y tenir 8 s sans être touché pour que le butin soit
versé au coffre du profil. Mourir laisse tout dans un sac, sur place.

### Nouvelles fonctionnalités
- **Inventaire de partie** : 12 emplacements, piles par type (`Shared/Loot/RunInventory`, testé),
  barre en bas de l'écran (couleur selon la rareté), messages « +6 Bois ».
- **Objets** (`Shared/Loot/ItemDefs`) : Grains, Fer, Bois, Cuir, Acier ancien (rare), Pierre de
  Faille (épique), Bandage.
- **Caisses et coffres** posés selon le type de tuile (coffres en haut des tours, sur le toit du
  donjon, dans la crypte) ; fouille en maintenant E (ou le bouton de l'invite) ; contenu tiré par
  le serveur (`Shared/Loot/LootTables`, testé) ; ce qui ne rentre pas reste dedans.
- **Butin des Échoués** : environ une fois sur deux, un petit butin à ramasser.
- **Sac à la mort** : tout ce que l'on portait reste dans « Sac de … », que n'importe qui peut
  fouiller, jusqu'à l'effondrement de la tuile. Rien n'est laissé si l'on tombe dans le Vide.
- **Points d'extraction** (`Shared/Eclat/ExtractionPlan`, testé) : 2 ou 3 points ouverts 90 s à
  des moments tirés de la graine, toujours sur une tuile qui tient pendant leur fenêtre, plus la
  **Faille finale** sur le toit du Donjon de 12 à 16 min. Colonne de lumière, distance et compte à
  rebours (annoncé 60 s avant) ; jauge de 8 s remise à zéro au moindre dégât.
- **Bilan d'extraction** : objets rapportés, Grains (et total), nombre d'extractions ; bouton
  « Repartir ».
- Statistiques du profil : extractions et morts comptées.
- `tools/ouvrir-eclat.ps1` : construit la place Éclat et l'ouvre dans Studio en un clic.

### Modifications
- Remotes ajoutés : `InventoryState`, `LootEvent`, `ExtractionResult` (vers le client),
  `RequestRedeploy` (vers le serveur, limité).
- `EclatService.schedule()` ; une nouvelle partie relance les joueurs extraits.

### Corrections de bugs
- Invites de fouille invisibles quand elles étaient au ras d'une caisse : posées au-dessus.
- « Repartir » refusé : détruire le personnage ne vidait pas `Player.Character`.

### Vérifications (Studio)
- Tests Lune : 9 nouveaux (piles, 12 emplacements, objets et quantités invalides refusés, reste
  dans le conteneur, vidage, tirages valides, taux de butin des Échoués, plan d'extraction sur
  200 graines, remise à zéro de la jauge) ; 99 au total.
- Partie : 20 caisses, 5 coffres, 3 points + la Faille. Caisse fouillée (6 Bois, caisse vidée,
  barre à jour) ; coffre (33 Grains, 1 Pierre de Faille).
- Extraction accélérée : jauge qui monte, bilan affiché (capture), Grains et objets versés au
  profil, personnage retiré ; « Repartir » : retour sur le Bord, santé 100.
- Mort en portant du butin : à terre puis mort à 20 s, « Sac de … » posé ; sac fouillé après
  réapparition : tout récupéré, sac retiré.
- 8 Échoués tués : 4 butins au sol.

### Problèmes connus
- Pas encore de téléportation vers le Refuge après l'extraction (v0.6.1), ni de coffre
  consultable au Refuge : le coffre se remplit, mais ne s'affiche pas encore.
- Caisses, coffres et sacs en blocs provisoires (modèles Blender à venir).
- Les Bandages ne s'utilisent pas encore.
- L'envoi de touches clavier vers une seconde fenêtre de Studio n'a pas marché pendant les tests :
  la fouille a été validée par l'API de l'invite, pas par une vraie pression de E.

### Fichiers
- **Ajoutés** : `src/shared/Loot/{ItemDefs,RunInventory,LootTables}.luau`,
  `src/shared/Eclat/ExtractionPlan.luau`,
  `src/server/Eclat/Systems/{LootService,ExtractionService}.luau`,
  `src/client/Eclat/Controllers/LootHud.luau`, `tests/specs/Loot.spec.luau`,
  `tools/ouvrir-eclat.ps1`, `docs/OMNIROUTE.md`
- **Modifiés** : `src/server/Eclat/Systems/EclatService.luau`, `src/shared/Net/Definitions.luau`,
  `tests/run.luau`, `src/shared/Config.luau`, `CHANGELOG.md`, `docs/{ROADMAP,DECISIONS}.md`,
  `docs/GDD/{02-gameplay,05-equipement-economie}.md`
- **Supprimés** : —

### Prochaines étapes
- v0.6.1 : téléportation Éclat ↔ Refuge et coffre au Refuge.
- v0.5.1 : kit de forteresse dans Blender (tuiles, caisses, coffres).

---

## [v0.5.0] — 2026-11-07 — « Éclats »

### Description générale
Premier vrai Éclat : la carte de la forteresse est générée à partir d'une graine (grille de
5 × 5 tuiles), puis s'effondre côté par côté pendant la partie, jusqu'à la chute finale à 16 min.
Les tuiles sont encore en blocs provisoires (greybox) : les modules de décor Blender suivront.

### Nouvelles fonctionnalités
- **Génération procédurale** (`Shared/Eclat/EclatLayout`, testée) : Donjon au centre, quatre Bords
  d'Éclat d'apparition (un par côté), Remparts / Tours de guet aux coins, Cours d'armes, Villages,
  Ponts-levis, Crypte. Chaque bord partagé offre toujours au moins deux passages (sans mur, mur à
  deux portes, ou porte + chemin de ronde à deux rampes) ; le Donjon est toujours muré.
- **8 types de tuiles** construits en greybox : donjon à toit praticable et tourelles, cour avec
  couverts, remparts en L, tour de guet à rampes en spirale (24 studs), village (maisons, puits,
  étal), douve avec pont-levis et planche étroite, mausolée creux de la Crypte, bord de roche.
  Chaque tuile est un îlot de roche suspendu dans le Vide, avec des fragments figés qui flottent.
- **Calendrier de partie** (`Shared/Eclat/CollapseSchedule`, testé) : exploration (0–5 min),
  effondrement d'un côté de la couronne extérieure toutes les 2 min (5–11 min), Faille finale
  (12–16 min), effondrement total à 16 min ; l'ordre des côtés dépend de la graine.
- **Effondrement** : 30 s avant, fissures orange qui pulsent, poussière, grondement qui monte,
  alerte « LE CÔTÉ … VA S'EFFONDRER » et bord d'écran orange si l'on est dessus ; puis la tuile se
  désagrège pièce par pièce et tombe dans le Vide (secousse et grondement sourd).
- **Mort dans le Vide** : tomber sous la carte tue (joueurs et Échoués) ; à 16 min, tous ceux qui
  restent meurent, puis une nouvelle partie (nouvelle graine) commence 12 s plus tard.
- **Chrono** en haut de l'écran : phase et prochaine chute (« Chute du côté est dans 1:23 »).
- **Apparition par escouade** sur les Bords d'Éclat, face au centre ; réapparition sur la tuile
  debout la plus proche si la sienne est tombée.
- Échoués posés sur les tuiles selon leur type (arbalétriers sur les remparts, le toit du donjon,
  le sommet des tours), aucun à côté d'une tuile d'apparition.
- Test rapide dans Studio : attribut `EclatRestart` = « graine:échelle » (ex. « 42:0.1 »).

### Modifications
- `HealthService.killNow` (mort sans passer « à terre ») ; `EnemyService.models`.
- Sons : grondement d'effondrement (ProSoundEffects) et impact sourd (APM Music).

### Corrections de bugs
- **Joueur sans santé après une réapparition dans l'Éclat** : le personnage est annoncé avant
  d'être placé dans le monde, et HealthService l'ignorait (il devenait invulnérable). Il attend
  maintenant que le personnage soit en place.
- Téléportation vers la tuile d'apparition prise pour une triche par MovementGuard : délai de
  grâce accordé avant de déplacer le joueur.

### Vérifications (Studio)
- Tests Lune : 8 nouveaux (déterminisme de la graine, Donjon et apparitions, 8 types présents,
  deux passages par bord vus des deux côtés, conversions monde ↔ tuile, 4 vagues de 4 tuiles,
  phases et alerte 30 s, durées réduites) ; 90 au total.
- Place Éclat ouverte dans Studio : 25 tuiles, 8 types, ≈ 1 000 pièces ; vue du ciel (capture).
- Partie accélérée (graine 42, échelle 0,1) : 4 tuiles en alerte à 28 s avec fissures et alerte
  « LE CÔTÉ EST VA S'EFFONDRER » (capture), côté est tombé à 30 s (capture), chrono juste.
- Mort dans le Vide : tuile du joueur tombée à 66 s, mort à 69 s, réapparition (santé 100) sur la
  tuile debout la plus proche.
- Fin de partie : tout le monde meurt à 16 min (96 s accélérées), nouvelle graine et nouvelle
  partie, joueur replacé sur son Bord d'apparition.
- Réapparitions répétées : toujours sur le Bord, santé intacte (aucun Échoué à portée).
- Le `require` relatif (`./EclatLayout`) marche dans Roblox comme dans Lune.

### Problèmes connus
- Tuiles en greybox (blocs) : les vrais modules de décor Blender viennent en v0.5.1.
- La Faille finale et le Gardien ne sont pas encore là (seulement un repère sur le donjon).
- Pas encore d'inventaire, de butin ni d'extraction (v0.6.0) : mourir ne fait rien perdre.
- Le ressenti des distances, des couverts et de l'escalade est à juger manette / clavier en main.
- Sons choisis sans écoute.

### Fichiers
- **Ajoutés** : `src/shared/Eclat/{EclatLayout,CollapseSchedule}.luau`,
  `src/server/Eclat/Lib/TileKit.luau`, `src/server/Eclat/Systems/EclatService.luau`,
  `src/client/Eclat/Controllers/EclatHud.luau`, `tests/specs/Eclat.spec.luau`
- **Modifiés** : `src/server/Eclat/Systems/EnemySpawns.luau`,
  `src/server/Core/Systems/{HealthService,EnemyService}.luau`,
  `src/client/Core/Combat/CombatSounds.luau`, `tests/run.luau`, `src/shared/Config.luau`,
  `CHANGELOG.md`, `docs/{ROADMAP,DECISIONS}.md`, `docs/GDD/{02-gameplay,06-environnements}.md`
- **Supprimés** : —

### Prochaines étapes
- v0.5.1 : kit de forteresse modélisé dans Blender (murs, portes, escaliers, toits) à la place de
  la greybox.
- v0.6.0 : inventaire, butin, extraction.

---

## [v0.4.14] — 2026-11-07 — « Fracas »

### Description générale
Le combat a maintenant un vrai paysage sonore : chaque arme a son tir, son mécanisme, son
rechargement et son dégainage, et chaque événement (touche, tête, élimination, dégâts, mort,
élan) a son son.

### Nouvelles fonctionnalités
- **Tirs propres à chaque arme** : pistolet, fusil à répétition (avec coup de levier après le
  tir), Fusil du Zénith (détonation lourde puis culasse tirée et repoussée), arbalète (départ du
  carreau).
- **Dégainer / ranger** : son de dégainage propre à chaque arme (armement des armes à feu,
  mécanisme en bois de l'arbalète, lame tirée du fourreau, épée longue) ; petit bruit en rangeant.
- **Rechargements** propres à chaque arme ; le son s'arrête si l'on change d'arme en cours.
- **Impacts** : balle dans le décor, carreau d'arbalète (pour soi et pour les tirs des autres).
- **Balle qui frôle** : sifflement quand le tir d'un autre joueur passe près de soi.
- **Retours** : marqueur de touche, « ding » de tir dans la tête, note d'élimination ; coup sourd
  quand on est touché.
- **Mort** : chute du corps (entendue par tous) et note sombre pour sa propre mort.
- **Mobilité** : souffle d'élan, son du saut mural.

### Modifications
- `CombatSounds` : coupure en fondu des sons trop longs (`maxTime`), volume réglable par appel,
  arrêt d'un son (`stop`).
- `WeaponDefs` : champs `drawSound`, `reloadSound`, `impactSound`, `cycleSounds`.
- Le Zénith et le fusil n'utilisent plus le son du pistolet ralenti.

### Corrections de bugs
- —

### Vérifications (Studio)
- Les 28 sons candidats se chargent (`ContentProvider` : Success, durées relevées).
- Séquence complète en jeu, sons enregistrés au moment où ils jouent : dégainage, tir, impact,
  mécanisme et rechargement de chaque arme à feu ; rangement ; dégainage et coups des deux lames ;
  élimination du mannequin au Zénith (touche, élimination, bris, chute du corps) ; dégâts reçus
  jusqu'à la mort (coups sourds, chute, note de mort) ; élan sur une vraie pression de F.
- Pas d'erreur de nos scripts dans la console.

### Problèmes connus
- **Sons choisis sans écoute** : à juger à l'oreille (volumes, choix). Chaque son se remplace en
  une ligne dans `CombatSounds.luau`.
- Non vérifiés en jeu : « ding » de tir dans la tête (le tir de test a touché le corps), balle
  qui frôle (il faut un second joueur), saut mural.

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `src/client/Core/Combat/CombatSounds.luau`, `src/shared/Combat/WeaponDefs.luau`,
  `src/client/Core/Controllers/{CombatController,GameFeel}.luau`, `src/shared/Config.luau`,
  `CHANGELOG.md`, `docs/{ASSETS,DECISIONS}.md`
- **Supprimés** : —

### Prochaines étapes
- Écoute par l'utilisateur ; remplacer les sons qui ne conviennent pas.
- Sons des capacités et des Échoués (voix, pas), ambiance de la forteresse.

---

## [v0.4.13] — 2026-11-07 — « Zénith — textures »

### Description générale
Les deux textures Blender du Fusil du Zénith (cercle runique et rayon) sont importées et
branchées : le Rayon du Zénith et la lunette ont enfin leur vrai rendu.

### Nouvelles fonctionnalités
- —

### Modifications
- Cercles runiques du Rayon du Zénith, onde d'impact et réticule de la lunette : vraie texture
  `CercleRunique` (au lieu de la texture de secours).
- Rayon descendant du ciel : vraie texture `Rayon`.

### Corrections de bugs
- —

### Vérifications (Studio)
- Les deux images se chargent (`ContentProvider` : Success).
- Rayon du Zénith lancé sur le mannequin : 5 cercles runiques et rayon visibles (capture).
- Lunette (clic droit maintenu, vraie souris) : champ de vision 22°, réticule runique doré (capture).

### Problèmes connus
- Son de tir du sniper provisoire (son du pistolet, plus grave).
- Les bêtes n'ont ni squelette ni animations : ce sont des modèles de test.

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `src/client/Core/Combat/VfxTextures.luau`, `src/shared/Config.luau`,
  `CHANGELOG.md`, `docs/ASSETS.md`
- **Supprimés** : —

### Prochaines étapes
- Son de tir du sniper ; selon les retours, squelette et animations des bêtes.

---

## [v0.4.12] — 2026-11-07 — « Zénith »

### Description générale
Une arme de prestige inspirée des références de l'utilisateur, le Fusil du Zénith (sniper), avec
une vraie lunette et une capacité spectaculaire, et trois bêtes de test modélisées dans Blender.

### Nouvelles fonctionnalités
- **Fusil du Zénith** (6e présentoir de l'armurerie) : modèle Blender de 2 268 triangles (indigo,
  filigrane de laiton, ivoire, noyau serti, lentille-cadran d'horloge, rouage qui tourne, cristal
  de Temps). 82 dégâts, portée énorme, 4 balles ; très imprécis sans viser.
- **Lunette** : en visée, zoom à 22°, souris plus fine, voile sombre et réticule doré ; son
  propre personnage disparaît (pour soi) pour dégager la vue.
- **Concentration** (passif) : immobile depuis 0,8 s, un tir dans la tête fait environ ×2.
- **Rayon du Zénith** (capacité) : on vise un point ; des cercles runiques dorés s'empilent et
  tournent au-dessus pendant 1,2 s (visibles par tous) et un rayon descend du ciel ; puis éclair,
  gerbe de pointes et onde au sol (70 dégâts au centre, 35 au bord, 7 studs).
- **Bestiaire de test** au Refuge : Loup de Cristal, Scarabée-Horloge, Raie du Temps (modèles
  Blender), sur des socles nommés ; respiration et vol simulés, pas d'IA.
- Textures Blender du cercle runique et du rayon (à importer).
- Champ de vision élargi pendant l'élan et la course sur les murs.

### Modifications
- Les modèles d'armes peuvent avoir un **rouage articulé** (pièce « Rouage » → Motor6D animé).
- Le modificateur de dégâts des capacités sait si le tir touche la tête.
- Sensibilité de la souris proportionnelle au zoom.
- Bibliothèque Blender commune (`assets/blender/lib/`) : primitives, export par matériau, aperçus.

### Corrections de bugs
- —

### Vérifications (Studio)
- Fusil du Zénith : 82 dégâts sur le mannequin ; lunette à 23° avec voile, personnage masqué
  (capture) ; rouage articulé présent ; 6 présentoirs.
- Rayon du Zénith : annonce visible (cercles, rayon), impact −55 sur un mannequin un peu décentré.
- Bestiaire : 3 bêtes exposées et animées (capture).

### Problèmes connus
- `CercleRunique.png` et `Rayon.png` ne sont pas encore dans l'inventaire : cercles et rayon
  utilisent une texture de secours (l'effet est bien moins beau tant qu'ils ne sont pas importés).
- Son de tir du sniper provisoire (son du pistolet, plus grave).
- Les bêtes n'ont ni squelette ni animations : ce sont des modèles de test.

### Fichiers
- **Ajoutés** : `src/client/Core/Controllers/ZenithFx.luau`,
  `src/server/Refuge/Systems/Bestiary.luau`, `assets/blender/lib/{fracture_shapes,fracture_preview}.py`,
  `assets/blender/weapons/{build_fusil_zenith.py,Fusil_Zenith.fbx}`,
  `assets/blender/beasts/{build_betes.py,Loup_Cristal.fbx,Scarabee_Horloge.fbx,Raie_Temps.fbx,betes_test.blend}`,
  `assets/blender/vfx/{CercleRunique.png,Rayon.png}`, `assets/blender/centres_v0412.json`
- **Modifiés** : `src/shared/Combat/{WeaponDefs,Ability}.luau`,
  `src/server/Core/Systems/{AbilityService,WeaponService}.luau`, `src/server/Core/Lib/WeaponModels.luau`,
  `src/server/Refuge/Systems/Armory.luau`,
  `src/client/Core/Controllers/{AbilityController,CameraFeel,CombatController,GameFeel,ShoulderCamera}.luau`,
  `src/client/Core/Combat/VfxTextures.luau`, `assets/blender/vfx/generate_sprites.py`,
  `assets/blender/weapons/armes_de_base.blend`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/{ASSETS,DECISIONS}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Importer les deux textures (cercle, rayon) ; son de tir du sniper.
- Selon les retours : animer les bêtes (squelette Blender) et en faire des Échoués / créatures.

---

## [v0.4.11] — 2026-11-07 — « Mobilité »

### Description générale
FRACTURE devient un jeu de mobilité : élan au sol et en l'air, course sur les murs, saut mural.
Et la glissade « disparue » est expliquée.

### Nouvelles fonctionnalités
- **Élan** (F, bouton « Élan », croix ▲) : poussée courte et nette dans la direction du
  mouvement, au sol ou une fois en l'air ; images rémanentes cyan et son.
- **Course sur les murs** : automatique en sautant le long d'un mur en courant ; corps penché vers
  le mur, foulées rapides, poussière et étincelles contre le mur. Armes utilisables pendant la course.
- **Saut mural** : sauter pendant la course pousse loin du mur, vers le haut et vers l'avant ;
  toucher un mur rend l'élan aérien.
- Bouton tactile « Élan ».

### Modifications
- Le serveur tolère l'élan et la course sur les murs (durée, vitesse, montée), au plus une fois
  par recharge qu'il mesure lui-même.
- Les aides de l'interface affichent la touche du clavier du joueur (AZERTY / QWERTY).

### Corrections de bugs
- **Glissade** : elle fonctionne (vérifié avec les vraies touches). Depuis v0.4.9, dans Studio
  seulement, elle se fait avec **C** et non Ctrl (Ctrl + A / Ctrl + D dupliquait le décor dans la
  fenêtre de test). Le jeu publié garde Ctrl.

### Vérifications (Studio, vraies touches)
- Glissade : sprint + C → mode Slide.
- Élan au sol : 24 studs parcourus (≈ 7 en marchant) ; élan aérien après un saut : 29 studs ;
  aucune correction de la garde de mouvement.
- Course sur les murs le long d'un mur de test : 45 images de course, corps penché de 28° vers le
  mur ; saut mural : hauteur atteinte 12,4 studs (≈ 10 pour un saut simple), poussé loin du mur.
- Aucune erreur en console.

### Problèmes connus
- Ressenti à régler en jeu (vitesse et durée de l'élan, durée de la course sur les murs).
- Le Refuge a peu de murs adaptés : la vraie mise en valeur viendra avec les cartes des Éclats.
- Mobile et manette non testés avec de vraies pressions.

### Fichiers
- **Ajoutés** : `src/client/Core/Movement/{Dash,WallRun}.luau`
- **Modifiés** : `src/shared/Movement/MovementConfig.luau`,
  `src/client/Core/Controllers/{MovementController,CharacterAnimation,CombatController,GameFeel,MobileControls,AbilityController}.luau`,
  `src/client/Core/Animation/Poses.luau`, `src/server/Core/Systems/MovementState.luau`,
  `src/shared/Config.luau`, `README.md`, `CHANGELOG.md`, `docs/{DECISIONS,ROADMAP}.md`,
  `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Retours sur le ressenti ; v0.5.0 « Éclats » avec des cartes pensées pour la mobilité.

---

## [v0.4.10] — 2026-11-07 — « Éclat — textures »

### Description générale
Les textures d'effets dessinées dans Blender sont importées et utilisées en jeu.

### Nouvelles fonctionnalités
- Particules avec les textures du jeu : éclats de Temps (bris, matérialisation, ambiance, onde),
  étincelles étirées (impacts, parade), lueur (noyau chargé, capacités), poussière (course,
  glissade, réception).
- Vignettes d'écran (dégâts, santé basse, soin) en vrai dégradé radial.

### Modifications
- `Combat/VfxTextures` : identifiants des 5 images importées.

### Corrections de bugs
- —

### Vérifications (Studio)
- Les 5 images se chargent (`ContentProvider` : succès).
- Capture : bandeau « ÉLIMINÉ », mannequin brisé, vignette radiale en santé basse.

### Problèmes connus
- Intensité des effets à valider en jeu.

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `src/client/Core/Combat/VfxTextures.luau`, `src/shared/Config.luau`,
  `CHANGELOG.md`, `docs/ASSETS.md`
- **Supprimés** : —

### Prochaines étapes
- v0.5.0 « Éclats » : génération procédurale à partir de tuiles.

---

## [v0.4.9] — 2026-11-07 — « Éclat »

### Description générale
Le jeu devient plus vivant à l'œil : réactions aux coups, animations d'armes, effets de santé,
ambiance. Et la « duplication » signalée est expliquée et corrigée.

### Nouvelles fonctionnalités
- **Coups reçus** : flash blanc sur toute cible touchée ; le buste recule (joueurs et Échoués).
- **Éliminations** : bandeau « ÉLIMINÉ » (ou « À TERRE ») pour le tireur ; mannequins et joueurs
  éliminés se brisent en éclats, comme les Échoués.
- **Armes** :
  - **dégainer** : l'arme part de la hanche et monte en position, et se **matérialise** en
    particules cyan (avec un son) ;
  - **rechargement animé** : l'arme bascule vers la poitrine, les mains suivent ; visible par tous ;
  - **noyau chargé** : le cœur cyan de l'arme en main brille et scintille, visible par tous.
- **Santé** : sous 35 %, bords rouges qui battent, image désaturée, battements de cœur ; un soin
  (Retour) donne un flash cyan.
- **Mouvement et ambiance** : bouffées de poussière sous les pieds en courant ; éclats de Temps
  qui flottent dans l'air autour du joueur.
- **Interface** : le compteur de munitions « saute » à chaque tir.
- **Textures d'effets faites dans Blender** (éclat, étincelle, lueur, poussière, vignette), prêtes
  à importer ; textures Roblox intégrées en attendant.

### Modifications
- Les étincelles sont orientées dans le sens de leur trajectoire.
- Les bords rouges des dégâts utilisent la nouvelle vignette en dégradé.

### Corrections de bugs
- **Duplication** (captures de l'utilisateur) : dans Studio, glisser avec Ctrl en se déplaçant
  déclenchait Ctrl + A puis Ctrl + D (tout sélectionner, dupliquer) dans la fenêtre de test :
  personnages, mannequins, armurerie copiés côté client, entourés en bleu (sélection). Dans
  Studio, la glissade passe sur C ; le jeu publié garde Ctrl (D-041). La place enregistrée ne
  contenait aucun doublon.
- Les bords rouges des dégâts étaient dessinés hors de l'écran (invisibles).

### Vérifications (Studio)
- Duplication : copies présentes seulement côté client (×3), une seule côté serveur, 18 objets
  sélectionnés dans Studio ; place enregistrée vérifiée sans doublon.
- Dégainer : 5 émetteurs de matérialisation ; flash du mannequin touché ; bandeau « ÉLIMINÉ » ;
  lueur du noyau chargé ; rechargement publié (2,1 s) ; ambiance présente.
- Santé 25 : saturation −0,55, battements de cœur, bords rouges en dégradé (capture).
- Aucune erreur en console.

### Problèmes connus
- Les 5 textures Blender restent à importer (textures Roblox par défaut en attendant).
- Ressenti à valider (intensité des effets, son de battements choisi sans écoute).

### Fichiers
- **Ajoutés** : `src/client/Core/Controllers/GameFeel.luau`,
  `src/client/Core/Combat/{VfxTextures,ScreenVignette}.luau`,
  `assets/blender/vfx/{generate_sprites.py,Eclat.png,Etincelle.png,Lueur.png,Poussiere.png,Vignette.png}`
- **Modifiés** : `src/client/Core/Controllers/{MovementController,CharacterAnimation,EnemyVisuals,CombatHUD}.luau`,
  `src/client/Core/Combat/{WeaponFx,CombatSounds}.luau`, `src/client/Core/Animation/MovementEffects.luau`,
  `src/server/Core/Systems/WeaponService.luau`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/{ASSETS,DECISIONS}.md`
- **Supprimés** : —

### Prochaines étapes
- Import des textures d'effets, réglages selon les retours.
- v0.5.0 « Éclats » : génération procédurale à partir de tuiles.

---

## [v0.4.8] — 2026-11-07 — « Correctif arbalète »

### Description générale
Correctif signalé en test : « Arbalète, en faisant Q, rien ne se passe ».

### Nouvelles fonctionnalités
- Un message explique pourquoi une capacité est refusée (« Rechargement en cours », « Cible hors
  d'atteinte »).

### Modifications
- **Carreau de stase** : tiré par le noyau, il n'a plus besoin d'un carreau chargé (utilisable
  pendant le rechargement) ; portée de 60 studs ; s'il ne touche rien, la bulle tombe au sol à
  cet endroit.
- Tests : pressions de touches réelles (clavier, clic droit maintenu) envoyées à Studio.

### Corrections de bugs
- Arbalète : Q juste après un tir (arbalète en rechargement) était refusé sans aucun message.
- Arbalète : un carreau de stase qui ne touchait rien (visée vers le ciel ou très loin) créait sa
  bulle à 250 studs, hors de vue : on croyait qu'il ne s'était rien passé.

### Vérifications (Studio, vraies touches)
- Arbalète : tir normal puis Q pendant le rechargement, visée vers le ciel → bulle posée au sol à
  22 studs.
- Toutes les armes avec les vraies touches : pistolet Q (Retour), lame Q (Pas de l'ombre), fusil
  Q bref (salve) et Q maintenu (balle de rebond), épée longue Q (onde) et clic droit maintenu
  (Garde du Temps levée puis baissée au relâchement, noyau restant 61 %).

### Problèmes connus
- Manette et tactile non vérifiés avec de vraies pressions.

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `src/server/Core/Systems/{AbilityService,WeaponService}.luau`,
  `src/shared/Combat/Ability.luau`, `src/client/Core/Controllers/AbilityController.luau`,
  `src/shared/Config.luau`, `CHANGELOG.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Retours de test, puis v0.5.0 « Éclats ».

---

## [v0.4.7] — 2026-11-07 — « Noyaux II »

### Description générale
Les trois autres armes reçoivent leurs capacités : chaque arme du jeu a maintenant au moins une
capacité active et un trait passif.

### Nouvelles fonctionnalités
- **Fusil à répétition**
  - **Salve au levier** (Q bref) : 3 balles en 0,6 s, cadence ignorée, un peu moins précises.
  - **Balle de rebond** (Q maintenu 0,35 s, ou bouton « Capa. » maintenu) : la balle ricoche une
    fois sur un mur et peut toucher quelqu'un caché derrière un angle. Traçante dorée.
  - **Souffle** (passif) : après 1 s immobile, le tir suivant fait +25 % (« SOUFFLE +25 % »).
- **Arbalète lourde — Carreau de stase** : au premier impact, une bulle cyan de 4 studs pendant
  3 s ralentit joueurs et Échoués de 50 % ; un tir qui la traverse perd 50 % de ses dégâts.
- **Épée longue**
  - **Onde de fracture** (Q) : 0,5 s d'annonce (épée levée), puis une onde de 8 studs au sol
    (fissures cyan) : 35 dégâts, ralentit les joueurs touchés, étourdit les Échoués. Parable.
  - **Garde du Temps** (parade maintenue 0,35 s avec un noyau plein) : bloque tout ce qui vient
    de face (coups et tirs), lame levée en travers et contour cyan ; vide le noyau en 3 s ; on ne
    peut pas attaquer et l'on avance au ralenti.
- La jauge indique les deux capacités et comment les déclencher.

### Modifications
- Tirs côté serveur réorganisés (une seule fonction de tir pour les tirs normaux et spéciaux).
- Ralentissement générique (attributs `SlowUntil` / `SlowFactor`) appliqué aux joueurs et aux
  Échoués.
- Outil de test Studio : `aimAt` (point visé imposé).

### Corrections de bugs
- —

### Vérifications (Studio)
- Salve : mannequin de 150 détruit par la salve. Souffle : 60 au lieu de 48 après 1,5 s immobile.
- Balle de rebond : tirée sur un mur de test, elle revient toucher le mannequin caché (−60).
- Carreau de stase : homme d'armes touché (−75), ralenti de 13 à 6,5 studs/s ; bulle disparue
  après 3 s.
- Onde de fracture : annonce visible, homme d'armes 120 → 85 et étourdi.
- Garde du Temps : coup de l'homme d'armes bloqué (santé 100 → 100), garde baissée seule après
  3 s, noyau vidé.
- Aucune erreur en console.

### Problèmes connus
- Ressenti à valider à la main pour les cinq armes (durées, puissance, lisibilité).
- Tests faits contre des Échoués et des mannequins ; pas encore contre un vrai joueur.
- La commande « appui long » (fusil) et la parade maintenue (Garde du Temps) n'ont été vérifiées
  qu'en simulant les requêtes : à essayer au clavier, à la manette et au tactile.

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `src/shared/Combat/{Ability,WeaponDefs}.luau`,
  `src/server/Core/Systems/{AbilityService,WeaponService,HealthService,EnemyService}.luau`,
  `src/client/Core/Controllers/{AbilityController,CombatController,CharacterAnimation,MobileControls,MovementController}.luau`,
  `src/client/Core/Combat/WeaponFx.luau`, `tests/specs/Ability.spec.luau`, `src/shared/Config.luau`,
  `CHANGELOG.md`, `docs/{DECISIONS,ROADMAP}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Retours de test et équilibrage des capacités.
- v0.5.0 « Éclats » : génération procédurale à partir de tuiles (kit médiéval dans Blender).

---

## [v0.4.6] — 2026-11-07 — « Lames »

### Description générale
La mêlée retravaillée : enchaînements, coups qui suivent une vraie trajectoire d'arme, aide à
la visée avec une petite fente, et des impacts qui se sentent.

### Nouvelles fonctionnalités
- **Enchaînement de 3 coups** : taille de droite à gauche, revers, puis **estoc** (×1,3), si les
  coups s'enchaînent en moins de 0,9 s. Le serveur suit l'enchaînement et applique le bonus.
- **Coups animés par la trajectoire de l'arme** : la lame décrit un vrai arc et les mains suivent
  par cinématique inverse ; sur l'épée longue, **les deux mains restent sur la poignée** pendant
  les coups. Le buste accompagne chaque coup. Coup chargé de haut en bas ; pendant la charge,
  l'arme monte au-dessus de l'épaule. Parade : lame levée en travers.
- **Aide à la mêlée** : le coup vise l'ennemi le plus proche du viseur (cône de 55°), le
  personnage se tourne vers lui et **avance d'au plus 2,5 studs** (fente), jamais à travers un mur.
- **Impacts** : traînée blanche et cyan qui suit la lame, étincelles et éclair à l'impact, son
  d'impact (plus lourd pour le coup chargé), micro-arrêt de 0,06 s et secousse de caméra.
- Les autres joueurs voient les mêmes coups (enchaînement transmis) et la même traînée.

### Modifications
- Anciennes poses fixes de coup et de parade supprimées (remplacées par les trajectoires).
- La garde de mouvement tolère la fente pendant 0,5 s après chaque coup.

### Corrections de bugs
- Épée longue : la main gauche lâchait la poignée pendant les coups.
- Coups ratés de peu à la souris ou au tactile (aide à la mêlée).

### Vérifications (Studio)
- À 6,1 studs du mannequin, caméra décalée de 25° : 3 coups qui portent (30, 30, puis 39 pour
  l'estoc), fente jusqu'à 3,6 studs, position conservée (aucune correction anti-triche).
- Épée longue : main gauche à 0,32 stud au plus de sa place sur la poignée pendant les 3 coups.
- Capture : épée longue tenue à deux mains en plein coup, traînée visible.

### Problèmes connus
- Ressenti à valider à la main (vitesse des coups, fente, aide trop forte ou pas assez).
- Sons d'impact choisis sans écoute (Creator Store, gratuits).
- La charge du coup chargé n'est pas visible par les autres joueurs (seulement le coup).
- Studio : un test lancé quand la fenêtre n'a pas le focus ne dessine aucune image (rien à voir
  avec le jeu).

### Fichiers
- **Ajoutés** : `src/client/Core/Animation/MeleeMotion.luau`
- **Modifiés** : `src/client/Core/Controllers/{CombatController,CharacterAnimation}.luau`,
  `src/client/Core/Animation/Poses.luau`, `src/client/Core/Combat/{WeaponFx,CombatSounds}.luau`,
  `src/server/Core/Systems/WeaponService.luau`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/{DECISIONS,ROADMAP}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- v0.4.7 « Noyaux II » : capacités du fusil, de l'arbalète et de l'épée longue.

---

## [v0.4.5] — 2026-11-07 — « Noyaux »

### Description générale
Premières capacités spéciales des armes : chaque arme a un noyau de Temps qui se charge en
combattant. Le pistolet permet de revenir en arrière, la lame courte d'apparaître dans le dos
d'un ennemi. Les trois autres armes suivront après les retours de test.

### Nouvelles fonctionnalités
- **Noyau** : jauge au-dessus des munitions (PC) ou dans le bouton « Capa. » (mobile), remplie
  par les dégâts infligés avec l'arme (100 points). Son et pulsation quand il est plein.
  Touche **Q** (PC), bouton **Capa.** (mobile), **LB** (manette).
- **Retour** (pistolet) : après 0,25 s d'annonce (lueur cyan), retour à la position d'il y a
  2 s, avec la santé d'alors (+35 au maximum, jamais moins). Traînée cyan entre les deux points.
- **Pas de l'ombre** (lame courte) : l'ennemi le plus proche du viseur à moins de 12 studs est
  entouré en violet ; Q → après 0,3 s, réapparition dans son dos, tourné vers lui ; le premier
  coup dans les 1,5 s fait ×1,5. La victime voit « DERRIÈRE TOI ! », entend un son et peut parer.
  Impossible à travers un mur ou contre un joueur au Refuge.
- **Riposte** (lame courte, passif) : après une parade réussie, le coup suivant fait ×2.
- **Recharge sur élimination** (pistolet, passif) : chargeur plein en éliminant ou mettant à
  terre une cible.
- 6 nouveaux tests (Ability) : 81 au total. Outil Studio : `fillAbility`.

### Modifications
- Le noyau se vide à la mort, comme le reste (D-002).
- `HealthService.heal` : seul moyen de rendre de la santé (jamais à terre ni mort).

### Corrections de bugs
- —

### Vérifications (Studio)
- Retour : 34 studs parcourus, retour de 29,8 studs (position 2 s plus tôt) ; santé 55 → 90
  (plafond +35) ; noyau vidé.
- Pas de l'ombre : cible choisie, marquée pendant l'annonce, réapparition exactement 2,6 studs
  dans le dos de l'homme d'armes ; coup suivant 45 au lieu de 30.
- Riposte : deux parades réussies, coups suivants de 60 au lieu de 30.
- Recharge sur élimination : 7 tirs, mannequin brisé, chargeur affiché 12 / 12.
- Sons chargés (pas écoutés), aucune erreur en console.

### Problèmes connus
- Ressenti à valider à la main : durées d'annonce, distance du Retour, 100 points de charge.
- Sons choisis sans écoute (Creator Store, gratuits).
- Pas de l'ombre contre un vrai joueur non testé (avertissement vérifié seulement dans le code).
- Les noyaux se chargent aussi sur les mannequins du Refuge (pratique pour s'entraîner).

### Fichiers
- **Ajoutés** : `src/shared/Combat/Ability.luau`, `src/server/Core/Systems/AbilityService.luau`,
  `src/client/Core/Controllers/AbilityController.luau`, `tests/specs/Ability.spec.luau`
- **Modifiés** : `src/shared/Combat/WeaponDefs.luau`, `src/shared/Net/Definitions.luau`,
  `src/server/Core/Systems/{WeaponService,HealthService,DevTools}.luau`,
  `src/client/Core/Controllers/MobileControls.luau`, `src/client/Core/Combat/{CombatSounds,WeaponFx}.luau`,
  `src/shared/Config.luau`, `tests/run.luau`, `README.md`, `CHANGELOG.md`,
  `docs/{DECISIONS,ROADMAP}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Retours de test, réglages des deux capacités.
- v0.4.6 « Noyaux II » : salve et balle de rebond (fusil), carreau de stase (arbalète), onde
  de fracture et Garde du Temps (épée longue).

---

## [v0.4.4] — 2026-11-07 — « Échoués »

### Description générale
Les premiers ennemis : l'homme d'armes et l'arbalétrier figés, modélisés dans Blender et
dirigés par le serveur, avec des attaques toujours annoncées. Et une nouvelle façon de tenir
les armes : à deux mains, avec un port d'arme « soldat » en sprint.

### Nouvelles fonctionnalités
- **Homme d'armes figé** (120 PV) : poursuit, lève son épée rouillée qui rougeoie 0,6 s
  (contour rouge, son d'avertissement), puis frappe (22). **Parable** : coup annulé et ennemi
  étourdi 0,9 s. On peut aussi esquiver en sortant de sa portée.
- **Arbalétrier figé** (80 PV) : garde ses distances, épaule 1,1 s avec un **trait rouge** vers
  sa cible qui s'épaissit puis clignote, puis tire (28). Se cacher annule le tir ; bouger au bon
  moment le fait rater (il vise où l'on était 0,3 s plus tôt).
- « Sauts » temporels : de temps en temps, un Échoué se fige une fraction de seconde.
- Mort : le corps se brise en éclats cyan (son de verre) ; barres de vie au-dessus des Échoués.
- **Éclat** : 8 Échoués à leur poste (3 groupes) ; un poste est réoccupé 90 s après la mort.
- **Tenue des armes refaite** (cinématique inverse, mesurée sur chaque avatar) :
  - repos : fusil et arbalète à l'épaule canon vers le sol, pistolet à deux mains devant la
    poitrine, lame en garde, épée longue en garde à deux mains ;
  - **sprint : arme en travers de la poitrine, à deux mains** (port d'arme) ;
  - visée ou juste après un tir : arme épaulée vers le viseur, pistolet bras tendus.
  - Les Échoués utilisent le même système.
- Modèles Blender : équipement de l'homme d'armes (13 pièces), de l'arbalétrier (11 pièces),
  épée rouillée (4 pièces), intégrés dans `ServerStorage`.
- 7 nouveaux tests (EnemyBrain) : 75 au total. Outils Studio : `spawnEnemy`, `clearEnemies`.

### Modifications
- Fusil à répétition : **crosse raccourcie** dans Blender (1,55 → 1,0 stud) pour que les bras
  d'un avatar Roblox puissent le tenir. L'ancien modèle est archivé (`ServerStorage > ArchiveModels`).
- Une frappe de mêlée sans joueur attaquant (Échoué, mannequin) ne touche que les joueurs.
- Le décalage arme / main est partagé entre serveur et client (`Combat/WeaponGrip`).
- Poses fixes de tenue d'arme supprimées (remplacées par la cinématique inverse).

### Corrections de bugs
- Armes tenues à bout de bras d'une seule main, pointées vers le ciel (signalé avec captures).
- Quatre armes importées en double dans Studio : supprimées.

### Vérifications (Studio)
- Homme d'armes : repère et poursuit le joueur, annonce 0,58 s avant de frapper, 22 dégâts par
  coup ; parade 0,15 s avant le coup → aucun dégât, ennemi étourdi.
- Arbalétrier : visée avec trait rouge, arbalète épaulée à deux mains.
- Mort : 3 balles de fusil (72 → 24 → 0), bris, corps retiré après 4 s.
- Tenue mesurée : main gauche à la position voulue sur le pistolet ; à 0,15 stud de la cible sur
  l'épée longue ; captures de chaque arme au repos, en sprint et en visée.
- Sons vérifiés au chargement (pas à l'écoute).

### Problèmes connus
- Ressenti des Échoués et de la nouvelle tenue à valider à la main (clavier et tactile).
- Réapparition à 90 s dans l'Éclat non testée en partie réelle (code relu, testé via `spawnEnemy`
  au Refuge).
- Fusil : la main gauche tient le fût juste devant la carcasse (bras Roblox trop courts pour
  plus loin).
- Les Échoués n'attaquent pas encore les autres escouades de façon délibérée, ne grimpent pas.
- Postes des Échoués provisoires (sol de test de l'Éclat).

### Fichiers
- **Ajoutés** : `src/shared/Combat/{EnemyDefs,EnemyBrain,WeaponGrip}.luau`,
  `src/server/Core/Systems/EnemyService.luau`, `src/server/Eclat/Systems/EnemySpawns.luau`,
  `src/client/Core/Controllers/EnemyVisuals.luau`, `src/client/Core/Animation/{ArmIK,WeaponHold}.luau`,
  `tests/specs/EnemyBrain.spec.luau`,
  `assets/blender/enemies/{Homme_Armes_Equipement,Arbaletrier_Equipement,Epee_Rouillee}.fbx`,
  `assets/blender/enemies/echoues.blend`
- **Modifiés** : `src/server/Core/Systems/{WeaponService,DevTools}.luau`,
  `src/server/Core/Lib/WeaponModels.luau`,
  `src/client/Core/Controllers/{CharacterAnimation,CombatController,CombatHUD}.luau`,
  `src/client/Core/Animation/Poses.luau`, `src/client/Core/Combat/{CombatSounds,WeaponFx}.luau`,
  `assets/blender/weapons/{Fusil_Repetition.fbx,armes_de_base.blend}`, `src/shared/Config.luau`,
  `tests/run.luau`, `CHANGELOG.md`, `docs/{ASSETS,DECISIONS,ROADMAP}.md`, `docs/GDD/07-ennemis.md`
- **Supprimés** : —

### Prochaines étapes
- Retours de test sur les Échoués et la tenue des armes, réglages.
- v0.5.0 « Éclats » : génération procédurale à partir de tuiles (kit médiéval dans Blender).

---

## [v0.4.3] — 2026-11-06 — « Arsenal »

### Description générale
Trois nouvelles armes (modélisées dans Blender), la parade, une armurerie au Refuge pour
choisir ses armes, et une interface tactile dédiée.

### Nouvelles fonctionnalités
- **Fusil à répétition** : 48 dégâts, 6 balles, très précis en visée, dégâts pleins jusqu'à
  80 studs (70 % au-delà de 220).
- **Arbalète lourde** : 75 dégâts, un carreau, **traverse une première cible** (70 % des
  dégâts sur la suivante).
- **Épée longue** : 42 dégâts, coup chargé ×2, large cône (100°) et longue portée (8,5 studs),
  tenue à deux mains.
- **Parade** : clic droit / LT / bouton « Parer » avec une arme de mêlée ; un coup de face
  pendant la fenêtre est annulé et l'attaquant est **étourdi** 0,9 s. « PARADE ! » et
  « ÉTOURDI » à l'écran, étincelles cyan, son métallique, visible par tous.
- **Armurerie** du Refuge : 5 présentoirs (armes exposées en rotation), « Équiper » en
  maintenant la touche d'interaction.
- **Interface tactile** dédiée autour du pouce droit (Tirer/Frapper, Viser/Parer, Recharger,
  Arme, Sprint, Glisser, Grappin) ; munitions déplacées au-dessus des boutons sur mobile.
- Modèles Blender des trois armes (FBX + source) ; formes provisoires en attendant l'import.
- Fonction de frappe de mêlée générique côté serveur, prête pour les Échoués (v0.4.4).
- Animations : arme longue tenue à deux mains, épée longue à deux mains (pose trouvée par
  recherche automatique : main gauche à 0,3 stud de la poignée), pose de parade.
- 4 nouveaux tests (Parry) : 68 au total. Outils Studio : `setWeapon`, `dummyAttack`.

### Modifications
- La charge (armes choisies) est publiée en attributs du joueur (`Loadout1`, `Loadout2`).
- Les ennemis peuvent blesser les joueurs même au Refuge (D-034) ; le PvP reste interdit au Refuge.
- Chaque arme a son propre son (hauteur différente pour le fusil).

### Corrections de bugs
- Les présentoirs voisins se déclenchaient à la place du bon (portée d'interaction réduite).

### Vérifications (Studio)
- Fusil : 48 / 48 sur le mannequin. Arbalète : 112,5 (tête) sur le premier mannequin puis le
  carreau continue et achève le second. Épée longue : 38 (santé restante du mannequin).
- Mannequin qui frappe sans parade : 30 dégâts (15 absorbés par l'armure) ; avec parade :
  coup annulé, mannequin étourdi ; parade trop tôt : coup reçu.

### Problèmes connus
- Les trois nouveaux modèles Blender restent à importer dans Studio (formes provisoires en jeu).
- Interface tactile vérifiée à l'écran sur PC, pas sur un vrai téléphone.
- Parade et PvP non testés entre deux vrais joueurs.
- Sons provisoires (arbalète et parade notamment).

### Fichiers
- **Ajoutés** : `src/shared/Combat/Parry.luau`, `src/server/Refuge/Systems/Armory.luau`,
  `src/client/Core/Controllers/MobileControls.luau`, `tests/specs/Parry.spec.luau`,
  `assets/blender/weapons/{Fusil_Repetition,Arbalete_Lourde,Epee_Longue}.fbx`
- **Modifiés** : `src/shared/Combat/WeaponDefs.luau`, `src/shared/Net/Definitions.luau`,
  `src/server/Core/Systems/{WeaponService,HealthService,DevTools}.luau`,
  `src/server/Core/Lib/WeaponModels.luau`, `src/client/Core/Controllers/{CombatController,CombatHUD,CharacterAnimation,MovementController}.luau`,
  `src/client/Core/Animation/Poses.luau`, `src/client/Core/Combat/{CombatSounds,WeaponFx}.luau`,
  `assets/blender/weapons/armes_de_base.blend`, `src/shared/Config.luau`, `tests/run.luau`,
  `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `docs/{ASSETS,DECISIONS,ROADMAP}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Import des trois modèles (puis réglage par Claude).
- v0.4.4 « Échoués » : homme d'armes et arbalétrier figés (modélisés dans Blender), IA serveur.

---

## [v0.4.2] — 2026-11-06 — « Armes en main »

### Description générale
Les modèles Blender du pistolet et de la lame sont importés, réglés et utilisés en jeu à la
place des formes provisoires.

### Nouvelles fonctionnalités
- Pistolet de Fractureur et lame courte (modèles Blender) tenus en main, visibles par tous.
- Matériaux Roblox : métal sombre, laiton, cuir, acier, noyau cyan en Neon.
- Bouche du canon placée au bout du vrai canon (origine des traçantes et de la lueur).

### Modifications
- Garde de la lame : avant-bras à l'horizontale, lame pointée vers l'avant.

### Corrections de bugs
- **Armes tenues à l'envers** depuis v0.4.0 (canon et lame vers le corps) : en v0.4.0, j'avais
  lu à l'envers l'axe avant de l'arme et « corrigé » dans le mauvais sens. Orientation
  re-mesurée sur les deux axes (avant et haut) : corrigé pour les deux armes.
- Modèles importés 100 fois trop grands (l'importeur lit les fichiers Blender en centimètres) :
  remis à l'échelle (pistolet 0,46 × 1,19 × 1,62 studs, lame 2,78 studs, comme dans Blender).

### Problèmes connus
- Les modèles importés vivent dans la place de travail Place1 (`ServerStorage > WeaponModels`) :
  **enregistrer Place1**. Les places construites par Rojo utilisent encore les formes
  provisoires (stratégie de versionnement des maillages à venir).
- Le noyau cyan du pistolet est sur le flanc gauche : moins visible depuis la caméra d'épaule
  droite. À corriger au prochain export Blender (règle ajoutée à `CLAUDE.md`).

### Fichiers
- **Modifiés** : `src/server/Core/Lib/WeaponModels.luau`, `src/client/Core/Animation/Poses.luau`,
  `src/shared/Config.luau`, `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `docs/ASSETS.md`,
  `docs/ROADMAP.md`
- **Ajoutés / supprimés** : —

### Prochaines étapes
- v0.4.3 « Arsenal » : fusil à répétition, arbalète lourde, épée longue (modélisés dans
  Blender), parade, interface mobile dédiée.

---

## [v0.4.1] — 2026-11-06 — « Armes de base »

### Description générale
Correction de la caméra (clic droit) et premiers vrais modèles 3D : le pistolet de Fractureur
et la lame courte, modélisés dans Blender.

### Nouvelles fonctionnalités
- **Caméra de combat maison (PC)** : arme en main, souris verrouillée au centre, ses
  mouvements tournent la vue ; la caméra se rapproche en visée et ne traverse pas les murs.
- **Pistolet de Fractureur (Blender)** : cadre sombre, pièces en laiton, poignée en cuir,
  noyau temporel cyan dans une cage — 1 928 triangles, 4 pièces par matériau.
- **Lame courte (Blender)** : manche en cuir à bagues de laiton, garde et pommeau en laiton,
  lame d'acier à gorge cyan — 1 064 triangles.
- Les modèles importés dans `ServerStorage > WeaponModels` remplacent automatiquement les
  formes provisoires (toutes les pièces sont soudées à la poignée).
- `CLAUDE.md` : règles de travail du projet, dont « tout objet 3D est modélisé dans Blender ».

### Modifications
- Plus aucune modification forcée de la souris hors combat.

### Corrections de bugs
- **La caméra ne tournait plus au clic droit** : le combat forçait le comportement de la
  souris à chaque image, même arme rangée. Corrigé (D-028).

### Problèmes connus
- Les modèles Blender doivent être **importés dans Studio** (Importer 3D) : l'outil Studio
  disponible ne permet pas d'importer un FBX automatiquement. Les formes provisoires restent
  utilisées d'ici là.
- Rotation de la caméra à la souris non testable de mon côté (simulation de souris
  indisponible) : à vérifier à la main.

### Fichiers
- **Ajoutés** : `CLAUDE.md`, `src/client/Core/Controllers/ShoulderCamera.luau`,
  `assets/blender/weapons/{armes_de_base.blend,Pistolet_Fractureur.fbx,Lame_Courte.fbx}`
- **Modifiés** : `src/client/Core/Controllers/CombatController.luau`,
  `src/server/Core/Lib/WeaponModels.luau`, `src/shared/Config.luau`, `CHANGELOG.md`,
  `docs/{ASSETS,DECISIONS,ROADMAP}.md`
- **Supprimés** : —

### Prochaines étapes
- Import des deux modèles dans Studio, puis réglage des matériaux et de la tenue en main.
- v0.4.2 « Arsenal » : fusil, arbalète, épée longue (modélisés dans Blender), parade, interface mobile.

---

## [v0.4.0] — 2026-11-06 — « Combat »

### Description générale
Première version du combat : équipement de base (pistolet de Fractureur, lame courte), visée
par-dessus l'épaule, dégâts calculés par le serveur avec compensation de latence, santé et
armure, mise à terre, mannequins d'entraînement au Refuge.

### Nouvelles fonctionnalités
- **Pistolet** : 24 dégâts, tête ×1,5, 5 tirs/s, 12 balles, rechargement 1,4 s, chute des
  dégâts de 35 à 90 studs (55 % au minimum), dispersion qui grandit en courant, en l'air et en
  enchaînant les tirs, très réduite en visée.
- **Lame courte** : 30 dégâts, attaque chargée (maintenir 0,6 s) ×1,8, cône de 75° sur 6,5 studs.
- **Visée** : caméra par-dessus l'épaule, zoom en visée, réticule dynamique, souris verrouillée
  au centre sur PC, personnage tourné vers la caméra ; recul de caméra.
- **Serveur** : vérification de chaque tir (arme, cadence, munitions, origine, mur), cibles
  remontées dans le temps pour juger le tir sur ce que le tireur voyait.
- **Santé / armure / à terre** : 100 PV + 15 d'armure ; à 0, un joueur tombe à terre (rampe,
  20 s, 30 de « santé à terre ») ; publiée en attributs pour l'interface.
- **Interface** : réticule, marqueur de touche (blanc / orange tête / rouge KO), chiffres de
  dégâts, munitions, barres santé et armure, bords rouges et flèche de direction des dégâts
  reçus, écran « À TERRE », barres de vie des mannequins.
- **Effets** : traçantes, lueur de bouche, impacts teintés selon la surface, traînée de lame.
- **Animations** : pistolet tenu à deux mains et pointé vers la cible, lame en garde, coups
  (balayage ou coup vertical chargé, préparation visible), pose à terre.
- **Armes visibles par tous** (formes provisoires), remplaçables par des modèles Blender.
- **Champ de tir** au Refuge : mannequin proche, lointain et mobile ; brisés à 0, réparés en 3 s.
- 14 nouveaux tests unitaires (Damage, WeaponState, HitMath, PositionHistory) : 64 au total.

### Modifications
- La caméra (CameraFeel) gère aussi le décalage d'épaule, le zoom de visée et le recul.
- Le déplacement est bridé à terre (vitesse 4, plus de saut ni de mouvement spécial).

### Corrections de bugs
- Détecté en test : le canon de l'arme pointait vers l'arrière (orientation des mains du
  nouveau système d'articulations). Corrigé.
- Détecté en test : bras gauche écarté vers l'extérieur en visée. Corrigé (soutien à deux mains).
- Détecté par les tests unitaires : arrondi qui pouvait refuser un tir à la cadence exacte.

### Vérifications
- Mannequin proche : 24 au corps, 36 à la tête. Chute des dégâts : 18,9 à 60 studs, 13,9 à 90.
- Lame : 30 / 30 / 30 / 54 (chargée), mise KO puis réparation à 150 PV en 3 s.
- Compensation de latence : 8 touches sur 10 sur une cible à 12 studs/s avec 200 ms de latence.

### Problèmes connus
- **Non testé à plusieurs joueurs** : PvP et mise à terre (le PvP n'existe que dans la place
  Éclat). Test possible dans Studio : onglet Test → Clients et serveur → 2 joueurs, place Éclat.
- **Trop de boutons tactiles** par défaut sur mobile (déplacement + combat) : une disposition
  mobile dédiée est prévue en v0.4.1.
- Sons provisoires, choisis sans écoute.
- Chez les autres joueurs, le bras du pistolet vise droit devant (l'inclinaison réelle de leur
  visée n'est pas encore transmise).
- Pas encore de réanimation par un coéquipier (arrive avec les escouades).

### Fichiers
- **Ajoutés** : `src/shared/Combat/{CombatConfig,WeaponDefs,Damage,WeaponState,HitMath}.luau`,
  `src/server/Core/Lib/{PositionHistory,WeaponModels}.luau`,
  `src/server/Core/Systems/{CombatTargets,HealthService,WeaponService}.luau`,
  `src/server/Refuge/Systems/TrainingDummies.luau`,
  `src/client/Core/Combat/{CombatSounds,WeaponFx}.luau`,
  `src/client/Core/Controllers/{CombatController,CombatHUD}.luau`, `tests/specs/Combat.spec.luau`
- **Modifiés** : `src/client/Core/Controllers/{CameraFeel,CharacterAnimation,MovementController}.luau`,
  `src/client/Core/Animation/Poses.luau`, `src/shared/Net/Definitions.luau`,
  `src/shared/Config.luau`, `tests/run.luau`, `README.md`, `CHANGELOG.md`,
  `docs/{ARCHITECTURE,DECISIONS,ROADMAP,ASSETS}.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Ton test du combat au champ de tir (à l'ouest du point d'apparition).
- v0.4.1 « Arsenal » : fusil à répétition, arbalète lourde, épée longue, parade, interface
  mobile dédiée.

---

## [v0.3.2] — 2026-11-06 — « Poussière »

### Description générale
Corrections suite à ton test : scintillement du sol et effets de glissade trop discrets.

### Nouvelles fonctionnalités
- **Effets de glissade renforcés**, teintés selon la couleur du sol : nuage de poussière plus
  dense (bouffée au démarrage), petits débris projetés vers l'arrière qui retombent, traînée
  de frottement au sol. Anneau de poussière plus marqué à la réception.
- Outils de test Studio : joystick simulé (`FractureMovementQA:Invoke("move", direction)`) et
  coupure des animations (`QA_NoProceduralAnim`) pour les diagnostics.

### Modifications
- Aucune modification du gameplay.

### Corrections de bugs
- **Scintillement des textures du sol** : la place de test (Place1) contenait son propre
  Baseplate dont la surface était exactement à la même hauteur que le sol du projet
  (z-fighting). Baseplate et point d'apparition en double retirés de Place1. Les places
  construites par Rojo n'étaient pas concernées.

### Vérifications
- Vitesse réelle mesurée en sprint : 22,0 studs/s (attendu 22), 1 image lente sur 90, avec ou
  sans animations : les animations n'ajoutent aucun ralentissement.

### Problèmes connus
- Sons toujours à valider à l'oreille.

### Fichiers
- **Modifiés** : `src/client/Core/Animation/MovementEffects.luau`,
  `src/client/Core/Controllers/{CharacterAnimation,MovementController}.luau`,
  `src/shared/Config.luau`, `CHANGELOG.md`, `README.md`
- **Ajoutés / supprimés** : —

### Prochaines étapes
- v0.4.0 « Combat ».

---

## [v0.3.1] — 2026-11-06 — « Ressenti »

### Description générale
Refonte du ressenti du déplacement après ton test (« lent et de mauvaise qualité ») : les
mécaniques étaient justes en chiffres mais sans animations, avec des changements de vitesse
instantanés et aucun retour de caméra ni son. Tout est repris.

### Nouvelles fonctionnalités
- **Animations** générées par le code, visibles par tous les joueurs : glissade (assis, pieds
  devant), escalade (attraper puis se hisser), grappin (bras pointé vers la cible, corps tiré),
  saut, chute (bras écartés), réception (accroupi selon la hauteur), inclinaison du sprint.
  Compatibles avec les deux systèmes d'articulations Roblox (Motor6D, AnimationConstraint).
- **Caméra** : champ de vision qui s'élargit en sprint (+7), glissade (+11) et grappin (+15),
  inclinaison en glissade, petit choc à la réception.
- **Effets** : poussière en glissade et à la réception ; sons de glissade, de grappin (tir et
  accroche) et de réception, en 3D.
- **Grappin en trois temps** : le crochet vole vers la cible (corde molle qui se tend), la
  traction part de ta vitesse actuelle et accélère, puis ralentit à l'arrivée.
- **Escalade automatique en fin de grappin** si on arrive face à un rebord : permet d'atteindre
  des rebords trop hauts pour une escalade directe.
- **Tolérance des commandes** : glissade et escalade pressées 0,18 s trop tôt sont retenues ;
  saut possible 0,12 s après avoir quitté un rebord.
- Ressort amorti réutilisable (`Shared/Util/Spring`) avec 5 tests : 50 tests au total.
- Point de test Studio côté client (`FractureMovementQA`) pour piloter le vrai contrôleur.

### Modifications
- Vitesse progressive : démarrage à 9 studs/s puis accélération, passage marche ↔ sprint en
  douceur, sortie de glissade sans à-coup (mesuré : ≤ 1 stud/s de variation par image).
- Glissade : ralentissement « ease-out » au lieu de linéaire.
- Escalade : trajectoire courbe lissée, durée selon la hauteur (0,3 à 0,47 s), sortie avec un
  léger élan vers l'avant, plus de changement d'état brutal à la fin.
- Grappin : s'arrête à 3,5 studs de la cible (au lieu de 6), le corps se tourne vers la cible.
- La garde serveur tient compte du temps de vol du crochet.

### Corrections de bugs
- La jauge d'endurance pouvait rester affichée alors qu'elle était pleine.

### Problèmes connus
- **Sons choisis sans écoute** (bibliothèque gratuite Roblox) : à valider à l'oreille, et à
  remplacer si besoin dans `src/client/Core/Animation/SoundConfig.luau`.
- Les animations ont été vérifiées par mesure des angles et par captures de poses fixes ; le
  rendu en mouvement reste à juger par toi.
- La hitbox ne se baisse toujours pas pendant la glissade.

### Fichiers
- **Ajoutés** : `src/shared/Util/Spring.luau`, `src/client/Core/Animation/{JointRig,Poses,PoseAnimator,MovementEffects,SoundConfig}.luau`,
  `src/client/Core/Controllers/{CharacterAnimation,CameraFeel}.luau`,
  `src/server/Core/Systems/MovementState.luau`, `tests/specs/Spring.spec.luau`
- **Modifiés** : `src/client/Core/Controllers/{MovementController,GrappleVisuals,StaminaBar}.luau`,
  `src/client/Core/Movement/{Context,Slide,Mantle,Grapple,Rope}.luau`,
  `src/server/Core/Systems/Grapple.luau`, `src/shared/Movement/MovementConfig.luau`,
  `src/shared/Net/Definitions.luau`, `src/shared/Config.luau`, `tests/run.luau`, `README.md`,
  `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ASSETS.md`,
  `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Ton test à la main ; retouches de poses, de vitesses et de sons selon ton retour.
- v0.4.0 « Combat ».

---

## [v0.3.0] — 2026-11-06 — « Mouvement »

### Description générale
Premier système de jeu : le déplacement des Fractureurs, jouable sur PC, mobile et manette,
avec une garde serveur contre les déplacements impossibles.

### Nouvelles fonctionnalités
- **Sprint** (22 studs/s) avec **jauge d'endurance** : 6 s de sprint, recharge en 4 s après
  0,6 s de pause ; à bout de souffle, resprint possible à 25 %. Jauge affichée à l'écran.
- **Glissade** en courant : 30 → 15 studs/s en 0,8 s (≈ 18 studs), 2,5 fois plus longue en
  descente (≈ 45 studs), coûte 15 % d'endurance, sauter garde l'élan.
- **Escalade de rebord** automatique de 2,5 à 7 studs, en 0,35 s, avec vérification de la
  place disponible.
- **Grappin** : portée 60 studs, 70 studs/s, recharge 8 s ; sauter pendant la traction lâche
  avec une impulsion ; corde visible par tous les joueurs.
- **Contrôles** clavier, boutons tactiles et manette.
- **Garde de mouvement** serveur : échantillonnage toutes les 0,2 s, retour à la dernière
  position valide après 3 anomalies (vitesse, téléportation, vol).
- **Validation serveur du grappin** : type, recharge, portée, ligne de vue.
- **Outils de test Studio** (`DevCommand`, inactifs dans le jeu publié).
- **Parcours de test** dans le Refuge (blocs de 2 / 4 / 6,5 / 9 studs, tour, pente).
- 12 nouveaux tests unitaires (Stamina, MovementValidator) : 45 au total.

### Modifications
- Réglages du personnage fixés par les places : vitesse de marche 14, hauteur de saut 7,2,
  verrouillage de la souris (Maj) désactivé car Maj sert au sprint.
- GDD 03 : sprint en bascule sur mobile et manette (D-018), touche du grappin, valeurs réelles.
- Cartes de test déplacées dans `maps/refuge/Greybox.model.json`.

### Corrections de bugs
- Détecté en test : la jauge d'endurance pouvait rester bloquée à 0,000000000000001 sans
  jamais atteindre 0 (erreur d'arrondi). Corrigé.
- Détecté en test : la force de glissade et de grappin était trop faible face au freinage du
  Humanoid (pic à 4 studs/s au lieu de 30). Force multipliée par 5.
- Détecté en test : Rojo n'appliquait pas la propriété `Position` (sol et point d'apparition
  au mauvais endroit). Toutes les positions passent par `CFrame`.

### Problèmes connus
- **Les contrôles n'ont pas été testés à la main** : la simulation de touches de Studio n'atteint
  pas le jeu. Les mouvements ont été testés en appelant directement les modules ; il reste à
  vérifier le ressenti au clavier, au tactile et à la manette.
- Aucune animation dédiée (glissade, escalade, grappin) ; la hitbox ne se baisse pas pendant
  la glissade.
- Le grappin est donné à tous les joueurs en attendant le système d'équipement.
- Le grappin sur mobile vise le centre de l'écran sans réticule visible.

### Fichiers
- **Ajoutés** : `src/shared/Movement/{MovementConfig,Stamina}.luau`,
  `src/server/Core/Lib/MovementValidator.luau`,
  `src/server/Core/Systems/{MovementGuard,Grapple,DevTools}.luau`,
  `src/client/Core/Movement/{Context,Rope,Slide,Mantle,Grapple}.luau`,
  `src/client/Core/Controllers/{MovementController,GrappleVisuals,StaminaBar}.luau`,
  `maps/refuge/Greybox.model.json`, `tests/specs/{Stamina,MovementValidator}.spec.luau`
- **Modifiés** : `places/refuge.project.json`, `places/eclat.project.json`,
  `src/shared/Net/Definitions.luau`, `src/shared/Config.luau`, `tests/run.luau`, `README.md`,
  `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`,
  `docs/ASSETS.md`, `docs/GDD/03-combat.md`
- **Supprimés** : —

### Prochaines étapes
- Ton test à la main du ressenti (PC, et mobile via l'émulateur de Studio).
- v0.4.0 « Combat » : caméra par-dessus l'épaule, armes de base, dégâts validés par le serveur
  avec historique des positions, santé et armure, premiers Échoués.

---

## [v0.2.0] — 2026-11-06 — « Fondations »

### Description générale
Phase 3 : les fondations techniques sur lesquelles tous les systèmes de jeu reposeront.
Aucun gameplay encore : les places contiennent un sol et un point d'apparition.

### Nouvelles fonctionnalités
- **Deux places** construites à partir du même code : Refuge et Éclat
  (`places/refuge.project.json`, `places/eclat.project.json`), StreamingEnabled activé.
- **Démarrage modulaire** : un seul Script serveur et un seul LocalScript chargent les
  systèmes communs puis ceux de la place, en deux phases (`init`, puis `start`).
- **Couche réseau** : liste unique des remotes, création côté serveur, limite de fréquence
  par joueur et par remote, validateurs d'arguments (`Guard`).
- **Données joueur** : chargement avec verrou de session, réessais avec attente
  exponentielle, sauvegarde automatique toutes les 60 s (décalée par joueur), sauvegarde au
  départ et à l'arrêt du serveur, schéma versionné avec migrations, validation avant écriture,
  expulsion propre en cas d'échec (jamais de profil vide).
- **Instantané du profil** envoyé au joueur (`ProfileSnapshot`) ; contrôleur client en lecture seule.
- **Tests automatiques** : 33 tests unitaires (Lune) ; la CI vérifie formatage, lint, tests
  et construction des deux places.

### Modifications
- Arborescence `src/server` et `src/client` réorganisée en `Core` / `Refuge` / `Eclat`.
- `default.project.json` supprimé au profit de `places/*.project.json`.
- Lune ajouté à la chaîne d'outils.

### Corrections de bugs
- Détecté pendant les tests dans Studio : le stockage en mémoire acceptait silencieusement
  des données non stockables (ex. Vector3). Corrigé par la validation avant écriture.

### Problèmes connus
- La téléportation Refuge ↔ Éclat n'existe pas encore (nécessite la publication des places).
- Le chemin « DataStore réel » n'a pas été testé (accès aux API désactivé dans Studio) ;
  seule la chaîne en mémoire et la logique de verrou l'ont été.
- Si le serveur s'arrête pendant le chargement d'un joueur, son verrou peut rester actif
  jusqu'à 150 s (il expire ensuite tout seul).

### Fichiers
- **Ajoutés** : `places/refuge.project.json`, `places/eclat.project.json`,
  `src/places/*/PlaceKind.luau`, `src/shared/Net/Definitions.luau`,
  `src/shared/Util/Guard.luau`, `src/shared/Util/Signal.luau`,
  `src/server/Core/init.server.luau`, `src/server/Core/Lib/{Net,RateLimiter,Retry,ProfileSchema,SessionLock,ProfileStore,DataConfig}.luau`,
  `src/server/Core/Systems/{PlayerData,ProfileReplication}.luau`,
  `src/client/Core/init.client.luau`, `src/client/Core/Lib/Net.luau`,
  `src/client/Core/Controllers/ProfileController.luau`, `tests/` (run, TestKit, 5 fichiers de tests)
- **Modifiés** : `.github/workflows/ci.yml`, `.gitignore`, `rokit.toml`, `README.md`,
  `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`,
  `src/shared/Config.luau`, `src/shared/Types.luau`
- **Supprimés** : `default.project.json`, `src/server/init.server.luau`,
  `src/client/init.client.luau`

### Prochaines étapes
- v0.3.0 « Mouvement » : contrôleur de déplacement (sprint, glissade, escalade, grappin),
  contrôles tactiles, vérifications serveur de la vitesse.
- En parallèle : première relique dans Blender (« Pas de Faille »).

---

## [v0.1.2] — 2026-11-06 — « Game Design Document »

### Description générale
Phase 2 : rédaction du Game Design Document complet de la vertical slice. Aucun code de jeu.

### Nouvelles fonctionnalités
- GDD en 11 sections dans `docs/GDD/` : univers, gameplay, combat, progression, équipement et
  économie, environnements, ennemis, multijoueur, interface, direction artistique, périmètre
  de la vertical slice.

### Modifications
- Progression permanente confirmée (D-012) ; méthode de travail autonome (D-013) ;
  décisions de détail du GDD consignées (D-014).
- Liste des assets alignée sur le GDD (16 assets, tous à créer).
- Feuille de route et README mis à jour ; `Config.GAME_VERSION` passe à `0.1.2`.

### Corrections de bugs
- Aucune.

### Problèmes connus
- Toutes les valeurs chiffrées du GDD sont théoriques et devront être équilibrées en test.
- Le GDD attend une relecture et une validation.

### Fichiers
- **Ajoutés** : `docs/GDD/README.md`, `docs/GDD/01-univers.md` à `docs/GDD/11-vertical-slice.md`
- **Modifiés** : `CHANGELOG.md`, `README.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`,
  `docs/ASSETS.md`, `docs/GDD/00-concept.md`, `src/shared/Config.luau`
- **Supprimés** : —

### Prochaines étapes
- Phase 3 : architecture technique détaillée et fondations (v0.2.0) : multi-places, réseau
  sécurisé, données joueur avec verrou de session.
- Premier asset Blender : la relique « Pas de Faille ».

---

## [v0.1.1] — 2026-11-06 — « Décisions de conception »

### Description générale
Les questions ouvertes du concept sont tranchées. Aucune modification du code.

### Nouvelles fonctionnalités
- Aucune.

### Modifications
- Perte **totale** du butin et de l'équipement emporté à la mort, retour à l'équipement de
  base ; l'emplacement d'Ancre est supprimé (D-007, remplace D-006).
- PvP obligatoire dans les Éclats à haut risque (D-008).
- Mobile prioritaire (D-009).
- Première époque : forteresse médiévale (D-010).
- Contexte de production consigné : développeur solo débutant à temps plein (D-011).
- `Config.GAME_VERSION` passe à `0.1.1`.

### Corrections de bugs
- Aucune.

### Problèmes connus
- À confirmer : le Codex, la maîtrise et la réputation restent-ils permanents malgré la perte totale ?

### Fichiers
- **Ajoutés** : —
- **Modifiés** : `CHANGELOG.md`, `README.md`, `docs/DECISIONS.md`, `docs/GDD/00-concept.md`,
  `src/shared/Config.luau`
- **Supprimés** : —

### Prochaines étapes
- Phase 2 : rédaction du Game Design Document complet.

---

## [v0.1.0] — 2026-11-06 — « Initialisation »

### Description générale
Création du projet. Le concept **Fracture** (extraction PvPvE) et l'univers des
**Éclats temporels** sont choisis à l'issue de la phase 1. Aucun gameplay n'est implémenté.

### Nouvelles fonctionnalités
- Aucune fonctionnalité de jeu.
- Structure de projet Rojo (`src/shared`, `src/server`, `src/client`) avec points d'entrée
  serveur et client en démarrage deux phases (`init` puis `start`).
- Chaîne d'outils figée via Rokit : Rojo 7.7.1, Selene 0.32.0, StyLua 2.6.0, Wally 0.3.2.
- CI GitHub Actions : vérification du formatage (StyLua) et lint (Selene).
- Documentation : concept, journal des décisions, feuille de route, architecture prévue,
  suivi des assets, règles de versionnement.

### Modifications
- Aucune (première version).

### Corrections de bugs
- Aucune.

### Problèmes connus
- Les questions de conception ouvertes (temps disponible, sévérité de la perte, intensité
  du PvP, priorité mobile) ne sont pas encore tranchées.
- L'architecture multi-places (Refuge + Éclats) est décidée mais pas encore reflétée dans
  la configuration Rojo (un seul `default.project.json` pour l'instant).

### Fichiers
- **Ajoutés** : `README.md`, `CHANGELOG.md`, `default.project.json`, `rokit.toml`,
  `wally.toml`, `selene.toml`, `stylua.toml`, `.gitignore`, `.gitattributes`,
  `.github/workflows/ci.yml`, `src/shared/Types.luau`, `src/shared/Config.luau`,
  `src/server/init.server.luau`, `src/client/init.client.luau`, `docs/GDD/00-concept.md`,
  `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/ASSETS.md`,
  `docs/VERSIONING.md`, dossiers vides `assets/`, `src/*/Systems|Controllers|Util`.
- **Modifiés** : —
- **Supprimés** : —

### Prochaines étapes
- Répondre aux questions ouvertes du concept.
- Phase 2 : rédiger le Game Design Document complet (v0.1.x).
- Phase 3 : architecture multi-places et premier système fondateur (v0.2.0).
