fx_version 'cerulean'
game 'gta5'

author 'Jorn#0008'
description 'qbx_customs adapte a QBCore (Project Terrific) : Los Santos Customs en libre-service'
repository 'https://github.com/Qbox-project/qbx_customs'
version '0.1.1'

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/utils.lua',
    'client/menus/main.lua',
    'client/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/main.lua'
}

files {
    'locales/*.json',
    'config/*.lua',
    'client/**/*.lua',
    'carcols_gen9.meta',
    'carmodcols_gen9.meta',
}

data_file 'CARCOLS_GEN9_FILE' 'carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'carmodcols_gen9.meta'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

dependencies { 'qb-core', 'ox_lib', 'oxmysql' }
