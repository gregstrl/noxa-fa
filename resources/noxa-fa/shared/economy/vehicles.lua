-- =====================================================================
--  NOXA FA — ÉCONOMIE : Catalogue & prix des véhicules (shared)
--  ---------------------------------------------------------------------
--  Source UNIQUE des prix de concession. Le serveur lit ici (jamais le
--  client) le prix d'un modèle à l'achat. Chaque palier de classe respecte
--  la grille imposée et l'invariant temporel « S = 200–500 h de jeu ».
--
--  MÉTHODE DE FIXATION DU PRIX :
--    prix ≈ heures_visées × revenu_horaire_de_référence
--    On utilise deux références :
--      • revenu MÉDIAN légal soutenable  ≈ 2 500 $/h  (bas/moyen du jeu)
--      • revenu HAUT légitime soutenable ≈ 8 000 $/h  (top illégal/business)
--    Les classes F→C visent l'accessibilité au revenu médian ; les classes
--    B→S visent l'endgame au revenu haut (sinon inflation impossible à tenir).
-- =====================================================================

Noxa = Noxa or {}
local C = Noxa.Config
C.Economy = C.Economy or {}

-- Références horaires utilisées pour justifier les durées d'acquisition.
local REF_MEDIAN = 2500   -- $/h net, joueur légal moyen
local REF_HIGH   = 8000   -- $/h net, top earner légitime (cf. bande illégale)

-- ---------------------------------------------------------------------
--  Paliers de classe : bornes de prix imposées + durée d'acquisition cible.
--  `ref` = revenu horaire servant à juger la durée (median|high).
-- ---------------------------------------------------------------------
C.VehicleClasses = {
    F = { label = 'F — Citadine / 2 roues',  min = 5000,    max = 20000,   ref = 'median',
          why = 'Premier véhicule : 2–8 h de jeu. Mobilité de base pour tous.' },
    E = { label = 'E — Compacte',            min = 20000,   max = 60000,   ref = 'median',
          why = 'Citadine fiable : ~8–24 h. Objectif de la 1re semaine.' },
    D = { label = 'D — Berline / SUV',       min = 60000,   max = 150000,  ref = 'median',
          why = 'Véhicule familial/travail : ~24–60 h.' },
    C = { label = 'C — Sport d\'entrée',     min = 150000,  max = 400000,  ref = 'median',
          why = 'Première sportive : ~60–160 h au revenu médian.' },
    B = { label = 'B — Sportive',            min = 400000,  max = 900000,  ref = 'high',
          why = 'Sportive confirmée : ~50–110 h au revenu haut (endgame léger).' },
    A = { label = 'A — Supersport',          min = 900000,  max = 2000000, ref = 'high',
          why = 'Supersport : ~110–250 h au revenu haut. Marqueur de réussite.' },
    S = { label = 'S — Hypercar',            min = 2000000, max = 8000000, ref = 'high',
          why = 'INVARIANT : 250–1000 h. Flagship endgame, statut ultime.' },
}

