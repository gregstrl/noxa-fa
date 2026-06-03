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

-- Note : les commandes de staff (kick, ban, job, setmoney, revive...) sont
-- regroupées dans le module Administration (server/modules/admin/server.lua).
-- main.lua reste minimal : exports framework + bannière de démarrage.

-- Expose l'API sociétés (lecture) aux autres ressources de façon homogène.
exports('GetSociety', function(name)
    return {
        balance = Noxa.Societies.getBalance(name),
        exists  = Noxa.Societies.exists(name),
    }
end)

-- ---------------------------------------------------------------------
--  Démarrage
-- ---------------------------------------------------------------------

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    U.print('info', '====================================')
    U.print('info', ' Noxa FA core démarré (v0.5.0)')
    U.print('info', ' Modules : core, config-manager, societies,')
    U.print('info', '           economy, jobs, banking, characters, admin,')
    U.print('info', '           world (shop/fuel), properties, phone')
    U.print('info', '====================================')
end)
