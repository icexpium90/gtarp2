Config = {}
Config.Interior = vector3(-264.1443, -951.5657, 75.8179) -- Interior to load where characters are previewed
Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86) -- Default spawn coords if you have start apartments disabled
Config.PedCoords = vector4(-256.3065, -941.7942, 75.8287, 156.7334) -- Create preview ped at these coordinates
Config.HiddenCoords = vector4(-261.8508, -949.5483, 75.8287, 142.5654) -- Hides your actual ped while you are in selection
Config.CamCoords = vector4(-258.5254, -943.3583, 76.1148, 309.1309) -- Camera coordinates for character preview screen
Config.EnableDeleteButton = true -- Define if the player can delete the character or not

-- LUSO RP : tenue de base affichee a la selection pour un personnage qui n'a encore aucune apparence enregistree
-- (le modele suit le sexe du personnage). Format : [numero de composant] = { modele, texture }
-- 3 = bras, 4 = pantalon, 6 = chaussures, 8 = sous-haut, 11 = haut. A ajuster avec /pedmenu si besoin.
Config.TenueParDefaut = {
    [0] = { -- homme
        modele = 'mp_m_freemode_01',
        composants = { [3] = { 0, 0 }, [4] = { 1, 0 }, [6] = { 1, 0 }, [8] = { 15, 0 }, [11] = { 0, 0 } },
    },
    [1] = { -- femme
        modele = 'mp_f_freemode_01',
        composants = { [3] = { 0, 0 }, [4] = { 0, 0 }, [6] = { 3, 0 }, [8] = { 14, 0 }, [11] = { 0, 0 } },
    },
}

Config.DefaultNumberOfCharacters = 4 -- Define maximum amount of default characters, Max 4 //ST4LTH
Config.PlayersNumberOfCharacters = { -- Define maximum amount of player characters by rockstar license (you can find this license in your server's database in the player table)
    { license = "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", numberOfChars = 2 },
}
