-- =====================================================================
--  NOXA FA — Boutique (server-side, autoritaire)
--  Achat d'articles d'épicerie : prix lus depuis la config (jamais du
--  client), débit en espèces validé, application des effets (faim/soif).
-- =====================================================================

Noxa = Noxa or {}

local U   = Noxa.Utils
local E   = Noxa.Enums
local S   = Noxa.Security
local CFG = Noxa.Config

--- Retrouve un article du catalogue serveur (source de vérité).
local function findItem(shopId, itemId)
    local shop = CFG.Shops[shopId]
    if not shop then return nil end
    for _, it in ipairs(shop.items) do
        if it.id == itemId then return it end
    end
    return nil
end

S.onNet('noxa:shop:buy', function(src, ply, shopId, itemId)
    if type(shopId) ~= 'string' or type(itemId) ~= 'string' then
        return S.flag(src, 'shop:buy paramètres invalides')
    end
    local item = findItem(shopId, itemId)
    if not item then
        return S.flag(src, ('shop:buy article inconnu %s/%s'):format(shopId, itemId))
    end

    -- Débit espèces + TVA reversée au Trésor Public (puits anti-inflation).
    if not Noxa.Economy.chargeWithTax(src, E.Accounts.CASH, item.price, 'shop:' .. itemId) then
        return TriggerClientEvent('noxa:notify', src, 'Espèces insuffisantes.', 'error')
    end

    -- Effets sur les besoins vitaux (bornés sur [0,100] par le module Needs).
    if Noxa.Needs then
        if item.hunger then Noxa.Needs.modify(ply, 'hunger', item.hunger) end
        if item.thirst then Noxa.Needs.modify(ply, 'thirst', item.thirst) end
    end

    TriggerClientEvent('noxa:notify', src,
        ('%s acheté (%s).'):format(item.label, U.money(item.price)), 'success')
end)
