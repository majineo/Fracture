# 02 — Gameplay : la partie dans un Éclat

> Statut : 📋 Prévu. Toutes les valeurs chiffrées sont des points de départ à équilibrer en test.

## 1. Avant la partie (Refuge)

1. Le joueur prépare sa **charge** : 2 armes, 1 armure, 1 outil, 1 sac, 3 consommables
   (voir 05-equipement-economie) et 2 capacités du Codex.
   Tout ce qui est emporté peut être perdu, sauf l'équipement de base (voir §6).
2. Il rejoint ou forme une **escouade** (1 à 4 joueurs).
3. Il choisit un **Éclat** au Portail :

| Type d'Éclat | PvP | Butin | Joueurs |
|---|---|---|---|
| **Calme** | Non | Faible | 8 à 12 |
| **Instable** | Oui | Normal | 12 à 16 |
| **Critique** 💭 | Oui | Élevé, reliques rares | 16 à 24 |

La vertical slice contient Calme et Instable.

## 2. Structure d'un Éclat

Un Éclat est une **grille de tuiles** (voir 06-environnements) assemblées à partir d'une graine.
Les escouades apparaissent sur les bords, éloignées les unes des autres. Le centre contient
le **Donjon**, où dort le Gardien.

| Phase | Durée | Ce qui se passe |
|---|---|---|
| **Exploration** | 0 – 5 min | Pillage, Échoués faibles, coffres, premières reliques |
| **Effondrement** | 5 – 12 min | Un côté de la couronne extérieure (4 tuiles) tombe toutes les 2 min, alerte 30 s avant ; ordre des côtés tiré de la graine (✅ v0.5.0) |
| **Faille finale** | 12 – 16 min | Le Gardien s'éveille, la Faille d'extraction finale s'ouvre près du Donjon |
| **Fin** | 16 min | L'Éclat s'effondre entièrement : tout joueur encore présent meurt |

## 3. L'extraction

- **Points d'extraction secondaires** : 2 à 3 par Éclat, ouverts à des moments aléatoires
  pendant 90 s. Il faut rester **8 s** dans la zone sans subir de dégâts. Ils permettent de
  partir tôt avec un butin modeste.
- **La Faille finale** : toujours ouverte pendant la dernière phase, mais près du Gardien.
- Extraire = le butin transporté devient la propriété permanente du joueur (transaction serveur).

## 4. Butin

| Source | Contenu |
|---|---|
| Coffres et caisses | Matériaux, Grains, consommables |
| Échoués | Matériaux, parfois une arme d'époque |
| **Autels** | Reliques (1 à 3 par Éclat) |
| Gardien | Matériaux rares, relique garantie |
| **Sacs de joueurs morts** | Tout ce que le joueur portait (hors équipement de base) |

L'inventaire de partie est limité à **12 emplacements** (pensé pour le tactile : pas de grille
à la Tetris). Un sac à dos (équipement) peut en ajouter.

## 5. Mécaniques signatures

### Utiliser ou ramener
Une relique ramassée offre **3 charges** d'un pouvoir utilisable tout de suite. Chaque charge
utilisée l'abîme ; à 0 charge, elle disparaît. Ramenée **avec ses 3 charges**, elle peut être
stabilisée au Refuge et entre définitivement dans le **Codex** (voir 04-progression).
Une relique partiellement utilisée se revend contre des Grains.

### Signature
Jauge de 0 à 100 qui augmente avec le nombre de reliques portées et les combats bruyants
(tirs, explosions).

| Signature | Effet |
|---|---|
| 0 – 39 | Invisible |
| 40 – 69 | Les Échoués proches te repèrent plus vite |
| 70 – 100 | Ta position approximative apparaît sur la boussole de tous les joueurs toutes les 20 s |

### Pactes
Deux escouades peuvent conclure un Pacte (interaction de proximité, acceptée des deux côtés) :
pas de tirs alliés entre elles, positions partagées. Rompre un Pacte est possible ; le
traître porte la marque **Parjure** (visible de tous) jusqu'à la fin de l'Éclat.

### Événements temporels 💭
Exemples : écho d'une bataille qui fait réapparaître des Échoués, zone où le temps ralentit,
cloche qui révèle tous les joueurs. Un ou deux par partie, après la vertical slice.

## 6. La mort

- Le joueur lâche un **Sac** contenant tout ce qu'il portait, sauf l'équipement de base
  (D-007). Le Sac reste jusqu'à l'effondrement de sa tuile.
- **Réanimation** : un coéquipier peut relever un joueur à terre pendant 20 s (5 s
  d'interaction). Au-delà, ou s'il est achevé, le joueur est mort.
- Un joueur mort peut **observer** son escouade jusqu'à la fin de la partie.
- Ce qui n'est **jamais** perdu : Codex, maîtrise d'armes, rang, spécialisations, réputation,
  équipement de base, cosmétiques.

## 7. L'équipement de base

Gratuit, illimité, jamais perdu, **jamais lâché** dans un Sac. Il doit permettre à un joueur
habile de gagner un combat contre un joueur mieux équipé (écart maximal visé : environ 20 %).
Contenu : Pistolet de Fractureur, Lame courte, armure légère, 1 bandage.
