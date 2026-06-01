-- =====================================================================
--  NOXA FA — Point d'entrée client
--  • Initialise la phase de sélection au spawn
--  • Maintient un miroir local lecture-seule de l'état joueur (statebag)
--  • Expose une API client (GetPlayerData)
-- =====================================================================

Noxa = Noxa or {}

-- Miroir local des données joueur (synchronisées par le serveur, lecture seule)
local playerData = nil

--- Accès lecture seule aux données joueur côté client.
function Noxa.GetPlayerData()
    return playerData
end

-- Écoute les mises à jour du statebag répliqué par le serveur.
AddStateBagChangeHandler('noxa:player', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value then
        playerData = value
        TriggerEvent('noxa:client:playerDataUpdated', value)
    end
end)

-- ---------------------------------------------------------------------
--  Démarrage du client : préparer l'écran et lancer la sélection
-- ---------------------------------------------------------------------

CreateThread(function()
    -- Attendre que la session soit active (joueur réellement en partie)
    while not NetworkIsSessionStarted() do Wait(100) end

    Noxa.Spawn.prepareSelection()

    -- Laisser le temps au framework serveur de préparer le compte
    Wait(500)
    Noxa.Characters.requestList()
end)

exports('GetPlayerData', Noxa.GetPlayerData)
