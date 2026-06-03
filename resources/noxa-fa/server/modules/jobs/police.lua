-- =====================================================================
--  NOXA FA — Job actif POLICE (server-side)
--  • Menottage, fouille, amende (facture LSPD), emprisonnement, MDT.
--  • Toute action revérifie côté serveur : job == police ET en service,
--    cible chargée ET à portée. Aucune confiance au client.
--  • Chaque action sensible est journalisée (noxa_logs).
-- =====================================================================

Noxa = Noxa or {}

local U   = Noxa.Utils
local E   = Noxa.Enums
local DB  = Noxa.DB
local S   = Noxa.Security
local CFG = Noxa.Config.JobActions.police

-- ---------------------------------------------------------------------
--  Gardes communes
-- ---------------------------------------------------------------------

--- Retourne l'objet Player si la source est un policier EN SERVICE, sinon nil.
local function copOnDuty(src)
    local ply = Noxa.Players.get(src)
    if not ply or ply.job ~= 'police' or not ply.duty then return nil end
    return ply
end

--- Distance serveur entre l'acteur et sa cible (anti-triche de portée).
local function inRange(src, targetId)
    local tped = GetPlayerPed(targetId)
    if not tped or tped == 0 then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(tped)) <= CFG.actionDistance
end

local function deny(src, msg) TriggerClientEvent('noxa:notify', src, msg, 'error') end

--- Enregistre une commande réservée à la police en service, cible à portée.
---@param name string
---@param handler fun(src:integer, ply:table, target:table, args:table)
local function copCommand(name, handler)
    RegisterCommand(name, function(src, args)
        local ply = copOnDuty(src)
        if not ply then return deny(src, 'Réservé à la police en service.') end
        local tid = tonumber(args[1])
        local target = tid and Noxa.Players.get(tid)
        if not target then return deny(src, 'Cible introuvable / non chargée.') end
        if not inRange(src, tid) then return deny(src, 'Cible trop éloignée.') end
        handler(src, ply, target, args)
    end, false)
end

-- ---------------------------------------------------------------------
--  /menottes [id] — bascule l'état menotté de la cible
-- ---------------------------------------------------------------------
copCommand('menottes', function(src, ply, target)
    local cuffed = not (target.metadata.cuffed == true)
    target:setMeta('cuffed', cuffed)
    TriggerClientEvent('noxa:police:cuff', target.source, cuffed)
    TriggerClientEvent('noxa:notify', src, cuffed and 'Suspect menotté.' or 'Suspect démenotté.', 'success')
    TriggerClientEvent('noxa:notify', target.source, cuffed and 'Vous avez été menotté.' or 'Vous avez été démenotté.', 'inform')
    DB.log('job', 'info', target.license,
        ('%s a %s %s'):format(ply:getName(), cuffed and 'menotté' or 'démenotté', target:getName()))
end)

-- ---------------------------------------------------------------------
--  /fouille [id] — affiche l'inventaire & les espèces de la cible (lecture)
-- ---------------------------------------------------------------------
copCommand('fouille', function(src, ply, target)
    local payload = target:invPayload()
    TriggerClientEvent('noxa:police:searchResult', src, {
        name  = target:getName(),
        id    = target.source,
        cash  = target.cash,
        items = payload.slots or {},
    })
    DB.log('job', 'info', target.license, ('%s a fouillé %s'):format(ply:getName(), target:getName()))
end)

-- ---------------------------------------------------------------------
--  /amende [id] [montant] [raison...] — émet une facture (caisse LSPD)
-- ---------------------------------------------------------------------
copCommand('amende', function(src, ply, target, args)
    local amount = U.sanitizeAmount(args[2])
    if not amount or amount < 1 or amount > CFG.maxFine then
        return deny(src, ('Montant invalide (1 - %s).'):format(U.money(CFG.maxFine)))
    end
    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Infraction au code de la route.' end
    DB.createInvoice({
        emitter_cid  = ply.citizenid,
        emitter_name = ply:getName(),
        society      = 'lspd',
        target_cid   = target.citizenid,
        amount       = amount,
        label        = ('Amende — %s'):format(reason),
    })
    TriggerClientEvent('noxa:notify', src, ('Amende de %s émise à %s.'):format(U.money(amount), target:getName()), 'success')
    TriggerClientEvent('noxa:notify', target.source, ('⚠ Amende reçue : %s (voir banque).'):format(U.money(amount)), 'warning')
    DB.log('job', 'warn', target.license, ('%s a verbalisé %s de %s : %s'):format(ply:getName(), target:getName(), U.money(amount), reason))
end)

-- ---------------------------------------------------------------------
--  /emprisonner [id] [minutes] — incarcère la cible
-- ---------------------------------------------------------------------
copCommand('emprisonner', function(src, ply, target, args)
    local minutes = U.clampInt(args[2] or 0, 1, CFG.maxJail)
    if not minutes then return deny(src, ('Durée invalide (1 - %d min).'):format(CFG.maxJail)) end
    target:setMeta('jail', os.time() + minutes * 60)
    target:setMeta('cuffed', false)
    TriggerClientEvent('noxa:police:cuff', target.source, false)
    if Noxa.AntiCheat then Noxa.AntiCheat.grace(target.source) end
    TriggerClientEvent('noxa:police:jail', target.source, minutes, CFG.jail)
    TriggerClientEvent('noxa:notify', src, ('%s emprisonné·e %d min.'):format(target:getName(), minutes), 'success')
    DB.log('job', 'warn', target.license, ('%s a emprisonné %s (%d min)'):format(ply:getName(), target:getName(), minutes))
end)

-- ---------------------------------------------------------------------
--  Libération : demandée par le client en fin de peine (revérifiée serveur)
-- ---------------------------------------------------------------------
S.onNet('noxa:police:requestRelease', function(src, ply)
    local until_ = ply.metadata.jail
    if not until_ or os.time() < (until_ - 5) then return end  -- peine non purgée
    ply:setMeta('jail', nil)
    if Noxa.AntiCheat then Noxa.AntiCheat.grace(src) end
    TriggerClientEvent('noxa:police:release', src, CFG.release)
end)

-- ---------------------------------------------------------------------
--  MDT — données des effectifs en service (NUI)
-- ---------------------------------------------------------------------
S.onNet('noxa:police:mdt:fetch', function(src, ply)
    if ply.job ~= 'police' then return S.flag(src, 'mdt sans être police') end
    local units = {}
    for _, p in pairs(Noxa.Players.getAll()) do
        if p.job == 'police' and p.duty then
            local g = E.getJobGrade('police', p.job_grade)
            units[#units + 1] = { id = p.source, name = p:getName(), grade = g and g.label or '' }
        end
    end
    TriggerClientEvent('noxa:police:mdt:data', src, { officer = ply:getName(), units = units })
end)
