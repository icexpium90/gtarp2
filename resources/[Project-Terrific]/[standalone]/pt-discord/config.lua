Config = {}

-- Liens des webhooks Discord : JAMAIS ici (le depot est public). Ils viennent de webhooks.cfg, ecrit
-- automatiquement par le bot Discord (/setup) et charge par server.cfg avec la ligne :  exec webhooks.cfg
--   set pt_webhook_twitter "https://discord.com/api/webhooks/..."
--   set pt_webhook_lbc "..."            (petites annonces du telephone = Leboncoin)
--   set pt_webhook_annonces "..."       (annonces RP : /annonce)
--   set pt_webhook_entreprises "..."    (ouvertures / fermetures)

Config.NomServeur = 'LUSO RP'
Config.Couleur = 13214247   -- dore (0xC9A227)

-- Entreprises : ouverture / fermeture annoncees en jeu et sur Discord
Config.Entreprises = {
    auto = true,                -- ouverture automatique quand le 1er employe prend son service, fermeture quand le dernier part
    delaiFermeture = 180,       -- secondes sans personne en service avant d'annoncer la fermeture (evite les deconnexions breves)
    -- metiers sans annonce (services publics, petits boulots)
    ignores = { unemployed = true, police = true, gendarmerie = true, ambulance = true,
                bus = true, garbage = true, hotdog = true, trucker = true, vineyard = true, tow = true },
    delaiCommande = 120,        -- secondes entre deux /ouverture ou /fermeture d'une meme entreprise
}

-- /annonce [texte] : annonce RP d'une entreprise (employe en service), affichee a tous en jeu + Discord
Config.Annonce = {
    delai = 300,                -- secondes entre deux annonces d'une meme entreprise
    longueurMax = 300,
    prix = 0,                   -- cout en banque de l'entreprise / du joueur (0 = gratuit)
}

-- Twitter et petites annonces du telephone (qb-phone) recopies sur Discord
Config.Twitter = true
Config.NomTwitter = 'Kuikui'      -- nom du reseau social RP (affiche sur Discord)
Config.Leboncoin = true
Config.NomLeboncoin = 'Leboncoin RP'
