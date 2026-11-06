--!strict
-- Système de données joueur : chargement, sauvegarde et verrou de session.
-- Studio : ServerScriptService > Server > Systems > PlayerData
--
-- Cycle de vie :
--   Connexion  -> revendication du verrou + chargement (réessais si un autre serveur le détient)
--   En jeu     -> le profil en mémoire est la seule source de vérité ; le jeu le modifie via
--                 PlayerData.get(player). Personne d'autre ne touche aux DataStores.
--   Toutes les 60 s (décalé par joueur) -> sauvegarde + rafraîchissement du verrou
--   Départ     -> sauvegarde finale + libération du verrou
--   Arrêt du serveur (BindToClose) -> sauvegarde finale de TOUS les joueurs
--
-- Sécurité :
--   * Échec de chargement => le joueur est expulsé avec un message. On ne le laisse JAMAIS
--     jouer avec un profil vide (sa prochaine sauvegarde écraserait ses vraies données).
--   * Verrou perdu => on n'écrit plus rien et le joueur est expulsé (un autre serveur possède
--     ses données).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Lib = script.Parent.Parent.Lib
local DataConfig = require(Lib.DataConfig)
local ProfileSchema = require(Lib.ProfileSchema)
local ProfileStore = require(Lib.ProfileStore)
local Retry = require(Lib.Retry)
local SessionLock = require(Lib.SessionLock)

type ProfileData = ProfileSchema.ProfileData

type Session = {
	player: Player,
	key: string,
	data: ProfileData,
	saving: boolean,
	nextSave: number,
}

local MESSAGES = table.freeze({
	LOAD_FAILED = "Impossible de charger tes données pour le moment. Reviens dans quelques instants.",
	LOCKED = "Tes données sont encore en cours de sauvegarde sur un autre serveur. Reviens dans un instant.",
	INCOMPATIBLE = "Une mise à jour du jeu est en cours. Reviens dans quelques minutes.",
	CORRUPT = "Un problème a été détecté avec tes données. Elles n'ont pas été modifiées. Contacte le support.",
	LOCK_LOST = "Ta session a été ouverte sur un autre serveur.",
	SHUTTING_DOWN = "Le serveur redémarre. Reviens dans un instant.",
})

-- Identifiant de ce serveur pour le verrou. Vide dans Studio : on en génère un.
local JOB_ID = if game.JobId ~= "" then game.JobId else `studio-{math.random(1, 1e9)}`

local PlayerData = {}

-- Déclenché quand le profil d'un joueur est prêt : (player, data).
PlayerData.ProfileLoaded = Signal.new() :: Signal.Signal<Player, ProfileData>
-- Déclenché juste avant la sauvegarde finale d'un joueur qui part : (player, data).
-- Les écouteurs peuvent encore modifier `data` (ex. dans un Éclat : quitter = mourir), mais
-- ne doivent JAMAIS attendre (task.wait, appels réseau) : la sauvegarde suit immédiatement.
PlayerData.ProfileReleasing = Signal.new() :: Signal.Signal<Player, ProfileData>

local store: ProfileStore.Store? = nil
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local pendingWrites = 0
local shuttingDown = false

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

local function kick(player: Player, message: string)
	if player.Parent ~= nil then
		player:Kick(message)
	end
end

local function callStore(key: string, transform: (any) -> any): boolean
	local activeStore = store
	if activeStore == nil then
		return false
	end
	local ok = Retry.run(
		DataConfig.CALL_ATTEMPTS,
		DataConfig.CALL_BASE_DELAY,
		DataConfig.CALL_MAX_DELAY,
		task.wait,
		function()
			activeStore.update(key, transform)
		end,
		function(attempt: number, err: string)
			warn(
				`[PlayerData] {key} : tentative {attempt}/{DataConfig.CALL_ATTEMPTS} échouée : {err}`
			)
		end
	)
	return ok
end

-- Une tentative de revendication. Renvoie (appel réussi, résultat, données).
local function tryClaim(key: string): (boolean, SessionLock.ClaimOutcome?, ProfileData?)
	local outcome: SessionLock.ClaimOutcome? = nil
	local data: ProfileData? = nil
	local ok = callStore(key, function(stored: any)
		-- UpdateAsync peut rappeler la transformation : on repart de zéro à chaque appel.
		local record, claimOutcome, claimedData =
			SessionLock.claim(stored, JOB_ID, os.time(), DataConfig.LOCK_STALE_AFTER, ProfileSchema)
		outcome = claimOutcome
		data = claimedData
		return record
	end)
	if not ok then
		return false, nil, nil
	end
	return true, outcome, data
end

