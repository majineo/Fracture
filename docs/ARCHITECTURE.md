# Architecture technique

> Statut : 📋 Prévue. Ce document sera détaillé en phase 3.

## Implémenté (v0.1.0)

- Code synchronisé par Rojo depuis `src/` (voir [README](../README.md)).
- Démarrage deux phases : le script serveur charge chaque ModuleScript de `Server/Systems`,
  appelle `init()` sur tous, puis `start()` sur tous. Même principe côté client avec
  `Client/Controllers`. Un système ne dépend d'un autre qu'après la phase `init`.
- Luau `--!strict` dans tous les fichiers.

## Prévu

- **Multi-places** (voir D-004) : place Refuge + places d'Éclats, code partagé dans `src/shared`,
  un fichier de projet Rojo par place.
- **Réseau** : remotes déclarés à un seul endroit, chaque remote validé côté serveur (types,
  limites de fréquence, cohérence de l'état). Le client ne décide jamais des dégâts, du butin
  ou de l'inventaire.
- **Données joueur** : session lock, sauvegardes périodiques, schéma versionné avec migrations,
  objets identifiés par GUID.
- **Tests** : modules de logique pure testables séparément, remotes de test réservés à Studio.
