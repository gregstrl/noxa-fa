-- =====================================================================
--  NOXA FA — Boutique (client-side) : menu MenuV -> serveur autoritaire
--  Le menu n'émet que des intentions d'achat : le serveur valide le prix,
--  débite l'argent et applique les effets (faim/soif). Zéro confiance.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Shop = Noxa.Shop or {}

-- Menus MenuV créés à la demande puis réutilisés (un par boutique).
local shopMenus = {}

--- Ouvre (ou construit) le menu MenuV d'une boutique.
---@param key string identifiant de la boutique (ex: grocery)
---@param label string titre affiché
---@param items table[] catalogue { id, label, price, emoji }
function Noxa.Shop.open(key, label, items)
    local menu = shopMenus[key]
    if not menu then
        menu = MenuV:CreateMenu(label or 'Boutique', 'Paiement à la caisse',
            'topleft', 0, 150, 220, 'size-110', 'default', 'menuv', 'noxa_shop_' .. key)
        for _, it in ipairs(items or {}) do
            menu:AddButton({
                icon = it.emoji,
                label = it.label,
                description = ('Prix : %d$'):format(it.price or 0),
                -- L'achat n'est qu'une intention : le serveur reste seul juge
                -- (prix, solde, effets). Le menu reste ouvert pour enchaîner.
                select = function()
                    TriggerServerEvent('noxa:shop:buy', key, it.id)
                end,
            })
        end
        shopMenus[key] = menu
    end
    MenuV:OpenMenu(menu)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then MenuV:CloseAll() end
end)
