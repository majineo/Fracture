# 05 — Équipement et économie

> Statut : 📋 Prévu.

## 1. Ressources

| Ressource | Rôle | Perdable ? |
|---|---|---|
| **Grains** (monnaie) | Fabrication, stabilisation, achats auprès de l'Ordre | Seulement ceux portés en partie |
| **Matériaux communs** (fer, bois, cuir) | Fabrication | Oui, en partie |
| **Matériaux d'époque** (ex. acier ancien, pierre de Faille) | Fabrication avancée, stabilisation | Oui, en partie |
| **Reliques** | Codex | Oui, en partie |

Tout ce qui est stocké au **coffre du Refuge** est en sécurité. Seul ce qui est emporté en
partie est en jeu.

## 2. Fabrication

- À la **Forge du Refuge**, à partir de recettes (rang, maîtrise, réputation).
- Pas d'usure des objets : un objet se perd uniquement à la mort. Règle simple et lisible.
- Niveaux de qualité : Commun → Raffiné → Maître. Écart total plafonné à ~20 % avec la base.

## 3. Catégories d'équipement

| Emplacement | Exemples | Effet |
|---|---|---|
| Arme ×2 | Voir 03-combat | Style de combat |
| Armure | Légère / moyenne / lourde | Points d'armure contre vitesse |
| Outil | Grappin, lanterne, crochet | Option de déplacement ou d'exploration |
| Sac | Petit / grand | +2 / +4 emplacements de butin |
| Consommables ×3 | Bandages, injecteurs, fumigènes, ancre de fuite | Survie |

## 4. Équilibre de l'économie

- **Entrées** : butin extrait, revente de reliques abîmées, contrats.
- **Sorties** : fabrication, stabilisation, pertes à la mort.
- La perte totale est elle-même une sortie importante : elle évite l'inflation.
- **Pas d'échange entre joueurs** dans la vertical slice (principal vecteur de duplication
  d'objets). À étudier plus tard avec une sécurité renforcée.

## 5. Sécurité des objets

- Chaque objet a un **identifiant unique** (GUID) ; deux objets identiques ne peuvent pas exister.
- L'extraction est une **transaction serveur** : le butin passe de « porté » à « possédé » en
  une seule écriture.
- Profils protégés par un **verrou de session** (un seul serveur peut modifier un profil).

## 6. Monétisation (Robux)

Principe : **jamais de puissance à vendre**. Avec la perte totale et le PvP, vendre de la
puissance détruirait le jeu.

| Prévu | Exemples |
|---|---|
| Cosmétiques | Apparences d'armes, de harnais, effets de stabilisation |
| Passe de saison 💭 | Récompenses cosmétiques par époque |
| Confort léger 💭 | Emplacements de coffre supplémentaires, serveurs privés |

Interdit : armes, capacités, Grains contre des Robux, protection contre la perte.
