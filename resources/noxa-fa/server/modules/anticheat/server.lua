-- =====================================================================
--  NOXA FA — Anti-cheat & Panel staff (server-side, AUTORITAIRE)
--  ---------------------------------------------------------------------
--  DÉTECTION (scan serveur, jamais le client de confiance) :
--    • Speed hack   — vélocité serveur (à pied / en véhicule) hors seuil.
--    • Téléportation — saut de position NON corrélé à la vélocité (blink).
--    • God mode     — santé / armure hors bornes légitimes.
--    • Armes triche — arme sélectionnée dans une liste noire (menu/spawn).
--    • Spam d'entités — création réseau d'entités au-dessus d'un débit (entityCreating).
--    • Injection d'argent — pont depuis la classe Player (solde anormal / hors borne).
--  ÉCHELLE DE SANCTION (score cumulé, décroissant dans le temps) :
--    alerte+log  ->  avertissement  ->  freeze+alerte urgente  ->  kick+log  ->  ban auto+log
--  Chaque détection est journalisée (noxa_anticheat_logs + noxa_logs) et
--  diffusée en TEMPS RÉEL au panel staff (helper+).
--  ---------------------------------------------------------------------
--  PANEL STAFF (overlay z-index 60) — endpoints sécurisés :
--    open/fetch/action revérifient le rang staff SERVEUR à chaque appel.
--    Fonctions : screenshot · spectate discret · freeze · TP discrète ·
--    kick/ban · logs AC · alertes temps réel.
-- =====================================================================

Noxa = Noxa or {}
Noxa.AntiCheat = {}

local AC  = Noxa.AntiCheat
local U   = Noxa.Utils
local E   = Noxa.Enums
local DB  = Noxa.DB
local CFG = Noxa.Config.AntiCheat

-- Numérotation des actions (escalade : on n'applique qu'une seule fois chaque palier).
local ACTION_LEVEL = { alert = 0, warn = 1, freeze = 2, kick = 3, ban = 4 }

-- État anti-triche par joueur.
-- [src] = { score, applied, lastPos{vec}, lastScan, spawns{ts...}, graceUntil }
local state = {}
local joinTimes = {}              -- [src] = os.time() (durée de session)

