Config = {}

Config.Touche = 38                -- E
Config.DelaiEffets = 4            -- secondes minimum entre deux effets sur une meme cabine
Config.VolumeDefaut = 60          -- en %
Config.BpmDefaut = 128            -- tempo utilise en attendant l'analyse (ou si elle echoue)
-- Analyse automatique du tempo de chaque morceau par le serveur (ffmpeg, + yt-dlp pour YouTube : voir LISEZMOI.md)
Config.AnalyseTempo = true
Config.AnalyseAdresse = 'http://127.0.0.1:30125'   -- service tools/dj-analyse (meme machine que le serveur)

-- Jeu de lumieres synchronise sur le tempo (projecteurs, lasers, stroboscope, fumee automatique).
-- Chaque cabine peut definir : projecteurs = { vec3(...), ... } (sinon : au-dessus des machines a fumee),
-- lasers = { vec3(...), ... } (sinon : au-dessus du centre de la scene), public = vec3(...) (centre de la foule,
-- sinon devant la scene, du cote des canons a confettis).
Config.Lumieres = {
    distance = 150.0,                 -- distance a laquelle on voit le spectacle
    couleurs = {
        { 255, 0, 120 }, { 0, 180, 255 }, { 140, 0, 255 }, { 255, 60, 0 }, { 0, 255, 120 }, { 255, 255, 255 },
    },
    fumeeToutesLesMesures = 8,        -- fumee automatique toutes les N mesures (4 temps)
    -- rampe (truss) au-dessus de chaque scene, calculee si la cabine ne donne pas ses positions :
    lyres = 16,                       -- nombre de lyres (projecteurs motorises) ; positions : cabine.lyres = { vec3... }
    strobos = 10,                     -- nombre de stroboscopes ; positions : cabine.strobos = { vec3... }
    largeurRampe = 26.0,              -- largeur de la rampe (m)
    hauteurRampe = 6.0,               -- hauteur de la rampe au-dessus du centre de la scene (m)
    faisceaux = true,                 -- faisceaux visibles des lyres (cones de lumiere dans l'air)
    -- jets de CO2 : alignes devant chaque scene (ou cabine.co2 = { vec3... }) ; jetsDevant = nombre de jets
    jetsDevant = 6,
    co2 = {
        effets = {                    -- premier effet disponible dans le jeu
            { dict = 'core', nom = 'exp_sht_extinguisher', echelle = 3.4 },
            { dict = 'core', nom = 'ent_sht_steam', echelle = 3.8 },
        },
        angleTir = 55.0,              -- angle au-dessus de l'horizontale, vers le public (90 = droit vers le ciel)
        duree = 1500,                 -- duree d'un jet (ms)
    },
    -- lance-flammes au pied de la scene (entre les jets de CO2) : sub-bass, drops, growls
    flammes = {
        nombre = 4,
        effets = {
            { dict = 'core', nom = 'ent_sht_flame', echelle = 2.2 },
            { dict = 'core', nom = 'exp_grd_petrol_pump_post', echelle = 1.0 },
        },
        rotation = vec3(90.0, 0.0, 0.0), -- vers le ciel
        duree = 900,
    },
    -- couleurs : changent quand l'harmonie du morceau change (analyse), sinon toutes les 8 mesures
}

-- Cabines DJ
--   coords     : la table de mixage (le DJ se place devant et appuie sur E)
--   son        : d'ou vient la musique (centre de la scene) ; portee : distance a laquelle on l'entend (m)
--   evenement  : cabine utilisable seulement quand cet evenement pt-maploader est allume (/festival on)
--   acces      : qui peut mixer. admins = true : les admins ; metiers = { nom = true } ; tous = true : n'importe qui.
--                Les joueurs autorises par un admin avec /autoriserdj [id] peuvent toujours mixer.
--   effets     : positions des effets (fumee au sol, confettis devant la scene, feux d'artifice au-dessus)
Config.Cabines = {
    {
        id = 'ultra_principale',
        label = 'Ultra - grande scene',
        coords = vec3(-1435.11, -1351.94, 7.07),
        son = vec3(-1435.0, -1352.0, 10.0),
        portee = 110.0,
        evenement = 'ultra_festival',
        acces = { admins = true },
        effets = {
            fumee = {
                vec3(-1420.21, -1351.07, 5.19), vec3(-1424.58, -1351.40, 5.19), vec3(-1428.60, -1351.74, 5.19),
                vec3(-1441.35, -1352.79, 5.19), vec3(-1445.84, -1353.14, 5.19), vec3(-1449.82, -1353.37, 5.19),
            },
            confettis = { vec3(-1420.0, -1347.0, 9.0), vec3(-1435.0, -1347.0, 9.0), vec3(-1450.0, -1347.0, 9.0) },
            feux = { vec3(-1415.0, -1356.0, 30.0), vec3(-1435.0, -1356.0, 34.0), vec3(-1455.0, -1356.0, 30.0) },
        },
    },
    {
        id = 'ultra_scene2',
        label = 'Ultra - scene 2',
        coords = vec3(-1328.70, -1382.35, 7.07),
        son = vec3(-1329.0, -1379.0, 9.0),
        portee = 80.0,
        evenement = 'ultra_festival',
        acces = { admins = true },
        effets = {
            fumee = { vec3(-1332.97, -1381.20, 5.69), vec3(-1325.71, -1378.73, 5.69) },
            confettis = { vec3(-1331.0, -1375.0, 9.0), vec3(-1324.0, -1373.0, 9.0) },
            feux = { vec3(-1329.0, -1382.0, 30.0) },
        },
    },
    {
        id = 'ultra_scene3',
        label = 'Ultra - scene 3',
        coords = vec3(-1477.82, -1203.38, 5.93),
        son = vec3(-1477.0, -1201.0, 8.0),
        portee = 80.0,
        evenement = 'ultra_festival',
        acces = { admins = true },
        effets = {
            fumee = {
                vec3(-1488.97, -1207.40, 3.99), vec3(-1484.26, -1205.75, 3.99), vec3(-1472.20, -1201.53, 3.99),
                vec3(-1467.59, -1199.94, 3.99),
            },
            confettis = { vec3(-1484.0, -1210.0, 7.0), vec3(-1471.0, -1206.0, 7.0) },
            feux = { vec3(-1478.0, -1200.0, 30.0) },
        },
    },
}

-- Effets de particules du jeu (dictionnaire, nom, en boucle ?, duree en ms pour les boucles, echelle)
Config.Effets = {
    fumee = { label = 'Fumee', dict = 'core', nom = 'exp_grd_bzgas_smoke', boucle = true, duree = 9000, echelle = 1.6,
              secours = { dict = 'scr_ba_club', nom = 'scr_ba_club_smoke_machine', echelle = 3.0 } },
    confettis = { label = 'Canons a confettis', dict = 'scr_xs_celebration', nom = 'scr_xs_confetti_burst', boucle = false, echelle = 2.0 },
    feux = { label = 'Feux d\'artifice', dict = 'scr_indep_fireworks', nom = 'scr_indep_firework_starburst', boucle = false, echelle = 2.0 },
}
