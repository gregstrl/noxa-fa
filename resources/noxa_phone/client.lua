-- =====================================================================
--  NOXA FA — Téléphone (design figé) · client
--  Lie le design exact (html/index.html + html/bridge.js) au serveur noxa-fa.
--  Le client ne stocke rien : toutes les données viennent du serveur
--  autoritaire (events noxa:phone:*). F1 ouvre/ferme.
-- =====================================================================
local isOpen = false

local function openPhone()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('noxa:phone:request')   -- demande l'état initial (BDD)
end

local function closePhone()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand('phone', function()
    if isOpen then closePhone() else openPhone() end
end, false)
RegisterKeyMapping('phone', 'Ouvrir le téléphone NOXA', 'keyboard', 'F1')

-- Fermeture demandée depuis l'UI.
RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------
--  Données serveur -> NUI (le bridge les injecte dans window.PD)
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:phone:bootstrap', function(data)
    SendNUIMessage({ action = 'bootstrap', data = data or {} })
end)
RegisterNetEvent('noxa:phone:contacts', function(list)
    SendNUIMessage({ action = 'contacts', list = list or {} })
end)
RegisterNetEvent('noxa:phone:sms:incoming', function(msg)
    SendNUIMessage({ action = 'smsIncoming', msg = msg or {} })
end)
RegisterNetEvent('noxa:phone:sms:sent', function(msg)
    SendNUIMessage({ action = 'smsSent', msg = msg or {} })
end)
RegisterNetEvent('noxa:phone:sms:threadData', function(data)
    SendNUIMessage({ action = 'smsThread', data = data or {} })
end)
RegisterNetEvent('noxa:phone:tweets', function(list)
    SendNUIMessage({ action = 'tweets', list = list or {} })
end)
RegisterNetEvent('noxa:phone:tweet:new', function(tweet)
    SendNUIMessage({ action = 'tweetNew', tweet = tweet or {} })
end)

-- ---------------------------------------------------------------------
--  Actions UI -> serveur (RegisterNUICallback -> events -> BDD)
-- ---------------------------------------------------------------------
RegisterNUICallback('smsSend', function(b, cb)
    if b and b.to and b.body then TriggerServerEvent('noxa:phone:sms:send', b.to, b.body) end
    cb({ ok = true })
end)
RegisterNUICallback('smsThread', function(b, cb)
    if b and b.peer then TriggerServerEvent('noxa:phone:sms:thread', b.peer) end
    cb({ ok = true })
end)
RegisterNUICallback('tweetPost', function(b, cb)
    if b and b.body then TriggerServerEvent('noxa:phone:tweet:post', b.body) end
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
