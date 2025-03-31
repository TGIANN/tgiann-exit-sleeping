fx_version "cerulean"
game "gta5"
lua54 "yes"
version '1.0.0'

dependencies {
    "tgiann-core", -- https://tgiann.com/en/package/5869215
}

shared_scripts {
    "configs/config.lua",
    "languages/*.lua",
    "class/main.lua",
}

client_scripts {
    "client/*.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/*.lua",
}
