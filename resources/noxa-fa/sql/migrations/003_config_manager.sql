-- =====================================================================
--  NOXA FA — Migration 003 : Panel gestion serveur (config-manager)
--  • noxa_config            : surcharges de configuration persistées (JSON).
--    Chaque ligne = un « domaine » de config (economy, poi, jobs...) dont
--    l'instantané remplace la valeur statique en mémoire au démarrage.
--  • noxa_scheduled_messages : messages serveur diffusés à intervalle.
--  Idempotent (CREATE TABLE IF NOT EXISTS).
-- =====================================================================

CREATE TABLE IF NOT EXISTS `noxa_config` (
    `ckey`       VARCHAR(64)  NOT NULL,                  -- domaine (economy, poi, enumsJobs...)
    `cvalue`     LONGTEXT     NOT NULL,                  -- instantané JSON du domaine
    `updated_by` VARCHAR(64)  DEFAULT NULL,              -- acteur (nom [cid] | console)
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noxa_scheduled_messages` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `body`        VARCHAR(512) NOT NULL,
    `interval_min` INT UNSIGNED NOT NULL DEFAULT 30,     -- périodicité (minutes)
    `enabled`     TINYINT(1)   NOT NULL DEFAULT 1,
    `created_by`  VARCHAR(64)  DEFAULT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
