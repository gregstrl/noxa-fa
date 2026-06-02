-- =====================================================================
--  NOXA FA — Gestionnaire des joueurs (registre + cycle de vie)
--  • Registre central des objets Player chargés
--  • Connexion : vérification ban, chargement compte
--  • Déconnexion : sauvegarde + nettoyage
--  • Sauvegarde périodique automatique
-- =====================================================================

Noxa = Noxa or {}
Noxa.Players = {}

local M      = Noxa.Players
local U      = Noxa.Utils
local DB     = Noxa.DB
local CFG    = Noxa.Config
local Player = Noxa.PlayerClass

-- Registre : [source] = Player
local registry = {}

-- ---------------------------------------------------------------------
--  Accès au registre
-- ---------------------------------------------------------------------

---@param src integer
---@return Player|nil
function M.get(src)
    return registry[src]
end

---@param citizenid string
---@return Player|nil
function M.getByCitizenId(citizenid)
    for _, ply in pairs(registry) do
        if ply.citizenid == citizenid then return ply end
    end
    return nil
end

function M.getAll()
    return registry
end

function M.count()
    local n = 0
    for _ in pairs(registry) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------
--  Chargement / déchargement d'un personnage
-- ---------------------------------------------------------------------

--- Instancie et enregistre un Player à partir d'un personnage possédé.
---@param src integer
---@param row table ligne noxa_characters
---@param account table ligne noxa_accounts
---@return Player
function M.load(src, row, account)
    local ply = Player.new(src, row, account)
    registry[src] = ply
    ply:syncState()
    DB.log('join', 'info', account.license,
        ('%s a chargé %s (%s)'):format(GetPlayerName(src) or '??', ply:getName(), ply.citizenid))
    U.print('info', '%s connecté en tant que %s', GetPlayerName(src) or '??', ply:getName())
    TriggerEvent('noxa:playerLoaded', src, ply)
    return ply
end

--- Sauvegarde et retire un joueur du registre.
function M.unload(src)
    local ply = registry[src]
    if not ply then return end
    ply.source = src
    ply:save()
    registry[src] = nil
    TriggerEvent('noxa:playerUnloaded', src, ply.citizenid)
end

-- ---------------------------------------------------------------------
--  Connexion : vérification du compte & des bans (deferral)
-- ---------------------------------------------------------------------

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('[Noxa FA] Vérification du compte de %s...'):format(name))

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        return deferrals.done('[Noxa FA] Impossible de récupérer votre identifiant Rockstar.')
    end

    local account = DB.ensureAccount(license, name)
    if not account then
        return deferrals.done('[Noxa FA] Erreur de connexion à la base de données. Réessayez.')
    end

    -- Vérification du bannissement
    if account.banned == 1 then
        local expire = account.ban_expire
        if not expire or expire > os.time() then
            local msg = account.ban_reason or 'Comportement contraire au règlement.'
            DB.log('security', 'warn', license, 'Connexion refusée: compte banni')
            return deferrals.done(('[Noxa FA] Vous êtes banni.\nRaison : %s'):format(msg))
        end
        -- Ban expiré : on le lève automatiquement
        MySQL.update('UPDATE noxa_accounts SET banned = 0, ban_reason = NULL, ban_expire = NULL WHERE id = ?',
            { account.id })
    end

    deferrals.done()
end)

-- ---------------------------------------------------------------------
--  Déconnexion : sauvegarde
-- ---------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src = source
    if registry[src] then
        M.unload(src)
        U.print('info', 'Joueur %s déconnecté, sauvegarde effectuée.', src)
    end
end)

-- ---------------------------------------------------------------------
--  Sauvegarde périodique automatique
-- ---------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(CFG.Save.interval)
        local saved = 0
        for _, ply in pairs(registry) do
            ply:save()
            saved = saved + 1
        end
        if saved > 0 then
            U.print('info', 'Sauvegarde auto : %d joueur(s).', saved)
        end
    end
end)

-- Sauvegarde de sécurité à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ply in pairs(registry) do
        ply:save()
    end
end)

return M
