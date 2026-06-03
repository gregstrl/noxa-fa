-- =====================================================================
--  NOXA FA — Créateur de personnage (client-side)
--  Zone dédiée isolée + caméra 3/4 face. Le ped est figé pendant la
--  création ; chaque changement NUI est appliqué LIVE sur le ped via le
--  module Apparence. À la confirmation, l'apparence est envoyée au serveur
--  (validée + persistée), puis le personnage est chargé/spawné normalement.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Creator = {}

local Creator = Noxa.Creator
local A        = Noxa.Appearance
local NUI      = Noxa.NUI

-- Zone de création isolée (hangar LSIA, à l'écart de la map jouable).
local SCENE = { x = -1043.4, y = -2750.0, z = 21.36, heading = 331.0 }

local state = {
    active  = false,
    charId  = nil,
    data    = nil,          -- table d'apparence en cours d'édition
    cam     = nil,
    heading = SCENE.heading,
    zone    = 'face',
}

-- ---------------------------------------------------------------------
--  Caméra : 3 plans de cadrage (visage / buste / pieds) en léger 3/4.
-- ---------------------------------------------------------------------
local CAM_ZONES = {
    face = { fwd = 0.95, side = 0.30, height = 0.62, fov = 24.0, look = 0.60 },
    body = { fwd = 1.90, side = 0.45, height = 0.20, fov = 42.0, look = 0.10 },
    legs = { fwd = 1.40, side = 0.35, height = -0.55, fov = 36.0, look = -0.55 },
}

--- Positionne la caméra relativement au ped pour la zone demandée.
local function placeCamera(zone)
    local z = CAM_ZONES[zone] or CAM_ZONES.face
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local h = math.rad(GetEntityHeading(ped))
    -- Devant le ped (sens du regard) + décalage latéral pour le 3/4.
    local fx = pos.x - math.sin(h) * z.fwd
    local fy = pos.y + math.cos(h) * z.fwd
    local sx = math.cos(h) * z.side
    local sy = math.sin(h) * z.side
    if not state.cam then
        state.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
            fx + sx, fy + sy, pos.z + z.height, 0.0, 0.0, 0.0, z.fov, false, 0)
        SetCamActive(state.cam, true)
        RenderScriptCams(true, false, 0, true, true)
    else
        SetCamCoord(state.cam, fx + sx, fy + sy, pos.z + z.height)
        SetCamFov(state.cam, z.fov)
    end
    PointCamAtCoord(state.cam, pos.x, pos.y, pos.z + z.look)
    state.zone = zone
end

-- ---------------------------------------------------------------------
--  Démarrage du créateur pour un personnage fraîchement créé.
-- ---------------------------------------------------------------------
---@param charId integer
---@param gender integer 0|1
function Creator.start(charId, gender)
    if state.active then return end
    state.active  = true
    state.charId  = charId
    state.data    = A.default(gender)
    state.heading = SCENE.heading

    DoScreenFadeOut(300)
    Wait(350)

    local ped = PlayerPedId()
    RequestCollisionAtCoord(SCENE.x, SCENE.y, SCENE.z)
    SetEntityCoordsNoOffset(ped, SCENE.x + 0.0, SCENE.y + 0.0, SCENE.z + 0.0, false, false, false)
    SetEntityHeading(ped, SCENE.heading)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, true)

    -- Charger collision/sol avant d'afficher (anti-chute).
    local t = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < t do Wait(50) end

    A.apply(state.data)
    placeCamera('face')
    DoScreenFadeIn(400)

    -- L'écran NUI de sélection laisse place au panneau créateur.
    NUI.send('characters', 'close')
    NUI.send('creator', 'open', {
        gender = gender,
        data   = state.data,
        limits = A.LIMITS,
    })
end

--- Termine la session de création : détruit la caméra, dégèle (le spawn
--- du personnage prend le relais via noxa:char:selected).
function Creator.finish()
    if not state.active then return end
    state.active = false
    if state.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(state.cam, false)
        state.cam = nil
    end
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
end

function Creator.isActive() return state.active end

-- ---------------------------------------------------------------------
--  Callbacks NUI -> Lua : édition LIVE (appliquée directement sur le ped)
-- ---------------------------------------------------------------------

