# Journal des décisions

Chaque décision importante est consignée ici avec sa raison, pour pouvoir y revenir.
Une décision n'est jamais effacée : si elle change, on ajoute une nouvelle entrée qui la remplace.

---

## D-001 — Concept retenu : FRACTURE (extraction PvPvE)
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée
- **Choix** : parmi cinq concepts (Vélocité, Fracture, Écho, Colosses, Symbiose), le concept
  B « Fracture » est retenu.
- **Raisons** : forte rejouabilité (Éclats procéduraux), tension risque/récompense, multijoueur
  riche (escouades, alliances, trahisons), évolution sur plusieurs années, production basée sur
  des kits modulaires compatibles avec un travail Blender en petite équipe.
- **Idées conservées des autres concepts** : le déplacement riche de *Vélocité* (glissade,
  escalade, grappin) est intégré au combat.

## D-002 — Univers : les Éclats temporels
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée
- **Choix** : le temps s'est brisé ; chaque Éclat est le fragment instable d'une époque.
- **Raisons** : justifie le mélange armes à feu, mêlée et pouvoirs ; variété visuelle
  illimitée (une époque par mise à jour) ; identité distinctive sur Roblox.
- **Alternatives écartées** : Rêves fracturés (moins lisible, plus coûteux), Ciel brisé (moins distinctif).

## D-003 — Boucle de partie validée
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Validée (à confirmer en test)
- **Choix** : Refuge → Éclat de 12 à 18 min (exploration → effondrement → Faille finale) → extraction.
- **Note** : la durée sera ajustée lors des tests du prototype.

## D-004 — Univers Roblox multi-places
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : 📋 Décidée, pas encore implémentée
- **Choix** : une place Refuge (hub) et une ou plusieurs places d'Éclats, reliées par
  TeleportService ; matchmaking via MemoryStoreService ; serveurs réservés pour les Éclats.
- **Raisons** : nécessaire pour des parties de 16 à 24 joueurs isolées du hub. Changer ce
  choix plus tard obligerait à reconstruire l'architecture.

## D-005 — Code source synchronisé par Rojo
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ✅ Implémentée
- **Choix** : le code vit dans des fichiers `.luau` versionnés par Git et synchronisés dans Studio
  par Rojo. Outils figés par Rokit. Luau en mode `--!strict`.
- **Raisons** : historique Git complet, revue de code, CI, pas de code perdu dans un fichier de place.

## D-006 — Progression : permanente contre risquée
- **Date** : 2026-11-06 · **Version** : v0.1.0 · **Statut** : ⛔ Remplacée par D-007
- **Proposition** : capacités du Codex, maîtrise d'armes, spécialisations et réputation sont
  permanentes ; seuls le butin transporté et l'équipement emporté se perdent à la mort.
  Emplacement d'Ancre protégé, équipement de base toujours gratuit, écarts de stats plafonnés (~+20 %).

---

## D-007 — Perte totale à la mort
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée (remplace D-006)
- **Choix** : un joueur qui meurt dans un Éclat perd **tout** son butin et tout l'équipement
  emporté. Il repart avec l'**équipement de base** gratuit. Pas d'emplacement d'Ancre.
- **Toujours permanent** : Codex, maîtrise d'armes, spécialisations, réputation (confirmé en D-012).
- **Risque assumé** : frustration plus forte pour un public jeune. Mesures prévues : équipement
  de base réellement viable, Éclats calmes pour reconstruire un stock, mesure du taux d'abandon
  après une mort lors des tests.

## D-008 — PvP dans les Éclats à haut risque
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Choix** : PvP obligatoire dans les Éclats à haut risque ; Éclats calmes sans PvP conservés
  pour les joueurs solo et occasionnels.

## D-009 — Mobile prioritaire
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Conséquences** : contrôles tactiles pensés dès le premier système (pas ajoutés après coup),
  assistance à la visée sur mobile, interface lisible sur petit écran, budgets de performance
  calibrés pour des téléphones d'entrée de gamme.

