local config = require 'config.server'
local sharedConfig = require 'config.shared'
local logger = Bridge.logger

local enteredProperty = {}
-- MLO : un joueur qui a acces a un bien MLO et se trouve dedans (physiquement, sans passer par la porte)
-- peut gerer ses coffres, son garage et ses ascenseurs. Rempli par server/garage.lua (callback de proximite).
ProcheMLO = {}
function ProprieteActive(src) return enteredProperty[src] or ProcheMLO[src] end
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
            interactions[#interactions + 1] = { type = 'stash', coords = vec3(c.x, c.y, c.z), index = i, label = stashes[i].label,
                model = stashes[i].model, w = stashes[i].coords.w or 0.0 }
        end
    end
    local interactData = json.decode(property.interact_options) or {}
    for i = 1, #interactData do
        if interactData[i].coords then
            local c = isInteriorShell and CalculateOffsetCoords(propertyCoords, interactData[i].coords) or interactData[i].coords
            interactions[#interactions + 1] = { type = interactData[i].type, coords = vec3(c.x, c.y, c.z),
                model = interactData[i].model, w = interactData[i].coords.w or 0.0 }
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
    if RafraichirMLO then RafraichirMLO() end
    local property = MySQL.single.await('SELECT * FROM properties WHERE id = ?', {propertyId})
    if not property or not insideProperty[propertyId] then return end
    local interactions = buildInteractions(property)
    for _, src in ipairs(insideProperty[propertyId]) do
        TriggerClientEvent('qbx_properties:client:updateInteractions', src, interactions, property.interior, type(property.rent_interval) == 'number', false)
    end
end

-- Le proprietaire (ou un agent immobilier / admin) place un point a sa position actuelle
local MODELES_AUTORISES = {}
for _, m in ipairs(sharedConfig.meubles or {}) do if m.model then MODELES_AUTORISES[m.model] = true end end
if sharedConfig.coffreFort then MODELES_AUTORISES[sharedConfig.coffreFort] = true end

-- position envoyee par l'apercu de placement : verifiee (a moins de 12 m du joueur)
local function positionChoisie(src, pos)
    if type(pos) ~= 'table' or not tonumber(pos.x) or not tonumber(pos.y) or not tonumber(pos.z) then return nil end
    local p = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    if #(GetEntityCoords(GetPlayerPed(src)) - p) > 12.0 then return nil end
    return p, tonumber(pos.w) or GetEntityHeading(GetPlayerPed(src))
end

