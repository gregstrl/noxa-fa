-- =====================================================================
--  NOXA FA — Couche de sécurité serveur
--  • Rate-limiting des events réseau (anti-spam / anti-flood)
--  • Wrapper d'enregistrement d'events sécurisé (validation source)
--  • Comptage de violations + auto-kick/ban
--  • Journalisation centralisée des incidents
-- =====================================================================

Noxa = Noxa or {}
Noxa.Security = {}

local S   = Noxa.Security
local U   = Noxa.Utils
local DB  = Noxa.DB
local CFG = Noxa.Config.Security

-- État par joueur : compteurs de rate-limit et violations
-- [src] = { events = { [name] = { count, reset } }, violations = n }
local state = {}

local function getState(src)
    local s = state[src]
    if not s then
        s = { events = {}, violations = 0 }
        state[src] = s
    end
    return s
end

AddEventHandler('playerDropped', function()
    state[source] = nil
end)

--- Enregistre une violation. Au-delà du seuil, le joueur est expulsé.
---@param src integer
---@param reason string
function S.flag(src, reason)
    local s = getState(src)
    s.violations = s.violations + 1
    local license = GetPlayerIdentifierByType(src, 'license')
    U.print('warn', 'Violation #%d de %s (src %s) : %s', s.violations,
        GetPlayerName(src) or '??', src, reason)
    DB.log('security', 'warn', license,
        ('Violation: %s'):format(reason), { src = src, count = s.violations })

    if s.violations >= CFG.autobanThreshold then
        DB.log('security', 'error', license, 'Auto-kick: seuil de violations atteint', { reason = reason })
        DropPlayer(src, CFG.kickMessage)
    end
end

--- Vérifie le rate-limit pour un event donné. Retourne false si dépassé.
---@param src integer
---@param eventName string
---@return boolean allowed
function S.checkRate(src, eventName)
    local rule = CFG.rateLimit[eventName] or CFG.rateLimit.default
    local s = getState(src)
    local now = GetGameTimer()
    local e = s.events[eventName]
    if not e or now > e.reset then
        s.events[eventName] = { count = 1, reset = now + rule.window }
        return true
    end
    e.count = e.count + 1
    if e.count > rule.count then
        return false
    end
    return true
end

--- Cooldown SOUPLE anti rapid-fire pour les actions sensibles (achats, ventes,
--- virements…). Contrairement au rate-limit anti-flood, un dépassement n'est PAS
--- compté comme violation : il ne déclenche donc aucun auto-kick (un double-clic
--- légitime ne sanctionne jamais le joueur, il est simplement ignoré + notifié).
--- Garantit un délai minimal `ms` (défaut 1000) entre deux appels d'une même clé.
---@param src integer
---@param key string
---@param ms? integer délai minimal en millisecondes (défaut 1000)
---@return boolean allowed
function S.cooldown(src, key, ms)
    ms = ms or 1000
    local s = getState(src)
    s.cooldowns = s.cooldowns or {}
    local now  = GetGameTimer()
    local last = s.cooldowns[key]
    if last and (now - last) < ms then
        TriggerClientEvent('noxa:notify', src, 'Patientez un court instant.', 'inform')
        return false
    end
    s.cooldowns[key] = now
    return true
end

--- Enregistre un event réseau sécurisé.
--- Applique rate-limit + exige que le joueur soit pleinement chargé (sauf opt-out).
--- Le handler reçoit (src, player, ...) où player est l'objet Player chargé.
---@param name string
---@param handler fun(src:integer, player:table, ...:any)
---@param opts? { requireLoaded?: boolean }
function S.onNet(name, handler, opts)
    opts = opts or {}
    local requireLoaded = opts.requireLoaded ~= false  -- true par défaut
    RegisterNetEvent(name, function(...)
        local src = source
        -- 1. Rate limit
        if not S.checkRate(src, name) then
            S.flag(src, ('flood event %s'):format(name))
            return
        end
        -- 2. Joueur chargé ?
        local player = Noxa.Players and Noxa.Players.get(src)
        if requireLoaded and not player then
            S.flag(src, ('event %s avant chargement'):format(name))
            return
        end
        -- 3. Exécution protégée (une erreur de handler ne crash pas le thread réseau)
        local ok, err = pcall(handler, src, player, ...)
        if not ok then
            U.print('error', 'Handler %s a échoué : %s', name, tostring(err))
        end
    end)
end

return S
