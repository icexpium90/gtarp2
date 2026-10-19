Config = {}

-- Aucun de ces PNJ n'a d'icone sur la carte. Les positions sont approximatives : un admin se place a l'endroit voulu
-- et tape /pnjillegal [nom] (ex. /pnjillegal blanchisseur, /pnjillegal armurier, /pnjillegal deal3) pour y deplacer
-- le PNJ (orientation = celle de l'admin). La nouvelle position est gardee apres redemarrage.
-- /pnjillegal sans argument : liste des PNJ et leur position actuelle.

-- ---------------------------------------------------------------------------------------------------------------
-- Points de deal : on vend sa drogue a un PNJ, paye en billets marques (argent sale, a blanchir)
Config.PointsDeal = {
    { id = 'deal1', label = 'Grove Street', coords = vector4(-191.0, -1712.0, 32.7, 140.0), ped = 'g_m_y_famca_01' },
    { id = 'deal2', label = 'Rancho', coords = vector4(340.0, -2045.0, 21.4, 50.0), ped = 'g_m_y_mexgoon_02' },
    { id = 'deal3', label = 'El Burro Heights', coords = vector4(1160.0, -1650.0, 36.9, 300.0), ped = 'g_m_y_salvagoon_01' },
    { id = 'deal4', label = 'Canaux de Vespucci', coords = vector4(-1094.0, -1648.0, 4.4, 220.0), ped = 'a_m_y_stbla_02' },
    { id = 'deal5', label = 'Sandy Shores', coords = vector4(1903.0, 3712.0, 32.8, 210.0), ped = 'a_m_m_hillbilly_02' },
    { id = 'deal6', label = 'Paleto Bay', coords = vector4(-97.0, 6406.0, 31.6, 45.0), ped = 'a_m_m_hillbilly_01' },
}

-- Prix par unite (aleatoire entre min et max), en argent sale
Config.Drogues = {
    ['weed_white-widow'] = { min = 30, max = 45 },
    ['weed_skunk']       = { min = 30, max = 45 },
    ['weed_purple-haze'] = { min = 35, max = 50 },
    ['weed_og-kush']     = { min = 35, max = 50 },
    ['weed_amnesia']     = { min = 40, max = 55 },
    ['weed_ak47']        = { min = 40, max = 55 },
    ['joint']            = { min = 15, max = 25 },
    ['weed_fleur']       = { min = 110, max = 130 },
    ['weed_pochon']      = { min = 1000, max = 1600 },
    ['weed_apex']        = { min = 1000, max = 1600 },
    ['cokebaggy']        = { min = 120, max = 180 },
    ['crack_baggy']      = { min = 90, max = 140 },
    ['meth']             = { min = 100, max = 160 },
    ['xtcbaggy']         = { min = 70, max = 110 },
    ['oxy']              = { min = 60, max = 100 },
}
Config.MaxParVente = 10          -- unites achetees au maximum a chaque passage
Config.DelaiPoint = 180          -- secondes avant que le meme PNJ rachete (tous joueurs confondus)
Config.ChanceAlertePolice = 25   -- % de chance d'alerte police (ps-dispatch) a chaque vente

-- ---------------------------------------------------------------------------------------------------------------
-- Blanchisseur : derriere le Pawn Shop de Vinewood. Echange les billets marques contre de l'argent propre.
Config.Blanchisseur = {
    coords = vector4(421.0, 330.5, 103.2, 160.0),
    ped = 'a_m_m_business_01',
    taux = 0.70,                 -- 70 % de la valeur rendue en liquide propre (30 % de commission)
    minParPassage = 10000,       -- valeur minimum de billets marques pour qu'il accepte
    maxParPassage = 10000000,    -- valeur maximum blanchie a chaque passage
    delai = 600,                 -- secondes entre deux blanchiments pour un meme joueur
}

-- ---------------------------------------------------------------------------------------------------------------
-- Armurier clandestin : Stab City (caravanes au bord de l'Alamo Sea, Sandy Shores). Sans permis, paiement en liquide,
-- armes sans numero enregistre au MDT. Une arme a la fois. Prix du marche noir (2 a 3 fois l'Ammu-Nation).
Config.Armurier = {
    coords = vector4(68.0, 3692.0, 39.8, 330.0),
    ped = 'g_m_y_lost_02',
    gangs = nil,                 -- ex. { ballas = true, vagos = true } pour le reserver a des gangs ; nil = tout le monde
    produits = {
        { name = 'weapon_switchblade',     price = 150,   amount = 10 },
        { name = 'weapon_knuckle',         price = 120,   amount = 10 },
        { name = 'weapon_snspistol',       price = 1500,  amount = 5 },
        { name = 'weapon_pistol',          price = 2200,  amount = 5 },
        { name = 'weapon_heavypistol',     price = 3500,  amount = 3 },
        { name = 'weapon_machinepistol',   price = 6000,  amount = 2 },
        { name = 'weapon_microsmg',        price = 8000,  amount = 2 },
        { name = 'weapon_sawnoffshotgun',  price = 4000,  amount = 2 },
        { name = 'weapon_compactrifle',    price = 12000, amount = 1 },
        { name = 'pistol_ammo',            price = 100,    amount = 50 },
        { name = 'smg_ammo',               price = 150,    amount = 30 },
        { name = 'shotgun_ammo',           price = 120,    amount = 30 },
        { name = 'rifle_ammo',             price = 250,   amount = 20 },
        { name = 'keya',                   price = 7500,  amount = 3 },   -- cle du labo de cannabis (qb-weedplanting)
    },
}
