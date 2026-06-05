-- =====================================================================
--  NOXA FA — Designs autonomes hébergés (Anti-Cheat / Gestion serveur)
--  Ces panels sont des exports React mono-fichier (Claude Design) chargés
--  en iframe. Le client n'émet qu'une INTENTION d'ouverture : le serveur
--  vérifie le rang, construit les données réelles, puis ACCORDE l'ouverture.
--  Aucune donnée client de confiance ; tout est revérifié serveur.
-- =====================================================================

Noxa = Noxa or {}

local NUI = Noxa.NUI

-- ---------------------------------------------------------------------
--  Ouverture / fermeture (anti-superposition : un seul panneau plein actif)
-- ---------------------------------------------------------------------

local function openDesign(panel, payload)
    NUI.openPanel(panel)        -- ferme proprement un autre panneau plein
    NUI.setFocus(true)
    NUI.send(panel, 'open', { data = payload or {} })
end

local function closeDesign(panel)
    if NUI.activePanel ~= panel then return end
    NUI.send(panel, 'close', {})
    NUI.closePanel(panel)
    NUI.setFocus(false)
end

-- Fermeture déclenchée par l'anti-superposition (ouverture d'un autre panneau).
NUI.registerPanel('anticheat', function() closeDesign('anticheat') end)
NUI.registerPanel('gestion',   function() closeDesign('gestion') end)

-- ---------------------------------------------------------------------
--  Panel Anti-Cheat (helper+) — F8 ou /anticheat
-- ---------------------------------------------------------------------

RegisterCommand('anticheat', function()
    TriggerServerEvent('noxa:acpanel:open')
end, false)
RegisterKeyMapping('anticheat', 'Ouvrir le panel anti-cheat', 'keyboard', 'F8')

RegisterNetEvent('noxa:acpanel:grant', function(payload)
    openDesign('anticheat', payload or {})
end)

-- ---------------------------------------------------------------------
--  Panel Gestion serveur (superadmin) — /gestion
-- ---------------------------------------------------------------------

RegisterCommand('gestion', function()
    TriggerServerEvent('noxa:gestion:open')
end, false)

RegisterNetEvent('noxa:gestion:grant', function(payload)
    openDesign('gestion', payload or {})
end)

-- ---------------------------------------------------------------------
--  Fermeture demandée par la NUI (Échap dans le design)
-- ---------------------------------------------------------------------

RegisterNUICallback('designClose', function(body, cb)
    local panel = type(body) == 'table' and body.panel or nil
    if panel == 'anticheat' or panel == 'gestion' then
        closeDesign(panel)
    end
    cb('ok')
end)
