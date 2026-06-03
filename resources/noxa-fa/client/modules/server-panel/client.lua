-- =====================================================================
--  NOXA FA — Panel gestion serveur (client-side)
--  Le client n'émet que des INTENTIONS ; l'ouverture est ACCORDÉE par le
--  serveur (rang superadmin revérifié). Les domaines « client » diffusés
--  (POI, spawn, boutiques, systèmes) sont appliqués À CHAUD : la carte, les
--  zones de proximité et le PVP se mettent à jour sans restart.
-- =====================================================================

Noxa = Noxa or {}

local NUI = Noxa.NUI
local CFG = Noxa.Config

-- ---------------------------------------------------------------------
--  Application en place d'un domaine de config (préserve les références
--  capturées par les autres modules — cf. config-manager serveur).
-- ---------------------------------------------------------------------
local function deepCopy(v)
    if type(v) ~= 'table' then return v end
    local t = {}
    for k, val in pairs(v) do t[k] = deepCopy(val) end
    return t
end

local function replaceContents(target, source)
    if type(target) ~= 'table' or type(source) ~= 'table' then return end
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(source) do target[k] = deepCopy(v) end
end

-- ---------------------------------------------------------------------
--  Effets locaux des bascules systèmes
-- ---------------------------------------------------------------------
local function applySystems(sys)
    if type(sys) ~= 'table' then return end
    -- PVP global (tirs amis). Les autres drapeaux sont lus serveur.
    NetworkSetFriendlyFireOption(sys.pvp ~= false)
end

-- ---------------------------------------------------------------------
--  Réception d'un domaine diffusé par le serveur (refresh sans restart)
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:cfg:domain', function(name, data)
    if name == 'poi' then
        replaceContents(CFG.POI, data)
        if Noxa.Blips and Noxa.Blips.rebuild then Noxa.Blips.rebuild() end
        if Noxa.World and Noxa.World.rebuild then Noxa.World.rebuild() end
    elseif name == 'spawn' then
        replaceContents(CFG.DefaultSpawn, data)
    elseif name == 'shops' then
        replaceContents(CFG.Shops, data)
    elseif name == 'systems' then
        replaceContents(CFG.Systems, data)
        applySystems(CFG.Systems)
    end
end)

-- =====================================================================
--  Ouverture du panel (F9) — le serveur décide selon le rang superadmin
-- =====================================================================
RegisterCommand('serverpanel', function()
    TriggerServerEvent('noxa:cfg:open')
end, false)
RegisterKeyMapping('serverpanel', 'Ouvrir le panel gestion serveur', 'keyboard', 'F9')

-- Fermeture déclenchée par l'anti-superposition (ouverture d'un autre panneau).
NUI.registerPanel('serverpanel', function()
    NUI.send('serverpanel', 'close', {})
end)

-- Ouverture accordée par le serveur : on ouvre la NUI avec l'instantané.
RegisterNetEvent('noxa:cfg:grant', function(snapshot)
    NUI.openPanel('serverpanel')
    NUI.setFocus(true)
    NUI.send('serverpanel', 'open', snapshot or {})
end)

-- Instantané rafraîchi (après une action).
RegisterNetEvent('noxa:cfg:snapshot', function(snapshot)
    NUI.send('serverpanel', 'snapshot', snapshot or {})
end)

-- ---------------------------------------------------------------------
--  Ponts NUI -> Lua
-- ---------------------------------------------------------------------
RegisterNUICallback('cfgClose', function(_, cb)
    if NUI.activePanel == 'serverpanel' then
        NUI.closePanel('serverpanel')
        NUI.setFocus(false)
    end
    cb('ok')
end)

RegisterNUICallback('cfgAction', function(body, cb)
    if type(body) == 'table' and body.action then
        TriggerServerEvent('noxa:cfg:action', body)
    end
    cb('ok')
end)

RegisterNUICallback('cfgRefresh', function(_, cb)
    TriggerServerEvent('noxa:cfg:refresh')
    cb('ok')
end)

-- Position courante du joueur (pour pré-remplir spawn / point POI).
RegisterNUICallback('cfgGetCoords', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    cb({
        x = math.floor(c.x * 100) / 100,
        y = math.floor(c.y * 100) / 100,
        z = math.floor(c.z * 100) / 100,
        heading = math.floor(GetEntityHeading(ped) * 10) / 10,
    })
end)
