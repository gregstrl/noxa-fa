-- =====================================================================
--  NOXA FA — Module Personnages (client-side)
--  Pilote l'échange avec le serveur pour la sélection/création.
--  L'UI NUI viendra plus tard ; ici on expose une API + des stubs ox_lib.
-- =====================================================================

Noxa = Noxa or {}
Noxa.Characters = {}

local Chars = Noxa.Characters

-- État local de la phase de sélection
local current = { list = nil, maxSlots = 4 }

-- Demande la liste des personnages au serveur.
function Chars.requestList()
    TriggerServerEvent('noxa:char:requestList')
end

-- Réception de la liste depuis le serveur.
RegisterNetEvent('noxa:char:setList', function(data)
    if data.error then
        return print(('[Noxa] Erreur liste personnages : %s'):format(data.error))
    end
    current.list = data.characters
    current.maxSlots = data.maxSlots
    -- TODO(UI) : afficher l'écran NUI de sélection. Stub console pour l'instant.
    print(('[Noxa] %d personnage(s) chargé(s) (max %d).'):format(#data.characters, data.maxSlots))
    -- Auto-sélection du premier perso si présent (provisoire avant l'UI).
    if data.characters[1] then
        Chars.select(data.characters[1].id)
    end
end)

-- Demande de création.
---@param payload table { firstname, lastname, gender, dob, nationality }
function Chars.create(payload)
    TriggerServerEvent('noxa:char:create', payload)
end

RegisterNetEvent('noxa:char:createResult', function(res)
    if res.ok then
        print('[Noxa] Personnage créé, rechargement de la liste.')
        Chars.requestList()
    else
        print(('[Noxa] Échec création personnage : %s'):format(res.error or 'inconnu'))
    end
end)

-- Sélection / chargement.
function Chars.select(charId)
    TriggerServerEvent('noxa:char:select', charId)
end

RegisterNetEvent('noxa:char:selected', function(data)
    -- Le serveur a chargé le personnage : on spawn à la position renvoyée.
    Noxa.Spawn.toPosition(data.position)
    Noxa.Spawn.release()
    print(('[Noxa] Personnage %s prêt.'):format(data.citizenid))
end)

RegisterNetEvent('noxa:char:deleteResult', function(res)
    if res.ok then Chars.requestList() end
end)