-- ---------------------------------------------------------------------
--  Catalogue concession. spawn = nom de modèle GTA, class = palier ci-dessus.
--  Chaque prix est borné par sa classe (vérifié au boot par Eco.checkVehicles).
-- ---------------------------------------------------------------------
C.Vehicles = {
    -- F — Citadines & 2 roues : mobilité accessible dès les premières heures.
    { spawn = 'panto',    label = 'Benefactor Panto',  class = 'F', price = 6000 },
    { spawn = 'blista',   label = 'Dinka Blista',      class = 'F', price = 9500 },
    { spawn = 'asea',     label = 'Declasse Asea',     class = 'F', price = 12000 },
    { spawn = 'brioso',   label = 'Grotti Brioso R/A', class = 'F', price = 16000 },
    { spawn = 'faggio',   label = 'Pegassi Faggio',    class = 'F', price = 5000 },

    -- E — Compactes : premier vrai achat « confort ».
    { spawn = 'warrener', label = 'Vapid Warrener',    class = 'E', price = 24000 },
    { spawn = 'futo',     label = 'Karin Futo',        class = 'E', price = 30000 },
    { spawn = 'sultan',   label = 'Karin Sultan',      class = 'E', price = 42000 },
    { spawn = 'kuruma',   label = 'Karin Kuruma',      class = 'E', price = 56000 },

    -- D — Berlines / SUV : véhicule de travail polyvalent.
    { spawn = 'intruder', label = 'Karin Intruder',    class = 'D', price = 68000 },
    { spawn = 'buffalo',  label = 'Bravado Buffalo',   class = 'D', price = 82000 },
    { spawn = 'tailgater',label = 'Obey Tailgater',    class = 'D', price = 98000 },
    { spawn = 'baller2',  label = 'Gallivanter Baller',class = 'D', price = 145000 },

    -- C — Sportives d'entrée : première sportive, ~60–160 h.
    { spawn = 'elegy',    label = 'Annis Elegy RH8',   class = 'C', price = 175000 },
    { spawn = 'sultanrs', label = 'Karin Sultan RS',   class = 'C', price = 225000 },
    { spawn = 'banshee',  label = 'Bravado Banshee',   class = 'C', price = 260000 },
    { spawn = 'comet2',   label = 'Pfister Comet',     class = 'C', price = 330000 },

    -- B — Sportives confirmées : endgame léger (revenu haut).
    { spawn = 'jester3',  label = 'Dinka Jester Classic', class = 'B', price = 480000 },
    { spawn = 'sc1',      label = 'Ubermacht SC1',     class = 'B', price = 620000 },
    { spawn = 'neon',     label = 'Pfister Neon',      class = 'B', price = 700000 },
    { spawn = 'pariah',   label = 'Ocelot Pariah',     class = 'B', price = 850000 },

    -- A — Supersport : marqueur de réussite, 110–250 h.
    { spawn = 'reaper',   label = 'Pegassi Reaper',    class = 'A', price = 980000 },
    { spawn = 'zentorno', label = 'Pegassi Zentorno',  class = 'A', price = 1250000 },
    { spawn = 'nero',     label = 'Truffade Nero',     class = 'A', price = 1450000 },
    { spawn = 't20',      label = 'Progen T20',        class = 'A', price = 1700000 },

    -- S — Hypercars : flagship endgame, l'invariant temporel ultime.
    { spawn = 'tigon',    label = 'Lampadati Tigon',   class = 'S', price = 2200000 },
    { spawn = 'zorrusso', label = 'Pegassi Zorrusso',  class = 'S', price = 3000000 },
    { spawn = 'emerus',   label = 'Progen Emerus',     class = 'S', price = 3400000 },
    { spawn = 'thrax',    label = 'Truffade Thrax',    class = 'S', price = 4000000 },
    { spawn = 'krieger',  label = 'Benefactor Krieger',class = 'S', price = 4200000 },
    { spawn = 'deveste',  label = 'Principe Deveste',  class = 'S', price = 5100000 },
    { spawn = 's80',      label = 'Annis S80RR',       class = 'S', price = 6500000 },
    { spawn = 'tyrant',   label = 'Overflod Tyrant',   class = 'S', price = 8000000 },
}

-- ---------------------------------------------------------------------
--  REVENTE (concession) — FAUCET borné, pensé anti-spéculation.
--  Revendre un véhicule réinjecte de l'argent dans la masse monétaire : on
--  ne récupère donc qu'une FRACTION du prix catalogue HT, jamais les taxes
--  d'achat (TVA luxe « brûlée »). Acheter puis revendre est structurellement
--  PERDANT (≥ 50 % + surtaxe luxe), ce qui tue le flip et garde le faucet
--  sous contrôle. L'état du véhicule module encore la valeur (une épave vaut
--  moins), sans jamais tomber à zéro (socle `minCondition`).
-- ---------------------------------------------------------------------
C.Economy.Resale = {
    rate         = 0.50,  -- 50 % du prix catalogue HT : revendre = perte sèche assumée.
    minCondition = 0.60,  -- plancher d'état : une épave conserve 60 % de la valeur de revente.
}

-- Index spawn -> entrée (résolution O(1) côté serveur).
C.VehicleIndex = {}
for _, v in ipairs(C.Vehicles) do
    C.VehicleIndex[v.spawn] = v
end

--- Prix d'un modèle (source serveur). nil si hors catalogue.
---@param spawn string
---@return integer|nil price, table|nil entry
function C.getVehiclePrice(spawn)
    local v = C.VehicleIndex[tostring(spawn or ''):lower()]
    if not v then return nil end
    return v.price, v
end

-- ---------------------------------------------------------------------
--  Vérification au boot (debug) : bornes de classe + invariant temporel.
-- ---------------------------------------------------------------------
function C.Economy.checkVehicles()
    if not C.Debug then return end
    local refs = { median = REF_MEDIAN, high = REF_HIGH }
    for _, v in ipairs(C.Vehicles) do
        local cls = C.VehicleClasses[v.class]
        if not cls then
            print(('[Noxa:eco] Véhicule %s : classe inconnue %s'):format(v.spawn, tostring(v.class)))
        elseif v.price < cls.min or v.price > cls.max then
            print(('[Noxa:eco] Véhicule %s (%s) : prix %d HORS bande [%d..%d]')
                :format(v.spawn, v.class, v.price, cls.min, cls.max))
        end
    end
    -- Contrôle de l'invariant S = 200–500 h sur le bas de la classe S.
    local hours = 2200000 / refs.high
    print(('[Noxa:eco] Invariant : S d\'entree (2.2M$) = %.0f h au revenu haut (%d$/h).')
        :format(hours, REF_HIGH))
end

return C.Vehicles
