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
        -- Inventaire : la réorganisation (drag&drop) et l'usage peuvent être
        -- rapides — limites plus larges pour ne pas flagger un jeu normal.
        ['noxa:inv:move']    = { count = 60, window = 10000 },
        ['noxa:inv:use']     = { count = 30, window = 10000 },
        ['noxa:inv:request'] = { count = 30, window = 10000 },
        ['noxa:inv:drop']    = { count = 30, window = 10000 },
        -- Panneau admin : navigation au clavier + rafraîchissements fréquents
        -- (limites larges pour ne pas flagger un staff légitime).
        ['noxa:admin:fetch']  = { count = 80, window = 10000 },
        ['noxa:admin:action'] = { count = 60, window = 10000 },
        -- Panel gestion serveur : enchaînement de sauvegardes par un superadmin.
        ['noxa:cfg:action']   = { count = 80, window = 10000 },
        ['noxa:cfg:refresh']  = { count = 40, window = 10000 },
        -- Panel staff : navigation + rafraîchissements fréquents par un staff.
        ['noxa:staff:open']   = { count = 20, window = 10000 },
        ['noxa:staff:fetch']  = { count = 80, window = 10000 },
        ['noxa:staff:action'] = { count = 80, window = 10000 },
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

-- =====================================================================
--  JOBS ACTIFS — réglages Police / EMS / Mécanicien (validés serveur)
-- =====================================================================
C.JobActions = {
    -- Police : menottage, fouille, amende, emprisonnement
    police = {
        actionDistance = 4.0,        -- distance max acteur<->cible (menottes/fouille)
        maxFine        = 50000,      -- montant maximal d'une amende
        maxJail        = 120,        -- durée maximale de prison (minutes)
        -- Prison de Bolingbroke (intérieur cellules)
        jail    = { x = 1641.80, y = 2570.50, z = 45.56, heading = 270.0 },
        release = { x = 1846.00, y = 2585.00, z = 45.67, heading = 0.0 },
    },
    -- EMS : réanimation, soin, état inconscient
    ems = {
        actionDistance = 4.0,
        hospital       = { x = 295.80, y = -1446.90, z = 29.97, heading = 0.0 },
        deathBleedout   = 5 * 60,    -- secondes avant respawn auto possible (info HUD)
    },
    -- Mécanicien : réparation (coût items + délai)
    mechanic = {
        repairTime     = 30000,      -- durée de réparation (ms)
        repairItem     = 'repairkit',-- item consommé
        repairCount    = 1,          -- quantité consommée par réparation
        actionDistance = 6.0,        -- distance max au véhicule réparé
    },
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

-- =====================================================================
--  ANTI-CHEAT — détection server-side (vélocité, position, santé, armes,
--  spawn d'entités) + échelle de sanctions. TOUT est vérifié serveur ;
--  le client n'est JAMAIS de confiance. Seuils volontairement larges pour
--  ne pas pénaliser un jeu légitime : une détection vaut mieux qu'un faux
--  positif qui bannirait un joueur honnête.
-- =====================================================================
C.AntiCheat = {
    enabled       = true,
    scanInterval  = 3000,        -- ms entre deux passes de scan serveur
    -- Rang staff (et au-dessus) EXEMPTÉ du scan : un modérateur peut avoir un
    -- comportement « anormal » légitime (noclip, TP, test). user/helper restent surveillés.
    exemptRank    = 'mod',
    graceMs       = 8000,        -- fenêtre de grâce après une TP serveur légitime (jail, bien, admin)

    -- Vitesse : vélocité serveur (m/s). 1 m/s ≈ 3.6 km/h.
    speed = {
        onFoot    = 12.0,        -- ~43 km/h : un sprint humain plafonne ~7 m/s
        inVehicle = 95.0,        -- ~342 km/h : au-delà = véhicule trafiqué (hypercar ≈ 150 km/h)
        severity  = 'high',
    },
    -- Téléportation : grand saut de position NON corrélé à la vélocité (blink).
    -- On compare la distance parcourue à la distance plausible (vélocité × Δt).
    teleport = {
        minJump   = 80.0,        -- en-deçà : jamais flaggé (déplacements normaux)
        tolerance = 1.8,         -- marge : distance ≤ vélocité×Δt×tolérance + base
        base      = 25.0,        -- distance « gratuite » par scan (latence, courbes)
        severity  = 'medium',
    },
    -- God mode : santé / armure hors bornes légitimes (max health joueur = 200).
    godmode = {
        maxHealth = 200,
        maxArmor  = 100,
        severity  = 'high',
    },
    -- Armes interdites en RP (spawn d'arme / menu de triche), lues server-side.
    weapons = {
        severity  = 'critical',
        blacklist = {
            [`WEAPON_MINIGUN`]        = true,
            [`WEAPON_RPG`]            = true,
            [`WEAPON_GRENADELAUNCHER`]= true,
            [`WEAPON_GRENADELAUNCHER_SMOKE`] = true,
            [`WEAPON_RAILGUN`]        = true,
            [`WEAPON_HOMINGLAUNCHER`] = true,
            [`WEAPON_COMPACTLAUNCHER`]= true,
            [`WEAPON_RAYMINIGUN`]     = true,
        },
    },
    -- Spam de spawn d'entités réseau (props/véhicules) : fenêtre glissante.
    spawn = {
        window      = 10000,     -- fenêtre (ms)
        maxInWindow = 10,        -- nb max d'entités créées / fenêtre / joueur
        severity    = 'medium',
    },
    -- Échelle d'action : poids par sévérité -> score cumulé -> sanction.
    weights = { low = 1, medium = 2, high = 3, critical = 6 },
    actions = {
        warnAt   = 2,            -- avertit le joueur (dissuasion) + alerte staff
        freezeAt = 4,            -- fige le joueur + alerte URGENTE staff
        kickAt   = 6,            -- expulsion + log
        banAt    = 10,           -- bannissement automatique + log
    },
    banDuration   = 0,           -- durée du ban auto (secondes ; 0 = permanent)
    decayInterval = 60000,       -- le score décroît dans le temps...
    decayAmount   = 1,           -- ...de N points par minute (évite l'accumulation lente)
    -- Capture d'écran staff (optionnel) : URL de webhook Discord. Vide = désactivé.
    -- Nécessite la ressource externe `screenshot-basic` (non incluse, facultative).
    screenshotWebhook = '',
}

-- =====================================================================
--  MONDE — Points d'intérêt (POI), blips & zones d'interaction
--  Source unique des lieux. blips.lua dessine la carte, zones.lua gère la
--  proximité (thread 500ms) + le prompt NUI « [ E ] Accéder ».
--  Chaque catégorie : { label, blip{sprite,color,scale,shortRange}|false,
--                        interact{type, prompt}, points{ {x,y,z}, ... } }
-- =====================================================================
C.POI = {
    bank = {
        label = 'Banque',
        blip  = { sprite = 108, color = 2, scale = 0.85, shortRange = true },
        interact = { type = 'bank', prompt = 'Accéder à la banque' },
        points = {
            { x = 149.93,   y = -1040.20, z = 29.37 },
            { x = -1212.98, y = -330.84,  z = 37.78 },
            { x = -2962.60, y = 482.60,   z = 15.70 },
            { x = 1175.00,  y = 2706.80,  z = 38.09 },
            { x = 314.18,   y = -278.00,  z = 54.17 },
            { x = -351.53,  y = -49.52,   z = 49.04 },
        },
    },
    atm = {
        label = 'Distributeur',
        blip  = { sprite = 277, color = 2, scale = 0.55, shortRange = true },
        interact = { type = 'bank', prompt = 'Utiliser le distributeur' },
        points = {
            { x = 147.42,   y = -1035.60, z = 29.34 },
            { x = -1205.00, y = -324.00,  z = 37.87 },
            { x = 295.80,   y = -895.60,  z = 29.21 },
            { x = -57.60,   y = -92.60,   z = 57.78 },
            { x = 24.50,    y = -946.20,  z = 29.36 },
            { x = 129.40,   y = 234.50,   z = 105.50 },
            { x = -253.30,  y = -692.40,  z = 33.60 },
            { x = 1135.60,  y = -469.50,  z = 66.70 },
            { x = -846.60,  y = -340.00,  z = 38.70 },
            { x = 33.00,    y = -1347.80, z = 29.50 },
            { x = 289.50,   y = -1256.50, z = 29.44 },
            { x = -537.00,  y = -854.00,  z = 29.20 },
            { x = 1167.40,  y = 2708.90,  z = 38.10 },
            { x = 379.20,   y = 325.60,   z = 103.60 },
            { x = 1822.00,  y = 3683.00,  z = 34.30 },
            { x = 540.50,   y = 2671.00,  z = 42.20 },
        },
    },
    grocery = {
        label = 'Épicerie 24/7',
        blip  = { sprite = 52, color = 2, scale = 0.80, shortRange = true },
        interact = { type = 'shop', prompt = 'Parcourir l\'épicerie', extra = 'grocery' },
        points = {
            { x = 24.50,    y = -1347.30, z = 29.50 },
            { x = -47.50,   y = -1757.50, z = 29.42 },
            { x = 1135.00,  y = -982.30,  z = 46.42 },
            { x = -707.50,  y = -914.30,  z = 19.22 },
            { x = -1820.50, y = 792.50,   z = 138.11 },
            { x = 1697.99,  y = 4924.40,  z = 42.06 },
            { x = 1961.50,  y = 3740.00,  z = 32.34 },
            { x = 547.40,   y = 2671.70,  z = 42.16 },
            { x = 2557.50,  y = 382.30,   z = 108.62 },
        },
    },
    clothing = {
        label = 'Vêtements',
        blip  = { sprite = 73, color = 47, scale = 0.80, shortRange = true },
        interact = { type = 'clothing', prompt = 'Entrer dans la boutique' },
        points = {
            { x = 72.30,    y = -1399.10, z = 29.38 },
            { x = -703.80,  y = -152.30,  z = 37.42 },
            { x = -167.90,  y = -298.90,  z = 39.73 },
            { x = 428.70,   y = -800.10,  z = 29.49 },
            { x = -1193.40, y = -772.30,  z = 17.32 },
            { x = 4.90,     y = 6512.30,  z = 31.88 },
            { x = 1190.40,  y = 2713.40,  z = 38.22 },
            { x = 618.10,   y = 2759.30,  z = 42.09 },
        },
    },
    barber = {
        label = 'Coiffeur',
        blip  = { sprite = 71, color = 48, scale = 0.75, shortRange = true },
        interact = { type = 'barber', prompt = 'S\'asseoir chez le coiffeur' },
        points = {
            { x = -814.30,  y = -183.80,  z = 37.57 },
            { x = 136.80,   y = -1708.30, z = 29.29 },
            { x = -1282.60, y = -1117.00, z = 6.99 },
            { x = 1931.50,  y = 3729.70,  z = 32.84 },
            { x = -32.90,   y = -152.20,  z = 57.08 },
        },
    },
    hospital = {
        label = 'Hôpital',
        blip  = { sprite = 61, color = 1, scale = 0.90, shortRange = false },
        interact = { type = 'hospital', prompt = 'Se faire soigner' },
        points = {
            { x = 295.80,   y = -1446.90, z = 29.97 },
            { x = -449.70,  y = -340.50,  z = 34.50 },
            { x = 1839.60,  y = 3672.90,  z = 34.28 },
            { x = -247.80,  y = 6331.00,  z = 32.43 },
        },
    },
    police = {
        label = 'Commissariat',
        blip  = { sprite = 60, color = 29, scale = 0.90, shortRange = false },
        interact = { type = 'police', prompt = 'Accéder au poste' },
        points = {
            { x = 425.10,   y = -979.50,  z = 30.71 },
            { x = -1108.50, y = -845.00,  z = 19.32 },
            { x = 1853.20,  y = 3686.60,  z = 34.27 },
            { x = -448.50,  y = 6012.60,  z = 31.72 },
        },
    },
    garage = {
        label = 'Garage',
        blip  = { sprite = 357, color = 3, scale = 0.80, shortRange = true },
        interact = { type = 'garage', prompt = 'Ouvrir le garage' },
        points = {
            { x = -337.00,  y = -135.00,  z = 39.00 },
            { x = 215.00,   y = -810.00,  z = 30.73 },
            { x = -340.00,  y = -1450.00, z = 30.66 },
            { x = 1736.00,  y = 3710.00,  z = 34.16 },
            { x = -169.00,  y = 6219.00,  z = 31.49 },
        },
    },
    fuel = {
        label = 'Station essence',
        blip  = { sprite = 361, color = 5, scale = 0.75, shortRange = true },
        interact = { type = 'fuel', prompt = 'Faire le plein' },
        points = {
            { x = 49.40,    y = 2778.80, z = 58.04 },
            { x = 263.90,   y = 2606.50, z = 44.98 },
            { x = 1039.90,  y = 2671.10, z = 39.55 },
            { x = 2539.70,  y = 2594.20, z = 37.94 },
            { x = 2005.00,  y = 3773.90, z = 32.40 },
            { x = 1687.20,  y = 4929.40, z = 42.08 },
            { x = -70.20,   y = -1761.80, z = 29.53 },
            { x = 265.10,   y = -1261.30, z = 29.29 },
            { x = -724.60,  y = -935.10, z = 19.21 },
            { x = -1437.60, y = -276.80, z = 46.21 },
        },
    },
    mairie = {
        label = 'Mairie',
        blip  = { sprite = 419, color = 0, scale = 0.85, shortRange = true },
        interact = { type = 'mairie', prompt = 'Entrer à la mairie' },
        points = {
            { x = -545.00,  y = -204.00, z = 38.22 },
        },
    },
    fishing = {
        label = 'Pêche',
        blip  = { sprite = 68, color = 3, scale = 0.75, shortRange = true },
        interact = { type = 'fishing', prompt = 'Lancer la ligne' },
        points = {
            { x = -1850.00, y = -1240.00, z = 8.62 },
            { x = 1300.00,  y = 4216.00,  z = 33.90 },
            { x = -1493.00, y = -938.00,  z = 9.00 },
            { x = 3849.00,  y = 4459.00,  z = 4.00 },
        },
    },
    hunting = {
        label = 'Chasse',
        blip  = { sprite = 442, color = 5, scale = 0.75, shortRange = true },
        interact = { type = 'hunting', prompt = 'Préparer la chasse' },
        points = {
            { x = -1577.00, y = 4717.00, z = 60.00 },
            { x = 1700.00,  y = 4780.00, z = 42.00 },
            { x = -780.00,  y = 5575.00, z = 34.00 },
        },
    },
    casino = {
        label = 'Casino Diamond',
        blip  = { sprite = 679, color = 2, scale = 0.90, shortRange = true },
        interact = { type = 'casino', prompt = 'Entrer au casino' },
        points = {
            { x = 925.00,   y = 46.00, z = 81.10 },
        },
    },
    dealership = {
        label = 'Concession automobile',
        blip  = { sprite = 326, color = 46, scale = 0.90, shortRange = false },
        interact = { type = 'dealership', prompt = 'Parcourir la concession' },
        points = {
            { x = -56.70,  y = -1096.60, z = 26.42 },   -- Premium Deluxe Motorsport
            { x = -1255.60, y = -361.00, z = 36.91 },   -- showroom secondaire
        },
    },
}

-- =====================================================================
--  VÉHICULES — concession, garages & fourrière (état persisté en BDD).
--  Le catalogue/prix vit dans shared/economy/vehicles.lua (C.Vehicles).
-- =====================================================================
C.VehicleConfig = {
    defaultGarage = 'central',     -- garage unique (foundation : tous les POI 'garage')
    impoundFee    = 5000,          -- amende de récupération en fourrière
    -- Point de sortie d'un véhicule depuis la concession (livraison immédiate).
    dealerSpawn   = { x = -30.50, y = -1095.50, z = 26.40, heading = 70.0 },
    -- Décalage de sortie au garage (devant le ped) si aucun point libre détecté.
    garageSpawnOffset = 3.0,
    plateFormat   = 'NX%05d',      -- gabarit de plaque (numérique borné)
}

-- =====================================================================
--  MONDE — Cycle jour/nuit & météo (autorité serveur, broadcast 30s).
--  Le serveur fait foi du temps écoulé ; le client interpole entre deux
--  synchros et verrouille la météo (pas de cycle aléatoire GTA).
-- =====================================================================
C.World = {
    startHour     = 8,           -- heure de démarrage du serveur (au boot)
    -- Échelle de temps : durée réelle (ms) d'UNE minute en jeu.
    -- 2000 ms/min => journée complète en 48 min réelles (rythme RP confortable).
    msPerMinute   = 2000,
    broadcast     = 30 * 1000,   -- intervalle de diffusion de l'heure/météo
    transition    = 15,          -- durée de transition météo (secondes)
    -- Rotation météo : durée réelle (ms) de chaque palier + séquence réaliste.
    weatherHold   = 10 * 60 * 1000,
    weatherCycle  = {
        'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST',
        'RAIN', 'THUNDER', 'CLEARING', 'CLOUDS',
    },
}

-- =====================================================================
--  ÉPICERIE — catalogue (prix + effets besoins). Validé/borné serveur.
-- =====================================================================
C.Shops = {
    grocery = {
        label = 'Épicerie 24/7',
        items = {
            { id = 'water',    label = 'Bouteille d\'eau', price = 50,  emoji = '💧', thirst = 40 },
            { id = 'sandwich', label = 'Sandwich',        price = 75,  emoji = '🥪', hunger = 40 },
            { id = 'juice',    label = 'Jus de fruit',    price = 35,  emoji = '🧃', thirst = 25 },
            { id = 'meal',     label = 'Repas complet',   price = 150, emoji = '🍱', hunger = 60, thirst = 30 },
        },
    },
}

-- =====================================================================
--  STATION ESSENCE — 2$/% · mise à jour noxa_vehicles.fuel
-- =====================================================================
C.Fuel = {
    pricePerUnit = 2,     -- coût d'un point de carburant (1%)
    maxFuel      = 100,
    tickMs       = 200,   -- intervalle de remplissage (jauge fluide)
    unitsPerTick = 2,     -- carburant ajouté par tick
}

-- =====================================================================
--  IMMOBILIER — paliers, prix & biens (coords pilotées config, état en BDD)
--  Le serveur seed `noxa_properties` depuis cette table au démarrage.
-- =====================================================================
C.PropertyTiers = {
    studio    = { label = 'Studio',      price = 50000 },
    apartment = { label = 'Appartement', price = 150000 },
    house     = { label = 'Maison',      price = 400000 },
    villa     = { label = 'Villa',       price = 1200000 },
}

-- Catalogue de mobilier plaçable à l'intérieur (modèle prop + libellé).
C.Furniture = {
    { model = 'prop_off_chair_05',     label = 'Chaise',        emoji = '🪑' },
    { model = 'prop_table_03',         label = 'Table',         emoji = '🛋' },
    { model = 'prop_tv_flat_01',       label = 'Télévision',    emoji = '📺' },
    { model = 'v_res_d_bed',           label = 'Lit',           emoji = '🛏' },
    { model = 'prop_couch_01',         label = 'Canapé',        emoji = '🛋' },
    { model = 'prop_plant_01a',        label = 'Plante',        emoji = '🪴' },
    { model = 'prop_food_bs_tray_01',  label = 'Étagère',       emoji = '📦' },
    { model = 'prop_ld_fridge_01',     label = 'Réfrigérateur', emoji = '🧊' },
}

-- Intérieurs partagés (shells GTA par défaut). Plusieurs biens peuvent
-- pointer vers le même intérieur : l'instanciation logique se fait par owner.
C.Interiors = {
    studio    = { x = 261.30,  y = -1287.00, z = -25.30, heading = 0.0 },
    apartment = { x = -773.90, y = 342.02,   z = 196.69, heading = 180.0 },
    house     = { x = -174.10, y = 497.10,   z = 137.43, heading = 200.0 },
    villa     = { x = -1289.40, y = 454.50,  z = 96.90,  heading = 300.0 },
}

C.Properties = {
    { name = 'apt_integrity', label = 'Integrity Way, Apt 1', tier = 'apartment',
      door = { x = -47.00,   y = -585.00,  z = 37.00 } },
    { name = 'apt_morningwood', label = 'Morningwood Blvd, Apt 4', tier = 'apartment',
      door = { x = -1447.30, y = -537.60,  z = 33.30 } },
    { name = 'studio_mirror', label = 'Mirror Park Studio', tier = 'studio',
      door = { x = 1216.40,  y = -640.20,  z = 67.60 } },
    { name = 'studio_vespucci', label = 'Vespucci Studio', tier = 'studio',
      door = { x = -1289.00, y = -1115.00, z = 6.80 } },
    { name = 'house_grove', label = 'Grove Street House', tier = 'house',
      door = { x = 87.40,    y = -1959.00, z = 21.10 } },
    { name = 'house_vinewood', label = 'Vinewood Hills House', tier = 'house',
      door = { x = -174.10,  y = 502.10,   z = 137.43 } },
    { name = 'villa_richman', label = 'Richman Villa', tier = 'villa',
      door = { x = -1289.40, y = 449.50,   z = 96.90 } },
}

-- =====================================================================
--  SYSTÈMES — bascules globales pilotées en direct (panel gestion serveur)
--  Valeurs par défaut ; surchargées à chaud via le config-manager (BDD).
--  Les modules concernés lisent ces drapeaux au runtime (jamais de restart).
-- =====================================================================
C.Systems = {
    pvp           = true,    -- tirs amis autorisés (PVP global)
    weatherAuto   = true,    -- rotation météo automatique (sinon météo figée)
    forcedWeather = false,   -- type météo imposé quand weatherAuto = false (ex 'RAIN')
    payroll       = true,    -- versement automatique des salaires
    economyTax    = true,    -- prélèvement des taxes/puits monétaires
    scheduledMsg  = true,    -- diffusion des messages serveur planifiés
}

-- =====================================================================
--  TÉLÉPHONE — réglages NUI (touche, applications)
-- =====================================================================
C.Phone = {
    openKey = 'F1',
    maxContacts = 100,
    maxMessages = 200,   -- messages conservés par conversation
}

return C
