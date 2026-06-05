-- =====================================================================
--  NOXA FA — Module Banque (server-side)
--  • Dépôt / retrait / virement entre comptes, tout validé et borné serveur.
--  • Facturation : un professionnel (perm `bill`) émet une facture vers un
--    citoyen ; le paiement crédite la caisse de la société émettrice.
--  • Le client ne fait QU'émettre des intentions : aucun montant n'est jamais
--    accepté tel quel, tout transite par la classe Player + bornes config.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Banking = {}

local Bank = Noxa.Banking
local U    = Noxa.Utils
local E    = Noxa.Enums
local DB   = Noxa.DB
local S    = Noxa.Security
local CFG  = Noxa.Config
local Soc  = Noxa.Societies

-- ---------------------------------------------------------------------
--  Dépôt / retrait (espèces <-> banque)
-- ---------------------------------------------------------------------

S.onNet('noxa:bank:deposit', function(src, ply, amount)
    if not S.cooldown(src, 'bank:deposit') then return end
    amount = U.sanitizeAmount(amount)
    if not amount or amount > CFG.Banking.maxDeposit then
        return TriggerClientEvent('noxa:notify', src, 'Montant invalide.', 'error')
    end
    if not ply:removeMoney(E.Accounts.CASH, amount, 'bank:deposit') then
        return TriggerClientEvent('noxa:notify', src, 'Espèces insuffisantes.', 'error')
    end
    ply:addMoney(E.Accounts.BANK, amount, 'bank:deposit')
    TriggerClientEvent('noxa:notify', src, ('Déposé : %s'):format(U.money(amount)), 'success')
end)

S.onNet('noxa:bank:withdraw', function(src, ply, amount)
    if not S.cooldown(src, 'bank:withdraw') then return end
    amount = U.sanitizeAmount(amount)
    if not amount or amount > CFG.Banking.maxWithdraw then
        return TriggerClientEvent('noxa:notify', src, 'Montant invalide.', 'error')
    end
    if not ply:removeMoney(E.Accounts.BANK, amount, 'bank:withdraw') then
        return TriggerClientEvent('noxa:notify', src, 'Solde insuffisant.', 'error')
    end
    ply:addMoney(E.Accounts.CASH, amount, 'bank:withdraw')
    TriggerClientEvent('noxa:notify', src, ('Retiré : %s'):format(U.money(amount)), 'success')
end)

-- ---------------------------------------------------------------------
--  Virement bancaire (banque -> banque) par citizenid
-- ---------------------------------------------------------------------

S.onNet('noxa:bank:transfer', function(src, ply, targetCid, amount)
    if not S.cooldown(src, 'bank:transfer') then return end
    amount = U.sanitizeAmount(amount)
    if not amount or amount > CFG.Banking.maxTransfer then
        return TriggerClientEvent('noxa:notify', src, 'Montant invalide.', 'error')
    end
    if type(targetCid) ~= 'string' or targetCid == ply.citizenid then
        return TriggerClientEvent('noxa:notify', src, 'Destinataire invalide.', 'error')
    end
    local target = Noxa.Players.getByCitizenId(targetCid)
    if not target then
        return TriggerClientEvent('noxa:notify', src, 'Destinataire introuvable / hors ligne.', 'error')
    end

    -- Frais éventuels (config). Le débiteur paie montant + frais.
    local fee = math.floor(amount * (CFG.Banking.transferFee or 0))
    if not ply:removeMoney(E.Accounts.BANK, amount + fee, 'transfer:out') then
        return TriggerClientEvent('noxa:notify', src, 'Solde insuffisant.', 'error')
    end
    target:addMoney(E.Accounts.BANK, amount, 'transfer:in')
    if fee > 0 then Soc.add('state', fee, ply.citizenid, 'transfer_fee') end

    TriggerClientEvent('noxa:notify', src,
        ('Virement de %s à %s.'):format(U.money(amount), target:getName()), 'success')
    TriggerClientEvent('noxa:notify', target.source,
        ('Vous avez reçu %s de %s.'):format(U.money(amount), ply:getName()), 'success')
end)

-- ---------------------------------------------------------------------
--  Facturation
-- ---------------------------------------------------------------------

