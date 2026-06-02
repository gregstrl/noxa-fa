-- =====================================================================
--  NOXA FA — Module HUD (client-side)
--  Alimente l'interface HUD NUI : argent/identité/emploi (statebag serveur)
--  + santé/armure (lues nativement) + besoins (métadonnées répliquées).
--  Purement informatif : aucune donnée n'est autoritaire ici.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI
local CFG = Noxa.Config.Needs

-- Compose et pousse l'instantané HUD vers la NUI.
local function pushHud()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data then return end
    local ped = PlayerPedId()
    local m = data.metadata or {}
    NUI.send('hud', 'update', {
        name      = data.name,
        citizenid = data.citizenid,
        job       = data.job,
        cash      = data.cash,
        bank      = data.bank,
        needs = {
            health = GetEntityHealth(ped),      -- 0..200 (converti en % côté NUI)
            armor  = GetPedArmour(ped),         -- 0..100
            hunger = m.hunger or 100,
            thirst = m.thirst or 100,
            stress = m.stress or 0,
        },
    })
end

-- Mise à jour immédiate quand l'état joueur change (argent, job, besoins).
AddEventHandler('noxa:client:playerDataUpdated', pushHud)

-- Rafraîchissement régulier pour la santé/armure (valeurs natives temps réel).
CreateThread(function()
    while true do
        Wait(CFG.syncInterval)
        if Noxa.GetPlayerData and Noxa.GetPlayerData() then pushHud() end
    end
end)

-- Dégâts de famine / déshydratation infligés par le serveur (autoritaire).
RegisterNetEvent('noxa:needs:damage', function(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    if hp > 100 then  -- ne tue pas directement : plancher de sécurité
        SetEntityHealth(ped, math.max(101, hp - amount))
    end
end)
