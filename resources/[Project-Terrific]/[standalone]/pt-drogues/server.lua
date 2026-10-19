local QBCore = exports['qb-core']:GetCoreObject()

local function notifier(src, texte, genre, duree)
    TriggerClientEvent('QBCore:Notify', src, texte, genre or 'primary', duree or 6000)
end

local function estAdmin(src)
    return src == 0 or QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
        or IsPlayerAceAllowed(src, 'command')
end

-- ---------------------------------------------------------------------------------------------------------------
-- Postes de transformation (positions modifiables en jeu, gardees en KVP)

local postes = {}
for _, p in ipairs(Config.Postes) do
    local c = p.coords
    local kvp = GetResourceKvpString('poste_' .. p.id)
    if kvp then
        local d = json.decode(kvp)
        if d then c = vector3(d.x, d.y, d.z) end
    end
    postes[p.id] = { x = c.x, y = c.y, z = c.z }
end
GlobalState.pt_drogues_postes = postes

local function definition(id)
    for _, p in ipairs(Config.Postes) do
        if p.id == id then return p end
    end
end

local deplacerTransfo   -- defini plus bas (PNJ transformateur de weed)
RegisterCommand('postedrogue', function(src, args)
    if not estAdmin(src) then return end
    local id = args[1]
    if id == 'transformateur' then
        if src ~= 0 then deplacerTransfo(src) end
        return
    end
    if not id or not definition(id) then
        for _, p in ipairs(Config.Postes) do
            local c = postes[p.id]
            local t = ('%s (%s) : %.1f, %.1f, %.1f'):format(p.id, p.label, c.x, c.y, c.z)
            if src == 0 then print(t) else TriggerClientEvent('chat:addMessage', src, { args = { 'Drogue', t } }) end
        end
        return
    end
    if src == 0 then return end
    local c = GetEntityCoords(GetPlayerPed(src))
    postes[id] = { x = c.x, y = c.y, z = c.z }
    SetResourceKvp('poste_' .. id, json.encode(postes[id]))
    GlobalState.pt_drogues_postes = postes
    notifier(src, ('Poste %s deplace ici (garde apres redemarrage).'):format(id), 'success')
end, false)

local enCours = {}   -- [src] = fin prevue (anti double transformation)

-- nombre de lots realisables avec l'inventaire du joueur
local function lotsPossibles(Player, p)
    local n = p.parLot or 1
    for _, e in ipairs(p.entree) do
        local total = 0
        for _, it in pairs(Player.PlayerData.items or {}) do
            if it and it.name == e.item then total = total + (it.amount or 0) end
        end
        n = math.min(n, math.floor(total / e.qte))
    end
    return n
end

lib.callback.register('pt-drogues:commencer', function(src, id)
    local p = definition(id)
    local Player = QBCore.Functions.GetPlayer(src)
    if not p or not Player then return false end
    local c = postes[id]
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(c.x, c.y, c.z)) > 4.0 then return false end
    local lots = lotsPossibles(Player, p)
    if lots <= 0 then
        local besoin = {}
        for _, e in ipairs(p.entree) do
            besoin[#besoin + 1] = ('%dx %s'):format(e.qte, (QBCore.Shared.Items[e.item] or {}).label or e.item)
        end
        notifier(src, 'Il te faut : ' .. table.concat(besoin, ' + '), 'error')
        return false
    end
    local duree = p.duree * lots
    enCours[src] = { id = id, lots = lots, fin = GetGameTimer() + duree - 500 }
    return lots, duree
end)

