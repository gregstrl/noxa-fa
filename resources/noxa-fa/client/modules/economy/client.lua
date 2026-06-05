-- =====================================================================
--  NOXA FA — Module Économie (client-side)
--  Reçoit le flux monétaire serveur (noxa:economy:tx) et l'affiche sous
--  forme de toasts économiques (+/−) près du HUD argent. Purement informatif :
--  le serveur reste seul juge des soldes (statebag répliqué).
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

-- Traduction d'une « raison » technique en libellé lisible + catégorie.
-- (préfixe -> { label, cat }) ; cat sert au pictogramme côté NUI.
local LABELS = {
    ['salary']     = { label = 'Salaire',            cat = 'income'   },
    ['transfer:in']= { label = 'Virement reçu',      cat = 'income'   },
    ['transfer:out']={ label = 'Virement émis',      cat = 'transfer' },
    ['bank:deposit']={ label = 'Dépôt',              cat = 'transfer' },
    ['bank:withdraw']={label = 'Retrait',            cat = 'transfer' },
    ['invoice:received'] = { label = 'Facture payée par un tiers', cat = 'income' },
    ['invoice:pay']= { label = 'Facture réglée',     cat = 'expense'  },
    ['shop']       = { label = 'Achat boutique',     cat = 'expense'  },
    ['fuel']       = { label = 'Carburant',          cat = 'expense'  },
    ['vehicle']    = { label = 'Concession (véhicule)', cat = 'transfer' },
    ['fine']       = { label = 'Amende',             cat = 'fine'     },
    ['upkeep']     = { label = 'Charges (loyer/entretien)', cat = 'expense' },
    ['cashcap:auto'] = { label = 'Dépôt automatique', cat = 'transfer' },
    ['society:deposit']  = { label = 'Dépôt société',  cat = 'transfer' },
    ['society:withdraw'] = { label = 'Retrait société', cat = 'transfer' },
}

--- Résout le libellé d'une raison (gère les préfixes « famille:détail »).
local function resolve(reason)
    reason = tostring(reason or '')
    if LABELS[reason] then return LABELS[reason] end
    local prefix = reason:match('^([^:]+)')
    if prefix and LABELS[prefix] then return LABELS[prefix] end
    -- Cas particulier : salary:police, fine:exces_vitesse, shop:water...
    if LABELS[reason:gsub(':.*$', '')] then return LABELS[reason:gsub(':.*$', '')] end
    return { label = 'Mouvement', cat = 'neutral' }
end

RegisterNetEvent('noxa:economy:tx', function(tx)
    if type(tx) ~= 'table' then return end
    local amount = tonumber(tx.amount) or 0
    if amount <= 0 then return end

    -- Filtre le bruit : on n'affiche pas les micro-mouvements internes
    -- (ex : dépôt auto en deux écritures sous le seuil d'intérêt).
    if amount < 10 then return end

    local info = resolve(tx.reason)
    NUI.send('economy', 'tx', {
        sign    = (tx.type == 'add') and '+' or '-',
        amount  = amount,
        account = tx.account,           -- cash | bank
        label   = info.label,
        cat     = info.cat,             -- income|expense|transfer|fine|neutral
    })
end)
