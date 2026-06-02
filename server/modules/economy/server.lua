-- =====================================================================
--  NOXA FA — Module Économie (server-side)
--  • API serveur exportée pour les autres ressources/modules
--  • Versement automatique des salaires (paie)
--  • Aucune confiance dans le client : tout transite par la classe Player
-- =====================================================================

Noxa = Noxa or {}
Noxa.Economy = {}

local Eco = Noxa.Economy
local U   = Noxa.Utils
local E   = Noxa.Enums
local CFG = Noxa.Config

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

-- Exports pour interopérabilité inter-ressources
exports('AddMoney',      Eco.add)
exports('RemoveMoney',   Eco.remove)
exports('GetMoney',      Eco.get)
exports('TransferMoney', Eco.transfer)

-- Note : la paie automatique des salaires est gérée par le module Emplois
-- (server/modules/jobs/server.lua), où elle est prélevée sur les caisses
-- société. L'économie ne fournit ici que les primitives monétaires.

return Eco
