-- =====================================================================
--  NOXA FA — Gestion du spawn client
--  Le serveur reste autoritaire : le client se contente d'appliquer la
--  position renvoyée après sélection du personnage.
--  Invariant de sûreté : quel que soit le chemin (position nil, collision
--  non chargée, timeout), le joueur RÉCUPÈRE TOUJOURS le contrôle, la
--  visibilité et le dégel. Un spawn ne doit jamais laisser un ped figé.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Spawn = {}

local Spawn = Noxa.Spawn

-- Position de repli si le serveur n'envoie aucune coordonnée valable.
local FALLBACK = { x = -1037.0, y = -2738.0, z = 20.16, heading = 328.0 }

--- Garantit que le ped est jouable : dégelé, visible, collisionné, libre.
--- Idempotent : peut être appelé plusieurs fois sans effet de bord.
---@param ped integer
local function ensurePlayable(ped)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetPlayerControl(PlayerId(), true, 0)
    ClearPedTasksImmediately(ped)
end

--- Téléporte et fait apparaître le joueur à une position donnée.
--- Tolère une position absente ou partielle (repli sur FALLBACK).
---@param pos { x:number, y:number, z:number, heading?:number }|nil
function Spawn.toPosition(pos)
    local ped = PlayerPedId()
    -- Position invalide -> repli (on NE retourne JAMAIS sans rendre la main).
    if type(pos) ~= 'table' or not (pos.x and pos.y and pos.z) then
        pos = FALLBACK
    end
    local x, y, z = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0
    local heading = (pos.heading or 0.0) + 0.0

    -- Précharge la collision autour du point cible AVANT téléportation.
    RequestCollisionAtCoord(x, y, z)
    NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)

    -- Attendre le chargement du monde autour du joueur (borné : anti-blocage).
    local timeout = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    ensurePlayable(ped)
end

--- Prépare l'écran : masque le joueur et le fige le temps de la sélection.
function Spawn.prepareSelection()
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerControl(PlayerId(), false, 0)
    SetEntityCollision(ped, false, false)
    DoScreenFadeOut(0)
end

--- Rend la main au joueur après spawn complet (sécurité : double dégel).
function Spawn.release()
    ensurePlayable(PlayerPedId())
    if not IsScreenFadedIn() then
        DoScreenFadeIn(800)
    end
end