-- Rotation du ped (boutons ◄ ►). Recadre la caméra après rotation.
RegisterNUICallback('creatorRotate', function(body, cb)
    if state.active then
        local dir = tonumber(body.dir) or 1
        state.heading = (state.heading + dir * 18.0) % 360.0
        SetEntityHeading(PlayerPedId(), state.heading)
        placeCamera(state.zone)
    end
    cb('ok')
end)

-- Changement de plan caméra (visage / buste / pieds).
RegisterNUICallback('creatorCamera', function(body, cb)
    if state.active then placeCamera(tostring(body.zone or 'face')) end
    cb('ok')
end)

-- Mise à jour d'un attribut d'apparence (appliquée immédiatement).
RegisterNUICallback('creatorSet', function(body, cb)
    if not state.active then return cb('ok') end
    local d = state.data
    local kind = body.kind

    if kind == 'gender' then
        local g = (tonumber(body.value) == 1) and 1 or 0
        state.data = A.default(g)
        A.apply(state.data)
        placeCamera(state.zone)
        NUI.send('creator', 'reset', { gender = g, data = state.data })

    elseif kind == 'parents' then
        local hb = d.headBlend
        hb.shapeFirst  = tonumber(body.dad) or hb.shapeFirst
        hb.shapeSecond = tonumber(body.mom) or hb.shapeSecond
        hb.skinFirst   = hb.shapeFirst
        hb.skinSecond  = hb.shapeSecond
        A.apply(d)

    elseif kind == 'mix' then
        local hb = d.headBlend
        if body.shapeMix ~= nil then hb.shapeMix = tonumber(body.shapeMix) or 0.5 end
        if body.skinMix ~= nil then hb.skinMix = tonumber(body.skinMix) or 0.5 end
        A.apply(d)

    elseif kind == 'face' then
        local i = tonumber(body.index)
        if i then
            d.faceFeatures[i] = (tonumber(body.value) or 0.0) + 0.0
            SetPedFaceFeature(PlayerPedId(), i, d.faceFeatures[i])
        end

    elseif kind == 'overlay' then
        local i = tonumber(body.index)
        if i then
            d.overlays[i] = d.overlays[i] or { value = 0, colour = 0, opacity = 1.0 }
            d.overlays[i].value = tonumber(body.value) or 0
            d.overlays[i].opacity = tonumber(body.opacity) or d.overlays[i].opacity or 1.0
            A.apply(d)
        end

    elseif kind == 'overlayColor' then
        local i = tonumber(body.index)
        if i and d.overlays[i] then
            d.overlays[i].colour = tonumber(body.colour) or 0
            d.overlays[i].secondColour = tonumber(body.colour) or 0
            A.apply(d)
        end

    elseif kind == 'hair' then
        d.hair.style = tonumber(body.value) or 0
        SetPedComponentVariation(PlayerPedId(), 2, d.hair.style, 0, 0)

    elseif kind == 'hairColor' then
        d.hair.color = tonumber(body.color) or d.hair.color or 0
        d.hair.highlight = tonumber(body.highlight) or d.hair.highlight or 0
        SetPedHairColor(PlayerPedId(), d.hair.color, d.hair.highlight)

    elseif kind == 'eye' then
        d.eyeColor = tonumber(body.value) or 0
        SetPedEyeColor(PlayerPedId(), d.eyeColor)

    elseif kind == 'component' then
        local id = tonumber(body.id)
        if id then
            d.components[id] = d.components[id] or { drawable = 0, texture = 0 }
            if body.drawable ~= nil then d.components[id].drawable = tonumber(body.drawable) or 0 end
            if body.texture ~= nil then d.components[id].texture = tonumber(body.texture) or 0 end
            SetPedComponentVariation(PlayerPedId(), id,
                d.components[id].drawable, d.components[id].texture, 0)
        end
    end
    cb('ok')
end)

-- Confirmation : envoie l'apparence au serveur (validation + persistance),
-- qui charge ensuite le personnage et déclenche le spawn.
RegisterNUICallback('creatorConfirm', function(_, cb)
    if state.active and state.charId then
        TriggerServerEvent('noxa:char:saveAppearance', {
            id = state.charId, appearance = state.data,
        })
    end
    cb('ok')
end)

return Creator
