-- Biens MLO : garage physique (vehicules gares visibles sur leurs places) et ascenseurs entre etages.
-- Les places et les ascenseurs se placent avec le menu proprietaire (F6) > Garage et ascenseurs.
local logger = Bridge.logger
local MAX_PLACES = 30
local RAYON_ACTIF = 150.0     -- les vehicules gares apparaissent quand un joueur est a moins de 150 m
local RAYON_PROCHE = 80.0     -- distance pour gerer un bien MLO sans passer par sa porte

local function notify(src, msg, typ) Bridge.Notify(src, msg, typ) end
local function decode(v) return (v and v ~= '' and json.decode(v)) or {} end

---------------------------------------------------------------- cache des biens MLO (rafraichi toutes les 20 s ou apres un changement)
local cacheMLO, cacheDate = {}, 0
local function biensMLO(force)
    if not force and os.time() - cacheDate < 20 then return cacheMLO end
    local rows = MySQL.query.await("SELECT id, property_name, coords, owner, keyholders, interact_options, stash_options, places, ascenseurs FROM properties WHERE interior = ?", { Bridge.MLO }) or {}
    cacheMLO = {}
    for _, r in ipairs(rows) do
        local c = json.decode(r.coords)
        r.porte = vec3(c.x, c.y, c.z)
        r.places = decode(r.places)
        r.ascenseurs = decode(r.ascenseurs)
        -- centre approximatif du bien : porte, points interieurs, places et etages
        local pts = { r.porte }
        for _, it in ipairs(decode(r.interact_options)) do if it.coords then pts[#pts + 1] = vec3(it.coords.x, it.coords.y, it.coords.z) end end
        for _, p in ipairs(r.places) do pts[#pts + 1] = vec3(p.x, p.y, p.z) end
        for _, a in ipairs(r.ascenseurs) do for _, e in ipairs(a.etages or {}) do pts[#pts + 1] = vec3(e.x, e.y, e.z) end end
        r.points = pts
        cacheMLO[#cacheMLO + 1] = r
    end
    cacheDate = os.time()
    return cacheMLO
end
function RafraichirMLO() cacheDate = 0 end

local function distanceBien(bien, pos)
    local d = math.huge
    for _, p in ipairs(bien.points) do d = math.min(d, #(pos - p)) end
    return d
end

local function accesCid(bien, cid)
    if bien.owner == cid then return true end
    for _, k in ipairs(decode(bien.keyholders)) do if k == cid then return true end end
    return false
end

local function accesJoueur(src, bien)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    return accesCid(bien, player.PlayerData.citizenid) or HasPhysicalKey(src, bien.id) or Bridge.IsRealtor(src)
end

---------------------------------------------------------------- proximite : donnees du bien MLO autour du joueur
lib.callback.register('qbx_properties:callback:proximite', function(source)
    local pos = GetEntityCoords(GetPlayerPed(source))
    local meilleur, dmin = nil, RAYON_PROCHE
    for _, bien in ipairs(biensMLO()) do
        local d = distanceBien(bien, pos)
        if d < dmin and accesJoueur(source, bien) then meilleur, dmin = bien, d end
    end
    if not meilleur then
        ProcheMLO[source] = nil
        return nil
    end
    ProcheMLO[source] = meilleur.id
    local row = MySQL.single.await('SELECT * FROM properties WHERE id = ?', { meilleur.id })
    local interactions = {}
    for _, it in ipairs(BuildPropertyInteractions(row)) do
        if it.type ~= 'exit' then interactions[#interactions + 1] = it end
    end
    local player = Bridge.GetPlayer(source)
    return {
        id = meilleur.id,
        nom = meilleur.property_name,
        proprietaire = player and player.PlayerData.citizenid == meilleur.owner or Bridge.IsRealtor(source),
        interactions = interactions,
        places = meilleur.places,
        ascenseurs = meilleur.ascenseurs,
    }
end)

AddEventHandler('playerDropped', function() ProcheMLO[source] = nil end)

---------------------------------------------------------------- gestion (proprietaire ou agent)
local function bienGere(src)
    local id = ProprieteActive(src)
    if not id then notify(src, 'Placez-vous dans votre bien.', 'error') return nil end
    local row = MySQL.single.await('SELECT id, owner, property_name, interior, places, ascenseurs FROM properties WHERE id = ?', { id })
    local player = Bridge.GetPlayer(src)
    if not row or not player or (row.owner ~= player.PlayerData.citizenid and not Bridge.IsRealtor(src)) then
        notify(src, locale('notify.no_access'), 'error')
        return nil
    end
    row.places = decode(row.places)
    row.ascenseurs = decode(row.ascenseurs)
    return row
end

local function posValide(src, pos)
    if type(pos) ~= 'table' or not tonumber(pos.x) then return nil end
    local p = { x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0, w = (tonumber(pos.w) or 0.0) + 0.0 }
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(p.x, p.y, p.z)) > 15.0 then return nil end
    return p
end

RegisterNetEvent('qbx_properties:server:ajouterPlace', function(pos)
    local src = source
    local bien = bienGere(src)
    if not bien then return end
    if bien.interior ~= Bridge.MLO then return notify(src, 'Garage physique reserve aux biens MLO.', 'error') end
    local p = posValide(src, pos)
    if not p then return end
    if #bien.places >= MAX_PLACES then return notify(src, ('Maximum %d places.'):format(MAX_PLACES), 'error') end
    bien.places[#bien.places + 1] = p
    MySQL.update.await('UPDATE properties SET places = ? WHERE id = ?', { json.encode(bien.places), bien.id })
    -- le garage qb-garages du bien est remplace par le garage physique
    UnregisterPropertyGarage(bien.property_name)
    SendGaragesToAll()
    RafraichirMLO()
    notify(src, ('Place %d ajoutee.'):format(#bien.places), 'success')
end)

RegisterNetEvent('qbx_properties:server:retirerPlace', function()
    local src = source
    local bien = bienGere(src)
    if not bien then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    local idx, dmin = nil, 5.0
    for i, p in ipairs(bien.places) do
        local d = #(pos - vec3(p.x, p.y, p.z))
        if d < dmin then idx, dmin = i, d end
    end
    if not idx then return notify(src, 'Aucune place a moins de 5 m.', 'error') end
    table.remove(bien.places, idx)
    MySQL.update.await('UPDATE properties SET places = ? WHERE id = ?', { json.encode(bien.places), bien.id })
    RafraichirMLO()
    notify(src, 'Place retiree (le vehicule qui y etait reste au garage).', 'success')
end)

RegisterNetEvent('qbx_properties:server:creerAscenseur', function(nom, vehicule, etages)
    local src = source
    local bien = bienGere(src)
    if not bien or type(etages) ~= 'table' or #etages < 2 then return end
    local liste = {}
    for i, e in ipairs(etages) do
        local p = type(e) == 'table' and tonumber(e.x) and { x = e.x + 0.0, y = e.y + 0.0, z = e.z + 0.0, w = (tonumber(e.w) or 0.0) + 0.0 }
        if not p then return end
        p.nom = (type(e.nom) == 'string' and #e.nom > 0) and e.nom:sub(1, 24) or ('Etage %d'):format(i)
        liste[#liste + 1] = p
        if i >= 12 then break end
    end
    bien.ascenseurs[#bien.ascenseurs + 1] = { nom = (type(nom) == 'string' and #nom > 0) and nom:sub(1, 24) or 'Ascenseur', vehicule = vehicule == true, etages = liste }
    MySQL.update.await('UPDATE properties SET ascenseurs = ? WHERE id = ?', { json.encode(bien.ascenseurs), bien.id })
    RafraichirMLO()
    notify(src, ('Ascenseur cree (%d etages).'):format(#liste), 'success')
end)

RegisterNetEvent('qbx_properties:server:supprimerAscenseur', function(index)
    local src = source
    local bien = bienGere(src)
    if not bien or not bien.ascenseurs[tonumber(index) or 0] then return end
    table.remove(bien.ascenseurs, tonumber(index))
    MySQL.update.await('UPDATE properties SET ascenseurs = ? WHERE id = ?', { json.encode(bien.ascenseurs), bien.id })
    RafraichirMLO()
    notify(src, 'Ascenseur supprime.', 'success')
end)

---------------------------------------------------------------- garage physique : vehicules gares visibles
local gares = {}  -- [propertyId] = { [plate] = { entity, place } }

local TYPES = { boats = 'boat', helicopters = 'heli', planes = 'plane', motorcycles = 'bike', cycles = 'bike', trains = 'train' }
local function typeVehicule(modele)
    local v = QBCore.Shared.Vehicles[modele]
    local cat = v and ((v.category or v.categoryLabel or '') .. ''):lower() or ''
    return TYPES[cat] or 'automobile'
end

local function supprimerGares(propertyId)
    for plate, g in pairs(gares[propertyId] or {}) do
        if DoesEntityExist(g.entity) then DeleteEntity(g.entity) end
    end
    gares[propertyId] = nil
end

local function apparaitre(bien, garageNom)
    local liste = MySQL.query.await('SELECT plate, vehicle, hash, mods, fuel, engine, body FROM player_vehicles WHERE garage = ? AND state = 1', { garageNom }) or {}
    gares[bien.id] = gares[bien.id] or {}
    local actuels = gares[bien.id]
    -- places deja prises par un vehicule gare present
    local prises = {}
    for plate, g in pairs(actuels) do
        if DoesEntityExist(g.entity) then prises[g.place] = plate else actuels[plate] = nil end
    end
    for _, v in ipairs(liste) do
        if not actuels[v.plate] then
            local place
            for i = 1, #bien.places do if not prises[i] then place = i break end end
            if not place then break end
            local p = bien.places[place]
            local modele = v.vehicle
            local hash = tonumber(v.hash) or joaat(modele)
            local ok, veh = pcall(CreateVehicleServerSetter, hash, typeVehicule(modele), p.x, p.y, p.z + 0.3, p.w or 0.0)
            if ok and veh and veh ~= 0 then
                local limite = GetGameTimer() + 3000
                while not DoesEntityExist(veh) and GetGameTimer() < limite do Wait(0) end
                if DoesEntityExist(veh) then
                    SetVehicleNumberPlateText(veh, v.plate)
                    SetVehicleDoorsLocked(veh, 2)
                    Entity(veh).state:set('ptGarage', {
                        props = decode(v.mods), plate = v.plate, fuel = v.fuel, engine = v.engine, body = v.body, bien = bien.id,
                    }, true)
                    actuels[v.plate] = { entity = veh, place = place }
                    prises[place] = v.plate
                end
            end
        end
    end
end

CreateThread(function()
    while not PropertiesReady do Wait(1000) end
    Wait(5000)
    while true do
        local joueurs = {}
        for _, id in ipairs(GetPlayers()) do joueurs[#joueurs + 1] = GetEntityCoords(GetPlayerPed(id)) end
        for _, bien in ipairs(biensMLO()) do
            if #bien.places > 0 and bien.owner then
                local actif = false
                for _, pos in ipairs(joueurs) do
                    if distanceBien(bien, pos) < RAYON_ACTIF then actif = true break end
                end
                if actif then
                    local ok, err = pcall(apparaitre, bien, PropertyGarageId(bien.property_name))
                    if not ok then print('[qbx_properties] garage physique : ' .. tostring(err)) end
                elseif gares[bien.id] then
                    supprimerGares(bien.id)
                end
            elseif gares[bien.id] then
                supprimerGares(bien.id)
            end
        end
        Wait(4000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(gares) do supprimerGares(id) end
end)

-- prendre un vehicule gare : cles, deverrouillage, il quitte le garage (state 0)
RegisterNetEvent('qbx_properties:server:prendreVehicule', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local st = Entity(veh).state.ptGarage
    if not st then return end
    local bien
    for _, b in ipairs(biensMLO()) do if b.id == st.bien then bien = b break end end
    if not bien or not accesJoueur(src, bien) then return notify(src, 'Vous n\'avez pas les cles de ce garage.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 6.0 then return end
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { st.plate })
    if gares[bien.id] then gares[bien.id][st.plate] = nil end
    Entity(veh).state:set('ptGarage', nil, true)
    SetVehicleDoorsLocked(veh, 1)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        exports['qb-vehiclekeys']:GiveKeys(src, st.plate)
    end
    TriggerClientEvent('qbx_properties:client:vehiculePris', src, netId, st.fuel)
    notify(src, ('%s : cles recuperees.'):format(st.plate), 'success')
end)

-- garer le vehicule conduit sur une place libre du bien
RegisterNetEvent('qbx_properties:server:garerVehicule', function(netId, props, fuel, engine, body)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or type(props) ~= 'table' then return end
    local pos = GetEntityCoords(veh)
    local bien, place
    for _, b in ipairs(biensMLO()) do
        for i, p in ipairs(b.places) do
            if #(pos - vec3(p.x, p.y, p.z)) < 4.0 then bien, place = b, i break end
        end
        if bien then break end
    end
    if not bien then return notify(src, 'Aucune place de parking ici.', 'error') end
    if not accesJoueur(src, bien) then return notify(src, 'Ce garage ne vous est pas accessible.', 'error') end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local possede = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    if not possede then return notify(src, 'Ce vehicule n\'appartient a personne : impossible de le garer.', 'error') end
    for p2, g in pairs(gares[bien.id] or {}) do
        if g.place == place and DoesEntityExist(g.entity) and g.entity ~= veh then
            return notify(src, 'Cette place est deja occupee.', 'error')
        end
    end
    MySQL.update.await('UPDATE player_vehicles SET state = 1, garage = ?, mods = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {
        PropertyGarageId(bien.property_name), json.encode(props), math.floor(tonumber(fuel) or 100), math.floor(tonumber(engine) or 1000), math.floor(tonumber(body) or 1000), plate,
    })
    -- le vehicule conduit est remplace par la version garee (verrouillee) a la place exacte
    TriggerClientEvent('qbx_properties:client:quitterVehicule', src, netId)
    SetTimeout(2500, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        local ok, err = pcall(apparaitre, bien, PropertyGarageId(bien.property_name))
        if not ok then print('[qbx_properties] garage physique : ' .. tostring(err)) end
    end)
    notify(src, ('%s gare (place %d).'):format(plate, place), 'success')
    logger.log({ source = src, event = 'qbx_properties:garer', message = ('%s gare dans %s'):format(plate, bien.property_name) })
end)
