fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noxa-core'
author 'Noxa FA'
description 'Noxa FA — Base RP FiveM moderne, modulaire et sécurisée (UI 100% custom)'
version '0.5.0'

-- Dépendances : UNIQUEMENT oxmysql (base de données).
-- ZÉRO ox_lib : toute l'interface est 100 % NUI custom (nui/).
dependencies {
    'oxmysql',
    -- MenuV : bibliothèque de menus unifiée (concession, garage, fourrière…).
    'menuv',
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
    -- Catalogue d'objets & réglages d'inventaire (lu client + serveur).
    'shared/items.lua',
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
    -- Gestionnaire de config live (panel gestion serveur) : référence
    -- Config/Enums au chargement, applique les surcharges BDD au boot.
    'server/modules/config-manager/server.lua',
    -- Modules (sociétés AVANT jobs/banque qui en dépendent)
    'server/modules/societies/server.lua',
    'server/modules/economy/server.lua',
    'server/modules/jobs/server.lua',
    -- Jobs actifs (chargés APRÈS le cœur jobs : police / EMS / mécanicien)
    'server/modules/jobs/police.lua',
    'server/modules/jobs/ems.lua',
    'server/modules/jobs/mechanic.lua',
    'server/modules/banking/server.lua',
    'server/modules/characters/server.lua',
    'server/modules/needs/server.lua',
    -- Inventaire : étend la classe Player (après core), utilise Needs à l'usage.
    'server/modules/inventory/server.lua',
    'server/modules/admin/server.lua',
    -- Anti-cheat & panel staff (détection server-side + overlay staff F3).
    -- Après le cœur (Players/Security/DB) ; expose Noxa.AntiCheat (grace/report).
    'server/modules/anticheat/server.lua',
    -- Monde & gameplay (après needs : la boutique applique des effets de besoins)
    'server/modules/world/shop.lua',
    'server/modules/world/fuel.lua',
    -- Heure & météo serveur (autorité + broadcast 30s).
    'server/modules/world/time.lua',
    -- Véhicules : concession/garage/fourrière (utilise Noxa.Economy au runtime).
    'server/modules/vehicles/server.lua',
    'server/modules/properties/server.lua',
    'server/modules/phone/server.lua',
    -- Trafic de drogue & activités légales (récolte/transfo/vente, pêche/chasse).
    -- Après le cœur (Players/Security/Economy) ; vérifient proximité POI server-side.
    'server/modules/drugs/server.lua',
    'server/modules/activities/server.lua',
    'server/main.lua',
}

-- =====================================================================
--  CLIENT  — nui.lua (pont) chargé en premier, avant toute UI
-- =====================================================================
client_scripts {
    -- API MenuV (global `MenuV`) — chargée AVANT tout module qui ouvre un menu.
    '@menuv/menuv.lua',
    'client/core/nui.lua',
    'client/core/spawn.lua',
    'client/core/ui.lua',
    -- Personnages : apparence + créateur AVANT le pilote de sélection.
    'client/modules/characters/appearance.lua',
    'client/modules/characters/creator.lua',
    'client/modules/characters/client.lua',
    'client/modules/hud/client.lua',
    'client/modules/inventory/client.lua',
    'client/modules/economy/client.lua',
    'client/modules/jobs/client.lua',
    -- Jobs actifs côté client (effets locaux pilotés serveur)
    'client/modules/jobs/police.lua',
    'client/modules/jobs/ems.lua',
    'client/modules/jobs/mechanic.lua',
    'client/modules/banking/client.lua',
    'client/modules/admin/client.lua',
    -- Panel gestion serveur (F9, superadmin) : applique les domaines diffusés.
    'client/modules/server-panel/client.lua',
    -- Panel staff & anti-cheat (F3) : spectate discret, screenshot, report FPS.
    'client/modules/staff-panel/client.lua',
    -- Monde : carte (blips), zones de proximité, boutique, carburant
    'client/modules/world/blips.lua',
    'client/modules/world/zones.lua',
    'client/modules/world/shop.lua',
    'client/modules/world/fuel.lua',
    -- Synchro heure & météo (interpolation + verrou météo).
    'client/modules/world/sync.lua',
    -- Véhicules : concession/garage/fourrière (s'enregistre via World.on).
    'client/modules/vehicles/client.lua',
    -- Immobilier & téléphone
    'client/modules/properties/client.lua',
    'client/modules/phone/client.lua',
    -- Trafic de drogue & activités (MenuV aux POI : récolte/transfo/vente, pêche/chasse).
    -- Après world/zones (s'enregistrent via World.on) et @menuv (menus).
    'client/modules/drugs/client.lua',
    'client/modules/activities/client.lua',
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
    'nui/inventory/inventory.css',
    'nui/inventory/inventory.js',
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
    -- Véhicules : menus migrés vers MenuV (plus de NUI custom dédiée).
    'nui/phone/phone.css',
    'nui/phone/phone.js',
    -- Jobs actifs (MDT police / atelier méca / fouille)
    'nui/jobs/jobs.css',
    'nui/jobs/jobs.js',
    -- Panneau d'administration NUI (F10)
    'nui/admin/admin.css',
    'nui/admin/admin.js',
    -- Panel gestion serveur NUI (F9, superadmin)
    'nui/server-panel/server-panel.css',
    'nui/server-panel/server-panel.js',
    -- Panel staff & anti-cheat NUI (F3, helper+)
    'nui/staff-panel/staff-panel.css',
    'nui/staff-panel/staff-panel.js',
}
