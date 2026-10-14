Config = {}

-- Nombre de metiers qu'un personnage peut cumuler (le gang est a part : QBCore gere metier et gang separement,
-- donc "agent immobilier + mecano + mafia" = 2 metiers + 1 gang).
Config.MaxJobs = 3

-- Delai minimum entre deux changements de metier actif (secondes)
Config.Cooldown = 60

-- Metiers qui ne comptent pas comme un emploi
Config.Ignores = { unemployed = true }

-- Metiers qu'on ne peut pas cumuler avec certains autres (ex. police et gang de rue n'ont rien a voir ici :
-- les gangs sont separes). Exemple : { police = { 'ambulance' } } interdit police + ambulance.
Config.Incompatibles = {
    police = { 'ambulance' },
    ambulance = { 'police' },
}

-- Changer de metier hors service uniquement (evite de quitter la police en pleine poursuite)
Config.HorsServiceSeulement = false

-- Groupes QBCore autorises a utiliser /addjob et /removejob
Config.AdminGroup = 'admin'
