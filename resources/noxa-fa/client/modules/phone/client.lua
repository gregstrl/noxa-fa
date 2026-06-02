-- =====================================================================
--  NOXA FA — Téléphone (client-side) : pont NUI <-> serveur
--  Touche F1 : ouvre/ferme le smartphone NUI custom. Le client ne stocke
--  rien de sensible : toutes les données viennent du serveur autoritaire.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

local isOpen = false

local function openPhone()
    if isOpen then return end
    isOpen = true
    NUI.setFocus(true)
    NUI.send('phone', 'open', {})
    TriggerServerEvent('noxa:phone:request')
end

local function closePhone()
    if not isOpen then return end
    isOpen = false
    NUI.setFocus(false)
    NUI.send('phone', 'close', {})
end

RegisterCommand('phone', function()
    if isOpen then closePhone() else openPhone() end
end, false)
RegisterKeyMapping('phone', 'Ouvrir le téléphone', 'keyboard', Noxa.Config.Phone.openKey or 'F1')

-- ---------------------------------------------------------------------
--  Données serveur -> NUI
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:phone:bootstrap', function(data)
    -- Complète avec les soldes du HUD (statebag local, lecture seule).
    local pd = Noxa.GetPlayerData and Noxa.GetPlayerData() or {}
    data.bank = pd.bank or 0
    data.cash = pd.cash or 0
    NUI.send('phone', 'bootstrap', data)
end)

RegisterNetEvent('noxa:phone:contacts', function(list)
    NUI.send('phone', 'contacts', { list = list or {} })
end)

RegisterNetEvent('noxa:phone:sms:incoming', function(msg)
    NUI.send('phone', 'smsIncoming', msg or {})
    if not isOpen then
        Noxa.UI.notify(('📱 SMS de %s'):format(msg and msg.from or '???'), 'inform')
    end
end)

RegisterNetEvent('noxa:phone:sms:sent', function(msg)
    NUI.send('phone', 'smsSent', msg or {})
end)

RegisterNetEvent('noxa:phone:sms:threadData', function(data)
    NUI.send('phone', 'smsThread', data or {})
end)

RegisterNetEvent('noxa:phone:tweets', function(list)
    NUI.send('phone', 'tweets', { list = list or {} })
end)

RegisterNetEvent('noxa:phone:tweet:new', function(tweet)
    NUI.send('phone', 'tweetNew', tweet or {})
end)

-- Rafraîchit le solde affiché dans l'app Banque du téléphone.
AddEventHandler('noxa:client:playerDataUpdated', function(data)
    if isOpen then NUI.send('phone', 'sync', { bank = data.bank or 0, cash = data.cash or 0 }) end
end)

-- ---------------------------------------------------------------------
--  Callbacks NUI -> serveur
-- ---------------------------------------------------------------------
RegisterNUICallback('phoneClose', function(_, cb) closePhone(); cb('ok') end)

RegisterNUICallback('phoneContactAdd', function(b, cb)
    if b.name and b.number then TriggerServerEvent('noxa:phone:contact:add', b.name, b.number) end
    cb('ok')
end)
RegisterNUICallback('phoneContactDelete', function(b, cb)
    if b.id then TriggerServerEvent('noxa:phone:contact:delete', b.id) end
    cb('ok')
end)
RegisterNUICallback('phoneSmsSend', function(b, cb)
    if b.to and b.body then TriggerServerEvent('noxa:phone:sms:send', b.to, b.body) end
    cb('ok')
end)
RegisterNUICallback('phoneSmsThread', function(b, cb)
    if b.peer then TriggerServerEvent('noxa:phone:sms:thread', b.peer) end
    cb('ok')
end)
RegisterNUICallback('phoneTweetPost', function(b, cb)
    if b.body then TriggerServerEvent('noxa:phone:tweet:post', b.body) end
    cb('ok')
end)
RegisterNUICallback('phoneTweetsList', function(_, cb)
    TriggerServerEvent('noxa:phone:tweets:list'); cb('ok')
end)
-- Virement rapide depuis l'app Banque (réutilise le module bancaire).
RegisterNUICallback('phoneBankTransfer', function(b, cb)
    local amt = tonumber(b.amount)
    if b.target and amt then TriggerServerEvent('noxa:bank:transfer', b.target, amt) end
    cb('ok')
end)
