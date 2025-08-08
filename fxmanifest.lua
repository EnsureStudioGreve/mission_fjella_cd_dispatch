fx_version 'cerulean'
game 'gta5'

author 'Fjella'
description 'Chicken Heist Mission'
version '1.0.0'

shared_scripts { 
    '@ox_lib/init.lua',
    'config.lua'
}


client_scripts {'client/*.lua'}

server_scripts {'server/*.lua'}




dependencies {
    'ox_inventory',
    'ox_target',
    'ox_doorlock',
    'ps-dispatch'
}
