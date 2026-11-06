# 11 — Vertical slice : périmètre exact

> La première version jouable. Objectif : prouver que **une partie dans un Éclat est amusante**.
> Rien en dehors de cette liste n'est développé avant qu'elle soit atteinte (D-011).

## Contenu

| Domaine | Inclus | Exclu (plus tard) |
|---|---|---|
| Places | Refuge minimal + 1 place d'Éclat | Autres époques |
| Types d'Éclats | Calme, Instable | Critique |
| Tuiles | 8 types de tuiles médiévales, grille 5 × 5 | Événements temporels |
| Déplacement | Marche, sprint, glissade, escalade, grappin | — |
| Armes | 5 (voir 03-combat) | Accessoires |
| Reliques | 3 (voir 04-progression), niveau 1 seulement | Niveaux 2 et 3 |
| Ennemis | 2 Échoués + le Roi Sans Heure | Chevalier brisé |
| Progression | Codex, maîtrise (2 paliers), rang 1 à 10 | Spécialisations, réputation |
| Économie | Grains, 3 matériaux, Forge, Coffre | Échanges, factions |
| Multijoueur | Escouades, file d'attente, Pactes | Classements |
| Interface | Combat, Charge, Codex, Forge, Coffre, Portail, fin de partie | Tutoriel scénarisé |
| Plateformes | Mobile, PC | Manette (si le temps le permet) |

## Critères de réussite

- Une partie complète se déroule sans bug bloquant avec 8 joueurs.
- 60 images/s sur PC moyen, 30 images/s stables sur un téléphone d'entrée de gamme.
- Aucune duplication d'objets possible lors des tests d'exploitation.
- Les testeurs veulent relancer une partie après une mort.

## Ordre de développement

Voir [ROADMAP](../ROADMAP.md) : fondations → déplacement → combat → Éclats → extraction →
reliques → vertical slice complète.
