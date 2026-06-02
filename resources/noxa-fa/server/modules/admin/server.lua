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

return Admin
