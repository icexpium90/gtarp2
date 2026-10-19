Config = {}

-- ---------------------------------------------------------------------------------------------------------------
-- Transformation rapide (weed et coke). Un admin peut deplacer un poste : se placer a l'endroit voulu et taper
-- /postedrogue [id] (ex. /postedrogue coke). La position est gardee apres redemarrage. Sans argument : liste.
Config.Postes = {
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
-- Weed (version simple) : champ au nord -> fleurs + apex -> transformateur -> pochons / joints -> vente
Config.Weed = {
    -- champ de Grapeseed : les plants repoussent 5 min apres la recolte
    champ = { centre = vector3(2224.0, 5577.0, 53.8), colonnes = 4, rangees = 3, ecart = 3.2 },
    modelePlant = 'prop_weed_01',
    repousse = 5 * 60,               -- secondes
    dureeRecolte = 8000,             -- ms
    recolte = { fleurs = { min = 45, max = 55 }, apex = { min = 5, max = 6 } },

    -- PNJ transformateur (arriere-salle du weed shop ; /postedrogue transformateur pour le deplacer)
    transformateur = { coords = vector4(351.0, -1009.6, 28.4, 180.0), ped = 'a_m_y_hippy_01' },
    apexParPochon = 1,               -- 1 apex = 1 pochon
    fleursParPochon = 10,            -- un pochon se reconvertit en 10 fleurs
    jointsParFleur = 5,              -- le transformateur roule 5 joints avec 1 fleur
    dureeParUnite = 400,             -- ms par unite transformee (plafonne a 20 s)

    -- vente dans la rue (n'importe quel passant, Alt sur lui) : paye en billets marques
    rue = {
        fleur = { min = 110, max = 130 },
        pochon = { min = 1000, max = 1600 },
        apex = { min = 1000, max = 1600 },
        joint = { min = 45, max = 60 },
        maxParVente = 5,             -- unites achetees au maximum par passant
        chanceRefus = 25,            -- % de passants qui refusent
        chanceAlerte = 15,           -- % d'alerte police a chaque vente
        delai = 8,                   -- secondes entre deux ventes pour un meme joueur
    },
    -- rachat au weed shop (prix bas, en liquide propre)
    weedshop = {
        coords = vector3(357.55, -1022.25, 29.39),
        prix = { joint = 50, fleur = 60, pochon = 600, apex = 500 },
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

-- positions des plants du champ (meme calcul cote serveur et joueurs)
function PositionsPlants()
    local c = Config.Weed.champ
    local liste = {}
    for i = 0, c.colonnes - 1 do
        for j = 0, c.rangees - 1 do
            liste[#liste + 1] = vector3(c.centre.x + (i - (c.colonnes - 1) / 2) * c.ecart,
                                        c.centre.y + (j - (c.rangees - 1) / 2) * c.ecart, c.centre.z)
        end
    end
    return liste
end
