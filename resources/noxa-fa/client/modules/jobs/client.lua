-- =====================================================================
--  NOXA FA — Module Emplois (client-side)
--  Prise/fin de service + menu patron 100 % NUI custom (zéro ox_lib).
--  Toute la logique est serveur ; le client n'émet que des intentions.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

-- /service : bascule l'état de service (duty). Keybind natif F6.
RegisterCommand('service', function()
    TriggerServerEvent('noxa:job:toggleDuty')
end, false)
RegisterKeyMapping('service', 'Prendre / quitter le service', 'keyboard', 'F6')

--- Saisie d'un ID de joueur cible via dialogue NUI, puis exécution.
local function askTargetId(title, onValue)
    NUI.input({ title = title, fields = {
        { name = 'id', label = 'ID du joueur', type = 'number', min = 1, required = true },
    } }, function(values)
        local id = values and tonumber(values.id)
        if id then onValue(id) end
    end)
end

-- /boss : menu patron (visible seulement si le joueur a les droits).
RegisterCommand('boss', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or not data.job.isBoss then
        return Noxa.UI.notify('Vous n\'êtes pas responsable d\'une société.', 'error')
    end

    NUI.openMenu({
        title = ('Gestion — %s'):format(data.job.label or data.job.name),
        subtitle = 'Actions de direction',
        options = {
            { id = 'hire',     label = 'Embaucher',                  description = 'Recruter le joueur le plus proche par ID', icon = '➕' },
            { id = 'grade',    label = 'Promouvoir / rétrograder',   description = 'Changer le grade d\'un employé',           icon = '⇅' },
            { id = 'fire',     label = 'Licencier',                  description = 'Renvoyer un employé',                      icon = '➖', danger = true },
            { id = 'deposit',  label = 'Caisse — Déposer',           description = 'Verser de votre banque vers la société',   icon = '⬇' },
            { id = 'withdraw', label = 'Caisse — Retirer',           description = 'Retirer de la caisse vers votre banque',   icon = '⬆' },
        },
    }, function(option)
        if option == 'hire' then
            askTargetId('Embaucher un joueur', function(id) TriggerServerEvent('noxa:job:hire', id) end)
        elseif option == 'fire' then
            askTargetId('Licencier un joueur', function(id) TriggerServerEvent('noxa:job:fire', id) end)
        elseif option == 'grade' then
            NUI.input({ title = 'Changer de grade', fields = {
                { name = 'id', label = 'ID du joueur', type = 'number', min = 1, required = true },
                { name = 'grade', label = 'Nouveau grade', type = 'number', min = 0, required = true },
            } }, function(v)
                if v then TriggerServerEvent('noxa:job:setGrade', tonumber(v.id), tonumber(v.grade)) end
            end)
        elseif option == 'deposit' or option == 'withdraw' then
            NUI.input({ title = option == 'deposit' and 'Déposer en caisse' or 'Retirer de la caisse', fields = {
                { name = 'amount', label = 'Montant', type = 'number', min = 1, required = true },
            } }, function(v)
                if v then TriggerServerEvent('noxa:job:society:' .. option, tonumber(v.amount)) end
            end)
        end
    end)
end, false)
