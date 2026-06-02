-- =====================================================================
--  NOXA FA — ÉCONOMIE : Anti-inflation (puits monétaires & taxes)
--  ---------------------------------------------------------------------
--  Une économie RP gonfle si l'argent ENTRE plus vite qu'il ne SORT. Ce
--  fichier centralise tous les PUITS (sinks) qui retirent de la masse
--  monétaire : taxes, loyers, entretien, amendes, plafond d'espèces.
--  Les recettes fiscales sont versées au Trésor Public (société `state`),
--  qui pourra financer salaires publics / projets serveur (boucle fermée).
-- =====================================================================

Noxa = Noxa or {}
local C = Noxa.Config
C.Economy = C.Economy or {}
local Eco = C.Economy

-- Caisse réceptrice de toutes les recettes fiscales (cf. enums E.Societies).
Eco.treasury = 'state'

-- ---------------------------------------------------------------------
--  Taxes sur transactions (mission : 3–5 %).
--  • sales    : TVA prélevée sur tout achat de consommable (épicerie, plein).
--  • transfer : taxe sur les virements joueur→joueur (limite blanchiment /
--               transferts massifs ; câblée sur C.Banking.transferFee).
--  • luxury   : surtaxe sur les gros achats (concession) — gros retrait ciblé.
-- ---------------------------------------------------------------------
Eco.Tax = {
    sales    = 0.05,   -- 5 % : haut de la fourchette, consommable = sink fréquent.
    transfer = 0.03,   -- 3 % : friction légère, n'étrangle pas l'entraide RP.
    luxury   = 0.07,   -- 7 % : véhicules de concession, retrait monétaire majeur.
}

-- Branche la taxe de virement bancaire sur la doctrine fiscale (source unique).
-- banking/server.lua lit déjà C.Banking.transferFee et crédite `state`.
C.Banking.transferFee = Eco.Tax.transfer

-- ---------------------------------------------------------------------
--  Plafond d'espèces sur soi (mission : limiter le cash).
--  Au-delà du plafond DUR, l'excédent est automatiquement viré en banque
--  (argent tracé, non braquable). But : forcer l'usage bancaire + réduire
--  l'intérêt des grosses liasses (futurs braquages = butin plafonné).
-- ---------------------------------------------------------------------
Eco.CashCap = {
    soft = 50000,    -- seuil d'alerte : niveau « confortable » sans pénalité.
    hard = 100000,   -- plafond dur : tout dépassement est viré vers la banque.
}

-- ---------------------------------------------------------------------
--  Cycle d'entretien (loyers + maintenance véhicules).
--  Un « cycle fiscal » = 60 min réelles. Débité aux propriétaires EN LIGNE.
-- ---------------------------------------------------------------------
Eco.Upkeep = {
    interval = 60 * 60 * 1000,   -- 1 h réelle = 1 cycle fiscal.

    -- Loyer par palier de bien : ≈ 0,5 % de la valeur du bien / cycle.
    -- Justif : possession = coût récurrent ; décourage l'accumulation passive
    -- de biens et crée un puits proportionnel à la richesse immobilière.
    rent = {
        studio    = 250,    -- 0,5 % de 50 000 $
        apartment = 750,    -- 0,5 % de 150 000 $
        house     = 2000,   -- 0,5 % de 400 000 $
        villa     = 6000,   -- 0,5 % de 1 200 000 $
    },

    -- Entretien : coût fixe par véhicule possédé / cycle (assurance + garage).
    -- Justif : posséder 10 voitures doit coûter ; sink anti-thésaurisation.
    maintenancePerVehicle = 150,
}

-- ---------------------------------------------------------------------
--  Amendes (police). Barème borné serveur, versé au Trésor Public.
--  Émises via l'export Economy:Fine (cf. server/modules/economy). Sink
--  punitif + levier RP de la loi. Montants pensés pour « piquer » sans ruiner.
-- ---------------------------------------------------------------------
Eco.Fines = {
    stationnement   = { amount = 250,  label = 'Stationnement gênant' },
    exces_vitesse   = { amount = 500,  label = 'Excès de vitesse' },
    feu_rouge       = { amount = 750,  label = 'Refus de priorité / feu rouge' },
    conduite_dang   = { amount = 1500, label = 'Conduite dangereuse' },
    defaut_assurance= { amount = 2000, label = 'Défaut d\'assurance' },
    delit_fuite     = { amount = 5000, label = 'Délit de fuite' },
    -- Borne dure : aucune amende au-delà (anti-abus d'un agent ripoux).
    _max = 25000,
}

return Eco
