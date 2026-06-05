-- =====================================================================
--  NOXA FA — Trafic de drogue (client-side) : présentation MenuV + anim.
--  Le client ne détient AUCUNE vérité : il ouvre les menus MenuV aux POI
--  (récolte / labo / revendeur), joue une animation de cueillette puis
--  émet une simple intention au serveur (clé de drogue). Quantités, prix,
--  cooldowns et proximité sont (re)vérifiés côté serveur.
-- =====================================================================

Noxa = Noxa or {}
Noxa.DrugsClient = {}

local CFG   = Noxa.Config
local DCFG  = Noxa.Config.Drugs
local World = Noxa.World

-- Animation générique de cueillette/travail (ambiante, toujours dispo).
local WORK_ANIM = { dict = 'amb@world_human_gardener_plant@male@idle_a', name = 'idle_a' }

-- Menus MenuV créés à la demande, puis réutilisés.
local harvestMenus = {}   -- [drugKey] = menu
local processMenus = {}   -- [drugKey] = menu
local sellMenu     = nil

-- ---------------------------------------------------------------------
--  Action chronométrée : joue une animation pendant `ms`, puis callback.
--  Annulable en bougeant (le serveur reste seul juge du résultat).
-- ---------------------------------------------------------------------
local busy = false
local function timedAction(ms, label, onDone)
    if busy then return end
    busy = true
    Noxa.UI.notify(label .. '…', 'inform')

    RequestAnimDict(WORK_ANIM.dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(WORK_ANIM.dict) and GetGameTimer() < t do Wait(10) end

    local ped = PlayerPedId()
    if HasAnimDictLoaded(WORK_ANIM.dict) then
        TaskPlayAnim(ped, WORK_ANIM.dict, WORK_ANIM.name, 4.0, -4.0, ms, 1, 0, false, false, false)
    end

    local deadline = GetGameTimer() + ms
    local startPos = GetEntityCoords(ped)
    local cancelled = false
    while GetGameTimer() < deadline do
        Wait(150)
        if #(GetEntityCoords(PlayerPedId()) - startPos) > 2.5 then
            cancelled = true
            break
        end
    end

    ClearPedTasks(PlayerPedId())
    busy = false
    if cancelled then
        Noxa.UI.notify('Action interrompue.', 'error')
    else
        onDone()
    end
end

-- ---------------------------------------------------------------------
--  RÉCOLTE — menu au champ/dépôt (un par drogue).
-- ---------------------------------------------------------------------
local function openHarvest(key)
    local d = DCFG.types[key]
    if not d then return end
    local menu = harvestMenus[key]
    if not menu then
        menu = MenuV:CreateMenu(d.label, 'Récolte', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_drug_h_' .. key)
        menu:AddButton({
            icon = '🌿', label = ('Récolter (%s)'):format(d.label),
            description = 'Cueillir la matière première',
            select = function()
                MenuV:CloseAll()
                timedAction(d.harvest.time, 'Récolte en cours', function()
                    TriggerServerEvent('noxa:drug:harvest', key)
                end)
            end,
        })
        harvestMenus[key] = menu
    end
    MenuV:OpenMenu(menu)
end

-- ---------------------------------------------------------------------
--  TRANSFORMATION — menu au labo (un par drogue).
-- ---------------------------------------------------------------------
local function openProcess(key)
    local d = DCFG.types[key]
    if not d then return end
    local menu = processMenus[key]
    if not menu then
        menu = MenuV:CreateMenu(d.label, 'Transformation', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_drug_p_' .. key)
        menu:AddButton({
            icon = '⚗️', label = ('Conditionner (%s)'):format(d.label),
            description = ('%dx matière → %dx produit fini'):format(d.process.need, d.process.give),
            select = function()
                MenuV:CloseAll()
                timedAction(d.process.time, 'Transformation en cours', function()
                    TriggerServerEvent('noxa:drug:process', key)
                end)
            end,
        })
        processMenus[key] = menu
    end
    MenuV:OpenMenu(menu)
end

-- ---------------------------------------------------------------------
--  VENTE — menu au revendeur (tous produits confondus).
-- ---------------------------------------------------------------------
local function openSell()
    if not sellMenu then
        sellMenu = MenuV:CreateMenu('Revendeur', 'Marché noir', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_drug_sell')
        sellMenu:AddButton({
            icon = '💵', label = 'Écouler la marchandise',
            description = 'Vendre vos produits (prix au cours du jour)',
            select = function()
                MenuV:CloseAll()
                TriggerServerEvent('noxa:drug:sell')
            end,
        })
    end
    MenuV:OpenMenu(sellMenu)
end

-- ---------------------------------------------------------------------
--  Branchement sur les zones de proximité (prompt « [E] » -> menu MenuV).
-- ---------------------------------------------------------------------
World.on('drug_harvest', function(point)
    openHarvest(point.extra)
end)
World.on('drug_process', function(point)
    openProcess(point.extra)
end)
World.on('drug_sell', function()
    openSell()
end)

-- ---------------------------------------------------------------------
--  Dispatch police : un GPS éphémère pointe la zone de vente signalée.
-- ---------------------------------------------------------------------
RegisterNetEvent('noxa:drug:dispatch', function(pos)
    if type(pos) ~= 'table' or not pos.x then return end
    local blip = AddBlipForCoord(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Trafic signalé')
    EndTextCommandSetBlipName(blip)
    SetNewWaypoint(pos.x + 0.0, pos.y + 0.0)
    -- Disparition automatique après 90s (piste qui refroidit).
    SetTimeout(90000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then MenuV:CloseAll() end
end)

return Noxa.DrugsClient
