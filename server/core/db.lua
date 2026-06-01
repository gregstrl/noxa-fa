-- =====================================================================
--  NOXA FA — Couche d'accès base de données (server-side)
--  Encapsule oxmysql. Aucune requête SQL ailleurs dans le code.
-- =====================================================================

Noxa = Noxa or {}
Noxa.DB = {}

local DB = Noxa.DB
local U  = Noxa.Utils

-- ---------------------------------------------------------------------
--  Comptes
-- ---------------------------------------------------------------------

--- Récupère ou crée le compte lié à une license Rockstar.
---@param license string
---@param name string pseudo actuel
---@return table|nil account
function DB.ensureAccount(license, name)
    if not license then return nil end
    local row = MySQL.single.await(
        'SELECT * FROM noxa_accounts WHERE license = ?', { license })
    if row then
        MySQL.update('UPDATE noxa_accounts SET last_name = ?, last_seen = NOW() WHERE id = ?',
            { name, row.id })
        return row
    end
    local id = MySQL.insert.await(
        'INSERT INTO noxa_accounts (license, last_name) VALUES (?, ?)', { license, name })
    return MySQL.single.await('SELECT * FROM noxa_accounts WHERE id = ?', { id })
end

-- ---------------------------------------------------------------------
--  Personnages
-- ---------------------------------------------------------------------

--- Liste les personnages non supprimés d'un compte.
---@param accountId integer
---@return table[] characters
function DB.getCharacters(accountId)
    return MySQL.query.await(
        'SELECT * FROM noxa_characters WHERE account_id = ? AND deleted = 0 ORDER BY slot ASC',
        { accountId }) or {}
end

--- Charge un personnage en garantissant qu'il appartient bien au compte.
--- Empêche tout joueur de charger le personnage d'un autre (server-side ownership).
---@param charId integer
---@param accountId integer
---@return table|nil
function DB.getOwnedCharacter(charId, accountId)
    return MySQL.single.await(
        'SELECT * FROM noxa_characters WHERE id = ? AND account_id = ? AND deleted = 0',
        { charId, accountId })
end

--- Crée un nouveau personnage. Retourne la ligne complète.
---@param accountId integer
---@param data table
---@return table|nil
function DB.createCharacter(accountId, data)
    local id = MySQL.insert.await([[
        INSERT INTO noxa_characters
            (account_id, slot, citizenid, firstname, lastname, dob, gender, nationality, cash, bank, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId, data.slot or 0, data.citizenid, data.firstname, data.lastname,
        data.dob, data.gender or 0, data.nationality or 'Inconnue',
        data.cash, data.bank, U.jsonEncode(data.metadata or {}),
    })
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM noxa_characters WHERE id = ?', { id })
end

--- Soft-delete d'un personnage (conserve l'historique).
function DB.deleteCharacter(charId, accountId)
    return MySQL.update.await(
        'UPDATE noxa_characters SET deleted = 1 WHERE id = ? AND account_id = ?',
        { charId, accountId })
end

--- Sauvegarde l'état complet d'un personnage chargé.
---@param char table données de la classe Player
function DB.saveCharacter(char)
    MySQL.update([[
        UPDATE noxa_characters SET
            job = ?, job_grade = ?, gang = ?, gang_grade = ?,
            cash = ?, bank = ?, position = ?, appearance = ?, metadata = ?, inventory = ?
        WHERE id = ?
    ]], {
        char.job, char.job_grade, char.gang, char.gang_grade,
        char.cash, char.bank,
        U.jsonEncode(char.position), U.jsonEncode(char.appearance),
        U.jsonEncode(char.metadata), U.jsonEncode(char.inventory),
        char.id,
    })
end

--- Vérifie l'unicité d'un citizenid avant attribution.
function DB.citizenIdExists(citizenid)
    local row = MySQL.scalar.await(
        'SELECT 1 FROM noxa_characters WHERE citizenid = ? LIMIT 1', { citizenid })
    return row ~= nil
end

-- ---------------------------------------------------------------------
--  Journalisation (transactions + logs)
-- ---------------------------------------------------------------------

function DB.logTransaction(citizenid, account, txType, amount, balance, reason)
    MySQL.insert(
        'INSERT INTO noxa_transactions (citizenid, account, type, amount, balance, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenid, account, txType, amount, balance, reason })
end

function DB.log(category, level, license, message, data)
    MySQL.insert(
        'INSERT INTO noxa_logs (category, level, license, message, data) VALUES (?, ?, ?, ?, ?)',
        { category, level, license, message, data and U.jsonEncode(data) or nil })
end

return DB
