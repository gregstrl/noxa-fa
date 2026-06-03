-- =====================================================================
--  NOXA FA — Panel staff & anti-cheat (client-side)
--  Le client n'émet que des INTENTIONS : l'ouverture est ACCORDÉE par le
--  serveur (vérif rang), chaque action est revérifiée serveur et journalisée.
--  Effets locaux pilotés serveur : spectate discret, capture d'écran.
--  Rapporte les FPS (statebag répliqué) pour la fiche joueur du panel.
-- =====================================================================

Noxa = Noxa or {}

local NUI = Noxa.NUI
local CFG = Noxa.Config.AntiCheat

-- ---------------------------------------------------------------------
--  Ouverture du panel (F3) — le serveur décide selon le rang
-- ---------------------------------------------------------------------

RegisterCommand('staffpanel', function()
    TriggerServerEvent('noxa:staff:open')
end, false)
RegisterKeyMapping('staffpanel', 'Ouvrir le panel staff', 'keyboard', 'F3')

-- Fermeture déclenchée par l'anti-superposition (ouverture d'un autre panneau).
NUI.registerPanel('staff', function()
    NUI.send('staff', 'close', {})
end)

RegisterNetEvent('noxa:staff:grant', function(payload)
    NUI.openPanel('staff')
    NUI.setFocus(true)
    NUI.send('staff', 'open', payload or {})
end)

RegisterNetEvent('noxa:staff:data', function(what, list)
    NUI.send('staff', 'data', { what = what, list = list or {} })
end)

-- Alerte anti-triche temps réel (poussée à tout staff en ligne).
RegisterNetEvent('noxa:staff:alert', function(alert)
    NUI.send('staff', 'alert', alert or {})
end)

RegisterNUICallback('staffClose', function(_, cb)
    if NUI.activePanel == 'staff' then
        NUI.closePanel('staff')
        NUI.setFocus(false)
    end
    cb('ok')
end)

RegisterNUICallback('staffFetch', function(body, cb)
    TriggerServerEvent('noxa:staff:fetch', body.what, body.arg)
    cb('ok')
end)

RegisterNUICallback('staffAction', function(body, cb)
    if type(body) == 'table' and body.action then
        TriggerServerEvent('noxa:staff:action', body)
    end
    cb('ok')
end)

-- Réception d'une capture d'écran prête (URL hébergée ou statut texte).
RegisterNetEvent('noxa:staff:screenshotReady', function(d)
    NUI.send('staff', 'screenshot', d or {})
end)

-- ---------------------------------------------------------------------
--  Spectate DISCRET — observe une cible sans être visible
--  (mode spectateur GTA : le ped local est masqué pour les autres).
-- ---------------------------------------------------------------------

local spectating = false
local specReturn  = nil   -- position de retour (avant spectate)
local stopSpectate        -- forward-declaration (référencée avant sa définition)

RegisterNetEvent('noxa:staff:spectate', function(d)
    if type(d) ~= 'table' then return end
    local ped = PlayerPedId()

    if d.state and not spectating then
        local target = GetPlayerFromServerId(tonumber(d.target) or -1)
        if target == -1 then return Noxa.UI.notify('Cible hors de portée.', 'error') end
        local tped = GetPlayerPed(target)
        if tped == 0 then return Noxa.UI.notify('Cible non chargée (trop loin).', 'error') end
        specReturn = GetEntityCoords(ped)
        -- Se placer dans la scope de la cible pour la voir, puis passer spectateur.
        local tc = GetEntityCoords(tped)
        RequestCollisionAtCoord(tc.x, tc.y, tc.z)
        SetEntityCoords(ped, tc.x, tc.y, tc.z + 0.5, false, false, false, false)
        local timeout = GetGameTimer() + 4000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
            Wait(25)
        end
        SetEntityVisible(ped, false, false)
        FreezeEntityPosition(ped, true)
        NetworkSetInSpectatorMode(true, tped)
        spectating = true
        Noxa.UI.notify('Spectate discret activé. (Échap pour quitter)', 'inform')
    elseif not d.state and spectating then
        stopSpectate()
    end
end)

stopSpectate = function()
    if not spectating then return end
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    if specReturn then
        SetEntityCoords(ped, specReturn.x, specReturn.y, specReturn.z, false, false, false, false)
        specReturn = nil
    end
    spectating = false
    Noxa.UI.notify('Spectate désactivé.', 'inform')
end

-- Échap quitte le spectate (sécurité anti-blocage).
CreateThread(function()
    while true do
        if spectating and IsControlJustPressed(0, 322) then  -- ESC
            stopSpectate()
        end
        Wait(spectating and 0 or 500)
    end
end)

-- ---------------------------------------------------------------------
--  Capture d'écran de la cible (best-effort)
--  Nécessite la ressource screenshot-basic + un webhook configuré.
--  Sans cela, on renvoie un statut texte (jamais de blocage).
-- ---------------------------------------------------------------------

RegisterNetEvent('noxa:staff:screenshot', function(requester)
    requester = tonumber(requester)
    if not requester then return end
    local webhook = CFG.screenshotWebhook or ''
    if GetResourceState('screenshot-basic') ~= 'started' or webhook == '' then
        TriggerServerEvent('noxa:staff:screenshotResult', requester,
            '(screenshot-basic + webhook requis — non configuré)')
        return
    end
    exports['screenshot-basic']:requestScreenshotUpload(webhook, 'files[]', function(data)
        local ok, resp = pcall(json.decode, data)
        local url = ok and resp and resp.attachments and resp.attachments[1] and resp.attachments[1].url
        TriggerServerEvent('noxa:staff:screenshotResult', requester, url or '(échec de capture)')
    end)
end)

-- ---------------------------------------------------------------------
--  Report FPS — statebag répliqué (lu par le serveur pour la fiche joueur)
-- ---------------------------------------------------------------------

CreateThread(function()
    while true do
        local dt = GetFrameTime()
        local fps = dt > 0.0 and math.floor(1.0 / dt + 0.5) or 0
        LocalPlayer.state:set('noxa:fps', fps, true)
        Wait(2000)
    end
end)