## D-010 — Première époque : forteresse médiévale
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Validée
- **Choix** : la vertical slice se déroule dans un Éclat de forteresse médiévale.
- **Intérêt** : formes simples à modéliser (pierre, bois), bon premier projet Blender ;
  contraste fort avec les armes à feu des Fractureurs.

## D-011 — Contexte de production : développeur solo débutant
- **Date** : 2026-11-06 · **Version** : v0.1.1 · **Statut** : ✅ Constat
- **Contexte** : un seul développeur, à temps plein, sans expérience de Luau ni de Blender.
- **Conséquences** :
  - Claude écrit et explique le code ; chaque système est accompagné d'une explication et
    de tests à faire dans Studio, pour que l'apprentissage se fasse en avançant.
  - Apprentissage de Blender progressif, du plus simple au plus complexe : reliques → armes
    → kit de tuiles → créatures riggées → Gardien.
  - La vertical slice est la priorité absolue ; aucun contenu supplémentaire avant qu'elle
    soit amusante.

## D-012 — Progression permanente confirmée
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : ✅ Validée
- **Choix** : le Codex, la maîtrise d'armes, le rang, les spécialisations et la réputation ne
  sont jamais perdus à la mort. Seuls le butin et l'équipement emporté le sont (D-007).

## D-013 — Méthode de travail
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : ✅ Validée
- **Choix** : Claude prend les décisions techniques et de détail de façon autonome et les
  documente ; explications courtes. Les décisions de direction (concept, règles majeures,
  actions irréversibles ou publiques) restent soumises à validation.

## D-014 — Game Design Document v1
- **Date** : 2026-11-06 · **Version** : v0.1.2 · **Statut** : 📋 En attente de validation
- **Choix** : GDD rédigé dans `docs/GDD/` (11 sections). Décisions de détail notables :
  Éclat de 5 × 5 tuiles de 64 studs, parties de 16 min, extraction en 8 s, 12 emplacements de
  butin, reliques à 3 charges (« utiliser ou ramener »), 2 capacités équipées, pas d'usure des
  objets, pas d'échange entre joueurs dans la vertical slice, monétisation uniquement cosmétique.

## D-015 — Couche de données maison plutôt que la bibliothèque ProfileStore
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée
- **Choix** : verrou de session, migrations et sauvegardes écrits dans le projet
  (`SessionLock`, `ProfileSchema`, `PlayerData`) au lieu d'utiliser ProfileStore.
- **Raisons** : l'extraction et le passage Refuge ↔ Éclat exigent un contrôle exact du verrou
  et des transactions ; la logique critique est en modules purs, couverte par des tests
  automatiques, sans dépendance externe.
- **Revoir si** : des pertes ou duplications apparaissent en test réel ; ProfileStore reste
  l'alternative de référence.

## D-016 — Tests unitaires hors Studio avec Lune
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée
- **Choix** : la logique critique est écrite en modules purs testés par Lune, localement et
  dans la CI GitHub. Les comportements liés à Roblox sont testés en playtest dans Studio.

## D-017 — Deux places, code partagé
- **Date** : 2026-11-06 · **Version** : v0.2.0 · **Statut** : ✅ Implémentée (applique D-004)
- **Choix** : un fichier de projet Rojo par place (`places/*.project.json`) ; code commun dans
  `Core`, code propre dans `Refuge` / `Eclat` ; un seul Script serveur et un seul LocalScript.

## D-018 — Sprint en bascule sur mobile et manette
- **Date** : 2026-11-06 · **Version** : v0.3.0 · **Statut** : ✅ Implémentée (modifie le GDD 03)
- **Choix** : sur mobile et manette, le sprint est un bouton à bascule au lieu d'un sprint
  automatique en poussant le joystick au bord.
- **Raison** : Roblox ne fournit pas de façon fiable l'intensité du joystick tactile ; la
  bascule est prévisible et se désactive d'elle-même quand l'endurance est vide.

