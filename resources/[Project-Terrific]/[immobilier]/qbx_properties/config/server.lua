return {
    apartmentStash = {
        slots = 50,
        maxWeight = 150000
    },
    discordWebhook = nil, -- Replace nil with your webhook if you chose to use discord logging over ox_lib logging

    -- Coffres d'un bien : plusieurs coffres places par le proprietaire (Gerer > Placer les points)
    coffres = {
        max = 5,
        defaut = 'moyen',
        tailles = {
            petit = { label = 'Petit coffre', slots = 30, maxWeight = 100000 },
            moyen = { label = 'Coffre', slots = 50, maxWeight = 250000 },
            grand = { label = 'Grand coffre / armurerie', slots = 80, maxWeight = 600000 },
        },
    },

    -- Atelier de modification (LS Customs prive, F6 > Placer les points) selon le prix d'achat du bien :
    --   disponibleAPartirDe : prix minimum du bien pour pouvoir placer un atelier (0 = tous les biens)
    --   gratuitAPartirDe    : a partir de ce prix, toutes les modifications et reparations a l'atelier sont gratuites
    --                         (en dessous, elles sont payees comme dans un LS Customs ; false = jamais gratuit)
    atelier = {
        disponibleAPartirDe = 0,
        gratuitAPartirDe = 2000000,
    },

    -- Domicile = le bien avec garage le plus cher que le joueur possede (voir server/domicile.lua)
    --   tousLesVehicules : le garage du domicile donne acces a TOUS les vehicules ranges du joueur, ou qu'ils soient
    --                      (garage classique : liste complete ; garage physique MLO : ils viennent se garer sur les places libres)
    --   retourAuto       : un vehicule sorti revient tout seul au domicile si le joueur se deconnecte ou crashe,
    --                      au redemarrage du serveur, ou si le vehicule a disparu / est detruit et abandonne
    --   delaiAbandon     : secondes avant de rapatrier un vehicule detruit sans personne a bord ou disparu
    domicile = {
        tousLesVehicules = true,
        retourAuto = true,
        delaiAbandon = 120,
    },

    -- Agence immobiliere (metier realestate) : voir LISEZMOI.md
    agence = {
        job = 'realestate',
        societe = 'realestate',          -- compte qb-management qui encaisse ventes, loyers et doubles de cles
        commission = 0.10,               -- part de l'agent sur un contrat qu'il fait signer (vente ou premier loyer)
        achatDirect = true,              -- false : achat / location uniquement par contrat avec un agent
        impayesAvantExpulsion = 2,       -- loyers impayes consecutifs avant expulsion automatique
        prixDouble = 250,                -- prix d'un double de cle (objet property_key)
        prixSerrure = 1500,              -- changer les serrures (anciens doubles inutilisables)
        gradeGestion = 2,                -- grade minimum : modifier un prix, expulser, transferer, renommer, dupliquer
        gradeDirection = 4,              -- grade minimum : hausse / baisse globale des prix, suppression d'un bien
        contratDistance = 10.0,          -- distance max entre l'agent et le client pour un contrat
    },
}
