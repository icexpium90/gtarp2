fx_version 'cerulean'
game 'gta5'

author 'rhodinium'

shared_scripts {
    'shared.lua'
}

client_scripts {
    'client/cl_main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}