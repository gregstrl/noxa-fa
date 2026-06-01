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

-- ---------------------------------------------------------------------
--  Paie automatique des salaires (versée en banque)
-- ---------------------------------------------------------------------

-- Intervalle de paie : toutes les 30 minutes de jeu.
local PAY_INTERVAL = 30 * 60 * 1000

CreateThread(function()
    while true do
        Wait(PAY_INTERVAL)
        local paid = 0
        for src, ply in pairs(Noxa.Players.getAll()) do
            local salary = ply:getJobSalary()
            if salary and salary > 0 then
                ply:addMoney(E.Accounts.BANK, salary, 'salary:' .. ply.job)
                paid = paid + 1
            end
        end
        if paid > 0 then
            U.print('info', 'Paie versée à %d joueur(s).', paid)
        end
    end
end)

return Eco
