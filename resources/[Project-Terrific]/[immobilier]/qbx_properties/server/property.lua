local config = require 'config.server'
local sharedConfig = require 'config.shared'
local logger = Bridge.logger

local enteredProperty = {}
local insideProperty = {}
local citizenid = {}
local ring = {}

-- (hook ox_inventory retire : les coffres passent par qb-inventory)

-- Construit la liste des points d'interaction d'une propriete (coffre, sortie, vestiaire, deconnexion)
local function buildInteractions(property)
    local propertyCoords = json.decode(property.coords)
    propertyCoords = vec3(propertyCoords.x, propertyCoords.y, propertyCoords.z)
    local isInteriorShell = tonumber(property.interior) ~= nil
    local interactions, exitCoords = {}, nil
    local stashes = json.decode(property.stash_options) or {}
    for i = 1, #stashes do
        if stashes[i].coords then
            local c = isInteriorShell and CalculateOffsetCoords(propertyCoords, stashes[i].coords) or stashes[i].coords
            interactions[#interactions + 1] = { type = 'stash', coords = vec3(c.x, c.y, c.z) }
        end
    end
    local interactData = json.decode(property.interact_options) or {}
    for i = 1, #interactData do
        if interactData[i].coords then
            local c = isInteriorShell and CalculateOffsetCoords(propertyCoords, interactData[i].coords) or interactData[i].coords
            interactions[#interactions + 1] = { type = interactData[i].type, coords = vec3(c.x, c.y, c.z) }
            if interactData[i].type == 'exit' then exitCoords = c end
        end
    end
    return interactions, exitCoords, propertyCoords, isInteriorShell
end

function EnterProperty(playerSource, id, isSpawn)
    local property = MySQL.single.await('SELECT * FROM properties WHERE id = ?', {id})
    if not property then return end
    local interactions, exitCoords, propertyCoords, isInteriorShell = buildInteractions(property)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    if not isSpawn and #(playerCoords - propertyCoords) > 8.0 then return end

    local player = Bridge.GetPlayer(playerSource)
    citizenid[playerSource] = player.PlayerData.citizenid

    if isInteriorShell then
        TriggerClientEvent('qbx_properties:client:createInterior', playerSource, tonumber(property.interior), vec3(propertyCoords.x, propertyCoords.y, propertyCoords.z - sharedConfig.shellUndergroundOffset))
    end

    if exitCoords then
        SetEntityCoords(GetPlayerPed(playerSource), exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
        SetEntityHeading(GetPlayerPed(playerSource), exitCoords.w or 0.0)
    end

    enteredProperty[playerSource] = id
    insideProperty[id] = insideProperty[id] or {}
    insideProperty[id][#insideProperty[id] + 1] = playerSource
    -- un MLO fait partie du monde : on ne cache pas les autres joueurs
    if property.interior ~= Bridge.MLO then
        lib.triggerClientEvent('qbx_properties:client:concealPlayers', insideProperty[id], insideProperty[id])
    end

    player.Functions.SetMetaData('currentPropertyId', id)

    local decorations =  MySQL.query.await('SELECT `id`, `model`, `coords`, `rotation` FROM `properties_decorations` WHERE `property_id` = ?', {id})
    for i = 1, #decorations do
        local temp = json.decode(decorations[i].coords)
        decorations[i].coords = isInteriorShell and CalculateOffsetCoords(propertyCoords, vec3(temp.x, temp.y, temp.z)) or vec3(temp.x, temp.y, temp.z)
        temp = json.decode(decorations[i].rotation)
        decorations[i].rotation = vec3(temp.x, temp.y, temp.z)
    end

    TriggerClientEvent('qbx_properties:client:loadDecorations', playerSource, decorations)

    TriggerClientEvent('qbx_properties:client:updateInteractions', playerSource, interactions, property.interior, type(property.rent_interval) == 'number', not isInteriorShell)

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:enterProperty',
        message = locale('logs.enter_property', player.PlayerData.citizenid, property.property_name),
        webhook = config.discordWebhook
    })
end

-- Recharge les points d'interaction pour les joueurs deja a l'interieur (apres un deplacement de point)
local function refreshInteractions(propertyId)
    local property = MySQL.single.await('SELECT * FROM properties WHERE id = ?', {propertyId})
    if not property or not insideProperty[propertyId] then return end
    local interactions = buildInteractions(property)
    for _, src in ipairs(insideProperty[propertyId]) do
        TriggerClientEvent('qbx_properties:client:updateInteractions', src, interactions, property.interior, type(property.rent_interval) == 'number', false)
    end
end

-- Le proprietaire (ou un agent immobilier / admin) place un point a sa position actuelle
RegisterNetEvent('qbx_properties:server:setInteraction', function(kind)
    local src = source
    local propertyId = enteredProperty[src]
    if not propertyId then return end
    if kind ~= 'stash' and kind ~= 'clothing' and kind ~= 'logout' and kind ~= 'exit' then return end
    local player = Bridge.GetPlayer(src)
    local property = MySQL.single.await('SELECT owner, coords, interior, interact_options, stash_options FROM properties WHERE id = ?', {propertyId})
    if not property or not player then return end
    if player.PlayerData.citizenid ~= property.owner and not Bridge.IsRealtor(src) then
        return Bridge.Notify(src, locale('notify.no_access'), 'error')
    end
    local ped = GetPlayerPed(src)
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local pc = json.decode(property.coords)
    local point
    if tonumber(property.interior) ~= nil then
        point = { x = pos.x - pc.x, y = pos.y - pc.y, z = pos.z - (pc.z - sharedConfig.shellUndergroundOffset), w = heading }
    else
        point = { x = pos.x, y = pos.y, z = pos.z, w = heading }
    end
    if kind == 'stash' then
        local stashes = json.decode(property.stash_options) or {}
        local actuel = stashes[1] or {}
        stashes = { { coords = point, slots = actuel.slots or config.apartmentStash.slots, maxWeight = actuel.maxWeight or config.apartmentStash.maxWeight } }
        MySQL.update.await('UPDATE properties SET stash_options = ? WHERE id = ?', { json.encode(stashes), propertyId })
    else
        local inter = json.decode(property.interact_options) or {}
        local trouve = false
        for i = 1, #inter do
            if inter[i].type == kind then inter[i].coords = point trouve = true end
        end
        if not trouve then inter[#inter + 1] = { type = kind, coords = point } end
        MySQL.update.await('UPDATE properties SET interact_options = ? WHERE id = ?', { json.encode(inter), propertyId })
    end
    Bridge.Notify(src, locale('notify.point_placed'), 'success')
    refreshInteractions(propertyId)
end)

---@param playerSource integer
local function exitProperty(playerSource, isLogout)
    if not enteredProperty[playerSource] then return end

    TriggerClientEvent('qbx_properties:client:unloadProperty', playerSource)
    TriggerClientEvent('qbx_properties:client:revealPlayers', playerSource)

    if not isLogout then
        local enterCoords = json.decode(MySQL.single.await('SELECT coords FROM properties WHERE id = ?', {enteredProperty[playerSource]}).coords)
        SetEntityCoords(GetPlayerPed(playerSource), enterCoords.x, enterCoords.y, enterCoords.z, false, false, false, false)
    end

    for i = 1, #insideProperty[enteredProperty[playerSource]] do
        if insideProperty[enteredProperty[playerSource]][i] == playerSource then
            table.remove(insideProperty[enteredProperty[playerSource]], i)
            break
        end
    end

    lib.triggerClientEvent('qbx_properties:client:concealPlayers', insideProperty[enteredProperty[playerSource]], insideProperty[enteredProperty[playerSource]])
    local logPropertyId = enteredProperty[playerSource]
    enteredProperty[playerSource] = nil

    if isLogout then return end

    local player = Bridge.GetPlayer(playerSource)
    if not player then return end

    player.Functions.SetMetaData('currentPropertyId', nil)

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:exitProperty',
        message = locale('logs.exit_property', player.PlayerData.citizenid, logPropertyId),
        webhook = config.discordWebhook
    })
end

RegisterNetEvent('qbx_properties:server:exitProperty', function()
    exitProperty(source --[[@as number]])
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    exitProperty(source, true)
end)

lib.callback.register('qbx_properties:callback:loadProperties', function()
    local result = MySQL.query.await('SELECT coords FROM properties GROUP BY coords')
    local properties = {}
    for i = 1, #result do
        local coords = json.decode(result[i].coords)
        properties[i] = vec3(coords.x, coords.y, coords.z)
    end

    return properties
end)

lib.callback.register('qbx_properties:callback:requestProperties', function(_, propertyCoords)
    return MySQL.query.await('SELECT property_name, owner, id, price, rent_interval, keyholders FROM properties WHERE coords = ?', {json.encode(propertyCoords)})
end)

local function hasAccess(citizenId, propertyId)
    local property = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})
    if citizenId == property.owner then return true end

    local keyholders = json.decode(property.keyholders)
    for i = 1, #keyholders do
        if citizenId == keyholders[i] then return true end
    end

    return false
