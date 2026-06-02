-- =====================================================================
--  NOXA FA — Immobilier (client-side)
--  • Blips « à vendre » (orange) sur les biens libres.
--  • Portes interactives enregistrées dans le système de zones unifié :
--    menu contextuel NUI custom (Acheter / Entrer / Verrouiller / Mobilier).
--  • Téléportation intérieur/extérieur + rendu du mobilier sauvegardé.
--  Aucune donnée n'est de confiance : tout transite par le serveur autoritaire.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Realty = {}

local CFG   = Noxa.Config
local NUI   = Noxa.NUI
local World = Noxa.World
local Realty = Noxa.Realty

local properties = {}      -- liste reçue du serveur
local saleBlips = {}       -- handles des blips « à vendre »
local current = nil        -- intérieur courant { id, door, inside, furniture }
local spawnedFurniture = {}-- objets de mobilier instanciés (intérieur courant)

-- ---------------------------------------------------------------------
--  Synchronisation depuis le serveur
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:prop:list', function(list)
    properties = list or {}
    Realty.rebuildBlips()
    Realty.rebuildDoors()
end)

--- (Re)dessine les blips orange sur les biens encore à vendre.
function Realty.rebuildBlips()
    for _, b in ipairs(saleBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    saleBlips = {}
    for _, p in ipairs(properties) do
        if not p.owner and p.door then
            local b = AddBlipForCoord(p.door.x + 0.0, p.door.y + 0.0, p.door.z + 0.0)
            SetBlipSprite(b, 40)
            SetBlipColour(b, 17)        -- orange (à vendre)
            SetBlipScale(b, 0.80)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('%s — À vendre'):format(p.label))
            EndTextCommandSetBlipName(b)
            saleBlips[#saleBlips + 1] = b
        end
    end
end

--- (Re)enregistre les portes comme points d'interaction dynamiques.
function Realty.rebuildDoors()
    local pts = {}
    for _, p in ipairs(properties) do
        if p.door then
            pts[#pts + 1] = {
                coords = vector3(p.door.x + 0.0, p.door.y + 0.0, p.door.z + 0.0),
                type   = 'property',
                prompt = ('%s — %s'):format(p.label, p.owner and 'Porte' or 'À vendre'),
                data   = p,
            }
        end
    end
    World.setPoints('property', pts)
end

-- ---------------------------------------------------------------------
--  Menu de porte (contextuel NUI custom)
-- ---------------------------------------------------------------------
local function citizenId()
    local d = Noxa.GetPlayerData and Noxa.GetPlayerData()
    return d and d.citizenid or nil
end

World.on('property', function(point)
    local p = point.data
    if not p then return end
    local cid = citizenId()
    local isOwner = p.owner ~= nil and p.owner == cid
    local tier = CFG.PropertyTiers[p.tier]
    local options = {}

    if not p.owner then
        options[#options + 1] = { id = 'buy',
            label = ('Acheter — %s'):format(Noxa.Utils.money(p.price)),
            description = tier and tier.label or p.tier, icon = '🏠' }
    elseif isOwner then
        options[#options + 1] = { id = 'enter', label = 'Entrer', icon = '🚪' }
        options[#options + 1] = { id = 'lock',
            label = p.locked and 'Déverrouiller' or 'Verrouiller', icon = p.locked and '🔓' or '🔒' }
    else
        options[#options + 1] = { id = 'occupied', label = 'Propriété privée', description = "Occupé", icon = '⛔' }
    end

    NUI.openMenu({ title = p.label, subtitle = tier and tier.label or '', options = options }, function(opt)
        if opt == 'buy' then
            NUI.confirm({
                title = 'Achat immobilier',
                message = ('Acheter « %s » pour %s ?'):format(p.label, Noxa.Utils.money(p.price)),
                confirmText = 'Acheter', danger = false,
            }, function(ok) if ok then TriggerServerEvent('noxa:prop:buy', p.id) end end)
        elseif opt == 'enter' then
            TriggerServerEvent('noxa:prop:enter', p.id)
        elseif opt == 'lock' then
            TriggerServerEvent('noxa:prop:lock', p.id, not p.locked)
        end
    end)
end)

-- ---------------------------------------------------------------------
--  Intérieur : téléportation + mobilier
-- ---------------------------------------------------------------------
local function clearFurniture()
    for _, obj in ipairs(spawnedFurniture) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
    spawnedFurniture = {}
end

local function spawnFurniture(list)
    clearFurniture()
    for _, f in ipairs(list or {}) do
        local hash = GetHashKey(f.model)
        RequestModel(hash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
        if HasModelLoaded(hash) then
            local obj = CreateObject(hash, f.x + 0.0, f.y + 0.0, f.z + 0.0, false, false, false)
            SetEntityHeading(obj, f.heading or 0.0)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)
            spawnedFurniture[#spawnedFurniture + 1] = obj
        end
    end
end

RegisterNetEvent('noxa:prop:enterInterior', function(data)
    if not data or not data.inside then return end
    current = { id = data.id, door = data.door, inside = data.inside, furniture = data.furniture or {} }
    DoScreenFadeOut(400)
    Wait(450)
    Noxa.Spawn.toPosition(data.inside)
    spawnFurniture(current.furniture)

    -- Point de sortie : à l'intérieur, à l'endroit d'arrivée.
    World.setPoints('property_exit', { {
        coords = vector3(data.inside.x + 0.0, data.inside.y + 0.0, data.inside.z + 0.0),
        type   = 'property_exit',
        prompt = 'Sortir',
    } })
    Wait(300)
    DoScreenFadeIn(500)
    Noxa.UI.notify('Tapez /meubles pour gérer votre mobilier.', 'inform')
end)

World.on('property_exit', function()
    if not current then return end
    local door = current.door
    DoScreenFadeOut(400)
    Wait(450)
    clearFurniture()
    if door then Noxa.Spawn.toPosition(door) end
    World.setPoints('property_exit', {})
    current = nil
    Wait(300)
    DoScreenFadeIn(500)
end)

-- ---------------------------------------------------------------------
--  Mobilier : placement simple devant le joueur + persistance serveur
-- ---------------------------------------------------------------------
local function placeInFront(model)
    local ped = PlayerPedId()
    local fwd = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.2, 0.0)
    local heading = GetEntityHeading(ped)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return end
    -- Place au sol
    local z = fwd.z
    local found, groundZ = GetGroundZFor_3dCoord(fwd.x, fwd.y, fwd.z + 1.0, false)
    if found then z = groundZ end
    local obj = CreateObject(hash, fwd.x, fwd.y, z, false, false, false)
    SetEntityHeading(obj, heading + 180.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    spawnedFurniture[#spawnedFurniture + 1] = obj
    current.furniture[#current.furniture + 1] = {
        model = model, x = fwd.x, y = fwd.y, z = z, heading = heading + 180.0,
    }
end

local function saveFurniture()
    if not current then return end
    TriggerServerEvent('noxa:prop:furniture:save', current.id, current.furniture)
end

local function openFurnitureMenu()
    if not current then
        return Noxa.UI.notify('Vous devez être à l\'intérieur de votre bien.', 'error')
    end
    local opts = { { id = '__clear', label = 'Tout retirer', icon = '🗑' } }
    for i, f in ipairs(CFG.Furniture) do
        opts[#opts + 1] = { id = tostring(i), label = f.label, icon = f.emoji }
    end
    NUI.openMenu({ title = 'Mobilier', subtitle = 'Placer devant vous', options = opts }, function(opt)
        if opt == '__clear' then
            clearFurniture()
            current.furniture = {}
            saveFurniture()
        elseif opt then
            local item = CFG.Furniture[tonumber(opt)]
            if item then placeInFront(item.model); saveFurniture() end
        end
    end)
end

RegisterCommand('meubles', openFurnitureMenu, false)

-- Demande la liste des biens une fois le personnage chargé.
AddEventHandler('noxa:client:playerDataUpdated', function()
    if next(properties) == nil then TriggerServerEvent('noxa:prop:request') end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    Wait(2000)
    TriggerServerEvent('noxa:prop:request')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearFurniture() end
end)
