# FRACTURE — Document de concept

> Statut : 📋 Concept validé (phase 1). Le détail est dans les sections 01 à 11 du GDD
> ([sommaire](README.md)). Dernière mise à jour : v0.1.2 — 2026-11-06

## 1. Pitch

Le temps s'est brisé. Le monde n'est plus qu'une mosaïque d'**Éclats** : des fragments instables
d'époques passées et futures (forteresse médiévale, ville industrielle, base futuriste, jungle
préhistorique…). Les **Fractureurs** y plongent pour récupérer des reliques de pouvoir, et doivent
s'en **extraire** avant que l'Éclat ne s'effondre. D'autres escouades sont dans le même Éclat.

**Genre** : extraction PvPvE, action à la troisième personne avec armes à feu, mêlée, pouvoirs
et déplacement riche.

## 2. Piliers de conception

1. **Le skill décide.** Écarts de stats plafonnés, progression surtout horizontale (options, styles).
2. **Chaque décision a un prix.** Utiliser ou ramener une relique, rester ou s'extraire.
3. **La carte est un adversaire.** Effondrement dynamique, chemins qui changent.
4. **La mort coûte cher.** Mourir fait perdre tout le butin et l'équipement emporté (D-007) ;
   l'équipement de base doit rester assez bon pour qu'un joueur habile puisse se reconstruire.

## 3. Boucle de partie

| Moment | Contenu |
|---|---|
| **Refuge** | Choix de l'équipement et des capacités, choix de l'Éclat (époque, danger, PvP ou non), escouade |
| **0 à 5 min : exploration** | Pillage, premières créatures (les Échoués), repérage des autres équipes |
| **5 à 12 min : effondrement** | Zones extérieures qui se désagrègent, extractions qui s'ouvrent et se ferment |
| **12 à 18 min : Faille finale** | Apparition du Gardien d'Éclat, dernière extraction disputée |
| **Retour** | Stabilisation des reliques, fabrication, réputation |

## 4. Mécaniques signatures

- 📋 **Utiliser ou ramener** : une relique trouvée donne un pouvoir immédiat mais se consume ;
  ramenée intacte, elle est stabilisée et entre définitivement dans le **Codex**.
- 📋 **Signature** : plus on porte de reliques, plus on est visible (radar ennemi, créatures).
- 📋 **Effondrement dynamique** et événements temporels (échos d'armées, zones ralenties).
- 📋 **Pactes** : alliances temporaires entre escouades ; la trahison est possible mais visible.
- 📋 **Combat** : armes à feu et mêlée viables ; glissade, escalade de rebords, grappin.

## 5. Progression

| Couche | Perdable ? | Rôle |
|---|---|---|
| Codex (capacités stabilisées) | Non | Cœur du développement du personnage |
| Maîtrise d'armes (par l'usage) | Non | Techniques et accessoires |
| Spécialisations (Éclaireur, Briseur, Tisseur temporel…) | Non | Styles de jeu |
| Équipement fabriqué et butin | Oui, **en totalité** à la mort | Risque et récompense ; retour à l'équipement de base |
| Réputation de factions | Non | Éclats rares, recettes |

Le Refuge est un lieu social, **pas** une base à faire fructifier (pas de tycoon).

## 6. Multijoueur

- Escouades de 1 à 4, Éclats de 16 à 24 joueurs (4 à 6 escouades) sur serveurs réservés.
- Créatures toujours présentes pour qu'un Éclat ne soit jamais vide.
- PvP obligatoire dans les Éclats à haut risque (D-008).
- Éclats calmes (sans PvP) pour les joueurs solo ou occasionnels.
- **Mobile prioritaire** (D-009) : contrôles tactiles et assistance à la visée dès le départ.

## 7. Première version jouable visée (vertical slice)

1 Refuge minimal · 1 époque (**forteresse médiévale**, D-010) · 6 à 8 tuiles d'Éclat assemblées procéduralement · 2 types de
créatures + 1 Gardien · 3 armes · 3 reliques · extraction · inventaire persistant sécurisé.

## 8. Risques identifiés

| Risque | Réponse prévue |
|---|---|
| Frustration de la perte totale (public jeune) | Progression permanente séparée, équipement de base viable, Éclats calmes, mesure des abandons en test |
| Développeur solo débutant (D-011) | Périmètre strict de la vertical slice, apprentissage progressif, code expliqué |
| Population insuffisante | PvE omniprésent, Éclats calmes, taille d'Éclat ajustable |
| Duplication d'objets | GUID par objet, extraction transactionnelle côté serveur, session lock |
| Latence des combats | Validation serveur avec historique des positions |
| Coût du contenu | Kits modulaires réutilisables par époque |

## 9. Questions ouvertes

- ✅ Équipe : solo, à temps plein, débutant en Luau et Blender (D-011).
- ✅ Perte : totale (D-007) ; Codex, maîtrise, rang et réputation restent permanents (D-012).
- ✅ PvP obligatoire dans les Éclats à haut risque (D-008).
- ✅ Mobile prioritaire (D-009).
- ✅ Première époque : forteresse médiévale (D-010).
