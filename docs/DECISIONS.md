# Journal des décisions

Chaque décision importante est consignée ici avec sa raison, pour pouvoir y revenir.
Une décision n'est jamais effacée : si elle change, on ajoute une nouvelle entrée qui la remplace.

---

## D-001 — Concept retenu : FRACTURE (extraction PvPvE)
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée
- **Choix** : parmi cinq concepts (Vélocité, Fracture, Écho, Colosses, Symbiose), le concept
  B « Fracture » est retenu.
- **Raisons** : forte rejouabilité (Éclats procéduraux), tension risque/récompense, multijoueur
  riche (escouades, alliances, trahisons), évolution sur plusieurs années, production basée sur
  des kits modulaires compatibles avec un travail Blender en petite équipe.
- **Idées conservées des autres concepts** : le déplacement riche de *Vélocité* (glissade,
  escalade, grappin) est intégré au combat.

## D-002 — Univers : les Éclats temporels
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée
- **Choix** : le temps s'est brisé ; chaque Éclat est le fragment instable d'une époque.
- **Raisons** : justifie le mélange armes à feu, mêlée et pouvoirs ; variété visuelle
  illimitée (une époque par mise à jour) ; identité distinctive sur Roblox.
- **Alternatives écartées** : Rêves fracturés (moins lisible, plus coûteux), Ciel brisé (moins distinctif).

## D-003 — Boucle de partie validée
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée (à confirmer en test)
- **Choix** : Refuge → Éclat de 12 à 18 min (exploration → effondrement → Faille finale) → extraction.
- **Note** : la durée sera ajustée lors des tests du prototype.

## D-004 — Univers Roblox multi-places
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : 📋 Décidée, pas encore implémentée
- **Choix** : une place Refuge (hub) et une ou plusieurs places d'Éclats, reliées par
  TeleportService ; matchmaking via MemoryStoreService ; serveurs réservés pour les Éclats.
- **Raisons** : nécessaire pour des parties de 16 à 24 joueurs isolées du hub. Changer ce
  choix plus tard obligerait à reconstruire l'architecture.

## D-005 — Code source synchronisé par Rojo
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Implémentée
- **Choix** : le code vit dans des fichiers `.luau` versionnés par Git et synchronisés dans Studio
  par Rojo. Outils figés par Rokit. Luau en mode `--!strict`.
- **Raisons** : historique Git complet, revue de code, CI, pas de code perdu dans un fichier de place.

## D-006 — Progression : permanente contre risquée
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ⛔ Remplacée par D-007
- **Proposition** : capacités du Codex, maîtrise d'armes, spécialisations et réputation sont
  permanentes ; seuls le butin transporté et l'équipement emporté se perdent à la mort.
  Emplacement d'Ancre protégé, équipement de base toujours gratuit, écarts de stats plafonnés (~+20 %).

---

## D-007 — Perte totale à la mort
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée (remplace D-006)
- **Choix** : un joueur qui meurt dans un Éclat perd **tout** son butin et tout l'équipement
  emporté. Il repart avec l'**équipement de base** gratuit. Pas d'emplacement d'Ancre.
- **Toujours permanent** : Codex, maîtrise d'armes, spécialisations, réputation (confirmé en D-012).
- **Risque assumé** : frustration plus forte pour un public jeune. Mesures prévues : équipement
  de base réellement viable, Éclats calmes pour reconstruire un stock, mesure du taux d'abandon
  après une mort lors des tests.

## D-008 — PvP dans les Éclats à haut risque
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Choix** : PvP obligatoire dans les Éclats à haut risque ; Éclats calmes sans PvP conservés
  pour les joueurs solo et occasionnels.

## D-009 — Mobile prioritaire
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Conséquences** : contrôles tactiles pensés dès le premier système (pas ajoutés après coup),
  assistance à la visée sur mobile, interface lisible sur petit écran, budgets de performance
  calibrés pour des téléphones d'entrée de gamme.

## D-010 — Première époque : forteresse médiévale
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Choix** : la vertical slice se déroule dans un Éclat de forteresse médiévale.
- **Intérêt** : formes simples à modéliser (pierre, bois), bon premier projet Blender ;
  contraste fort avec les armes à feu des Fractureurs.

## D-011 — Contexte de production : développeur solo débutant
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Constat
- **Contexte** : un seul développeur, à temps plein, sans expérience de Luau ni de Blender.
- **Conséquences** :
  - Claude écrit et explique le code ; chaque système est accompagné d'une explication et
    de tests à faire dans Studio, pour que l'apprentissage se fasse en avançant.
  - Apprentissage de Blender progressif, du plus simple au plus complexe : reliques → armes
    → kit de tuiles → créatures riggées → Gardien.
  - La vertical slice est la priorité absolue ; aucun contenu supplémentaire avant qu'elle
    soit amusante.

## D-012 — Progression permanente confirmée
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : ✅ Validée
- **Choix** : le Codex, la maîtrise d'armes, le rang, les spécialisations et la réputation ne
  sont jamais perdus à la mort. Seuls le butin et l'équipement emporté le sont (D-007).

## D-013 — Méthode de travail
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : ✅ Validée
- **Choix** : Claude prend les décisions techniques et de détail de façon autonome et les
  documente ; explications courtes. Les décisions de direction (concept, règles majeures,
  actions irréversibles ou publiques) restent soumises à validation.

## D-014 — Game Design Document v1
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : 📋 En attente de validation
- **Choix** : GDD rédigé dans `docs/GDD/` (11 sections). Décisions de détail notables :
  Éclat de 5 × 5 tuiles de 64 studs, parties de 16 min, extraction en 8 s, 12 emplacements de
  butin, reliques à 3 charges (« utiliser ou ramener »), 2 capacités équipées, pas d'usure des
  objets, pas d'échange entre joueurs dans la vertical slice, monétisation uniquement cosmétique.

## D-015 — Couche de données maison plutôt que la bibliothèque ProfileStore
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée
- **Choix** : verrou de session, migrations et sauvegardes écrits dans le projet
  (`SessionLock`, `ProfileSchema`, `PlayerData`) au lieu d'utiliser ProfileStore.
- **Raisons** : l'extraction et le passage Refuge ↔ Éclat exigent un contrôle exact du verrou
  et des transactions ; la logique critique est en modules purs, couverte par des tests
  automatiques, sans dépendance externe.
- **Revoir si** : des pertes ou duplications apparaissent en test réel ; ProfileStore reste
  l'alternative de référence.

## D-016 — Tests unitaires hors Studio avec Lune
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée
- **Choix** : la logique critique est écrite en modules purs testés par Lune, localement et
  dans la CI GitHub. Les comportements liés à Roblox sont testés en playtest dans Studio.

## D-017 — Deux places, code partagé
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée (applique D-004)
- **Choix** : un fichier de projet Rojo par place (`places/*.project.json`) ; code commun dans
  `Core`, code propre dans `Refuge` / `Eclat` ; un seul Script serveur et un seul LocalScript.