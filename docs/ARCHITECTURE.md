# Architecture technique

> Dernière mise à jour : v0.3.0 — 2026-11-06

## 1. Vue d'ensemble

Le jeu est un **univers Roblox à deux places** (D-004) qui partagent le même code :

| Place | Fichier de projet Rojo | Rôle |
|---|---|---|
| Refuge | `places/refuge.project.json` | Hub social, préparation, Forge, Portail |
| Éclat | `places/eclat.project.json` | Parties d'extraction (serveurs réservés) |

Chaque fichier de projet assemble le **code commun** (`Core`) et le **code propre à la place**
(`Refuge` ou `Eclat`), et fournit `Shared.PlaceKind`.

## 2. Arborescence

```text
src/
├── shared/                      → ReplicatedStorage > Shared (visible par les clients)
│   ├── Config.luau                 réglages publics (version…)
│   ├── Types.luau                  types qui traversent le réseau
│   ├── Net/Definitions.luau        LISTE UNIQUE des remotes
│   └── Util/Guard.luau, Signal.luau
├── places/<place>/PlaceKind.luau → ReplicatedStorage > Shared > PlaceKind
├── server/
│   ├── Core/                    → ServerScriptService > Server (le seul Script serveur)
│   │   ├── init.server.luau        démarrage deux phases
│   │   ├── Lib/                    modules utilitaires serveur (non démarrés)
│   │   └── Systems/                systèmes communs (démarrés)
│   ├── Refuge/Systems/          → Server > Place > Systems (place Refuge)
│   └── Eclat/Systems/           → Server > Place > Systems (place Éclat)
└── client/
    ├── Core/                    → StarterPlayerScripts > Client (le seul LocalScript)
    │   ├── init.client.luau
    │   ├── Lib/Net.luau
    │   └── Controllers/
    ├── Refuge/Controllers/
    └── Eclat/Controllers/
tests/                             tests unitaires hors Studio (Lune)
```

## 3. Démarrage

Le Script serveur charge tous les ModuleScripts de `Server/Systems` et `Server/Place/Systems`,
les trie par nom, appelle `init()` sur tous, puis `start()` sur tous (chacun dans son thread).
Même principe côté client avec les `Controllers`.

- `init()` : synchrone, ne bloque pas. Connexions, écoute des remotes, dépendances.
- `start()` : boucles et travail long.
- Un système en utilise un autre par `require` direct ; jamais de `_G`.

**Ajouter un système** : un fichier dans `Systems/` (ou `Controllers/` côté client) qui
renvoie une table avec `init` et/ou `start`. Rien d'autre à modifier.

## 4. Réseau

- Tous les remotes sont déclarés dans `shared/Net/Definitions.luau` avec leur direction et
  leur limite de fréquence. Le serveur les crée au démarrage dans `ReplicatedStorage > Remotes`.
- Serveur : `Net.on(nom, gestionnaire)` (requêtes du client), `Net.fire(nom, joueur, …)`,
  `Net.fireAll(nom, …)`. Client : `Net.fire(nom, …)`, `Net.on(nom, gestionnaire)`.
- Chaque requête passe par un **limiteur de fréquence** (seau à jetons par joueur et par remote).
- Les arguments arrivent en `unknown` : chaque gestionnaire les valide avec `Guard`
  (type → bornes → permission → plausibilité).
- Le client n'envoie que des **intentions**. Le serveur décide de tout (dégâts, butin, objets).
- Pas de `RemoteFunction` appelée vers le client.

| Remote | Direction | Rôle |
|---|---|---|
| `ClientReady` | Client → serveur | Le client est prêt ; demande son instantané de profil |
| `ProfileSnapshot` | Serveur → client | Vue publique du profil du joueur |
| `GrappleStart` | Client → serveur | Cible du grappin (Vector3), validée par le serveur |
| `GrappleEnd` | Client → serveur | Fin du grappin |
| `GrappleState` | Serveur → clients | Corde d'un joueur (cible ou nil) pour l'affichage |
| `DevCommand` | Client → serveur | Commandes de test, écoutées uniquement dans Studio |

## 5. Données joueur

Un seul module touche aux DataStores : `Server/Systems/PlayerData`.

```text
Connexion ─▶ revendication du verrou (UpdateAsync) ─▶ profil en mémoire
                 │ verrou d'un autre serveur ? réessais 8 × 3 s, sinon expulsion
                 │ échec de lecture ? expulsion (jamais de profil vide)
En jeu ─▶ PlayerData.get(player) : le jeu modifie la table en mémoire
Toutes les 60 s (décalé) ─▶ sauvegarde + rafraîchissement du verrou
Départ / arrêt du serveur ─▶ sauvegarde finale + libération du verrou
```

- **Verrou de session** (`Lib/SessionLock`) : un seul serveur à la fois peut écrire un profil.
  Un serveur qui a perdu le verrou n'écrit plus rien. Un verrou de plus de 150 s est
  considéré comme abandonné (serveur planté).
- **Schéma versionné** (`Lib/ProfileSchema`) : migrations de version en version, ajout des
  champs manquants, refus des données d'une version future ou illisibles (jamais écrasées).
- **Validation avant écriture** : toute donnée non stockable (Vector3, Instance, NaN…) est
  détectée ; la dernière sauvegarde valide est alors conservée.
- **Objets indexés par GUID** dans le coffre : une seule copie possible de chaque objet.
- **Studio** : sans accès aux API, stockage en mémoire (JSON) ; avec accès, DataStore séparé
  `PlayerProfiles_v1_Studio` pour ne jamais toucher aux données réelles.

## 6. Déplacement

```text
Client (Controllers/MovementController)          Serveur
  entrées (clavier, tactile, manette)               Systems/MovementGuard
  machine à états : Normal / Slide / Mantle /         positions toutes les 0,2 s
                    Grapple                           → Lib/MovementValidator (pur)
  Movement/Slide, Mantle, Grapple, Rope               → retour en arrière si impossible
  Shared/Movement/Stamina (pur)                     Systems/Grapple
        │ GrappleStart(cible) ───────────────────▶   type → recharge → portée → vue
        │                                             → MovementGuard.allow(...)
        ◀──────────────── GrappleState(joueur, cible) → corde chez les autres clients
```

- Les réglages sont dans `Shared/Movement/MovementConfig` (lisibles par le client ; le serveur
  s'en sert pour fixer ses limites).
- Tout système serveur qui déplace un joueur doit appeler `MovementGuard.grace` (téléportation)
  ou `MovementGuard.allow` (vitesse exceptionnelle), sinon le joueur sera ramené en arrière.
- Outils de test Studio : `Remotes.DevCommand:FireServer("teleport", position)`.

## 7. Tests

| Niveau | Outil | Ce qui est couvert |
|---|---|---|
| Unitaires | Lune (`lune run tests/run`), aussi en CI | Guard, RateLimiter, Retry, ProfileSchema, SessionLock, Stamina, MovementValidator |
| Intégration | Studio (playtest) | Démarrage des deux places, profil, limite de fréquence, stockage, escalade, glissade, grappin, garde de mouvement |

Règle : la logique importante est écrite en **modules purs** (sans dépendance Roblox, horloge
et attentes injectables) pour être testable hors Studio.

## 8. Prévu

- 📋 Téléportation Refuge ↔ Éclat et file d'attente (MemoryStore) — nécessite de publier les
  deux places dans un même univers Roblox.
- 📋 Cartes définitives construites dans Studio : export en `.rbxm` dans `maps/` (les greybox
  sont déjà en `.model.json`).
