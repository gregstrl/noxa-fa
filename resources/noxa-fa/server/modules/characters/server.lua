-- =====================================================================
--  NOXA FA — Module Personnages (server-side)
--  Création, sélection, suppression multi-personnages.
--  Sécurité : ownership vérifié serveur, validation stricte des entrées.
-- =====================================================================

Noxa = Noxa or {}

local U   = Noxa.Utils
local DB  = Noxa.DB
local S   = Noxa.Security
local CFG = Noxa.Config

-- Cache du compte par source pendant la phase de sélection (avant chargement perso)
local accounts = {}

-- ---------------------------------------------------------------------
--  Helpers
-- ---------------------------------------------------------------------

--- Récupère (et met en cache) le compte du joueur.
local function getAccount(src)
    if accounts[src] then return accounts[src] end
    local license = GetPlayerIdentifierByType(src, 'license')
    local acc = license and DB.ensureAccount(license, GetPlayerName(src))
    accounts[src] = acc
    return acc
end

AddEventHandler('playerDropped', function()
    accounts[source] = nil
end)

--- Génère un citizenid garanti unique.
local function uniqueCitizenId()
    for _ = 1, 10 do
        local id = U.generateCitizenId()
        if not DB.citizenIdExists(id) then return id end
    end
    -- Repli extrêmement improbable
    return U.generateCitizenId() .. tostring(math.random(10, 99))
end

-- ---------------------------------------------------------------------
--  Sélection : envoyer la liste des personnages au client
-- ---------------------------------------------------------------------

S.onNet('noxa:char:requestList', function(src)
    local acc = getAccount(src)
    if not acc then
        return TriggerClientEvent('noxa:char:setList', src, { error = 'account' })
    end
    local chars = DB.getCharacters(acc.id)
    -- On n'expose que les champs nécessaires à l'écran de sélection
    local list = {}
    for _, c in ipairs(chars) do
        list[#list + 1] = {
            id        = c.id,
            slot      = c.slot,
            firstname = c.firstname,
            lastname  = c.lastname,
            job       = c.job,
            cash      = c.cash,
            bank      = c.bank,
            dob       = c.dob,
        }
    end
    TriggerClientEvent('noxa:char:setList', src, {
        characters = list,
        maxSlots   = CFG.Characters.maxSlots,
    })
end, { requireLoaded = false })

-- ---------------------------------------------------------------------
--  Création d'un personnage
-- ---------------------------------------------------------------------

