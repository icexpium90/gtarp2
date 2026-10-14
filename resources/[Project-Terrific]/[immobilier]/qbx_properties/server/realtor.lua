local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- /createproperty : agent immobilier (metier realestate) ou admin
lib.addCommand('createproperty', {
    help = 'Creer un bien immobilier (maison, entrepot, villa, MLO) a votre position',
}, function(source)
    if not Bridge.IsRealtor(source) then
        return Bridge.Notify(source, 'Reserve aux agents immobiliers et aux admins.', 'error')
    end
    TriggerClientEvent('qbx_properties:client:createProperty', source)
end)

-- interiorIndex : modele de shell (nombre), nom d'interieur du catalogue, ou Bridge.MLO
-- mloCoords : point d'entree interieur (vec4) quand interiorIndex == Bridge.MLO
RegisterNetEvent('qbx_properties:server:createProperty', function(interiorIndex, data, propertyCoords, garageCoords, mloCoords)
    local playerSource = source --[[@as number]]
    if not Bridge.IsRealtor(playerSource) then return end
    local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
    if type(data) ~= 'table' or type(data[1]) ~= 'string' or tonumber(data[2]) == nil then return end

    local interact, stash = {}, {}
    if interiorIndex == Bridge.MLO then
        if not mloCoords then return end
        -- l'agent est a l'interieur du MLO : la sortie est sa position, les autres points se placent ensuite
        if #(playerCoords - vec3(mloCoords.x, mloCoords.y, mloCoords.z)) > 5.0 then return end
        interact[#interact + 1] = { type = 'exit', coords = { x = mloCoords.x, y = mloCoords.y, z = mloCoords.z, w = mloCoords.w } }
    else
        local interior = sharedConfig.interiors[interiorIndex]
        if not interior then return end
        if not garageCoords and #(playerCoords - propertyCoords) > 5.0 then return end
        if garageCoords and #(playerCoords - garageCoords.xyz) > 5.0 then return end
        for _, kind in ipairs({ 'logout', 'clothing', 'exit' }) do
            if interior[kind] then interact[#interact + 1] = { type = kind, coords = interior[kind] } end
        end
        if interior.stash then
            stash[1] = { coords = interior.stash, slots = config.apartmentStash.slots, maxWeight = config.apartmentStash.maxWeight }
        end
    end

    local result = MySQL.single.await('SELECT id FROM properties ORDER BY id DESC', {})
    local propertyNumber = (result and result.id or 0) + 1
    local propertyName = string.format('%s %s', data[1], propertyNumber)

    MySQL.insert.await('INSERT INTO `properties` (`coords`, `property_name`, `price`, `interior`, `interact_options`, `stash_options`, `rent_interval`, `garage`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        json.encode(propertyCoords),
        propertyName,
        math.floor(tonumber(data[2])),
        tostring(interiorIndex),
        json.encode(interact),
        json.encode(stash),
        tonumber(data[3]),
        garageCoords and json.encode(garageCoords) or nil,
    })
    TriggerClientEvent('qbx_properties:client:addProperty', -1, propertyCoords)
    Bridge.Notify(playerSource, ('Bien cree : %s'):format(propertyName), 'success')
end)
