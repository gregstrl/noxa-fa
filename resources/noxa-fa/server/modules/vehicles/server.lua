-- =====================================================================
--  NOXA FA — Module Véhicules (server-side, autoritaire)
--  ---------------------------------------------------------------------
--  Concession · Garage · Fourrière. Le serveur est seule autorité :
--    • prix lu dans le catalogue partagé (jamais envoyé par le client) ;
--    • plaque générée serveur, unique en base ;
--    • ownership vérifié sur CHAQUE opération (anti-vol) ;
--    • transitions d'état (stored<->out<->impound) ATOMIQUES en SQL
--      (UPDATE ... WHERE state = ?) = anti double-sortie / anti-dupe.
--  Le client ne fait que spawn/despawn l'entité ; la vérité vit en BDD.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Vehicles = {}

local Veh  = Noxa.Vehicles
local U    = Noxa.Utils
local CFG  = Noxa.Config
local VCFG = Noxa.Config.VehicleConfig
local E    = Noxa.Enums
local S    = Noxa.Security
local DB   = Noxa.DB

-- ---------------------------------------------------------------------
--  Plaque unique
-- ---------------------------------------------------------------------
local function generatePlate()
    for _ = 1, 30 do
        local plate = (VCFG.plateFormat or 'NX%05d'):format(math.random(0, 99999))
        if not DB.plateExists(plate) then return plate end
    end
    -- Repli ultra-improbable : suffixe temporel pour garantir l'unicité.
    return ('NX%05d'):format(os.time() % 100000)
end

-- ---------------------------------------------------------------------
--  Catalogue concession -> NUI (regroupé par classe)
-- ---------------------------------------------------------------------
local function buildCatalog()
    local byClass = {}
    for _, v in ipairs(CFG.Vehicles) do
        local total = Noxa.Economy.vehicleTotal(v.spawn) or v.price
        byClass[v.class] = byClass[v.class] or {}
        table.insert(byClass[v.class], {
            spawn = v.spawn, label = v.label, class = v.class, price = total,
        })
    end
    -- Ordre des classes (premium en bas) + métadonnées de palier.
    local order, out = { 'F', 'E', 'D', 'C', 'B', 'A', 'S' }, {}
    for _, cls in ipairs(order) do
        if byClass[cls] then
            local def = CFG.VehicleClasses[cls]
            out[#out + 1] = { class = cls, label = def and def.label or cls,
                              vehicles = byClass[cls] }
        end
    end
    return out
end
local CATALOG                      -- caché après le 1er calcul (catalogue statique)
local function catalog()
    CATALOG = CATALOG or buildCatalog()
    return CATALOG
end

-- ---------------------------------------------------------------------
--  CONCESSION — achat
-- ---------------------------------------------------------------------
S.onNet('noxa:veh:catalog', function(src, ply)
    TriggerClientEvent('noxa:veh:catalog', src, {
        catalog = catalog(),
        bank    = ply.bank,
    })
end)

S.onNet('noxa:veh:buy', function(src, ply, spawn)
    if not S.cooldown(src, 'veh:buy') then return end
    spawn = tostring(spawn or ''):lower()
    local total, base = Noxa.Economy.vehicleTotal(spawn)
    if not total then
        return S.flag(src, ('veh:buy modèle hors catalogue: %s'):format(spawn))
    end
    if ply.bank < total then
        return TriggerClientEvent('noxa:notify', src, 'Fonds bancaires insuffisants.', 'error')
    end

    local plate = generatePlate()
    -- Débit AVANT insertion ; rollback si l'écriture échoue (cohérence).
    if not ply:removeMoney(E.Accounts.BANK, total, ('vehicle:buy:%s'):format(spawn)) then
        return TriggerClientEvent('noxa:notify', src, 'Paiement refusé.', 'error')
    end
    local ok = DB.createVehicle(ply.citizenid, spawn, plate, VCFG.defaultGarage)
    if not ok then
        ply:addMoney(E.Accounts.BANK, total, 'vehicle:buy:rollback')   -- remboursement
        return TriggerClientEvent('noxa:notify', src, 'Erreur lors de l\'immatriculation.', 'error')
    end

    DB.log('vehicle', 'info', ply.license,
        ('Achat %s (%s) pour %s'):format(spawn, plate, U.money(total)),
        { base = base, total = total, cid = ply.citizenid })
    TriggerClientEvent('noxa:notify', src,
        ('Véhicule acheté (%s). Livré à votre garage.'):format(plate), 'success')
    TriggerClientEvent('noxa:veh:bought', src, { plate = plate, bank = ply.bank })
end)

