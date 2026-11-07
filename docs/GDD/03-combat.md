# 03 — Combat et déplacement

> Statut : 📋 Prévu. Valeurs de départ à équilibrer.

## 1. Caméra et contrôles

- Troisième personne par-dessus l'épaule, épaule changeable. Visée rapprochée en mode visée.
- **Mobile prioritaire** (D-009) : chaque action a un bouton tactile dès sa création.

| Action | PC | Mobile | Manette |
|---|---|---|---|
| Tirer / frapper | Clic gauche | Bouton tir (droite) | RT |
| Viser | Clic droit | Bouton visée | LT |
| Sprint | Maj (maintien) | Bouton Sprint (bascule) | L3 (bascule) |
| Grappin | G (vise le curseur) | Bouton Grappin (vise le centre de l'écran) | R3 |
| Glissade | C pendant le sprint | Bouton accroupi pendant le sprint | B |
| Saut / escalade | Espace | Bouton saut | A |
| Capacité de l'arme (✅ v0.4.5) | Q | Bouton « Capa. » | LB |
| Capacités du Codex 1 / 2 (📋) | à définir | Deux boutons | à définir |
| Arme 1 / 2 (même touche = ranger) | 1 / 2 | Bouton Arme (fait défiler) | Croix ◀ / ▶ |
| Recharger | R | Bouton | X |
| Interagir | F | Bouton contextuel | Y |

**Assistance à la visée** sur mobile et manette uniquement : léger ralentissement de la
caméra sur une cible et faible attraction en visée. Jamais sur souris.

## 2. Déplacement

| Mouvement | Valeur de départ | Note |
|---|---|---|
| Marche | 14 studs/s | |
| Sprint | 22 studs/s | Endurance : 6 s, recharge en 4 s après 0,6 s de pause ; jauge vide = resprint à 25 % |
| Glissade | 30 → 15 studs/s en 0,8 s (≈ 18 studs) | En sprint uniquement, coûte 15 % d'endurance ; en descente elle dure 2,5 fois plus (≈ 45 studs) ; sauter pendant la glissade garde l'élan |
| Escalade de rebord | De 2,5 à 7 studs de haut, en 0,35 s | Automatique en sautant face à un rebord |
| Grappin | Portée 60 studs, 70 studs/s, recharge 8 s | Sauter pendant la traction = lâcher avec une petite impulsion. **Équipement** (pour l'instant donné à tous) |

✅ Implémenté en v0.3.0. Le déplacement repose sur un contrôleur personnalisé construit
au-dessus du Humanoid. La position est simulée côté client et vérifiée côté serveur
(vitesse maximale, montée maximale, téléportation) ; un grappin n'est autorisé qu'après
validation serveur (portée, recharge, ligne de vue).

**Ressenti (v0.3.1)** : accélération progressive (9 → 14 studs/s au démarrage), glissade qui
ralentit en douceur et rend la vitesse sans à-coup, escalade sur une courbe lissée, grappin en
trois temps (vol du crochet, traction qui accélère, ralentissement à l'arrivée), escalade
automatique si le grappin arrive face à un rebord (permet d'atteindre des rebords trop hauts
pour une escalade directe). Commandes retenues 0,18 s si pressées trop tôt, saut possible
0,12 s après avoir quitté un rebord.

**Animations (v0.3.1)** : ✅ animations procédurales (générées par le code, visibles par tous
les joueurs) pour la glissade, l'escalade (attraper puis se hisser), le grappin (bras pointé
vers la cible), le saut, la chute, la réception et l'inclinaison du sprint.
Caméra : champ de vision élargi en sprint / glissade / grappin, inclinaison en glissade, choc
à la réception. Effets : poussière de glissade et de réception, sons.

### Kit de mobilité (✅ v0.4.11, D-043)

FRACTURE est un jeu de **mobilité** : on se bat en mouvement.

- **Élan** (F · bouton « Élan » · croix ▲) : poussée de 0,16 s à 62 studs/s dans la direction du
  mouvement, au sol ou **une fois en l'air** (rendu au sol ou en touchant un mur) ; 20 %
  d'endurance, recharge 1,1 s. Images rémanentes cyan.
- **Course sur les murs** (automatique) : en l'air, en courant le long d'un mur quasi vertical, on
  court dessus jusqu'à 1,3 s (petite montée puis descente). On peut tirer et frapper pendant la
  course.
- **Saut mural** : sauter pendant la course pousse loin du mur, vers le haut et vers l'avant ; on
  enchaîne les murs.
- Le serveur tolère ces vitesses brièvement, au plus une fois par recharge qu'il mesure lui-même.

## 3. Santé et dégâts

✅ Implémenté en v0.4.0 (santé, armure, à terre, tête ×1,5, chute des dégâts avec la
distance). La réanimation par un coéquipier arrive avec les escouades.

- **Santé** : 100. **Armure** : 0 à 50 points selon l'équipement, absorbe les dégâts en premier.
- Pas de régénération naturelle : bandages (lent) et injecteurs (rapide) en consommables.
- **Coups à la tête** : ×1,5 pour les armes à distance.
- **Temps pour tuer visé** : 1 à 1,5 s entre joueurs bien équipés à moyenne distance.
  Assez court pour récompenser la précision, assez long pour pouvoir réagir.
- **Joueur à terre** : à 0 santé, le joueur rampe pendant 20 s ; il peut être réanimé ou achevé.

## 4. Armes de la vertical slice

✅ v0.4.0 : pistolet de Fractureur (24 dégâts, 5 tirs/s, 12 balles, 1,4 s de rechargement,
pleins dégâts jusqu'à 35 studs puis 55 % à 90 studs) et lame courte (30, attaque chargée
×1,8 après 0,6 s, cône de 75° sur 6,5 studs).

✅ v0.4.3 : fusil à répétition (48 dégâts, 1,5 tir/s, 6 balles, 2,4 s, très précis en visée,
dégâts pleins jusqu'à 80 studs), arbalète lourde (75 dégâts, 1 carreau, 1,9 s, traverse une
cible) et épée longue (42 dégâts, ×2 chargée après 0,8 s, cône de 100° sur 8,5 studs).
Choix des armes à l'armurerie du Refuge (provisoire).

| Arme | Type | Source | Rôle |
|---|---|---|---|
| **Pistolet de Fractureur** | Distance, semi-auto | Équipement de base | Polyvalent, précis |
| **Lame courte** | Mêlée, rapide | Équipement de base | Finition, discrétion |
| **Fusil à répétition** | Distance, longue portée | Fabriqué au Refuge | Contrôle à distance |
| **Arbalète lourde** | Distance, lente, perforante | Butin médiéval | Très gros dégâts, recharge longue |
| **Épée longue** | Mêlée lourde | Butin médiéval | Coups chargés, parade |

## 5. Mêlée

- Attaque légère (**enchaînement de 3** ✅ v0.4.6 : taille, revers, estoc ×1,3 ; coups espacés de
  moins de 0,9 s) et **attaque chargée** (maintien), qui remet l'enchaînement à zéro.
- **Aide à la mêlée** (✅ v0.4.6, tous supports) : le coup vise l'ennemi le plus proche du centre
  de l'écran dans un cône de 55°, le personnage se tourne vers lui et avance d'au plus 2,5 studs
  (jamais à travers un mur). Le serveur revérifie portée, cône et ligne de vue.
- **Impact** (✅ v0.4.6) : traînée sur la vraie lame, étincelles, son d'impact, micro-arrêt.
- **Parade** (✅ v0.4.3) : clic droit / LT / bouton « Parer » avec une arme de mêlée. Fenêtre
  de 0,22 s (lame) ou 0,3 s (épée longue), recharge 0,75 s ; un coup de face pendant la
  fenêtre est annulé et l'attaquant est étourdi 0,9 s. C'est la mécanique de skill principale
  au corps à corps.
- La mêlée bat la distance à moins de 6 studs ; la distance gagne au-delà.

## 6. Capacités

### 6.1 Capacités des armes (✅ v0.4.5 – v0.4.7, D-038)

Chaque arme a une **capacité active** et un **trait passif**. La capacité s'utilise quand le
**noyau** de l'arme est plein ; il se remplit en infligeant des dégâts avec cette arme (100 points)
et se vide à la mort. Toute capacité est annoncée (lueur, son, courte préparation). 📋 Plus tard :
débloquées par la maîtrise de l'arme (permanente).

| Arme | Capacité active | Trait passif | Statut |
|---|---|---|---|
| Pistolet | **Retour** : après 0,25 s, retour à sa position d'il y a 2 s, avec la santé d'alors (+35 au plus, jamais moins) | Chargeur plein après une élimination / mise à terre | ✅ v0.4.5 |
| Lame courte | **Pas de l'ombre** : ennemi visé à moins de 12 studs, réapparition dans son dos après 0,3 s ; premier coup ×1,5. La victime est prévenue (« DERRIÈRE TOI ! ») et peut parer | **Riposte** : après une parade réussie, coup suivant ×2 (1,5 s) | ✅ v0.4.5 |
| Fusil à répétition | **Salve au levier** (Q bref : 3 balles en 0,6 s, cadence ignorée, plus de dispersion) **et** **balle de rebond** (Q maintenu 0,35 s : ricoche une fois sur un mur) | **Souffle** : après 1 s immobile, tir suivant +25 % (immobilité jugée par le serveur) | ✅ v0.4.7 |
| Arbalète lourde | **Carreau de stase** (tiré par le noyau, même en rechargement ; portée 60 studs, sinon la bulle tombe au sol) : bulle de 4 studs au premier impact, 3 s ; ralentit joueurs et Échoués de 50 % ; un tir qui la traverse perd 50 % | Perforation | ✅ v0.4.7 |
| Épée longue | **Onde de fracture** (Q : 0,5 s d'annonce, onde de 8 studs, 35 dégâts, ralentit / étourdit, parable) ; **Garde du Temps** (parade maintenue 0,35 s : bloque tout de face, 75°, vide le noyau en 3 s, pas d'attaque, déplacement ralenti) | Allonge | ✅ v0.4.7 |

### 6.2 Capacités du Codex

Deux capacités du Codex sont équipées par partie (voir 04-progression). Les reliques
non stabilisées ramassées en partie occupent un emplacement temporaire séparé.

## 7. Règles techniques (sécurité et réseau)

- Le client envoie seulement des **intentions** (« je tire dans cette direction ») ; le serveur
  calcule les dégâts.
- **Validation des tirs** : le serveur garde un historique des positions sur 1 s et vérifie
  que la cible était bien là au moment du tir, compte tenu de la latence du tireur.
- Cadence de tir, munitions, rechargement et portée vérifiés côté serveur.
- Aucun dégât, objet ou ressource n'est jamais décidé par le client.