## D-019 — Déplacement simulé par le client, borné par le serveur
- **Date** : 2026-11-06 · **Version** : v0.3.0 · **Statut** : ✅ Implémentée
- **Choix** : glissade, escalade et grappin sont simulés localement (réactivité, surtout sur
  mobile). Le serveur échantillonne les positions toutes les 0,2 s et ramène en arrière tout
  déplacement impossible (3 anomalies sur 1 s). Les mouvements rapides légitimes (grappin)
  ne sont autorisés qu'après validation serveur. Aucun bannissement automatique.

## D-020 — Outils de test réservés à Studio
- **Date** : 2026-11-06 · **Version** : v0.3.0 · **Statut** : ✅ Implémentée
- **Choix** : un remote `DevCommand` n'est écouté que si `RunService:IsStudio()`. Il permet
  par exemple de téléporter son personnage sans déclencher la garde de mouvement.

## D-021 — Cartes de test versionnées en fichiers `.model.json`
- **Date** : 2026-11-06 · **Version** : v0.3.0 · **Statut** : ✅ Implémentée
- **Choix** : les décors de test (greybox) vivent dans `maps/` et sont synchronisés par Rojo.
  Les positions sont toujours données par la propriété `CFrame` (format explicite) :
  `Position` n'est pas appliquée de façon fiable par Rojo (bug constaté en test).

## D-022 — Animations procédurales plutôt qu'importées (pour l'instant)
- **Date** : 2026-11-06 · **Version** : v0.3.1 · **Statut** : ✅ Implémentée
- **Choix** : les animations de mouvement sont générées par le code (poses mélangées par
  ressorts par-dessus les animations Roblox), sur les deux systèmes d'articulations Roblox
  (Motor6D et AnimationConstraint). Le mode de chaque joueur est répliqué par le serveur
  (attribut `MoveMode`) pour que tous voient les mêmes animations.
- **Raisons** : fonctionnent immédiatement (pas d'import ni de publication d'animation), se
  règlent dans un seul fichier (`Animation/Poses.luau`), s'adaptent à la situation (bras
  pointé vers la cible du grappin, poids de la réception selon la hauteur de chute).
- **Plus tard** : des animations faites main (Blender ou Moon Animator) pourront remplacer
  certaines poses sans changer le reste.

## D-023 — Ressenti : tout passe par des ressorts
- **Date** : 2026-11-06 · **Version** : v0.3.1 · **Statut** : ✅ Implémentée
- **Choix** : vitesse, champ de vision, inclinaison de caméra et poids des animations suivent
  des ressorts amortis (`Shared/Util/Spring`), jamais des changements instantanés.
- **Mesure** : plus gros à-coup de vitesse entre deux images ≤ 1 stud/s hors impulsions
  volontaires (départ de glissade).

## D-024 — Touches jugées par le serveur avec compensation de latence
- **Date** : 2026-11-06 · **Version** : v0.4.0 · **Statut** : ✅ Implémentée
- **Choix** : le client envoie origine, direction et heure du tir ; le serveur remonte les
  cibles dans le temps (historique de 1 s, au plus 0,4 s en arrière, moins la latence du
  tireur) et teste le rayon contre des zones simplifiées (sphère de tête, boîte de corps,
  +0,5 stud de tolérance). Le décor arrête le tir.
- **Mesure** : 8 touches sur 10 sur une cible à 12 studs/s avec 200 ms de latence simulée.
- **Limite connue** : un tricheur peut toujours viser automatiquement (impossible à prouver
  côté serveur) ; il ne peut pas tirer plus vite, plus loin, à travers les murs, ni choisir
  ses dégâts.

## D-025 — Pas de dégâts entre joueurs au Refuge
- **Date** : 2026-11-06 · **Version** : v0.4.0 · **Statut** : ✅ Implémentée
- **Choix** : le PvP n'existe que dans la place Éclat. Au Refuge, seules les cibles
  d'entraînement peuvent être touchées.

