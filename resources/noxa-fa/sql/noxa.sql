-- =====================================================================
--  NOXA FA — Schéma de base de données
--  Compatible MariaDB 10.5+ / MySQL 8+
--  Conventions : InnoDB, utf8mb4, clés étrangères, index explicites.
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
