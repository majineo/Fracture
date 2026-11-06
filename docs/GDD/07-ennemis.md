# 07 — Ennemis (Échoués et Gardien)

> Statut : 📋 Prévu. Tous les modèles sont **à créer**.

## 1. Principes

- Les Échoués sont **lisibles** : chaque attaque est annoncée par une animation claire.
- Ils rejouent leur époque : un soldat figé reprend sa garde, un arbalétrier recharge en boucle.
- Ils attaquent **aussi les autres escouades** : on peut attirer des Échoués sur un rival.
- IA côté serveur, simple et peu coûteuse (états : immobile → alerte → poursuite → attaque).

## 2. Échoués de la forteresse médiévale

| Échoué | Rôle | Santé | Comportement |
|---|---|---|---|
| **Homme d'armes figé** | Mêlée | 120 | S'approche, attaque en 2 coups annoncés ; peut être paré |
| **Arbalétrier figé** | Distance | 80 | Reste en hauteur, tir lent visible (ligne rouge 1 s avant) |
| **Chevalier brisé** 💭 | Élite | 300 | Bouclier frontal, il faut le contourner |

La vertical slice contient les deux premiers.

## 3. Le Gardien : le Roi Sans Heure

Un roi en armure, trois fois la taille d'un joueur, figé sur son trône au moment de la chute
de sa forteresse. Il s'éveille au début de la Faille finale.

| Phase | Santé | Attaques |
|---|---|---|
| **1 — Le Roi** | 100 % → 60 % | Coups d'épée en arc, charge en ligne droite |
| **2 — La Couronne brisée** | 60 % → 25 % | Invoque 3 hommes d'armes, onde de choc temporelle |
| **3 — Le Temps arrêté** | 25 % → 0 % | Gèle des zones de l'arène, attaques plus rapides |

- Santé adaptée au nombre de joueurs présents dans l'arène.
- **Points faibles** : la couronne (dégâts ×2) exposée après une charge ratée.
- Récompense : relique garantie, matériaux rares, trophée cosmétique (première victoire).
- Les escouades rivales sont dans la même arène : c'est le moment idéal pour un Pacte… ou une trahison.

## 4. Notes Blender

- Échoués : **un seul rig humanoïde partagé** (compatible R15) pour les deux types ; seuls les
  maillages et accessoires changent. Animations : marche, garde, 2 attaques, touché, mort.
- Gardien : rig dédié, environ 10 animations. C'est le modèle le plus difficile de la vertical
  slice : à faire **en dernier**, quand le pipeline est maîtrisé.
