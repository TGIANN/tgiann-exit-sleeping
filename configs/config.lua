tgiCoreExports        = exports["tgiann-core"]
config                = tgiCoreExports:getConfig()

config.lang           = "en"

config.clotheScripts  = {
    tgiann_clothing     = GetResourceState("tgiann-clothing") ~= "missing",
    illenium_appearance = GetResourceState("illenium-appearance") ~= "missing",
    crm_appearance      = GetResourceState("crm-appearance") ~= "missing",
    rcore_clothing      = GetResourceState("rcore_clothing") ~= "missing",
}

config.sleepingDay    = 3

config.testCommand    = {
    name = "exittest",
    perm = {
        esx = "admin",
        qb  = "god",
    }
}

config.pedSpawnDist   = 25.0
config.sleepAnimation = {
    {
        dict = "amb@world_human_bum_slumped@male@laying_on_left_side@idle_a",
        anim = "idle_b",
        flags = 1,
    },
}

config.carryAnimation = {
    player1 = {
        dict = "missfinale_c2mcs_1",
        anim = "fin_c2_mcs_1_camman",
        flags = 49,
    },
    player2 = {
        dict = "nm",
        anim = "firemans_carry",
        flags = 33,
    },
    attach = { 0, 0.20, 0.15, 0.63, 0.5, 0.5, 5.0 }
}

config.langs          = {}
config.debug          = false