-- Écrit les données d'une session. `release` libère le verrou.
local function writeSession(session: Session, release: boolean): SessionLock.SaveOutcome?
	-- Une seule écriture à la fois par joueur.
	while session.saving do
		task.wait(0.1)
	end
	session.saving = true
	pendingWrites += 1

	-- Données non stockables (bug de gameplay) : on garde la dernière version valide déjà
	-- enregistrée, mais on continue à gérer le verrou (rafraîchir ou libérer) pour ne pas
	-- bloquer le joueur.
	local valid, problem = ProfileSchema.validate(session.data)
	if not valid then
		warn(
			`[PlayerData] {session.key} : données non stockables ({problem}) — dernière sauvegarde valide conservée`
		)
	end

	local outcome: SessionLock.SaveOutcome? = nil
	local ok = callStore(session.key, function(stored: any)
		local payload = if valid
			then session.data
			elseif typeof(stored) == "table" then stored.data
			else nil
		if payload == nil then
			return nil
		end
		local record, saveOutcome = SessionLock.save(stored, JOB_ID, payload, os.time(), release)
		outcome = saveOutcome
		return record
	end)

	pendingWrites -= 1
	session.saving = false

	if not ok then
		warn(`[PlayerData] sauvegarde de {session.key} impossible après plusieurs tentatives`)
		return nil
	end
	if outcome == "LockLost" then
		warn(`[PlayerData] verrou perdu pour {session.key} : aucune écriture effectuée`)
		if sessions[session.player] == session then
			sessions[session.player] = nil
		end
		kick(session.player, MESSAGES.LOCK_LOST)
	end
	return outcome
end

local function releasePlayer(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	PlayerData.ProfileReleasing:Fire(player, session.data)
	writeSession(session, true)
end

-- Libère un profil revendiqué pour un joueur parti pendant le chargement.
local function releaseOrphan(player: Player, key: string, data: ProfileData)
	local orphan: Session =
		{ player = player, key = key, data = data, saving = false, nextSave = math.huge }
	writeSession(orphan, true)
end

local function loadPlayer(player: Player)
	if loading[player] or sessions[player] then
		return
	end
	if shuttingDown then
		kick(player, MESSAGES.SHUTTING_DOWN)
		return
	end
	if store == nil then
		kick(player, MESSAGES.LOAD_FAILED)
		return
	end

	loading[player] = true
	local key = keyFor(player)
	local resolved = false

	for _ = 1, DataConfig.LOCK_WAIT_ATTEMPTS do
		if player.Parent == nil then
			resolved = true
			break
		end

		local ok, outcome, data = tryClaim(key)
		if not ok then
			kick(player, MESSAGES.LOAD_FAILED)
			resolved = true
			break
		end

		if (outcome == "Created" or outcome == "Claimed") and data ~= nil then
			resolved = true
			if player.Parent == nil or shuttingDown then
				-- Parti (ou arrêt du serveur) pendant le chargement : on rend le verrou.
				releaseOrphan(player, key, data)
				kick(player, MESSAGES.SHUTTING_DOWN)
				break
			end
			data.stats.sessions += 1
			local session: Session = {
				player = player,
				key = key,
				data = data,
				saving = false,
				-- Décalage par joueur pour ne pas sauvegarder tout le monde au même instant.
				nextSave = os.clock()
					+ DataConfig.AUTOSAVE_INTERVAL
					+ (player.UserId % DataConfig.AUTOSAVE_INTERVAL),
			}
			sessions[player] = session
			loading[player] = nil
			PlayerData.ProfileLoaded:Fire(player, data)
			return
		elseif outcome == "Locked" then
			task.wait(DataConfig.LOCK_WAIT_DELAY)
		elseif outcome == "Incompatible" then
			kick(player, MESSAGES.INCOMPATIBLE)
			resolved = true
			break
		else
			warn(`[PlayerData] données illisibles pour {key} : rien n'a été écrit`)
			kick(player, MESSAGES.CORRUPT)
			resolved = true
			break
		end
	end

	if not resolved then
		-- Toujours verrouillé par un autre serveur après toutes les tentatives.
		kick(player, MESSAGES.LOCKED)
	end
	loading[player] = nil
end

local function autosaveLoop()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, session in sessions do
			if now >= session.nextSave and not session.saving then
				session.nextSave = now + DataConfig.AUTOSAVE_INTERVAL
				task.spawn(writeSession, session, false)
			end
		end
	end
end

local function onShutdown()
	shuttingDown = true
	local players: { Player } = {}
	for player in sessions do
		table.insert(players, player)
	end
	for _, player in players do
		task.spawn(releasePlayer, player)
	end
	local deadline = os.clock() + DataConfig.SHUTDOWN_TIMEOUT
	while pendingWrites > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pendingWrites > 0 then
		warn(`[PlayerData] arrêt du serveur : {pendingWrites} sauvegarde(s) non terminée(s)`)
	end
end

-- API publique ------------------------------------------------------------------------

-- Profil en mémoire d'un joueur, ou nil s'il n'est pas (encore) chargé.
-- Les modifications faites sur cette table sont sauvegardées automatiquement.
function PlayerData.get(player: Player): ProfileData?
	local session = sessions[player]
	return if session then session.data else nil
end

function PlayerData.isLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- Type de stockage actif ("DataStore", "Memory" ou nil), pour les diagnostics.
function PlayerData.storeKind(): ProfileStore.StoreKind?
	return if store then store.kind else nil
end

-- Cycle de vie -------------------------------------------------------------------------

function PlayerData.init()
	store = ProfileStore.open()
	Players.PlayerRemoving:Connect(function(player)
		releasePlayer(player)
	end)
	game:BindToClose(onShutdown)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	if RunService:IsStudio() then
		print(`[PlayerData] prêt (stockage : {PlayerData.storeKind() or "AUCUN"})`)
	end
	autosaveLoop()
end

return PlayerData
