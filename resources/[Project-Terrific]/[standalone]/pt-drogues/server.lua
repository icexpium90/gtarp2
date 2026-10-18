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

RegisterCommand('postedrogue', function(src, args)
    if not estAdmin(src) then return end
    local id = args[1]
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

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() or not gofast then return end
    for _, p in ipairs(gofast.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    if DoesEntityExist(gofast.veh) then DeleteEntity(gofast.veh) end
    GlobalState.pt_gofast = nil
end)
