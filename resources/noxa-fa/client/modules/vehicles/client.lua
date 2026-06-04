-- =====================================================================
--  NOXA FA — Module Véhicules (client-side)
--  Concession · Garage · Fourrière. Présentation 100 % MenuV (menus
--  in-game unifiés) ; le client ne fait que présenter les menus et
--  matérialiser/retirer l'entité. Toute la vérité (possession, prix,
--  état) reste serveur. Spawn/despawn + lecture de l'état (carburant,
--  santé) au remisage. Mods appliqués depuis le JSON persisté.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Vehicles = {}

local Veh   = Noxa.Vehicles
local CFG   = Noxa.Config
local VCFG  = Noxa.Config.VehicleConfig
local World = Noxa.World
local money = Noxa.Utils.money

-- Entités sorties suivies localement : [plate] = entité (pour le remisage).
local out = {}
local lastGarage = nil   -- coords du dernier garage utilisé (point de spawn)

-- Menus MenuV (créés à la demande, réutilisés ensuite).
local dealer      = { menu = nil, built = false }
local garageMenu  = nil
local garageOpen  = false

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

--- Remise un véhicule sorti : lit son état local avant d'avertir le serveur.
local function storeVehicle(plate)
    local veh    = out[plate]
    local status = (veh and DoesEntityExist(veh)) and readStatus(veh) or {}
    TriggerServerEvent('noxa:veh:store', {
        plate = plate, fuel = status.fuel, engine = status.engine, body = status.body,
    })
    MenuV:CloseAll()
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
    -- Rafraîchit la liste de garage si elle est encore ouverte.
    if garageOpen and lastGarage then
        TriggerServerEvent('noxa:veh:garage', VCFG.defaultGarage)
    end
end)

RegisterNetEvent('noxa:veh:bought', function(data)
    -- Met à jour le solde affiché dans la concession (achat suivant).
    if dealer.menu then
        dealer.menu.Subtitle = ('Compte bancaire : %s'):format(money(data.bank or 0))
    end
end)

-- ---------------------------------------------------------------------
--  CONCESSION — construction & ouverture du menu (MenuV)
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:veh:catalog', function(data)
    if type(data) ~= 'table' or not data.catalog then return end
    -- Le catalogue est statique côté serveur : on bâtit l'arborescence une
    -- seule fois (catégories -> véhicules), puis on ne fait que rouvrir.
    if not dealer.built then
        dealer.menu = MenuV:CreateMenu('Concession', 'Sélectionnez un véhicule',
            'topleft', 0, 150, 220, 'size-110', 'default', 'menuv', 'noxa_dealer')

        for _, cls in ipairs(data.catalog) do
            local sub = MenuV:CreateMenu(('Catégorie %s'):format(cls.class), cls.label,
                'topleft', 0, 150, 220, 'size-110', 'default', 'menuv',
                'noxa_dealer_' .. tostring(cls.class))

            for _, v in ipairs(cls.vehicles) do
                local spawn = v.spawn
                sub:AddButton({
                    icon        = '🚗',
                    label       = v.label,
                    description = ('Prix : %s — Acheter (livré au garage)'):format(money(v.price)),
                    select      = function() TriggerServerEvent('noxa:veh:buy', spawn) end,
                })
            end

            dealer.menu:AddButton({
                label       = cls.label,
                description = ('%d véhicule(s) dans cette catégorie'):format(#cls.vehicles),
                value       = sub,
            })
        end
        dealer.built = true
    end

    dealer.menu.Subtitle = ('Compte bancaire : %s'):format(money(data.bank or 0))
    MenuV:OpenMenu(dealer.menu)
end)

-- ---------------------------------------------------------------------
--  GARAGE / FOURRIÈRE — menu reconstruit à chaque ouverture (état vivant)
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:veh:garage', function(data)
    if type(data) ~= 'table' then return end
    if not garageMenu then
        garageMenu = MenuV:CreateMenu('Garage', '', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_garage')
        garageMenu:On('open',  function() garageOpen = true end)
        garageMenu:On('close', function() garageOpen = false end)
    end

    garageMenu:ClearItems()
    local n = 0

    for _, v in ipairs(data.vehicles or {}) do
        n = n + 1
        local plate = v.plate
        if v.state == 'out' then
            garageMenu:AddButton({
                icon        = '🅿️',
                label       = ('%s [%s]'):format(v.label, plate),
                description = 'Véhicule sorti — Remiser',
                select      = function() storeVehicle(plate) end,
            })
        else -- 'stored'
            garageMenu:AddButton({
                icon        = '🚗',
                label       = ('%s [%s]'):format(v.label, plate),
                description = 'Remisé — Sortir le véhicule',
                select      = function()
                    TriggerServerEvent('noxa:veh:takeOut', plate)
                    MenuV:CloseAll()
                end,
            })
        end
    end

    for _, v in ipairs(data.impound or {}) do
        n = n + 1
        local plate = v.plate
        garageMenu:AddButton({
            icon        = '⛓️',
            label       = ('%s [%s]'):format(v.label, plate),
            description = ('Fourrière — Récupérer (amende %s)'):format(money(data.impoundFee)),
            select      = function() TriggerServerEvent('noxa:veh:retrieve', plate) end,
        })
    end

    if n == 0 then
        garageMenu:AddButton({ label = 'Aucun véhicule', description = 'Vous n\'avez aucun véhicule ici.' })
    end

    garageMenu.Subtitle = ('%d véhicule(s)'):format(n)
    MenuV:OpenMenu(garageMenu)
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

-- Sécurité : ferme tout menu ouvert si la ressource s'arrête.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then MenuV:CloseAll() end
end)

return Veh
