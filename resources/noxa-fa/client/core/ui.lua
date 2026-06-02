-- =====================================================================
--  NOXA FA — Couche UI client (notifications & annonces)
--  100 % NUI custom (zéro ox_lib). Le serveur déclenche ; le client affiche.
-- =====================================================================

Noxa = Noxa or {}
Noxa.UI = {}

local validTypes = { success = true, error = true, inform = true, warning = true }

--- Notification standard (toast NUI custom).
---@param msg string
---@param kind? string success|error|inform|warning
---@param title? string
function Noxa.UI.notify(msg, kind, title)
    Noxa.NUI.send('notify', 'show', {
        title = title,
        msg   = msg,
        type  = validTypes[kind] and kind or 'inform',
    })
end

-- Déclenché par le serveur pour tout retour d'action.
RegisterNetEvent('noxa:notify', function(msg, kind)
    if type(msg) ~= 'string' then return end
    Noxa.UI.notify(msg, kind)
end)

-- Annonce serveur (broadcast staff) — toast « announce » plus visible.
RegisterNetEvent('noxa:announce', function(msg)
    if type(msg) ~= 'string' then return end
    Noxa.NUI.send('notify', 'show', {
        title = 'Annonce', msg = msg, type = 'announce', duration = 8000,
    })
end)
