# 07 — Ennemis (Échoués et Gardien)

> Statut : 🔧 En cours. ✅ Homme d'armes et arbalétrier figés (v0.4.4) · 📋 Chevalier brisé,
> Gardien.

## 1. Principes

- Les Échoués sont **lisibles** : chaque attaque est annoncée par une animation claire.
- Ils rejouent leur époque : un soldat figé reprend sa garde, un arbalétrier recharge en boucle.
- Ils attaquent **aussi les autres escouades** : on peut attirer des Échoués sur un rival.
- IA côté serveur, simple et peu coûteuse (états : immobile → alerte → poursuite → attaque).

## 2. Échoués de la forteresse médiévale

| Échoué | Rôle | Santé | Comportement |
|---|---|---|---|
| **Homme d'armes figé** ✅ | Mêlée | 120 | Poursuit, lève son épée qui rougeoie 0,6 s puis frappe (22) ; paré = étourdi 0,9 s |
| **Arbalétrier figé** ✅ | Distance | 80 | Garde ses distances (recule sous 16 studs), épaule 1,1 s avec un trait rouge vers sa cible, puis tire (28) ; se cacher annule le tir |
| **Chevalier brisé** 💭 | Élite | 300 | Bouclier frontal, il faut le contourner |

La vertical slice contient les deux premiers.

### Fonctionnement (v0.4.4)

- **Cerveau** : module pur `Combat/EnemyBrain` (testé) appelé 5 fois par seconde par le serveur
  (`EnemyService`) : repos, retour au poste, poursuite, recul, préparation, frappe, visée, tir,
  étourdi. Repérage avec ligne de vue (55 / 80 studs), abandon au-delà de 90 / 110 studs.
- **Annonces** lues par les clients (`EnemyVisuals`) : attributs `AttackAt` (épée levée,
  contour rouge, son d'avertissement) et `AimAt` (trait rouge qui s'épaissit puis clignote).
- **Esquive** : le coup de mêlée part même si l'on recule (on esquive en sortant de la
  portée) ; l'arbalétrier vise la position du joueur 0,3 s plus tôt (on esquive en bougeant).
- **« Sauts » temporels** : toutes les 4 à 9 s, l'ennemi se fige 0,18 s (contour cyan).
- **Mort** : le corps se brise en éclats cyan. Dans l'Éclat, chaque poste est réoccupé
  90 s plus tard. Les Échoués n'attaquent que les joueurs (pas entre eux).
- 📋 Prévu : attaquer les autres escouades (attirer un Échoué sur un rival), tir en hauteur,
  vrais rigs animés.

## 3. Le Gardien : le Roi Sans Heure

Un roi en armure, trois fois la taille d'un joueur, figé sur son trône au moment de la chute
de sa forteresse. Il s'éveille au début de la Faille finale.

| Phase | Santé | Attaques |
|---|---|---|
| **1 — Le Roi** | 100 % → 60 % | Coups d'épée en arc, charge en ligne droite |
| **2 — La Couronne brisée** | 60 % → 25 % | Invoque 3 hommes d'armes, onde de choc temporelle |
| **3 — Le Temps arrêté** | 25 % → 0 % | Gèle des zones de l'arène, attaques plus rapides |

- Santé adaptée au nombre de joueurs présents dans l'arène.
- ✅ v0.8.0 : `Shared/Combat/GuardianBrain` (testé) + `GuardianService` ; corps R15 ×3, couronne
  provisoire ; arène = tuile du Donjon ; 1 500 PV +50 % par joueur ; trésor à sa mort.
- **Points faibles** : la couronne (dégâts ×2) exposée après une charge ratée.
- Récompense : relique garantie, matériaux rares, trophée cosmétique (première victoire).
- Les escouades rivales sont dans la même arène : c'est le moment idéal pour un Pacte… ou une trahison.

## 4. Notes Blender

- Échoués ✅ (v0.4.4) : corps R15 standard de Roblox + **équipement modélisé dans Blender**
  (une pièce par matériau, soudée à la partie du corps indiquée par son nom). Animations :
  celles de Roblox + poses procédurales (garde, préparation, coup, visée, étourdi).
- Gardien : rig dédié, environ 10 animations. C'est le modèle le plus difficile de la vertical
  slice : à faire **en dernier**, quand le pipeline est maîtrisé.
