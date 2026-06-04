-- =====================================================================
--  NOXA FA — Module Inventaire (server-side, autoritaire & anti-dupe)
--  ---------------------------------------------------------------------
--  Modèle de données : self.inventory = liste d'emplacements
--      { { slot=1, name='bread', count=3, meta={} }, ... }
--  • Source de vérité UNIQUE en mémoire (objet Player) ; persistée en JSON
--    dans noxa_characters.inventory à la sauvegarde du personnage (atomique
--    avec l'argent/metadata). Pas de table séparée = pas de désync = pas de
--    duplication possible entre deux sources concurrentes.
--  • Toute mutation est bornée (poids, slots, quantités) et journalisable.
--  • Le client n'émet QUE des intentions ; aucune valeur n'est de confiance.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Inventory = {}

local Inv    = Noxa.Inventory
local U      = Noxa.Utils
local CFG    = Noxa.Config
local ICFG   = Noxa.Config.Inventory
local S      = Noxa.Security
local Player = Noxa.PlayerClass

-- ---------------------------------------------------------------------
--  Helpers internes (opèrent sur la liste d'emplacements)
-- ---------------------------------------------------------------------

--- Normalise l'inventaire en liste propre (tolère un legacy {} ou objet).
local function normalize(inv)
    local out = {}
    if type(inv) ~= 'table' then return out end
    for _, e in pairs(inv) do
        if type(e) == 'table' and e.name and CFG.getItem(e.name) then
            out[#out + 1] = {
                slot  = tonumber(e.slot) or 0,
                name  = e.name,
                count = math.max(1, math.floor(tonumber(e.count) or 1)),
                meta  = type(e.meta) == 'table' and e.meta or {},
            }
        end
    end
    return out
end

--- Poids total transporté (grammes).
local function weightOf(inv)
    local w = 0
    for _, e in ipairs(inv) do
        local it = CFG.getItem(e.name)
        if it then w = w + (it.weight * e.count) end
    end
    return w
end

--- Premier emplacement libre (1..slots), ou nil si plein.
local function freeSlot(inv)
    local used = {}
    for _, e in ipairs(inv) do used[e.slot] = true end
    for s = 1, ICFG.slots do
        if not used[s] then return s end
    end
    return nil
end

--- Entrée occupant un emplacement donné.
local function atSlot(inv, slot)
    for _, e in ipairs(inv) do
        if e.slot == slot then return e end
    end
    return nil
end

--- Retire les entrées vides (count <= 0).
local function compact(inv)
    local out = {}
    for _, e in ipairs(inv) do
        if e.count > 0 then out[#out + 1] = e end
    end
    return out
end

-- ---------------------------------------------------------------------
--  API Player (autoritaire)
-- ---------------------------------------------------------------------

--- Garantit que self.inventory est une liste normalisée (idempotent).
function Player:invEnsure()
    if not self._invReady then
        self.inventory = normalize(self.inventory)
        self._invReady = true
    end
    return self.inventory
end

function Player:invWeight()
    return weightOf(self:invEnsure())
end

--- Quantité totale d'un item dans le sac.
function Player:invCount(name)
    local n = 0
    for _, e in ipairs(self:invEnsure()) do
        if e.name == name then n = n + e.count end
    end
    return n
end

function Player:hasItem(name, count)
    return self:invCount(name) >= (tonumber(count) or 1)
end

--- Ajoute un item. Empile si possible, sinon occupe de nouveaux slots.
--- Refuse si l'item est inconnu, ou si le poids dépasse la limite.
---@return boolean ok, string|nil err
function Player:addItem(name, count, meta)
    local it = CFG.getItem(name)
    if not it then return false, 'unknown' end
    count = math.floor(tonumber(count) or 1)
    if count <= 0 then return false, 'count' end

    local inv = self:invEnsure()
    -- Garde-fou poids (poids total après ajout).
    if weightOf(inv) + it.weight * count > ICFG.maxWeight then
        return false, 'weight'
    end

    if it.stackable and (meta == nil or next(meta) == nil) then
        -- Empilage sur une pile existante du même item (sans metadata).
        for _, e in ipairs(inv) do
            if e.name == name and (not e.meta or next(e.meta) == nil) then
                e.count = e.count + count
                self:invSync()
                return true
            end
        end
        local s = freeSlot(inv)
        if not s then return false, 'space' end
        inv[#inv + 1] = { slot = s, name = name, count = count, meta = {} }
    else
        -- Non empilable (ou avec metadata) : 1 slot par unité.
        for _ = 1, count do
            local s = freeSlot(inv)
            if not s then self:invSync(); return false, 'space' end
            inv[#inv + 1] = { slot = s, name = name, count = 1,
                              meta = type(meta) == 'table' and meta or {} }
        end
    end
    self:invSync()
    return true
end

--- Retire `count` exemplaires d'un item (réparti sur les piles, slot d'abord).
---@return boolean ok
function Player:removeItem(name, count, slot)
    count = math.floor(tonumber(count) or 1)
    if count <= 0 then return false end
    local inv = self:invEnsure()
    if self:invCount(name) < count then return false end

    -- Priorité au slot ciblé s'il correspond.
    if slot then
        local e = atSlot(inv, slot)
        if e and e.name == name then
            local take = math.min(e.count, count)
            e.count = e.count - take
            count = count - take
        end
    end
    -- Reste : on pioche sur les autres piles.
    for _, e in ipairs(inv) do
        if count <= 0 then break end
        if e.name == name and e.count > 0 then
            local take = math.min(e.count, count)
            e.count = e.count - take
            count = count - take
        end
    end
    self.inventory = compact(inv)
    self:invSync()
    return true
end

--- Déplace / fusionne un emplacement vers un autre (réorganisation NUI).
function Player:moveSlot(from, to)
    if from == to then return end
    local inv = self:invEnsure()
    local a = atSlot(inv, from)
    if not a then return end
    if to < 1 or to > ICFG.slots then return end
    local b = atSlot(inv, to)
    if not b then
        a.slot = to                       -- déplacement vers slot vide
    elseif a.name == b.name and CFG.isStackable(a.name)
        and next(a.meta) == nil and next(b.meta) == nil then
        b.count = b.count + a.count        -- fusion de piles identiques
        a.count = 0
        self.inventory = compact(inv)
    else
        a.slot, b.slot = b.slot, a.slot    -- échange
    end
    self:invSync()
end

--- Consomme l'item d'un slot et applique son effet (server-side).
---@return boolean ok
function Player:useSlot(slot)
    local e = atSlot(self:invEnsure(), slot)
    if not e then return false end
    local it = CFG.getItem(e.name)
    if not it or not it.usable then return false end

    local fx = it.effects or {}
    -- Effets de besoins (faim/soif/stress) via le module autoritaire Needs.
    if Noxa.Needs then
        if fx.hunger then Noxa.Needs.modify(self, 'hunger', fx.hunger) end
        if fx.thirst then Noxa.Needs.modify(self, 'thirst', fx.thirst) end
        if fx.stress then Noxa.Needs.modify(self, 'stress', fx.stress) end
    end
    -- Soin : appliqué client-side (santé = entité locale).
    if fx.health then
        TriggerClientEvent('noxa:inv:heal', self.source, fx.health)
    end
    -- Hooks d'action (ouverture téléphone, crochetage...).
    if fx.action then
        TriggerClientEvent('noxa:inv:action', self.source, fx.action, slot)
    end

    -- Le téléphone/outil ne se consomme pas ; les consommables oui.
    if it.category == 'consommable' then
        self:removeItem(e.name, 1, slot)
    else
        self:invSync()
    end
    TriggerClientEvent('noxa:notify', self.source,
        ('Vous utilisez : %s'):format(it.label), 'inform')
    -- Hook compat : les ressources tierces (couche ESX -> RegisterUsableItem)
    -- peuvent réagir à l'usage d'un item. Émis APRÈS l'effet noxa autoritaire.
    TriggerEvent('noxa:item:used', self.source, e.name, slot)
    return true
end

--- Charge utile envoyée à la NUI (rendu de la grille + hotbar).
function Player:invPayload()
    local inv = self:invEnsure()
    local slots = {}
    for _, e in ipairs(inv) do
        local it = CFG.getItem(e.name)
        if it then
            slots[#slots + 1] = {
                slot = e.slot, name = e.name, count = e.count,
                label = it.label, emoji = it.emoji, weight = it.weight,
                usable = it.usable == true, category = it.category,
            }
        end
    end
    return {
        slots     = slots,
        weight    = weightOf(inv),
        maxWeight = ICFG.maxWeight,
        maxSlots  = ICFG.slots,
        hotbar    = ICFG.hotbar,
    }
end

function Player:invSync()
    TriggerClientEvent('noxa:inv:set', self.source, self:invPayload())
end

-- ---------------------------------------------------------------------
--  Seed de départ + synchro au chargement du personnage
-- ---------------------------------------------------------------------
AddEventHandler('noxa:playerLoaded', function(src, ply)
    -- Dotation unique au premier chargement (flag en metadata, persisté).
    if not ply.metadata.starterKit then
        ply:addItem('phone', 1)
        ply:addItem('water', 2)
        ply:addItem('bread', 2)
        ply:addItem('bandage', 1)
        ply.metadata.starterKit = true
        ply:syncState()
    end
    ply:invSync()
end)

-- ---------------------------------------------------------------------
--  Events réseau (intentions client -> autorité serveur)
-- ---------------------------------------------------------------------

S.onNet('noxa:inv:request', function(src, ply)
    ply:invSync()
end)

S.onNet('noxa:inv:use', function(src, ply, slot)
    slot = tonumber(slot)
    if not slot then return S.flag(src, 'inv:use slot invalide') end
    ply:useSlot(slot)
end)

S.onNet('noxa:inv:move', function(src, ply, from, to)
    from, to = tonumber(from), tonumber(to)
    if not from or not to then return end
    ply:moveSlot(from, to)
end)

S.onNet('noxa:inv:drop', function(src, ply, slot, count)
    slot, count = tonumber(slot), tonumber(count)
    local e = atSlot(ply:invEnsure(), slot or -1)
    if not e then return end
    count = math.min(e.count, math.max(1, count or e.count))
    if ply:removeItem(e.name, count, slot) then
        local it = CFG.getItem(e.name)
        TriggerClientEvent('noxa:notify', src,
            ('Vous jetez %dx %s.'):format(count, it and it.label or e.name), 'inform')
    end
end)

S.onNet('noxa:inv:give', function(src, ply, targetId, slot, count)
    targetId, slot, count = tonumber(targetId), tonumber(slot), tonumber(count)
    local target = targetId and Noxa.Players.get(targetId)
    if not target then
        return TriggerClientEvent('noxa:notify', src, 'Aucun joueur à proximité.', 'error')
    end
    -- Vérification de proximité côté serveur (positions des peds réseau).
    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(targetId))
    if #(a - b) > (CFG.Inventory.dropRadius + 1.0) then
        return TriggerClientEvent('noxa:notify', src, 'Joueur trop éloigné.', 'error')
    end
    local e = atSlot(ply:invEnsure(), slot or -1)
    if not e then return end
    count = math.min(e.count, math.max(1, count or 1))
    -- Transaction : le destinataire doit pouvoir porter, sinon on annule.
    if not target:addItem(e.name, count, next(e.meta) ~= nil and e.meta or nil) then
        return TriggerClientEvent('noxa:notify', src,
            'Le destinataire ne peut pas porter cet objet.', 'error')
    end
    ply:removeItem(e.name, count, slot)
    local it = CFG.getItem(e.name)
    TriggerClientEvent('noxa:notify', src, ('Donné %dx %s.'):format(count, it.label), 'success')
    TriggerClientEvent('noxa:notify', targetId, ('Reçu %dx %s.'):format(count, it.label), 'success')
end)

-- ---------------------------------------------------------------------
--  Exports inter-modules (jobs, drogues, boutiques, récompenses...)
-- ---------------------------------------------------------------------
exports('AddItem',      function(src, name, count, meta)
    local p = Noxa.Players.get(src); return p and p:addItem(name, count, meta) or false
end)
exports('RemoveItem',   function(src, name, count)
    local p = Noxa.Players.get(src); return p and p:removeItem(name, count) or false
end)
exports('HasItem',      function(src, name, count)
    local p = Noxa.Players.get(src); return p and p:hasItem(name, count) or false
end)
exports('GetInventory', function(src)
    local p = Noxa.Players.get(src); return p and p:invPayload() or nil
end)
exports('GetItemCount', function(src, name)
    local p = Noxa.Players.get(src); return p and p:invCount(name) or 0
end)

return Inv
