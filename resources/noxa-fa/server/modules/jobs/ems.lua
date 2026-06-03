-- =====================================================================
--  NOXA FA — Job actif EMS (server-side)
--  • État inconscient autoritaire (metadata.isDead) déclaré par le client à
--    la mort, vérifié serveur, diffusé aux EMS en service.
--  • Réanimation / soin réservés aux EMS en service, cible à portée.
-- =====================================================================

Noxa = Noxa or {}

local U   = Noxa.Utils
local E   = Noxa.Enums
local DB  = Noxa.DB
local S   = Noxa.Security
local CFG = Noxa.Config.JobActions.ems

-- ---------------------------------------------------------------------
--  Gardes
-- ---------------------------------------------------------------------
local function emsOnDuty(src)
    local ply = Noxa.Players.get(src)
    if not ply or ply.job ~= 'ambulance' or not ply.duty then return nil end
    return ply
end

local function inRange(src, targetId)
    local tped = GetPlayerPed(targetId)
    if not tped or tped == 0 then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(tped)) <= CFG.actionDistance
end

local function deny(src, msg) TriggerClientEvent('noxa:notify', src, msg, 'error') end

local function emsCommand(name, handler)
    RegisterCommand(name, function(src, args)
        local ply = emsOnDuty(src)
        if not ply then return deny(src, 'Réservé à l\'EMS en service.') end
        local tid = tonumber(args[1])
        local target = tid and Noxa.Players.get(tid)
        if not target then return deny(src, 'Cible introuvable / non chargée.') end
        if not inRange(src, tid) then return deny(src, 'Cible trop éloignée.') end
        handler(src, ply, target, args)
    end, false)
end

-- ---------------------------------------------------------------------
--  Déclaration de décès par le client (état autoritaire serveur)
-- ---------------------------------------------------------------------
S.onNet('noxa:ems:death', function(src, ply)
    if ply.metadata.isDead then return end
    ply:setMeta('isDead', true)
    ply.metadata.deathAt = os.time()  -- horodatage pour le bleedout (respawn auto)
    DB.log('job', 'info', ply.license, ('%s est inconscient'):format(ply:getName()))
    -- Alerte les EMS en service (position approximative).
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, p in pairs(Noxa.Players.getAll()) do
        if p.job == 'ambulance' and p.duty and p.source ~= src then
            TriggerClientEvent('noxa:notify', p.source,
                ('🚑 Patient inconscient : %s'):format(ply:getName()), 'warning')
            TriggerClientEvent('noxa:ems:alert', p.source,
                { name = ply:getName(), x = coords.x, y = coords.y, z = coords.z })
        end
    end
end)

-- ---------------------------------------------------------------------
--  Respawn auto (bleedout) : anti-blocage si aucun EMS disponible.
--  Autorisé seulement après le délai d'agonie ; renvoie à l'hôpital.
-- ---------------------------------------------------------------------
S.onNet('noxa:ems:selfRespawn', function(src, ply)
    if not ply.metadata.isDead then return end
    local since = os.time() - (ply.metadata.deathAt or 0)
    if since < CFG.deathBleedout then
        return TriggerClientEvent('noxa:notify', src,
            ('Patientez encore %ds avant de réapparaître.'):format(CFG.deathBleedout - since), 'inform')
    end
    ply:setMeta('isDead', false)
    ply.metadata.deathAt = nil
    TriggerClientEvent('noxa:admin:revive', src)
    TriggerClientEvent('noxa:ems:respawn', src, CFG.hospital)
    DB.log('job', 'info', ply.license, ('%s a réapparu à l\'hôpital (bleedout)'):format(ply:getName()))
end)

-- ---------------------------------------------------------------------
--  /ranimer [id] — réanime une cible inconsciente
-- ---------------------------------------------------------------------
emsCommand('ranimer', function(src, ply, target)
    if not target.metadata.isDead then
        return deny(src, 'Cette personne n\'est pas inconsciente.')
    end
    target:setMeta('isDead', false)
    TriggerClientEvent('noxa:admin:revive', target.source)  -- réutilise l'effet de réanimation
    TriggerClientEvent('noxa:notify', src, ('%s réanimé·e.'):format(target:getName()), 'success')
    TriggerClientEvent('noxa:notify', target.source, 'Vous avez été réanimé·e par l\'EMS.', 'success')
    DB.log('job', 'info', target.license, ('%s a réanimé %s'):format(ply:getName(), target:getName()))
end)

-- ---------------------------------------------------------------------
--  /soigner [id] — soigne (santé + armure légère) une cible consciente
-- ---------------------------------------------------------------------
emsCommand('soigner', function(src, ply, target)
    if target.metadata.isDead then
        return deny(src, 'Patient inconscient : utilisez /ranimer.')
    end
    TriggerClientEvent('noxa:admin:heal', target.source)
    TriggerClientEvent('noxa:notify', src, ('%s soigné·e.'):format(target:getName()), 'success')
    TriggerClientEvent('noxa:notify', target.source, 'Vous avez été soigné·e par l\'EMS.', 'success')
    DB.log('job', 'info', target.license, ('%s a soigné %s'):format(ply:getName(), target:getName()))
end)
