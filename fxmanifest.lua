fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noxa-core'
author 'Noxa FA'
description 'Noxa FA — Base RP FiveM moderne, modulaire et sécurisée'
version '0.2.0'

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
    -- Cœur (ordre strict : dépendances ascendantes)
    'server/core/db.lua',
    'server/core/security.lua',
    'server/core/player.lua',
    'server/core/manager.lua',
    -- Modules (sociétés AVANT jobs/banque qui en dépendent)
    'server/modules/societies/server.lua',
    'server/modules/economy/server.lua',
    'server/modules/jobs/server.lua',
    'server/modules/banking/server.lua',
    'server/modules/characters/server.lua',
    'server/modules/admin/server.lua',
    'server/main.lua',
}

-- =====================================================================
--  CLIENT
-- =====================================================================
client_scripts {
    'client/core/spawn.lua',
    'client/core/ui.lua',
    'client/modules/characters/client.lua',
    'client/modules/jobs/client.lua',
    'client/modules/banking/client.lua',
    'client/modules/admin/client.lua',
    'client/main.lua',
}

-- Fichiers servis au client (locales, etc.)
files {
    'locales/*.json',
}
