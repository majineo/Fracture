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

Animations : 📋 aucune animation dédiée pour l'instant (glissade, escalade, grappin) ; la
caméra s'abaisse pendant la glissade.

## 3. Santé et dégâts

- **Santé** : 100. **Armure** : 0 à 50 points selon l'équipement, absorbe les dégâts en premier.
- Pas de régénération naturelle : bandages (lent) et injecteurs (rapide) en consommables.
- **Coups à la tête** : ×1,5 pour les armes à distance.
- **Temps pour tuer visé** : 1 à 1,5 s entre joueurs bien équipés à moyenne distance.
  Assez court pour récompenser la précision, assez long pour pouvoir réagir.
- **Joueur à terre** : à 0 santé, le joueur rampe pendant 20 s ; il peut être réanimé ou achevé.

## 4. Armes de la vertical slice

| Arme | Type | Source | Rôle |
|---|---|---|---|
| **Pistolet de Fractureur** | Distance, semi-auto | Équipement de base | Polyvalent, précis |
| **Lame courte** | Mêlée, rapide | Équipement de base | Finition, discrétion |
| **Fusil à répétition** | Distance, longue portée | Fabriqué au Refuge | Contrôle à distance |
| **Arbalète lourde** | Distance, lente, perforante | Butin médiéval | Très gros dégâts, recharge longue |
| **Épée longue** | Mêlée lourde | Butin médiéval | Coups chargés, parade |

## 5. Mêlée

- Attaque légère (enchaînement de 3) et **attaque chargée** (maintien).
- **Parade** : fenêtre de 0,25 s qui renvoie le coup et étourdit brièvement l'attaquant.
  C'est la mécanique de skill principale au corps à corps.
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
