-- =====================================================================
--  NOXA FA — Immobilier (server-side, autoritaire)
--  • Seed des biens depuis la config (coords) ; état (propriétaire, verrou,
--    mobilier) persisté en base noxa_properties.
--  • Achat atomique (anti double-achat / anti-dupe), paiement bancaire borné.
--  • Entrée/sortie : le serveur renvoie les coords d'intérieur (instance
--    logique par propriétaire). Verrouillage réservé au propriétaire.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Properties = {}

local Prop = Noxa.Properties
local U    = Noxa.Utils
local E    = Noxa.Enums
local DB   = Noxa.DB
local S    = Noxa.Security
local CFG  = Noxa.Config

-- Cache : [id] = ligne enrichie (coords décodées, mobilier décodé)
local cache = {}

-- ---------------------------------------------------------------------
--  Initialisation : seed config -> base, puis chargement en cache
-- ---------------------------------------------------------------------
function Prop.init()
    for _, p in ipairs(CFG.Properties) do
        local tier = CFG.PropertyTiers[p.tier]
        local inside = CFG.Interiors[p.tier] or CFG.DefaultSpawn
        DB.ensureProperty({
            name   = p.name,
            label  = p.label,
            tier   = p.tier,
            price  = tier and tier.price or 0,
            door   = U.jsonEncode(p.door),
            inside = U.jsonEncode(inside),
        })
    end
    for _, r in ipairs(DB.getProperties()) do
        cache[r.id] = {
            id        = r.id,
            name      = r.name,
            label     = r.label,
            tier      = r.tier,
            price     = math.floor(tonumber(r.price) or 0),
            owner_cid = r.owner_cid,
            locked    = r.locked == 1,
            door      = U.jsonDecode(r.coords_door, {}),
            inside    = U.jsonDecode(r.coords_inside, CFG.DefaultSpawn),
            furniture = U.jsonDecode(r.furniture, {}),
        }
    end
    U.print('info', 'Immobilier chargé : %d bien(s).', U.tableCount(cache))
end

-- ---------------------------------------------------------------------
--  Vue client (lecture seule). On expose tout le parc ; le client compare
--  owner_cid à son propre citizenid pour adapter l'UI (acheter / entrer).
-- ---------------------------------------------------------------------
local function buildClientList()
    local list = {}
    for _, p in pairs(cache) do
        local tier = CFG.PropertyTiers[p.tier]
        list[#list + 1] = {
            id        = p.id,
            label     = p.label,
            tier      = p.tier,
            tierLabel = tier and tier.label or p.tier,
            price     = p.price,
            owner     = p.owner_cid,
            locked    = p.locked,
            door      = p.door,
        }
    end
    return list
end

local function broadcastList()
    TriggerClientEvent('noxa:prop:list', -1, buildClientList())
end

-- Envoi initial (le client redemande après chargement complet du perso).
S.onNet('noxa:prop:request', function(src)
    TriggerClientEvent('noxa:prop:list', src, buildClientList())
end)

-- ---------------------------------------------------------------------
--  Achat (atomique + paiement bancaire borné)
-- ---------------------------------------------------------------------
S.onNet('noxa:prop:buy', function(src, ply, propId)
    propId = tonumber(propId)
    local p = propId and cache[propId]
    if not p then return S.flag(src, 'prop:buy bien inconnu') end
    if p.owner_cid then
        return TriggerClientEvent('noxa:notify', src, 'Ce bien est déjà vendu.', 'error')
    end
    if ply:getMoney(E.Accounts.BANK) < p.price then
        return TriggerClientEvent('noxa:notify', src, 'Solde bancaire insuffisant.', 'error')
    end

    -- Réservation atomique en base AVANT de débiter (anti double-achat).
    if not DB.buyProperty(propId, ply.citizenid) then
        return TriggerClientEvent('noxa:notify', src, 'Bien indisponible.', 'error')
    end
    if not ply:removeMoney(E.Accounts.BANK, p.price, 'property:' .. p.name) then
        -- Débit impossible : on annule la réservation pour rester cohérent.
        DB.releaseProperty(propId)
        return TriggerClientEvent('noxa:notify', src, 'Paiement refusé.', 'error')
    end

    p.owner_cid = ply.citizenid
    p.locked    = true
    DB.log('property', 'info', ply.license,
        ('%s a acheté %s (%s)'):format(ply.citizenid, p.label, U.money(p.price)))
    TriggerClientEvent('noxa:notify', src, ('Félicitations ! %s acheté.'):format(p.label), 'success')
    broadcastList()
end)

-- ---------------------------------------------------------------------
--  Entrée / sortie
-- ---------------------------------------------------------------------
local function canAccess(ply, p)
    -- Propriétaire (extensible : invités/colocataires à venir).
    return p.owner_cid ~= nil and p.owner_cid == ply.citizenid
end

S.onNet('noxa:prop:enter', function(src, ply, propId)
    propId = tonumber(propId)
    local p = propId and cache[propId]
    if not p then return end
    if not canAccess(ply, p) then
        return TriggerClientEvent('noxa:notify', src, 'Vous n\'avez pas la clé.', 'error')
    end
    if p.locked then
        return TriggerClientEvent('noxa:notify', src, 'La porte est verrouillée.', 'error')
    end
    TriggerClientEvent('noxa:prop:enterInterior', src, {
        id = p.id, inside = p.inside, door = p.door, furniture = p.furniture,
    })
end)

-- ---------------------------------------------------------------------
--  Verrouillage (propriétaire uniquement)
-- ---------------------------------------------------------------------
S.onNet('noxa:prop:lock', function(src, ply, propId, state)
    propId = tonumber(propId)
    local p = propId and cache[propId]
    if not p then return end
    if p.owner_cid ~= ply.citizenid then
        return S.flag(src, 'prop:lock non propriétaire')
    end
    p.locked = state == true
    DB.setPropertyLocked(propId, p.locked)
    TriggerClientEvent('noxa:notify', src,
        p.locked and 'Porte verrouillée. 🔒' or 'Porte déverrouillée. 🔓', 'inform')
    broadcastList()
end)

-- ---------------------------------------------------------------------
--  Mobilier (propriétaire uniquement) — sauvegarde de la disposition
-- ---------------------------------------------------------------------
S.onNet('noxa:prop:furniture:save', function(src, ply, propId, furniture)
    propId = tonumber(propId)
    local p = propId and cache[propId]
    if not p then return end
    if p.owner_cid ~= ply.citizenid then
        return S.flag(src, 'prop:furniture non propriétaire')
    end
    if type(furniture) ~= 'table' then return end

    -- Validation : modèles autorisés uniquement, nombre borné.
    local allowed = {}
    for _, f in ipairs(CFG.Furniture) do allowed[f.model] = true end
    local clean = {}
    for _, item in ipairs(furniture) do
        if #clean >= 50 then break end
        if type(item) == 'table' and allowed[item.model]
           and type(item.x) == 'number' and type(item.y) == 'number' and type(item.z) == 'number' then
            clean[#clean + 1] = {
                model = item.model,
                x = item.x, y = item.y, z = item.z,
                heading = tonumber(item.heading) or 0.0,
            }
        end
    end
    p.furniture = clean
    DB.savePropertyFurniture(propId, U.jsonEncode(clean))
    TriggerClientEvent('noxa:notify', src, 'Mobilier sauvegardé.', 'success')
end)

-- ---------------------------------------------------------------------
--  Démarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    -- Laisse la base se préparer (idempotence du seed sociétés/biens).
    Wait(1500)
    Prop.init()
end)

return Prop