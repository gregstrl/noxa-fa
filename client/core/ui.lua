-- =====================================================================
--  NOXA FA — Couche UI client (notifications & annonces)
--  Centralise le retour visuel. S'appuie sur ox_lib (lib.notify).
--  Le serveur déclenche ces events ; le client ne fait qu'afficher.
-- =====================================================================

Noxa = Noxa or {}
Noxa.UI = {}

local types = { success = 'success', error = 'error', inform = 'inform', warning = 'warning' }

--- Notification standard.
---@param msg string
---@param kind? string success|error|inform|warning
function Noxa.UI.notify(msg, kind)
    lib.notify({
        title       = 'Noxa FA',
        description = msg,
        type        = types[kind] or 'inform',
        position    = 'top',
    })
end

-- Déclenché par le serveur pour tout retour d'action.
RegisterNetEvent('noxa:notify', function(msg, kind)
    if type(msg) ~= 'string' then return end
    Noxa.UI.notify(msg, kind)
end)

-- Annonce serveur (broadcast staff) — affichée plus visiblement.
RegisterNetEvent('noxa:announce', function(msg)
    if type(msg) ~= 'string' then return end
    lib.notify({
        title       = 'Annonce',
        description = msg,
        type        = 'inform',
        position    = 'top',
        duration    = 8000,
        icon        = 'bullhorn',
    })
end)