-- ---------------------------------------------------------------------
--  CONCESSION — revente (FAUCET borné, cf. doctrine economy/vehicles.lua)
--  Seuls les véhicules REMISÉS sont revendables (pas un véhicule sorti ou en
--  fourrière). La valeur est calculée serveur depuis le catalogue + l'état.
-- ---------------------------------------------------------------------
S.onNet('noxa:veh:resaleList', function(src, ply)
    local list = {}
    for _, v in ipairs(DB.getOwnedVehicles(ply.citizenid)) do
        if v.state == 'stored' then
            local value = Noxa.Economy.vehicleResale(v.model, v.engine, v.body)
            if value then
                local cv = CFG.VehicleIndex[v.model]
                list[#list + 1] = {
                    plate = v.plate, model = v.model,
                    label = cv and cv.label or v.model, value = value,
                }
            end
        end
    end
    TriggerClientEvent('noxa:veh:resaleList', src, { vehicles = list })
end)

S.onNet('noxa:veh:sell', function(src, ply, plate)
    if not S.cooldown(src, 'veh:sell') then return end
    plate = tostring(plate or '')
    local row = DB.getOwnedVehicleByPlate(plate, ply.citizenid)
    if not row then return S.flag(src, ('veh:sell non possédé: %s'):format(plate)) end
    if row.state ~= 'stored' then
        return TriggerClientEvent('noxa:notify', src,
            'Seul un véhicule remisé peut être revendu.', 'error')
    end
    local value = Noxa.Economy.vehicleResale(row.model, row.engine, row.body)
    if not value then
        return TriggerClientEvent('noxa:notify', src,
            'Ce modèle ne peut pas être revendu ici.', 'error')
    end
    -- Suppression GARDÉE (remisé + possédé) AVANT crédit : si elle échoue
    -- (déjà vendu / sorti entre-temps), aucun argent n'est créé.
    if not DB.deleteOwnedVehicle(plate, ply.citizenid, 'stored') then
        return TriggerClientEvent('noxa:notify', src,
            'Revente impossible (véhicule indisponible).', 'error')
    end
    ply:addMoney(E.Accounts.BANK, value, ('vehicle:sell:%s'):format(row.model))
    DB.log('vehicle', 'info', ply.license,
        ('Revente %s (%s) pour %s'):format(row.model, plate, U.money(value)),
        { value = value, cid = ply.citizenid })
    TriggerClientEvent('noxa:notify', src,
        ('Véhicule revendu (%s) : %s versés sur votre compte.'):format(plate, U.money(value)),
        'success')
    TriggerClientEvent('noxa:veh:sold', src, { plate = plate, bank = ply.bank })
end)

-- ---------------------------------------------------------------------
--  GARAGE — lister / sortir / remiser
-- ---------------------------------------------------------------------
S.onNet('noxa:veh:garage', function(src, ply, garage)
    garage = type(garage) == 'string' and garage or VCFG.defaultGarage
    local owned    = DB.getOwnedVehicles(ply.citizenid, garage)
    local impound  = DB.getImpoundedVehicles(ply.citizenid)
    -- Enrichit chaque ligne avec le label catalogue (affichage).
    local function label(model)
        local v = CFG.VehicleIndex[model]
        return v and v.label or model
    end
    for _, v in ipairs(owned)   do v.label = label(v.model) end
    for _, v in ipairs(impound) do v.label = label(v.model) end
    TriggerClientEvent('noxa:veh:garage', src, {
        garage     = garage,
        vehicles   = owned,
        impound    = impound,
        impoundFee = VCFG.impoundFee,
    })
end)

