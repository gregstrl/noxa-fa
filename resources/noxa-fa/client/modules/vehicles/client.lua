-- =====================================================================
--  NOXA FA — Module Véhicules (client-side)
--  Concession · Garage · Fourrière. Le client ne fait que présenter la NUI
--  et matérialiser/retirer l'entité ; toute la vérité (possession, prix,
--  état) est serveur. Spawn/despawn + lecture de l'état (carburant, santé)
--  au remisage. Mods appliqués depuis le JSON persisté.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Vehicles = {}

local Veh   = Noxa.Vehicles
local CFG   = Noxa.Config
local VCFG  = Noxa.Config.VehicleConfig
local NUI   = Noxa.NUI
local World = Noxa.World

-- Entités sorties suivies localement : [plate] = entité (pour le remisage).
local out = {}
local lastGarage = nil   -- coords du dernier garage utilisé (point de spawn)
local uiOpen = false

-- ---------------------------------------------------------------------
--  Application des modifications (depuis le JSON persisté)
-- ---------------------------------------------------------------------
local function applyMods(veh, mods)
    if type(mods) ~= 'table' then return end
    SetVehicleModKit(veh, 0)
    if mods.primaryColor and mods.secondaryColor then
        SetVehicleColours(veh, mods.primaryColor, mods.secondaryColor)
    end
    if mods.wheelType then SetVehicleWheelType(veh, mods.wheelType) end
    if type(mods.mods) == 'table' then
        for modType, modIndex in pairs(mods.mods) do
            SetVehicleMod(veh, tonumber(modType), tonumber(modIndex), false)
        end
    end
end

--- Lit l'état courant d'une entité véhicule (pour persistance au remisage).
local function readStatus(veh)
    return {
        fuel   = math.floor(GetVehicleFuelLevel(veh)),
        engine = GetVehicleEngineHealth(veh),
        body   = GetVehicleBodyHealth(veh),
    }
end

-- ---------------------------------------------------------------------
--  Spawn d'un véhicule possédé (sortie de garage)
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:veh:spawn', function(data)
    if type(data) ~= 'table' or not data.model then return end
    local hash = GetHashKey(data.model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return Noxa.UI.notify('Modèle de véhicule introuvable.', 'error')
    end
    RequestModel(hash)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return Noxa.UI.notify('Chargement du véhicule échoué.', 'error') end

    local ped = PlayerPedId()
    local base = lastGarage or GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    -- Décalage devant le joueur pour éviter le télescopage.
    local off = VCFG.garageSpawnOffset or 3.0
    local sx = base.x - math.sin(math.rad(heading)) * off
    local sy = base.y + math.cos(math.rad(heading)) * off

    local veh = CreateVehicle(hash, sx + 0.0, sy + 0.0, base.z + 0.5, heading, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return Noxa.UI.notify('Apparition du véhicule échouée.', 'error') end

    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleFuelLevel(veh, (tonumber(data.fuel) or 100) + 0.0)
    SetVehicleEngineHealth(veh, tonumber(data.engine) or 1000.0)
    SetVehicleBodyHealth(veh, tonumber(data.body) or 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    applyMods(veh, data.mods)
    SetVehicleEngineOn(veh, true, true, false)
    SetPedIntoVehicle(ped, veh, -1)

    out[data.plate] = veh
    Noxa.UI.notify(('Véhicule sorti (%s).'):format(data.plate), 'success')
end)

-- Remisage confirmé serveur : on détruit l'entité locale.
RegisterNetEvent('noxa:veh:stored', function(data)
    local veh = out[data.plate]
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    out[data.plate] = nil
end)

RegisterNetEvent('noxa:veh:retrieved', function()
    -- Rafraîchit la liste de garage si elle est ouverte.
    if uiOpen and lastGarage then
        TriggerServerEvent('noxa:veh:garage', VCFG.defaultGarage)
    end
end)

RegisterNetEvent('noxa:veh:bought', function(data)
    -- Met à jour le solde affiché dans la concession (achat suivant).
    NUI.send('vehicles', 'bank', { bank = data.bank })
end)

-- ---------------------------------------------------------------------
--  Réception des données serveur -> NUI
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:veh:catalog', function(data)
    uiOpen = true
    NUI.setFocus(true)
    NUI.send('vehicles', 'dealership', data)
end)

RegisterNetEvent('noxa:veh:garage', function(data)
    uiOpen = true
    NUI.setFocus(true)
    NUI.send('vehicles', 'garage', data)
end)

-- ---------------------------------------------------------------------
--  Handlers d'interaction de proximité (zones)
-- ---------------------------------------------------------------------
World.on('dealership', function()
    TriggerServerEvent('noxa:veh:catalog')
end)

World.on('garage', function(point)
    lastGarage = point.coords
    TriggerServerEvent('noxa:veh:garage', VCFG.defaultGarage)
end)

-- ---------------------------------------------------------------------
--  Callbacks NUI -> Lua
-- ---------------------------------------------------------------------
RegisterNUICallback('vehBuy', function(body, cb)
    if body.spawn then TriggerServerEvent('noxa:veh:buy', body.spawn) end
    cb('ok')
end)

RegisterNUICallback('vehTakeOut', function(body, cb)
    if body.plate then TriggerServerEvent('noxa:veh:takeOut', body.plate) end
    -- Fermeture immédiate du garage : on sort en voiture.
    uiOpen = false
    NUI.setFocus(false)
    NUI.send('vehicles', 'close')
    cb('ok')
end)

RegisterNUICallback('vehStore', function(body, cb)
    local plate = body.plate
    if plate then
        local veh = out[plate]
        local status = (veh and DoesEntityExist(veh)) and readStatus(veh) or {}
        TriggerServerEvent('noxa:veh:store', {
            plate = plate, fuel = status.fuel, engine = status.engine, body = status.body,
        })
    end
    cb('ok')
end)

RegisterNUICallback('vehRetrieve', function(body, cb)
    if body.plate then TriggerServerEvent('noxa:veh:retrieve', body.plate) end
    cb('ok')
end)

RegisterNUICallback('vehClose', function(_, cb)
    uiOpen = false
    NUI.setFocus(false)
    cb('ok')
end)

-- Sécurité : libère le focus si la ressource s'arrête NUI ouverte.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiOpen then NUI.releaseAll() end
end)

return Veh
