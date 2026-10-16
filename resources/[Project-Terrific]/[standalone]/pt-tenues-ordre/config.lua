Config = {}

-- Metiers autorises (en service) a prendre une tenue avec /tenue (ambulance = SAMU / sapeurs-pompiers)
Config.Metiers = { gendarmerie = true, police = true, ambulance = true }

-- Tenues : ped du jeu remplace par la tenue francaise (dossier stream)
Config.Tenues = {
    { label = 'Gendarme motard (homme)',          modele = 's_m_y_hwaycop_01', metiers = { gendarmerie = true } },
    { label = 'Gendarme mobile (homme)',          modele = 's_m_m_chemsec_01', metiers = { gendarmerie = true } },
    { label = 'Gendarme (femme)',                 modele = 's_f_y_sheriff_01', metiers = { gendarmerie = true } },
    { label = 'Sapeur-pompier, tenue de feu (SDIS 51)', modele = 's_m_y_fireman_01', metiers = { ambulance = true } },
}

-- Tenue mise automatiquement a la prise de service (et a la connexion si le metier commence en service).
-- homme / femme : modele du ped selon le sexe du personnage ; absent = le joueur garde ses vetements.
-- Le vestiaire (/tenue) reste disponible pour changer de tenue.
-- tenueDuMetier : d'abord la tenue de service enregistree par le chef dans le vestiaire du metier (illenium-appearance,
-- tenues EUP francaises de pt-eup-france). Celle dont le nom commence par "Service" est prise en priorite, sinon la premiere.
-- Sans tenue enregistree pour le metier, le ped (homme / femme) est utilise s'il est defini.
Config.TenueAuto = {
    police      = { tenueDuMetier = true },
    gendarmerie = { tenueDuMetier = true, homme = 's_m_m_chemsec_01', femme = 's_f_y_sheriff_01' },
    ambulance   = { tenueDuMetier = true, homme = 's_m_y_fireman_01' },
}
Config.TenueAutoALaConnexion = true
