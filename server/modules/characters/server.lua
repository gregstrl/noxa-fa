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

    local row = DB.createCharacter(acc.id, {
        slot        = #existing,
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
    TriggerClientEvent('noxa:char:createResult', src, { ok = true, id = row.id })
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
        citizenid = ply.citizenid,
        position  = ply.position,
        appearance = ply.appearance,
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
