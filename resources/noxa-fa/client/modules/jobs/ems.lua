-- =====================================================================
--  NOXA FA — Job actif EMS (client-side)
--  • Détection locale de la mort -> déclare l'état inconscient au serveur
--    (autorité), maintient le joueur « à terre » jusqu'à réanimation ou
--    respawn auto (bleedout). Restitution garantie du contrôle au réveil.
--  • Alertes patients pour les EMS en service (blip temporaire).
-- =====================================================================

Noxa = Noxa or {}

local downed = false

--- Maintient le joueur inconscient (au sol via ragdoll + contrôles bloqués).
--- Le ragdoll est fiable sans dépendre d'un dictionnaire d'animation précis.
local function beginDowned()
    Noxa.UI.notify('Vous êtes inconscient. Un EMS peut vous réanimer — ou /respawn après le délai.', 'error')
    CreateThread(function()
        while downed do
            Wait(0)
            local ped = PlayerPedId()
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)  DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true) DisableControlAction(0, 143, true)
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 22, true)  -- saut
            DisableControlAction(0, 23, true)  -- entrer véhicule
            if not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 60000, 60000, 0, false, false, false)
            end
        end
    end)
end

-- ---------------------------------------------------------------------
--  Boucle de détection de décès
-- ---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        if not downed and IsEntityDead(ped) then
            downed = true
            local c = GetEntityCoords(ped)
            -- Annule l'écran « wasted » : on ressuscite sur place, mais à terre.
            NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), false, false)
            SetEntityHealth(ped, 150)
            TriggerServerEvent('noxa:ems:death')
            beginDowned()
        end
    end
end)

-- Fin de l'état inconscient : déclenché par la réanimation (admin/EMS).
AddEventHandler('noxa:client:revived', function()
    if downed then
        downed = false
        ClearPedTasksImmediately(PlayerPedId())
        Noxa.UI.notify('Vous reprenez connaissance.', 'success')
    end
end)

-- /respawn : demande un respawn auto (le serveur vérifie le bleedout).
RegisterCommand('respawn', function()
    if not downed then return end
    TriggerServerEvent('noxa:ems:selfRespawn')
end, false)
RegisterKeyMapping('respawn', 'Réapparaître (inconscient)', 'keyboard', 'G')

-- Respawn accordé : téléportation à l'hôpital (le réveil vient de revive).
RegisterNetEvent('noxa:ems:respawn', function(coords)
    Noxa.Spawn.toPosition(coords)
end)

-- ---------------------------------------------------------------------
--  Alerte patient (EMS en service) : blip temporaire 30 s
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:ems:alert', function(data)
    if type(data) ~= 'table' or not data.x then return end
    local blip = AddBlipForCoord(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Patient : %s'):format(data.name or '??'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(30000, function() if DoesBlipExist(blip) then RemoveBlip(blip) end end)
end)
