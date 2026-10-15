fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-casino'
description 'LUSO RP : Diamond Casino jouable avec l\'argent du jeu (jetons) : entree, caisse, machines a sous, roulette, blackjack'
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
    'bob74_ipl',
}
