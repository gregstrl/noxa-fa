-- =====================================================================
--  NOXA FA — Compatibilité ESX (server-side)
--  ---------------------------------------------------------------------
--  Expose l'API ESX classique en déléguant à noxa-fa. Aucun état n'est
--  dupliqué : chaque appel rejoint l'objet Player VIVANT de noxa-fa
--  (récupéré par export, références Lua↔Lua préservées) — donc zéro
--  désync et zéro contournement de l'autorité serveur.
--
--  Couvre l'essentiel attendu par un script ESX :
--    • exports['es_extended']:getSharedObject() / TriggerEvent('esx:getSharedObject')
--    • ESX.GetPlayerFromId / GetPlayerFromIdentifier / GetPlayers / GetExtendedPlayers
--    • xPlayer.addMoney/removeMoney/getMoney/getAccount/addAccountMoney/...
--    • xPlayer.setJob/getJob  + event esx:setJob
--    • xPlayer.addInventoryItem/removeInventoryItem/getInventoryItem/...
--    • ESX.RegisterServerCallback / RegisterUsableItem / RegisterCommand
--    • events esx:playerLoaded / esx:setJob / esx:addInventoryItem
-- =====================================================================

ESX = {}

-- Mapping des comptes ESX -> comptes noxa. 'black_money' non géré (noxa
-- n'a pas d'argent sale : on renvoie 0 / refuse poliment).
local ACCOUNTS = { money = 'cash', cash = 'cash', bank = 'bank' }

-- ---------------------------------------------------------------------
--  Helpers internes
-- ---------------------------------------------------------------------

--- Récupère l'objet Player VIVANT de noxa-fa (avec ses méthodes).
local function noxa(src)
    return exports['noxa-fa']:GetPlayer(tonumber(src))
end

--- Lit l'instantané répliqué (statebag) pour les libellés cosmétiques.
local function syncedData(src)
    local ok, st = pcall(function() return Player(tonumber(src)).state['noxa:player'] end)
    if ok and type(st) == 'table' then return st end
    return nil
end

--- Construit la table `job` au format ESX à partir de l'objet noxa.
local function buildJob(ply)
    local g  = ply:getJobGradeData() or {}
    local sd = syncedData(ply.source)
    local label = (sd and sd.job and sd.job.label) or ply.job
    return {
        id           = ply.job_grade,
        name         = ply.job,
        label        = label,
        grade        = ply.job_grade,
        grade_name   = g.name or '',
        grade_label  = g.label or '',
        grade_salary = g.salary or 0,
        onDuty       = ply.duty and true or false,
        skin_male    = {},
        skin_female  = {},
    }
end

