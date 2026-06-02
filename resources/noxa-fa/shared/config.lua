-- =====================================================================
--  NOXA FA — Configuration partagée (client + serveur)
--  Modifiable sans toucher au code. Valeurs sensibles côté serveur uniquement.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Config = {}

local C = Noxa.Config

-- Identité du projet
C.ServerName       = 'Noxa FA'
C.Locale           = 'fr'
C.Debug            = GetConvarInt('noxa:debug', 0) == 1

-- Personnages
C.Characters = {
    maxSlots        = 4,        -- emplacements max par compte
    minNameLength   = 2,
    maxNameLength   = 24,
    startCash       = 500,
    startBank       = 5000,
}

-- Position de spawn par défaut (apparts/derniers points gérés ailleurs)
C.DefaultSpawn = { x = -1037.0, y = -2738.0, z = 20.16, heading = 328.0 }

-- Économie
C.Economy = {
    -- Bornes de sécurité : toute transaction hors de ces limites est refusée + loggée
    maxTransaction  = 50000000,    -- montant max d'une seule opération
    maxBalance      = 999999999,   -- solde maximum autorisé (détection duplication)
    logThreshold    = 100000,      -- au-delà : log systématique en base
}

-- Sécurité / anti-triche
C.Security = {
    -- Limitation de débit des events réseau (par joueur)
    rateLimit = {
        default     = { count = 20, window = 10000 },  -- 20 appels / 10s par event
    },
    -- Bannir automatiquement après N violations critiques détectées
    autobanThreshold = 5,
    kickMessage      = 'Noxa FA — Action refusée par la protection serveur.',
}

-- Sauvegarde
C.Save = {
    interval = 5 * 60 * 1000,   -- sauvegarde périodique auto : 5 minutes
}

-- Banque
C.Banking = {
    maxWithdraw  = 1000000,   -- retrait max par opération (cash depuis banque)
    maxDeposit   = 5000000,   -- dépôt max par opération
    maxTransfer  = 5000000,   -- virement max par opération
    transferFee  = 0.0,       -- frais de virement (0.0 = gratuit, 0.02 = 2%)
    invoiceMax   = 1000000,   -- montant max d'une facture
    invoiceTTL   = 7,         -- durée de vie d'une facture impayée (jours)
}

-- Emplois / paie
C.Jobs = {
    payInterval   = 30 * 60 * 1000, -- versement des salaires : 30 min
    payRequiresSociety = true,      -- ne verser que si la société a les fonds
    maxGrade      = 20,             -- borne anti-abus côté boss-actions
}

-- Sociétés
C.Societies = {
    saveInterval = 2 * 60 * 1000,   -- persistance des soldes société : 2 min
}

-- Besoins vitaux (faim / soif / stress) — décroissance autoritaire serveur
C.Needs = {
    decayInterval = 60 * 1000,   -- intervalle de décroissance : 60s
    hungerRate    = 2,           -- points de faim perdus par cycle
    thirstRate    = 3,           -- points de soif perdus par cycle (soif plus rapide)
    stressDecay   = 1,           -- le stress redescend naturellement par cycle
    damageOnEmpty = 5,           -- dégâts de santé/cycle quand faim OU soif = 0
    syncInterval  = 15 * 1000,   -- rafraîchissement HUD (santé/armure lues client)
}

-- Administration
C.Admin = {
    -- Durées de ban prédéfinies (en secondes ; 0 = permanent)
    banDurations = {
        ['1h']  = 3600,
        ['1d']  = 86400,
        ['3d']  = 259200,
        ['7d']  = 604800,
        ['30d'] = 2592000,
        ['perm'] = 0,
    },
    announcePrefix = '^1[ADMIN]^7 ',
}

return C
