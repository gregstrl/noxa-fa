-- =====================================================================
--  NOXA FA — Gestion du spawn client
--  Le serveur reste autoritaire : le client se contente d'appliquer la
--  position renvoyée après sélection du personnage.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Spawn = {}

local Spawn = Noxa.Spawn

--- Téléporte et fait apparaître le joueur à une position donnée.
---@param pos { x:number, y:number, z:number, heading?:number }
function Spawn.toPosition(pos)
    local ped = PlayerPedId()
    if not pos then return end
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false)
    SetEntityHeading(ped, pos.heading or 0.0)
    -- Attendre le chargement du monde autour du joueur
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(50)
    end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.heading or 0.0, true, false)
    ClearPedTasksImmediately(ped)
end

--- Prépare l'écran : masque le joueur et le fige le temps de la sélection.
function Spawn.prepareSelection()
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerControl(PlayerId(), false, 0)
    DoScreenFadeOut(0)
end

--- Rend la main au joueur après spawn complet.
function Spawn.release()
    SetPlayerControl(PlayerId(), true, 0)
    DoScreenFadeIn(800)
end
