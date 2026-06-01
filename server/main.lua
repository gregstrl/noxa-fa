-- =====================================================================
--  NOXA FA — Point d'entrée serveur
--  Bootstrap, exports framework, commandes utilitaires de base.
-- =====================================================================

local U = Noxa.Utils
local E = Noxa.Enums

-- ---------------------------------------------------------------------
--  Exports framework (accès à l'objet joueur depuis d'autres ressources)
-- ---------------------------------------------------------------------

exports('GetPlayer', function(src)
    return Noxa.Players.get(src)
end)

exports('GetPlayerByCitizenId', function(citizenid)
    return Noxa.Players.getByCitizenId(citizenid)
end)

exports('GetPlayers', function()
    return Noxa.Players.getAll()
end)

-- ---------------------------------------------------------------------
--  Commandes admin de base (gardes server-side sur le rang staff)
-- ---------------------------------------------------------------------

--- Vérifie que la source possède au moins le rang requis.
local function hasStaff(src, minRank)
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    return (E.StaffRanks[ply.staffRank] or 0) >= (E.StaffRanks[minRank] or 99)
end

-- /setjob [id] [job] [grade]
RegisterCommand('setjob', function(src, args)
    if src ~= 0 and not hasStaff(src, 'admin') then return end
    local target = Noxa.Players.get(tonumber(args[1]))
    if not target then return end
    if target:setJob(args[2], tonumber(args[3]) or 0) then
        U.print('info', '%s -> job %s grade %s', target:getName(), target.job, target.job_grade)
    end
end, true)

-- /givemoney [id] [account] [amount]
RegisterCommand('givemoney', function(src, args)
    if src ~= 0 and not hasStaff(src, 'admin') then return end
    local target = Noxa.Players.get(tonumber(args[1]))
    if not target then return end
    target:addMoney(args[2] or 'cash', tonumber(args[3]) or 0, 'admin:givemoney')
end, true)

-- ---------------------------------------------------------------------
--  Démarrage
-- ---------------------------------------------------------------------

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    U.print('info', '====================================')
    U.print('info', ' Noxa FA core démarré (v0.1.0)')
    U.print('info', ' Modules : core, economy, characters')
    U.print('info', '====================================')
end)
