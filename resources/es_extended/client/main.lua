-- =====================================================================
--  NOXA FA — Compatibilité ESX (client-side)
--  ---------------------------------------------------------------------
--  Expose ESX.PlayerData, ESX.GetPlayerData, ESX.ShowNotification,
--  ESX.TriggerServerCallback et les events esx:playerLoaded / esx:setJob,
--  en se synchronisant sur l'état joueur répliqué par noxa-fa (statebag).
-- =====================================================================

ESX = {}
ESX.PlayerData   = {}
ESX.PlayerLoaded = false

-- ---------------------------------------------------------------------
--  Accès aux données joueur (lecture seule)
-- ---------------------------------------------------------------------
function ESX.GetPlayerData()
    return ESX.PlayerData
end

function ESX.SetPlayerData(key, value)
    ESX.PlayerData[key] = value
end

function ESX.IsPlayerLoaded()
    return ESX.PlayerLoaded
end

-- ---------------------------------------------------------------------
--  Notifications -> NUI custom noxa (pas de ox_lib / pas de feed GTA)
-- ---------------------------------------------------------------------
local NOTIFY_MAP = { info = 'inform', error = 'error', success = 'success', warning = 'warning' }

function ESX.ShowNotification(msg, ntype, length)
    local kind = NOTIFY_MAP[ntype] or (ntype or 'inform')
    -- noxa-fa expose un export client Notify (UI 100 % NUI custom).
    exports['noxa-fa']:Notify(msg, kind)
end

-- Variante répandue dans les scripts ESX.
function ESX.TextUI(msg, ntype)
    exports['noxa-fa']:Notify(msg, NOTIFY_MAP[ntype] or 'inform')
end

RegisterNetEvent('esx:showNotification', function(msg, ntype)
    ESX.ShowNotification(msg, ntype)
end)

-- ---------------------------------------------------------------------
--  Callbacks serveur (TriggerServerCallback)
-- ---------------------------------------------------------------------
local clientCallbacks = {}
local callbackId = 0

function ESX.TriggerServerCallback(name, cb, ...)
    callbackId = callbackId + 1
    clientCallbacks[callbackId] = cb
    TriggerServerEvent('esx:triggerServerCallback', name, callbackId, ...)
end

RegisterNetEvent('esx:serverCallback', function(requestId, ...)
    local cb = clientCallbacks[requestId]
    if cb then
        cb(...)
        clientCallbacks[requestId] = nil
    end
end)

-- ---------------------------------------------------------------------
--  Utilitaires Math (souvent utilisés côté client aussi)
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

-- ---------------------------------------------------------------------
--  getSharedObject (export + event legacy)
-- ---------------------------------------------------------------------
local function getSharedObject() return ESX end

exports('getSharedObject', getSharedObject)

AddEventHandler('esx:getSharedObject', function(cb)
    if type(cb) == 'function' then cb(ESX) end
end)

-- ---------------------------------------------------------------------
--  Synchronisation sur l'état joueur noxa (statebag répliqué)
--  noxa émet 'noxa:client:playerDataUpdated' à chaque changement (argent,
--  job, besoins). On reconstruit ESX.PlayerData et on relaie esx:setJob.
-- ---------------------------------------------------------------------
local function applyNoxaData(d)
    if type(d) ~= 'table' then return end
    local prevJob = ESX.PlayerData.job
    ESX.PlayerData.identifier = d.citizenid
    ESX.PlayerData.name       = d.name
    ESX.PlayerData.money      = d.cash
    ESX.PlayerData.bank       = d.bank
    ESX.PlayerData.metadata   = d.metadata
    ESX.PlayerData.accounts   = {
        { name = 'money', money = d.cash or 0, label = 'Argent' },
        { name = 'bank',  money = d.bank or 0, label = 'Banque' },
    }
    -- Job au format ESX à partir de l'instantané noxa.
    if d.job then
        ESX.PlayerData.job = {
            name        = d.job.name,
            label       = d.job.label,
            grade       = d.job.grade,
            grade_label = d.job.gradeLabel,
            onDuty      = d.job.onDuty and true or false,
        }
        -- Relais esx:setJob si le job a changé.
        if prevJob and prevJob.name and
           (prevJob.name ~= d.job.name or prevJob.grade ~= d.job.grade) then
            TriggerEvent('esx:setJob', ESX.PlayerData.job, prevJob)
        end
    end
end

AddEventHandler('noxa:client:playerDataUpdated', function(value)
    applyNoxaData(value)
    if not ESX.PlayerLoaded then
        ESX.PlayerLoaded = true
        TriggerEvent('esx:playerLoaded', ESX.PlayerData)
    end
end)

-- Réception de l'instantané serveur (cohérent avec esx:playerLoaded ESX).
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    if type(xPlayer) == 'table' then
        for k, v in pairs(xPlayer) do ESX.PlayerData[k] = v end
        ESX.PlayerLoaded = true
    end
end)

-- Si noxa avait déjà chargé les données avant nous (resource restart).
CreateThread(function()
    Wait(500)
    local d = exports['noxa-fa']:GetPlayerData()
    if d then
        applyNoxaData(d)
        ESX.PlayerLoaded = true
    end
end)

print('[es_extended] Couche de compatibilité ESX (Noxa FA) chargée — client.')