RegisterNetEvent('pt-drogues:terminer', function(id)
    local src = source
    local e = enCours[src]
    enCours[src] = nil
    local p = definition(id)
    local Player = QBCore.Functions.GetPlayer(src)
    if not e or e.id ~= id or not p or not Player or GetGameTimer() < e.fin then return end
    local c = postes[id]
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(c.x, c.y, c.z)) > 4.0 then return end
    local lots = math.min(e.lots, lotsPossibles(Player, p))
    if lots <= 0 then return end
    for _, en in ipairs(p.entree) do
        Player.Functions.RemoveItem(en.item, en.qte * lots)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[en.item], 'remove', en.qte * lots)
    end
    local qte = p.sortie.qte * lots
    if Player.Functions.AddItem(p.sortie.item, qte) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[p.sortie.item], 'add', qte)
    else
        -- inventaire plein : on rend ce qui a ete pris
        for _, en in ipairs(p.entree) do Player.Functions.AddItem(en.item, en.qte * lots) end
        notifier(src, 'Inventaire plein ou trop lourd.', 'error')
    end
end)

AddEventHandler('playerDropped', function() enCours[source] = nil end)

-- ---------------------------------------------------------------------------------------------------------------
-- Go-fast

local G = Config.GoFast
local gofast = nil      -- { veh, peds = {}, trajet, debut, fouille }
local prochain = os.time() + G.intervalle

