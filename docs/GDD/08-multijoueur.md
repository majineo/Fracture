# 08 — Multijoueur

> Statut : 📋 Prévu. Architecture décidée en D-004.

## 1. Places et serveurs

| Place | Joueurs par serveur | Type de serveur |
|---|---|---|
| **Refuge** | Jusqu'à 30 | Public |
| **Éclat** | 8 à 16 (vertical slice) | Serveur réservé, créé pour chaque partie |

## 2. Parcours d'un joueur

1. Arrivée au Refuge, chargement du profil (verrou de session).
2. Formation d'une escouade (invitation ou groupe d'amis Roblox).
3. Le chef d'escouade lance la recherche au Portail → file d'attente partagée entre serveurs.
4. Quand assez d'escouades sont réunies (ou après 60 s d'attente avec un minimum atteint),
   un serveur réservé est créé et tous les membres y sont téléportés ensemble.
5. Fin de partie (extraction ou mort) → retour au Refuge, profil sauvegardé avant le départ.

## 3. Escouades

- 1 à 4 joueurs, téléportés ensemble.
- Marqueurs partagés (« ennemi ici », « butin ici ») : indispensables sur mobile sans chat vocal.
- Réanimation entre coéquipiers.
- Pas de tirs alliés à l'intérieur d'une escouade.

## 4. Interactions entre escouades

- **Pactes** et **Parjure** (voir 02-gameplay).
- Attirer des Échoués sur une escouade rivale.
- Piller les Sacs des joueurs morts.

## 5. Population faible

- Si le nombre d'escouades est trop bas, la partie démarre quand même : les Échoués sont plus
  nombreux et l'Éclat est plus petit.
- Les Éclats calmes peuvent démarrer à partir d'une seule escouade.

## 6. Communication

- Chat textuel Roblox et chat vocal Roblox (13 ans et plus, géré par Roblox).
- Roue de messages rapides pour mobile.

## 7. Risques techniques

| Risque | Réponse |
|---|---|
| Téléportation qui échoue | Nouvelles tentatives, retour au Refuge sans perte |
| Déconnexion en partie | Le personnage reste 30 s ; s'il meurt, la perte s'applique (sinon exploit de déconnexion) |
| Joueur qui quitte avec du butin | Le butin n'est acquis qu'à l'extraction : quitter = mort |
| Données corrompues ou dupliquées | Verrou de session, GUID, sauvegarde avant téléportation |
