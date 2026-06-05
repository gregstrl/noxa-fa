-- =====================================================================
--  NOXA FA — Activités légales : pêche & chasse (server-side, autoritaire)
--  • Achat d'outil, cueillette chronométrée (butin tiré au sort, borné),
--    et vente sur place. Proximité, outil requis, cooldown et butin sont
--    recalculés serveur. Le client n'émet qu'une clé d'activité.
--  • Pas de table SQL : le butin vit dans l'inventaire (déjà persisté).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Activities = {}

local Act  = Noxa.Activities
local CFG  = Noxa.Config
local ACFG = Noxa.Config.Activities
local S    = Noxa.Security
local Eco  = Noxa.Economy

-- Cooldowns de cueillette : [src] = { [key] = GetGameTimer() }.
local lastGather = {}

-- Proximité serveur d'un POI dont interact.type == itype (cf. C.POI).
local function nearActivity(src, itype, maxDist)
    maxDist = maxDist or 4.0
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, cat in pairs(CFG.POI) do
        local it = cat.interact
        if it and it.type == itype and cat.points then
            for _, pt in ipairs(cat.points) do
                if #(pos - vector3(pt.x + 0.0, pt.y + 0.0, pt.z + 0.0)) <= maxDist then
                    return true
                end
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------
--  Achat d'outil (canne / couteau) — réglé en liquide.
-- ---------------------------------------------------------------------
S.onNet('noxa:act:buyTool', function(src, ply, key)
    local a = ACFG[tostring(key)]
    if not a then return S.flag(src, 'act:buyTool clé inconnue') end
    if not nearActivity(src, key, 4.0) then return S.flag(src, 'act:buyTool hors zone') end
    if ply:hasItem(a.tool, 1) then
        return TriggerClientEvent('noxa:notify', src, 'Vous possédez déjà cet outil.', 'inform')
    end
    if ply:getMoney('cash') < (a.toolPrice or 0) then
        return TriggerClientEvent('noxa:notify', src, 'Pas assez de liquide.', 'error')
    end
    if not Eco.remove(src, 'cash', a.toolPrice, 'activity_tool') then return end
    if not ply:addItem(a.tool, 1) then
        Eco.add(src, 'cash', a.toolPrice, 'activity_tool_refund')
        return TriggerClientEvent('noxa:notify', src, 'Inventaire plein.', 'error')
    end
    local tool = CFG.getItem(a.tool)
    TriggerClientEvent('noxa:notify', src,
        ('Acheté : %s.'):format(tool and tool.label or a.tool), 'success')
end)

-- ---------------------------------------------------------------------
--  Cueillette — exige l'outil, applique un cooldown, tire le butin.
-- ---------------------------------------------------------------------
S.onNet('noxa:act:gather', function(src, ply, key)
    local a = ACFG[tostring(key)]
    if not a then return S.flag(src, 'act:gather clé inconnue') end
    if not nearActivity(src, key, 5.0) then return S.flag(src, 'act:gather hors zone') end
    if not ply:hasItem(a.tool, 1) then
        local tool = CFG.getItem(a.tool)
        return TriggerClientEvent('noxa:notify', src,
            ('Il vous faut : %s.'):format(tool and tool.label or a.tool), 'error')
    end
    lastGather[src] = lastGather[src] or {}
    local now = GetGameTimer()
    if now - (lastGather[src][key] or 0) < (a.cooldown or 0) then
        return TriggerClientEvent('noxa:notify', src, 'Patientez un instant.', 'inform')
    end
    lastGather[src][key] = now

    -- Tirage indépendant par entrée de butin (probabilités bornées).
    local got = {}
    for _, l in ipairs(a.loot) do
        if math.random(100) <= l.chance then
            local n = math.random(l.amount[1], l.amount[2])
            if n > 0 and ply:addItem(l.item, n) then
                got[#got + 1] = ('%dx %s'):format(n, l.label)
            end
        end
    end
    if #got == 0 then
        return TriggerClientEvent('noxa:notify', src, 'Vous repartez les mains vides…', 'inform')
    end
    TriggerClientEvent('noxa:notify', src, ('Obtenu : %s.'):format(table.concat(got, ', ')), 'success')
end)

-- ---------------------------------------------------------------------
--  Vente sur place — écoule tout le butin de l'activité contre du liquide.
-- ---------------------------------------------------------------------
S.onNet('noxa:act:sell', function(src, ply, key)
    local a = ACFG[tostring(key)]
    if not a then return S.flag(src, 'act:sell clé inconnue') end
    if not nearActivity(src, key, 5.0) then return S.flag(src, 'act:sell hors zone') end

    local earned = 0
    for _, l in ipairs(a.loot) do
        local have = ply:invCount(l.item)
        if have > 0 and l.sell and ply:removeItem(l.item, have) then
            earned = earned + (l.sell * have)
        end
    end
    if earned <= 0 then
        return TriggerClientEvent('noxa:notify', src, 'Vous n\'avez rien à vendre.', 'inform')
    end
    Eco.add(src, 'cash', earned, 'activity_sale')
    TriggerClientEvent('noxa:notify', src, ('Vente : +%d$.'):format(earned), 'success')
end)

AddEventHandler('playerDropped', function()
    lastGather[source] = nil
end)

return Act
