-- =====================================================================
--  NOXA FA — Énumérations & référentiels partagés
--  Source unique de vérité pour jobs, comptes, grades de staff, sociétés.
--  Le serveur recalcule TOUJOURS les droits depuis ce référentiel : aucune
--  donnée envoyée par le client n'est jamais considérée comme autoritaire.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Enums = {}

local E = Noxa.Enums

-- Types de comptes monétaires personnels
E.Accounts = {
    CASH = 'cash',
    BANK = 'bank',
}

-- Types de transaction (journal personnel + société)
E.TxType = {
    ADD    = 'add',
    REMOVE = 'remove',
}

-- Catégories d'action bancaire (pour l'historique détaillé)
E.BankAction = {
    DEPOSIT       = 'deposit',
    WITHDRAW      = 'withdraw',
    TRANSFER_OUT  = 'transfer_out',
    TRANSFER_IN   = 'transfer_in',
    INVOICE_PAID  = 'invoice_paid',
    INVOICE_RECV  = 'invoice_received',
    SALARY        = 'salary',
    PURCHASE      = 'purchase',
}

-- Statut d'une facture
E.InvoiceStatus = {
    PENDING = 'pending',
    PAID    = 'paid',
    REFUSED = 'refused',
}

-- Types de société (compte partagé)
E.SocietyType = {
    PUBLIC  = 'public',  -- service public (police, ems)
    PRIVATE = 'private', -- entreprise privée (mécano, concession)
    GANG    = 'gang',    -- organisation criminelle
    STATE   = 'state',   -- caisse de l'État / trésor public
}

-- Grades de staff (ordre croissant de permission)
E.StaffRanks = {
    user       = 0,
    helper     = 1,
    mod        = 2,
    admin      = 3,
    superadmin = 4,
}

-- ---------------------------------------------------------------------
--  Sociétés (comptes partagés). Les jobs/gangs y sont rattachés via
--  le champ `society`. Soldes initiaux servis au premier démarrage SQL.
-- ---------------------------------------------------------------------
E.Societies = {
    state         = { label = 'Trésor Public', type = E.SocietyType.STATE,   start = 0 },
    lspd          = { label = 'LSPD',          type = E.SocietyType.PUBLIC,  start = 500000 },
    ems           = { label = 'EMS',           type = E.SocietyType.PUBLIC,  start = 500000 },
    mechanic      = { label = 'Mécano LS',     type = E.SocietyType.PRIVATE, start = 25000 },
    gang_ballas   = { label = 'Ballas',        type = E.SocietyType.GANG,    start = 0 },
    gang_families = { label = 'Families',      type = E.SocietyType.GANG,    start = 0 },
}

-- ---------------------------------------------------------------------
--  Référentiel des métiers.
--  grades : échelle [0..n] = { name, label, salary, isBoss?, perms? }
--  society : société (caisse) d'où sont versés salaires / factures.
--  onDutyOnly : salaire versé uniquement en service.
--  perms : table de flags booléens (recruit, fire, promote, bill, manageFunds).
-- ---------------------------------------------------------------------
E.Jobs = {
    unemployed = {
        label = 'Sans emploi',
        defaultGrade = 0,
        grades = {
            [0] = { name = 'freelance', label = 'Citoyen', salary = 50 },
        },
    },
    police = {
        label = 'LSPD',
        whitelisted = true,
        society = 'lspd',
        onDutyOnly = true,
        grades = {
            [0] = { name = 'cadet',      label = 'Cadet',      salary = 750 },
            [1] = { name = 'officer',    label = 'Officier',   salary = 1000 },
            [2] = { name = 'sergeant',   label = 'Sergent',    salary = 1400 },
            [3] = { name = 'lieutenant', label = 'Lieutenant', salary = 1900, perms = { recruit = true } },
            [4] = { name = 'chief',      label = 'Chef',       salary = 2600, isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, bill = true, manageFunds = true } },
        },
    },
    ambulance = {
        label = 'EMS',
        whitelisted = true,
        society = 'ems',
        onDutyOnly = true,
        grades = {
            [0] = { name = 'intern',    label = 'Interne',     salary = 700 },
            [1] = { name = 'paramedic', label = 'Ambulancier', salary = 1100 },
            [2] = { name = 'doctor',    label = 'Médecin',     salary = 1700, perms = { recruit = true, bill = true } },
            [3] = { name = 'chief',     label = 'Chef',        salary = 2500, isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, bill = true, manageFunds = true } },
        },
    },
    mechanic = {
        label = 'Mécanicien',
        society = 'mechanic',
        grades = {
            [0] = { name = 'apprentice', label = 'Apprenti',   salary = 600 },
            [1] = { name = 'mechanic',   label = 'Mécanicien', salary = 1000, perms = { bill = true } },
            [2] = { name = 'boss',       label = 'Patron',     salary = 1800, isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, bill = true, manageFunds = true } },
        },
    },
}

-- ---------------------------------------------------------------------
--  Organisations criminelles (structure parallèle aux jobs).
--  Pas de salaire automatique : les gangs vivent de leurs activités.
-- ---------------------------------------------------------------------
E.Gangs = {
    none = {
        label = 'Aucun',
        grades = { [0] = { name = 'none', label = 'Aucun' } },
    },
    ballas = {
        label = 'Ballas',
        society = 'gang_ballas',
        grades = {
            [0] = { name = 'recruit',  label = 'Recrue' },
            [1] = { name = 'member',   label = 'Membre' },
            [2] = { name = 'enforcer', label = 'Soldat', perms = { recruit = true } },
            [3] = { name = 'boss',     label = 'Boss', isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, manageFunds = true } },
        },
    },
    families = {
        label = 'Families',
        society = 'gang_families',
        grades = {
            [0] = { name = 'recruit',  label = 'Recrue' },
            [1] = { name = 'member',   label = 'Membre' },
            [2] = { name = 'enforcer', label = 'Soldat', perms = { recruit = true } },
            [3] = { name = 'boss',     label = 'Boss', isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, manageFunds = true } },
        },
    },
}

-- ---------------------------------------------------------------------
--  Helpers de résolution (lecture seule, client + serveur)
-- ---------------------------------------------------------------------

--- Retourne la table d'un grade de job, ou nil.
function E.getJobGrade(jobName, grade)
    local job = E.Jobs[jobName]
    if not job then return nil end
    return job.grades[grade]
end

--- Retourne la table d'un grade de gang, ou nil.
function E.getGangGrade(gangName, grade)
    local gang = E.Gangs[gangName]
    if not gang then return nil end
    return gang.grades[grade]
end

return E
