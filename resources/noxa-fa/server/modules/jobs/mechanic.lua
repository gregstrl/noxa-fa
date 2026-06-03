-- =====================================================================
--  NOXA FA — Job actif MÉCANICIEN (server-side)
--  • Réparation : réservée au métier mécanicien, consomme un kit, délai
--    serveur de référence. L'item est retiré côté serveur (anti-dupe)
--    AVANT d'autoriser le client à lancer l'animation/réparation.
-- =====================================================================

Noxa = Noxa or {}

local U   = Noxa.Utils
local DB  = Noxa.DB
local S   = Noxa.Security
local CFG = Noxa.Config.JobActions.mechanic

-- ---------------------------------------------------------------------
--  Demande de réparation (le client a déjà repéré un véhicule à portée)
-- ---------------------------------------------------------------------
S.onNet('noxa:mechanic:repairRequest', function(src, ply)
    if ply.job ~= 'mechanic' then
        return TriggerClientEvent('noxa:notify', src, 'Réservé aux mécaniciens.', 'error')
    end
    if not ply:hasItem(CFG.repairItem, CFG.repairCount) then
        return TriggerClientEvent('noxa:notify', src, 'Kit de réparation requis.', 'error')
    end
    -- Consommation immédiate (autorité serveur, anti double-réparation).
    if not ply:removeItem(CFG.repairItem, CFG.repairCount) then
        return TriggerClientEvent('noxa:notify', src, 'Kit de réparation introuvable.', 'error')
    end
    TriggerClientEvent('noxa:mechanic:repairStart', src, CFG.repairTime)
    DB.log('job', 'info', ply.license, ('%s a lancé une réparation'):format(ply:getName()))
end)
