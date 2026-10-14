Config = {}

Config.Debug = false         -- Set to true for debug mode (shows client/server tables in console)

Config.GKSPhone = false      -- Set to true if using gks phone, false for qb-phone

Config.LockOnFlag = false    -- Set to true to lock front plate reader on flagged status
Config.NotifDuration = 6000  -- Time until scan notification disappears (default = 6sec)
Config.OxTarget = true      -- Set True if using ox-target, false will use qb-target

Config.AllowedVehicles = { -- vehicules de police du jeu de base (build 3889), les anciens modeles addon nk* n'etaient pas installes
    [1] = {model = 'police', label = 'Police Cruiser'},
    [2] = {model = 'police2', label = 'Police Buffalo'},
    [3] = {model = 'police3', label = 'Police Interceptor'},
    [4] = {model = 'police4', label = 'Unmarked Cruiser'},
    [5] = {model = 'policet', label = 'Police Transporter'},
    [6] = {model = 'sheriff', label = 'Sheriff Cruiser'},
    [7] = {model = 'sheriff2', label = 'Sheriff SUV'},
    [8] = {model = 'fbi', label = 'FIB Buffalo'},
    [9] = {model = 'fbi2', label = 'FIB Granger'},
    [10] = {model = 'pranger', label = 'Park Ranger'},
    [11] = {model = 'police5', label = 'Stanier LE Cruiser'},
    [12] = {model = 'polgauntlet', label = 'Gauntlet Interceptor'},
    [13] = {model = 'poldominator10', label = 'Dominator FX Interceptor'},
    [14] = {model = 'poldorado', label = 'Dorado Cruiser'},
    [15] = {model = 'polgreenwood', label = 'Greenwood Cruiser'},
    [16] = {model = 'polimpaler5', label = 'Impaler SZ Cruiser'},
    [17] = {model = 'polimpaler6', label = 'Impaler LX Cruiser'},
    [18] = {model = 'polcaracara', label = 'Caracara Pursuit'},
    [19] = {model = 'polcoquette4', label = 'Coquette D10 Pursuit'},
    [20] = {model = 'polfaction2', label = 'Outreach Faction'},
    [21] = {model = 'polterminus', label = 'Terminus Patrol'},
    [22] = {model = 'polbuffalo', label = 'Buffalo Cruiser'},
    [23] = {model = 'polbuffalo6', label = 'Buffalo STX Pursuit'},
    [24] = {model = 'polignus', label = 'Ignus Pursuit'},
    [25] = {model = 'polamggtr', label = 'AMG GT R Interceptor'},
}

Config.GTAVSounds = {        -- Frontend sounds from GTAV (https://wiki.gtanet.work/index.php?title=FrontEndSoundlist)
    good = {
        name = "5_Second_Timer",
        ref = "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS",
    },
    bad = {
        name = "Event_Message_Purple",
        ref = "GTAO_FM_Events_Soundset",
    },
}