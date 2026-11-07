# 04 — Progression

> Statut : 📋 Prévu. Principe : la progression ajoute des **options**, pas de la puissance brute.

## 1. Vue d'ensemble

| Couche | Perdable à la mort ? | Comment on progresse | Ce que ça donne |
|---|---|---|---|
| **Codex** | Non | Stabiliser des reliques extraites | Capacités équipables |
| **Maîtrise d'armes** | Non | Utiliser une catégorie d'armes | Techniques, accessoires, apparences |
| **Rang de Fractureur** | Non | XP de partie (surtout les extractions) | Accès aux Éclats, recettes, spécialisations |
| **Spécialisations** 💭 | Non | Débloquées par le rang | Style de jeu |
| **Réputation** 💭 | Non | Contrats de faction | Recettes, Éclats rares |
| **Équipement et butin** | **Oui, en totalité** | Butin, fabrication | Puissance modérée et temporaire |

D-007 et D-012 : seuls l'équipement emporté et le butin se perdent.

## 2. Le Codex

- Une relique extraite intacte (3 charges) peut être **stabilisée** au Refuge contre des Grains
  et un matériau d'époque.
- Elle devient une **capacité permanente**, utilisable à chaque partie sans risque de perte.
- On n'équipe que **2 capacités** à la fois : un vétéran a plus de choix, pas plus de puissance.
- Chaque capacité a **3 niveaux** : stabiliser plusieurs fois la même relique débloque une
  variante (pas seulement plus de dégâts).

✅ v0.7.1 (`Shared/Loot/Codex`, testé) : stabilisation au coffre du Refuge contre **60 Grains +
1 Acier ancien** (relique intacte consommée, niveau +1, 3 au plus) ; 2 capacités équipées ;
dans l'Éclat, **2 utilisations par vie** (3 dès le niveau 2), touches V et B (R1 / Select à la
manette, ou toucher la pastille). Les variantes de niveau 3 restent à faire.

### Reliques de la vertical slice

| Relique | Effet | Variante niveau 3 |
|---|---|---|
| **Pas de Faille** | Dash de 15 studs qui traverse les projectiles | Laisse un écho qui distrait les Échoués |
| **Stase** | Gèle une petite zone pendant 2 s (projectiles et ennemis ralentis) | La zone devient un mur temporaire |
| **Onde de choc** | Frappe au sol qui repousse et étourdit dans 10 studs | Projette le lanceur vers le haut |

## 3. Maîtrise d'armes

- Par **catégorie** (pistolets, fusils, arbalètes, lames, armes lourdes), pas par arme précise :
  la maîtrise survit à la perte d'une arme.
- Les paliers débloquent des **techniques** (ex. annuler un rechargement par une glissade,
  enchaîner une parade sur une attaque chargée), des **recettes d'accessoires** et des
  apparences. Aucun bonus de dégâts brut.

## 4. Rang de Fractureur

- XP gagnée à chaque partie, fortement majorée par une extraction réussie.
- Ne donne aucune statistique : il débloque des types d'Éclats, des recettes et les spécialisations.
- Vertical slice : rangs 1 à 10.

## 5. Spécialisations 💭

Débloquées au rang 10, une seule active, changeable au Refuge.

| Spécialisation | Style | Passif (exemple) |
|---|---|---|
| **Éclaireur** | Mobilité, repérage | Signature réduite, grappin rechargé plus vite |
| **Briseur** | Mêlée, armure | Parade plus large, armure lourde sans pénalité |
| **Tisseur temporel** | Capacités | Un 3e emplacement de capacité, armes plus faibles |

## 6. Ce qui fait la différence entre les joueurs

1. **Le skill** : visée, parade, déplacement, connaissance des Éclats.
2. **Le Codex** : la diversité des capacités et des variantes maîtrisées.
3. **L'équipement** : temporaire, plafonné à environ +20 % d'efficacité par rapport à la base.
4. **L'apparence** : cosmétiques de maîtrise, trophées de Gardien.