S.onNet('noxa:char:create', function(src, _, payload)
    local acc = getAccount(src)
    if not acc then return end
    if type(payload) ~= 'table' then
        return S.flag(src, 'char:create payload invalide')
    end

    -- Limite de slots (anti-spam base de données)
    local existing = DB.getCharacters(acc.id)
    if #existing >= CFG.Characters.maxSlots then
        return TriggerClientEvent('noxa:char:createResult', src, { error = 'maxSlots' })
    end

    -- Validation stricte des entrées (server-side, jamais le client)
    local firstname = U.sanitizeName(payload.firstname, CFG.Characters.minNameLength, CFG.Characters.maxNameLength)
    local lastname  = U.sanitizeName(payload.lastname,  CFG.Characters.minNameLength, CFG.Characters.maxNameLength)
    if not firstname or not lastname then
        return TriggerClientEvent('noxa:char:createResult', src, { error = 'name' })
    end
    local gender = (tonumber(payload.gender) == 1) and 1 or 0
    local dob = type(payload.dob) == 'string' and payload.dob:match('^%d%d%d%d%-%d%d%-%d%d$') or '2000-01-01'

    -- Premier emplacement libre : #existing réutilise un slot déjà pris si un
    -- personnage du milieu a été supprimé (slots 0,2 -> #existing=2 = collision).
    local used = {}
    for _, c in ipairs(existing) do used[c.slot] = true end
    local slot = 0
    while used[slot] do slot = slot + 1 end

    local row = DB.createCharacter(acc.id, {
        slot        = slot,
        citizenid   = uniqueCitizenId(),
        firstname   = firstname,
        lastname    = lastname,
        dob         = dob,
        gender      = gender,
        nationality = type(payload.nationality) == 'string' and payload.nationality:sub(1, 48) or 'Inconnue',
        cash        = CFG.Characters.startCash,
        bank        = CFG.Characters.startBank,
        metadata    = {},
    })
    if not row then
        return TriggerClientEvent('noxa:char:createResult', src, { error = 'db' })
    end

    DB.log('character', 'info', acc.license,
        ('Création personnage %s %s (%s)'):format(firstname, lastname, row.citizenid))
    TriggerClientEvent('noxa:char:createResult', src, { ok = true, id = row.id, gender = gender })
end, { requireLoaded = false })

-- ---------------------------------------------------------------------
--  Apparence : validation + persistance (créateur de personnage)
--  Le client n'est jamais autoritaire : on borne chaque valeur côté serveur
--  avant de l'écrire (anti-injection / valeurs hors plage / crash client).
-- ---------------------------------------------------------------------

--- Borne un nombre dans [min,max] (retourne def si invalide).
local function num(v, min, max, def)
    v = tonumber(v)
    if not v then return def end
    if v < min then return min end
    if v > max then return max end
    return v
end

--- Nettoie une table d'apparence reçue du client (structure stricte, bornée).
local function sanitizeAppearance(raw)
    if type(raw) ~= 'table' then return nil end
    local gender = (tonumber(raw.gender) == 1) and 1 or 0
    local out = {
        gender = gender,
        model = gender == 1 and 'mp_f_freemode_01' or 'mp_m_freemode_01',
        headBlend = {}, faceFeatures = {}, overlays = {},
        hair = {}, components = {}, props = {}, eyeColor = 0,
    }
    local hb = type(raw.headBlend) == 'table' and raw.headBlend or {}
    out.headBlend = {
        shapeFirst  = math.floor(num(hb.shapeFirst, 0, 45, 0)),
        shapeSecond = math.floor(num(hb.shapeSecond, 0, 45, 0)),
        skinFirst   = math.floor(num(hb.skinFirst, 0, 45, 0)),
        skinSecond  = math.floor(num(hb.skinSecond, 0, 45, 0)),
        shapeMix    = num(hb.shapeMix, 0.0, 1.0, 0.5),
        skinMix     = num(hb.skinMix, 0.0, 1.0, 0.5),
    }
    if type(raw.faceFeatures) == 'table' then
        for k, v in pairs(raw.faceFeatures) do
            local i = tonumber(k)
            if i and i >= 0 and i <= 19 then out.faceFeatures[tostring(i)] = num(v, -1.0, 1.0, 0.0) end
        end
    end
    if type(raw.overlays) == 'table' then
        for k, ov in pairs(raw.overlays) do
            local i = tonumber(k)
            if i and i >= 0 and i <= 12 and type(ov) == 'table' then
                out.overlays[tostring(i)] = {
                    value = math.floor(num(ov.value, 0, 255, 0)),
                    colour = math.floor(num(ov.colour, 0, 63, 0)),
                    secondColour = math.floor(num(ov.secondColour, 0, 63, 0)),
                    opacity = num(ov.opacity, 0.0, 1.0, 1.0),
                }
            end
        end
    end
    local hair = type(raw.hair) == 'table' and raw.hair or {}
    out.hair = {
        style = math.floor(num(hair.style, 0, 80, 0)),
        color = math.floor(num(hair.color, 0, 63, 0)),
        highlight = math.floor(num(hair.highlight, 0, 63, 0)),
    }
    out.eyeColor = math.floor(num(raw.eyeColor, 0, 31, 0))
    if type(raw.components) == 'table' then
        for k, c in pairs(raw.components) do
            local id = tonumber(k)
            if id and id >= 0 and id <= 11 and type(c) == 'table' then
                out.components[tostring(id)] = {
                    drawable = math.floor(num(c.drawable, 0, 500, 0)),
                    texture = math.floor(num(c.texture, 0, 100, 0)),
                }
            end
        end
    end
    if type(raw.props) == 'table' then
        for k, p in pairs(raw.props) do
            local id = tonumber(k)
            if id and id >= 0 and id <= 12 and type(p) == 'table' then
                out.props[tostring(id)] = {
                    drawable = math.floor(num(p.drawable, -1, 200, -1)),
                    texture = math.floor(num(p.texture, 0, 100, 0)),
                }
            end
        end
    end
    return out
end

S.onNet('noxa:char:saveAppearance', function(src, _, payload)
    local acc = getAccount(src)
    if not acc then return end
    if type(payload) ~= 'table' then return S.flag(src, 'saveAppearance payload invalide') end
    local charId = tonumber(payload.id)
    if not charId then return S.flag(src, 'saveAppearance id invalide') end

    local row = DB.getOwnedCharacter(charId, acc.id)
    if not row then return S.flag(src, ('saveAppearance non possédé (id=%s)'):format(charId)) end

    local appearance = sanitizeAppearance(payload.appearance)
    if not appearance then return S.flag(src, 'saveAppearance apparence invalide') end

    DB.saveAppearance(charId, acc.id, U.jsonEncode(appearance))

    -- Charge le personnage et déclenche le spawn (l'apparence vient d'être figée).
    row.appearance = U.jsonEncode(appearance)
    local ply = Noxa.Players.load(src, row, acc)
    TriggerClientEvent('noxa:char:selected', src, {
        citizenid  = ply.citizenid,
        position   = ply.position,
        appearance = ply.appearance,
        gender     = ply.gender,
    })
end, { requireLoaded = false })

-- ---------------------------------------------------------------------
--  Sélection / chargement d'un personnage
-- ---------------------------------------------------------------------

S.onNet('noxa:char:select', function(src, _, charId)
    local acc = getAccount(src)
    if not acc then return end
    charId = tonumber(charId)
    if not charId then return S.flag(src, 'char:select id invalide') end

    -- Vérification d'appartenance côté serveur (anti-triche : pas le perso d'autrui)
    local row = DB.getOwnedCharacter(charId, acc.id)
    if not row then
        return S.flag(src, ('char:select non possédé (id=%s)'):format(charId))
    end

    local ply = Noxa.Players.load(src, row, acc)
    TriggerClientEvent('noxa:char:selected', src, {
        citizenid  = ply.citizenid,
        position   = ply.position,
        appearance = ply.appearance,
        gender     = ply.gender,
    })
end, { requireLoaded = false })

-- ---------------------------------------------------------------------
--  Suppression (soft-delete)
-- ---------------------------------------------------------------------

S.onNet('noxa:char:delete', function(src, _, charId)
    local acc = getAccount(src)
    if not acc then return end
    charId = tonumber(charId)
    if not charId then return S.flag(src, 'char:delete id invalide') end

    local row = DB.getOwnedCharacter(charId, acc.id)
    if not row then
        return S.flag(src, ('char:delete non possédé (id=%s)'):format(charId))
    end
    DB.deleteCharacter(charId, acc.id)
    DB.log('character', 'info', acc.license, ('Suppression personnage %s'):format(row.citizenid))
    TriggerClientEvent('noxa:char:deleteResult', src, { ok = true, id = charId })
end, { requireLoaded = false })
