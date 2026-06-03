-- =====================================================================
--  NOXA FA — Migration 004 : Anti-cheat & Panel staff
--  • noxa_anticheat_logs : journal dédié des détections anti-triche.
--    Chaque ligne = une violation détectée server-side (speed/teleport/
--    godmode/weapon/spawn/money), avec sa sévérité, le score atteint et
--    l'action appliquée (alert | freeze | kick | ban). Sert d'historique
--    auditable et alimente le flux d'alertes temps réel du panel staff.
--  Idempotent (CREATE TABLE IF NOT EXISTS).
-- =====================================================================

CREATE TABLE IF NOT EXISTS `noxa_anticheat_logs` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(64)  DEFAULT NULL,             -- identifiant Rockstar du joueur
    `citizenid`  VARCHAR(16)  DEFAULT NULL,             -- personnage chargé (si connu)
    `name`       VARCHAR(64)  DEFAULT NULL,             -- pseudo / nom RP au moment du flag
    `src`        INT UNSIGNED DEFAULT NULL,             -- source réseau (volatile, indicatif)
    `type`       VARCHAR(24)  NOT NULL,                 -- speedhack|teleport|godmode|weapon|spawn|money
    `severity`   VARCHAR(12)  NOT NULL DEFAULT 'low',   -- low|medium|high|critical
    `score`      INT UNSIGNED NOT NULL DEFAULT 0,       -- score anti-triche cumulé après ce flag
    `detail`     VARCHAR(512) NOT NULL,                 -- description lisible de la détection
    `position`   VARCHAR(64)  DEFAULT NULL,             -- coords « x, y, z » au moment du flag
    `action`     VARCHAR(16)  NOT NULL DEFAULT 'alert', -- alert|freeze|kick|ban
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_type` (`type`),
    KEY `idx_license` (`license`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
