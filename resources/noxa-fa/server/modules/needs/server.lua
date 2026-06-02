-- =====================================================================
--  NOXA FA — Module Besoins vitaux (server-side, autoritaire)
--  • Décroissance périodique de la faim et de la soif (jamais côté client).
--  • Le stress redescend naturellement au repos.
--  • À 0 de faim OU de soif : dégâts de santé infligés (event client).
--  • API exportée pour modifier les besoins (consommation d'items à venir).
--  Les valeurs vivent dans player.metadata et sont répliquées via syncState.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Needs = {}

local Needs = Noxa.Needs
local U     = Noxa.Utils
local CFG   = Noxa.Config.Needs

-- ---------------------------------------------------------------------
--  Mutations bornées d'un besoin
-- ---------------------------------------------------------------------

--- Ajuste un besoin (hunger|thirst|stress) en le bornant sur [0,100].
---@param ply table objet Player
---@param key string
---@param delta integer (peut être négatif)
function Needs.modify(ply, key, delta)
    if not ply then return end
    local cur = tonumber(ply.metadata[key]) or 100
    ply.metadata[key] = U.clampInt(cur + delta, 0, 100)
    ply:syncState()
end

--- Définit une valeur absolue bornée (consommation : manger/boire).
function Needs.set(ply, key, value)
    if not ply then return end
    ply.metadata[key] = U.clampInt(value, 0, 100)
    ply:syncState()
end

-- Exports inter-ressources (items de nourriture, drogues, activités...).
exports('AddNeed',    function(src, key, delta) Needs.modify(Noxa.Players.get(src), key, delta) end)
exports('SetNeed',    function(src, key, value) Needs.set(Noxa.Players.get(src), key, value) end)
exports('GetNeed',    function(src, key)
    local ply = Noxa.Players.get(src)
    return ply and (tonumber(ply.metadata[key]) or 100) or 0
end)

-- ---------------------------------------------------------------------
--  Boucle de décroissance (faim, soif, stress) + effets
-- ---------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(CFG.decayInterval)
        for _, ply in pairs(Noxa.Players.getAll()) do
            local m = ply.metadata
            m.hunger = U.clampInt((tonumber(m.hunger) or 100) - CFG.hungerRate, 0, 100)
            m.thirst = U.clampInt((tonumber(m.thirst) or 100) - CFG.thirstRate, 0, 100)
            -- Le stress redescend naturellement (l'augmentation vient d'activités).
            m.stress = U.clampInt((tonumber(m.stress) or 0) - CFG.stressDecay, 0, 100)

            -- Famine / déshydratation : dégâts de santé infligés client-side.
            if m.hunger <= 0 or m.thirst <= 0 then
                TriggerClientEvent('noxa:needs:damage', ply.source, CFG.damageOnEmpty)
            end
            ply:syncState()
        end
    end
end)

return Needs
