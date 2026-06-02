-- =====================================================================
--  NOXA FA — Carte : blips des points d'intérêt (client-side)
--  Dessine un blip pour chaque POI déclaré dans C.POI. Aucune logique
--  de gameplay ici : purement cartographique (lecture seule de la config).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Blips = {}

local CFG  = Noxa.Config
local Blip = Noxa.Blips

local created = {}   -- handles des blips créés (nettoyage à l'arrêt)

--- Crée un blip statique pour une coordonnée donnée.
local function addBlip(coords, def, label)
    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(blip, def.sprite)
    SetBlipColour(blip, def.color)
    SetBlipScale(blip, def.scale or 0.8)
    SetBlipAsShortRange(blip, def.shortRange ~= false)
    SetBlipDisplay(blip, 4)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    created[#created + 1] = blip
    return blip
end

--- Parcourt C.POI et matérialise tous les blips déclarés.
function Blip.buildAll()
    for _, cat in pairs(CFG.POI) do
        if cat.blip and cat.points then
            for _, pt in ipairs(cat.points) do
                addBlip(pt, cat.blip, cat.label)
            end
        end
    end
end

--- Supprime tous les blips créés (rechargement de ressource).
function Blip.clearAll()
    for _, b in ipairs(created) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    created = {}
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    Blip.buildAll()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Blip.clearAll() end
end)
