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
-- Les admins en ajoutent avec /casinojeu machine|roulette|blackjack|poker|courses (a leur position) et retirent le plus
-- proche avec /casinojeu retirer. 'courses' n'a pas de meuble : c'est une borne de paris (ecran Inside Track).
Config.Modeles = {
    machine = 'vw_prop_casino_slot_04a',
    roulette = 'vw_prop_casino_roulette_01',
    blackjack = 'vw_prop_casino_blckjack_01',
    poker = 'vw_prop_casino_3cardpoker_01',
    courses = false,
}
Config.Jeux = {
    { type = 'roulette',  coords = vector4(1144.814, 268.263, -52.840, 315.0) },
    { type = 'roulette',  coords = vector4(1150.355, 262.722, -52.840, 135.0) },
    { type = 'blackjack', coords = vector4(1148.837, 269.747, -52.840, 225.3) },
    { type = 'blackjack', coords = vector4(1151.840, 266.747, -52.840, 45.3) },
    { type = 'poker',     coords = vector4(1143.338, 264.245, -52.840, 135.0) },
    { type = 'poker',     coords = vector4(1146.329, 261.254, -52.840, 315.0) },
    { type = 'courses',   coords = vector4(1092.50, 260.50, -51.24, 0.0) },
    { type = 'courses',   coords = vector4(1094.50, 259.00, -51.24, 0.0) },
}

-- ---------------------------------------------------------------------------------------------------------------
-- Croupiers (un PNJ derriere chaque roulette, table de blackjack et de poker) et joueurs assis
Config.Croupier = {
    actif = true,
    modeles = { 's_m_y_casino_01', 's_f_y_casino_01' },
    decalage = vector3(0.0, 0.70, 0.0),  -- position du croupier par rapport au centre de la table (repere de la table)
    s_asseoir = true,                    -- le joueur s'assoit a la chaise libre la plus proche pendant la partie
    camera = true,                       -- camera au-dessus de la table pendant la partie
}

-- ---------------------------------------------------------------------------------------------------------------
-- Roue de la fortune : un tour gratuit par personnage toutes les 24 h (heure reelle). 20 cases.
Config.Roue = {
    coords = vector4(1111.052, 229.849, -50.641, 0.0),   -- socle de la roue (modele du casino)
    delai = 24 * 3600,
    voiture = 'zentorno',            -- gros lot, expose sur le podium et livre au parking du casino
    garage = 'casinogarage',
    podium = vector4(1100.0, 220.0, -48.75, 0.0),
    decalageAngle = 0.0,             -- a regler si la fleche ne tombe pas pile sur la case gagnante
    -- une case = { type = 'jetons' | 'argent' | 'voiture' | 'rien', montant, chance (poids) }
    cases = {
        { type = 'jetons', montant = 2500,  chance = 10 }, { type = 'argent', montant = 5000,   chance = 6 },
        { type = 'jetons', montant = 1000,  chance = 14 }, { type = 'rien',                     chance = 8 },
        { type = 'jetons', montant = 5000,  chance = 6 },  { type = 'argent', montant = 10000,  chance = 4 },
        { type = 'jetons', montant = 1500,  chance = 12 }, { type = 'jetons', montant = 20000,  chance = 2 },
        { type = 'argent', montant = 2500,  chance = 8 },  { type = 'jetons', montant = 1000,   chance = 14 },
        { type = 'jetons', montant = 10000, chance = 3 },  { type = 'argent', montant = 25000,  chance = 2 },
        { type = 'jetons', montant = 2000,  chance = 10 }, { type = 'rien',                     chance = 8 },
        { type = 'jetons', montant = 3000,  chance = 8 },  { type = 'argent', montant = 50000,  chance = 1 },
        { type = 'jetons', montant = 1500,  chance = 12 }, { type = 'voiture',                  chance = 0.5 },
        { type = 'jetons', montant = 4000,  chance = 7 },  { type = 'argent', montant = 7500,   chance = 5 },
    },
}

-- ---------------------------------------------------------------------------------------------------------------
-- Courses de chevaux (Inside Track) : 6 chevaux, cote = gain total pour 1 jeton mise. Redistribution ~91 %.
Config.Chevaux = {
    { nom = 'Tonnerre de Luso', cote = 3 },
    { nom = 'Etoile du Sud',    cote = 4 },
    { nom = 'Mistral',          cote = 5 },
    { nom = 'Petit Diable',     cote = 7 },
    { nom = 'Vent du Nord',     cote = 10 },
    { nom = 'Derniere Chance',  cote = 15 },
}
Config.DureeCourse = 14   -- secondes de course a l'ecran

-- Three Card Poker : bonus d'ante (paye meme si le croupier gagne) pour une suite, un brelan, une quinte flush
Config.BonusPoker = { suite = 1, brelan = 4, quinte = 5 }

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
