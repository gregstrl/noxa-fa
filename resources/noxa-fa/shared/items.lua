-- =====================================================================
--  NOXA FA — Catalogue d'objets & réglages d'inventaire (shared)
--  Source UNIQUE des définitions d'items : poids, empilable, utilisable,
--  effets. Lu côté client (rendu NUI : icône/label/poids) ET côté serveur
--  (autorité : poids transporté, effets de consommation, anti-dupe).
--  La table noxa_items en BDD n'est qu'un miroir de référence (admin) ;
--  l'autorité runtime, c'est ce fichier.
-- =====================================================================

Noxa = Noxa or {}
local C = Noxa.Config
C.Inventory = C.Inventory or {}

-- ---------------------------------------------------------------------
--  Réglages globaux de l'inventaire
-- ---------------------------------------------------------------------
C.Inventory.slots      = 30        -- emplacements du sac
C.Inventory.hotbar     = 5         -- emplacements de raccourci (touches 1-5)
C.Inventory.maxWeight  = 50000     -- poids max transporté, en grammes (50 kg)
C.Inventory.dropRadius = 2.5       -- distance max pour donner un objet à un joueur

-- ---------------------------------------------------------------------
--  Catalogue. Chaque item :
--    label      : nom affiché
--    weight     : poids unitaire en grammes
--    stackable  : empilable dans un même slot (sinon 1 par slot)
--    usable     : déclenche un effet via « Utiliser »
--    emoji      : icône NUI (zéro asset externe)
--    category   : regroupement (consommable/outil/divers)
--    effects    : table d'effets serveur appliqués à l'usage
--                 (hunger/thirst/stress = delta besoin ; health = soin ;
--                  action = hook spécial : 'phone')
-- ---------------------------------------------------------------------
C.Items = {
    bread = {
        label = 'Pain', weight = 150, stackable = true, usable = true,
        emoji = '🍞', category = 'consommable', effects = { hunger = 25 },
    },
    water = {
        label = 'Bouteille d\'eau', weight = 500, stackable = true, usable = true,
        emoji = '💧', category = 'consommable', effects = { thirst = 35 },
    },
    sandwich = {
        label = 'Sandwich', weight = 200, stackable = true, usable = true,
        emoji = '🥪', category = 'consommable', effects = { hunger = 40 },
    },
    juice = {
        label = 'Jus de fruit', weight = 450, stackable = true, usable = true,
        emoji = '🧃', category = 'consommable', effects = { thirst = 25 },
    },
    meal = {
        label = 'Repas complet', weight = 600, stackable = true, usable = true,
        emoji = '🍱', category = 'consommable', effects = { hunger = 60, thirst = 30 },
    },
    bandage = {
        label = 'Bandage', weight = 50, stackable = true, usable = true,
        emoji = '🩹', category = 'consommable', effects = { health = 20, stress = -5 },
    },
    phone = {
        label = 'Téléphone', weight = 180, stackable = false, usable = true,
        emoji = '📱', category = 'outil', effects = { action = 'phone' },
    },
    lockpick = {
        label = 'Crochet', weight = 120, stackable = true, usable = true,
        emoji = '🪛', category = 'outil', effects = { action = 'lockpick' },
    },
    -- Outils métiers (jobs actifs : police / EMS / mécanicien) -----------
    handcuffs = {
        label = 'Menottes', weight = 300, stackable = false, usable = false,
        emoji = '🔗', category = 'outil',
    },
    medikit = {
        label = 'Kit médical', weight = 1200, stackable = true, usable = false,
        emoji = '🚑', category = 'outil',
    },
    repairkit = {
        label = 'Kit de réparation', weight = 2000, stackable = true, usable = false,
        emoji = '🔧', category = 'outil',
    },
}

--- Définition d'un item (ou nil si inconnu).
---@param name string
---@return table|nil
function C.getItem(name)
    return C.Items[tostring(name or '')]
end

--- Empilable ? (items inconnus traités comme non empilables par prudence)
---@param name string
function C.isStackable(name)
    local it = C.Items[name]
    return it ~= nil and it.stackable == true
end

return C.Items
