Config = {}

-- Metiers autorises (en service) a prendre une tenue avec /tenue
Config.Metiers = { gendarmerie = true, police = true }

-- Tenues : ped du jeu remplace par la tenue francaise (dossier stream)
Config.Tenues = {
    { label = 'Gendarme motard (homme)',          modele = 's_m_y_hwaycop_01', metiers = { gendarmerie = true } },
    { label = 'Gendarme mobile (homme)',          modele = 's_m_m_chemsec_01', metiers = { gendarmerie = true } },
    { label = 'Gendarme (femme)',                 modele = 's_f_y_sheriff_01', metiers = { gendarmerie = true } },
}
