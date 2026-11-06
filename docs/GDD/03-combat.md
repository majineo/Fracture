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
| Capacité 1 / 2 | Q / E | Deux boutons | LB / RB |
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

- Attaque légère (enchaînement de 3) et **attaque chargée** (maintien).
- **Parade** (✅ v0.4.3) : clic droit / LT / bouton « Parer » avec une arme de mêlée. Fenêtre
  de 0,22 s (lame) ou 0,3 s (épée longue), recharge 0,75 s ; un coup de face pendant la
  fenêtre est annulé et l'attaquant est étourdi 0,9 s. C'est la mécanique de skill principale
  au corps à corps.
- La mêlée bat la distance à moins de 6 studs ; la distance gagne au-delà.

## 6. Capacités

Deux capacités du Codex sont équipées par partie (voir 04-progression). Les reliques
non stabilisées ramassées en partie occupent un emplacement temporaire séparé.

## 7. Règles techniques (sécurité et réseau)

- Le client envoie seulement des **intentions** (« je tire dans cette direction ») ; le serveur
  calcule les dégâts.
- **Validation des tirs** : le serveur garde un historique des positions sur 1 s et vérifie
  que la cible était bien là au moment du tir, compte tenu de la latence du tireur.
- Cadence de tir, munitions, rechargement et portée vérifiés côté serveur.
- Aucun dégât, objet ou ressource n'est jamais décidé par le client.