-- Émission d'une facture (réservée aux métiers disposant de la perm `bill`).
S.onNet('noxa:bank:invoice:create', function(src, ply, targetId, amount, label)
    if not S.cooldown(src, 'bank:invoice:create') then return end
    if not ply:hasJobPerm('bill') then
        return S.flag(src, 'invoice:create sans permission')
    end
    amount = U.sanitizeAmount(amount)
    if not amount or amount > CFG.Banking.invoiceMax then
        return TriggerClientEvent('noxa:notify', src, 'Montant de facture invalide.', 'error')
    end
    local target = Noxa.Players.get(tonumber(targetId))
    if not target or target.citizenid == ply.citizenid then
        return TriggerClientEvent('noxa:notify', src, 'Cible invalide.', 'error')
    end

    label = (type(label) == 'string' and label ~= '') and label:sub(1, 128) or 'Facture'
    DB.createInvoice({
        emitter_cid  = ply.citizenid,
        emitter_name = ply:getName(),
        society      = ply:getSociety(),
        target_cid   = target.citizenid,
        amount       = amount,
        label        = label,
    })
    DB.log('invoice', 'info', ply.license,
        ('Facture %s -> %s : %s (%s)'):format(ply.citizenid, target.citizenid, U.money(amount), label))
    TriggerClientEvent('noxa:notify', src, ('Facture émise : %s'):format(U.money(amount)), 'success')
    TriggerClientEvent('noxa:notify', target.source,
        ('Nouvelle facture de %s : %s'):format(ply:getName(), U.money(amount)), 'inform')
end)

-- Liste des factures en attente du joueur.
S.onNet('noxa:bank:invoice:list', function(src, ply)
    local rows = DB.getPendingInvoices(ply.citizenid)
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = {
            id       = r.id,
            from     = r.emitter_name,
            amount   = tonumber(r.amount),
            label    = r.label,
            date     = tostring(r.created_at),
        }
    end
    TriggerClientEvent('noxa:bank:invoice:setList', src, list)
end)

-- Paiement d'une facture (depuis la banque ; crédite la société émettrice).
S.onNet('noxa:bank:invoice:pay', function(src, ply, invoiceId)
    if not S.cooldown(src, 'bank:invoice:pay') then return end
    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end
    -- Ownership : la facture doit cibler CE joueur et être en attente
    local inv = DB.getOwnedInvoice(invoiceId, ply.citizenid)
    if not inv then return S.flag(src, 'invoice:pay non possédée') end

    local amount = U.sanitizeAmount(inv.amount)
    if not amount then return end

    -- Réservation atomique AVANT le débit : seule la première requête concurrente
    -- réussit la réclamation, ce qui élimine tout double-paiement (race condition).
    if not DB.claimInvoice(invoiceId, ply.citizenid) then
        return TriggerClientEvent('noxa:notify', src, 'Facture déjà traitée.', 'inform')
    end
    if not ply:removeMoney(E.Accounts.BANK, amount, 'invoice:pay') then
        -- Débit refusé : on rouvre la facture pour rester cohérent.
        DB.setInvoiceStatus(invoiceId, E.InvoiceStatus.PENDING)
        return TriggerClientEvent('noxa:notify', src, 'Solde insuffisant pour payer.', 'error')
    end

    -- Crédit du bénéficiaire : société si renseignée, sinon l'émetteur (si en ligne)
    if inv.society and Soc.exists(inv.society) then
        Soc.add(inv.society, amount, ply.citizenid, 'invoice:' .. invoiceId)
    else
        local emitter = Noxa.Players.getByCitizenId(inv.emitter_cid)
        if emitter then emitter:addMoney(E.Accounts.BANK, amount, 'invoice:received') end
    end

    -- Statut déjà passé à 'paid' par DB.claimInvoice (réservation atomique).
    TriggerClientEvent('noxa:notify', src, ('Facture payée : %s'):format(U.money(amount)), 'success')
end)

-- Refus d'une facture.
S.onNet('noxa:bank:invoice:refuse', function(src, ply, invoiceId)
    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end
    local inv = DB.getOwnedInvoice(invoiceId, ply.citizenid)
    if not inv then return S.flag(src, 'invoice:refuse non possédée') end
    DB.setInvoiceStatus(invoiceId, E.InvoiceStatus.REFUSED)
    TriggerClientEvent('noxa:notify', src, 'Facture refusée.', 'inform')
end)

return Bank
