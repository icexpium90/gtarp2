Config = {}

-- Metiers qui peuvent facturer (/facture ou menu radial F1 > metier > Facturer).
--   commission : part du montant versee a l'employe qui a facture (le reste va au compte de l'entreprise, qb-management)
--   max        : montant maximum d'une facture
Config.Metiers = {
    mechanic  = { label = 'Mecanicien / LS Customs', commission = 0.10, max = 500000 },
    ambulance = { label = 'SAMU / Sapeurs-pompiers', commission = 0.10, max = 50000 },
    taxi      = { label = 'Taxi', commission = 0.20, max = 10000 },
    tow       = { label = 'Depanneuse', commission = 0.20, max = 20000 },
    cardealer = { label = 'Concession automobile', commission = 0.05, max = 5000000 },
    lawyer    = { label = 'Avocat', commission = 0.50, max = 100000 },
}

Config.EnService = true        -- il faut etre en service pour facturer
Config.Distance = 6.0          -- distance maximum entre l'employe et le client (m)
Config.MotifDefautTravaux = 'Travaux LS Customs'
