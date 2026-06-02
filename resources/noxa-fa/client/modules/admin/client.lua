-- =====================================================================
--  NOXA FA — Module Administration (client-side)
--  Handlers déclenchés UNIQUEMENT par le serveur (jamais par le joueur).
--  Effets locaux : soin, réanimation, téléportation contrôlée serveur.
-- =====================================================================

Noxa = Noxa or {}

-- Soin complet du ped local.
RegisterNetEvent('noxa:admin:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
end)

-- Réanimation (sortie d'état "mort/down" + soin).
RegisterNetEvent('noxa:admin:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedTasksImmediately(ped)
    -- Notifie d'éventuels modules médicaux que le joueur est rétabli.
    TriggerEvent('noxa:client:revived')
end)

-- Téléportation pilotée serveur (goto / bring).
RegisterNetEvent('noxa:admin:teleport', function(pos)
    if type(pos) ~= 'table' or not pos.x then return end
    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
    local timeout = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(25)
    end
end)
