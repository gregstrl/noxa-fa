-- =====================================================================
--  NOXA FA — Synchronisation Heure & Météo (client-side)
--  Reçoit l'état autoritaire du serveur (toutes les 30s + à la connexion) et :
--    • interpole l'heure localement chaque seconde (cycle jour/nuit fluide) ;
--    • applique et VERROUILLE la météo (aucun cycle aléatoire GTA).
--  Aucune confiance : le serveur fait foi ; le client ne fait qu'afficher.
-- =====================================================================

Noxa = Noxa or {}

-- Base de référence reçue du serveur (point d'interpolation).
local base = { hour = 8, minute = 0, ms = GetGameTimer(), msPerMinute = 2000 }
local weather = nil
local synced  = false

RegisterNetEvent('noxa:world:sync', function(d)
    if type(d) ~= 'table' then return end
    base.hour        = tonumber(d.hour) or base.hour
    base.minute      = tonumber(d.minute) or base.minute
    base.msPerMinute = tonumber(d.msPerMinute) or base.msPerMinute
    base.ms          = GetGameTimer()
    synced = true

    if d.weather and d.weather ~= weather then
        weather = d.weather
        -- Transition douce + persistance (empêche le moteur de reprendre la main).
        SetWeatherTypeOvertimePersist(weather, (tonumber(d.transition) or 15) + 0.0)
    end
end)

-- Interpolation de l'heure (cycle fluide entre deux synchros serveur).
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    while true do
        if synced then
            local elapsed = GetGameTimer() - base.ms
            local add     = math.floor(elapsed / base.msPerMinute)
            local total   = (base.hour * 60 + base.minute + add) % 1440
            NetworkOverrideClockTime(math.floor(total / 60), total % 60, 0)
        end
        Wait(1000)
    end
end)

-- Verrou météo : réaffirme périodiquement le type courant (anti-reprise GTA).
CreateThread(function()
    while true do
        Wait(30000)
        if weather then
            SetWeatherTypePersist(weather)
            SetWeatherTypeNow(weather)
            SetOverrideWeather(weather)
        end
    end
end)