-- Tampon mémoire des dernières alertes (réhydrate un panel à l'ouverture).
local recentAlerts = {}
local MAX_RECENT = 50

local serverStart = os.time()

-- ---------------------------------------------------------------------
--  Helpers d'état & de rang
-- ---------------------------------------------------------------------

local function getState(src)
    local s = state[src]
    if not s then
        s = { score = 0, applied = 0, lastPos = nil, lastScan = 0, spawns = {}, graceUntil = 0, expects = {} }
        state[src] = s
    end
    return s
end

--- Rang staff d'une source (objet Player chargé requis pour un rang > user).
local function rankOf(src)
    if src == 0 then return 'superadmin' end
    local ply = Noxa.Players.get(src)
    return ply and ply.staffRank or 'user'
end

--- La source possède-t-elle au moins le rang requis ?
local function hasStaff(src, minRank)
    if src == 0 then return true end
    return (E.StaffRanks[rankOf(src)] or 0) >= (E.StaffRanks[minRank] or 99)
end

--- Identité lisible de l'acteur (logs).
local function actorName(src)
    if src == 0 then return 'console' end
    local ply = Noxa.Players.get(src)
    return ply and ('%s [%s]'):format(ply:getName(), ply.citizenid) or ('src:' .. src)
end

--- Le joueur est-il exempté du scan anti-triche ? (staff de test, ou non chargé)
function AC.isExempt(src)
    if not CFG.enabled then return true end
    return (E.StaffRanks[rankOf(src)] or 0) >= (E.StaffRanks[CFG.exemptRank] or 99)
end

--- Ouvre une fenêtre de grâce (téléportation serveur légitime : jail, bien, admin).
--- Suspend la détection de téléportation pendant CFG.graceMs (ou ms fourni).
---@param src integer
---@param ms? integer
function AC.grace(src, ms)
    if not src or src == 0 then return end
    local s = getState(src)
    s.graceUntil = GetGameTimer() + (ms or CFG.graceMs)
    s.lastPos = nil   -- le prochain scan réinitialise la référence (pas de faux saut)
end
exports('AntiCheatGrace', function(src, ms) AC.grace(src, ms) end)

--- Déclare une DESTINATION de téléportation légitime (coords serveur, jamais
--- client). Un saut qui atterrit à proximité ne sera PAS flaggé. Couvre les
--- TP non interceptables au scan (ex. sortie d'un intérieur côté client) sans
--- jamais faire confiance au client (les coords viennent de la config serveur).
---@param src integer
---@param coords table {x,y,z}
---@param ttlMs? integer durée de validité (défaut 10 min)
function AC.expect(src, coords, ttlMs)
    if not src or src == 0 or type(coords) ~= 'table' or not coords.x then return end
    local s = getState(src)
    s.expects[#s.expects + 1] = {
        x = coords.x + 0.0, y = coords.y + 0.0, z = (coords.z or 0.0) + 0.0,
        exp = GetGameTimer() + (ttlMs or 600000),
    }
end
exports('AntiCheatExpect', function(src, coords, ttl) AC.expect(src, coords, ttl) end)

AddEventHandler('playerJoining', function()
    joinTimes[source] = os.time()
end)

AddEventHandler('playerDropped', function()
    state[source] = nil
    joinTimes[source] = nil
end)

-- À l'arrivée en jeu (spawn du personnage), grâce courte : le premier saut
-- vers le point de spawn ne doit pas être interprété comme une téléportation.
AddEventHandler('noxa:playerLoaded', function(src)
    AC.grace(src, 10000)
end)

-- ---------------------------------------------------------------------
--  Diffusion temps réel aux staff connectés (helper+)
-- ---------------------------------------------------------------------

--- Liste des sources staff actuellement en ligne (rang >= helper).
local function staffSources()
    local list = {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        if (E.StaffRanks[rankOf(src)] or 0) >= E.StaffRanks.helper then
            list[#list + 1] = src
        end
    end
    return list
end

--- Pousse une alerte à tous les staff en ligne + l'archive dans le tampon.
local function broadcastAlert(alert)
    recentAlerts[#recentAlerts + 1] = alert
    if #recentAlerts > MAX_RECENT then
        table.remove(recentAlerts, 1)
    end
    for _, src in ipairs(staffSources()) do
        TriggerClientEvent('noxa:staff:alert', src, alert)
    end
end

-- ---------------------------------------------------------------------
--  Position serveur (OneSync) — lecture autoritaire
-- ---------------------------------------------------------------------

local function pedOf(src)
    return GetPlayerPed(src)
end

local function posString(src)
    local ped = pedOf(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return ('%.1f, %.1f, %.1f'):format(c.x, c.y, c.z)
end

-- ---------------------------------------------------------------------
--  Application des sanctions (escalade à palier unique)
-- ---------------------------------------------------------------------

local function applyBan(src, reason)
    local ply = Noxa.Players.get(src)
    local license = ply and ply.license or GetPlayerIdentifierByType(src, 'license')
    local expire  = (CFG.banDuration == 0) and nil or (os.time() + CFG.banDuration)
    local accountId
    if ply then
        accountId = ply.accountId
    else
        local acc = license and DB.getAccountByLicense(license)
        accountId = acc and acc.id
    end
    if accountId then
        DB.setAccountBan(accountId, reason, expire)
        DB.insertBan({ account_id = accountId, license = license,
            reason = reason, banned_by = 'anticheat', expire = expire })
    end
    DropPlayer(src, ('[Noxa FA] Anti-triche : %s'):format(reason))
end

--- Exécute le palier d'action atteint (idempotent par palier via st.applied).
local function escalate(src, st, action, kind)
    local lvl = ACTION_LEVEL[action] or 0
    if lvl <= st.applied then return 'alert' end   -- palier déjà appliqué
    st.applied = lvl
    if action == 'warn' then
        TriggerClientEvent('noxa:notify', src,
            '⚠ Comportement suspect détecté par la protection serveur.', 'warning')
    elseif action == 'freeze' then
        TriggerClientEvent('noxa:admin:freeze', src, true)
    elseif action == 'kick' then
        DropPlayer(src, '[Noxa FA] Anti-triche : comportement non autorisé répété.')
    elseif action == 'ban' then
        applyBan(src, ('triche détectée (%s)'):format(kind))
    end
    return action
end

-- ---------------------------------------------------------------------
--  Point d'entrée central des détections
-- ---------------------------------------------------------------------

--- Rapporte une violation anti-triche : score, journal, alerte, sanction.
---@param src integer
---@param kind string speedhack|teleport|godmode|weapon|spawn|money
---@param severity string low|medium|high|critical
---@param detail string description lisible
function AC.report(src, kind, severity, detail)
    if not CFG.enabled then return end
    if not src or src == 0 then return end
    local st = getState(src)
    st.score = st.score + (CFG.weights[severity] or 1)

    -- Palier d'action visé en fonction du score cumulé.
    local A = CFG.actions
    local target = 'alert'
    if st.score >= A.banAt then target = 'ban'
    elseif st.score >= A.kickAt then target = 'kick'
    elseif st.score >= A.freezeAt then target = 'freeze'
    elseif st.score >= A.warnAt then target = 'warn' end

    local applied = escalate(src, st, target, kind)

    local ply  = Noxa.Players.get(src)
    local name = ply and ply:getName() or (GetPlayerName(src) or '??')
    local pos  = posString(src)

    -- Journal dédié anti-triche + log sécurité général (corrélation).
    DB.logAnticheat({
        license   = ply and ply.license or GetPlayerIdentifierByType(src, 'license'),
        citizenid = ply and ply.citizenid or nil,
        name      = name, src = src,
        type      = kind, severity = severity, score = st.score,
        detail    = detail, position = pos, action = applied,
    })
    DB.log('anticheat', severity == 'critical' and 'error' or 'warn',
        ply and ply.license or nil,
        ('[%s] %s : %s (score %d -> %s)'):format(kind, name, detail, st.score, applied))

    -- Alerte temps réel au panel staff.
    broadcastAlert({
        kind = kind, severity = severity, detail = detail,
        name = name, src = src, score = st.score, action = applied,
        pos = pos, time = os.time(),
    })

    U.print('warn', 'AC[%s] %s : %s (score %d, %s)', kind, name, detail, st.score, applied)
end

-- Bridge argent : appelé par la classe Player lors d'une anomalie de solde
-- (déjà détectée côté économie). Centralise la visibilité dans le flux AC.
exports('AntiCheatReportMoney', function(src, detail)
    AC.report(src, 'money', 'high', detail or 'mouvement d\'argent anormal')
end)

-- ---------------------------------------------------------------------
--  Boucle de scan serveur (vitesse · téléportation · god mode · armes)
-- ---------------------------------------------------------------------

local function magnitude(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Le point d'arrivée correspond-il à une destination de TP autorisée (non expirée) ?
-- Élague au passage les destinations périmées.
local EXPECT_RADIUS = 8.0
local function nearExpected(st, coords, now)
    local kept, hit = {}, false
    for _, d in ipairs(st.expects) do
        if now < d.exp then
            kept[#kept + 1] = d
            local dx, dy, dz = coords.x - d.x, coords.y - d.y, coords.z - d.z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= EXPECT_RADIUS then hit = true end
        end
    end
    st.expects = kept
    return hit
end

local function scanPlayer(src, now)
    local ped = pedOf(src)
    if not ped or ped == 0 then return end

    local st = getState(src)
    local coords = GetEntityCoords(ped)
    local vel = GetEntityVelocity(ped)
    local speed = magnitude(vel)               -- m/s
    local inVeh = GetVehiclePedIsIn(ped, false) ~= 0

    -- 1) Speed hack -----------------------------------------------------
    -- À pied : on exige DEUX scans consécutifs au-dessus du seuil pour ne pas
    -- flagger une chute / un ragdoll / une projection (brefs, < intervalle de scan).
    -- En véhicule : le seuil est si haut (342 km/h) qu'un flag isolé suffit.
    if inVeh then
        st.footStreak = 0
        if speed > CFG.speed.inVehicle then
            AC.report(src, 'speedhack', CFG.speed.severity,
                ('vitesse %.0f m/s (%.0f km/h) en véhicule'):format(speed, speed * 3.6))
        end
    else
        if speed > CFG.speed.onFoot then
            st.footStreak = (st.footStreak or 0) + 1
            if st.footStreak >= 2 then
                AC.report(src, 'speedhack', CFG.speed.severity,
                    ('vitesse %.0f m/s (%.0f km/h) à pied (soutenue)'):format(speed, speed * 3.6))
            end
        else
            st.footStreak = 0
        end
    end

    -- 2) Téléportation (blink) -----------------------------------------
    -- Distance parcourue depuis le dernier scan vs distance plausible
    -- (vélocité × Δt). Un saut bien supérieur à la vitesse réelle = blink.
    local graced = now < st.graceUntil
    if st.lastPos and not graced then
        local dt = (now - st.lastScan) / 1000.0
        if dt > 0 then
            local dist = #(coords - st.lastPos)
            local plausible = speed * dt * CFG.teleport.tolerance + CFG.teleport.base
            if dist > CFG.teleport.minJump and dist > plausible and not nearExpected(st, coords, now) then
                AC.report(src, 'teleport', CFG.teleport.severity,
                    ('saut de %.0f m en %.1fs (vitesse %.0f m/s)'):format(dist, dt, speed))
            end
        end
    end
    st.lastPos  = coords
    st.lastScan = now

    -- 3) God mode -------------------------------------------------------
    local health = GetEntityHealth(ped)
    local armor  = GetPedArmour(ped)
    if health > CFG.godmode.maxHealth then
        AC.report(src, 'godmode', CFG.godmode.severity,
            ('santé %d > %d'):format(health, CFG.godmode.maxHealth))
    elseif armor > CFG.godmode.maxArmor then
        AC.report(src, 'godmode', CFG.godmode.severity,
            ('armure %d > %d'):format(armor, CFG.godmode.maxArmor))
    end

    -- 4) Arme interdite (menu de triche / spawn d'arme) -----------------
    local weapon = GetSelectedPedWeapon(ped)
    if CFG.weapons.blacklist[weapon] then
        AC.report(src, 'weapon', CFG.weapons.severity,
            ('arme interdite équipée (hash %s)'):format(weapon))
    end
end

CreateThread(function()
    if not CFG.enabled then return end
    while true do
        Wait(CFG.scanInterval)
        local now = GetGameTimer()
        for _, sid in ipairs(GetPlayers()) do
            local src = tonumber(sid)
            -- On ne scanne QUE les joueurs pleinement chargés et non exemptés
            -- (évite les faux positifs en lobby / sélection de personnage).
            if Noxa.Players.get(src) and not AC.isExempt(src) then
                -- pcall : un échec de native (joueur en transition) ne casse pas la boucle.
                pcall(scanPlayer, src, now)
            end
        end
    end
end)

-- ---------------------------------------------------------------------
--  Spam de création d'entités réseau (props / véhicules)
--  entityCreating : `source` = joueur à l'origine de la création.
-- ---------------------------------------------------------------------

AddEventHandler('entityCreating', function(handle)
    local src = source
    if not src or src == 0 or AC.isExempt(src) then return end
    -- BUG-01 : ne compter QUE les entités réellement spawnées par un script/joueur.
    -- Les PNJ et véhicules ambiants/garés du monde natif prennent comme owner
    -- réseau le joueur qui les streame ; sans ce filtre ils étaient comptés comme
    -- des "spawns joueur" et déclenchaient une boucle de faux positifs (entité ??).
    -- ePopulationType : 6=permanent script, 7=mission, 10=tool -> créées par script.
    --                   1..5 = aléatoire/ambiant (monde natif) -> ignoré.
    -- nil (native indisponible) -> on laisse passer, le seuil glissant fait foi.
    local pop = GetEntityPopulationType(handle)
    if pop and pop ~= 6 and pop ~= 7 and pop ~= 10 then return end
    local st = getState(src)
    local now = GetGameTimer()
    local win = {}
    for _, ts in ipairs(st.spawns) do
        if now - ts < CFG.spawn.window then win[#win + 1] = ts end
    end
    win[#win + 1] = now
    st.spawns = win
    if #win > CFG.spawn.maxInWindow then
        st.spawns = {}   -- réinitialise pour ne pas spammer le même flag
        AC.report(src, 'spawn', CFG.spawn.severity,
            ('%d entités créées en %.0fs'):format(#win, CFG.spawn.window / 1000))
    end
end)

-- ---------------------------------------------------------------------
--  Décroissance du score (évite l'accumulation lente -> faux positif)
-- ---------------------------------------------------------------------

CreateThread(function()
    if not CFG.enabled then return end
    while true do
        Wait(CFG.decayInterval)
        for _, st in pairs(state) do
            if st.score > 0 then
                st.score = math.max(0, st.score - CFG.decayAmount)
                -- Si le score retombe sous un palier, on libère ce palier (sauf kick/ban : déjà partis).
                if st.score < CFG.actions.freezeAt and st.applied == ACTION_LEVEL.freeze then
                    st.applied = ACTION_LEVEL.warn
                end
            end
        end
    end
end)

-- =====================================================================
--  PANEL STAFF NUI (F3) — instantanés & actions sécurisées
-- =====================================================================

--- Construit la fiche temps réel de tous les joueurs connectés.
---@param canSeeIp boolean l'IP n'est exposée qu'aux admins (donnée sensible)
local function buildPlayers(canSeeIp)
    local list = {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ply = Noxa.Players.get(src)
        local jobDef = ply and E.Jobs[ply.job]
        local st = state[src]
        local ped = GetPlayerPed(src)
        local pos = (ped ~= 0) and GetEntityCoords(ped) or nil
        list[#list + 1] = {
            id      = src,
            name    = ply and ply:getName() or GetPlayerName(src),
            steam   = GetPlayerName(src),
            license = (GetPlayerIdentifierByType(src, 'license') or ''):gsub('license:', ''),
            discord = (GetPlayerIdentifierByType(src, 'discord') or ''):gsub('discord:', ''),
            ip      = canSeeIp and GetPlayerEndpoint(src) or nil,
            ping    = GetPlayerPing(src),
            fps     = math.floor(tonumber(Player(src).state['noxa:fps']) or 0),
            pos     = pos and ('%.0f, %.0f, %.0f'):format(pos.x, pos.y, pos.z) or '—',
            job     = ply and ply.job or '-',
            jobLabel = jobDef and jobDef.label or '—',
            grade   = ply and ply.job_grade or 0,
            cash    = ply and ply.cash or 0,
            bank    = ply and ply.bank or 0,
            cid     = ply and ply.citizenid or nil,
            rank    = ply and ply.staffRank or 'user',
            session = os.time() - (joinTimes[src] or os.time()),
            acScore = st and st.score or 0,
            loaded  = ply ~= nil,
        }
    end
    table.sort(list, function(a, b)
        if a.acScore ~= b.acScore then return a.acScore > b.acScore end  -- suspects en tête
        return a.id < b.id
    end)
    return list
end

local function buildServer()
    return {
        name       = Noxa.Config.ServerName,
        connected  = #GetPlayers(),
        maxClients = GetConvarInt('sv_maxclients', 48),
        uptime     = os.time() - serverStart,
        acEnabled  = CFG.enabled,
        flags24h   = #recentAlerts,
    }
end

-- ---------------------------------------------------------------------
--  Ouverture du panel (gate serveur ; non-staff -> silence)
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:staff:open', function(src, ply)
    if not hasStaff(src, 'helper') then return end
    local canSeeIp = hasStaff(src, 'admin')
    DB.log('anticheat', 'info', ply and ply.license,
        ('%s a ouvert le panel staff'):format(actorName(src)))
    TriggerClientEvent('noxa:staff:grant', src, {
        rank         = rankOf(src),
        canSeeIp     = canSeeIp,
        players      = buildPlayers(canSeeIp),
        server       = buildServer(),
        alerts       = recentAlerts,
        banDurations = (function()
            local keys = {}
            for k in pairs(Noxa.Config.Admin.banDurations) do keys[#keys + 1] = k end
            table.sort(keys)
            return keys
        end)(),
    })
end)

-- ---------------------------------------------------------------------
--  Rafraîchissement de section à la demande
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:staff:fetch', function(src, ply, what, arg)
    if not hasStaff(src, 'helper') then return Noxa.Security.flag(src, 'staff:fetch sans rang') end
    if what == 'players' then
        TriggerClientEvent('noxa:staff:data', src, 'players', buildPlayers(hasStaff(src, 'admin')))
    elseif what == 'server' then
        TriggerClientEvent('noxa:staff:data', src, 'server', buildServer())
    elseif what == 'aclogs' then
        local filter = (type(arg) == 'string') and arg or 'all'
        local rows = DB.getAnticheatLogs(filter, 80)
        TriggerClientEvent('noxa:staff:data', src, 'aclogs', rows)
    end
end)

-- ---------------------------------------------------------------------
--  Table d'actions du panel — chaque action déclare son rang minimal.
--  run(src, actor, targetId, params)
-- ---------------------------------------------------------------------

local function feedback(src, msg, kind)
    TriggerClientEvent('noxa:notify', src, msg, kind or 'inform')
end

local actions = {}

-- Freeze / libération (modération douce).
actions.freeze = { rank = 'mod', run = function(src, ply, tid, p)
    if not GetPlayerName(tid) then return feedback(src, 'Cible introuvable.', 'error') end
    local on = p.state ~= false
    TriggerClientEvent('noxa:admin:freeze', tid, on)
    DB.log('anticheat', 'info', nil, ('%s a %s src:%s (staff)'):format(
        actorName(src), on and 'figé' or 'libéré', tid))
    feedback(src, on and 'Joueur figé.' or 'Joueur libéré.', 'success')
end }

-- Spectate discret : le staff (src) observe la cible (tid) sans être vu.
actions.spectate = { rank = 'mod', run = function(src, ply, tid, p)
    if not GetPlayerName(tid) then return feedback(src, 'Cible introuvable.', 'error') end
    TriggerClientEvent('noxa:staff:spectate', src, { target = tid, state = p.state ~= false })
    DB.log('anticheat', 'info', nil, ('%s spectate src:%s (%s)'):format(
        actorName(src), tid, p.state ~= false and 'on' or 'off'))
end }

-- Téléportation discrète vers la cible (coords lues serveur).
actions.tp = { rank = 'mod', run = function(src, ply, tid)
    if src == 0 then return end
    local ped = GetPlayerPed(tid)
    if ped == 0 then return feedback(src, 'Cible introuvable.', 'error') end
    local c = GetEntityCoords(ped)
    AC.grace(src)   -- évite que NOTRE TP staff déclenche une fausse détection
    TriggerClientEvent('noxa:admin:teleport', src, { x = c.x, y = c.y, z = c.z })
    DB.log('anticheat', 'info', nil, ('%s s\'est TP vers src:%s'):format(actorName(src), tid))
end }

-- Capture d'écran de la cible (best-effort : nécessite screenshot-basic + webhook).
actions.screenshot = { rank = 'mod', run = function(src, ply, tid)
    if not GetPlayerName(tid) then return feedback(src, 'Cible introuvable.', 'error') end
    TriggerClientEvent('noxa:staff:screenshot', tid, src)
    DB.log('anticheat', 'info', nil, ('%s a demandé un screenshot de src:%s'):format(actorName(src), tid))
    feedback(src, 'Capture demandée…', 'inform')
end }

-- Kick (mod+).
actions.kick = { rank = 'mod', run = function(src, ply, tid, p)
    local name = GetPlayerName(tid)
    if not name then return feedback(src, 'Cible introuvable.', 'error') end
    local reason = (p.reason and p.reason ~= '') and p.reason or 'Comportement contraire au règlement.'
    DB.log('anticheat', 'warn', GetPlayerIdentifierByType(tid, 'license'),
        ('%s a kické %s : %s'):format(actorName(src), name, reason))
    DropPlayer(tid, ('[Noxa FA] Expulsé : %s'):format(reason))
    feedback(src, ('%s expulsé.'):format(name), 'success')
end }

-- Ban (admin+).
actions.ban = { rank = 'admin', run = function(src, ply, tid, p)
    local target = Noxa.Players.get(tid)
    local license, accountId, displayName
    if target then
        license, accountId, displayName = target.license, target.accountId, target:getName()
    else
        license = GetPlayerIdentifierByType(tid, 'license')
        local acc = license and DB.getAccountByLicense(license)
        accountId, displayName = acc and acc.id, GetPlayerName(tid) or ('src:' .. tid)
    end
    if not accountId then return feedback(src, 'Compte cible introuvable.', 'error') end
    local durKey  = p.duration or 'perm'
    local seconds = Noxa.Config.Admin.banDurations[durKey] or tonumber(durKey)
    if not seconds then return feedback(src, 'Durée invalide.', 'error') end
    local expire  = (seconds == 0) and nil or (os.time() + seconds)
    local reason  = (p.reason and p.reason ~= '') and p.reason or 'Comportement contraire au règlement.'
    DB.setAccountBan(accountId, reason, expire)
    DB.insertBan({ account_id = accountId, license = license,
        reason = reason, banned_by = actorName(src), expire = expire })
    DB.log('anticheat', 'error', license,
        ('%s a banni %s (%s) : %s'):format(actorName(src), displayName, durKey, reason))
    DropPlayer(tid, ('[Noxa FA] Banni (%s)\nRaison : %s'):format(durKey, reason))
    feedback(src, ('%s banni (%s).'):format(displayName, durKey), 'success')
end }

Noxa.Security.onNet('noxa:staff:action', function(src, ply, payload)
    if type(payload) ~= 'table' or type(payload.action) ~= 'string' then
        return Noxa.Security.flag(src, 'staff:action malformée')
    end
    local def = actions[payload.action]
    if not def then return Noxa.Security.flag(src, ('staff:action inconnue (%s)'):format(payload.action)) end
    if not hasStaff(src, def.rank) then
        return Noxa.Security.flag(src, ('staff:action %s sans rang'):format(payload.action))
    end
    def.run(src, ply, tonumber(payload.target), payload.params or {})
    -- Rafraîchit la liste (l'action a pu modifier l'état des joueurs).
    TriggerClientEvent('noxa:staff:data', src, 'players', buildPlayers(hasStaff(src, 'admin')))
end)

-- ---------------------------------------------------------------------
--  Relais de la capture d'écran (cible -> staff demandeur)
--  La cible renvoie l'URL hébergée ; on la transmet au staff.
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:staff:screenshotResult', function(src, ply, requesterSrc, url)
    requesterSrc = tonumber(requesterSrc)
    if not requesterSrc or not hasStaff(requesterSrc, 'mod') then return end
    if type(url) ~= 'string' then return end
    TriggerClientEvent('noxa:staff:screenshotReady', requesterSrc, { src = src, url = url })
    DB.log('anticheat', 'info', nil, ('screenshot de src:%s -> %s'):format(src, url))
end, { requireLoaded = false })

-- =====================================================================
--  PANEL ANTI-CHEAT (design autonome NUI) — tableau de bord LECTURE SEULE
--  ---------------------------------------------------------------------
--  Construit `window.DATA` attendu par nui/anticheat/index.html à partir de
--  l'état serveur RÉEL (joueurs, alertes mémoire, logs/bans BDD). Le design
--  est un export figé : ses boutons d'action ne rappellent pas Lua — les
--  sanctions restent sur le panel staff FONCTIONNEL (F3). Ce panel sert de
--  console de visualisation enrichie (helper+ ; IP réservée admin+).
-- =====================================================================

local AC_TYPE_LABEL = {
    speedhack = 'Speed Hack', teleport = 'Teleport', godmode = 'God Mode',
    weapon = 'Weapon Spawn', spawn = 'Entity Spam', money = 'Money Exploit',
}
local SEVERITY_CONFIDENCE = { low = 35, medium = 65, high = 85, critical = 97 }
local STAFF_ROLE = { helper = 'Support', mod = 'Modérateur', admin = 'Admin', superadmin = 'Founder' }

local function initialsOf(name)
    local a, b = tostring(name or '?'):match('(%a)%a*%s+(%a)')
    if a and b then return (a .. b):upper() end
    return tostring(name or '?'):sub(1, 2):upper()
end

local function fmtPlaytime(secs)
    secs = math.max(0, secs or 0)
    return ('%dh %02dm'):format(math.floor(secs / 3600), math.floor((secs % 3600) / 60))
end

local function statusOf(score)
    if score >= 12 then return 'critical' end
    if score >= 4 then return 'warn' end
    return 'clean'
end

local function isoFromEpoch(t)
    return os.date('!%Y-%m-%dT%H:%M:%SZ', t or os.time())
end

local function buildAcPlayers(canSeeIp)
    local list = {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ply = Noxa.Players.get(src)
        local st  = state[src]
        local score = st and st.score or 0
        local jobDef = ply and E.Jobs[ply.job]
        local name = ply and ply:getName() or GetPlayerName(src) or ('src:' .. src)
        list[#list + 1] = {
            id       = src,
            name     = name,
            initials = initialsOf(name),
            license  = (GetPlayerIdentifierByType(src, 'license') or ''),
            steam    = (GetPlayerIdentifierByType(src, 'steam') or GetPlayerName(src) or ''),
            discord  = (GetPlayerIdentifierByType(src, 'discord') or ''):gsub('discord:', ''),
            ip       = canSeeIp and (GetPlayerEndpoint(src) or '—') or '—',
            ping     = GetPlayerPing(src),
            playtime = fmtPlaytime(os.time() - (joinTimes[src] or os.time())),
            trust    = math.max(0, math.min(100, 100 - score * 6)),
            flags    = score > 0 and math.ceil(score / 2) or 0,
            status   = statusOf(score),
            job      = (jobDef and jobDef.label) or (ply and ply.job) or 'Civil',
            joined   = '—',
        }
    end
    table.sort(list, function(a, b) return a.flags > b.flags end)
    return list
end

local function buildAcDetections()
    local out = {}
    for i = #recentAlerts, 1, -1 do
        local a = recentAlerts[i]
        out[#out + 1] = {
            id         = ('D-%04X'):format(((a.time or 0) + i) % 0xFFFF),
            type       = AC_TYPE_LABEL[a.kind] or a.kind,
            player     = a.name, pid = a.src,
            severity   = a.severity or 'low',
            status     = (a.action == 'ban' or a.action == 'kick') and 'resolved' or 'open',
            time       = isoFromEpoch(a.time),
            detail     = a.detail,
            confidence = SEVERITY_CONFIDENCE[a.severity] or 50,
        }
        if #out >= 40 then break end
    end
    return out
end

local function buildAcWatchlist()
    local out = {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local st = state[src]
        if st and (st.score or 0) > 0 then
            local ply = Noxa.Players.get(src)
            local name = ply and ply:getName() or GetPlayerName(src) or ('src:' .. src)
            out[#out + 1] = {
                pid = src, name = name, initials = initialsOf(name),
                trust = math.max(0, 100 - st.score * 6),
                since = isoFromEpoch(joinTimes[src]),
                note  = ('Score anti-triche %d — surveillance automatique.'):format(st.score),
                by    = 'Anti-Cheat',
            }
        end
    end
    return out
end

local function buildAcLogs()
    local out = {}
    for _, r in ipairs(DB.getAnticheatLogs('all', 30)) do
        out[#out + 1] = {
            time  = tostring(r.created_at or ''):sub(12, 19),
            tag   = 'DETECT',
            level = r.severity or 'info',
            msg   = ('%s — %s (#%s) %s'):format(AC_TYPE_LABEL[r.type] or r.type or '?',
                r.name or '?', r.src or '?', r.detail or ''),
        }
    end
    return out
end

local function buildAcBans()
    local out = {}
    for _, r in ipairs(DB.getRecentBans(40)) do
        local duration
        if not r.expire then
            duration = 'Permanent'
        else
            local left = (tonumber(r.expire) or 0) - os.time()
            duration = (left <= 0) and 'Expiré' or ('%d j'):format(math.ceil(left / 86400))
        end
        out[#out + 1] = {
            id       = ('B-%s'):format(r.id),
            player   = r.name or r.license or '?',
            license  = r.license or '',
            reason   = r.reason or '—',
            by       = r.banned_by or 'console',
            date     = tostring(r.created_at or ''):sub(1, 10),
            duration = duration,
            active   = (tonumber(r.active) or 0) == 1,
        }
    end
    return out
end

local function buildAcStaff()
    local out = {}
    for _, src in ipairs(staffSources()) do
        local ply = Noxa.Players.get(src)
        local name = ply and ply:getName() or GetPlayerName(src) or ('src:' .. src)
        local rank = rankOf(src)
        out[#out + 1] = {
            name = name, initials = initialsOf(name),
            role = STAFF_ROLE[rank] or rank, online = true,
            actions = 0, since = fmtPlaytime(os.time() - (joinTimes[src] or os.time())),
        }
    end
    return out
end

local function buildAcStats()
    local counts, detByType = {}, {}
    for _, a in ipairs(recentAlerts) do
        local lbl = AC_TYPE_LABEL[a.kind] or a.kind
        counts[lbl] = (counts[lbl] or 0) + 1
    end
    for lbl, v in pairs(counts) do detByType[#detByType + 1] = { label = lbl, value = v } end
    table.sort(detByType, function(a, b) return a.value > b.value end)
    -- Séries de longueur fixe (le design itère 24/12 points) — valeurs réelles courantes.
    local online = #GetPlayers()
    local playerSeries, detTrend = {}, {}
    for i = 1, 24 do playerSeries[i] = online end
    for i = 1, 12 do detTrend[i] = #recentAlerts end
    return { playerSeries = playerSeries, detByType = detByType, detTrend = detTrend }
end

Noxa.Security.onNet('noxa:acpanel:open', function(src, ply)
    if not hasStaff(src, 'helper') then return Noxa.Security.flag(src, 'acpanel:open sans rang') end
    local canSeeIp = hasStaff(src, 'admin')
    DB.log('anticheat', 'info', ply and ply.license,
        ('%s a ouvert le panel anti-cheat (design)'):format(actorName(src)))
    TriggerClientEvent('noxa:acpanel:grant', src, {
        serverName = Noxa.Config.ServerName,
        maxSlots   = GetConvarInt('sv_maxclients', 48),
        players    = buildAcPlayers(canSeeIp),
        detections = buildAcDetections(),
        watchlist  = buildAcWatchlist(),
        bans       = buildAcBans(),
        logs       = buildAcLogs(),
        staff      = buildAcStaff(),
        detTypes   = { 'Aimbot', 'Triggerbot', 'Speed Hack', 'Teleport', 'God Mode',
                       'Noclip', 'Money Exploit', 'Weapon Spawn', 'Lua Injection', 'Resource Tampering' },
        stats      = buildAcStats(),
    })
end)

return AC
