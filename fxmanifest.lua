fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noxa-core'
author 'Noxa FA'
description 'Noxa FA — Base RP FiveM moderne, modulaire et sécurisée'
version '0.1.0'

-- Dépendances : ox_lib (utils/UI) + oxmysql (base de données)
dependencies {
    'ox_lib',
    'oxmysql',
}

-- =====================================================================
--  SHARED  — chargé client + serveur
-- =====================================================================
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/enums.lua',
    'shared/utils.lua',
}

-- =====================================================================
--  SERVER  — toute la logique critique est server-side
-- =====================================================================
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/db.lua',
    'server/core/security.lua',
    'server/core/player.lua',
    'server/core/manager.lua',
    'server/modules/economy/server.lua',
    'server/modules/characters/server.lua',
    'server/main.lua',
}

-- =====================================================================
--  CLIENT
-- =====================================================================
client_scripts {
    'client/core/spawn.lua',
    'client/modules/characters/client.lua',
    'client/main.lua',
}

-- Fichiers servis au client (locales, etc.)
files {
    'locales/*.json',
}
