-- =====================================================================
--  NOXA FA — Module Administration (server-side)
--  Boîte à outils staff : modération, sanctions, téléportation, économie.
--  • Chaque commande revérifie le rang staff côté serveur (jamais le client).
--  • Toute action sensible est journalisée (noxa_logs) pour audit.
--  • Bans horodatés persistés (noxa_bans + état compte) et vérifiés à la
--    connexion par le manager.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Admin = {}

local Admin = Noxa.Admin
local U     = Noxa.Utils
local E     = Noxa.Enums
local DB    = Noxa.DB
local CFG   = Noxa.Config

-- ---------------------------------------------------------------------
--  Helpers de permission & enregistrement de commandes
-- ---------------------------------------------------------------------

--- La source possède-t-elle au moins le rang requis ? (console = src 0 = OK)
local function hasStaff(src, minRank)
    if src == 0 then return true end
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    return (E.StaffRanks[ply.staffRank] or 0) >= (E.StaffRanks[minRank] or 99)
end

--- Identité lisible de l'acteur pour les logs.
local function actorName(src)
    if src == 0 then return 'console' end
    local ply = Noxa.Players.get(src)
    return ply and ('%s [%s]'):format(ply:getName(), ply.citizenid) or ('src:' .. src)
end

--- Enregistre une commande staff protégée. Le handler reçoit (src, args, ply).
---@param name string
---@param minRank string
---@param handler fun(src:integer, args:table, ply:table|nil)
local function staffCommand(name, minRank, handler)
    RegisterCommand(name, function(src, args)
        if not hasStaff(src, minRank) then
            if src ~= 0 then
                TriggerClientEvent('noxa:notify', src, 'Permission insuffisante.', 'error')
            end
            return
        end
        handler(src, args, Noxa.Players.get(src))
    end, false)  -- restricted=false : la garde se fait sur le rang staff DB
end

--- Notifie un acteur (console -> print, joueur -> notify client).
local function feedback(src, msg, kind)
    if src == 0 then
        U.print('info', msg)
    else
        TriggerClientEvent('noxa:notify', src, msg, kind or 'inform')
    end
end

-- ---------------------------------------------------------------------
--  Économie / emploi
-- ---------------------------------------------------------------------

-- /setmoney [id] [cash|bank] [montant]
staffCommand('setmoney', 'admin', function(src, args)
    local target = Noxa.Players.get(tonumber(args[1]))
    local account = args[2]
    local amount = U.sanitizeAmount(args[3])
    if not target or (account ~= E.Accounts.CASH and account ~= E.Accounts.BANK) or not amount then
        return feedback(src, 'Usage: /setmoney [id] [cash|bank] [montant]', 'error')
    end
    -- On recale le solde en passant par les primitives validées (add/remove)
    local current = target:getMoney(account)
    if amount > current then
        target:addMoney(account, amount - current, 'admin:setmoney')
    elseif amount < current then
        target:removeMoney(account, current - amount, 'admin:setmoney')
    end
    DB.log('admin', 'warn', nil, ('%s a réglé %s de %s à %s'):format(
        actorName(src), account, target:getName(), U.money(amount)))
    feedback(src, ('%s.%s = %s'):format(target:getName(), account, U.money(amount)), 'success')
end)

-- /job [id] [job] [grade]  (affectation admin, contourne la whitelist)
staffCommand('job', 'admin', function(src, args)
    local target = Noxa.Players.get(tonumber(args[1]))
    if not target or not args[2] then
        return feedback(src, 'Usage: /job [id] [job] [grade]', 'error')
    end
    local ok, err = Noxa.Jobs.setPlayerJob(target, args[2], tonumber(args[3]) or 0, { bypassWhitelist = true })
    if ok then
        DB.log('admin', 'info', nil, ('%s a affecté %s à %s'):format(actorName(src), target:getName(), args[2]))
        feedback(src, ('%s -> %s'):format(target:getName(), args[2]), 'success')
    else
        feedback(src, ('Échec: %s'):format(err or 'inconnu'), 'error')
    end
end)

