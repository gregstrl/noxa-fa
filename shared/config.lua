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

return C
