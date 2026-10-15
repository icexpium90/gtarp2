fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-multijob'
description 'LUSO RP : plusieurs metiers par personnage (2 ou 3), changement de metier actif en jeu'
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

dependencies { 'qb-core', 'oxmysql', 'ox_lib' }
