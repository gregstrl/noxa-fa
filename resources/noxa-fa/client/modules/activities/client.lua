-- =====================================================================
--  NOXA FA — Activités légales (client-side) : pêche & chasse.
--  Présentation 100 % MenuV aux POI (cf. C.POI : type 'fishing'/'hunting').
--  Le client joue l'animation de cueillette puis émet l'intention au
--  serveur ; achat d'outil, butin et vente restent autoritaires serveur.
-- =====================================================================

Noxa = Noxa or {}
Noxa.ActivitiesClient = {}

local CFG   = Noxa.Config
local ACFG  = Noxa.Config.Activities
local World = Noxa.World
local money = Noxa.Utils.money

local menus = {}   -- [key] = menu MenuV
local busy  = false

-- ---------------------------------------------------------------------
--  Action chronométrée (animation propre à l'activité) puis callback.
-- ---------------------------------------------------------------------
local function timedAction(a, label, onDone)
    if busy then return end
    busy = true
    Noxa.UI.notify(label .. '…', 'inform')

    local anim = a.anim or {}
    if anim.dict then
        RequestAnimDict(anim.dict)
        local t = GetGameTimer() + 1500
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(10) end
    end

    local ped = PlayerPedId()
    if anim.dict and HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, a.gatherTime, 1, 0, false, false, false)
    end

    local deadline = GetGameTimer() + a.gatherTime
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
--  Menu d'activité : acheter l'outil · pratiquer · vendre le butin.
-- ---------------------------------------------------------------------
local function openActivity(key)
    local a = ACFG[key]
    if not a then return end
    local menu = menus[key]
    if not menu then
        menu = MenuV:CreateMenu(a.label, 'Activité', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_act_' .. key)

        menu:AddButton({
            icon = '🎯', label = a.label,
            description = 'Pratiquer l\'activité (outil requis)',
            select = function()
                MenuV:CloseAll()
                timedAction(a, a.label .. ' en cours', function()
                    TriggerServerEvent('noxa:act:gather', key)
                end)
            end,
        })
        menu:AddButton({
            icon = '💰', label = 'Vendre le butin',
            description = 'Écouler poissons / gibier sur place',
            select = function()
                MenuV:CloseAll()
                TriggerServerEvent('noxa:act:sell', key)
            end,
        })
        local tool = CFG.getItem(a.tool)
        menu:AddButton({
            icon = '🛒', label = ('Acheter : %s'):format(tool and tool.label or a.tool),
            description = ('Prix : %s'):format(money(a.toolPrice)),
            select = function()
                TriggerServerEvent('noxa:act:buyTool', key)
            end,
        })
        menus[key] = menu
    end
    MenuV:OpenMenu(menu)
end

World.on('fishing', function() openActivity('fishing') end)
World.on('hunting', function() openActivity('hunting') end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then MenuV:CloseAll() end
end)

return Noxa.ActivitiesClient
