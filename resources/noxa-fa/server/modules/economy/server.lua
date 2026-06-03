-- =====================================================================
--  NOXA FA — Module Économie (server-side)
--  • API monétaire exportée (add/remove/get/transfer) pour les modules.
--  • PUITS anti-inflation : TVA sur consommables, amendes, loyers, entretien.
--  • Catalogue véhicules : prix autoritaire (concession) + surtaxe luxe.
--  • Aucune confiance dans le client : tout transite par la classe Player.
--    Toutes les recettes fiscales sont versées au Trésor Public (state).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Economy = {}

local Eco = Noxa.Economy
local U   = Noxa.Utils
local E   = Noxa.Enums
local DB  = Noxa.DB
local Soc = Noxa.Societies
local CFG = Noxa.Config
local ECO = CFG.Economy          -- doctrine économique (shared/economy/*)

-- ---------------------------------------------------------------------
--  API serveur (utilisable par d'autres modules via exports)
-- ---------------------------------------------------------------------

---@param src integer
---@param account string cash|bank
---@param amount integer
---@param reason? string
---@return boolean
function Eco.add(src, account, amount, reason)
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    return ply:addMoney(account, amount, reason)
end

---@return boolean
function Eco.remove(src, account, amount, reason)
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    return ply:removeMoney(account, amount, reason)
end

---@return integer
function Eco.get(src, account)
    local ply = Noxa.Players.get(src)
    if not ply then return 0 end
    return ply:getMoney(account)
end

--- Transfert sécurisé entre deux joueurs (banque -> banque).
---@return boolean
function Eco.transfer(srcFrom, srcTo, amount, reason)
    amount = U.sanitizeAmount(amount)
    if not amount then return false end
    local from = Noxa.Players.get(srcFrom)
    local to   = Noxa.Players.get(srcTo)
    if not from or not to then return false end
    if not from:removeMoney(E.Accounts.BANK, amount, reason or 'transfer-out') then
        return false
    end
    to:addMoney(E.Accounts.BANK, amount, reason or 'transfer-in')
    return true
end

-- ---------------------------------------------------------------------
--  PUITS #1 — Achat taxé (TVA). Le joueur paie `base` (prix TTC affiché) ;
--  la part de taxe est versée au Trésor Public, le reste sort de la masse
--  monétaire (sink). Utilisé par l'épicerie et la station essence.
-- ---------------------------------------------------------------------

--- Calcule la part de taxe d'un montant.
---@param base integer
---@param rate? number défaut : TVA (Tax.sales)
---@return integer
function Eco.taxOf(base, rate)
    -- Bascule live (panel gestion serveur) : taxes désactivables sans restart.
    if Noxa.Config.Systems and Noxa.Config.Systems.economyTax == false then return 0 end
    rate = rate or ECO.Tax.sales
    return math.floor((tonumber(base) or 0) * rate)
end

--- Débite un achat (espèces ou banque) et reverse la taxe au Trésor.
---@param src integer
---@param account string
---@param base integer prix payé par le joueur (TTC)
---@param reason string
---@param rate? number taux de taxe (défaut TVA)
---@return boolean ok
function Eco.chargeWithTax(src, account, base, reason, rate)
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    base = U.sanitizeAmount(base)
    if not base then return false end
    if not ply:removeMoney(account, base, reason) then return false end
    local tax = Eco.taxOf(base, rate)
    if tax > 0 and Soc.exists(ECO.treasury) then
        Soc.add(ECO.treasury, tax, ply.citizenid, 'tax:' .. reason)
    end
    return true
end

-- ---------------------------------------------------------------------
--  PUITS #2 — Amendes (police). Barème borné, versé au Trésor Public.
--  Débite la banque en priorité (argent tracé), puis les espèces.
-- ---------------------------------------------------------------------

--- Inflige une amende à un joueur. `key` = clé de barème OU montant libre.
---@param src integer cible
---@param key string|integer clé Fines OU montant brut
---@param officerCid? string agent émetteur (audit)
---@return boolean ok, integer amount
function Eco.fine(src, key, officerCid)
    local ply = Noxa.Players.get(src)
    if not ply then return false, 0 end

    local amount, label
    local preset = type(key) == 'string' and ECO.Fines[key] or nil
    if preset then
        amount, label = preset.amount, preset.label
    else
        amount = U.sanitizeAmount(key)
        label  = 'Amende'
    end
    if not amount then return false, 0 end
    amount = math.min(amount, ECO.Fines._max)   -- borne anti-abus

    -- Banque d'abord, puis espèces (le citoyen DOIT payer la loi).
    local account = E.Accounts.BANK
    if not ply:removeMoney(account, amount, 'fine:' .. tostring(key)) then
        account = E.Accounts.CASH
        if not ply:removeMoney(account, amount, 'fine:' .. tostring(key)) then
            TriggerClientEvent('noxa:notify', src, 'Amende impayée : fonds insuffisants.', 'error')
            return false, amount
        end
    end
    if Soc.exists(ECO.treasury) then
        Soc.add(ECO.treasury, amount, officerCid, 'fine:' .. tostring(key))
    end
    TriggerClientEvent('noxa:notify', src,
        ('Amende : %s (%s)'):format(U.money(amount), label), 'warning')
    return true, amount
end

-- ---------------------------------------------------------------------
--  Catalogue véhicules — prix autoritaire (concession). La surtaxe « luxe »
--  s'ajoute au prix catalogue et part au Trésor Public.
-- ---------------------------------------------------------------------

--- Prix catalogue d'un modèle (sans taxe). nil si hors catalogue.
function Eco.vehiclePrice(spawn)
    return CFG.getVehiclePrice(spawn)
end

--- Prix total à payer (catalogue + surtaxe luxe).
---@return integer|nil total, integer|nil base, integer|nil tax
function Eco.vehicleTotal(spawn)
    local base = CFG.getVehiclePrice(spawn)
    if not base then return nil end
    local tax = Eco.taxOf(base, ECO.Tax.luxury)
    return base + tax, base, tax
end

-- ---------------------------------------------------------------------
--  PUITS #3 — Cycle d'entretien (loyers + maintenance véhicules).
--  Débité aux propriétaires EN LIGNE, toutes les `Upkeep.interval`.
--  Banque d'abord, sinon espèces. Recette versée au Trésor Public.
-- ---------------------------------------------------------------------

local function chargeUpkeep(ply)
    if not (ply and ply.citizenid) then return end
    local up = ECO.Upkeep

    -- Loyers (somme des biens possédés, par palier).
    local rent = 0
    for _, row in ipairs(DB.getOwnedPropertyTiers(ply.citizenid)) do
        rent = rent + (up.rent[row.tier] or 0)
    end
    -- Entretien (par véhicule possédé).
    local vehicles = DB.countOwnedVehicles(ply.citizenid)
    local maint = vehicles * up.maintenancePerVehicle

    local total = rent + maint
    if total <= 0 then return end

    local account = E.Accounts.BANK
    local paid = ply:removeMoney(account, total, 'upkeep')
    if not paid then
        account = E.Accounts.CASH
        paid = ply:removeMoney(account, total, 'upkeep')
    end

    if paid then
        if Soc.exists(ECO.treasury) then
            Soc.add(ECO.treasury, total, ply.citizenid, 'upkeep')
        end
        TriggerClientEvent('noxa:notify', ply.source,
            ('Charges réglées : %s (loyer %s · entretien %s)')
                :format(U.money(total), U.money(rent), U.money(maint)), 'inform')
    else
        -- Insolvable : on n'endette pas (pas de solde négatif), on alerte.
        -- Un futur système de saisie pourra s'appuyer sur cet état.
        TriggerClientEvent('noxa:notify', ply.source,
            ('Charges impayées : %s. Régularisez vos comptes.'):format(U.money(total)), 'error')
    end
end

CreateThread(function()
    while true do
        Wait(ECO.Upkeep.interval)
        -- Bascule live : entretien/loyers suspendus si les taxes sont coupées.
        if Noxa.Config.Systems and Noxa.Config.Systems.economyTax == false then goto skipUpkeep end
        local players = Noxa.Players.getAll and Noxa.Players.getAll() or {}
        local n = 0
        for _, ply in pairs(players) do
            chargeUpkeep(ply)
            n = n + 1
        end
        if n > 0 then U.debug('Cycle d\'entretien appliqué à %d joueur(s).', n) end
        ::skipUpkeep::
    end
end)

-- ---------------------------------------------------------------------
--  Exports pour interopérabilité inter-ressources
-- ---------------------------------------------------------------------
exports('AddMoney',        Eco.add)
exports('RemoveMoney',     Eco.remove)
exports('GetMoney',        Eco.get)
exports('TransferMoney',   Eco.transfer)
exports('ChargeWithTax',   Eco.chargeWithTax)
exports('Fine',            Eco.fine)
exports('GetVehiclePrice', Eco.vehiclePrice)
exports('GetVehicleTotal', Eco.vehicleTotal)

-- Note : la paie automatique des salaires est gérée par le module Emplois
-- (server/modules/jobs/server.lua), prélevée sur les caisses société. Le
-- module Économie fournit ici les primitives monétaires et les PUITS.

-- ---------------------------------------------------------------------
--  Self-checks de cohérence économique (debug uniquement)
-- ---------------------------------------------------------------------
CreateThread(function()
    Wait(2000)   -- laisse enums + sociétés finir de charger
    if ECO.audit then ECO.audit() end
    if ECO.checkVehicles then ECO.checkVehicles() end
end)

return Eco
