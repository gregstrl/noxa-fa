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

--- Réclame atomiquement une facture encore en attente (anti double-paiement).
--- Passe son statut à 'paid' UNIQUEMENT si elle est toujours 'pending'.
--- Garantit qu'un seul paiement aboutit même en cas d'events concurrents.
---@return boolean claimed
function DB.claimInvoice(invoiceId, targetCid)
    local affected = MySQL.update.await([[
        UPDATE noxa_invoices SET status = 'paid', paid_at = NOW()
        WHERE id = ? AND target_cid = ? AND status = 'pending'
    ]], { invoiceId, targetCid })
    return (affected or 0) > 0
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

-- ---------------------------------------------------------------------
--  Véhicules — carburant (station essence)
-- ---------------------------------------------------------------------

--- Ajoute du carburant à un véhicule immatriculé (borné à 100). Sans effet
--- si la plaque n'existe pas (véhicule libre / spawn non persisté).
function DB.refuelVehicle(plate, units)
    MySQL.update('UPDATE noxa_vehicles SET fuel = LEAST(100, fuel + ?) WHERE plate = ?',
        { units, plate })
end

--- Nombre de véhicules possédés par un citoyen (cycle d'entretien).
---@return integer
function DB.countOwnedVehicles(cid)
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM noxa_vehicles WHERE owner_cid = ?', { cid })
    return tonumber(n) or 0
end

-- ---------------------------------------------------------------------
--  Immobilier (maisons / appartements)
-- ---------------------------------------------------------------------

--- Crée un bien s'il n'existe pas encore (seed depuis la config au boot).
function DB.ensureProperty(p)
    MySQL.insert.await([[
        INSERT INTO noxa_properties (name, label, tier, price, coords_door, coords_inside)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), tier = VALUES(tier),
            price = VALUES(price), coords_door = VALUES(coords_door),
            coords_inside = VALUES(coords_inside)
    ]], { p.name, p.label, p.tier, p.price, p.door, p.inside })
end

--- Charge tous les biens (appelé une fois au démarrage).
function DB.getProperties()
    return MySQL.query.await('SELECT * FROM noxa_properties') or {}
end

--- Paliers des biens possédés par un citoyen (cycle d'entretien : loyers).
---@return table[] lignes { tier }
function DB.getOwnedPropertyTiers(cid)
    return MySQL.query.await('SELECT tier FROM noxa_properties WHERE owner_cid = ?', { cid }) or {}
end

--- Achat atomique : n'attribue le bien que s'il est encore libre.
---@return boolean ok
function DB.buyProperty(propId, ownerCid)
    local affected = MySQL.update.await(
        'UPDATE noxa_properties SET owner_cid = ?, locked = 1 WHERE id = ? AND owner_cid IS NULL',
        { ownerCid, propId })
    return (affected or 0) > 0
end

--- Libère un bien (rollback d'achat / revente).
function DB.releaseProperty(propId)
    MySQL.update('UPDATE noxa_properties SET owner_cid = NULL, locked = 0 WHERE id = ?', { propId })
end

--- Met à jour l'état de verrouillage d'un bien.
function DB.setPropertyLocked(propId, locked)
    MySQL.update('UPDATE noxa_properties SET locked = ? WHERE id = ?',
        { locked and 1 or 0, propId })
end

--- Persiste le mobilier (JSON) d'un bien.
function DB.savePropertyFurniture(propId, furnitureJson)
    MySQL.update('UPDATE noxa_properties SET furniture = ? WHERE id = ?',
        { furnitureJson, propId })
end

-- ---------------------------------------------------------------------
--  Téléphone (numéro, contacts, SMS, réseau social)
-- ---------------------------------------------------------------------

--- Attribue/persiste le numéro de téléphone d'un personnage.
function DB.setCharacterPhone(charId, phone)
    MySQL.update('UPDATE noxa_characters SET phone = ? WHERE id = ?', { phone, charId })
end

function DB.getContacts(ownerCid)
    return MySQL.query.await(
        'SELECT id, name, number FROM noxa_phone_contacts WHERE owner_cid = ? ORDER BY name ASC',
        { ownerCid }) or {}
end

function DB.addContact(ownerCid, name, number)
    return MySQL.insert.await(
        'INSERT INTO noxa_phone_contacts (owner_cid, name, number) VALUES (?, ?, ?)',
        { ownerCid, name, number })
end

function DB.deleteContact(id, ownerCid)
    return MySQL.update.await(
        'DELETE FROM noxa_phone_contacts WHERE id = ? AND owner_cid = ?', { id, ownerCid })
end

--- Enregistre un SMS (numéros normalisés émetteur/destinataire).
function DB.addMessage(fromNum, toNum, body)
    return MySQL.insert.await(
        'INSERT INTO noxa_phone_messages (from_num, to_num, body) VALUES (?, ?, ?)',
        { fromNum, toNum, body })
end

--- Fil de discussion entre deux numéros (ordre chronologique).
function DB.getThread(a, b, limit)
    return MySQL.query.await([[
        SELECT from_num, to_num, body, created_at FROM noxa_phone_messages
        WHERE (from_num = ? AND to_num = ?) OR (from_num = ? AND to_num = ?)
        ORDER BY id ASC LIMIT ?
    ]], { a, b, b, a, limit or 200 }) or {}
end

--- Derniers correspondants (liste des conversations) d'un numéro.
function DB.getConversations(myNum)
    return MySQL.query.await([[
        SELECT peer, MAX(created_at) AS last_at FROM (
            SELECT to_num AS peer, created_at FROM noxa_phone_messages WHERE from_num = ?
            UNION ALL
            SELECT from_num AS peer, created_at FROM noxa_phone_messages WHERE to_num = ?
        ) t GROUP BY peer ORDER BY last_at DESC LIMIT 50
    ]], { myNum, myNum }) or {}
end

function DB.addTweet(cid, author, body)
    return MySQL.insert.await(
        'INSERT INTO noxa_phone_tweets (author_cid, author, body) VALUES (?, ?, ?)',
        { cid, author, body })
end

function DB.getTweets(limit)
    return MySQL.query.await(
        'SELECT author, body, created_at FROM noxa_phone_tweets ORDER BY id DESC LIMIT ?',
        { limit or 30 }) or {}
end

return DB
