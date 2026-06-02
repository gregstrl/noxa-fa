-- =====================================================================
--  NOXA FA — Station essence (server-side, autoritaire)
--  Débite le coût du carburant manquant (2$/% par défaut) en espèces, puis
--  autorise le client à remplir. Persiste le niveau pour les véhicules
--  immatriculés en base (noxa_vehicles) — ignoré pour les véhicules libres.
-- =====================================================================

Noxa = Noxa or {}

local U    = Noxa.Utils
local E    = Noxa.Enums
local DB   = Noxa.DB
local S    = Noxa.Security
local FUEL = Noxa.Config.Fuel

S.onNet('noxa:fuel:request', function(src, ply, plate, units)
    units = U.clampInt(units, 1, FUEL.maxFuel)
    if not units then
        return TriggerClientEvent('noxa:notify', src, 'Quantité de carburant invalide.', 'error')
    end

    local cost = units * FUEL.pricePerUnit
    if not ply:removeMoney(E.Accounts.CASH, cost, 'fuel') then
        return TriggerClientEvent('noxa:notify', src, 'Espèces insuffisantes pour le plein.', 'error')
    end

    -- Persistance pour les véhicules possédés (sans échec si véhicule libre).
    if type(plate) == 'string' and plate ~= '' then
        DB.refuelVehicle(plate, units)
    end

    TriggerClientEvent('noxa:fuel:confirmed', src, units)
    TriggerClientEvent('noxa:notify', src, ('Plein : %s'):format(U.money(cost)), 'success')
end)
