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
}
