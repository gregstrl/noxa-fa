-- =====================================================================
--  NOXA FA — Migration 001 : Sociétés, Emplois, Banque, Admin, Véhicules
--  À exécuter APRÈS sql/noxa.sql. Idempotent (CREATE IF NOT EXISTS).
--  Compatible MariaDB 10.5+ / MySQL 8+. InnoDB / utf8mb4.
-- =====================================================================

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