S.onNet('noxa:veh:takeOut', function(src, ply, plate)
    plate = tostring(plate or '')
    local row = DB.getOwnedVehicleByPlate(plate, ply.citizenid)
    if not row then return S.flag(src, ('veh:takeOut non possédé: %s'):format(plate)) end
    if row.state ~= 'stored' then
        return TriggerClientEvent('noxa:notify', src, 'Ce véhicule n\'est pas remisé.', 'error')
    end
    -- Transition atomique : seule la 1re requête « stored->out » réussit.
    if not DB.setVehicleState(plate, ply.citizenid, 'stored', 'out') then
        return TriggerClientEvent('noxa:notify', src, 'Véhicule déjà sorti.', 'error')
    end
    TriggerClientEvent('noxa:veh:spawn', src, {
        model = row.model, plate = plate,
        fuel  = row.fuel, engine = row.engine, body = row.body,
        mods  = U.jsonDecode(row.mods, {}),
    })
end)

S.onNet('noxa:veh:store', function(src, ply, payload)
    if type(payload) ~= 'table' then return end
    local plate = tostring(payload.plate or '')
    local row = DB.getOwnedVehicleByPlate(plate, ply.citizenid)
    if not row then return S.flag(src, ('veh:store non possédé: %s'):format(plate)) end
    if row.state ~= 'out' then
        return TriggerClientEvent('noxa:notify', src, 'Ce véhicule n\'est pas sorti.', 'error')
    end
    -- Bornage des valeurs client (santé/carburant) avant persistance.
    local fuel   = U.clampInt(payload.fuel, 0, 100) or row.fuel
    local engine = math.max(0.0, math.min(1000.0, tonumber(payload.engine) or row.engine))
    local body   = math.max(0.0, math.min(1000.0, tonumber(payload.body) or row.body))
    local mods   = type(payload.mods) == 'table' and U.jsonEncode(payload.mods) or row.mods
    DB.saveVehicleStatus(plate, ply.citizenid, fuel, engine, body, mods)
    TriggerClientEvent('noxa:notify', src, 'Véhicule remisé.', 'success')
    TriggerClientEvent('noxa:veh:stored', src, { plate = plate })
end)

-- ---------------------------------------------------------------------
--  FOURRIÈRE — récupération contre amende
-- ---------------------------------------------------------------------
S.onNet('noxa:veh:retrieve', function(src, ply, plate)
    if not S.cooldown(src, 'veh:retrieve') then return end
    plate = tostring(plate or '')
    local row = DB.getOwnedVehicleByPlate(plate, ply.citizenid)
    if not row then return S.flag(src, ('veh:retrieve non possédé: %s'):format(plate)) end
    if row.state ~= 'impound' then
        return TriggerClientEvent('noxa:notify', src, 'Ce véhicule n\'est pas en fourrière.', 'error')
    end
    local fee = VCFG.impoundFee
    if ply:getMoney(E.Accounts.BANK) < fee and ply:getMoney(E.Accounts.CASH) < fee then
        return TriggerClientEvent('noxa:notify', src,
            ('Amende de %s requise.'):format(U.money(fee)), 'error')
    end
    -- Préfère la banque, sinon espèces.
    local account = ply:getMoney(E.Accounts.BANK) >= fee and E.Accounts.BANK or E.Accounts.CASH
    if not ply:removeMoney(account, fee, 'vehicle:impound:fee') then
        return TriggerClientEvent('noxa:notify', src, 'Paiement de l\'amende refusé.', 'error')
    end
    -- Atomique : impound -> stored (récupérable ensuite au garage).
    if not DB.setVehicleState(plate, ply.citizenid, 'impound', 'stored') then
        ply:addMoney(account, fee, 'vehicle:impound:rollback')
        return TriggerClientEvent('noxa:notify', src, 'Récupération impossible.', 'error')
    end
    TriggerClientEvent('noxa:notify', src,
        ('Véhicule récupéré (amende %s). Disponible au garage.'):format(U.money(fee)), 'success')
    TriggerClientEvent('noxa:veh:retrieved', src, { plate = plate })
end)

-- ---------------------------------------------------------------------
--  Boot : nettoyage des véhicules « sortis » orphelins -> fourrière.
-- ---------------------------------------------------------------------
CreateThread(function()
    Wait(2000)
    DB.impoundStrandedVehicles()
    U.print('info', 'Véhicules orphelins (sortis) renvoyés en fourrière.')
end)

return Veh
