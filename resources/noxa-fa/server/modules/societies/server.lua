-- =====================================================================
--  NOXA FA — Module Sociétés (server-side)
--  Caisses partagées (jobs publics/privés, gangs, État). Soldes en mémoire
--  pour des accès instantanés, persistés en base de façon différée (dirty).
--  • Aucune écriture SQL par opération : on marque "dirty" et un thread
--    sauvegarde par lot → réduction massive des appels base de données.
--  • Toute mutation est validée, bornée et journalisée (audit anti-abus).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Societies = {}

local Soc = Noxa.Societies
local U    = Noxa.Utils
local DB   = Noxa.DB
local E    = Noxa.Enums
local CFG  = Noxa.Config

-- Cache : [name] = { label, type, balance, dirty }
local cache = {}
local ready = false

-- ---------------------------------------------------------------------
--  Initialisation : seed depuis les enums + chargement des soldes
-- ---------------------------------------------------------------------
function Soc.init()
    -- 1. Garantit l'existence des sociétés déclarées dans les enums
    for name, def in pairs(E.Societies) do
        DB.ensureSociety(name, def.label, def.type, def.start)
    end
    -- 2. Charge l'état réel depuis la base (source de vérité au boot)
    for _, r in ipairs(DB.getSocieties()) do
        cache[r.name] = {
            label   = r.label,
            type    = r.type,
            balance = math.floor(tonumber(r.balance) or 0),
            dirty   = false,
        }
    end
    ready = true
    U.print('info', 'Sociétés chargées : %d caisse(s).', U.tableCount(cache))
end

-- ---------------------------------------------------------------------
--  Accès
-- ---------------------------------------------------------------------

function Soc.exists(name)
    return cache[name] ~= nil
end

---@return integer
function Soc.getBalance(name)
    local s = cache[name]
    return s and s.balance or 0
end

function Soc.canAfford(name, amount)
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    return Soc.getBalance(name) >= amount
end

function Soc.getAll()
    return cache
end

--- Crée une caisse société à chaud (ex: nouveau gang créé via le panel).
--- Idempotent : sans effet si la société existe déjà.
---@return boolean created
function Soc.ensure(name, label, sType, start)
    if cache[name] then return false end
    DB.ensureSociety(name, label, sType, start or 0)
    cache[name] = { label = label, type = sType, balance = math.floor(start or 0), dirty = false }
    return true
end

-- ---------------------------------------------------------------------
--  Mutations (validées + journalisées)
-- ---------------------------------------------------------------------

--- Crédite une caisse société.
---@param name string
---@param amount integer
---@param actor? string citizenid à l'origine
---@param reason? string
---@return boolean ok
function Soc.add(name, amount, actor, reason)
    local s = cache[name]
    if not s then return false end
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    if amount > CFG.Economy.maxTransaction then return false end
    s.balance = s.balance + amount
    s.dirty = true
    DB.logSocietyTx(name, E.TxType.ADD, amount, s.balance, actor, reason or 'unknown')
    return true
end

--- Débite une caisse société si les fonds sont suffisants.
---@return boolean ok
function Soc.remove(name, amount, actor, reason)
    local s = cache[name]
    if not s then return false end
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    if amount > s.balance then return false end  -- fonds insuffisants
    s.balance = s.balance - amount
    s.dirty = true
    DB.logSocietyTx(name, E.TxType.REMOVE, amount, s.balance, actor, reason or 'unknown')
    return true
end

-- ---------------------------------------------------------------------
--  Persistance différée (par lot)
-- ---------------------------------------------------------------------

local function flush()
    local n = 0
    for name, s in pairs(cache) do
        if s.dirty then
            DB.saveSocietyBalance(name, s.balance)
            s.dirty = false
            n = n + 1
        end
    end
    return n
end

Soc.flush = flush

-- ---------------------------------------------------------------------
--  Exports inter-ressources
-- ---------------------------------------------------------------------
exports('GetSocietyBalance',  Soc.getBalance)
exports('AddSocietyMoney',    Soc.add)
exports('RemoveSocietyMoney', Soc.remove)
exports('SocietyCanAfford',   Soc.canAfford)

-- ---------------------------------------------------------------------
--  Cycle de vie
-- ---------------------------------------------------------------------
CreateThread(function()
    Soc.init()
    while true do
        Wait(CFG.Societies.saveInterval)
        if ready then
            local n = flush()
            if n > 0 then U.debug('Sociétés : %d solde(s) persisté(s).', n) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    flush()
end)

return Soc
