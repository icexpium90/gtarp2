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
