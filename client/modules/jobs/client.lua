-- =====================================================================
--  NOXA FA — Module Emplois (client-side)
--  Interface légère : prise/fin de service + actions patron.
--  Toute la logique est serveur ; le client ne fait qu'émettre l'intention.
-- =====================================================================

Noxa = Noxa or {}

-- /service : bascule l'état de service (duty).
RegisterCommand('service', function()
    TriggerServerEvent('noxa:job:toggleDuty')
end, false)
lib.addKeybind({
    name = 'noxa_duty', description = 'Prendre/quitter le service',
    defaultKey = 'F6', onReleased = function()
        TriggerServerEvent('noxa:job:toggleDuty')
    end,
})

--- Demande l'ID d'un joueur ciblé via une boîte de saisie ox_lib.
local function askTargetId(title)
    local input = lib.inputDialog(title, {
        { type = 'number', label = 'ID du joueur', required = true, min = 1 },
    })
    return input and tonumber(input[1]) or nil
end

-- /boss : menu patron (visible seulement si le joueur a les droits).
RegisterCommand('boss', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or not data.job.isBoss then
        return Noxa.UI.notify('Vous n\'êtes pas responsable d\'une société.', 'error')
    end

    lib.registerContext({
        id = 'noxa_boss_menu',
        title = ('Gestion — %s'):format(data.job.label or data.job.name),
        options = {
            { title = 'Embaucher', icon = 'user-plus', onSelect = function()
                local id = askTargetId('Embaucher un joueur')
                if id then TriggerServerEvent('noxa:job:hire', id) end
            end },
            { title = 'Promouvoir / rétrograder', icon = 'arrows-up-down', onSelect = function()
                local input = lib.inputDialog('Changer de grade', {
                    { type = 'number', label = 'ID du joueur', required = true, min = 1 },
                    { type = 'number', label = 'Nouveau grade', required = true, min = 0 },
                })
                if input then TriggerServerEvent('noxa:job:setGrade', tonumber(input[1]), tonumber(input[2])) end
            end },
            { title = 'Licencier', icon = 'user-minus', onSelect = function()
                local id = askTargetId('Licencier un joueur')
                if id then TriggerServerEvent('noxa:job:fire', id) end
            end },
            { title = 'Caisse — Déposer', icon = 'arrow-down', onSelect = function()
                local input = lib.inputDialog('Déposer en caisse', {
                    { type = 'number', label = 'Montant', required = true, min = 1 },
                })
                if input then TriggerServerEvent('noxa:job:society:deposit', tonumber(input[1])) end
            end },
            { title = 'Caisse — Retirer', icon = 'arrow-up', onSelect = function()
                local input = lib.inputDialog('Retirer de la caisse', {
                    { type = 'number', label = 'Montant', required = true, min = 1 },
                })
                if input then TriggerServerEvent('noxa:job:society:withdraw', tonumber(input[1])) end
            end },
        },
    })
    lib.showContext('noxa_boss_menu')
end, false)
