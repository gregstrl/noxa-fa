-- =====================================================================
--  NOXA FA — Heure & Météo serveur (autoritaire)
--  • Horloge unique : le temps en jeu dérive du temps réel écoulé depuis le
--    boot (startHour + elapsed/msPerMinute), modulo 24h. Aucune dérive entre
--    clients : tous interpolent à partir de la même base diffusée.
--  • Météo rotative déterministe (séquence configurée), changée selon un
--    palier de temps réel. Diffusion groupée toutes les `broadcast` ms.
--  • À la connexion, le joueur reçoit immédiatement l'état courant.
-- =====================================================================

Noxa = Noxa or {}
Noxa.WorldTime = {}

local WT  = Noxa.WorldTime
local U   = Noxa.Utils
local CFG = Noxa.Config.World

local startMs       = GetGameTimer()
local weatherIndex  = 1
local weatherSince  = startMs

--- Heure/minute en jeu courantes, dérivées du temps réel écoulé.
local function currentTime()
    local elapsed = GetGameTimer() - startMs
    local total   = math.floor(CFG.startHour * 60 + elapsed / CFG.msPerMinute) % 1440
    return math.floor(total / 60), total % 60
end

--- Fait avancer la météo si le palier de temps est dépassé.
local function tickWeather()
    if GetGameTimer() - weatherSince >= CFG.weatherHold then
        weatherIndex = (weatherIndex % #CFG.weatherCycle) + 1
        weatherSince = GetGameTimer()
    end
end

--- Charge utile diffusée aux clients.
local function payload()
    local h, m = currentTime()
    return {
        hour        = h,
        minute      = m,
        msPerMinute = CFG.msPerMinute,
        weather     = CFG.weatherCycle[weatherIndex],
        transition  = CFG.transition,
    }
end

WT.payload = payload

-- Diffusion périodique (heure + météo) à tous les joueurs.
CreateThread(function()
    while true do
        tickWeather()
        TriggerClientEvent('noxa:world:sync', -1, payload())
        Wait(CFG.broadcast)
    end
end)

-- Synchro immédiate à la connexion d'un personnage.
AddEventHandler('noxa:playerLoaded', function(src)
    TriggerClientEvent('noxa:world:sync', src, payload())
end)

-- Commande admin : forcer une météo (réutilise le contrôle de rang admin si
-- présent ; sinon réservé à la console). Outil de test/event RP.
RegisterCommand('noxa:setweather', function(src, args)
    if src ~= 0 then
        local ply = Noxa.Players and Noxa.Players.get(src)
        local rank = ply and ply.staffRank or 0
        if (tonumber(rank) or 0) < (Noxa.Enums.StaffRanks and Noxa.Enums.StaffRanks.admin or 3) then
            return
        end
    end
    local w = (args[1] or ''):upper()
    for i, t in ipairs(CFG.weatherCycle) do
        if t == w then
            weatherIndex = i; weatherSince = GetGameTimer()
            TriggerClientEvent('noxa:world:sync', -1, payload())
            U.print('info', 'Météo forcée : %s', w)
            return
        end
    end
    print('Météo inconnue. Valeurs : ' .. table.concat(CFG.weatherCycle, ', '))
end, true)

return WT
