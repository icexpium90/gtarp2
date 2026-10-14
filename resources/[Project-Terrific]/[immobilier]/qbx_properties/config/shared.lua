-- Catalogue des interieurs proposes par /createproperty (agent immobilier ou admin).
--
-- Trois sortes d'interieurs :
--  * SHELL (sans MLO) : cle = modele du shell (`nom`). Les coordonnees sont des DECALAGES par rapport a la porte,
--    le shell est cree sous la carte (shellUndergroundOffset).
--  * INTERIEUR DU JEU (IPL charge par bob74_ipl) : cle = texte. Coordonnees ABSOLUES.
--  * MLO / batiment existant : choisi dans le menu "MLO / batiment existant", l'agent se place a l'interieur
--    et valide. Aucun reglage ici.
--
-- Seule la sortie ("exit") est obligatoire. Le coffre, le vestiaire et la deconnexion peuvent etre places en jeu
-- par le proprietaire (ou un agent / admin) : a la sortie, touche G > "Placer ici".
-- Les points des interieurs du jeu marques "a verifier" sont des origines d'interieur : le joueur est recale
-- au sol a l'entree, et la sortie peut etre replacee en jeu si besoin.
return {
    shellUndergroundOffset = 50.0,

    -- Les appartements de depart restent geres par qb-apartments (pas de selection ici)
    apartmentOptions = {},

    interiors = {
        ---------------------------------------------------------------- SHELLS (sans MLO)
        [`furnitured_midapart`] = {
            label = '[Appartement] Appartement meuble',
            firstspawn = vec3(1.46, -10.33, 0.0),
            exit = vec3(1.46, -10.33, 0.0),
            clothing = vec3(6.03, 9.3, 0.0),
            stash = vec3(6.91, 3.94, 0.0),
            logout = vec3(4.07, 7.89, 0.0)
        },
        [`shell_v16low`] = { label = '[Appartement] Studio simple', exit = vec4(4.693, -6.015, 1.11, 358.63) },
        [`modernhotel_shell`] = { label = '[Appartement] Chambre d\'hotel moderne', exit = vec4(4.98, 4.35, 1.16, 179.79) },
        [`shell_v16mid`] = { label = '[Maison] Maison moyenne', exit = vec4(1.561, -14.305, 1.147, 2.26) },
        [`shell_frankaunt`] = { label = '[Maison] Maison de quartier (tante de Franklin)', exit = vec4(-0.36, -5.89, 1.70, 358.21) },
        [`shell_lester`] = { label = '[Maison] Maison de Lester', exit = vec4(-1.78, -0.795, 1.1, 270.30) },
        [`shell_trevor`] = { label = '[Maison] Maison de Trevor', exit = vec4(0.374, -3.789, 2.428, 358.63) },
        [`shell_ranch`] = { label = '[Maison] Ranch', exit = vec4(-1.257, -5.469, 2.5, 270.57) },
        [`shell_trailer`] = { label = '[Maison] Caravane', exit = vec4(-1.4, -2.1, 3.3, 358.63) },
        [`shell_michael`] = { label = '[Villa] Villa (maison de Michael)', exit = vec4(-9.49, 5.54, 9.91, 270.86) },
        [`shell_warehouse1`] = { label = '[Entrepot] Entrepot (shell)', exit = vec4(-8.95, 0.51, 1.04, 268.82) },
        [`shell_garagem`] = { label = '[Garage] Garage moyen (shell)', exit = vec4(13.90, 1.63, 1.0, 87.05) },
        [`container_shell`] = { label = '[Entrepot] Container', exit = vec4(0.08, -5.73, 1.24, 359.32) },
        [`shell_office1`] = { label = '[Bureau] Bureau (shell)', exit = vec4(1.88, 5.06, 2.05, 180.07) },
        [`shell_store1`] = { label = '[Commerce] Magasin (shell)', exit = vec4(-2.61, -4.73, 1.08, 1.0) },

        ---------------------------------------------------------------- APPARTEMENTS ET MAISONS DU JEU (IPL)
        ['DellPerroHeightsApt4'] = {
            label = '[Appartement] Del Perro Heights - Apt 4',
            firstspawn = vec4(-1454.73, -537.03, 73.04, 212.89),
            exit = vec4(-1453.02, -539.5, 74.04, 35.33),
            clothing = vec3(-1449.88, -549.25, 72.84),
            stash = vec3(-1466.83, -527.03, 73.44),
            logout = vec3(-1454.08, -553.25, 72.84)
        },
        ['DellPerroHeightsApt7'] = {
            label = '[Appartement] Del Perro Heights - Apt 7',
            firstspawn = vec4(-1457.03, -524.08, 55.93, 123.32),
            exit = vec3(-1458.5, -520.89, 56.93),
            clothing = vec3(-1467.46, -537.28, 50.73),
            stash = vec3(-1457.44, -531.26, 56.94),
            logout = vec3(-1471.83, -533.47, 50.72)
        },
        ['4IntegrityWayApt28'] = {
            label = '[Appartement] 4 Integrity Way - Apt 28',
            firstspawn = vec4(-26.66, -596.81, 79.03, 67.54),
            exit = vec4(-30.58, -595.4, 80.03, 246.95),
            clothing = vec3(-38.25, -589.71, 78.83),
            stash = vec3(-12.1, -598.26, 79.43),
            logout = vec3(-37.14, -583.65, 78.83)
        },
        ['4IntegrityWayApt30'] = {
            label = '[Appartement] 4 Integrity Way - Apt 30 (duplex)',
            firstspawn = vec4(-15.94, -583.62, 89.11, 157.65),
            exit = vec4(-17.41, -588.17, 90.11, 338.23),
            clothing = vec3(-38.11, -583.48, 83.92),
            stash = vec3(-26.95, -588.61, 90.12),
            logout = vec3(-37.28, -577.89, 83.91)
        },
        ['RichardMajesticApt2'] = {
            label = '[Appartement] Richards Majestic - Apt 2',
            firstspawn = vec4(-916.66, -367.19, 113.27, 294.44),
            exit = vec4(-913.99, -365.81, 114.27, 115.17),
            clothing = vec3(-903.79, -363.99, 113.07),
            stash = vec3(-928.04, -377.22, 113.67),
            logout = vec3(-900.27, -368.65, 113.07)
        },
        ['TinselTowersApt42'] = {
            label = '[Appartement] Tinsel Towers - Apt 42',
            firstspawn = vec4(-607.7, 58.84, 97.2, 264.63),
            exit = vec4(-604.06, 58.99, 98.2, 91.45),
            clothing = vec3(-594.63, 56.15, 97.0),
            stash = vec3(-622.36, 55.09, 97.6),
            logout = vec3(-593.71, 50.18, 97.0)
        },
        ['GTAOHouseMid1'] = {
            label = '[Maison] Maison GTA Online (moyenne)',
            firstspawn = vec4(346.71, -1008.01, -100.2, 177.48),
            exit = vec4(346.76, -1011.52, -99.2, 358.57),
            clothing = vec3(350.84, -993.9, -99.2),
            stash = vec3(351.98, -998.8, -99.2),
            logout = vec3(349.24, -995.09, -99.2)
        },
        ['GTAOHouseLow1'] = {
            label = '[Maison] Maison GTA Online (simple)',
            firstspawn = vec4(259.66, -1003.63, -100.01, 296.47),
            exit = vec4(266.2, -1007.03, -100.92, 6.02),
            clothing = vec3(260.4, -1003.27, -99.01),
            stash = vec3(265.96, -999.37, -99.01),
            logout = vec3(262.91, -1002.92, -99.01)
        },

        ---------------------------------------------------------------- ENTREPOTS ET LOCAUX DU JEU (IPL, a verifier)
        ['EntrepotVehicules'] = { label = '[Entrepot] Entrepot de vehicules (Import/Export)', exit = vec4(994.59, -3002.59, -39.65, 0.0) },
        ['EntrepotCriminal'] = { label = '[Entrepot] Entrepot Criminal Enterprises', exit = vec4(849.10, -3000.21, -45.97, 0.0) },
        ['EntrepotCriminalVeh'] = { label = '[Entrepot] Entrepot de vehicules Criminal Enterprises', exit = vec4(800.14, -3001.43, -65.14, 0.0) },
        ['Bunker'] = { label = '[Entrepot] Bunker', exit = vec4(899.55, -3246.04, -98.05, 90.0) },
        ['GarageCartel'] = { label = '[Entrepot] Garage du cartel (Chop Shop)', exit = vec4(1220.13, -2277.84, -50.0, 0.0) },
        ['GarageCasse'] = { label = '[Entrepot] Casse automobile (Chop Shop)', exit = vec4(1077.28, -2274.88, -50.0, 0.0) },
        ['ClubBiker1'] = { label = '[Local] Clubhouse de biker 1', exit = vec4(1107.04, -3157.40, -37.52, 0.0) },
        ['ClubBiker2'] = { label = '[Local] Clubhouse de biker 2', exit = vec4(998.48, -3164.71, -38.91, 0.0) },
        ['BoiteDeNuit'] = { label = '[Local] Boite de nuit', exit = vec4(-1604.66, -3012.58, -78.0, 0.0) },
        ['BureauAgence'] = { label = '[Bureau] Bureau Money Fronts', exit = vec4(-1160.49, -1538.93, -50.0, 0.0) },

        ---------------------------------------------------------------- VILLAS DU JEU (a verifier)
        ['PenthouseCasino'] = { label = '[Villa] Penthouse du Diamond Casino', exit = vec4(976.64, 70.30, 115.16, 0.0) },
        ['Manoir1'] = { label = '[Villa] Manoir de Vinewood Hills (Safehouse 1)', exit = vec4(543.85, 712.75, 201.0, 0.0) },
        ['Manoir2'] = { label = '[Villa] Manoir de Richman (Safehouse 2)', exit = vec4(-1630.43, 470.85, 128.0, 0.0) },
        ['Manoir3'] = { label = '[Villa] Manoir de Tongva Hills (Safehouse 3)', exit = vec4(-2601.71, 1874.83, 166.0, 0.0) },
    },

    -- Agence immobiliere (Dynasty 8, Rockford Hills) : point du menu agence + menu du patron (qb-management)
    agence = {
        bureau = vec3(-716.11, 261.21, 84.14),
        blip = { sprite = 375, couleur = 2, label = 'Dynasty 8 - Agence immobiliere' },
    },

    -- Lieux MLO deja presents sur la carte (jeu de base ou ressources de [cartes]).
    -- /immo > Lieux MLO : GPS vers le lieu, puis "Creer ici" devant la porte (nom et prix pre-remplis).
    -- Les positions sont celles de la zone : c'est l'agent qui choisit la porte et le point d'arrivee interieur.
    lieux = {
        { label = 'Villa moderne (Tongva Hills)', zone = vec3(-2653.6, 1320.5, 144.3), prix = 2500000, type = 'Villa', ressource = 'pt-carte-villa-moderne' },
        { label = 'Maison de Michael (Rockford Hills)', zone = vec3(-816.5, 178.5, 72.2), prix = 3500000, type = 'Villa' },
        { label = 'Maison de Franklin (Vinewood Hills)', zone = vec3(7.9, 538.4, 176.0), prix = 1800000, type = 'Villa' },
        { label = 'Maison de tante Denise (Strawberry)', zone = vec3(-14.3, -1441.2, 31.1), prix = 180000, type = 'Maison' },
        { label = 'Maison de Lester (El Burro Heights)', zone = vec3(1273.9, -1719.7, 54.8), prix = 150000, type = 'Maison' },
        { label = 'Caravane de Trevor (Sandy Shores)', zone = vec3(1973.2, 3815.4, 33.4), prix = 60000, loyer = 24, type = 'Maison' },
        { label = 'Appartement de Floyd (Vespucci Beach)', zone = vec3(-1150.7, -1520.7, 10.6), prix = 2500, loyer = 24, type = 'Appartement' },
    },
}
