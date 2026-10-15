fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-factures'
description 'Project Terrific : factures des metiers (mecano, EMS, taxi...) payables tout de suite, avec /factures ou dans le telephone'
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

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
}
