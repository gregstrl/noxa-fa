-- =====================================================================
--  NOXA FA — Safezones (zones de paix, client-side)
--  Détection de proximité native (ZÉRO ox_lib). À l'intérieur d'une zone :
--    • noDamage  : invincibilité locale (le joueur ne subit aucun dégât) ;
--    • noWeapons : tir bloqué chaque frame + arme rangée (mains nues).
--  Invariant de sûreté : QUEL QUE SOIT le chemin de sortie (zone quittée,
--  zone désactivée à chaud, resource stop), l'état joueur est TOUJOURS
--  restauré (dégât réactivé, contrôles d'arme rendus). On ne laisse jamais
--  un joueur invincible hors zone.
-- =====================================================================

Noxa = Noxa or {}

local CFG = Noxa.Config

-- Pas de zone configurée -> module inerte (aucun thread inutile).
if not CFG.Safezones or #CFG.Safezones == 0 then return end

local SCAN_RADIUS = 100.0   -- distance d'activation du polling rapproché
local current = nil         -- zone courante (nil = hors zone)

--- Le système est-il actif ? (bascule live serveur, parité avec les autres modules)
local function enabled()
    return not (CFG.Systems and CFG.Systems.safezones == false)
end

--- Restaure l'état « jouable normal » du ped (idempotent : sans effet hors zone).
local function restore(ped)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    SetCanAttackFriendly(ped, true, true)
end

--- Applique les protections d'une zone sur le ped (appelé chaque frame à l'intérieur).
local function applyZone(ped, zone)
    if zone.noDamage then
        SetEntityInvincible(ped, true)
        SetPlayerInvincible(PlayerId(), true)
    end
    if zone.noWeapons then
        -- Range l'arme (retour mains nues) puis bloque le tir cette frame.
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)  -- attaque
        DisableControlAction(0, 25, true)  -- visée
        DisableControlAction(0, 47, true)  -- arme (G)
        DisableControlAction(0, 58, true)  -- arme (G véhicule)
        DisableControlAction(0, 140, true) -- mêlée légère
        DisableControlAction(0, 141, true) -- mêlée lourde
        DisableControlAction(0, 142, true) -- mêlée alternative
        DisableControlAction(0, 257, true) -- attaque 2
        DisableControlAction(0, 263, true) -- mêlée bloc
        local _, weapon = GetCurrentPedWeapon(ped, true)
        if weapon and weapon ~= `WEAPON_UNARMED` then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
    end
end

--- Trouve la zone contenant le joueur (ou nil), et la distance min utile au scan.
local function findZone(pos)
    for _, z in ipairs(CFG.Safezones) do
        if #(pos - z.coords) <= z.radius then return z end
    end
    return nil
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end

    while true do
        local wait = 1000
        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)

        if not enabled() then
            -- Système coupé à chaud : on libère proprement si on était dedans.
            if current then
                restore(ped)
                Noxa.UI.notify('Zones de paix désactivées.', 'inform')
                current = nil
            end
        else
            -- Pré-filtre : sommes-nous à portée d'au moins une zone ?
            local near = false
            for _, z in ipairs(CFG.Safezones) do
                if #(pos - z.coords) < SCAN_RADIUS then near = true break end
            end

            if near then
                local zone = findZone(pos)
                if zone then
                    wait = 0  -- à l'intérieur : boucle réactive (blocage tir par frame)
                    if current ~= zone then
                        current = zone
                        Noxa.UI.notify(
                            ('Zone sûre : %s. Armes et dégâts neutralisés.'):format(zone.label),
                            'success')
                    end
                    applyZone(ped, zone)
                else
                    wait = 200  -- proche mais pas dedans : polling resserré
                    if current then
                        restore(ped)
                        Noxa.UI.notify('Vous quittez la zone sûre.', 'inform')
                        current = nil
                    end
                end
            elseif current then
                -- Sorti d'un coup (TP) hors du rayon de scan : sécurité.
                restore(ped)
                Noxa.UI.notify('Vous quittez la zone sûre.', 'inform')
                current = nil
            end
        end

        Wait(wait)
    end
end)

-- Filet de sécurité : ne JAMAIS laisser un joueur invincible si la ressource
-- s'arrête alors qu'il est dans une zone.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and current then
        restore(PlayerPedId())
        current = nil
    end
end)
