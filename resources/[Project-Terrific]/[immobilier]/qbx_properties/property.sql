CREATE TABLE IF NOT EXISTS `properties` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `property_name` VARCHAR(255) NOT NULL,
    `coords` LONGTEXT NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `owner` VARCHAR(50) DEFAULT NULL,
    `interior` VARCHAR(255) NOT NULL,
    `keyholders` VARCHAR(2048) NOT NULL DEFAULT '[]',
    `rent_interval` INT DEFAULT NULL,
    `interact_options` VARCHAR(2048) NOT NULL DEFAULT '[]',
    `stash_options` VARCHAR(2048) NOT NULL DEFAULT '[]',
    `garage` LONGTEXT DEFAULT NULL,
    `serrure` INT NOT NULL DEFAULT 1,
    `next_rent` BIGINT DEFAULT NULL,
    `impayes` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner` (`owner`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
