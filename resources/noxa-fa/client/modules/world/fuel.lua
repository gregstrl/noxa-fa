-- =====================================================================
--  NOXA FA — Station essence (client-side)
--  À la pompe : repère le véhicule (conduit ou le plus proche), demande
--  l'autorisation serveur (paiement borné), puis remplit le réservoir avec
--  une jauge NUI animée. Le coût est TOUJOURS débité côté serveur.
-- =====================================================================

Noxa = Noxa or {}

local CFG   = Noxa.Config
local NUI   = Noxa.NUI
local World = Noxa.World
local FUEL  = CFG.Fuel

local refueling = false

--- Retourne le véhicule à ravitailler (occupé ou le plus proche < 5m), ou nil.
local function findVehicle(ped, pos)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    veh = GetClosestVehicle(pos.x, pos.y, pos.z, 5.0, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

World.on('fuel', function()
    if refueling then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = findVehicle(ped, pos)
    if not veh then
        return Noxa.UI.notify('Aucun véhicule à proximité de la pompe.', 'error')
    end

    local current = math.floor(GetVehicleFuelLevel(veh))
    if current < 0 then current = 0 end
    if current > FUEL.maxFuel then current = FUEL.maxFuel end
    local missing = FUEL.maxFuel - current
    if missing <= 1 then
        return Noxa.UI.notify('Le réservoir est déjà plein.', 'inform')
    end

    local plate = GetVehicleNumberPlateText(veh)
    plate = plate and plate:gsub('%s+$', '') or ''
    -- Demande d'autorisation : le serveur valide et débite le carburant manquant.
    TriggerServerEvent('noxa:fuel:request', plate, missing)
end)

-- Le serveur a débité le joueur : on procède au remplissage animé.
RegisterNetEvent('noxa:fuel:confirmed', function(units)
    units = tonumber(units) or 0
    if units <= 0 or refueling then return end
    local ped = PlayerPedId()
    local veh = findVehicle(ped, GetEntityCoords(ped))
    if not veh then return end

    refueling = true
    NUI.send('fuel', 'show', { percent = math.floor(GetVehicleFuelLevel(veh)) })

    CreateThread(function()
        local target = math.min(FUEL.maxFuel, GetVehicleFuelLevel(veh) + units)
        while GetVehicleFuelLevel(veh) < target - 0.5 do
            local lvl = math.min(target, GetVehicleFuelLevel(veh) + FUEL.unitsPerTick)
            SetVehicleFuelLevel(veh, lvl + 0.0)
            NUI.send('fuel', 'update', { percent = math.floor(lvl) })
            Wait(FUEL.tickMs)
        end
        SetVehicleFuelLevel(veh, target + 0.0)
        NUI.send('fuel', 'update', { percent = math.floor(target) })
        Wait(600)
        NUI.send('fuel', 'hide', {})
        refueling = false
        Noxa.UI.notify('Plein effectué.', 'success')
    end)
end)
