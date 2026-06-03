-- =====================================================================
--  NOXA FA — Apparence du personnage (client-side)
--  Applique une table d'apparence (JSON persistée en BDD) sur un ped :
--  modèle freemode, héritage du visage (head blend), traits faciaux,
--  superpositions (barbe/sourcils/teint), vêtements, coiffure & couleurs.
--  Source unique de la logique « données -> ped » : réutilisée par le
--  créateur de personnage ET par le rechargement à la connexion.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Appearance = {}

local A = Noxa.Appearance

-- Modèles freemode (seuls modèles supportant le head blend / customisation).
A.MODELS = { [0] = 'mp_m_freemode_01', [1] = 'mp_f_freemode_01' }

-- Bornes de validation (le serveur revalide ; ici protection d'application).
A.LIMITS = {
    parents      = 45,   -- 0..45 visages parents (mère/père)
    faceFeatures = 19,   -- 0..19 traits faciaux (sliders)
    overlays     = 12,   -- 0..12 superpositions tête
    hairColors   = 63,   -- 0..63 palette cheveux
    eyeColors    = 31,   -- 0..31 couleurs des yeux
}

-- ---------------------------------------------------------------------
--  Apparence par défaut (selon le genre). Base neutre et propre.
-- ---------------------------------------------------------------------
---@param gender integer 0 = homme, 1 = femme
---@return table
function A.default(gender)
    gender = (tonumber(gender) == 1) and 1 or 0
    return {
        model = A.MODELS[gender],
        gender = gender,
        headBlend = {
            shapeFirst = gender == 1 and 21 or 0,
            shapeSecond = gender == 1 and 21 or 0,
            skinFirst = gender == 1 and 21 or 0,
            skinSecond = gender == 1 and 21 or 0,
            shapeMix = 0.5, skinMix = 0.5,
        },
        faceFeatures = {},                       -- [0..19] = -1.0..1.0
        overlays = {},                           -- [id] = { value, colour, opacity }
        hair = { style = 0, color = 0, highlight = 0 },
        eyeColor = 0,
        components = {                           -- vêtements de départ neutres
            [3]  = { drawable = gender == 1 and 15 or 15, texture = 0 },  -- torse (bras)
            [4]  = { drawable = gender == 1 and 14 or 21, texture = 0 },  -- jambes
            [6]  = { drawable = gender == 1 and 35 or 34, texture = 0 },  -- chaussures
            [8]  = { drawable = gender == 1 and 15 or 15, texture = 0 },  -- sous-vêtement haut
            [11] = { drawable = gender == 1 and 15 or 15, texture = 0 },  -- haut
        },
        props = {},
    }
end

-- ---------------------------------------------------------------------
--  Chargement du modèle (borné, libère la mémoire après application).
-- ---------------------------------------------------------------------
---@param model string|number
---@return boolean ok
local function ensureModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return false end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    return HasModelLoaded(hash) or true
end

-- ---------------------------------------------------------------------
--  Application complète d'une apparence sur le ped local.
-- ---------------------------------------------------------------------
---@param data table apparence (peut être partielle)
function A.apply(data)
    if type(data) ~= 'table' then return end
    local gender = (tonumber(data.gender) == 1) and 1 or 0
    local model = data.model or A.MODELS[gender]

    -- 1. Modèle : seul un modèle freemode permet la customisation complète.
    ensureModel(model)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    -- 2. Héritage du visage (head blend : parents + mélange).
    local hb = data.headBlend
    if hb then
        SetPedHeadBlendData(ped,
            tonumber(hb.shapeFirst) or 0, tonumber(hb.shapeSecond) or 0, 0,
            tonumber(hb.skinFirst) or 0, tonumber(hb.skinSecond) or 0, 0,
            (tonumber(hb.shapeMix) or 0.5) + 0.0,
            (tonumber(hb.skinMix) or 0.5) + 0.0, 0.0, false)
    end

    -- 3. Traits faciaux (0..19, valeur -1.0..1.0).
    if type(data.faceFeatures) == 'table' then
        for idx, val in pairs(data.faceFeatures) do
            local i = tonumber(idx)
            if i and i >= 0 and i <= A.LIMITS.faceFeatures then
                SetPedFaceFeature(ped, i, (tonumber(val) or 0.0) + 0.0)
            end
        end
    end

    -- 4. Superpositions de tête (barbe, sourcils, teint, maquillage...).
    if type(data.overlays) == 'table' then
        for idx, ov in pairs(data.overlays) do
            local i = tonumber(idx)
            if i and i >= 0 and i <= A.LIMITS.overlays and type(ov) == 'table' then
                local value = tonumber(ov.value) or 0
                SetPedHeadOverlay(ped, i, value, (tonumber(ov.opacity) or 1.0) + 0.0)
                if ov.colour then
                    -- colourType : 1 = cheveux (barbe/sourcils), 2 = make-up.
                    local ctype = (i == 1 or i == 2 or i == 10) and 1 or 2
                    SetPedHeadOverlayColor(ped, i, ctype, tonumber(ov.colour) or 0,
                        tonumber(ov.secondColour) or tonumber(ov.colour) or 0)
                end
            end
        end
    end

    -- 5. Coiffure (composant 2) + couleur des cheveux (teinte + reflets).
    local hair = data.hair or {}
    SetPedComponentVariation(ped, 2, tonumber(hair.style) or 0, 0, 0)
    SetPedHairColor(ped, tonumber(hair.color) or 0, tonumber(hair.highlight) or 0)

    -- 6. Couleur des yeux.
    SetPedEyeColor(ped, tonumber(data.eyeColor) or 0)

    -- 7. Vêtements (composants) & accessoires (props).
    if type(data.components) == 'table' then
        for cid, c in pairs(data.components) do
            local id = tonumber(cid)
            if id and type(c) == 'table' then
                SetPedComponentVariation(ped, id, tonumber(c.drawable) or 0,
                    tonumber(c.texture) or 0, 0)
            end
        end
    end
    if type(data.props) == 'table' then
        for pid, p in pairs(data.props) do
            local id = tonumber(pid)
            if id and type(p) == 'table' then
                if (tonumber(p.drawable) or -1) < 0 then
                    ClearPedProp(ped, id)
                else
                    SetPedPropIndex(ped, id, tonumber(p.drawable) or 0,
                        tonumber(p.texture) or 0, true)
                end
            end
        end
    end
end

return A
