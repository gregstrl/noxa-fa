-- =====================================================================
--  NOXA FA — Trafic de drogue (server-side, autoritaire)
--  Chaîne : récolte (champ) -> transformation (labo) -> vente (revendeur).
--  • Chaque action VÉRIFIE côté serveur la proximité d'un POI compatible
--    (C.POI), un cooldown anti-spam et la possession réelle des items.
--  • Le client ne transmet QUE le type de drogue : aucune quantité, aucun
--    prix, aucune position de confiance. Tout est recalculé ici.
--  • Aucune table SQL dédiée : les drogues vivent dans l'inventaire (déjà
--    persisté en JSON, anti-dupe) ; les cooldowns sont en mémoire serveur.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Drugs = {}

local Drugs = Noxa.Drugs
local CFG   = Noxa.Config
local DCFG  = Noxa.Config.Drugs
local S     = Noxa.Security
local Eco   = Noxa.Economy

-- Cooldowns de récolte par joueur : [src] = GetGameTimer() de la dernière.
local lastHarvest = {}

-- ---------------------------------------------------------------------
--  Proximité : le joueur est-il réellement sur un POI du bon type ?
--  On scanne C.POI (source unique des lieux) et on compare la position
--  serveur du ped. extra (clé de drogue) filtre champ/labo par produit.
-- ---------------------------------------------------------------------
local function nearInteract(src, itype, extra, maxDist)
    maxDist = maxDist or 3.0
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, cat in pairs(CFG.POI) do
        local it = cat.interact
        if it and it.type == itype and (extra == nil or it.extra == extra) and cat.points then
            for _, pt in ipairs(cat.points) do
                if #(pos - vector3(pt.x + 0.0, pt.y + 0.0, pt.z + 0.0)) <= maxDist then
                    return true
                end
            end
        end
    end
    return false
end

local function randRange(t)
    return math.random(t[1], t[2])
end

-- ---------------------------------------------------------------------
--  Alerte police : prévient les agents en service d'une vente de rue.
--  Coût RP du trafic : probabilité paramétrée (DCFG.policeAlertChance).
-- ---------------------------------------------------------------------
local function alertPolice(src)
    if math.random(100) > (DCFG.policeAlertChance or 0) then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, p in pairs(Noxa.Players.getAll()) do
        if p.job == 'police' and p.duty then
            TriggerClientEvent('noxa:notify', p.source,
                '🚨 Trafic de stupéfiants signalé en ville.', 'warning')
            TriggerClientEvent('noxa:drug:dispatch', p.source,
                { x = pos.x, y = pos.y, z = pos.z })
        end
    end
end

-- ---------------------------------------------------------------------
--  RÉCOLTE — au champ/dépôt : produit la matière première de la drogue.
-- ---------------------------------------------------------------------
S.onNet('noxa:drug:harvest', function(src, ply, key)
    local d = DCFG.types[tostring(key)]
    if not d then return S.flag(src, 'drug:harvest clé inconnue') end
    if not nearInteract(src, 'drug_harvest', key, 3.5) then
        return S.flag(src, 'drug:harvest hors zone')
    end
    -- Cooldown anti-spam (le client a déjà joué l'animation côté présentation).
    local now  = GetGameTimer()
    local last = lastHarvest[src] or 0
    if now - last < (DCFG.harvestCooldown or 0) then
        return TriggerClientEvent('noxa:notify', src, 'Patientez avant de récolter à nouveau.', 'inform')
    end
    lastHarvest[src] = now

    local amount = randRange(d.harvest.amount)
    local ok = ply:addItem(d.raw, amount)
    if not ok then
        return TriggerClientEvent('noxa:notify', src, 'Vous ne pouvez plus rien porter.', 'error')
    end
    local raw = CFG.getItem(d.raw)
    TriggerClientEvent('noxa:notify', src,
        ('Récolté %dx %s.'):format(amount, raw and raw.label or d.raw), 'success')
end)

-- ---------------------------------------------------------------------
--  TRANSFORMATION — au labo : convertit `need` matières -> `give` produits.
-- ---------------------------------------------------------------------
S.onNet('noxa:drug:process', function(src, ply, key)
    local d = DCFG.types[tostring(key)]
    if not d then return S.flag(src, 'drug:process clé inconnue') end
    if not nearInteract(src, 'drug_process', key, 3.5) then
        return S.flag(src, 'drug:process hors zone')
    end
    local need = d.process.need or 1
    if not ply:hasItem(d.raw, need) then
        local raw = CFG.getItem(d.raw)
        return TriggerClientEvent('noxa:notify', src,
            ('Il faut %dx %s pour transformer.'):format(need, raw and raw.label or d.raw), 'error')
    end
    if not ply:removeItem(d.raw, need) then return end
    local give = d.process.give or 1
    if not ply:addItem(d.product, give) then
        -- Inventaire plein après retrait : on rembourse la matière première.
        ply:addItem(d.raw, need)
        return TriggerClientEvent('noxa:notify', src, 'Inventaire plein.', 'error')
    end
    local prod = CFG.getItem(d.product)
    TriggerClientEvent('noxa:notify', src,
        ('Transformation : %dx %s.'):format(give, prod and prod.label or d.product), 'success')
end)

-- ---------------------------------------------------------------------
--  VENTE — au revendeur : écoule les produits finis contre du liquide.
--  Plafonné à DCFG.sellMax unités/transaction ; prix tiré dans la
--  fourchette par type. Peut déclencher une alerte police.
-- ---------------------------------------------------------------------
S.onNet('noxa:drug:sell', function(src, ply)
    if not nearInteract(src, 'drug_sell', nil, 3.5) then
        return S.flag(src, 'drug:sell hors zone')
    end
    local cap   = DCFG.sellMax or 10
    local total = 0
    local earned = 0

    for _, d in pairs(DCFG.types) do
        if total >= cap then break end
        local have = ply:invCount(d.product)
        if have > 0 then
            local n = math.min(have, cap - total)
            if n > 0 and ply:removeItem(d.product, n) then
                local unit = randRange(d.sell.price)
                earned = earned + (unit * n)
                total  = total + n
            end
        end
    end

    if total <= 0 then
        return TriggerClientEvent('noxa:notify', src, 'Vous n\'avez rien à vendre.', 'inform')
    end
    Eco.add(src, 'cash', earned, 'drug_sale')
    TriggerClientEvent('noxa:notify', src,
        ('Vendu %d unité(s) pour %d$.'):format(total, earned), 'success')
    alertPolice(src)
end)

-- Nettoyage des cooldowns à la déconnexion.
AddEventHandler('playerDropped', function()
    lastHarvest[source] = nil
end)

return Drugs
