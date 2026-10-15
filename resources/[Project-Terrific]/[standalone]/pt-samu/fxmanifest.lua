fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-samu'
description 'LUSO RP : SAMU automatique. Quand un joueur est a terre et qu\'aucun SAMU / pompier n\'est de garde, un VSAV pilote par l\'IA vient le reanimer.'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'

dependencies { 'qb-core', 'ox_lib', 'qb-ambulancejob' }
