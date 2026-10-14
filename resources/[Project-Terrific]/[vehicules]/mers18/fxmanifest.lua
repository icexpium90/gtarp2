fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Renault Megane 4 RS (2018) - spawn: mers18 - mod de skyrix converti pour FiveM'

files {
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carcols.meta',
    'data/carvariations.meta',
}

data_file 'HANDLING_FILE'          'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE'  'data/vehicles.meta'
data_file 'CARCOLS_FILE'           'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'

client_script 'client.lua'
