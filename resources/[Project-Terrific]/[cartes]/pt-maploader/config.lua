Config = {}

-- Les objets sont crees localement chez chaque joueur quand il s'approche, et supprimes quand il s'eloigne.
Config.DistanceApparition = 350.0   -- metres
Config.ParFrame = 15                -- entites creees par image (evite les a-coups)
Config.ToucheTeleport = 38          -- E

-- Cartes converties avec tools/cartes/convertir_carte.py (Map Editor ou Menyoo Spooner).
-- actif : charger la carte ; vehicules / pnj : decor (vehicules verrouilles, pnj passifs) ;
-- eau : fichier water.xml de remplacement charge au demarrage (necessaire si la carte cree un lac).
Config.Cartes = {
    {
        nom = 'mafia_mansion',
        label = 'Domaine de la Cosa Nostra (Tongva Hills)',
        actif = true,
        fichier = 'cartes/mafia_mansion.lua',
        vehicules = true,
        pnj = true,
    },
    {
        -- Lourd : environ 2 000 objets, un lac artificiel et un water.xml complet de 2016.
        -- A activer seulement apres un test sur votre build (FPS, eau du reste de la carte).
        nom = 'underwater_hq',
        label = 'QG sous-marin et yacht-club (lac de Vinewood Hills)',
        actif = false,
        fichier = 'cartes/underwater_hq.lua',
        eau = 'cartes/underwater_water.xml',
        vehicules = true,
        pnj = false,
    },
    {
        -- Ultra Music Festival (Gidoxy) : grande scene, ecrans, enceintes, lasers et danseurs sur la plage de Vespucci.
        -- Environ 1 200 objets et 55 pnj. Evenement : invisible tant qu'un admin ne l'allume pas
        -- (/festival on, /festival off, ou /evenement ultra_festival on|off).
        nom = 'ultra_festival',
        label = 'Ultra Music Festival (plage de Vespucci)',
        actif = true,
        evenement = true,
        fichier = 'cartes/ultra_festival.lua',
        vehicules = false,
        pnj = true,
    },
    {
        -- Entrees des interieurs ikON Projects (pt-carte-ikon) : bureaux, club souterrain, LSIA VIP, garage MOD...
        -- Les appartements de Vespucci Beach sont geres par l'immobilier (qbx_properties), pas ici.
        nom = 'ikon_teleporteurs',
        label = 'Entrees ikON Projects',
        actif = true,
        ressource = 'pt-carte-ikon',
        fichier = 'cartes/ikon_teleporteurs.lua',
    },
}
