-- =====================================================================
--  NOXA FA — Boutique (client-side) : pont NUI <-> serveur
--  L'interface n'émet que des intentions d'achat : le serveur valide le
--  prix, débite l'argent et applique les effets (faim/soif). Zéro confiance.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

RegisterNUICallback('shopClose', function(_, cb)
    NUI.setFocus(false)
    cb('ok')
end)

RegisterNUICallback('shopBuy', function(body, cb)
    if type(body.shop) == 'string' and type(body.item) == 'string' then
        TriggerServerEvent('noxa:shop:buy', body.shop, body.item)
    end
    cb('ok')
end)

-- Le serveur confirme l'achat : on rafraîchit le cash affiché dans la boutique.
AddEventHandler('noxa:client:playerDataUpdated', function(data)
    NUI.send('shop', 'sync', { cash = data.cash or 0 })
end)
