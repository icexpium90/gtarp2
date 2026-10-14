Config = {}

-- Groupes QBCore autorises a utiliser /gangadmin
Config.AdminGroups = { 'admin', 'god' }

-- Touche d'interaction (38 = E) et distance d'affichage des points
Config.InteractKey = 38
Config.InteractDistance = 1.6
Config.DrawDistance = 15.0

-- Depot partage du gang (qb-inventory)
Config.Stash = { slots = 100, maxweight = 2000000 }

-- Shells utilisables comme QG sans MLO (fournis par qb-interior). Decalage de la sortie par rapport a l'entree,
-- le shell est cree 50 m sous l'entree.
Config.ShellOffset = 50.0
Config.Shells = {
    { model = 'shell_warehouse1', label = 'Entrepot', exit = vec4(-8.95, 0.51, 1.04, 268.82) },
    { model = 'shell_garagem', label = 'Garage moyen', exit = vec4(13.90, 1.63, 1.0, 87.05) },
    { model = 'shell_michael', label = 'Villa (maison de Michael)', exit = vec4(-9.49, 5.54, 9.91, 270.86) },
    { model = 'shell_trevor', label = 'Maison de Trevor', exit = vec4(0.374, -3.789, 2.428, 358.63) },
    { model = 'shell_ranch', label = 'Ranch', exit = vec4(-1.257, -5.469, 2.5, 270.57) },
    { model = 'shell_lester', label = 'Maison de Lester', exit = vec4(-1.78, -0.795, 1.1, 270.30) },
    { model = 'shell_frankaunt', label = 'Maison de quartier', exit = vec4(-0.36, -5.89, 1.70, 358.21) },
    { model = 'shell_v16mid', label = 'Maison moyenne', exit = vec4(1.561, -14.305, 1.147, 2.26) },
    { model = 'shell_office1', label = 'Bureau', exit = vec4(1.88, 5.06, 2.05, 180.07) },
    { model = 'container_shell', label = 'Container', exit = vec4(0.08, -5.73, 1.24, 359.32) },
}

-- Couleurs proposees (blip = couleur de blip GTA, rgb = couleur des vehicules)
Config.Colors = {
    { label = 'Violet', blip = 27, rgb = { 92, 30, 130 } },
    { label = 'Vert', blip = 2, rgb = { 20, 110, 40 } },
    { label = 'Jaune', blip = 5, rgb = { 220, 180, 20 } },
    { label = 'Noir', blip = 40, rgb = { 12, 12, 12 } },
    { label = 'Blanc', blip = 4, rgb = { 235, 235, 235 } },
    { label = 'Rouge', blip = 1, rgb = { 150, 10, 10 } },
    { label = 'Bleu', blip = 3, rgb = { 20, 60, 160 } },
    { label = 'Cyan', blip = 18, rgb = { 30, 170, 190 } },
    { label = 'Orange', blip = 17, rgb = { 220, 110, 20 } },
    { label = 'Gris', blip = 39, rgb = { 70, 70, 75 } },
    { label = 'Bordeaux', blip = 1, rgb = { 60, 0, 8 } },
    { label = 'Anthracite', blip = 40, rgb = { 28, 28, 32 } },
}