## D-026 — Équipement de base : 5 balles pour tuer
- **Date** : 2026-11-06 · **Version** : v0.4.0 · **Statut** : 💭 À valider en test
- **Choix** : pistolet 24 dégâts (×1,5 à la tête), 5 tirs/s, 12 balles ; lame 30 (54 chargée).
  Un joueur en équipement de base (100 PV + 15 d'armure) tombe en 5 balles au corps (0,8 s)
  ou 4 à la tête. Avec de meilleures armures (v0.6), on visera 1 à 1,5 s (GDD 03).

## D-027 — Armes provisoires remplaçables par des modèles Blender
- **Date** : 2026-11-06 · **Version** : v0.4.0 · **Statut** : ✅ Implémentée
- **Choix** : les armes tenues sont des formes simples créées par le code. Un modèle placé
  dans `ServerStorage > WeaponModels` avec le nom de l'arme (et une pièce « Grip ») les
  remplace automatiquement, sans changer le code.

## D-028 — Caméra de combat faite maison (PC)
- **Date** : 2026-11-06 · **Version** : v0.4.1 · **Statut** : ✅ Implémentée (remplace le verrou forcé de v0.4.0)
- **Constat** : forcer la souris au centre à chaque image empêchait la rotation au clic droit,
  même arme rangée ; et le module caméra Roblox (`PlayerModule`) n'est plus accessible aux
  scripts, donc pas de verrouillage officiel possible.
- **Choix** : arme en main sur PC, caméra d'épaule maison (souris verrouillée, mouvements de
  souris = rotation, évitement des murs). Arme rangée : caméra Roblox intacte. Mobile et
  manette : caméra Roblox.

## D-029 — Tout objet 3D est modélisé dans Blender
- **Date** : 2026-11-06 · **Version** : v0.4.1 · **Statut** : ✅ Règle de travail (inscrite dans `CLAUDE.md`)
- **Choix** : dès qu'un objet 3D est nécessaire (arme, décor, objet, créature), il est
  modélisé dans Blender sans attendre la demande ; les formes faites en code ne sont que
  provisoires. Une pièce par matériau, 1 unité = 1 stud, sources dans `assets/blender/`.

## D-030 — Arbalète : tir instantané perforant (pas encore de projectile)
- **Date** : 2026-11-06 · **Version** : v0.4.3 · **Statut** : ✅ Implémentée (💭 projectile réel à étudier)
- **Choix** : l'arbalète tire comme les armes à feu (jugée instantanément par le serveur), mais
  son carreau traverse une première cible (70 % des dégâts sur la suivante).
- **Raison** : un vrai projectile (temps de vol, chute) demande une simulation serveur avec
  compensation de latence dédiée. À reconsidérer si l'arbalète manque de caractère en test.

## D-031 — Parade : jugée par le serveur, valable contre la mêlée
- **Date** : 2026-11-06 · **Version** : v0.4.3 · **Statut** : ✅ Implémentée
- **Choix** : clic droit / LT / bouton « Parer » avec une arme de mêlée. Fenêtre 0,22 s (lame
  courte) ou 0,3 s (épée longue), recharge 0,75 s, coup venant de face (75°). Coup paré =
  aucun dégât et attaquant étourdi 0,9 s. Les tirs ne se parent pas.

## D-032 — Armurerie provisoire au Refuge
- **Date** : 2026-11-06 · **Version** : v0.4.3 · **Statut** : ✅ Implémentée (provisoire)
- **Choix** : présentoirs pour choisir son arme à feu et son arme de mêlée, en attendant
  l'inventaire et la fabrication (v0.6). Charge conservée d'une vie à l'autre, pas sauvegardée.

## D-033 — Boutons tactiles faits maison
- **Date** : 2026-11-06 · **Version** : v0.4.3 · **Statut** : ✅ Implémentée
- **Choix** : les boutons automatiques de Roblox (empilés, non configurables) sont remplacés
  par une interface tactile disposée autour du pouce droit, qui s'adapte à l'arme en main.

## D-034 — Les ennemis peuvent toujours blesser les joueurs
- **Date** : 2026-11-06 · **Version** : v0.4.3 · **Statut** : ✅ Implémentée
- **Choix** : la règle « pas de PvP au Refuge » ne concerne que les attaques entre joueurs ;
  une attaque sans joueur attaquant (ennemi, mannequin de test) blesse partout.