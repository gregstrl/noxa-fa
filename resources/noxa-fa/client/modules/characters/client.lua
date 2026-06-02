-- =====================================================================
--  NOXA FA — Module Personnages (client-side)
--  Pilote l'écran NUI custom de sélection / création / suppression.
--  Toute validation reste serveur ; le client ne fait qu'émettre l'intention.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Characters = {}

local Chars = Noxa.Characters
local NUI   = Noxa.NUI

-- État local de la phase de sélection
local current = { list = {}, maxSlots = 4, active = false }

-- Demande la liste des personnages au serveur.
function Chars.requestList()
    TriggerServerEvent('noxa:char:requestList')
end

-- Réception de la liste depuis le serveur : (ré)affiche l'écran NUI.
RegisterNetEvent('noxa:char:setList', function(data)
    if data.error then
        return Noxa.UI.notify('Erreur de chargement des personnages.', 'error')
    end
    current.list = data.characters or {}
    current.maxSlots = data.maxSlots or 4
    current.active = true
    NUI.setFocus(true)
    NUI.send('characters', 'open', { characters = current.list, maxSlots = current.maxSlots })
end)

RegisterNetEvent('noxa:char:createResult', function(res)
    if res.ok then
        Noxa.UI.notify('Personnage créé avec succès.', 'success')
        Chars.requestList()   -- recharge la grille (l'écran reste ouvert)
    else
        local map = { maxSlots = 'Nombre maximum de personnages atteint.', name = 'Nom invalide.',
                      db = 'Erreur base de données.' }
        Noxa.UI.notify(map[res.error] or 'Échec de la création.', 'error')
    end
end)

RegisterNetEvent('noxa:char:selected', function(data)
    -- Personnage chargé serveur : on ferme l'UI, libère le focus et spawn.
    current.active = false
    NUI.send('characters', 'close')
    NUI.releaseAll()
    Noxa.Spawn.toPosition(data.position)
    Noxa.Spawn.release()
    NUI.send('hud', 'show')
end)

RegisterNetEvent('noxa:char:deleteResult', function(res)
    if res.ok then
        Noxa.UI.notify('Personnage supprimé.', 'inform')
        Chars.requestList()
    end
end)

-- ---------------------------------------------------------------------
--  Callbacks NUI -> serveur (écran de personnages)
-- ---------------------------------------------------------------------

RegisterNUICallback('charSelect', function(body, cb)
    if body.id then TriggerServerEvent('noxa:char:select', body.id) end
    cb('ok')
end)

RegisterNUICallback('charCreate', function(body, cb)
    TriggerServerEvent('noxa:char:create', {
        firstname   = body.firstname,
        lastname    = body.lastname,
        gender      = body.gender,
        dob         = body.dob,
        nationality = body.nationality,
    })
    cb('ok')
end)

RegisterNUICallback('charDelete', function(body, cb)
    if body.id then TriggerServerEvent('noxa:char:delete', body.id) end
    cb('ok')
end)
