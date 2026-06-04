fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'es_extended'
author 'Noxa FA'
description 'Couche de compatibilité ESX pour Noxa FA — fait le pont vers le framework custom noxa-fa, pour que tout script ESX fonctionne sans modification.'
version '1.0.0'

-- IMPORTANT : ce n'est PAS ESX. C'est un shim mince qui expose l'API ESX
-- (ESX.GetPlayerFromId, xPlayer.addMoney/setJob/addInventoryItem, events
-- esx:playerLoaded/setJob/addInventoryItem...) en déléguant à noxa-fa.
-- Toute la logique critique reste autoritaire dans noxa-fa (server-side).

dependencies {
    'noxa-fa',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}