-- ---------------------------------------------------------------------
--  Fabrique d'un xPlayer ESX (closures sur l'objet noxa vivant)
-- ---------------------------------------------------------------------
local function buildXPlayer(ply)
    local src = ply.source
    local x = {}
    local vars = {}

    -- Champs ESX usuels (lecture directe)
    x.source      = src
    x.playerId    = src
    x.identifier  = ply.license
    x.name        = ply:getName()
    x.firstName   = ply.firstname
    x.lastName    = ply.lastname
    x.job         = buildJob(ply)
    x.group       = (ply.staffRank and ply.staffRank ~= 'user') and ply.staffRank or 'user'

    -- Identité / divers
    function x.getName() return ply:getName() end
    function x.getIdentifier() return ply.license end
    function x.getPlayerId() return src end
    function x.getSource() return src end
    function x.getCoords(vector)
        local c = GetEntityCoords(GetPlayerPed(src))
        if vector then return c end
        return { x = c.x, y = c.y, z = c.z }
    end
    function x.kick(reason) DropPlayer(tostring(src), reason or 'Vous avez été expulsé.') end

    -- Variables libres (xPlayer.set / get)
    function x.set(k, v) vars[k] = v end
    function x.get(k) return vars[k] end
    x.variables = vars

    -- ---- Argent --------------------------------------------------------
    function x.getMoney() return ply.cash end
    function x.addMoney(amount, reason)
        return ply:addMoney('cash', amount, reason or 'esx:addMoney')
    end
    function x.removeMoney(amount, reason)
        return ply:removeMoney('cash', amount, reason or 'esx:removeMoney')
    end
    function x.getAccount(name)
        local acc = ACCOUNTS[name]
        return {
            name  = name,
            money = acc and ply:getMoney(acc) or 0,
            label = name,
            round = true,
        }
    end
    function x.getAccounts(minimal)
        return {
            { name = 'money', money = ply.cash, label = 'Argent', round = true },
            { name = 'bank',  money = ply.bank, label = 'Banque', round = true },
        }
    end
    function x.addAccountMoney(name, amount, reason)
        local acc = ACCOUNTS[name]
        if not acc then return false end
        return ply:addMoney(acc, amount, reason or 'esx:addAccount')
    end
    function x.removeAccountMoney(name, amount, reason)
        local acc = ACCOUNTS[name]
        if not acc then return false end
        return ply:removeMoney(acc, amount, reason or 'esx:removeAccount')
    end
    function x.setAccountMoney(name, amount, reason)
        local acc = ACCOUNTS[name]
        if not acc then return false end
        amount = tonumber(amount) or 0
        local cur = ply:getMoney(acc)
        if amount > cur then return ply:addMoney(acc, amount - cur, reason or 'esx:setAccount') end
        if amount < cur then return ply:removeMoney(acc, cur - amount, reason or 'esx:setAccount') end
        return true
    end
    function x.setMoney(amount, reason) return x.setAccountMoney('money', amount, reason) end

    -- ---- Emploi --------------------------------------------------------
    function x.getJob()
        x.job = buildJob(ply)
        return x.job
    end
    function x.setJob(jobName, grade)
        local previous = x.getJob()
        local ok = ply:setJob(jobName, grade)
        if ok then
            x.job = buildJob(ply)
            TriggerEvent('esx:setJob', src, x.job, previous)
            TriggerClientEvent('esx:setJob', src, x.job)
        end
        return ok
    end

    -- ---- Inventaire ----------------------------------------------------
    function x.addInventoryItem(name, count, meta)
        local ok = ply:addItem(name, count, meta)
        if ok then TriggerClientEvent('esx:addInventoryItem', src, name, count) end
        return ok
    end
    function x.removeInventoryItem(name, count, meta)
        local ok = ply:removeItem(name, count)
        if ok then TriggerClientEvent('esx:removeInventoryItem', src, name, count) end
        return ok
    end
    function x.getInventoryItem(name)
        local payload = ply:invPayload()
        local item = { name = name, count = 0, label = name, weight = 0, usable = true, rare = false, canRemove = true }
        for _, s in ipairs(payload.slots) do
            if s.name == name then
                item.count  = item.count + s.count
                item.label  = s.label
                item.weight = s.weight
            end
        end
        return item
    end
    function x.getInventory(minimal)
        local payload = ply:invPayload()
        local agg = {}
        for _, s in ipairs(payload.slots) do
            local e = agg[s.name]
            if e then
                e.count = e.count + s.count
            else
                agg[s.name] = { name = s.name, count = s.count, label = s.label,
                                weight = s.weight, usable = true, canRemove = true }
            end
        end
        local out = {}
        for _, e in pairs(agg) do out[#out + 1] = e end
        return out
    end
    function x.hasItem(name)
        local c = ply:invCount(name)
        if c > 0 then return x.getInventoryItem(name), c end
        return nil
    end
    function x.canCarryItem(name, count)
        -- noxa borne réellement à l'ajout ; on autorise ici (refus propre côté add).
        return true
    end
    function x.getWeight() return ply:invWeight() end
    function x.getMaxWeight() return ply:invPayload().maxWeight end

    -- ---- Métadonnées / notifications ----------------------------------
    function x.getMeta(k) return ply:getMeta(k) end
    function x.setMeta(k, v) ply:setMeta(k, v) end
    function x.showNotification(msg, ntype)
        TriggerClientEvent('noxa:notify', src, msg, ntype or 'inform')
    end
    function x.triggerEvent(name, ...)
        TriggerClientEvent(name, src, ...)
    end

    return x
end

-- ---------------------------------------------------------------------
--  ESX — accès aux joueurs
-- ---------------------------------------------------------------------
function ESX.GetPlayerFromId(src)
    local ply = noxa(src)
    if not ply then return nil end
    return buildXPlayer(ply)
end

function ESX.GetPlayerFromIdentifier(identifier)
    for _, id in ipairs(GetPlayers()) do
        local ply = noxa(id)
        if ply and ply.license == identifier then return buildXPlayer(ply) end
    end
    return nil
end

--- Liste des sources (ids) connectés. ESX renvoie des nombres.
function ESX.GetPlayers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = tonumber(id) end
    return out
end

--- Joueurs étendus, filtrables (key='job', val='police' ...).
function ESX.GetExtendedPlayers(key, val)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local ply = noxa(id)
        if ply then
            local include = true
            if key == 'job' then include = (ply.job == val)
            elseif key == 'group' then include = ((ply.staffRank or 'user') == val) end
            if include then out[#out + 1] = buildXPlayer(ply) end
        end
    end
    return out
end

function ESX.GetNumPlayers() return #GetPlayers() end

-- ---------------------------------------------------------------------
--  ESX — callbacks serveur (TriggerServerCallback côté client)
-- ---------------------------------------------------------------------
local serverCallbacks = {}

function ESX.RegisterServerCallback(name, cb)
    serverCallbacks[name] = cb
end

RegisterNetEvent('esx:triggerServerCallback', function(name, requestId, ...)
    local src = source
    local cb  = serverCallbacks[name]
    if not cb then
        return print(('[es_extended] callback serveur inconnu: %s'):format(name))
    end
    cb(src, function(...)
        TriggerClientEvent('esx:serverCallback', src, requestId, ...)
    end, ...)
end)

-- ---------------------------------------------------------------------
--  ESX — objets utilisables (RegisterUsableItem)
--  Branché sur l'inventaire noxa : quand un item est utilisé in-game,
--  noxa émet 'noxa:item:used' (src, name, slot) que l'on route ici.
-- ---------------------------------------------------------------------
ESX.UsableItemsCallbacks = {}

function ESX.RegisterUsableItem(item, cb)
    ESX.UsableItemsCallbacks[item] = cb
end

function ESX.UseItem(src, item, ...)
    local cb = ESX.UsableItemsCallbacks[item]
    if cb then cb(src, item, ...) end
end

AddEventHandler('noxa:item:used', function(src, name, slot)
    ESX.UseItem(src, name, slot)
end)

-- ---------------------------------------------------------------------
--  ESX — commandes (wrapper minimal sur RegisterCommand natif)
-- ---------------------------------------------------------------------
function ESX.RegisterCommand(name, group, cb, allowConsole, suggestion)
    RegisterCommand(name, function(source, args, raw)
        local xPlayer = source > 0 and ESX.GetPlayerFromId(source) or nil
        if source > 0 and not xPlayer then return end
        cb(xPlayer or { source = 0 }, args, function(msg)
            if source > 0 then
                TriggerClientEvent('noxa:notify', source, msg, 'error')
            else
                print(msg)
            end
        end, raw)
    end, false)
end

-- ---------------------------------------------------------------------
--  ESX — utilitaires fréquemment utilisés par les scripts
-- ---------------------------------------------------------------------
ESX.Math = {}
function ESX.Math.Round(value, decimals)
    if decimals and decimals > 0 then
        local m = 10 ^ decimals
        return math.floor(value * m + 0.5) / m
    end
    return math.floor(value + 0.5)
end
function ESX.Math.GroupDigits(value)
    local left, num, right = tostring(value):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end
function ESX.Math.Trim(value)
    if value then return (tostring(value):gsub('^%s*(.-)%s*$', '%1')) end
    return nil
end

ESX.Table = {}
function ESX.Table.SizeOf(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function ESX.Trace(msg) print(('[es_extended] %s'):format(msg)) end

-- ---------------------------------------------------------------------
--  getSharedObject (export + event legacy)
-- ---------------------------------------------------------------------
local function getSharedObject() return ESX end

exports('getSharedObject', getSharedObject)

-- API legacy : TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
AddEventHandler('esx:getSharedObject', function(cb)
    if type(cb) == 'function' then cb(ESX) end
end)

-- ---------------------------------------------------------------------
--  Miroir des événements de cycle de vie noxa -> ESX
-- ---------------------------------------------------------------------

--- Instantané sérialisable (sans fonctions) destiné au client.
local function clientSnapshot(ply, xPlayer)
    return {
        source     = ply.source,
        identifier = ply.license,
        name       = ply:getName(),
        job        = xPlayer.job,
        money      = ply.cash,
        accounts   = xPlayer.getAccounts(),
        inventory  = xPlayer.getInventory(),
        metadata   = ply.metadata,
        firstName  = ply.firstname,
        lastName   = ply.lastname,
    }
end

AddEventHandler('noxa:playerLoaded', function(src, ply)
    local xPlayer = buildXPlayer(ply)
    -- Serveur : signature ESX (playerId, xPlayer, isNew)
    TriggerEvent('esx:playerLoaded', src, xPlayer, false)
    -- Client : on transmet un instantané lecture seule.
    TriggerClientEvent('esx:playerLoaded', src, clientSnapshot(ply, xPlayer))
end)

AddEventHandler('noxa:playerUnloaded', function(src)
    TriggerEvent('esx:playerDropped', src)
end)

print('[es_extended] Couche de compatibilité ESX (Noxa FA) chargée — server.')
