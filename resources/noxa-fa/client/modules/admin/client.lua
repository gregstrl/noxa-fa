-- =====================================================================
--  NOXA FA — Module Administration (client-side)
--  Handlers déclenchés UNIQUEMENT par le serveur (jamais par le joueur).
--  Effets locaux : soin, réanimation, téléportation contrôlée serveur.
-- =====================================================================

Noxa = Noxa or {}

-- Soin complet du ped local.
RegisterNetEvent('noxa:admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
end)

-- Réanimation (sortie d'état "mort/down" + soin).
RegisterNetEvent('noxa:admin:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedTasksImmediately(ped)
    -- Notifie d'éventuels modules médicaux que le joueur est rétabli.
    TriggerEvent('noxa:client:revived')
end)

-- Téléportation pilotée serveur (goto / bring).
RegisterNetEvent('noxa:admin:teleport', function(pos)
    if type(pos) ~= 'table' or not pos.x then return end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
    local timeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(25)
    end
end)

-- =====================================================================
--  PANNEAU ADMIN NUI (F10) — le client n'émet que des intentions.
--  L'ouverture est ACCORDÉE par le serveur (event grant) après vérif rang.
-- =====================================================================

local NUI = Noxa.NUI

-- F10 : demande d'ouverture (le serveur décide si le rang est suffisant).
RegisterCommand('adminmenu', function()
    TriggerServerEvent('noxa:admin:open')
end, false)
RegisterKeyMapping('adminmenu', 'Ouvrir le menu admin', 'keyboard', 'F10')

-- Fermeture déclenchée par le système anti-superposition (ouverture d'un autre panneau).
NUI.registerPanel('admin', function()
    NUI.send('admin', 'close', {})  -- la NUI répondra via le callback adminClose
end)

-- Ouverture accordée par le serveur : on ouvre la NUI avec le rang + données.
RegisterNetEvent('noxa:admin:grant', function(payload)
    NUI.openPanel('admin')
    NUI.setFocus(true)
    NUI.send('admin', 'open', payload or {})
end)

-- Données poussées par le serveur (players / logs / server).
RegisterNetEvent('noxa:admin:data', function(what, list)
    NUI.send('admin', 'data', { what = what, list = list or {} })
end)

RegisterNUICallback('adminClose', function(_, cb)
    if NUI.activePanel == 'admin' then
        NUI.closePanel('admin')
        NUI.setFocus(false)
    end
    cb('ok')
end)

RegisterNUICallback('adminFetch', function(body, cb)
    TriggerServerEvent('noxa:admin:fetch', body.what, body.arg)
    cb('ok')
end)

RegisterNUICallback('adminAction', function(body, cb)
    if type(body) == 'table' and body.action then
        TriggerServerEvent('noxa:admin:action', body)
    end
    cb('ok')
end)

-- ---------------------------------------------------------------------
--  Effets locaux déclenchés par le serveur (jamais par le joueur)
-- ---------------------------------------------------------------------

-- Gel / dégel d'un joueur (modération).
RegisterNetEvent('noxa:admin:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state == true)
    if state then
        Noxa.UI.notify('Vous avez été figé par le staff.', 'warning')
    else
        Noxa.UI.notify('Vous avez été libéré.', 'inform')
    end
end)

-- Téléportation vers le point de la carte (waypoint).
RegisterNetEvent('noxa:admin:tpWaypoint', function()
    local wp = GetFirstBlipInfoId(8)  -- 8 = blip waypoint
    if not DoesBlipExist(wp) then
        return Noxa.UI.notify('Aucun point GPS défini.', 'error')
    end
    local coords = GetBlipInfoIdCoord(wp)
    local ped = PlayerPedId()
    -- Recherche d'une hauteur de sol valable (le waypoint n'a pas de Z fiable).
    local x, y = coords.x, coords.y
    RequestCollisionAtCoord(x, y, 0.0)
    SetEntityCoords(ped, x, y, 1000.0, false, false, false, false)
    local groundZ, found = 0.0, false
    local timeout = GetGameTimer() + 6000
    while GetGameTimer() < timeout do
        found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
        if found then break end
        Wait(50)
    end
    SetEntityCoords(ped, x, y, (found and groundZ or 30.0) + 0.5, false, false, false, false)
    Noxa.UI.notify('Téléportation au point GPS.', 'success')
end)

-- Spawn d'un véhicule devant le joueur (admin).
RegisterNetEvent('noxa:admin:spawnVehicle', function(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return Noxa.UI.notify(('Modèle « %s » introuvable.'):format(model), 'error')
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(20) end
    if not HasModelLoaded(hash) then return Noxa.UI.notify('Chargement du modèle échoué.', 'error') end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local fwd = GetEntityForwardVector(ped)
    local veh = CreateVehicle(hash, pos.x + fwd.x * 3.0, pos.y + fwd.y * 3.0, pos.z, heading, true, false)
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)
    Noxa.UI.notify(('Véhicule « %s » généré.'):format(model), 'success')
end)

-- Actions sur le véhicule courant (réparer / supprimer / couleur).
RegisterNetEvent('noxa:admin:vehicleAct', function(act, params)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        -- À défaut, le véhicule le plus proche (3 m).
        local pos = GetEntityCoords(ped)
        veh = GetClosestVehicle(pos.x, pos.y, pos.z, 3.0, 0, 71)
    end
    if veh == 0 then return Noxa.UI.notify('Aucun véhicule à proximité.', 'error') end

    if act == 'repair' then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        Noxa.UI.notify('Véhicule réparé.', 'success')
    elseif act == 'delete' then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        Noxa.UI.notify('Véhicule supprimé.', 'success')
    elseif act == 'color' and type(params) == 'table' then
        SetVehicleCustomPrimaryColour(veh, params.r or 0, params.g or 0, params.b or 0)
        SetVehicleCustomSecondaryColour(veh, params.r or 0, params.g or 0, params.b or 0)
        Noxa.UI.notify('Couleur appliquée.', 'success')
    end
end)
