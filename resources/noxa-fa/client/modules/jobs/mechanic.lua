-- =====================================================================
--  NOXA FA — Job actif MÉCANICIEN (client-side)
--  • /reparer : repère le véhicule le plus proche, demande au serveur
--    (qui consomme le kit) puis joue l'animation + remet le véhicule à neuf.
--  • /atelier : menu MenuV atelier (réparer / nettoyer).
-- =====================================================================

Noxa = Noxa or {}
local CFG = Noxa.Config.JobActions.mechanic

local pendingVehicle = nil   -- véhicule visé en attente de validation serveur

--- Véhicule le plus proche du joueur dans le rayon d'action, ou 0.
local function nearestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local pos = GetEntityCoords(ped)
    return GetClosestVehicle(pos.x, pos.y, pos.z, CFG.actionDistance, 0, 71)
end

--- Lance le flux de réparation (validation + consommation côté serveur).
local function startRepair()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or data.job.name ~= 'mechanic' then
        return Noxa.UI.notify('Réservé aux mécaniciens.', 'error')
    end
    local veh = nearestVehicle()
    if veh == 0 then return Noxa.UI.notify('Aucun véhicule à proximité.', 'error') end
    pendingVehicle = veh
    TriggerServerEvent('noxa:mechanic:repairRequest')
end

RegisterCommand('reparer', startRepair, false)

-- Le serveur a validé + consommé le kit : on exécute la réparation.
RegisterNetEvent('noxa:mechanic:repairStart', function(duration)
    local veh = pendingVehicle
    pendingVehicle = nil
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return Noxa.UI.notify('Véhicule introuvable.', 'error')
    end
    local ped = PlayerPedId()
    Noxa.UI.notify('Réparation en cours…', 'inform')

    local dict = 'mini@repair'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    TaskPlayAnim(ped, dict, 'fixing_a_player', 8.0, -8.0, duration, 1, 0, false, false, false)

    CreateThread(function()
        local endAt = GetGameTimer() + (duration or CFG.repairTime)
        while GetGameTimer() < endAt do
            Wait(0)
            -- Affichage du temps restant au centre-bas de l'écran.
            local left = math.ceil((endAt - GetGameTimer()) / 1000)
            SetTextFont(4); SetTextScale(0.5, 0.5); SetTextCentre(true)
            SetTextColour(255, 255, 255, 220)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('🔧 Réparation… %ds'):format(left))
            EndTextCommandDisplayText(0.5, 0.86)
        end
        ClearPedTasks(ped)
        if DoesEntityExist(veh) then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehicleDirtLevel(veh, 0.0)
        end
        Noxa.UI.notify('Véhicule réparé.', 'success')
    end)
end)

-- ---------------------------------------------------------------------
--  Atelier — menu MenuV (réparer / nettoyer le véhicule le plus proche).
-- ---------------------------------------------------------------------
local atelierMenu

--- Nettoie le véhicule le plus proche (action atelier).
local function washNearest()
    local veh = nearestVehicle()
    if veh ~= 0 then
        SetVehicleDirtLevel(veh, 0.0)
        Noxa.UI.notify('Véhicule nettoyé.', 'success')
    else
        Noxa.UI.notify('Aucun véhicule à proximité.', 'error')
    end
end

RegisterCommand('atelier', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or data.job.name ~= 'mechanic' then
        return Noxa.UI.notify('Atelier réservé aux mécaniciens.', 'error')
    end
    if not atelierMenu then
        atelierMenu = MenuV:CreateMenu(data.job.label or 'Atelier', 'Atelier mécanicien',
            'topleft', 0, 150, 220, 'size-110', 'default', 'menuv', 'noxa_mech_atelier')
        atelierMenu:AddButton({
            icon = '🔧', label = 'Réparer le véhicule',
            description = 'Remise à neuf du véhicule le plus proche',
            select = function()
                MenuV:CloseAll()
                startRepair()
            end,
        })
        atelierMenu:AddButton({
            icon = '🧽', label = 'Nettoyer le véhicule',
            description = 'Retire la saleté du véhicule le plus proche',
            select = function()
                MenuV:CloseAll()
                washNearest()
            end,
        })
    end
    MenuV:OpenMenu(atelierMenu)
end, false)
