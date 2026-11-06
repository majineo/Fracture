# Suivi des modèles 3D et assets

> Aucun modèle n'existe encore. Chaque asset passe par les étapes ci-dessous.

**Étapes** : 💭 À concevoir → 📋 À créer (Blender) → 🔧 En création → 📦 À intégrer (Studio) → ✅ Intégré

## Normes techniques pour Blender → Roblox

- **Échelle** : 1 stud = 0,28 m. Régler l'échelle d'unités de la scène Blender en conséquence.
- **Budget** : 20 000 triangles maximum par MeshPart (viser beaucoup moins pour les décors répétés).
- **Textures** : 1024 px maximum (Roblox réduit au-delà), PBR via SurfaceAppearance
  (couleur, normale, rugosité, métal).
- **Modularité** : décors en kits sur une grille fixe (8 studs à confirmer) pour les tuiles d'Éclat.
- **Fichiers** : sources `.blend` dans `assets/blender/`, textures dans `assets/textures/`.
- Les effets (désintégration, particules) se font dans Roblox, pas dans Blender.

## Liste des assets

| Asset | Catégorie | Statut | Notes |
|---|---|---|---|
| Reliques (3 pour le prototype) | Objets | 💭 | Bon premier modèle pour valider le pipeline |
| Kit de tuiles de la première époque | Décors | 💭 | Époque à choisir |
| Échoués (2 types) | Créatures | 💭 | Rig et animations nécessaires |
| Gardien d'Éclat | Boss | 💭 | Le plus coûteux du prototype |
| Armes (3) | Équipement | 💭 | |
| Grappin | Équipement | 💭 | |
