fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noxa-core'
author 'Noxa FA'
description 'Noxa FA — Base RP FiveM moderne, modulaire et sécurisée (UI 100% custom)'
version '0.4.0'

-- Dépendances : UNIQUEMENT oxmysql (base de données).
-- ZÉRO ox_lib : toute l'interface est 100 % NUI custom (nui/).
dependencies {
    'oxmysql',
}

-- =====================================================================
--  SHARED  — chargé client + serveur
-- =====================================================================
shared_scripts {
    'shared/config.lua',
    -- Économie : doctrine salariale, catalogue véhicules, anti-inflation.
    -- Chargée APRÈS config (étend C.Economy/C.Banking) et AVANT enums (audit).
    'shared/economy/wages.lua',
    'shared/economy/vehicles.lua',
    'shared/economy/antiinflation.lua',
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
    'server/modules/needs/server.lua',
    'server/modules/admin/server.lua',
    -- Monde & gameplay (après needs : la boutique applique des effets de besoins)
    'server/modules/world/shop.lua',
    'server/modules/world/fuel.lua',
    'server/modules/properties/server.lua',
    'server/modules/phone/server.lua',
    'server/main.lua',
}

-- =====================================================================
--  CLIENT  — nui.lua (pont) chargé en premier, avant toute UI
-- =====================================================================
client_scripts {
    'client/core/nui.lua',
    'client/core/spawn.lua',
    'client/core/ui.lua',
    -- Personnages : apparence + créateur AVANT le pilote de sélection.
    'client/modules/characters/appearance.lua',
    'client/modules/characters/creator.lua',
    'client/modules/characters/client.lua',
    'client/modules/hud/client.lua',
    'client/modules/economy/client.lua',
    'client/modules/jobs/client.lua',
    'client/modules/banking/client.lua',
    'client/modules/admin/client.lua',
    -- Monde : carte (blips), zones de proximité, boutique, carburant
    'client/modules/world/blips.lua',
    'client/modules/world/zones.lua',
    'client/modules/world/shop.lua',
    'client/modules/world/fuel.lua',
    -- Immobilier & téléphone
    'client/modules/properties/client.lua',
    'client/modules/phone/client.lua',
    'client/main.lua',
}

-- =====================================================================
--  NUI  — interface 100 % custom (HTML/CSS/JS natif moderne)
-- =====================================================================
ui_page 'nui/index.html'

files {
    'locales/*.json',
    'nui/index.html',
    'nui/shell.css',
    'nui/shell.js',
    'nui/notify/notify.css',
    'nui/notify/notify.js',
    'nui/hud/hud.css',
    'nui/hud/hud.js',
    'nui/economy/economy.css',
    'nui/economy/economy.js',
    'nui/menus/menus.css',
    'nui/menus/menus.js',
    'nui/characters/characters.css',
    'nui/characters/characters.js',
    'nui/creator/creator.css',
    'nui/creator/creator.js',
    'nui/banking/banking.css',
    'nui/banking/banking.js',
    'nui/world/world.css',
    'nui/world/world.js',
    'nui/shop/shop.css',
    'nui/shop/shop.js',
    'nui/phone/phone.css',
    'nui/phone/phone.js',
}
