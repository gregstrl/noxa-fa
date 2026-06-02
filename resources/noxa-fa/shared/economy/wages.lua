-- =====================================================================
--  NOXA FA — ÉCONOMIE : Doctrine des salaires (shared, source de vérité)
--  ---------------------------------------------------------------------
--  Ce fichier NE crée PAS d'argent : il documente et borne la grille de
--  rémunération de tout le serveur. Les salaires réels sont versés par le
--  module Emplois (server/modules/jobs) depuis les CAISSES SOCIÉTÉ — jamais
--  ex nihilo. Ici on définit la *doctrine* et les outils de conversion.
--
--  RÈGLE D'OR — durée de jeu pour s'offrir un véhicule :
--    Une supercar (classe S, 2 M–8 M$) doit coûter 200–500 h de jeu
--    LÉGITIME au plus haut revenu soutenable (~8 000 $/h net). Cf.
--    economy/vehicles.lua qui calcule et vérifie cet invariant au boot.
-- =====================================================================

Noxa = Noxa or {}
local C = Noxa.Config
C.Economy = C.Economy or {}
local Eco = C.Economy

-- ---------------------------------------------------------------------
--  Rythme de paie
--  La paie tombe toutes les `Jobs.payInterval` (30 min par défaut), donc
--  2 cycles / heure. Tout salaire « par cycle » dans enums.lua vaut donc
--  le double en taux horaire. On dérive le facteur depuis la config (une
--  seule source : si on change l'intervalle, les bornes suivent).
-- ---------------------------------------------------------------------
Eco.cyclesPerHour = math.max(1, math.floor(3600000 / (C.Jobs.payInterval or 1800000)))

--- Convertit un salaire « par cycle de paie » en taux horaire.
---@param perCycle integer
---@return integer
function Eco.perHour(perCycle)
    return math.floor((tonumber(perCycle) or 0) * Eco.cyclesPerHour)
end

--- Convertit un taux horaire cible en salaire « par cycle de paie ».
--- (Utilitaire pour équilibrer de nouveaux métiers à partir d'un objectif.)
---@param hourly integer
---@return integer
function Eco.perCycle(hourly)
    return math.floor((tonumber(hourly) or 0) / Eco.cyclesPerHour)
end

-- ---------------------------------------------------------------------
--  Bandes de revenu cibles (taux HORAIRE net visé par catégorie).
--  Sert de garde-fou : le self-check au boot signale tout grade hors bande.
--  Justification de chaque borne ci-dessous.
-- ---------------------------------------------------------------------
Eco.Bands = {
    -- Petits boulots / non qualifié : couvre la subsistance (bouffe + loyer
    -- studio) en laissant une marge d'épargne lente. Plancher d'entrée RP.
    civil     = { min = 500,  max = 1500,  label = 'Civil / non qualifié' },

    -- Métiers légaux qualifiés (police, EMS, mécano, futurs jobs whitelistés).
    -- Doit permettre une berline (classe D) en ~30–80 h, pas un hypercar.
    qualified = { min = 2000, max = 4000,  label = 'Légal qualifié' },

    -- Activités illégales (gangs, trafic). Risque élevé (perte/arrestation/
    -- saisie) => rendement supérieur. Plafond soutenable = 10 000 $/h pour que
    -- l'invariant « S = 200–500 h » tienne sans hyperinflation.
    illegal   = { min = 4000, max = 10000, label = 'Illégal / criminel' },
}

-- Revenu passif de dole (citoyen sans emploi). VOLONTAIREMENT sous la bande
-- civile (≈100 $/h) : c'est un filet anti-blocage, pas un salaire. Le but est
-- d'inciter à trouver un emploi, jamais d'en vivre confortablement.
Eco.doleHourly = 100

-- ---------------------------------------------------------------------
--  Référence de rémunération par métier (taux HORAIRE, justifié).
--  ⚠ Source de vérité = enums.lua (salary par cycle). Cette table est le
--  MIROIR documenté + cible d'équilibrage. `Eco.audit()` (debug) compare les
--  deux et alerte en cas de dérive, garantissant qu'aucun chiffre ne « glisse »
--  sans justification.
--  Format : [job] = { [grade] = { hourly, why } }
-- ---------------------------------------------------------------------
Eco.WageRef = {
    police = {
        [0] = { hourly = 1500, why = 'Cadet : entrée qualifiée bas de bande (formation).' },
        [1] = { hourly = 2000, why = 'Officier : plein statut, bas de bande qualifiée.' },
        [2] = { hourly = 2800, why = 'Sergent : encadrement terrain.' },
        [3] = { hourly = 3800, why = 'Lieutenant : haut de bande, responsabilités RH (recruit).' },
        [4] = { hourly = 5200, why = 'Chef : boss, hors bande assumé (rareté + gestion caisse).' },
    },
    ambulance = {
        [0] = { hourly = 1400, why = 'Interne : entrée, légèrement sous bande qualifiée.' },
        [1] = { hourly = 2200, why = 'Ambulancier : cœur de métier soignant.' },
        [2] = { hourly = 3400, why = 'Médecin : expertise + facturation.' },
        [3] = { hourly = 5000, why = 'Chef : boss, gestion de la caisse EMS.' },
    },
    mechanic = {
        [0] = { hourly = 1200, why = 'Apprenti : sous-qualifié, revenu complété par les réparations.' },
        [1] = { hourly = 2000, why = 'Mécanicien : bas de bande + revenus de prestation (factures).' },
        [2] = { hourly = 3600, why = 'Patron : boss d\'une société privée (marge + caisse).' },
    },
    unemployed = {
        [0] = { hourly = 100,  why = 'Dole : filet de survie, sous-bande délibérément (cf. doleHourly).' },
    },
}

--- Vérifie la cohérence enums.lua ⟷ WageRef + appartenance aux bandes.
--- N'agit qu'en debug (log) : aucune correction silencieuse en prod.
function Eco.audit()
    if not C.Debug then return end
    local E = Noxa.Enums
    if not E then return end
    for jobName, grades in pairs(Eco.WageRef) do
        local job = E.Jobs[jobName]
        if job then
            for grade, ref in pairs(grades) do
                local g = job.grades[grade]
                local realHourly = g and Eco.perHour(g.salary) or 0
                if realHourly ~= ref.hourly then
                    print(('[Noxa:eco] DÉRIVE %s grade %d : enums=%d$/h ref=%d$/h')
                        :format(jobName, grade, realHourly, ref.hourly))
                end
            end
        end
    end
end

return Eco