RegisterNetEvent('qbx_properties:server:setInteraction', function(kind, taille, nom, pos, modele, deplacerIndex)
    local src = source
    local propertyId = ProprieteActive(src)
    if not propertyId then return end
    if kind ~= 'stash' and kind ~= 'clothing' and kind ~= 'logout' and kind ~= 'exit' and kind ~= 'safe' then return end
    local player = Bridge.GetPlayer(src)
    local property = MySQL.single.await('SELECT owner, coords, interior, interact_options, stash_options FROM properties WHERE id = ?', {propertyId})
    if not property or not player then return end
    if player.PlayerData.citizenid ~= property.owner and not Bridge.IsRealtor(src) then
        return Bridge.Notify(src, locale('notify.no_access'), 'error')
    end
    local ped = GetPlayerPed(src)
    local pos, heading = positionChoisie(src, pos)
    if not pos then pos, heading = GetEntityCoords(ped), GetEntityHeading(ped) end
    if modele ~= nil and modele ~= '' and not MODELES_AUTORISES[modele] then modele = nil end
    local modeleFinal = (modele and modele ~= '') and modele or nil
    local pc = json.decode(property.coords)
    local point
    if tonumber(property.interior) ~= nil then
        point = { x = pos.x - pc.x, y = pos.y - pc.y, z = pos.z - (pc.z - sharedConfig.shellUndergroundOffset), w = heading }
    else
        point = { x = pos.x, y = pos.y, z = pos.z, w = heading }
    end
    if kind == 'stash' and tonumber(deplacerIndex) then
        -- deplacer un coffre existant (meme contenu)
        local stashes = json.decode(property.stash_options) or {}
        local s = stashes[tonumber(deplacerIndex)]
        if not s then return end
        s.coords = point
        if modele ~= nil then s.model = modeleFinal end
        MySQL.update.await('UPDATE properties SET stash_options = ? WHERE id = ?', { json.encode(stashes), propertyId })
    elseif kind == 'stash' then
        -- un coffre de plus (armes, objets, argent sale en billets marques...), dans la limite de config.coffres.max
        local stashes = json.decode(property.stash_options) or {}
        local cfg = config.coffres
        local placesSansPosition = 0
        for i = 1, #stashes do if not stashes[i].coords then placesSansPosition += 1 end end
        if #stashes - placesSansPosition >= cfg.max then
            return Bridge.Notify(src, ('Maximum %d coffres par bien.'):format(cfg.max), 'error')
        end
        local t = cfg.tailles[taille] or cfg.tailles[cfg.defaut]
        local prochainId = 1
        for i = 1, #stashes do prochainId = math.max(prochainId, (stashes[i].id or 0) + 1) end
        local label = (type(nom) == 'string' and #nom > 0) and nom:sub(1, 30) or t.label
        -- le premier coffre sans position (shell sans coffre place) est reutilise, sinon on en ajoute un
        local reutilise = false
        for i = 1, #stashes do
            if not stashes[i].coords then
                stashes[i] = { coords = point, slots = t.slots, maxWeight = t.maxWeight, label = label, id = stashes[i].id, model = modeleFinal }
                reutilise = true
                break
            end
        end
        if not reutilise then
            -- le tout premier coffre garde l'identifiant historique (sans numero) pour conserver son contenu
            stashes[#stashes + 1] = { coords = point, slots = t.slots, maxWeight = t.maxWeight, label = label, id = #stashes > 0 and prochainId or nil, model = modeleFinal }
        end
        MySQL.update.await('UPDATE properties SET stash_options = ? WHERE id = ?', { json.encode(stashes), propertyId })
    else
        local inter = json.decode(property.interact_options) or {}
        local trouve = false
        for i = 1, #inter do
            if inter[i].type == kind then inter[i].coords = point inter[i].model = modeleFinal trouve = true end
        end
        if not trouve then inter[#inter + 1] = { type = kind, coords = point, model = modeleFinal } end
        MySQL.update.await('UPDATE properties SET interact_options = ? WHERE id = ?', { json.encode(inter), propertyId })
    end
    Bridge.Notify(src, locale('notify.point_placed'), 'success')
    refreshInteractions(propertyId)
end)

BuildPropertyInteractions = buildInteractions

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

ExitProperty = exitProperty
function GetEnteredProperty(src) return ProprieteActive(src) end
function GetPlayersInside(propertyId) return insideProperty[propertyId] or {} end

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

lib.callback.register('qbx_properties:callback:requestProperties', function(source, propertyCoords)
    local liste = MySQL.query.await('SELECT property_name, owner, id, price, rent_interval, keyholders, serrure FROM properties WHERE coords = ?', {json.encode(propertyCoords)}) or {}
    local player = Bridge.GetPlayer(source)
    local cid = player and player.PlayerData.citizenid
    for i = 1, #liste do
        local p = liste[i]
        p.acces = cid ~= nil and (cid == p.owner or lib.table.contains(json.decode(p.keyholders) or {}, cid) or HasPhysicalKey(source, p.id, p.serrure))
        p.serrure = nil
    end
    return liste
end)

local function hasAccess(citizenId, propertyId)
    local property = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})
    if not property then return false end
    if citizenId == property.owner then return true end

    local keyholders = json.decode(property.keyholders) or {}
    for i = 1, #keyholders do
        if citizenId == keyholders[i] then return true end
    end

    return false
end

-- double de cle physique : objet property_key dont les infos designent le bien et la serrure actuelle
function HasPhysicalKey(src, propertyId, serrure)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    if not serrure then
        serrure = MySQL.scalar.await('SELECT serrure FROM properties WHERE id = ?', { propertyId })
    end
    local items = player.Functions.GetItemsByName(Bridge.KeyItem) or {}
    for _, item in pairs(items) do
        local info = item.info or {}
        if tonumber(info.property) == tonumber(propertyId) and tonumber(info.serrure or 1) == tonumber(serrure or 1) then
            return true
        end
    end
    return false
end

-- acces d'un joueur connecte (cle numerique ou double de cle)
function HasPropertyAccess(src, propertyId)
    local player = Bridge.GetPlayer(src)
    if not player then return false end
    return hasAccess(player.PlayerData.citizenid, propertyId) or HasPhysicalKey(src, propertyId)
end

RegisterNetEvent('qbx_properties:server:enterProperty', function(data)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local propertyId = data.id
    if not HasPropertyAccess(playerSource, propertyId) then return end

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
    local propertyId = ProprieteActive(source)
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
    local propertyId = ProprieteActive(source)
    local result = MySQL.single.await('SELECT owner FROM properties WHERE id = ?', {propertyId})
    local owner = Bridge.GetPlayer(source)

    if owner.PlayerData.citizenid ~= result.owner then return end

    local players = insideProperty[propertyId]
    if not players or #players == 0 then
        -- bien MLO gere sur place : joueurs a moins de 15 m
        players = {}
        local pos = GetEntityCoords(GetPlayerPed(source))
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            if id ~= source and #(GetEntityCoords(GetPlayerPed(id)) - pos) < 15.0 then players[#players + 1] = id end
        end
    end
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
    local propertyId = ProprieteActive(source)
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
    local propertyId = ProprieteActive(playerSource)
    local result = MySQL.single.await('SELECT owner, keyholders FROM properties WHERE id = ?', {propertyId})

    if owner.PlayerData.citizenid ~= result.owner then return end

    local keyholders = json.decode(result.keyholders)
    if lib.table.contains(keyholders, keyholderCid) then return end
    keyholders[#keyholders + 1] = keyholderCid
    MySQL.Sync.execute('UPDATE properties SET keyholders = ? WHERE id = ?', {json.encode(keyholders), propertyId})
    SendGaragesToAll()
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
    local propertyId = ProprieteActive(playerSource)

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
    SendGaragesToAll()
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

local function stashIdentifier(propertyName, stash)
    if stash.id then return ('qbx_properties_%s_%s'):format(propertyName, stash.id) end
    return ('qbx_properties_%s'):format(propertyName)
end

RegisterNetEvent('qbx_properties:server:openStash', function(index)
    local playerSource = source --[[@as number]]
    local propertyId = ProprieteActive(playerSource)
    if not propertyId or not HasPropertyAccess(playerSource, propertyId) then return end

    local property = MySQL.single.await('SELECT property_name, stash_options FROM properties WHERE id = ?', {propertyId})
    local stash = (json.decode(property.stash_options) or {})[tonumber(index) or 1] or {}
    TriggerClientEvent('qbx_properties:client:openStash', playerSource, stashIdentifier(property.property_name, stash),
        stash.slots or config.apartmentStash.slots, stash.maxWeight or config.apartmentStash.maxWeight)
end)

-- retire le coffre le plus proche (proprietaire ou agent). Son contenu reste en base : remettre un coffre ne le recupere pas.
RegisterNetEvent('qbx_properties:server:removeStash', function()
    local src = source
    local propertyId = ProprieteActive(src)
    local player = Bridge.GetPlayer(src)
    if not propertyId or not player then return end
    local property = MySQL.single.await('SELECT * FROM properties WHERE id = ?', {propertyId})
    if not property or (player.PlayerData.citizenid ~= property.owner and not Bridge.IsRealtor(src)) then
        return Bridge.Notify(src, locale('notify.no_access'), 'error')
    end
    local interactions = buildInteractions(property)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local meilleur, dist = nil, 3.0
    for _, it in ipairs(interactions) do
        if it.type == 'stash' then
            local d = #(pos - it.coords)
            if d < dist then meilleur, dist = it.index, d end
        end
    end
    if not meilleur then return Bridge.Notify(src, 'Aucun coffre a moins de 3 m.', 'error') end
    local stashes = json.decode(property.stash_options) or {}
    table.remove(stashes, meilleur)
    MySQL.update.await('UPDATE properties SET stash_options = ? WHERE id = ?', { json.encode(stashes), propertyId })
    Bridge.Notify(src, 'Coffre retire.', 'success')
    refreshInteractions(propertyId)
end)

---------------------------------------------------------------- coffre-fort : argent propre (liquide) et argent sale (billets marques)
local function sumMarkedBills(player)
    local total, items = 0, player.Functions.GetItemsByName(Bridge.DirtyItem) or {}
    for _, it in pairs(items) do
        local valeur = tonumber(it.info and it.info.worth) or 0
        total += valeur * (it.amount or 1)
    end
    return total, items
end

lib.callback.register('qbx_properties:callback:listStashes', function(source)
    local propertyId = ProprieteActive(source)
    if not propertyId then return {} end
    local stashes = json.decode(MySQL.scalar.await('SELECT stash_options FROM properties WHERE id = ?', { propertyId }) or '[]') or {}
    local liste = {}
    for i, s in ipairs(stashes) do
        liste[#liste + 1] = { index = i, label = s.label or ('Coffre %d'):format(i), slots = s.slots, model = s.model }
    end
    return liste
end)

lib.callback.register('qbx_properties:callback:getSafe', function(source)
    local propertyId = ProprieteActive(source)
    if not propertyId or not HasPropertyAccess(source, propertyId) then return nil end
    local row = MySQL.single.await('SELECT coffre_propre, coffre_sale FROM properties WHERE id = ?', { propertyId })
    local player = Bridge.GetPlayer(source)
    return { propre = row.coffre_propre or 0, sale = row.coffre_sale or 0,
        liquide = player.PlayerData.money.cash or 0, billets = (sumMarkedBills(player)) }
end)

RegisterNetEvent('qbx_properties:server:safe', function(action, typ, montant)
    local src = source
    local propertyId = ProprieteActive(src)
    local player = Bridge.GetPlayer(src)
    if not propertyId or not player or not HasPropertyAccess(src, propertyId) then return end
    if typ ~= 'propre' and typ ~= 'sale' then return end
    local colonne = typ == 'propre' and 'coffre_propre' or 'coffre_sale'
    local solde = MySQL.scalar.await(('SELECT %s FROM properties WHERE id = ?'):format(colonne), { propertyId }) or 0
    montant = math.floor(tonumber(montant) or 0)

    if action == 'deposer' then
        if typ == 'propre' then
            if montant <= 0 or not player.Functions.RemoveMoney('cash', montant, 'Coffre-fort') then
                return Bridge.Notify(src, 'Pas assez de liquide.', 'error')
            end
        else
            -- tous les billets marques de l'inventaire sont deposes
            local total, items = sumMarkedBills(player)
            if total <= 0 then return Bridge.Notify(src, 'Aucun billet marque sur vous.', 'error') end
            for _, it in pairs(items) do player.Functions.RemoveItem(Bridge.DirtyItem, it.amount, it.slot) end
            montant = total
        end
        MySQL.update.await(('UPDATE properties SET %s = %s + ? WHERE id = ?'):format(colonne, colonne), { montant, propertyId })
        Bridge.Notify(src, ('$%d deposes (%s)'):format(montant, typ == 'propre' and 'argent propre' or 'argent sale'), 'success')
    elseif action == 'retirer' then
        if montant <= 0 or montant > solde then return Bridge.Notify(src, 'Montant invalide.', 'error') end
        local n = MySQL.update.await(('UPDATE properties SET %s = %s - ? WHERE id = ? AND %s >= ?'):format(colonne, colonne, colonne), { montant, propertyId, montant })
        if not n or n == 0 then return end
        if typ == 'propre' then
            player.Functions.AddMoney('cash', montant, 'Coffre-fort')
        elseif not player.Functions.AddItem(Bridge.DirtyItem, 1, false, { worth = montant }) then
            MySQL.update.await(('UPDATE properties SET %s = %s + ? WHERE id = ?'):format(colonne, colonne), { montant, propertyId })
            return Bridge.Notify(src, 'Inventaire plein.', 'error')
        end
        Bridge.Notify(src, ('$%d retires (%s)'):format(montant, typ == 'propre' and 'argent propre' or 'argent sale'), 'success')
    end
    logger.log({ source = src, event = 'qbx_properties:safe', message = ('%s %s %s $%d bien #%d'):format(player.PlayerData.citizenid, action, typ, montant, propertyId) })
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

function SendGaragesToAll()
    if RafraichirMLO then RafraichirMLO() end
    -- les icones "biens possedes" de chaque joueur sont a jour apres tout changement de proprietaire ou de cles
    TriggerClientEvent('qbx_properties:client:rafraichirBlips', -1)
    for _, src in ipairs(GetPlayers()) do sendGarages(tonumber(src)) end
end

local function registerGarage(name, owner, keyholders, garage)
    local id = garageId(name)
    -- bien avec garage physique (places de parking) : les vehicules sont gares sur place, pas de garage qb-garages
    local places = MySQL.scalar.await('SELECT places FROM properties WHERE property_name = ?', { name })
    if places and places ~= '[]' and places ~= '' then propertyGarages[id] = nil return end
    propertyGarages[id] = { label = name, takeVehicle = vec4(garage.x, garage.y, garage.z, garage.w or 0.0), propertyName = name }
end
RegisterPropertyGarage = registerGarage

function PropertyGarageId(name) return garageId(name) end

function UnregisterPropertyGarage(name)
    propertyGarages[garageId(name)] = nil
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
    SendGaragesToAll()
end

-- Libere un bien : plus de proprietaire ni de detenteurs, serrure changee, occupants sortis, garage retire
function ReleaseProperty(propertyId, raison)
    local property = MySQL.single.await('SELECT owner, property_name FROM properties WHERE id = ?', { propertyId })
    if not property then return end
    MySQL.update.await("UPDATE properties SET owner = NULL, keyholders = '[]', next_rent = NULL, impayes = 0, serrure = serrure + 1 WHERE id = ?", { propertyId })
    UnregisterPropertyGarage(property.property_name)
    if insideProperty[propertyId] then
        for _ = 1, #insideProperty[propertyId] do
            exitProperty(insideProperty[propertyId][1])
        end
    end
    SendGaragesToAll()
    if property.owner then
        local ancien = Bridge.GetPlayerByCitizenId(property.owner)
        if ancien and raison then Bridge.Notify(ancien.PlayerData.source, raison, 'error') end
    end
end

-- Preleve un loyer. Retourne true si paye.
local function payerLoyer(property)
    local player = Bridge.GetPlayerByCitizenId(property.owner) or Bridge.GetOfflinePlayer(property.owner)
    if not player then return false end
    local libelle = string.format('Loyer %s', property.property_name)
    if player.Offline then
        if (player.PlayerData.money.bank or 0) < property.price then return false end
        player.PlayerData.money.bank = player.PlayerData.money.bank - property.price
        Bridge.SaveOffline(player.PlayerData)
    else
        if not player.Functions.RemoveMoney('bank', property.price, libelle) then
            Bridge.Notify(player.PlayerData.source, string.format('Pas assez d\'argent en banque pour payer le loyer de %s', property.property_name), 'error')
            return false
        end
        Bridge.Notify(player.PlayerData.source, string.format('%s : $%s preleves', libelle, property.price))
    end
    Bridge.SocietyDeposit(property.price, libelle)
    return true
end

local function verifierLoyers()
    local maintenant = os.time()
    local dus = MySQL.query.await('SELECT id, owner, price, rent_interval, property_name, next_rent, impayes FROM properties WHERE owner IS NOT NULL AND rent_interval IS NOT NULL AND (next_rent IS NULL OR next_rent <= ?)', { maintenant }) or {}
    for _, property in ipairs(dus) do
        if not property.next_rent then
            -- bien loue avant la mise a jour : premiere echeance dans un intervalle
            MySQL.update.await('UPDATE properties SET next_rent = ? WHERE id = ?', { maintenant + property.rent_interval * 3600, property.id })
        elseif payerLoyer(property) then
            MySQL.update.await('UPDATE properties SET next_rent = ?, impayes = 0 WHERE id = ?', { maintenant + property.rent_interval * 3600, property.id })
        else
            local impayes = (property.impayes or 0) + 1
            if impayes >= Bridge.Agence.impayesAvantExpulsion then
                ReleaseProperty(property.id, string.format('Loyers impayes : vous avez ete expulse de %s', property.property_name))
                logger.log({ event = 'qbx_properties:expulsion', message = ('Expulsion pour impayes : %s (%s)'):format(property.property_name, property.owner) })
            else
                -- nouvelle tentative a l'echeance suivante
                MySQL.update.await('UPDATE properties SET next_rent = ?, impayes = ? WHERE id = ?', { maintenant + property.rent_interval * 3600, impayes, property.id })
                local p = Bridge.GetPlayerByCitizenId(property.owner)
                if p then
                    Bridge.Notify(p.PlayerData.source, string.format('Loyer impaye pour %s (%d/%d avant expulsion)', property.property_name, impayes, Bridge.Agence.impayesAvantExpulsion), 'error')
                end
            end
        end
    end
end

CreateThread(function()
    while not PropertiesReady do Wait(1000) end
    Wait(10000)
    while true do
        local ok, err = pcall(verifierLoyers)
        if not ok then print('[qbx_properties] loyers : ' .. tostring(err)) end
        Wait(60000)
    end
end)

RegisterNetEvent('qbx_properties:server:rentProperty', function(propertyId)
    local playerSource = source --[[@as number]]
    local player = Bridge.GetPlayer(playerSource)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    local property = MySQL.single.await('SELECT owner, price, property_name, coords, rent_interval, keyholders, garage FROM properties WHERE id = ?', {propertyId})
    local propertyCoords = json.decode(property.coords)
    if #(playerCoords - vec3(propertyCoords.x, propertyCoords.y, propertyCoords.z)) > 8.0 then return end
    if property.owner then return end
    if not property.rent_interval then return end

    if not Bridge.Agence.achatDirect then
        return Bridge.Notify(playerSource, 'Contactez un agent immobilier pour louer ce bien.', 'error')
    end
    if not player.Functions.RemoveMoney('bank', property.price, string.format('Loyer %s', property.property_name)) then
        Bridge.Notify(playerSource, 'Pas assez d\'argent en banque pour louer ce bien.', 'error')
        return
    end
    Bridge.SocietyDeposit(property.price, string.format('Loyer %s', property.property_name))

    if property.garage then
        registerGarage(property.property_name, player.PlayerData.citizenid, json.decode(property.keyholders), json.decode(property.garage))
    end

    Bridge.Notify(playerSource, string.format('Location de %s commencee', property.property_name), 'success')
    MySQL.update.await('UPDATE properties SET owner = ?, next_rent = ?, impayes = 0 WHERE id = ?', {player.PlayerData.citizenid, os.time() + property.rent_interval * 3600, propertyId})
    SendGaragesToAll()

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
    if not Bridge.Agence.achatDirect then
        return Bridge.Notify(playerSource, 'Contactez un agent immobilier pour acheter ce bien.', 'error')
    end

    if not player.Functions.RemoveMoney('cash', property.price, string.format('Achat %s', property.property_name)) and not player.Functions.RemoveMoney('bank', property.price, string.format('Achat %s', property.property_name)) then
        Bridge.Notify(playerSource, 'Pas assez d\'argent pour acheter ce bien.', 'error')
        return
    end

    if property.garage then
        registerGarage(property.property_name, player.PlayerData.citizenid, json.decode(property.keyholders), json.decode(property.garage))
    end

    Bridge.SocietyDeposit(property.price, string.format('Vente %s', property.property_name))
    MySQL.update.await('UPDATE properties SET owner = ?, next_rent = NULL WHERE id = ?', {player.PlayerData.citizenid, propertyId})
    SendGaragesToAll()
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

    -- colonnes ajoutees par Project Terrific (bases creees avant la mise a jour)
    for colonne, definition in pairs({
        serrure = 'INT NOT NULL DEFAULT 1',
        next_rent = 'BIGINT DEFAULT NULL',
        impayes = 'INT NOT NULL DEFAULT 0',
        coffre_propre = 'BIGINT NOT NULL DEFAULT 0',
        coffre_sale = 'BIGINT NOT NULL DEFAULT 0',
        places = "LONGTEXT NULL",
        ascenseurs = "LONGTEXT NULL",
    }) do
        local existe = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'properties' AND COLUMN_NAME = ?", { colonne })
        if existe == 0 then
            MySQL.query.await(('ALTER TABLE properties ADD COLUMN `%s` %s'):format(colonne, definition))
        end
    end
    PropertiesReady = true

    registerGarages()
end)

RegisterNetEvent('qbx_properties:server:stopRenting', function()
    local player = Bridge.GetPlayer(source)
    local propertyId = enteredProperty[source]
    if not propertyId then return end
    local property = MySQL.single.await('SELECT owner, property_name FROM properties WHERE id = ?', {propertyId})
    if not property or player.PlayerData.citizenid ~= property.owner then return end

    Bridge.Notify(player.PlayerData.source, string.format('Vous avez mis fin a la location de %s', property.property_name), 'success')
    ReleaseProperty(propertyId)

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
