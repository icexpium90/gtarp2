fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-drogues'
description 'LUSO RP : transformation rapide weed / coke et go-fast de coke (toutes les 30 min ou /gofastcoke)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qb-core',
    'ox_lib',
    'qb-target',
    'qb-inventory',
}