end

RegisterNetEvent('qbx_properties:server:enterProperty', function(data)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local propertyId = data.id
    if not hasAccess(player.PlayerData.citizenid, propertyId) then return end

    EnterProperty(playerSource, propertyId, data.isSpawn)
end)

RegisterNetEvent('qbx_properties:server:ringProperty', function(data)
    local playerSource = source --[[@as number]]
    local propertyId = data.id
    local property = MySQL.single.await('SELECT owner FROM properties WHERE id = ?', {propertyId})
    local owner = Bridge.GetPlayerByCitizenId(property.owner)

    ring[propertyId] = ring[propertyId] or {}
    if not lib.table.contains(ring[propertyId], playerSource) then
        ring[propertyId][#ring[propertyId] + 1] = playerSource
        SetTimeout(300000, function()
            for i = 1, #ring[propertyId] do
                if ring[propertyId][i] == playerSource then
                    table.remove(ring[propertyId], i)
                    break
                end
            end
        end)
    end
    if owner and enteredProperty[owner.PlayerData.source] == propertyId then
        Bridge.Notify(owner.PlayerData.source, locale('notify.someone_at_door'))
    end
end)

lib.callback.register('qbx_properties:callback:requestKeyHolders', function(source)
    local propertyId = enteredProperty[source]
    local result = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})
    local player = Bridge.GetPlayer(source)

    if player.PlayerData.citizenid ~= result.owner then return end

    local keyholders = json.decode(result.keyholders)
    local currentholders = {}
    for i = 1, #keyholders do
        local offlinePlayer = Bridge.GetOfflinePlayer(keyholders[i])
        if offlinePlayer then
            currentholders[#currentholders + 1] = {
                citizenid = offlinePlayer.PlayerData.citizenid,
                name = offlinePlayer.PlayerData.charinfo.firstname .. ' ' .. offlinePlayer.PlayerData.charinfo.lastname
            }
        end
    end
    return currentholders
