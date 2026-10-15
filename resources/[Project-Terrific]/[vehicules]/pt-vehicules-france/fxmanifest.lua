fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pt-vehicules-france'
description 'LUSO RP : vehicules des forces de l\'ordre francaises. Remplace police2 (Megane Police Municipale), police3 (BMW Gendarmerie BRI), police4 (Megane Police Nationale banalisee), sheriff (Megane Gendarmerie). Ajoute expertgn (Peugeot Expert Gendarmerie).'
version '1.0.0'

files {
    'data/vehicles.meta',
    'data/carvariations.meta',
}

data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'

client_script 'client.lua'
