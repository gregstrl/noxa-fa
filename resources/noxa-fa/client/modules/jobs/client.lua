-- =====================================================================
--  NOXA FA — Module Emplois (client-side)
--  Prise/fin de service + menu patron (MenuV). Les saisies numériques
--  (ID joueur, grade, montant) restent des dialogues NUI : MenuV n'offre
--  pas de champ de saisie libre. Toute la logique est serveur ; le client
--  n'émet que des intentions.
-- =====================================================================

Noxa = Noxa or {}
local NUI = Noxa.NUI

-- Menu patron MenuV (créé à la demande, réutilisé ensuite).
local bossMenu = nil

-- Panneau NUI partagé des jobs actifs (MDT police, atelier méca, fouille).
-- Fermeture pilotée par le système anti-superposition (ouverture d'un autre panneau).
NUI.registerPanel('jobs', function()
    NUI.send('jobs', 'close', {})
end)

RegisterNUICallback('jobsClose', function(_, cb)
    if NUI.activePanel == 'jobs' then
        NUI.closePanel('jobs')
        NUI.setFocus(false)
    end
    cb('ok')
end)

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

--- Saisie d'un montant de caisse (dépôt / retrait) via dialogue NUI.
local function askAmount(action)
    NUI.input({ title = action == 'deposit' and 'Déposer en caisse' or 'Retirer de la caisse', fields = {
        { name = 'amount', label = 'Montant', type = 'number', min = 1, required = true },
    } }, function(v)
        if v then TriggerServerEvent('noxa:job:society:' .. action, tonumber(v.amount)) end
    end)
end

-- /boss : menu patron (visible seulement si le joueur a les droits).
RegisterCommand('boss', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    if not data or not data.job or not data.job.isBoss then
        return Noxa.UI.notify('Vous n\'êtes pas responsable d\'une société.', 'error')
    end

    if not bossMenu then
        bossMenu = MenuV:CreateMenu('Gestion', '', 'topleft', 0, 150, 220,
            'size-110', 'default', 'menuv', 'noxa_boss')
    else
        bossMenu:ClearItems()
    end
    bossMenu.Title = ('Gestion — %s'):format(data.job.label or data.job.name)
    bossMenu.Subtitle = 'Actions de direction'

    bossMenu:AddButton({
        icon = '➕', label = 'Embaucher', description = 'Recruter le joueur le plus proche par ID',
        select = function()
            MenuV:CloseAll()
            askTargetId('Embaucher un joueur', function(id) TriggerServerEvent('noxa:job:hire', id) end)
        end,
    })
    bossMenu:AddButton({
        icon = '⇅', label = 'Promouvoir / rétrograder', description = 'Changer le grade d\'un employé',
        select = function()
            MenuV:CloseAll()
            NUI.input({ title = 'Changer de grade', fields = {
                { name = 'id', label = 'ID du joueur', type = 'number', min = 1, required = true },
                { name = 'grade', label = 'Nouveau grade', type = 'number', min = 0, required = true },
            } }, function(v)
                if v then TriggerServerEvent('noxa:job:setGrade', tonumber(v.id), tonumber(v.grade)) end
            end)
        end,
    })
    bossMenu:AddButton({
        icon = '➖', label = 'Licencier', description = 'Renvoyer un employé',
        select = function()
            MenuV:CloseAll()
            askTargetId('Licencier un joueur', function(id) TriggerServerEvent('noxa:job:fire', id) end)
        end,
    })
    bossMenu:AddButton({
        icon = '⬇', label = 'Caisse — Déposer', description = 'Verser de votre banque vers la société',
        select = function() MenuV:CloseAll(); askAmount('deposit') end,
    })
    bossMenu:AddButton({
        icon = '⬆', label = 'Caisse — Retirer', description = 'Retirer de la caisse vers votre banque',
        select = function() MenuV:CloseAll(); askAmount('withdraw') end,
    })

    MenuV:OpenMenu(bossMenu)
end, false)

-- Sécurité : ferme tout menu MenuV ouvert si la ressource s'arrête.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then MenuV:CloseAll() end
end)
