# Historique des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), numérotation
décrite dans [docs/VERSIONING.md](docs/VERSIONING.md). Chaque version porte un tag Git `vX.Y.Z`.

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
