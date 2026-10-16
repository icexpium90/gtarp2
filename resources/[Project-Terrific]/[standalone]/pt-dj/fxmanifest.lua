fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-dj'
description 'LUSO RP : cabines DJ (musique YouTube / MP3 entendue autour de la scene, file d\'attente, effets fumee / confettis / feux d\'artifice)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_script 'client.lua'

files {
    'html/led.html',
    'html/led.js',
}
server_script 'server.lua'

dependencies {
    'qb-core',
    'ox_lib',
    'xsound',
}