end)

lib.callback.register('qbx_properties:callback:requestPotentialKeyholders', function(source)
    local propertyId = enteredProperty[source]
    local result = MySQL.single.await('SELECT owner FROM properties WHERE id = ?', {propertyId})
    local owner = Bridge.GetPlayer(source)

    if owner.PlayerData.citizenid ~= result.owner then return end

    local players = insideProperty[propertyId]
    local insidePlayers = {}
    for i = 1, #players do
        local player = Bridge.GetPlayer(players[i])
        if player and not hasAccess(player.PlayerData.citizenid, propertyId) then
            insidePlayers[#insidePlayers + 1] = {
                citizenid = player.PlayerData.citizenid,
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            }
        end
    end
    return insidePlayers
end)

lib.callback.register('qbx_properties:callback:requestRingers', function(source)
    local propertyId = enteredProperty[source]
    local players = ring[propertyId] or {}
    local ringers = {}
    for i = 1, #players do
        local player = Bridge.GetPlayer(players[i])
        if player then
            ringers[#ringers + 1] = {
                citizenid = player.PlayerData.citizenid,
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            }
        end
    end
    return ringers
end)

lib.callback.register('qbx_properties:callback:checkAccess', function(source)
    local propertyId = enteredProperty[source]
    local result = MySQL.single.await('SELECT owner FROM properties WHERE id = ?', {propertyId})
    if not result then return false end
    return result.owner == Bridge.GetPlayer(source).PlayerData.citizenid or Bridge.IsRealtor(source)
end)

