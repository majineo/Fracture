# Historique des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), numérotation
décrite dans [docs/VERSIONING.md](docs/VERSIONING.md). Chaque version porte un tag Git `vX.Y.Z`.

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