local function etatPublic()
    if not gofast then
        GlobalState.pt_gofast = nil
        return
    end
    local pedsNet = {}
    for _, p in ipairs(gofast.peds) do
        if DoesEntityExist(p) then pedsNet[#pedsNet + 1] = NetworkGetNetworkIdFromEntity(p) end
    end
    GlobalState.pt_gofast = {
        id = gofast.id,
        veh = DoesEntityExist(gofast.veh) and NetworkGetNetworkIdFromEntity(gofast.veh) or nil,
        peds = pedsNet,
        arrivee = { x = gofast.trajet.arrivee.x, y = gofast.trajet.arrivee.y, z = gofast.trajet.arrivee.z },
        zone = gofast.zone, -- position floue (mise a jour toutes les 15 s)
        vitesse = G.vitesse, precision = G.precision,
        fouille = gofast.fouille,
    }
end

local function annoncer(texte)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local Player = QBCore.Functions.GetPlayer(src)
        local job = Player and Player.PlayerData.job or {}
        local police = job.type == 'leo'
        if not police or G.alerterPolice then
            notifier(src, police and ('Signalement : vehicule suspect, ' .. texte) or ('Rumeur : un go-fast charge de coke, ' .. texte), 'error', 12000)
        end
    end
end

local function zoneFloue(c)
    local a, d = math.random() * 2 * math.pi, math.random() * G.flou
    return { x = c.x + math.cos(a) * d, y = c.y + math.sin(a) * d, z = c.z }
end

local function terminer(raison)
    if not gofast then return end
    local g = gofast
    gofast = nil
    etatPublic()
    print(('[pt-drogues] go-fast termine (%s)'):format(raison))
    -- les entites restent 60 s (corps, voiture) puis disparaissent
    SetTimeout(60000, function()
        for _, p in ipairs(g.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
        if DoesEntityExist(g.veh) then DeleteEntity(g.veh) end
    end)
end

local function lancerGoFast(force)
    if gofast then return false, 'Un go-fast est deja en cours.' end
    local t = G.trajets[math.random(#G.trajets)]
    local veh = CreateVehicleServerSetter(joaat(G.vehicule), 'automobile', t.depart.x, t.depart.y, t.depart.z, t.depart.w)
    local attente = GetGameTimer() + 5000
    while not DoesEntityExist(veh) and GetGameTimer() < attente do Wait(50) end
    if not DoesEntityExist(veh) then return false, 'Creation du vehicule impossible.' end
    SetVehicleDoorsLocked(veh, 2)
    local peds = {}
    for i, modele in ipairs(G.equipage) do
        local ped = CreatePedInsideVehicle(veh, 4, joaat(modele), i - 2, true, false)
        attente = GetGameTimer() + 3000
        while not DoesEntityExist(ped) and GetGameTimer() < attente do Wait(50) end
        if DoesEntityExist(ped) then
            GiveWeaponToPed(ped, joaat(G.armes[((i - 1) % #G.armes) + 1]), 500, false, true)
            SetPedArmour(ped, G.armure)
            peds[#peds + 1] = ped
        end
    end
    gofast = {
        id = math.random(1, 999999), veh = veh, peds = peds, trajet = t, debut = os.time(), fouille = false,
        zone = zoneFloue(vector3(t.depart.x, t.depart.y, t.depart.z)),
    }
    etatPublic()
    annoncer(('depart %s. Zone marquee sur ta carte (approximative).'):format(t.zone))
    print(('[pt-drogues] go-fast lance : %s%s'):format(t.zone, force and ' (commande admin)' or ''))
    return true
end

RegisterCommand('gofastcoke', function(src)
    if not estAdmin(src) then return end
    local ok, err = lancerGoFast(true)
    if src ~= 0 then notifier(src, ok and 'Go-fast lance.' or err, ok and 'success' or 'error') else print(ok and 'go-fast lance' or err) end
end, false)

-- boucle : depart automatique, suivi de la position, fin
CreateThread(function()
    local derniereZone = 0
    while true do
        Wait(5000)
        if not gofast then
            if os.time() >= prochain then
                prochain = os.time() + G.intervalle
                if #GetPlayers() >= (G.minJoueurs or 1) then lancerGoFast(false) end
            end
        else
            local g = gofast
            if os.time() - g.debut > G.dureeMax then
                annoncer('le go-fast a disparu des radars.')
                terminer('temps ecoule')
            elseif not DoesEntityExist(g.veh) then
                terminer('vehicule disparu')
            else
                local pos = GetEntityCoords(g.veh)
                if #(pos - g.trajet.arrivee) < 60.0 and not g.fouille then
                    annoncer('la livraison a ete faite, trop tard.')
                    terminer('arrive a destination')
                elseif os.time() - derniereZone >= 15 then
                    derniereZone = os.time()
                    g.zone = zoneFloue(pos)
                    etatPublic()
                end
            end
        end
    end
end)

local function equipageMort(g)
    for _, p in ipairs(g.peds) do
        if DoesEntityExist(p) and GetEntityHealth(p) > 100 then return false end
    end
    return true
end

RegisterNetEvent('pt-drogues:fouiller', function(id)
    local src = source
    local g = gofast
    local Player = QBCore.Functions.GetPlayer(src)
    if not g or g.id ~= id or g.fouille or not Player then return end
    if not DoesEntityExist(g.veh) or #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(g.veh)) > 7.0 then return end
    if not equipageMort(g) then return notifier(src, 'L\'equipage est encore en vie.', 'error') end
    g.fouille = true
    local n = math.random(G.pains.min, G.pains.max)
    local donnes = 0
    for _ = 1, n do
        if Player.Functions.AddItem('coke_brick', 1) then donnes = donnes + 1 end
    end
    if donnes > 0 then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['coke_brick'], 'add', donnes)
        notifier(src, ('%d pain(s) de coke recupere(s). A couper au labo.'):format(donnes), 'success')
    end
    if donnes < n then notifier(src, ('Inventaire plein : %d pain(s) laisse(s) dans le coffre.'):format(n - donnes), 'error') end
    annoncer('le go-fast a ete intercepte.')
    terminer('fouille par ' .. GetPlayerName(src))
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Weed simple : champ, transformateur, rachat au weed shop, vente dans la rue

local W = Config.Weed
local PLANTS = PositionsPlants()
local repousse = {}          -- [i] = os.time() a partir duquel le plant est de nouveau pret
local recoltes = {}          -- [src] = { i, fin }
local function publierPlants()
    local t = {}
    for i = 1, #PLANTS do t[i] = repousse[i] and repousse[i] > os.time() and repousse[i] or 0 end
    GlobalState.pt_weed_plants = t
end
publierPlants()
CreateThread(function()
    while true do
        Wait(15000)
        local change = false
        for i, t in pairs(repousse) do
            if t <= os.time() then repousse[i] = nil change = true end
        end
        if change then publierPlants() end
    end
end)

local function donner(Player, src, item, n)
    if n <= 0 then return true end
    if Player.Functions.AddItem(item, n) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', n)
        return true
    end
    return false
end
local function retirer(Player, src, item, n)
    if n <= 0 then return true end
    if Player.Functions.RemoveItem(item, n) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove', n)
        return true
    end
    return false
end
local function compte(Player, item)
    local n = 0
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == item then n = n + (it.amount or 0) end
    end
    return n
end

lib.callback.register('pt-drogues:recolteDebut', function(src, i)
    i = tonumber(i)
    local p = i and PLANTS[i]
    if not p or (repousse[i] and repousse[i] > os.time()) then return false end
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(vector2(pos.x, pos.y) - vector2(p.x, p.y)) > 3.0 then return false end
    for s, r in pairs(recoltes) do if r.i == i and s ~= src then return false end end
    recoltes[src] = { i = i, fin = GetGameTimer() + W.dureeRecolte - 600 }
    return true
end)

RegisterNetEvent('pt-drogues:recolteFin', function()
    local src = source
    local r = recoltes[src]
    recoltes[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if not r or not Player or GetGameTimer() < r.fin or (repousse[r.i] and repousse[r.i] > os.time()) then return end
    repousse[r.i] = os.time() + W.repousse
    publierPlants()
    local fleurs = math.random(W.recolte.fleurs.min, W.recolte.fleurs.max)
    local apex = math.random(W.recolte.apex.min, W.recolte.apex.max)
    local ok1 = donner(Player, src, 'weed_fleur', fleurs)
    local ok2 = donner(Player, src, 'weed_apex', apex)
    if ok1 and ok2 then
        notifier(src, ('Recolte : %d fleurs et %d apex.'):format(fleurs, apex), 'success')
    else
        notifier(src, 'Inventaire plein : une partie de la recolte est perdue.', 'error')
    end
end)

-- transformateur (position modifiable : /postedrogue transformateur)
local tr = W.transformateur.coords
do
    local kvp = GetResourceKvpString('poste_transformateur')
    local d = kvp and json.decode(kvp)
    GlobalState.pt_weed_transfo = d or { x = tr.x, y = tr.y, z = tr.z, w = tr.w }
end
deplacerTransfo = function(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local pos = { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
    SetResourceKvp('poste_transformateur', json.encode(pos))
    GlobalState.pt_weed_transfo = pos
    notifier(src, 'Transformateur deplace ici (garde apres redemarrage).', 'success')
end

local ACTIONS = {
    pochons  = { entree = 'weed_apex',   parUnite = function() return W.apexParPochon end, sortie = 'weed_pochon', donne = function() return 1 end },
    fleurs   = { entree = 'weed_pochon', parUnite = function() return 1 end, sortie = 'weed_fleur', donne = function() return W.fleursParPochon end },
    joints   = { entree = 'weed_fleur',  parUnite = function() return 1 end, sortie = 'joint', donne = function() return W.jointsParFleur end },
}
local transfos = {}

local function presDuTransfo(src)
    local t = GlobalState.pt_weed_transfo
    return t and #(GetEntityCoords(GetPlayerPed(src)) - vector3(t.x, t.y, t.z)) < 4.0
end

lib.callback.register('pt-drogues:transfoDebut', function(src, action, qte)
    local a = ACTIONS[action]
    local Player = QBCore.Functions.GetPlayer(src)
    if not a or not Player or not presDuTransfo(src) then return false end
    local dispo = math.floor(compte(Player, a.entree) / a.parUnite())
    qte = math.min(dispo, math.floor(tonumber(qte) or dispo))
    if qte <= 0 then
        notifier(src, ('Il te faut des %s.'):format((QBCore.Shared.Items[a.entree] or {}).label or a.entree), 'error')
        return false
    end
    local duree = math.min(20000, math.max(2000, qte * W.dureeParUnite))
    transfos[src] = { action = action, qte = qte, fin = GetGameTimer() + duree - 500 }
    return qte, duree
end)

RegisterNetEvent('pt-drogues:transfoFin', function()
    local src = source
    local t = transfos[src]
    transfos[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if not t or not Player or GetGameTimer() < t.fin or not presDuTransfo(src) then return end
    local a = ACTIONS[t.action]
    local qte = math.min(t.qte, math.floor(compte(Player, a.entree) / a.parUnite()))
    if qte <= 0 then return end
    retirer(Player, src, a.entree, qte * a.parUnite())
    if not donner(Player, src, a.sortie, qte * a.donne()) then
        donner(Player, src, a.entree, qte * a.parUnite())
        notifier(src, 'Inventaire plein ou trop lourd.', 'error')
    end
end)

-- rachat au weed shop (liquide propre, prix bas)
RegisterNetEvent('pt-drogues:vendreWeedshop', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local c = W.weedshop.coords
    if not Player or #(GetEntityCoords(GetPlayerPed(src)) - c) > 5.0 then return end
    local total, detail = 0, {}
    for item, prix in pairs({ joint = W.weedshop.prix.joint, weed_fleur = W.weedshop.prix.fleur,
                              weed_pochon = W.weedshop.prix.pochon, weed_apex = W.weedshop.prix.apex }) do
        local n = compte(Player, item)
        if n > 0 and retirer(Player, src, item, n) then
            total = total + n * prix
            detail[#detail + 1] = ('%d %s'):format(n, (QBCore.Shared.Items[item] or {}).label or item)
        end
    end
    if total == 0 then return notifier(src, 'Tu n\'as rien a vendre (joints, fleurs, pochons, apex).', 'error') end
    Player.Functions.AddMoney('cash', total, 'weedshop-rachat')
    notifier(src, ('Weed shop : %s -> $%d'):format(table.concat(detail, ', '), total), 'success')
end)

-- vente a un passant
local derniereVente, passants = {}, {}
lib.callback.register('pt-drogues:venteRue', function(src, netId)
    local R = W.rue
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    if derniereVente[src] and os.time() - derniereVente[src] < R.delai then
        notifier(src, 'Doucement, attends un peu entre deux clients.', 'error')
        return false
    end
    netId = tonumber(netId) or 0
    local ped = NetworkGetEntityFromNetworkId(netId)
    if netId == 0 or ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ped)) > 4.0 then return false end
    if passants[netId] and os.time() - passants[netId] < 600 then
        notifier(src, 'Il t\'a deja achete quelque chose.', 'error')
        return false
    end
    derniereVente[src] = os.time()
    passants[netId] = os.time()
    if math.random(100) <= R.chanceRefus then
        notifier(src, 'Pas interesse. Il s\'en va.', 'error')
        if math.random(100) <= R.chanceAlerte * 2 and GetResourceState('pt-illegal') == 'started' then
            TriggerClientEvent('pt-illegal:client:alerte', src)
        end
        return 'refus'
    end
    local reste, total, vendus = R.maxParVente, 0, 0
    for _, item in ipairs({ 'weed_pochon', 'weed_apex', 'weed_fleur', 'joint' }) do
        if reste <= 0 then break end
        local cle = item:gsub('^weed_', '')
        local prix = R[cle]
        local n = math.min(reste, compte(Player, item), math.random(1, R.maxParVente))
        if prix and n > 0 and retirer(Player, src, item, n) then
            for _ = 1, n do total = total + math.random(prix.min, prix.max) end
            vendus = vendus + n
            reste = reste - n
        end
    end
    if vendus == 0 then
        notifier(src, 'Tu n\'as rien a lui vendre.', 'error')
        return false
    end
    Player.Functions.AddItem('markedbills', 1, false, { worth = total })
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add')
    notifier(src, ('Vendu : %d unite(s) pour $%d en billets marques.'):format(vendus, total), 'success')
    if math.random(100) <= R.chanceAlerte and GetResourceState('pt-illegal') == 'started' then
        TriggerClientEvent('pt-illegal:client:alerte', src)
    end
    return 'ok'
end)

AddEventHandler('playerDropped', function()
    local src = source
    recoltes[src], transfos[src], derniereVente[src] = nil, nil, nil
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() or not gofast then return end
    for _, p in ipairs(gofast.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    if DoesEntityExist(gofast.veh) then DeleteEntity(gofast.veh) end
    GlobalState.pt_gofast = nil
end)
