--!strict
-- Types qui traversent la frontière client/serveur.
-- Studio : ReplicatedStorage > Shared > Types

-- Type de place : chaque fichier de projet Rojo (places/*.project.json) fournit Shared.PlaceKind.
export type PlaceKind = "Refuge" | "Eclat"

-- Vue publique du profil envoyée au joueur propriétaire (jamais le profil brut).
export type ProfileSnapshot = {
	rank: number,
	xp: number,
	grains: number,
	codex: { [string]: number },
	mastery: { [string]: number },
	stashCount: number,
}

return nil
