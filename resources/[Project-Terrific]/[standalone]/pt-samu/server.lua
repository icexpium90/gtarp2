local QBCore = exports['qb-core']:GetCoreObject()
local enCours = {}      -- [src] = { debut = os.time() }
local derniere = {}     -- [src] = os.time() de la derniere intervention
local appelJoueurs = {} -- [src] = os.time() du premier appel transmis aux secouristes de garde

local function secouristesDeGarde()
    local n = 0
    for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = p.PlayerData.job
        if job and job.type == 'ems' and job.onduty then n += 1 end
    end
    return n
end

local function aTerre(Player)
    local m = Player.PlayerData.metadata
    return m.isdead or m.inlaststand
end

local function peutPayer(Player)
    local argent = Player.PlayerData.money
    return argent.cash >= Config.Prix or argent.bank >= Config.Prix
end

-- Le client demande le SAMU. Reponses : 'ia' (VSAV envoye), 'secouristes' (joueurs de garde prevenus),
-- 'argent' (pas d'argent et pas de prise en charge), 'attente' (recharge), 'non' (pas a terre)
lib.callback.register('pt-samu:demander', function(src, forcerIA)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not aTerre(Player) then return 'non' end
    if enCours[src] then return 'ia' end
    if derniere[src] and os.time() - derniere[src] < Config.Recharge then return 'attente' end

    local garde = secouristesDeGarde()
    if garde > Config.MaxSecouristesPourIA then
        appelJoueurs[src] = appelJoueurs[src] or os.time()
        local attenteFinie = Config.AttenteSecouristes > 0 and os.time() - appelJoueurs[src] >= Config.AttenteSecouristes
        if not (forcerIA and attenteFinie) then return 'secouristes' end
    end
    if not peutPayer(Player) and not Config.PriseEnChargeSecu then return 'argent' end

    appelJoueurs[src] = nil
    enCours[src] = { debut = os.time() }
    return 'ia'
end)

-- Fin des soins : verifie cote serveur, encaisse et reanime
RegisterNetEvent('pt-samu:server:soigne', function()
    local src = source
    local c = enCours[src]
    local Player = QBCore.Functions.GetPlayer(src)
    if not c or not Player then return end
    if os.time() - c.debut < math.floor(Config.DureeSoins / 1000) then return end
    enCours[src] = nil
    derniere[src] = os.time()
    if not aTerre(Player) then return end

    local paye = 0
    if Player.Functions.RemoveMoney('cash', Config.Prix, 'samu-intervention') or
       Player.Functions.RemoveMoney('bank', Config.Prix, 'samu-intervention') then
        paye = Config.Prix
        if GetResourceState('qb-management') == 'started' then
            exports['qb-management']:AddMoney('ambulance', paye)
        end
    end
    TriggerClientEvent('hospital:client:Revive', src)
    TriggerClientEvent('pt-samu:client:fin', src, paye)
end)

RegisterNetEvent('pt-samu:server:annule', function()
    enCours[source] = nil
end)

-- Reanime par un joueur (ou autre) : on oublie l'appel en attente
RegisterNetEvent('pt-samu:server:releve', function()
    appelJoueurs[source] = nil
end)

AddEventHandler('playerDropped', function()
    enCours[source] = nil
    appelJoueurs[source] = nil
    derniere[source] = nil
end)
