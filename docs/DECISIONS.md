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
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : 💭 Proposée, à confirmer
- **Proposition** : capacités du Codex, maîtrise d'armes, spécialisations et réputation sont
  permanentes ; seuls le butin transporté et l'équipement emporté se perdent à la mort.
  Emplacement d'Ancre protégé, équipement de base toujours gratuit, écarts de stats plafonnés (~+20 %).
