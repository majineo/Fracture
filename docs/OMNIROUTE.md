# OmniRoute : ce qui est installé et ce qu'il te reste à faire

> Outil personnel, hors du jeu. Installé le 2026-11-07 à ta demande.

## Ce qui est fait

- **Node.js 26.13.0 (LTS)** : version portable officielle (nodejs.org, empreinte SHA-256 vérifiée),
  dans `%LOCALAPPDATA%\Programs\node-v26.13.0-win-x64`, ajoutée au PATH de ton compte (pas de
  droits administrateur : l'installateur winget attendait une confirmation que je n'ai pas validée
  à ta place).
- **OmniRoute 3.8.53** : `npm install -g omniroute`.
- **Sécurité** : OmniRoute écoute par défaut sur tout le réseau, sans clé (n'importe quel appareil
  du Wi-Fi pourrait s'en servir et dépenser tes accès). Il est restreint à ce PC :
  variable d'environnement `OMNIROUTE_SERVER_HOST=127.0.0.1` (compte utilisateur).
- **Plugin Claude Code « omniroute »** : déclaré dans `%USERPROFILE%\.claude\settings.json`.
- Lancé dans l'onglet de terminal « OmniRoute » (Ctrl + C pour l'arrêter ; relancer : `omniroute`).

## Ce qu'il te reste à faire (toi seul : comptes et clés)

1. Ouvre le tableau de bord : <http://localhost:20128>.
2. Ajoute les fournisseurs gratuits que tu veux (chacun demande son propre compte et sa clé ;
   lis leurs conditions — OmniRoute marque certains « à éviter »).
3. Le serveur MCP (`/api/mcp/stream`) demande un jeton : crée-le dans le tableau de bord, puis
   ajoute-le au plugin (en-tête `Authorization: Bearer <jeton>`). Je ne crée ni comptes ni clés
   à ta place.
4. Redémarre Claude Code pour que le plugin se charge.

## À savoir

- OmniRoute ne rallonge pas mon quota Claude : il permet d'utiliser **d'autres** IA (souvent moins
  fortes pour un projet comme FRACTURE). Je continue de travailler normalement sans lui.
- Ne fais pas passer Claude Code lui-même par OmniRoute sans en parler : la qualité du travail
  dépendrait alors de modèles gratuits.
- Désinstaller : `npm uninstall -g omniroute`, supprimer le dossier Node.js ci-dessus, retirer
  `omniroute` de `%USERPROFILE%\.claude\settings.json`.
