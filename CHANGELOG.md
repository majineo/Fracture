# Historique des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/), numérotation
décrite dans [docs/VERSIONING.md](docs/VERSIONING.md). Chaque version porte un tag Git `vX.Y.Z`.

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
