Config = {}

-- Appel automatique au 15 apres X secondes a terre (le joueur peut aussi appuyer sur G pour appeler tout de suite)
Config.DelaiAppelAuto = 20

-- Le VSAV de l'IA ne vient que si le nombre de SAMU / pompiers DE GARDE est inferieur ou egal a ce nombre
Config.MaxSecouristesPourIA = 0

-- Si des secouristes sont de garde mais que personne n'est venu au bout de X secondes, l'IA intervient quand meme
-- (mettre 0 pour ne jamais remplacer les joueurs)
Config.AttenteSecouristes = 240

-- Prix de l'intervention (liquide puis banque), verse dans le compte de l'entreprise 'ambulance'
Config.Prix = 750
-- Sans argent : prise en charge par la Securite sociale (gratuit) si true, sinon pas d'intervention
Config.PriseEnChargeSecu = true

-- Duree des soins sur place (ms)
Config.DureeSoins = 15000

-- Vehicule et equipage (modeles du jeu : VSAV sapeurs-pompiers + medecin du SMUR)
Config.Vehicule = 'ambulance'
Config.Conducteur = 's_m_y_fireman_01'
Config.Medecin = 's_m_m_doctor_01'
Config.Plaque = 'SAMU 15'

-- Distance d'apparition du VSAV (metres, sur la route la plus proche)
Config.DistanceApparition = { min = 120, max = 220 }

-- Temps max de trajet avant que le VSAV soit rapproche (bloque, route impossible...) (secondes)
Config.TempsMaxTrajet = 75

-- Delai entre deux interventions de l'IA pour un meme joueur (secondes)
Config.Recharge = 120
