-- Modele de fxmanifest.lua pour une voiture addon (copier dans le dossier de la voiture)
-- Structure attendue :
--   [vehicules]/megane4rs/
--       fxmanifest.lua
--       data/vehicles.meta  data/handling.meta  data/carvariations.meta  data/carcols.meta  (data/vehiclelayouts.meta si fourni)
--       stream/megane4rs.yft  stream/megane4rs_hi.yft  stream/megane4rs.ytd  stream/megane4rs_<pieces de bodykit>.yft

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

files {
    'data/**/*.meta',
}

data_file 'HANDLING_FILE'          'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE'  'data/**/vehicles.meta'
data_file 'CARCOLS_FILE'           'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
-- data_file 'VEHICLE_LAYOUTS_FILE' 'data/**/vehiclelayouts.meta'
