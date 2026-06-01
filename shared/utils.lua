-- =====================================================================
--  NOXA FA — Fonctions utilitaires partagées
-- =====================================================================

Noxa = Noxa or {}
Noxa.Utils = {}

local U = Noxa.Utils

-- Log unifié avec préfixe coloré (console serveur/client)
function U.print(level, msg, ...)
    local tag = ('[Noxa:%s]'):format(level or 'info')
    print(('%s %s'):format(tag, msg:format(...)))
end

function U.debug(msg, ...)
    if Noxa.Config and Noxa.Config.Debug then
        U.print('debug', msg, ...)
    end
end

-- Arrondit et borne un montant d'argent à un entier positif.
-- Centralise la validation pour éviter les floats / valeurs négatives.
function U.sanitizeAmount(amount)
    amount = tonumber(amount)
    if not amount then return nil end
    amount = math.floor(amount)
    if amount <= 0 then return nil end
    return amount
end

-- Génère un citizenid public unique (ex: NX + 6 caractères alphanumériques)
function U.generateCitizenId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'NX'
    for _ = 1, 6 do
        local i = math.random(1, #chars)
        id = id .. chars:sub(i, i)
    end
    return id
end

-- Nettoie / borne un nom de personnage (anti-injection, anti-troll)
function U.sanitizeName(name, minLen, maxLen)
    if type(name) ~= 'string' then return nil end
    -- supprime les caractères non autorisés (lettres accentuées, tiret, espace)
    name = name:gsub("[^%a%-%' ]", '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if #name < (minLen or 2) or #name > (maxLen or 24) then return nil end
    -- capitalise la première lettre
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Encodage / décodage JSON sûr (jamais d'erreur fatale)
function U.jsonDecode(str, default)
    if type(str) ~= 'string' or str == '' then return default end
    local ok, res = pcall(json.decode, str)
    if ok and res ~= nil then return res end
    return default
end

function U.jsonEncode(tbl)
    local ok, res = pcall(json.encode, tbl)
    if ok then return res end
    return '{}'
end

return U
