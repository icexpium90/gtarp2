fx_version 'cerulean'
game 'gta5'

name 'qbx_properties'
description 'Systeme immobilier Qbox adapte a QBCore (LUSO RP) : maisons, appartements, entrepots, villas, shells et MLO'
repository 'https://github.com/Qbox-project/qbx_properties'
version '0.0.1-qbcore'

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/shared.lua',
    'shared/main.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/property.lua',
    'client/realtor.lua',
    'client/dataview.lua',
    'client/decorating.lua',
    'client/agence.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/property.lua',
    'server/realtor.lua',
    'server/agence.lua',
    'server/garage.lua',
    'server/domicile.lua',
}

files {
    'config/client.lua',
    'config/shared.lua',
    'locales/*.json',
    'screenshots/*.webp'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
    'qb-inventory',
    'qb-garages',
}

lua54 'yes'
