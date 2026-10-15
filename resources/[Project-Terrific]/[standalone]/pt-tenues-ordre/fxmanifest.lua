fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-tenues-ordre'
description 'LUSO RP : tenues de la Gendarmerie (motard, gendarme mobile, gendarme femme) et des sapeurs-pompiers (tenue de feu SDIS 51) en remplacement de peds du jeu + vestiaire /tenue'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'

dependencies { 'qb-core', 'ox_lib' }
