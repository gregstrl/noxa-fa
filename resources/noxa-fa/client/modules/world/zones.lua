-- =====================================================================
--  NOXA FA — Zones d'interaction de proximité (client-side)
--  ZÉRO ox_lib : détection native par DistanceBetweenCoords, thread 500ms
--  en veille / 0ms quand le joueur est dans une zone. Affiche le prompt NUI
--  « [ E ] <action> » et déclenche l'action du POI sur la touche E (38).
-- =====================================================================

Noxa = Noxa or {}
Noxa.World = {}

local CFG   = Noxa.Config
local NUI   = Noxa.NUI
local World = Noxa.World

local RADIUS = 2.0            -- rayon d'interaction (mètres)
local SCAN_RADIUS = 60.0      -- distance d'activation du scan rapproché

-- Liste plate des points interactifs (pré-calculée au démarrage).
local points = {}             -- { {coords, type, prompt, extra, label} }
local dynamic = {}            -- points enregistrés à chaud (ex: portes immobilier)
local handlers = {}           -- { [type] = fn(point) }
local active = nil            -- point courant sous le prompt
local promptShown = false

--- Enregistre le handler d'un type d'interaction (extensible par module).
---@param itype string
---@param fn fun(point:table)
function World.on(itype, fn)
    handlers[itype] = fn
end

--- Ajoute un point d'interaction dynamique (modules : immobilier, etc.).
--- Retourne une clé permettant un retrait ultérieur.
---@param point { coords:vector3, type:string, prompt:string, key?:any, data?:table }
function World.addPoint(point)
    dynamic[#dynamic + 1] = point
    return #dynamic
end

--- Remplace tous les points dynamiques d'un type donné (ex: refresh biens).
---@param itype string
---@param list table[]
function World.setPoints(itype, list)
    local kept = {}
    for _, p in ipairs(dynamic) do
        if p.type ~= itype then kept[#kept + 1] = p end
    end
    for _, p in ipairs(list) do kept[#kept + 1] = p end
    dynamic = kept
end

--- Construit la liste plate des points depuis C.POI.
local function buildPoints()
    points = {}
    for _, cat in pairs(CFG.POI) do
        local it = cat.interact
        if it and cat.points then
            for _, pt in ipairs(cat.points) do
                points[#points + 1] = {
                    coords = vector3(pt.x + 0.0, pt.y + 0.0, pt.z + 0.0),
                    type   = it.type,
                    prompt = it.prompt or 'Interagir',
                    extra  = it.extra,
                    label  = cat.label,
                }
            end
        end
    end
end

--- Reconstruit la liste plate des POI statiques (config modifiée à chaud).
--- Les points dynamiques (immobilier...) sont préservés.
function World.rebuild()
    buildPoints()
end

local function showPrompt(point)
    if promptShown and active == point then return end
    active = point
    promptShown = true
    NUI.send('world', 'prompt', { show = true, label = point.prompt })
end

local function hidePrompt()
    if not promptShown then return end
    promptShown = false
    active = nil
    NUI.send('world', 'prompt', { show = false })
end

--- Déclenche l'action liée au point courant.
local function trigger(point)
    local fn = handlers[point.type]
    if fn then
        fn(point)
    else
        -- Module non encore implémenté : retour clair au joueur.
        Noxa.UI.notify(('%s — disponible prochainement.'):format(point.label), 'inform')
    end
end

-- ---------------------------------------------------------------------
--  Boucle de proximité
-- ---------------------------------------------------------------------
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    buildPoints()

    while true do
        local wait = 500
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local nearest, nearestDist = nil, RADIUS

        -- Recherche du point le plus proche dans le rayon d'interaction
        -- (POI statiques de config + points dynamiques enregistrés à chaud).
        local function scan(list)
            for _, point in ipairs(list) do
                local d = #(pos - point.coords)
                if d < SCAN_RADIUS then
                    -- À portée de scan : on rapproche le polling (approche du POI)
                    -- sans pour autant tourner chaque frame tant qu'aucun point
                    -- n'est réellement à portée d'interaction.
                    if wait > 200 then wait = 200 end
                    if d < nearestDist then
                        nearest = point
                        nearestDist = d
                    end
                end
            end
        end
        scan(points)
        scan(dynamic)

        if nearest then
            wait = 0   -- point à portée : boucle réactive (prompt + touche E)
            showPrompt(nearest)
            if IsControlJustPressed(0, 38) then  -- touche E
                trigger(nearest)
            end
        else
            hidePrompt()
        end

        Wait(wait)
    end
end)

-- ---------------------------------------------------------------------
--  Handlers intégrés (bank / shop / fuel). Les autres types peuvent être
--  enrichis par leurs modules respectifs via World.on(type, fn).
-- ---------------------------------------------------------------------

-- Banque & distributeurs : réutilise l'ouverture bancaire guardée (module banque)
-- pour partager le même verrou de focus (anti double-ouverture / curseur bloqué).
World.on('bank', function()
    if Noxa.Banking and Noxa.Banking.open then Noxa.Banking.open() end
end)

-- Épicerie : ouvre le menu MenuV de la boutique (catalogue servi par la
-- config partagée). L'achat est validé et débité côté serveur.
World.on('shop', function(point)
    local shop = CFG.Shops[point.extra or 'grocery']
    if not shop then return end
    Noxa.Shop.open(point.extra or 'grocery', shop.label, shop.items)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then hidePrompt() end
end)
