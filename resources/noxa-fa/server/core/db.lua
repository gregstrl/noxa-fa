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

-- ---------------------------------------------------------------------
--  Sociétés (comptes partagés)
-- ---------------------------------------------------------------------

--- Charge toutes les sociétés (appelé une seule fois au démarrage).
---@return table[] rows
function DB.getSocieties()
    return MySQL.query.await('SELECT * FROM noxa_societies') or {}
end

--- Crée une société si absente (seed depuis les enums au boot).
function DB.ensureSociety(name, label, sType, startBalance)
    return MySQL.insert.await([[
        INSERT INTO noxa_societies (name, label, type, balance) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), type = VALUES(type)
    ]], { name, label, sType, startBalance or 0 })
end

--- Persiste le solde d'une société (sauvegarde périodique).
function DB.saveSocietyBalance(name, balance)
    MySQL.update('UPDATE noxa_societies SET balance = ? WHERE name = ?', { balance, name })
end

function DB.logSocietyTx(society, txType, amount, balance, actor, reason)
    MySQL.insert([[
        INSERT INTO noxa_society_transactions (society, type, amount, balance, actor, reason)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { society, txType, amount, balance, actor, reason })
end

-- ---------------------------------------------------------------------
--  Whitelist d'emploi
-- ---------------------------------------------------------------------

--- Renvoie le grade max autorisé pour un citoyen sur un job, ou nil.
---@return integer|nil
function DB.getJobWhitelist(citizenid, job)
    return MySQL.scalar.await(
        'SELECT max_grade FROM noxa_job_whitelist WHERE citizenid = ? AND job = ?',
        { citizenid, job })
end

--- Accorde / met à jour une whitelist (boss-action ou admin).
function DB.setJobWhitelist(citizenid, job, maxGrade, grantedBy)
    MySQL.insert([[
        INSERT INTO noxa_job_whitelist (citizenid, job, max_grade, granted_by) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE max_grade = VALUES(max_grade), granted_by = VALUES(granted_by)
    ]], { citizenid, job, maxGrade, grantedBy })
end

--- Révoque la whitelist d'un citoyen sur un job (licenciement).
function DB.removeJobWhitelist(citizenid, job)
    MySQL.update('DELETE FROM noxa_job_whitelist WHERE citizenid = ? AND job = ?', { citizenid, job })
end

-- ---------------------------------------------------------------------
--  Factures
-- ---------------------------------------------------------------------

function DB.createInvoice(data)
    return MySQL.insert.await([[
        INSERT INTO noxa_invoices (emitter_cid, emitter_name, society, target_cid, amount, label)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { data.emitter_cid, data.emitter_name, data.society, data.target_cid, data.amount, data.label })
end

function DB.getPendingInvoices(citizenid)
    return MySQL.query.await(
        'SELECT * FROM noxa_invoices WHERE target_cid = ? AND status = ? ORDER BY created_at DESC',
        { citizenid, 'pending' }) or {}
end

--- Charge une facture en garantissant qu'elle appartient bien au débiteur.
function DB.getOwnedInvoice(invoiceId, targetCid)
    return MySQL.single.await(
        'SELECT * FROM noxa_invoices WHERE id = ? AND target_cid = ? AND status = ?',
        { invoiceId, targetCid, 'pending' })
end

function DB.setInvoiceStatus(invoiceId, status)
    MySQL.update(
        'UPDATE noxa_invoices SET status = ?, paid_at = NOW() WHERE id = ?',
        { status, invoiceId })
end

-- ---------------------------------------------------------------------
--  Bannissements (audit ; l'état actif vit dans noxa_accounts)
-- ---------------------------------------------------------------------

function DB.insertBan(data)
    MySQL.insert([[
        INSERT INTO noxa_bans (account_id, license, reason, banned_by, expire)
        VALUES (?, ?, ?, ?, ?)
    ]], { data.account_id, data.license, data.reason, data.banned_by, data.expire })
end

function DB.deactivateBans(license)
    MySQL.update('UPDATE noxa_bans SET active = 0 WHERE license = ?', { license })
end

--- Applique le ban sur le compte (état autoritaire vérifié à la connexion).
function DB.setAccountBan(accountId, reason, expire)
    MySQL.update(
        'UPDATE noxa_accounts SET banned = 1, ban_reason = ?, ban_expire = ? WHERE id = ?',
        { reason, expire, accountId })
end

--- Récupère un compte par license (utilisé par les actions admin offline).
function DB.getAccountByLicense(license)
    return MySQL.single.await('SELECT * FROM noxa_accounts WHERE license = ?', { license })
end

return DB
