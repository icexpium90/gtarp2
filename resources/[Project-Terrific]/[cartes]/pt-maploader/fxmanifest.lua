fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-maploader'
description 'Project Terrific : chargement des cartes Map Editor / Menyoo converties (objets, vehicules, pnj, teleporteurs, eau)'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'

files {
    'cartes/*.lua',
    'cartes/*.xml',
}
