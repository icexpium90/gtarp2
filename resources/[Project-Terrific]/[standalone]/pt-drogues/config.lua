Config = {}

-- ---------------------------------------------------------------------------------------------------------------
-- Transformation rapide (weed et coke). Un admin peut deplacer un poste : se placer a l'endroit voulu et taper
-- /postedrogue [id] (ex. /postedrogue coke). La position est gardee apres redemarrage. Sans argument : liste.
Config.Postes = {
    -- arriere-salle du weed shop (MLO pt-carte-weedshop, Mission Row)
    {
        id = 'weed_effeuiller', label = 'Effeuiller les branches', icone = 'fas fa-cannabis',
        coords = vector3(348.3, -1012.45, 29.2),
        entree = { { item = 'weedplant_branch', qte = 1 } },
        sortie = { item = 'weedplant_weed', qte = 10 },
        duree = 6000, anim = { dict = 'anim@amb@business@weed@weed_inspecting_high_dry@', nom = 'weed_inspecting_high_base_inspector' },
    },
    {
        id = 'weed_ensacher', label = 'Ensacher le cannabis (2 g par sachet)', icone = 'fas fa-box',
        coords = vector3(355.56, -1012.45, 29.2),
        entree = { { item = 'weedplant_weed', qte = 2 }, { item = 'empty_weed_bag', qte = 1 } },
        sortie = { item = 'weed_og-kush', qte = 1 },
        duree = 2500, parLot = 10,   -- jusqu'a 10 sachets d'un coup (2,5 s chacun)
        anim = { dict = 'anim@amb@business@weed@weed_sorting_seated@', nom = 'sorter_right_sort_v3_sorter02' },
    },
    -- coke : couper un pain recupere sur un go-fast (Stab City, a cote de l'armurier ; /postedrogue coke pour deplacer)
    {
        id = 'coke', label = 'Couper un pain de coke (20 sachets)', icone = 'fas fa-flask',
        coords = vector3(62.5, 3698.0, 39.75),
        entree = { { item = 'coke_brick', qte = 1 } },
        sortie = { item = 'cokebaggy', qte = 20 },
        duree = 12000, anim = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', nom = 'coke_cut_v1_coccutter' },
    },
}

-- ---------------------------------------------------------------------------------------------------------------
-- Go-fast : une voiture chargee de pains de coke traverse la carte, escortee par des hommes armes.
-- Il faut l'arreter, eliminer l'equipage, puis fouiller le coffre. Automatique toutes les 30 min, ou /gofastcoke (admin).
Config.GoFast = {
    intervalle = 30 * 60,        -- secondes entre deux go-fast automatiques
    minJoueurs = 1,              -- joueurs connectes minimum pour un go-fast automatique
    dureeMax = 20 * 60,          -- secondes avant que le go-fast disparaisse s'il n'est pas intercepte
    vehicule = 'baller2',
    equipage = { 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03' },   -- conducteur + passagers
    armes = { 'WEAPON_MICROSMG', 'WEAPON_PISTOL', 'WEAPON_ASSAULTRIFLE' },
    armure = 50,
    precision = 35,              -- precision de tir des PNJ (0-100)
    vitesse = 32.0,              -- m/s (~115 km/h)
    pains = { min = 3, max = 6 }, -- pains de coke dans le coffre
    flou = 250.0,                -- la zone affichee sur la carte est decalee de 0 a N metres (il faut chercher)
    alerterPolice = true,        -- les metiers de type 'leo' (police, gendarmerie...) recoivent aussi le signalement
    -- trajets (depart -> arrivee) ; les positions sont recalees sur la route la plus proche
    trajets = {
        { zone = 'Sandy Shores -> Paleto Bay', depart = vector4(1730.0, 3300.0, 41.0, 300.0), arrivee = vector3(-140.0, 6250.0, 31.2) },
        { zone = 'Grapeseed -> Port de Los Santos', depart = vector4(1700.0, 4800.0, 41.9, 180.0), arrivee = vector3(1000.0, -3000.0, 5.9) },
        { zone = 'Chumash -> Vinewood', depart = vector4(-3100.0, 1200.0, 20.3, 0.0), arrivee = vector3(300.0, 200.0, 104.0) },
        { zone = 'Mirror Park -> Sandy Shores', depart = vector4(1100.0, -500.0, 64.0, 0.0), arrivee = vector3(1960.0, 3740.0, 32.3) },
        { zone = 'Harmony -> La Mesa', depart = vector4(550.0, 2680.0, 42.2, 100.0), arrivee = vector3(800.0, -1000.0, 26.0) },
    },
}
