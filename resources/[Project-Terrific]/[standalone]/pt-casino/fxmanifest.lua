fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-casino'
description 'LUSO RP : Diamond Casino jouable avec l\'argent du jeu (jetons) : caisse, machines a sous, roulette, blackjack, Three Card Poker, courses de chevaux, roue de la fortune, croupiers'
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
    'bob74_ipl',
    'oxmysql',
}
