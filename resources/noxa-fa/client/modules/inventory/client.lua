-- =====================================================================
--  NOXA FA — Module Inventaire (client-side)
--  Pilote la grille NUI et la hotbar. Aucune logique de confiance : le
--  client n'émet que des intentions, le serveur valide tout (poids, dupe,
--  effets). Touche I pour ouvrir, touches 1-5 pour la hotbar.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Inv = {}

local Inv = Noxa.Inv
local NUI = Noxa.NUI

local isOpen = false
local cache  = { slots = {}, hotbar = 5 }   -- dernier état reçu (résolution hotbar)

-- ---------------------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------------------
function Inv.open()
    if isOpen then return end
    -- Pas d'inventaire pendant la sélection/création de personnage.
    if Noxa.Creator and Noxa.Creator.isActive() then return end
    isOpen = true
    NUI.setFocus(true)                 -- souris + clavier (menu contextuel)
    NUI.send('inventory', 'open')
    TriggerServerEvent('noxa:inv:request')
end

-- Fermeture pilotée par la NUI : on demande la fermeture, la NUI renvoie
-- 'invClose' qui libère le focus (chemin unique = pas de double décrément).
function Inv.close()
    if not isOpen then return end
    NUI.send('inventory', 'close')
end

RegisterCommand('inventaire', function()
    if isOpen then Inv.close() else Inv.open() end
end, false)
RegisterKeyMapping('inventaire', 'Ouvrir l\'inventaire', 'keyboard', 'I')

-- ---------------------------------------------------------------------
--  Hotbar : touches 1-5 -> utiliser le slot correspondant (hors menu ouvert)
--  Contrôles FiveM 157..161 = touches 1..5 du pavé principal.
-- ---------------------------------------------------------------------
local HOTBAR_KEYS = { 157, 158, 159, 160, 161 }
CreateThread(function()
    while true do
        Wait(0)
        if not isOpen then
            for i = 1, cache.hotbar or 5 do
                if IsControlJustPressed(0, HOTBAR_KEYS[i]) then
                    -- N'utiliser que si un objet occupe réellement ce slot.
                    for _, s in ipairs(cache.slots) do
                        if s.slot == i then
                            TriggerServerEvent('noxa:inv:use', i)
                            break
                        end
                    end
                end
            end
        else
            Wait(150)   -- menu ouvert : la NUI gère, on relâche la boucle
        end
    end
end)

-- ---------------------------------------------------------------------
--  Réception de l'état serveur -> NUI
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:inv:set', function(payload)
    if type(payload) ~= 'table' then return end
    cache.slots  = payload.slots or {}
    cache.hotbar = payload.hotbar or 5
    NUI.send('inventory', 'set', payload)
end)

-- Soin (santé = entité locale) appliqué après usage d'un item de soin.
RegisterNetEvent('noxa:inv:heal', function(amount)
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    if hp <= 0 then return end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), hp + (tonumber(amount) or 0)))
end)

-- Hooks d'action d'item (ouverture téléphone, crochetage...).
RegisterNetEvent('noxa:inv:action', function(action)
    if action == 'phone' then
        ExecuteCommand('phone')        -- réutilise la bascule du module téléphone
    elseif action == 'lockpick' then
        Noxa.UI.notify('Crochetage — disponible prochainement.', 'inform')
    end
end)

-- ---------------------------------------------------------------------
--  Callbacks NUI -> Lua (relais vers le serveur autoritaire)
-- ---------------------------------------------------------------------
RegisterNUICallback('invClose', function(_, cb)
    isOpen = false
    NUI.setFocus(false)
    cb('ok')
end)

RegisterNUICallback('invUse', function(body, cb)
    if body.slot then TriggerServerEvent('noxa:inv:use', body.slot) end
    cb('ok')
end)

RegisterNUICallback('invMove', function(body, cb)
    if body.from and body.to then TriggerServerEvent('noxa:inv:move', body.from, body.to) end
    cb('ok')
end)

RegisterNUICallback('invDrop', function(body, cb)
    if body.slot then TriggerServerEvent('noxa:inv:drop', body.slot, body.count) end
    cb('ok')
end)

-- Donner : résout le joueur le plus proche côté client (le serveur revérifie
-- la distance avant tout transfert — défense en profondeur).
RegisterNUICallback('invGive', function(body, cb)
    if not body.slot then return cb('ok') end
    local target = Inv.closestPlayer()
    if not target then
        Noxa.UI.notify('Aucun joueur à proximité.', 'error')
        return cb('ok')
    end
    TriggerServerEvent('noxa:inv:give', target, body.slot, body.count)
    cb('ok')
end)

--- Identifiant serveur du joueur le plus proche (dans le rayon de don).
function Inv.closestPlayer()
    local me = PlayerId()
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local best, bestDist = nil, (Noxa.Config.Inventory.dropRadius or 2.5)
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            local d = #(myPos - GetEntityCoords(ped))
            if d < bestDist then
                best = GetPlayerServerId(pid)
                bestDist = d
            end
        end
    end
    return best
end

-- Sécurité : libère tout au stop de ressource.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then NUI.releaseAll() end
end)

return Inv