RegisterNetEvent('qbx_properties:server:letRingerIn', function(visitorCid)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local propertyId = enteredProperty[playerSource]
    local result = MySQL.single.await('SELECT owner, interior FROM properties WHERE id = ?', {propertyId})

    if player.PlayerData.citizenid ~= result.owner then return end

    local visitor = Bridge.GetPlayerByCitizenId(visitorCid)
    if not visitor then return end

    EnterProperty(visitor.PlayerData.source, propertyId)
    for i = 1, #ring[propertyId] do
        if ring[propertyId][i] == visitor.PlayerData.source then
            table.remove(ring[propertyId], i)
            break
        end
    end
end)

RegisterNetEvent('qbx_properties:server:addKeyholder', function(keyholderCid)
    local playerSource = source --[[@as number]]
    local owner = Bridge.GetPlayer(playerSource)
    local propertyId = enteredProperty[playerSource]
    local result = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})

    if owner.PlayerData.citizenid ~= result.owner then return end

    local keyholders = json.decode(result.keyholders)
    if lib.table.contains(keyholders, keyholderCid) then return end
    keyholders[#keyholders + 1] = keyholderCid
    MySQL.Sync.execute('UPDATE properties SET keyholders = ? WHERE id = ?', {json.encode(keyholders), propertyId})
    sendGaragesToAll()
    local keyholder = Bridge.GetPlayerByCitizenId(keyholderCid)
    if not keyholder then return end
    Bridge.Notify(playerSource, keyholder.PlayerData.charinfo.firstname.. locale('notify.keyholder'))
    Bridge.Notify(keyholder.PlayerData.source, locale('notify.added_as_keyholder'))

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:addKeyholder',
        message = locale('logs.added_keyholder', keyholderCid, propertyId),
        webhook = config.discordWebhook
    })
end)

RegisterNetEvent('qbx_properties:server:removeKeyholder', function(keyholderCid)
    local playerSource = source --[[@as number]]
    local owner = Bridge.GetPlayer(playerSource)
    local propertyId = enteredProperty[playerSource]

    local result = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})
    if owner.PlayerData.citizenid ~= result.owner then return end

    local keyholders = json.decode(result.keyholders)
    if not lib.table.contains(keyholders, keyholderCid) then return end

    for i = 1, #keyholders do
        if keyholders[i] == keyholderCid then
            table.remove(keyholders, i)
            break
        end
    end

    MySQL.Sync.execute('UPDATE properties SET keyholders = ? WHERE id = ?', {json.encode(keyholders), propertyId})
    sendGaragesToAll()
    local keyholder = Bridge.GetOfflinePlayer(keyholderCid)
    if not keyholder then return end
    Bridge.Notify(playerSource, keyholder.PlayerData.charinfo.firstname.. locale('notify.removed_as_keyholder'))

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:removeKeyholder',
        message = locale('logs.removed_keyholder', keyholderCid, propertyId),
        webhook = config.discordWebhook
    })
end)

RegisterNetEvent('qbx_properties:server:logoutProperty', function()
    local playerSource = source --[[@as number]]
    local propertyId = enteredProperty[playerSource]
    if not propertyId then return end

    local result = MySQL.single.await('SELECT owner, coords FROM properties WHERE id = ?', {propertyId})
    local player = Bridge.GetPlayer(playerSource)
    if player.PlayerData.citizenid ~= result.owner then return end

    TriggerClientEvent('qbx_properties:client:unloadProperty', playerSource)
    TriggerClientEvent('qbx_properties:client:revealPlayers', playerSource)
    for i = 1, #insideProperty[enteredProperty[playerSource]] do
        if insideProperty[enteredProperty[playerSource]][i] == playerSource then
            table.remove(insideProperty[enteredProperty[playerSource]], i)
            break
        end
    end

    lib.triggerClientEvent('qbx_properties:client:concealPlayers', insideProperty[enteredProperty[playerSource]], insideProperty[enteredProperty[playerSource]])
    enteredProperty[playerSource] = nil
    Bridge.Logout(playerSource)
    Wait(50)
    local coords = json.decode(result.coords)
    MySQL.update('UPDATE players SET position = ? WHERE citizenid = ?', { json.encode(vec4(coords.x, coords.y, coords.z, 0.0)), player.PlayerData.citizenid })
end)

