
-- ---------------------------------------------------------------------
--  Objets — catalogue de RÉFÉRENCE (miroir de shared/items.lua).
--  L'autorité runtime reste le fichier Lua partagé ; cette table sert de
--  référentiel lisible (admin/outils). L'inventaire des joueurs est stocké
--  en JSON dans noxa_characters.inventory (source unique, atomique, anti-dupe).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `noxa_items` (
    `name`       VARCHAR(48)  NOT NULL,
    `label`      VARCHAR(64)  NOT NULL,
    `weight`     INT UNSIGNED NOT NULL DEFAULT 0,    -- grammes
    `stackable`  TINYINT(1)   NOT NULL DEFAULT 1,
    `usable`     TINYINT(1)   NOT NULL DEFAULT 0,
    `category`   VARCHAR(24)  NOT NULL DEFAULT 'divers',
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `noxa_items` (`name`, `label`, `weight`, `stackable`, `usable`, `category`) VALUES
    ('bread',    'Pain',              150, 1, 1, 'consommable'),
    ('water',    'Bouteille d''eau',  500, 1, 1, 'consommable'),
    ('sandwich', 'Sandwich',          200, 1, 1, 'consommable'),
    ('juice',    'Jus de fruit',      450, 1, 1, 'consommable'),
    ('meal',     'Repas complet',     600, 1, 1, 'consommable'),
    ('bandage',  'Bandage',            50, 1, 1, 'consommable'),
    ('phone',    'Téléphone',         180, 0, 1, 'outil'),
    ('lockpick', 'Crochet',           120, 1, 1, 'outil')
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`), `weight` = VALUES(`weight`),
    `stackable` = VALUES(`stackable`), `usable` = VALUES(`usable`),
    `category` = VALUES(`category`);
