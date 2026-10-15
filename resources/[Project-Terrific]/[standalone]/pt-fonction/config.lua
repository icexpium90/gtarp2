Config = {}

-- Vehicules de fonction : un point (marqueur au sol) ou l'employe en service sort et range son vehicule.
--   point   : ou se tenir pour ouvrir le menu (a pied) et ranger le vehicule (au volant)
--   sortie  : ou le vehicule apparait (x, y, z, orientation)
--   grade   : grade minimum du metier pour ce vehicule
-- Les positions sont approximatives : un admin se place a l'endroit voulu et tape
--   /pointfonction [metier] point   ou   /pointfonction [metier] sortie
-- (gardees apres redemarrage).
-- La police a deja ses vehicules haut de gamme dans son garage (qb-policejob/config.lua) :
-- AMG GT R Interceptor des le grade 2, Mercedes S63 banalisee pour le commandement (grade 4).
Config.Metiers = {
    realestate = {
        label = 'Dynasty 8 - Vehicules de fonction',
        point = vector4(-708.6, 268.6, 83.1, 30.0),
        sortie = vector4(-703.5, 275.0, 83.1, 30.0),
        plaque = 'DYN8',
        couleur = { 0, 0 },          -- noir / noir (couleurs principales et secondaires du jeu)
        vehicules = {
            { modele = 's500w222', label = 'Mercedes S500 (W222)', grade = 0 },
            { modele = 'bmwe65', label = 'BMW 760i', grade = 1 },
            { modele = 'g65amg', label = 'Mercedes G65 AMG', grade = 2 },
            { modele = 's63w222', label = 'Mercedes S63 AMG', grade = 3 },
            { modele = 'mbh', label = 'Mercedes-Maybach S650', grade = 4 },
        },
    },
}

Config.EnService = true   -- il faut etre en service