RegisterNetEvent('qbx_properties:server:openStash', function()
    local playerSource = source --[[@as number]]
    local propertyId = enteredProperty[playerSource]
    local player = Bridge.GetPlayer(playerSource)
    if not hasAccess(player.PlayerData.citizenid, propertyId) then return end

    local property = MySQL.single.await('SELECT property_name, stash_options FROM properties WHERE id = ?', {propertyId})
    local stash = (json.decode(property.stash_options) or {})[1] or {}
    TriggerClientEvent('qbx_properties:client:openStash', playerSource, string.format('qbx_properties_%s', property.property_name),
        stash.slots or config.apartmentStash.slots, stash.maxWeight or config.apartmentStash.maxWeight)
end)

AddEventHandler('playerDropped', function ()
    local playerSource = source --[[@as number]]

    if not enteredProperty[playerSource] then return end

    for i = 1, #insideProperty[enteredProperty[playerSource]] do
        if insideProperty[enteredProperty[playerSource]][i] == playerSource then
            table.remove(insideProperty[enteredProperty[playerSource]], i)
            break
        end
    end

    Wait(50)
    local coords = json.decode(MySQL.single.await('SELECT coords FROM properties WHERE id = ?', {enteredProperty[playerSource]}).coords)
    MySQL.update('UPDATE players SET position = ? WHERE citizenid = ?', { json.encode(vec4(coords.x, coords.y, coords.z, 0.0)), citizenid[playerSource] })
end)

function canAccessCid(cid, owner, keyholders)
    if cid == owner then return true end
    for i = 1, #keyholders do
        if cid == keyholders[i] then return true end
    end
    return false
end

-- Garages de propriete : branches sur qb-garages (garages de type "house")
local propertyGarages = {} -- [garageId] = { label, takeVehicle, propertyName }

local function garageId(name)
    return 'property_' .. string.gsub(string.lower(name), '[^%w]', '_')
end

local function garageConfig()
    local cfg = {}
    for id, g in pairs(propertyGarages) do cfg[id] = { label = g.label, takeVehicle = g.takeVehicle } end
    return cfg
end

-- garages auxquels un joueur a acces (proprietaire ou detenteur de cle)
local function accessibleGarages(cid)
    local liste = {}
    for id, g in pairs(propertyGarages) do
        local p = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE property_name = ?', { g.propertyName })
        if p and canAccessCid(cid, p.owner, json.decode(p.keyholders) or {}) then
            liste[#liste + 1] = { id = id, coords = g.takeVehicle }
        end
    end
    return liste
end

local function sendGarages(src)
    local player = Bridge.GetPlayer(src)
    if not player then return end
    TriggerClientEvent('qb-garages:client:houseGarageConfig', src, garageConfig())
    TriggerClientEvent('qbx_properties:client:setGarages', src, accessibleGarages(player.PlayerData.citizenid))
end

local function sendGaragesToAll()
    for _, src in ipairs(GetPlayers()) do sendGarages(tonumber(src)) end
end

local function registerGarage(name, owner, keyholders, garage)
    local id = garageId(name)
    propertyGarages[id] = { label = name, takeVehicle = vec4(garage.x, garage.y, garage.z, garage.w or 0.0), propertyName = name }
end

-- utilise par qb-garages pour verifier l'acces a un garage de propriete
exports('HasGarageAccess', function(cid, id)
    local g = propertyGarages[id]
    if not g then return false end
    local p = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE property_name = ?', { g.propertyName })
    return p ~= nil and canAccessCid(cid, p.owner, json.decode(p.keyholders) or {})
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    sendGarages(source)
end)
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then sendGarages(Player.PlayerData.source) end
end)

