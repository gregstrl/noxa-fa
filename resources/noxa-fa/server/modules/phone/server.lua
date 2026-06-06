-- =====================================================================
--  NOXA FA — Téléphone (server-side, autoritaire)
--  • Attribution paresseuse d'un numéro unique au premier usage.
--  • Contacts, SMS (livraison temps réel si destinataire en ligne), réseau
--    social. Toute donnée d'origine joueur est bornée et validée.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Phone = {}

local Phone = Noxa.Phone
local U     = Noxa.Utils
local DB    = Noxa.DB
local S     = Noxa.Security
local CFG   = Noxa.Config

-- ---------------------------------------------------------------------
--  Numéro de téléphone
-- ---------------------------------------------------------------------
local function genNumber()
    return ('555-%04d%02d'):format(math.random(0, 9999), math.random(0, 99))
end

--- Garantit que le joueur possède un numéro (génère + persiste si absent).
local function ensureNumber(ply)
    if ply.phone and ply.phone ~= '' then return ply.phone end
    -- Collision improbable sur un espace de ~1M de numéros : tirage direct.
    local num = genNumber()
    ply.phone = num
    DB.setCharacterPhone(ply.id, num)
    return num
end

--- Recherche un joueur en ligne par son numéro (pour livraison temps réel).
local function findByNumber(number)
    for _, p in pairs(Noxa.Players.getAll()) do
        if p.phone == number then return p end
    end
    return nil
end

-- ---------------------------------------------------------------------
--  Bootstrap : envoie l'état initial du téléphone au client
-- ---------------------------------------------------------------------
S.onNet('noxa:phone:request', function(src, ply)
    local number = ensureNumber(ply)
    local convos = DB.getConversations(number)
    -- Fils complets (peer + messages) pour les UI qui PRÉCHARGENT les
    -- conversations (ex. design noxa_phone). Borné pour limiter les requêtes.
    local threads = {}
    for i = 1, math.min(#convos, 20) do
        local peer = convos[i].peer
        threads[#threads + 1] = { peer = peer, messages = DB.getThread(number, peer, 50) }
    end
    TriggerClientEvent('noxa:phone:bootstrap', src, {
        number   = number,
        owner    = ply:getName(),
        contacts = DB.getContacts(ply.citizenid),
        convos   = convos,
        threads  = threads,
        tweets   = DB.getTweets(30),
        bank     = ply.bank or 0,
        cash     = ply.cash or 0,
    })
end)

-- ---------------------------------------------------------------------
--  Contacts
-- ---------------------------------------------------------------------
S.onNet('noxa:phone:contact:add', function(src, ply, name, number)
    name   = U.sanitizeName(name, 1, 32) or (type(name) == 'string' and name:sub(1, 32))
    number = type(number) == 'string' and number:gsub('[^%d%-+]', ''):sub(1, 15) or nil
    if not name or not number or number == '' then
        return TriggerClientEvent('noxa:notify', src, 'Contact invalide.', 'error')
    end
    DB.addContact(ply.citizenid, name, number)
    TriggerClientEvent('noxa:phone:contacts', src, DB.getContacts(ply.citizenid))
    TriggerClientEvent('noxa:notify', src, 'Contact ajouté.', 'success')
end)

S.onNet('noxa:phone:contact:delete', function(src, ply, id)
    id = tonumber(id)
    if not id then return end
    DB.deleteContact(id, ply.citizenid)
    TriggerClientEvent('noxa:phone:contacts', src, DB.getContacts(ply.citizenid))
end)

-- ---------------------------------------------------------------------
--  SMS
-- ---------------------------------------------------------------------
S.onNet('noxa:phone:sms:send', function(src, ply, toNum, body)
    local myNum = ensureNumber(ply)
    toNum = type(toNum) == 'string' and toNum:gsub('[^%d%-+]', ''):sub(1, 15) or nil
    body  = type(body) == 'string' and body:sub(1, 255) or nil
    if not toNum or toNum == '' or not body or body == '' or toNum == myNum then
        return TriggerClientEvent('noxa:notify', src, 'Message invalide.', 'error')
    end
    DB.addMessage(myNum, toNum, body)

    -- Livraison temps réel si le destinataire est en ligne.
    local target = findByNumber(toNum)
    if target then
        TriggerClientEvent('noxa:phone:sms:incoming', target.source,
            { from = myNum, body = body })
    end
    TriggerClientEvent('noxa:phone:sms:sent', src, { to = toNum, body = body })
end)

S.onNet('noxa:phone:sms:thread', function(src, ply, peer)
    local myNum = ensureNumber(ply)
    peer = type(peer) == 'string' and peer:gsub('[^%d%-+]', ''):sub(1, 15) or nil
    if not peer then return end
    TriggerClientEvent('noxa:phone:sms:threadData', src, {
        peer = peer, messages = DB.getThread(myNum, peer, CFG.Phone.maxMessages),
    })
end)

-- ---------------------------------------------------------------------
--  Réseau social (Twitter-like)
-- ---------------------------------------------------------------------
S.onNet('noxa:phone:tweet:post', function(src, ply, body)
    body = type(body) == 'string' and body:sub(1, 280) or nil
    if not body or body:gsub('%s', '') == '' then
        return TriggerClientEvent('noxa:notify', src, 'Tweet vide.', 'error')
    end
    local author = ('@%s'):format((ply.firstname or 'user'):lower())
    DB.addTweet(ply.citizenid, author, body)
    -- Diffuse le nouveau tweet à tous les téléphones connectés.
    TriggerClientEvent('noxa:phone:tweet:new', -1, { author = author, body = body, created_at = os.date('%H:%M') })
end)

S.onNet('noxa:phone:tweets:list', function(src)
    TriggerClientEvent('noxa:phone:tweets', src, DB.getTweets(30))
end)

return Phone