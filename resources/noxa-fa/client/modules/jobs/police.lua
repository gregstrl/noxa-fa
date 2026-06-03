-- =====================================================================
--  NOXA FA — Job actif POLICE (client-side)
--  Effets locaux déclenchés UNIQUEMENT par le serveur (menottes, prison)
--  + ouverture du MDT NUI. Le client n'émet que des intentions.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

local cuffed = false
local jailUntil = nil

-- ---------------------------------------------------------------------
--  Menottage : restreint le ped et joue l'animation « mains menottées »
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:police:cuff', function(state)
    cuffed = state == true
    local ped = PlayerPedId()
    if not cuffed then
        ClearPedSecondaryTask(ped)
        ClearPedTasks(ped)
        return
    end
    local dict = 'mp_arresting'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    TaskPlayAnim(ped, dict, 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)

    CreateThread(function()
        while cuffed do
            Wait(0)
            -- Bloque attaque / armes / entrée véhicule pendant le menottage.
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)  DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true) DisableControlAction(0, 143, true)
            DisableControlAction(0, 23, true)  -- entrer véhicule
            DisableControlAction(0, 37, true)  -- ouvrir inventaire roue
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, 'mp_arresting', 'idle', 3) then
                TaskPlayAnim(p, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end
    end)
end)

-- ---------------------------------------------------------------------
--  Emprisonnement : téléportation + minuterie de peine
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:police:jail', function(minutes, coords)
    jailUntil = GetGameTimer() + minutes * 60 * 1000
    Noxa.Spawn.toPosition(coords)
    Noxa.UI.notify(('Vous êtes incarcéré·e pour %d minutes.'):format(minutes), 'warning')

    CreateThread(function()
        while jailUntil and GetGameTimer() < jailUntil do
            Wait(15000)
            if not jailUntil then break end
            local left = math.ceil((jailUntil - GetGameTimer()) / 60000)
            if left > 0 then Noxa.UI.notify(('Peine restante : %d min.'):format(left), 'inform') end
        end
        if jailUntil then
            jailUntil = nil
            TriggerServerEvent('noxa:police:requestRelease')
        end
    end)
end)

RegisterNetEvent('noxa:police:release', function(coords)
    jailUntil = nil
    Noxa.Spawn.toPosition(coords)
    Noxa.UI.notify('Vous êtes libéré·e. Restez en règle !', 'success')
end)

-- ---------------------------------------------------------------------
--  MDT (Mobile Data Terminal) — NUI dédiée
-- ---------------------------------------------------------------------
RegisterCommand('mdt', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or data.job.name ~= 'police' then
        return Noxa.UI.notify('MDT réservé à la police.', 'error')
    end
    TriggerServerEvent('noxa:police:mdt:fetch')
end, false)
RegisterKeyMapping('mdt', 'Ouvrir le MDT (police)', 'keyboard', 'F11')

RegisterNetEvent('noxa:police:mdt:data', function(data)
    NUI.openPanel('jobs')
    NUI.setFocus(true)
    NUI.send('jobs', 'mdt', data or {})
end)

-- Résultat de fouille -> NUI
RegisterNetEvent('noxa:police:searchResult', function(data)
    NUI.openPanel('jobs')
    NUI.setFocus(true)
    NUI.send('jobs', 'search', data or {})
end)
