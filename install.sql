-- =====================================================================
--  NOXA FA — INSTALLATION COMPLÈTE
--  Ouvrez phpMyAdmin, cliquez sur "Importer" depuis la page d'accueil
--  (sans sélectionner de base), choisissez ce fichier et cliquez Exécuter.
--  La base noxa_fa est créée automatiquement.
--  Idempotent : réimportable sans risque.
--  Compatible MariaDB 10.5+ / MySQL 8+. InnoDB / utf8mb4.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `noxa_fa`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `noxa_fa`;
--
--  Contenu : schéma de base (comptes, personnages, transactions, logs)
--            + sociétés, whitelist emplois, factures, bans, véhicules.
-- =====================================================================

-- ---------------------------------------------------------------------
--  Comptes (1 compte = 1 joueur réel, identifié par license)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_accounts` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`       VARCHAR(64)  NOT NULL,                 -- identifiant Rockstar license: stable
    `discord`       VARCHAR(32)  DEFAULT NULL,
    `last_name`     VARCHAR(64)  DEFAULT NULL,             -- dernier pseudo connu
    `staff_rank`    VARCHAR(24)  NOT NULL DEFAULT 'user',  -- user | helper | mod | admin | superadmin
    `vip_rank`      VARCHAR(24)  NOT NULL DEFAULT 'none',
    `banned`        TINYINT(1)   NOT NULL DEFAULT 0,
    `ban_reason`    VARCHAR(255) DEFAULT NULL,
    `ban_expire`    INT UNSIGNED DEFAULT NULL,             -- timestamp unix, NULL = permanent
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Personnages (multi-personnages par compte)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_characters` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`    INT UNSIGNED NOT NULL,
    `slot`          TINYINT UNSIGNED NOT NULL DEFAULT 0,   -- emplacement d'affichage
    `citizenid`     VARCHAR(12)  NOT NULL,                 -- identifiant RP public unique (ex: NX1A2B3C)
    `firstname`     VARCHAR(32)  NOT NULL,
    `lastname`      VARCHAR(32)  NOT NULL,
    `dob`           VARCHAR(10)  NOT NULL DEFAULT '2000-01-01',
    `gender`        TINYINT UNSIGNED NOT NULL DEFAULT 0,   -- 0 = homme, 1 = femme
    `nationality`   VARCHAR(48)  NOT NULL DEFAULT 'Inconnue',
    `phone`         VARCHAR(15)  DEFAULT NULL,
    -- Emploi / organisation
    `job`           VARCHAR(32)  NOT NULL DEFAULT 'unemployed',
    `job_grade`     INT UNSIGNED NOT NULL DEFAULT 0,
    `gang`          VARCHAR(32)  NOT NULL DEFAULT 'none',
    `gang_grade`    INT UNSIGNED NOT NULL DEFAULT 0,
    -- Économie (entiers, jamais de float pour l'argent)
    `cash`          BIGINT       NOT NULL DEFAULT 500,
    `bank`          BIGINT       NOT NULL DEFAULT 5000,
    -- Données structurées (JSON)
    `position`      LONGTEXT     DEFAULT NULL,             -- {x,y,z,heading}
    `appearance`    LONGTEXT     DEFAULT NULL,             -- skin/tenues
    `metadata`      LONGTEXT     DEFAULT NULL,             -- faim, soif, santé, progression, flags...
    `inventory`     LONGTEXT     DEFAULT NULL,
    -- État
    `deleted`       TINYINT(1)   NOT NULL DEFAULT 0,
    `last_played`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_citizenid` (`citizenid`),
    KEY `idx_account` (`account_id`),
    KEY `idx_job` (`job`),
    CONSTRAINT `fk_char_account` FOREIGN KEY (`account_id`)
        REFERENCES `noxa_accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Journal des transactions économiques (audit / anti-triche)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_transactions` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(12)  NOT NULL,
    `account`       VARCHAR(16)  NOT NULL,                 -- cash | bank
    `type`          VARCHAR(16)  NOT NULL,                 -- add | remove
    `amount`        BIGINT       NOT NULL,
    `balance`       BIGINT       NOT NULL,                 -- solde après opération
    `reason`        VARCHAR(128) NOT NULL DEFAULT 'unknown',
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Logs serveur génériques (sécurité, admin, anti-cheat)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_logs` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category`      VARCHAR(32)  NOT NULL,                 -- security | admin | economy | join...
    `level`        VARCHAR(12)  NOT NULL DEFAULT 'info',  -- info | warn | error
    `license`       VARCHAR(64)  DEFAULT NULL,
    `message`       VARCHAR(512) NOT NULL,
    `data`          LONGTEXT     DEFAULT NULL,
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ---------------------------------------------------------------------
--  Sociétés (comptes partagés : jobs publics/privés, gangs, État)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_societies` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`       VARCHAR(48)  NOT NULL,                  -- clé technique (ex: lspd)
    `label`      VARCHAR(64)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL DEFAULT 'private',-- public|private|gang|state
    `balance`    BIGINT       NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_society_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Journal des mouvements de caisse société (audit / anti-abus boss)
CREATE TABLE IF NOT EXISTS `noxa_society_transactions` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `society`    VARCHAR(48)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL,                  -- add|remove
    `amount`     BIGINT       NOT NULL,
    `balance`    BIGINT       NOT NULL,                  -- solde après opération
    `actor`      VARCHAR(12)  DEFAULT NULL,              -- citizenid à l'origine
    `reason`     VARCHAR(128) NOT NULL DEFAULT 'unknown',
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_society` (`society`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Whitelist d'emploi (métiers à accès restreint : police, ems...)
--  Un enregistrement = autorisation d'un citoyen pour un job + grade max.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_job_whitelist` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(12)  NOT NULL,
    `job`        VARCHAR(32)  NOT NULL,
    `max_grade`  INT UNSIGNED NOT NULL DEFAULT 0,
    `granted_by` VARCHAR(12)  DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_wl` (`citizenid`, `job`),
    KEY `idx_wl_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Factures (facturation entre citoyens / sociétés)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_invoices` (
    `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `emitter_cid`  VARCHAR(12)  NOT NULL,                -- citoyen émetteur
    `emitter_name` VARCHAR(64)  NOT NULL,
    `society`      VARCHAR(48)  DEFAULT NULL,            -- société bénéficiaire (si pro)
    `target_cid`   VARCHAR(12)  NOT NULL,                -- citoyen débiteur
    `amount`       BIGINT       NOT NULL,
    `label`        VARCHAR(128) NOT NULL DEFAULT 'Facture',
    `status`       VARCHAR(12)  NOT NULL DEFAULT 'pending', -- pending|paid|refused
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at`      TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_inv_target` (`target_cid`, `status`),
    KEY `idx_inv_emitter` (`emitter_cid`),
    KEY `idx_inv_society` (`society`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Historique des bannissements (audit admin ; accounts garde l'état actif)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_bans` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED DEFAULT NULL,
    `license`    VARCHAR(64)  NOT NULL,
    `reason`     VARCHAR(255) NOT NULL DEFAULT 'Non spécifié',
    `banned_by`  VARCHAR(64)  NOT NULL DEFAULT 'console',
    `expire`     INT UNSIGNED DEFAULT NULL,              -- unix ts, NULL = permanent
    `active`     TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ban_license` (`license`),
    KEY `idx_ban_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  Véhicules possédés (fondation : concessions, garages, fourrière)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_vehicles` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner_cid`   VARCHAR(12)  DEFAULT NULL,             -- propriétaire citoyen
    `society`     VARCHAR(48)  DEFAULT NULL,             -- ou véhicule de société
    `plate`       VARCHAR(12)  NOT NULL,
    `model`       VARCHAR(48)  NOT NULL,
    `garage`      VARCHAR(48)  NOT NULL DEFAULT 'central',
    `state`       VARCHAR(12)  NOT NULL DEFAULT 'stored',-- stored|out|impound
    `fuel`        TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `engine`      FLOAT        NOT NULL DEFAULT 1000.0,
    `body`        FLOAT        NOT NULL DEFAULT 1000.0,
    `mods`        LONGTEXT     DEFAULT NULL,             -- JSON modifications
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_plate` (`plate`),
    KEY `idx_veh_owner` (`owner_cid`),
    KEY `idx_veh_society` (`society`),
    KEY `idx_veh_state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
