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
    self.duty        = false   -- en service ? (non persisté : reset chaque session)

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
    -- Plafond d'espèces sur soi : l'excédent est viré automatiquement en banque.
    if account == E.Accounts.CASH then self:enforceCashCap() end
    return true
end

--- Applique le plafond d'espèces (anti-thésaurisation de liquide non tracé).
--- Au-delà du plafond DUR, l'excédent est ramené au seuil confort en banque.
function Player:enforceCashCap()
    local cap = CFG.Economy.CashCap
    if not cap or self.cash <= cap.hard then return end
    local excess = self.cash - cap.soft
    self.cash = self.cash - excess
    self.bank = self.bank + excess
    -- Journalise les DEUX mouvements (cohérence d'audit) + resync.
    self:onMoneyChanged(E.Accounts.CASH, E.TxType.REMOVE, excess, 'cashcap:auto')
    self:onMoneyChanged(E.Accounts.BANK, E.TxType.ADD, excess, 'cashcap:auto')
    TriggerClientEvent('noxa:notify', self.source,
        ('Excédent d\'espèces déposé en banque : %s'):format(U.money(excess)), 'inform')
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
    -- Flux économique temps réel vers la NUI (toast +/− contextualisé).
    -- Purement informatif : aucune valeur de confiance, le solde fait foi côté serveur.
    TriggerClientEvent('noxa:economy:tx', self.source, {
        account = account,
        type    = txType,
        amount  = amount,
        reason  = reason,
        balance = balance,
    })
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

--- Retourne la table du grade de job courant (label, perms, isBoss...).
function Player:getJobGradeData()
    return E.getJobGrade(self.job, self.job_grade)
end

--- Vérifie une permission de grade (recruit, fire, promote, bill, manageFunds).
---@param perm string
---@return boolean
function Player:hasJobPerm(perm)
    local g = self:getJobGradeData()
    return (g and g.perms and g.perms[perm]) == true
end

--- Le joueur est-il patron de sa société ?
function Player:isBoss()
    local g = self:getJobGradeData()
    return (g and g.isBoss) == true
end

--- Société (caisse) rattachée au job courant, ou nil.
function Player:getSociety()
    local job = E.Jobs[self.job]
    return job and job.society or nil
end

-- ---------------------------------------------------------------------
--  Service (duty) — état volatil, jamais persisté
-- ---------------------------------------------------------------------

--- Active/désactive le service. Les services publics ne touchent leur
--- salaire qu'en service (cf. module jobs).
---@param state boolean
function Player:setDuty(state)
    self.duty = state and true or false
    self:syncState()
    return self.duty
end

-- ---------------------------------------------------------------------
--  Organisation criminelle
-- ---------------------------------------------------------------------

--- Définit l'appartenance à un gang depuis le référentiel autoritaire.
---@return boolean ok
function Player:setGang(gangName, grade)
    local gang = E.Gangs[gangName]
    if not gang then return false end
    grade = tonumber(grade) or 0
    if not gang.grades[grade] then grade = next(gang.grades) end
    self.gang = gangName
    self.gang_grade = grade
    self:syncState()
    return true
end

function Player:getGangGradeData()
    return E.getGangGrade(self.gang, self.gang_grade)
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
    local jobGrade  = self:getJobGradeData()
    local gangGrade = self:getGangGradeData()
    local jobDef    = E.Jobs[self.job]
    local gangDef   = E.Gangs[self.gang]
    local data = {
        citizenid = self.citizenid,
        name      = self:getName(),
        job       = {
            name    = self.job,
            label   = jobDef and jobDef.label or self.job,
            grade   = self.job_grade,
            gradeLabel = jobGrade and jobGrade.label or '',
            isBoss  = jobGrade and jobGrade.isBoss or false,
            onDuty  = self.duty,
            society = jobDef and jobDef.society or nil,
        },
        gang      = {
            name    = self.gang,
            label   = gangDef and gangDef.label or self.gang,
            grade   = self.gang_grade,
            gradeLabel = gangGrade and gangGrade.label or '',
            isBoss  = gangGrade and gangGrade.isBoss or false,
        },
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