local function grades(noms)
    local g = {}
    for i, nom in ipairs(noms) do
        g[tostring(i - 1)] = { name = nom, isboss = (i == #noms) or nil }
    end
    return g
end
local RUE = { 'Recrue', 'Soldat', 'Lieutenant', 'Chef' }
local ORGA = { 'Associe', 'Soldat', 'Lieutenant', 'Bras droit', 'Chef' }

-- Gangs fournis par defaut. Les gangs de base de QBCore (lostmc, ballas, vagos, cartel, families, triads)
-- gardent leur identifiant ; leurs grades sont traduits. Les autres sont crees au demarrage.
-- color = index dans Config.Colors ; plate = 4 lettres au debut des plaques ; vehicles = flotte par defaut.
Config.Gangs = {
    ballas = { label = 'Ballas', color = 1, plate = 'BALL', grades = grades(RUE),
        vehicles = { { 'buccaneer2', 'Buccaneer Custom', 0 }, { 'chino2', 'Chino Custom', 0 }, { 'baller', 'Baller', 2 } } },
    families = { label = 'Families', color = 2, plate = 'FAMS', grades = grades(RUE),
        vehicles = { { 'tornado5', 'Tornado Custom', 0 }, { 'greenwood', 'Greenwood', 0 }, { 'baller', 'Baller', 2 } } },
    vagos = { label = 'Vagos', color = 3, plate = 'VAGO', grades = grades(RUE),
        vehicles = { { 'faction2', 'Faction Custom', 0 }, { 'voodoo', 'Voodoo Custom', 0 }, { 'cavalcade2', 'Cavalcade', 2 } } },
    lostmc = { label = 'The Lost MC', color = 4, plate = 'LOST', grades = grades({ 'Prospect', 'Membre', 'Sergent d\'armes', 'President' }),
        vehicles = { { 'daemon', 'Daemon', 0 }, { 'hexer', 'Hexer', 0 }, { 'gburrito2', 'Gang Burrito', 1 } } },
    cartel = { label = 'Cartel Madrazo', color = 5, plate = 'CRTL', grades = grades({ 'Halcon', 'Sicario', 'Lugarteniente', 'Patron' }),
        vehicles = { { 'cavalcade2', 'Cavalcade', 0 }, { 'baller3', 'Baller LE', 1 }, { 'mesa3', 'Mesa', 0 } } },
    triads = { label = 'Triades', color = 6, plate = 'TRIA', grades = grades({ 'Recrue', 'Combattant', 'Baton rouge', 'Tete de dragon' }),
        vehicles = { { 'fugitive', 'Fugitive', 0 }, { 'schafter2', 'Schafter', 1 } } },

    mafia = { label = 'Cosa Nostra', color = 4, plate = 'COSA', grades = grades({ 'Associe', 'Soldat', 'Capo', 'Consigliere', 'Parrain' }),
        vehicles = { { 'cognoscenti', 'Cognoscenti', 0 }, { 'schafter2', 'Schafter', 0 }, { 'cog55', 'Cognoscenti 55', 2 }, { 'stretch', 'Limousine', 3 } } },
    yakuza = { label = 'Yakuza', color = 5, plate = 'YAKU', grades = grades({ 'Kobun', 'Shatei', 'Wakagashira', 'Saiko-komon', 'Oyabun' }),
        vehicles = { { 'sultanrs', 'Sultan RS', 0 }, { 'elegy', 'Elegy Retro', 0 }, { 'schafter3', 'Schafter V12', 2 } } },
    bratva = { label = 'Bratva (Mafia russe)', color = 10, plate = 'BRAT', grades = grades({ 'Shestyorka', 'Boyevik', 'Brigadier', 'Sovietnik', 'Pakhan' }),
        vehicles = { { 'baller2', 'Baller', 0 }, { 'dubsta', 'Dubsta', 0 }, { 'xls2', 'XLS blindee', 3 } } },
    -- Mafia allemande : le cartel de l'ombre. Flotte 100 % BMW et SUV (flotte = 2 : remplace l'ancienne flotte en base)
    schatten = { label = 'Schattenkartell', color = 12, plate = 'SCHK', flotte = 2,
        grades = grades({ 'Kurier', 'Soldat', 'Vollstrecker', 'Unterboss', 'Der Pate' }),
        vehicles = {
            { 'm5e60', 'BMW M5 E60', 0 }, { 'x5m2016', 'BMW X5 M', 0 },
            { 'm5f90', 'BMW M5 F90 Competition', 1 }, { 'x6m', 'BMW X6 M', 1 },
            { 'bmwe65', 'BMW 760Li', 2 }, { 'baller6', 'Baller LE LWB blinde', 2 },
            { '2019m5', 'BMW M5 Competition 2019', 3 }, { 'xls2', 'XLS blinde', 3 },
            { 'lumma750', 'BMW 750Li Lumma', 4 },
        } },
    -- Mafia luso-martiniquaise : sang noir (portugais "sangue" + creole martiniquais "nwe")
    sanguenwe = { label = 'Sangue Nwe', color = 11, plate = 'SNWE', grades = grades({ 'Menino', 'Soldado', 'Tenente', 'Majo', 'Patrao' }),
        vehicles = { { 'gburrito', 'Gang Burrito', 0 }, { 'manchez', 'Manchez', 0 }, { 'rumpo3', 'Rumpo Custom', 0 }, { 'kamacho', 'Kamacho', 1 },
            { 'baller', 'Baller', 1 }, { 'sabregt2', 'Sabre GT Custom', 2 }, { 'cavalcade', 'Cavalcade', 3 } } },

    marabunta = { label = 'Marabunta Grande', color = 7, plate = 'MARA', grades = grades(RUE),
        vehicles = { { 'tornado', 'Tornado', 0 }, { 'manana', 'Manana', 0 } } },
    aztecas = { label = 'Varrios Los Aztecas', color = 8, plate = 'AZTE', grades = grades(RUE),
        vehicles = { { 'chino2', 'Chino Custom', 0 }, { 'virgo2', 'Virgo Custom', 0 } } },
}

-- Libelles des points d'un QG
Config.PointLabels = {
    entree = 'Entree du QG',
    interieur = 'Interieur (MLO / IPL)',
    depot = 'Depot du gang',
    vestiaire = 'Vestiaire',
    chef = 'Menu du chef',
    garage = 'Garage (menu)',
    garage_spawn = 'Sortie des vehicules',
}
Config.ORGA = ORGA
