-- =====================================================================
--  NOXA FA — Énumérations & référentiels partagés
--  Source unique de vérité pour jobs, comptes, grades de staff, etc.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Enums = {}

local E = Noxa.Enums

-- Types de comptes monétaires
E.Accounts = {
    CASH = 'cash',
    BANK = 'bank',
}

-- Types de transaction (pour le journal)
E.TxType = {
    ADD    = 'add',
    REMOVE = 'remove',
}

-- Grades de staff (ordre croissant de permission)
E.StaffRanks = {
    user       = 0,
    helper     = 1,
    mod        = 2,
    admin      = 3,
    superadmin = 4,
}

-- Référentiel des métiers. grades = échelle salariale/permissions.
-- Source autoritaire : le serveur recalcule toujours les droits depuis ce référentiel.
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
        grades = {
            [0] = { name = 'cadet',     label = 'Cadet',       salary = 750 },
            [1] = { name = 'officer',   label = 'Officier',    salary = 1000 },
            [2] = { name = 'sergeant',  label = 'Sergent',     salary = 1400 },
            [3] = { name = 'lieutenant',label = 'Lieutenant',  salary = 1900 },
            [4] = { name = 'chief',     label = 'Chef',        salary = 2600, isBoss = true },
        },
    },
    ambulance = {
        label = 'EMS',
        whitelisted = true,
        grades = {
            [0] = { name = 'intern',    label = 'Interne',     salary = 700 },
            [1] = { name = 'paramedic', label = 'Ambulancier', salary = 1100 },
            [2] = { name = 'doctor',    label = 'Médecin',     salary = 1700 },
            [3] = { name = 'chief',     label = 'Chef',        salary = 2500, isBoss = true },
        },
    },
    mechanic = {
        label = 'Mécanicien',
        grades = {
            [0] = { name = 'apprentice',label = 'Apprenti',    salary = 600 },
            [1] = { name = 'mechanic',  label = 'Mécanicien',  salary = 1000 },
            [2] = { name = 'boss',      label = 'Patron',      salary = 1800, isBoss = true },
        },
    },
}

-- Organisations criminelles (structure parallèle aux jobs)
E.Gangs = {
    none = { label = 'Aucun', grades = { [0] = { name = 'none', label = 'Aucun' } } },
}

return E