local function registerGarages()
    local properties = MySQL.query.await('SELECT property_name, owner, keyholders, garage FROM properties WHERE owner IS NOT NULL AND garage IS NOT NULL')
    if not properties then return end
    for i = 1, #properties do
        local property = properties[i]
        registerGarage(property.property_name, property.owner, json.decode(property.keyholders), json.decode(property.garage))
    end
    sendGaragesToAll()
end

local function startRentThread(propertyId)
    CreateThread(function()
        while true do
            local property = MySQL.single.await('SELECT owner, price, rent_interval, property_name FROM properties WHERE id = ?', {propertyId})
            if not property or not property.owner then break end

            local player = Bridge.GetPlayerByCitizenId(property.owner) or Bridge.GetOfflinePlayer(property.owner)
            if not player then print(string.format('%s does not exist anymore, consider checking property id %s', property.owner, propertyId)) break end

            if player.Offline then
                player.PlayerData.money.bank = player.PlayerData.money.bank - property.price
                if player.PlayerData.money.bank < 0 then break end
                Bridge.SaveOffline(player.PlayerData)
            else
                if not player.Functions.RemoveMoney('bank', property.price, string.format('Loyer %s', property.property_name)) then
                    Bridge.Notify(player.PlayerData.source, string.format('Pas assez d\'argent en banque pour payer le loyer de %s', property.property_name), 'error')
                    break
                end
            end

            Wait(property.rent_interval * 3600000)
        end

        MySQL.update('UPDATE properties SET owner = ? WHERE id = ?', {nil, propertyId})
    end)
end

RegisterNetEvent('qbx_properties:server:rentProperty', function(propertyId)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    local property = MySQL.single.await('SELECT owner, price, property_name, coords, rent_interval, keyholders, garage FROM properties WHERE id = ?', {propertyId})
    local propertyCoords = json.decode(property.coords)
    if #(playerCoords - vec3(propertyCoords.x, propertyCoords.y, propertyCoords.z)) > 8.0 then return end
    if property.owner then return end
    if not property.rent_interval then return end

    if player.PlayerData.money.bank < property.price then
        Bridge.Notify(playerSource, 'Pas assez d\'argent en banque pour louer ce bien.', 'error')
        return
    end

    if property.garage then
        registerGarage(property.property_name, player.PlayerData.citizenid, json.decode(property.keyholders), json.decode(property.garage))
    end

    Bridge.Notify(playerSource, string.format('Location de %s commencee', property.property_name), 'success')
    MySQL.update.await('UPDATE properties SET owner = ? WHERE id = ?', {player.PlayerData.citizenid, propertyId})
    sendGaragesToAll()
    startRentThread(propertyId)

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:rentProperty',
        message = locale('logs.rent_property', player.PlayerData.citizenid, propertyId),
        webhook = config.discordWebhook
    })
end)

RegisterNetEvent('qbx_properties:server:buyProperty', function(propertyId)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    local property = MySQL.single.await('SELECT owner, price, property_name, coords, keyholders, garage FROM properties WHERE id = ?', {propertyId})
    local propertyCoords = json.decode(property.coords)

    if #(playerCoords - vec3(propertyCoords.x, propertyCoords.y, propertyCoords.z)) > 8.0 or property.owner then return end

    if not player.Functions.RemoveMoney('cash', property.price, string.format('Achat %s', property.property_name)) and not player.Functions.RemoveMoney('bank', property.price, string.format('Achat %s', property.property_name)) then
        Bridge.Notify(playerSource, 'Pas assez d\'argent pour acheter ce bien.', 'error')
        return
    end

    if property.garage then
        registerGarage(property.property_name, player.PlayerData.citizenid, json.decode(property.keyholders), json.decode(property.garage))
    end

    MySQL.update.await('UPDATE properties SET owner = ? WHERE id = ?', {player.PlayerData.citizenid, propertyId})
    sendGaragesToAll()
    Bridge.Notify(playerSource, string.format('Vous avez achete %s pour $%s', property.property_name, property.price), 'success')

    logger.log({
        source = playerSource,
        event = 'qbx_properties:server:buyProperty',
        message = locale('logs.buy_property', player.PlayerData.citizenid, propertyId),
        webhook = config.discordWebhook
    })
end)

