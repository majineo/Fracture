# Règles de versionnement

## Numérotation `vMAJEUR.MINEUR.CORRECTIF`

| Partie | Quand l'incrémenter | Exemple |
|---|---|---|
| **MAJEUR** | Étape majeure du jeu. `v1.0.0` = première version publique jouable. | v1.0.0 |
| **MINEUR** | Nouveau système ou nouvelle mise à jour de contenu nommée. | v0.3.0 « Combat » |
| **CORRECTIF** | Corrections, équilibrage, documentation, petits ajustements. | v0.3.1 |

Tant que le jeu est en `0.x`, tout peut encore changer, y compris les fondations.

## Pour chaque version

1. Une entrée dans [CHANGELOG.md](../CHANGELOG.md) avec les 10 rubriques :
   numéro, date, nom, description, nouveautés, modifications, corrections,
   problèmes connus, fichiers ajoutés/modifiés/supprimés, prochaines étapes.
2. `Config.GAME_VERSION` mis à jour dans `src/shared/Config.luau`.
3. Un commit de version, puis un **tag Git annoté** `vX.Y.Z`.
4. Envoi sur GitHub (commits + tags).

## Règles

- Une ancienne version n'est jamais réécrite : on corrige par une nouvelle version.
- Pas de `git push --force` sur `main`.
- Les décisions importantes sont consignées dans [DECISIONS.md](DECISIONS.md).
- Le GDD, le code et le changelog doivent rester cohérents entre eux.

## Statuts utilisés dans la documentation

- ✅ **Implémenté** : présent dans le code et testé.
- 🔧 **En cours** : développement commencé.
- 📋 **Prévu** : validé, pas encore commencé.
- 💭 **À l'étude** : idée non validée.
