lib.versionCheck('Qbox-project/qbx_customs')
local sharedConfig = require 'config.shared'

---@return number
local function getModPrice(mod, level)
    if mod == 'cosmetic' or mod == 'colors' or mod == 18 then
        return sharedConfig.prices[mod] --[[@as number]]
    else
        return sharedConfig.prices[mod][level]
    end
end

---@param source number
---@param amount number
---@return boolean
local function removeMoney(source, amount)
    local player = QbxCore.GetPlayer(source)
    local cashBalance = player.Functions.GetMoney('cash')
    local bankBalance = player.Functions.GetMoney('bank')

    if cashBalance >= amount then
        player.Functions.RemoveMoney('cash', amount, locale('general.payReason'))
        return true
    elseif bankBalance >= amount then
        player.Functions.RemoveMoney('bank', amount, locale('general.payReason'))
        QbxCore.Notify(source, locale('notifications.success.paid', amount), 'success')
        return true
    end

    return false
end

-- LUSO RP : atelier prive d'un bien immobilier de luxe (qbx_properties) = modifications gratuites
local function atelierGratuit(source)
    if GetResourceState('qbx_properties') ~= 'started' then return false end
    local ok, gratuit = pcall(function() return exports.qbx_properties:AtelierGratuit(source) end)
    return ok and gratuit == true
end

-- LUSO RP : montant des travaux faits gratuitement par un mecanicien (a facturer au client ensuite)
local travaux = {}
local function ajouterTravaux(source, montant)
    travaux[source] = (travaux[source] or 0) + (tonumber(montant) or 0)
end
AddEventHandler('playerDropped', function() travaux[source] = nil end)

-- LUSO RP : kit grand angle paye, en attente d'installation (source -> niveau)
local angleAchete = {}

-- Won't charge money for mods if the player's job is in the list
lib.callback.register('qbx_customs:server:pay', function(source, mod, level)
    if mod == 'anglekit' then
        local ok = (function()
            if atelierGratuit(source) then return true end
            local zone = lib.callback.await('qbx_customs:client:zone', source)
            for i, v in ipairs(sharedConfig.zones) do
                if i == zone and v.freeMods then
                    local playerJob = QbxCore.GetPlayer(source)?.PlayerData?.job?.name
                    for _, job in ipairs(v.freeMods) do
                        if playerJob == job then
                            if job == 'mechanic' then ajouterTravaux(source, getModPrice(mod, level)) end
                            return true
                        end
                    end
                end
            end
            return removeMoney(source, getModPrice(mod, level) or 0)
        end)()
        if ok then angleAchete[source] = (tonumber(level) or 1) - 1 end
        return ok
    end
    if atelierGratuit(source) then return true end
    local zone = lib.callback.await('qbx_customs:client:zone', source)

    for i, v in ipairs(sharedConfig.zones) do
        if i == zone and v.freeMods then
            local playerJob = QbxCore.GetPlayer(source)?.PlayerData?.job?.name
            for _, job in ipairs(v.freeMods) do
                if playerJob == job then
                    if job == 'mechanic' then ajouterTravaux(source, getModPrice(mod, level)) end
                    return true
                end
            end
        end
    end

    return removeMoney(source, getModPrice(mod, level))
end)

-- Won't charge money for repairs if the player's job is in the list
lib.callback.register('qbx_customs:server:repair', function(source, bodyHealth)
    if atelierGratuit(source) then return true end
    local zone = lib.callback.await('qbx_customs:client:zone', source)

    for i, v in ipairs(sharedConfig.zones) do
        if i == zone and v.freeRepair then
            local playerJob = QbxCore.GetPlayer(source)?.PlayerData?.job?.name
            for _, job in ipairs(v.freeRepair) do
                if playerJob == job then
                    if job == 'mechanic' then ajouterTravaux(source, math.ceil(1000 - bodyHealth)) end
                    return true
                end
            end
        end
    end

    local price = math.ceil(1000 - bodyHealth)
    return removeMoney(source, price)
end)

local function IsVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {plate})
    if result then
        return true
    else
        return false
    end
end

--Copied from qb-mechanicjob
RegisterNetEvent('qbx_customs:server:saveVehicleProps', function()
    local src = source --[[@as number]]
    -- fin des travaux du mecanicien : proposer la facture du total au client
    if travaux[src] and travaux[src] > 0 then
        if GetResourceState('pt-factures') == 'started' then exports['pt-factures']:ProposerTravaux(src, travaux[src]) end
        travaux[src] = nil
    end
    local vehicleProps = lib.callback.await('qbx_customs:client:vehicleProps', src)
    if IsVehicleOwned(vehicleProps.plate) then
        MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
    end
end)

---------------------------------------------------------------- LUSO RP : kit grand angle (drift)
local function plaqueDe(veh)
    return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

CreateThread(function()
    -- colonne anglekit dans player_vehicles (ajoutee une seule fois)
    local existe = MySQL.query.await("SHOW COLUMNS FROM player_vehicles LIKE 'anglekit'")
    if not existe or not existe[1] then
        MySQL.query.await('ALTER TABLE player_vehicles ADD COLUMN anglekit TINYINT NOT NULL DEFAULT 0')
        print('[qbx_customs] colonne anglekit ajoutee a player_vehicles')
    end
end)

-- installation apres paiement (le niveau doit correspondre a ce qui vient d'etre paye)
RegisterNetEvent('qbx_customs:server:angleKit', function(netId, niveau)
    local src = source
    niveau = tonumber(niveau)
    if niveau == nil or angleAchete[src] ~= niveau then return end
    angleAchete[src] = nil
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 10.0 then return end
    Entity(veh).state:set('ptAngle', niveau, true)
    MySQL.update('UPDATE player_vehicles SET anglekit = ? WHERE plate = ?', { niveau, plaqueDe(veh) })
end)

-- niveau d'un vehicule possede, a la prise du volant
lib.callback.register('qbx_customs:server:angleDuVehicule', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    local etat = Entity(veh).state.ptAngle
    if etat ~= nil then return etat end
    local niveau = MySQL.scalar.await('SELECT anglekit FROM player_vehicles WHERE plate = ?', { plaqueDe(veh) }) or 0
    Entity(veh).state:set('ptAngle', niveau, true)
    return niveau
end)

AddEventHandler('playerDropped', function() angleAchete[source] = nil end)