Citizen.CreateThreadNow(function()
    local sql1 = LoadResourceFile(cache.resource, 'property.sql')
    local sql2 = LoadResourceFile(cache.resource, 'decorations.sql')
    local sql3 = LoadResourceFile(cache.resource, 'property_garages.sql')
    if not sql3 or sql3:gsub('%s', '') == '' then sql3 = nil end

    MySQL.query.await(sql1)
    MySQL.query.await(sql2)
    if sql3 then MySQL.query.await(sql3) end

    local properties = MySQL.query.await('SELECT id FROM properties WHERE owner IS NOT NULL AND rent_interval IS NOT NULL')
    for i = 1, #properties do
        startRentThread(properties[i].id)
    end

    registerGarages()
end)

RegisterNetEvent('qbx_properties:server:stopRenting', function()
    local player = Bridge.GetPlayer(source)
    local propertyId = enteredProperty[source]
    local property = MySQL.single.await('SELECT owner, property_name FROM properties WHERE id = ?', {propertyId})
    if player.PlayerData.citizenid ~= property.owner then return end

    Bridge.Notify(player.PlayerData.source, string.format('Vous avez mis fin a la location de %s', property.property_name), 'success')
    MySQL.update.await('UPDATE properties SET owner = ?, keyholders = JSON_OBJECT() WHERE id = ?', {nil, propertyId})
    for _ = 1, #insideProperty[propertyId] do
        exitProperty(insideProperty[propertyId][1])
    end

    logger.log({
        source = player.PlayerData.source,
        event = 'qbx_properties:server:stopRenting',
        message = locale('logs.stop_renting', player.PlayerData.citizenid, propertyId),
        webhook = config.discordWebhook
    })
end)

RegisterNetEvent('qbx_properties:server:addDecoration', function(hash, coords, rotation, objectId)
    local player = Bridge.GetPlayer(source)
    local propertyId = enteredProperty[source]
    local property = MySQL.single.await('SELECT owner, property_name FROM properties WHERE id = ?', {propertyId})
    if player.PlayerData.citizenid ~= property.owner then return end

    if objectId then
        lib.triggerClientEvent('qbx_properties:client:removeDecoration', insideProperty[propertyId], objectId)
        MySQL.update.await('UPDATE properties_decorations SET coords = ?, rotation = ? WHERE id = ?', { json.encode(coords), json.encode(rotation), objectId })
        lib.triggerClientEvent('qbx_properties:client:addDecoration', insideProperty[propertyId], objectId, hash, coords, rotation)
    else
        local id = MySQL.insert.await('INSERT INTO `properties_decorations` (property_id, model, coords, rotation) VALUES (?, ?, ?, ?)', {propertyId, hash, json.encode(coords), json.encode(rotation)})
        lib.triggerClientEvent('qbx_properties:client:addDecoration', insideProperty[propertyId], id, hash, coords, rotation)
    end

    logger.log({
        source = player.PlayerData.source,
        event = 'qbx_properties:server:addDecoration',
        message = locale('logs.add_decoration', player.PlayerData.citizenid, hash, propertyId),
        webhook = config.discordWebhook
    })
end)

RegisterNetEvent('qbx_properties:server:removeDecoration', function(objectId)
    local player = Bridge.GetPlayer(source)
    local propertyId = enteredProperty[source]
    local property = MySQL.single.await('SELECT owner FROM properties WHERE id = ?', {propertyId})
    if player.PlayerData.citizenid ~= property.owner then return end

    MySQL.query.await('DELETE FROM properties_decorations WHERE id = ?', {objectId})
    lib.triggerClientEvent('qbx_properties:client:removeDecoration', insideProperty[propertyId], objectId)

    logger.log({
        source = player.PlayerData.source,
        event = 'qbx_properties:server:removeDecoration',
        message = locale('logs.remove_decoration', player.PlayerData.citizenid, objectId, propertyId),
        webhook = config.discordWebhook
    })
end)