-- /setjobwl [id] [job] [gradeMax]  (accorde une whitelist d'emploi)
staffCommand('setjobwl', 'admin', function(src, args)
    local target = Noxa.Players.get(tonumber(args[1]))
    local job = args[2]
    local maxGrade = U.clampInt(args[3] or 0, 0, CFG.Jobs.maxGrade)
    if not target or not E.Jobs[job] or not maxGrade then
        return feedback(src, 'Usage: /setjobwl [id] [job] [gradeMax]', 'error')
    end
    DB.setJobWhitelist(target.citizenid, job, maxGrade, 'admin')
    DB.log('admin', 'info', nil, ('%s a whitelisté %s sur %s (g%d)'):format(
        actorName(src), target:getName(), job, maxGrade))
    feedback(src, ('Whitelist %s -> %s g%d'):format(target:getName(), job, maxGrade), 'success')
end)

-- /setgroup [id] [rang]  (gestion des rangs staff — superadmin uniquement)
staffCommand('setgroup', 'superadmin', function(src, args)
    local target = Noxa.Players.get(tonumber(args[1]))
    local rank = args[2]
    if not target or not E.StaffRanks[rank] then
        return feedback(src, 'Usage: /setgroup [id] [user|helper|mod|admin|superadmin]', 'error')
    end
    target.staffRank = rank
    MySQL.update('UPDATE noxa_accounts SET staff_rank = ? WHERE id = ?', { rank, target.accountId })
    DB.log('admin', 'warn', nil, ('%s a défini le rang de %s à %s'):format(
        actorName(src), target:getName(), rank))
    feedback(src, ('%s est désormais %s.'):format(target:getName(), rank), 'success')
end)

-- ---------------------------------------------------------------------
--  Modération : soin, réanimation, téléportation
-- ---------------------------------------------------------------------

-- /revive [id?]   (id optionnel : soi-même par défaut)
staffCommand('revive', 'admin', function(src, args)
    local targetId = tonumber(args[1]) or src
    if targetId == 0 then return feedback(src, 'Cible requise depuis la console.', 'error') end
    TriggerClientEvent('noxa:admin:revive', targetId)
    DB.log('admin', 'info', nil, ('%s a réanimé src:%s'):format(actorName(src), targetId))
    feedback(src, 'Joueur réanimé.', 'success')
end)

-- /heal [id?]
staffCommand('heal', 'mod', function(src, args)
    local targetId = tonumber(args[1]) or src
    if targetId == 0 then return feedback(src, 'Cible requise depuis la console.', 'error') end
    TriggerClientEvent('noxa:admin:heal', targetId)
    feedback(src, 'Joueur soigné.', 'success')
end)

-- /goto [id]   (se téléporter vers un joueur ; coords lues serveur)
staffCommand('goto', 'mod', function(src, args)
    if src == 0 then return end
    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerPed(targetId) or GetPlayerPed(targetId) == 0 then
        return feedback(src, 'Cible introuvable.', 'error')
    end
    local coords = GetEntityCoords(GetPlayerPed(targetId))
    TriggerClientEvent('noxa:admin:teleport', src, { x = coords.x, y = coords.y, z = coords.z })
end)

-- /bring [id]  (ramener un joueur à soi)
staffCommand('bring', 'admin', function(src, args)
    if src == 0 then return end
    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerPed(targetId) or GetPlayerPed(targetId) == 0 then
        return feedback(src, 'Cible introuvable.', 'error')
    end
    local coords = GetEntityCoords(GetPlayerPed(src))
    if Noxa.AntiCheat then Noxa.AntiCheat.grace(targetId) end
    TriggerClientEvent('noxa:admin:teleport', targetId, { x = coords.x, y = coords.y, z = coords.z })
    DB.log('admin', 'info', nil, ('%s a ramené src:%s'):format(actorName(src), targetId))
end)

-- /announce [message]
staffCommand('announce', 'mod', function(src, args)
    local msg = table.concat(args, ' ')
    if msg == '' then return feedback(src, 'Usage: /announce [message]', 'error') end
    TriggerClientEvent('noxa:announce', -1, msg)
    DB.log('admin', 'info', nil, ('%s a annoncé: %s'):format(actorName(src), msg))
end)

-- ---------------------------------------------------------------------
--  Sanctions : kick / ban / unban
-- ---------------------------------------------------------------------

-- /kick [id] [raison...]
staffCommand('kick', 'mod', function(src, args)
    local targetId = tonumber(args[1])
    local target = targetId and GetPlayerName(targetId)
    if not target then return feedback(src, 'Cible introuvable.', 'error') end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Comportement contraire au règlement.' end
    DB.log('admin', 'warn', GetPlayerIdentifierByType(targetId, 'license'),
        ('%s a kické %s : %s'):format(actorName(src), target, reason))
    DropPlayer(targetId, ('[Noxa FA] Expulsé : %s'):format(reason))
    feedback(src, ('%s expulsé.'):format(target), 'success')
end)

-- /ban [id] [durée] [raison...]   durée : 1h|1d|3d|7d|30d|perm ou secondes
staffCommand('ban', 'admin', function(src, args)
    local targetId = tonumber(args[1])
    local target = Noxa.Players.get(targetId)
    if not target then return feedback(src, 'Cible introuvable / non chargée.', 'error') end

    local durKey = args[2] or 'perm'
    local seconds = CFG.Admin.banDurations[durKey] or tonumber(durKey)
    if not seconds then return feedback(src, 'Durée invalide (1h|1d|3d|7d|30d|perm).', 'error') end
    local expire = (seconds == 0) and nil or (os.time() + seconds)

    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Comportement contraire au règlement.' end

    DB.setAccountBan(target.accountId, reason, expire)
    DB.insertBan({
        account_id = target.accountId,
        license    = target.license,
        reason     = reason,
        banned_by  = actorName(src),
        expire     = expire,
    })
    DB.log('admin', 'error', target.license,
        ('%s a banni %s (%s) : %s'):format(actorName(src), target:getName(), durKey, reason))
    DropPlayer(targetId, ('[Noxa FA] Banni (%s)\nRaison : %s'):format(durKey, reason))
    feedback(src, ('%s banni (%s).'):format(target:getName(), durKey), 'success')
end)

-- /unban [license]
staffCommand('unban', 'admin', function(src, args)
    local license = args[1]
    if not license then return feedback(src, 'Usage: /unban [license]', 'error') end
    local acc = DB.getAccountByLicense(license)
    if not acc then return feedback(src, 'Compte introuvable.', 'error') end
    MySQL.update('UPDATE noxa_accounts SET banned = 0, ban_reason = NULL, ban_expire = NULL WHERE id = ?',
        { acc.id })
    DB.deactivateBans(license)
    DB.log('admin', 'warn', license, ('%s a débanni %s'):format(actorName(src), license))
    feedback(src, 'Compte débanni.', 'success')
end)

-- =====================================================================
--  PANNEAU ADMIN NUI (F10) — flux 100 % piloté serveur
--  Le client n'émet que des INTENTIONS ; chaque event revérifie le rang
--  staff côté serveur (jamais le client) et journalise les actions
--  sensibles. Aucune donnée envoyée par le client n'est de confiance.
-- =====================================================================

local serverStart = os.time()

-- ---------------------------------------------------------------------
--  Construction des instantanés (lecture seule) envoyés à la NUI
-- ---------------------------------------------------------------------

--- Liste temps réel de TOUS les joueurs connectés (chargés ou en lobby).
local function buildPlayers()
    local list = {}
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ply = Noxa.Players.get(src)
        local jobDef = ply and E.Jobs[ply.job]
        list[#list + 1] = {
            id     = src,
            name   = ply and ply:getName() or GetPlayerName(src),
            steam  = GetPlayerName(src),
            ping   = GetPlayerPing(src),
            rank   = ply and ply.staffRank or 'user',
            job    = ply and ply.job or '-',
            jobLabel = jobDef and jobDef.label or '—',
            grade  = ply and ply.job_grade or 0,
            duty   = ply and ply.duty or false,
            cash   = ply and ply.cash or 0,
            bank   = ply and ply.bank or 0,
            cid    = ply and ply.citizenid or nil,
            loaded = ply ~= nil,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Référentiel des jobs (pour les listes déroulantes côté NUI).
local function buildJobs()
    local jobs = {}
    for name, def in pairs(E.Jobs) do
        local grades = {}
        for g, gd in pairs(def.grades) do
            grades[#grades + 1] = { grade = g, label = gd.label }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        jobs[#jobs + 1] = { name = name, label = def.label, grades = grades }
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    return jobs
end

--- Infos serveur (compteur, uptime, etc.).
local function buildServer()
    local up = os.time() - serverStart
    return {
        name      = CFG.ServerName,
        players   = Noxa.Players.count(),
        connected = #GetPlayers(),
        maxClients = GetConvarInt('sv_maxclients', 48),
        uptime    = up,
        resource  = GetCurrentResourceName(),
    }
end

--- Pousse l'instantané « joueurs » au demandeur (après chaque action).
local function pushPlayers(src)
    TriggerClientEvent('noxa:admin:data', src, 'players', buildPlayers())
end

-- ---------------------------------------------------------------------
--  Ouverture du panneau : gate serveur (non-staff -> rien)
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:admin:open', function(src, ply)
    if not hasStaff(src, 'helper') then
        -- Silencieux : un non-staff qui presse F10 n'obtient aucune ouverture.
        return
    end
    DB.log('admin', 'info', ply and ply.license,
        ('%s a ouvert le panneau admin'):format(actorName(src)))
    TriggerClientEvent('noxa:admin:grant', src, {
        rank         = ply and ply.staffRank or 'user',
        players      = buildPlayers(),
        jobs         = buildJobs(),
        server       = buildServer(),
        banDurations = (function()
            local keys = {}
            for k in pairs(CFG.Admin.banDurations) do keys[#keys + 1] = k end
            table.sort(keys)
            return keys
        end)(),
    })
end)

-- ---------------------------------------------------------------------
--  Récupération de données à la demande (rafraîchissement de section)
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:admin:fetch', function(src, ply, what, arg)
    if not hasStaff(src, 'helper') then return Noxa.Security.flag(src, 'admin:fetch sans rang') end
    if what == 'players' then
        pushPlayers(src)
    elseif what == 'server' then
        TriggerClientEvent('noxa:admin:data', src, 'server', buildServer())
    elseif what == 'logs' then
        -- Les logs restent réservés aux modérateurs et au-dessus.
        if not hasStaff(src, 'mod') then return end
        local category = (type(arg) == 'string' and arg ~= 'all') and arg or nil
        local sql = 'SELECT category, level, message, created_at FROM noxa_logs '
        local params = {}
        if category then sql = sql .. 'WHERE category = ? '; params[1] = category end
        sql = sql .. 'ORDER BY id DESC LIMIT 60'
        MySQL.query(sql, params, function(rows)
            TriggerClientEvent('noxa:admin:data', src, 'logs', rows or {})
        end)
    end
end)

-- ---------------------------------------------------------------------
--  Table d'actions : chaque action déclare son rang minimal + son handler.
--  handler(src, actor, targetId, params). targetId/params déjà extraits.
-- ---------------------------------------------------------------------

local function resolveTarget(targetId)
    return Noxa.Players.get(tonumber(targetId))
end

local actions = {}

actions.heal = { rank = 'mod', run = function(src, ply, tid)
    TriggerClientEvent('noxa:admin:heal', tid)
    feedback(src, 'Joueur soigné.', 'success')
end }

actions.revive = { rank = 'admin', run = function(src, ply, tid)
    TriggerClientEvent('noxa:admin:revive', tid)
    local t = resolveTarget(tid)
    if t then t:setMeta('isDead', false) end
    DB.log('admin', 'info', nil, ('%s a réanimé src:%s'):format(actorName(src), tid))
    feedback(src, 'Joueur réanimé.', 'success')
end }

actions.freeze = { rank = 'mod', run = function(src, ply, tid, p)
    TriggerClientEvent('noxa:admin:freeze', tid, p.state == true)
    feedback(src, p.state and 'Joueur figé.' or 'Joueur libéré.', 'success')
end }

actions.bring = { rank = 'admin', run = function(src, ply, tid)
    if src == 0 then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    if Noxa.AntiCheat then Noxa.AntiCheat.grace(tid) end
    TriggerClientEvent('noxa:admin:teleport', tid, { x = c.x, y = c.y, z = c.z })
    DB.log('admin', 'info', nil, ('%s a ramené src:%s'):format(actorName(src), tid))
end }

actions['goto'] = { rank = 'mod', run = function(src, ply, tid)
    if src == 0 then return end
    local ped = GetPlayerPed(tid)
    if ped == 0 then return feedback(src, 'Cible introuvable.', 'error') end
    local c = GetEntityCoords(ped)
    TriggerClientEvent('noxa:admin:teleport', src, { x = c.x, y = c.y, z = c.z })
end }

actions.kick = { rank = 'mod', run = function(src, ply, tid, p)
    local name = GetPlayerName(tid)
    if not name then return feedback(src, 'Cible introuvable.', 'error') end
    local reason = (p.reason and p.reason ~= '') and p.reason or 'Comportement contraire au règlement.'
    DB.log('admin', 'warn', GetPlayerIdentifierByType(tid, 'license'),
        ('%s a kické %s : %s'):format(actorName(src), name, reason))
    DropPlayer(tid, ('[Noxa FA] Expulsé : %s'):format(reason))
    feedback(src, ('%s expulsé.'):format(name), 'success')
end }

actions.ban = { rank = 'admin', run = function(src, ply, tid, p)
    local target = resolveTarget(tid)
    if not target then return feedback(src, 'Cible introuvable / non chargée.', 'error') end
    local durKey  = p.duration or 'perm'
    local seconds = CFG.Admin.banDurations[durKey] or tonumber(durKey)
    if not seconds then return feedback(src, 'Durée invalide.', 'error') end
    local expire  = (seconds == 0) and nil or (os.time() + seconds)
    local reason  = (p.reason and p.reason ~= '') and p.reason or 'Comportement contraire au règlement.'
    DB.setAccountBan(target.accountId, reason, expire)
    DB.insertBan({ account_id = target.accountId, license = target.license,
        reason = reason, banned_by = actorName(src), expire = expire })
    DB.log('admin', 'error', target.license,
        ('%s a banni %s (%s) : %s'):format(actorName(src), target:getName(), durKey, reason))
    DropPlayer(tid, ('[Noxa FA] Banni (%s)\nRaison : %s'):format(durKey, reason))
    feedback(src, ('%s banni (%s).'):format(target:getName(), durKey), 'success')
end }

actions.warn = { rank = 'mod', run = function(src, ply, tid, p)
    local target = resolveTarget(tid)
    if not target then return feedback(src, 'Cible introuvable.', 'error') end
    local reason = (p.reason and p.reason ~= '') and p.reason or 'Avertissement.'
    TriggerClientEvent('noxa:notify', target.source, ('⚠ Avertissement staff : %s'):format(reason), 'warning')
    DB.log('admin', 'warn', target.license, ('%s a averti %s : %s'):format(actorName(src), target:getName(), reason))
    feedback(src, ('Avertissement envoyé à %s.'):format(target:getName()), 'success')
end }

actions.setmoney = { rank = 'admin', run = function(src, ply, tid, p)
    local target  = resolveTarget(tid)
    local account = p.account
    local amount  = U.sanitizeAmount(p.amount)
    if not target or (account ~= E.Accounts.CASH and account ~= E.Accounts.BANK) or not amount then
        return feedback(src, 'Paramètres invalides.', 'error')
    end
    local current = target:getMoney(account)
    if amount > current then
        target:addMoney(account, amount - current, 'admin:setmoney')
    elseif amount < current then
        target:removeMoney(account, current - amount, 'admin:setmoney')
    end
    DB.log('admin', 'warn', target.license, ('%s a réglé %s de %s à %s'):format(
        actorName(src), account, target:getName(), U.money(amount)))
    feedback(src, ('%s.%s = %s'):format(target:getName(), account, U.money(amount)), 'success')
end }

actions.givemoney = { rank = 'admin', run = function(src, ply, tid, p)
    local target  = resolveTarget(tid)
    local account = p.account == E.Accounts.CASH and E.Accounts.CASH or E.Accounts.BANK
    local amount  = U.sanitizeAmount(p.amount)
    if not target or not amount then return feedback(src, 'Paramètres invalides.', 'error') end
    if p.remove then
        if not target:removeMoney(account, amount, 'admin:remove') then
            return feedback(src, 'Solde insuffisant.', 'error')
        end
    else
        target:addMoney(account, amount, 'admin:give')
    end
    DB.log('admin', 'warn', target.license, ('%s a %s %s (%s) à %s'):format(
        actorName(src), p.remove and 'retiré' or 'donné', U.money(amount), account, target:getName()))
    feedback(src, 'Opération effectuée.', 'success')
end }

actions.setjob = { rank = 'admin', run = function(src, ply, tid, p)
    local target = resolveTarget(tid)
    if not target or not p.job then return feedback(src, 'Paramètres invalides.', 'error') end
    local ok, err = Noxa.Jobs.setPlayerJob(target, p.job, tonumber(p.grade) or 0, { bypassWhitelist = true })
    if ok then
        DB.log('admin', 'info', target.license, ('%s a affecté %s à %s g%s'):format(
            actorName(src), target:getName(), p.job, tonumber(p.grade) or 0))
        feedback(src, ('%s -> %s'):format(target:getName(), p.job), 'success')
    else
        feedback(src, ('Échec: %s'):format(err or 'inconnu'), 'error')
    end
end }

actions.announce = { rank = 'mod', run = function(src, ply, tid, p)
    local msg = p.message
    if type(msg) ~= 'string' or msg == '' then return feedback(src, 'Message vide.', 'error') end
    TriggerClientEvent('noxa:announce', -1, msg)
    DB.log('admin', 'info', nil, ('%s a annoncé: %s'):format(actorName(src), msg))
    feedback(src, 'Annonce diffusée.', 'success')
end }

-- Téléportation libre (waypoint / coords) — exécutée sur le client demandeur.
actions.tpwaypoint = { rank = 'mod', run = function(src)
    TriggerClientEvent('noxa:admin:tpWaypoint', src)
end }

actions.tpcoords = { rank = 'mod', run = function(src, ply, tid, p)
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) then return feedback(src, 'Coordonnées invalides.', 'error') end
    TriggerClientEvent('noxa:admin:teleport', src, { x = x, y = y, z = z })
end }

-- Véhicules — spawn / réparation / suppression / couleur (côté client demandeur).
actions.spawnvehicle = { rank = 'admin', run = function(src, ply, tid, p)
    if type(p.model) ~= 'string' or p.model == '' then return feedback(src, 'Modèle invalide.', 'error') end
    TriggerClientEvent('noxa:admin:spawnVehicle', src, p.model)
    DB.log('admin', 'info', nil, ('%s a spawn le véhicule %s'):format(actorName(src), p.model))
end }

actions.repairvehicle = { rank = 'mod', run = function(src)
    TriggerClientEvent('noxa:admin:vehicleAct', src, 'repair')
end }

actions.deletevehicle = { rank = 'admin', run = function(src)
    TriggerClientEvent('noxa:admin:vehicleAct', src, 'delete')
end }

actions.colorvehicle = { rank = 'mod', run = function(src, ply, tid, p)
    TriggerClientEvent('noxa:admin:vehicleAct', src, 'color',
        { r = tonumber(p.r) or 0, g = tonumber(p.g) or 0, b = tonumber(p.b) or 0 })
end }

-- ---------------------------------------------------------------------
--  Point d'entrée unique des actions NUI
-- ---------------------------------------------------------------------

Noxa.Security.onNet('noxa:admin:action', function(src, ply, payload)
    if type(payload) ~= 'table' or type(payload.action) ~= 'string' then
        return Noxa.Security.flag(src, 'admin:action malformée')
    end
    local def = actions[payload.action]
    if not def then return Noxa.Security.flag(src, ('admin:action inconnue (%s)'):format(payload.action)) end
    if not hasStaff(src, def.rank) then
        return Noxa.Security.flag(src, ('admin:action %s sans rang'):format(payload.action))
    end
    def.run(src, ply, payload.target, payload.params or {})
    -- Rafraîchit la liste joueurs (l'action a pu en modifier l'état).
    pushPlayers(src)
end)

return Admin
