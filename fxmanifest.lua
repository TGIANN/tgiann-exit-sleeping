fx_version "cerulean"
game "gta5"
lua54 "yes"
author "TGIANN <tgiann.com>"
description "When players log out, a ped version of their character spawns at their last location. This ped persists in the game world, allowing other players to interact with, move, or manipulate it. Essentially, it mirrors Rust’s mechanic, where your character continues to “exist” in the world even when you’re offline."
version '1.0.4'

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
