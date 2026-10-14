CREATE TABLE IF NOT EXISTS `pt_gangs` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `color` INT NOT NULL DEFAULT 0,
    `plate` VARCHAR(4) NOT NULL DEFAULT 'GANG',
    `grades` TEXT NOT NULL,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pt_gangs_points` (
    `gang` VARCHAR(50) NOT NULL,
    `kind` VARCHAR(20) NOT NULL,
    `coords` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`gang`, `kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pt_gangs_settings` (
    `gang` VARCHAR(50) NOT NULL,
    `shell` VARCHAR(100) DEFAULT NULL,
    `blip` TINYINT NOT NULL DEFAULT 1,
    PRIMARY KEY (`gang`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pt_gangs_vehicles` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `gang` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `mingrade` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `gang` (`gang`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
