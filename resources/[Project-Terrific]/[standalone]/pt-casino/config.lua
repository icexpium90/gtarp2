Config = {}

-- IMPORTANT : jetons achetes UNIQUEMENT avec l'argent du jeu. Ne jamais vendre de jetons, de mises ou de gains
-- sur la boutique Tebex (interdit par les conditions FiveM).

Config.Jeton = 'casinochips'        -- objet utilise comme jeton (qb-core/shared/items.lua)
Config.PrixJeton = 1                -- 1 jeton = 1 $ (achat et revente au meme prix a la caisse)
Config.MiseMin = 10
Config.MiseMax = 50000

-- Entree : porte principale du casino <-> hall interieur (E pour passer)
-- Les positions se reglent en jeu : /casinopos entree (dehors, devant la porte) et /casinopos sortie (dans le hall)
Config.Entree = vector4(924.95, 46.20, 81.10, 58.0)
Config.Sortie = vector4(1089.80, 206.10, -49.00, 358.0)

-- Caisse (achat / revente des jetons), dans le hall. /casinopos caisse pour la deplacer.
Config.Caisse = vector4(1116.0, 219.9, -49.44, 85.0)

-- Tables et machines : une table (modele du jeu) est posee a chaque position si le casino n'en a pas deja une.
-- Les admins en ajoutent avec /casinojeu machine|roulette|blackjack (a leur position) et retirent la plus proche
-- avec /casinojeu retirer.
Config.Modeles = {
    machine = 'vw_prop_casino_slot_04a',
    roulette = 'vw_prop_casino_roulette_01',
    blackjack = 'vw_prop_casino_blckjack_01',
}
Config.Jeux = {
    { type = 'roulette',  coords = vector4(1144.814, 268.263, -52.840, 315.0) },
    { type = 'roulette',  coords = vector4(1150.355, 262.722, -52.840, 135.0) },
    { type = 'blackjack', coords = vector4(1148.837, 269.747, -52.840, 225.3) },
    { type = 'blackjack', coords = vector4(1151.840, 266.747, -52.840, 45.3) },
}

-- Machines a sous : symboles (poids = probabilite sur chaque rouleau) et gains pour 3 identiques (x la mise).
-- Deux cerises : mise rendue. Taux de redistribution d'environ 92 %.
Config.Symboles = {
    { nom = 'Cerise',  poids = 40, gain = 5 },
    { nom = 'Citron',  poids = 25, gain = 10 },
    { nom = 'Cloche',  poids = 15, gain = 20 },
    { nom = 'BAR',     poids = 10, gain = 40 },
    { nom = '7',       poids = 7,  gain = 100 },
    { nom = 'Diamant', poids = 3,  gain = 500 },
}
