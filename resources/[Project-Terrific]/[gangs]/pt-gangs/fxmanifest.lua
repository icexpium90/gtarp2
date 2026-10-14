fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-gangs'
author 'Project Terrific'
description 'Gangs et organisations : QG (MLO, IPL ou shell), depot, vestiaire, menu du chef, garage et flotte de vehicules avec cles. Setup admin en jeu (/gangadmin).'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

files { 'pt_gangs.sql' }

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
    'qb-inventory',
    'qb-vehiclekeys',
    'qb-management',
}
