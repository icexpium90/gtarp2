fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-illegal'
description 'LUSO RP : points de deal (vente de drogue a des PNJ), blanchisseur et armurier clandestin, sans icone sur la carte'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
}
