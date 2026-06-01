-- =====================================================================
--  NOXA FA — Classe Player (objet personnage chargé en mémoire)
--  Toute la logique critique (argent, job, métadonnées) vit ici, server-side.
--  Le client ne reçoit que des copies en lecture seule via syncState.
-- =====================================================================

Noxa = Noxa or {}

-- Capture la fonction native FiveM Player() AVANT de déclarer notre classe
-- du même nom (sinon le local masquerait la native et casserait les statebags).
local NativePlayer = Player

local U   = Noxa.Utils
local DB  = Noxa.DB
local E   = Noxa.Enums
local CFG = Noxa.Config

---@class Player
local Player = {}
Player.__index = Player

--- Construit un objet Player à partir d'une ligne SQL et du source réseau.
---@param src integer
---@param row table ligne noxa_characters
---@param account table ligne noxa_accounts
---@return Player
function Player.new(src, row, account)
    local self = setmetatable({}, Player)
    self.source      = src
    self.accountId   = account.id
    self.license     = account.license
    self.staffRank   = account.staff_rank

    self.id          = row.id
    self.citizenid   = row.citizenid
    self.firstname   = row.firstname
    self.lastname    = row.lastname
    self.gender      = row.gender
    self.dob         = row.dob
    self.nationality = row.nationality
    self.phone       = row.phone

    self.job         = row.job
    self.job_grade   = row.job_grade
    self.gang        = row.gang
    self.gang_grade  = row.gang_grade

    self.cash        = math.floor(row.cash or 0)
    self.bank        = math.floor(row.bank or 0)

    self.position    = U.jsonDecode(row.position, CFG.DefaultSpawn)
    self.appearance  = U.jsonDecode(row.appearance, {})
    self.metadata    = U.jsonDecode(row.metadata, {})
    self.inventory   = U.jsonDecode(row.inventory, {})

    self:initMetadata()
    return self
end

--- Initialise les métadonnées par défaut (idempotent).
function Player:initMetadata()
    local m = self.metadata
    if m.hunger == nil then m.hunger = 100 end
    if m.thirst == nil then m.thirst = 100 end
    if m.health == nil then m.health = 200 end
    if m.armor  == nil then m.armor  = 0 end
    if m.stress == nil then m.stress = 0 end
    if m.xp     == nil then m.xp     = {} end   -- progression par compétence
    if m.licenses == nil then m.licenses = {} end -- permis (driving, weapon...)
end

-- ---------------------------------------------------------------------
--  Nom / identité
-- ---------------------------------------------------------------------

function Player:getName()
    return ('%s %s'):format(self.firstname, self.lastname)
end

-- ---------------------------------------------------------------------
--  Économie — UNIQUE point d'entrée autoritaire pour l'argent
-- ---------------------------------------------------------------------

--- Retourne le solde d'un compte (cash | bank).
function Player:getMoney(account)
    if account == E.Accounts.CASH then return self.cash end
    if account == E.Accounts.BANK then return self.bank end
    return 0
end

--- Ajoute de l'argent. Validé, borné, journalisé.
---@return boolean ok
function Player:addMoney(account, amount, reason)
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    if amount > CFG.Economy.maxTransaction then
        Noxa.Security.flag(self.source, ('addMoney hors borne: %s'):format(amount))
        return false
    end
    if account == E.Accounts.CASH then
        self.cash = self.cash + amount
    elseif account == E.Accounts.BANK then
        self.bank = self.bank + amount
    else
        return false
    end
    self:onMoneyChanged(account, E.TxType.ADD, amount, reason)
    return true
end

--- Retire de l'argent si le solde est suffisant. Validé, journalisé.
---@return boolean ok
function Player:removeMoney(account, amount, reason)
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    local current = self:getMoney(account)
    if amount > current then return false end  -- fonds insuffisants
    if account == E.Accounts.CASH then
        self.cash = self.cash - amount
    elseif account == E.Accounts.BANK then
        self.bank = self.bank - amount
    else
        return false
    end
    self:onMoneyChanged(account, E.TxType.REMOVE, amount, reason)
    return true
end

--- Hook interne : journalise + détecte les anomalies + synchronise le client.
function Player:onMoneyChanged(account, txType, amount, reason)
    local balance = self:getMoney(account)
    reason = reason or 'unknown'

    -- Détection de duplication : solde anormalement élevé
    if balance > CFG.Economy.maxBalance then
        Noxa.Security.flag(self.source,
            ('solde %s anormal: %s'):format(account, balance))
    end
    -- Journalisation (toujours pour les gros montants)
    if amount >= CFG.Economy.logThreshold then
        DB.logTransaction(self.citizenid, account, txType, amount, balance, reason)
    end
    self:syncState()
end

-- ---------------------------------------------------------------------
--  Emploi
-- ---------------------------------------------------------------------

--- Définit le job du joueur depuis le référentiel autoritaire.
---@return boolean ok
function Player:setJob(jobName, grade)
    local job = E.Jobs[jobName]
    if not job then return false end
    grade = tonumber(grade) or job.defaultGrade or 0
    if not job.grades[grade] then grade = next(job.grades) end
    self.job = jobName
    self.job_grade = grade
    self:syncState()
    return true
end

function Player:getJobSalary()
    local job = E.Jobs[self.job]
    if not job then return 0 end
    local g = job.grades[self.job_grade]
    return g and g.salary or 0
end

-- ---------------------------------------------------------------------
--  Métadonnées
-- ---------------------------------------------------------------------

function Player:getMeta(key)
    return self.metadata[key]
end

function Player:setMeta(key, value)
    self.metadata[key] = value
    self:syncState()
end

-- ---------------------------------------------------------------------
--  Synchronisation client (lecture seule via statebag joueur)
-- ---------------------------------------------------------------------

--- Pousse un instantané non sensible vers le client (UI, HUD) via statebag répliqué.
function Player:syncState()
    local data = {
        citizenid = self.citizenid,
        name      = self:getName(),
        job       = { name = self.job, grade = self.job_grade },
        gang      = { name = self.gang, grade = self.gang_grade },
        cash      = self.cash,
        bank      = self.bank,
        metadata  = self.metadata,
    }
    NativePlayer(self.source).state:set('noxa:player', data, true)
end

-- ---------------------------------------------------------------------
--  Persistance
-- ---------------------------------------------------------------------

function Player:save()
    DB.saveCharacter(self)
end

Noxa.PlayerClass = Player
return Player
