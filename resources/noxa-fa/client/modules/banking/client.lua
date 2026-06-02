-- =====================================================================
--  NOXA FA — Module Banque (client-side)
--  Pilote l'interface bancaire NUI custom (zéro ox_lib).
--  Aucune valeur de solde n'est de confiance : l'affichage provient du
--  statebag répliqué serveur (Noxa.GetPlayerData).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Banking = Noxa.Banking or {}
local NUI = Noxa.NUI

-- Verrou d'ouverture : sans ce garde, F7 (keymapping, déclenché même focus NUI
-- actif) ré-ouvrait la banque et ré-acquérait le focus sans relâche correspondant
-- → compteur de focus déséquilibré, curseur bloqué.
local isOpen = false

-- Ouvre l'interface bancaire (point d'entrée unique : commande + zones POI).
function Noxa.Banking.open()
    if isOpen then return end
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data then return end
    isOpen = true
    NUI.setFocus(true)
    NUI.send('banking', 'open', {
        name      = data.name,
        citizenid = data.citizenid,
        cash      = data.cash or 0,
        bank      = data.bank or 0,
    })
end

-- /banque : ouvre l'interface bancaire.
RegisterCommand('banque', Noxa.Banking.open, false)
RegisterKeyMapping('banque', 'Ouvrir la banque', 'keyboard', 'F7')

-- Synchronise les soldes affichés quand l'état joueur change (statebag).
AddEventHandler('noxa:client:playerDataUpdated', function(data)
    NUI.send('banking', 'sync', { cash = data.cash or 0, bank = data.bank or 0 })
end)

-- Réception de la liste des factures depuis le serveur.
RegisterNetEvent('noxa:bank:invoice:setList', function(list)
    NUI.send('banking', 'invoices', { list = list or {} })
end)

-- ---------------------------------------------------------------------
--  Callbacks NUI -> serveur
-- ---------------------------------------------------------------------

RegisterNUICallback('bankClose', function(_, cb)
    if isOpen then isOpen = false; NUI.setFocus(false) end
    cb('ok')
end)

RegisterNUICallback('bankDeposit', function(body, cb)
    local amount = tonumber(body.amount)
    if amount then TriggerServerEvent('noxa:bank:deposit', amount) end
    cb('ok')
end)

RegisterNUICallback('bankWithdraw', function(body, cb)
    local amount = tonumber(body.amount)
    if amount then TriggerServerEvent('noxa:bank:withdraw', amount) end
    cb('ok')
end)

RegisterNUICallback('bankTransfer', function(body, cb)
    local amount = tonumber(body.amount)
    if body.target and amount then TriggerServerEvent('noxa:bank:transfer', body.target, amount) end
    cb('ok')
end)

RegisterNUICallback('bankInvoices', function(_, cb)
    TriggerServerEvent('noxa:bank:invoice:list')
    cb('ok')
end)

RegisterNUICallback('bankInvoicePay', function(body, cb)
    if body.id then TriggerServerEvent('noxa:bank:invoice:pay', body.id) end
    cb('ok')
end)

RegisterNUICallback('bankInvoiceRefuse', function(body, cb)
    if body.id then TriggerServerEvent('noxa:bank:invoice:refuse', body.id) end
    cb('ok')
end)

-- /facturer [id] [montant] [libellé...] : émission rapide pour les pros.
RegisterCommand('facturer', function(_, args)
    local id = tonumber(args[1])
    local amount = tonumber(args[2])
    if not id or not amount then
        return Noxa.UI.notify('Usage : /facturer [id] [montant] [libellé]', 'error')
    end
    local label = table.concat(args, ' ', 3)
    TriggerServerEvent('noxa:bank:invoice:create', id, amount, label ~= '' and label or nil)
end, false)
