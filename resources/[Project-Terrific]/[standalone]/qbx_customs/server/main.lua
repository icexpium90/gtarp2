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

-- LUSO RP : piece speciale payee, en attente d'installation ([source][piece] = niveau)
local piecesAchetees = {}
local PIECES = sharedConfig.piecesSpeciales

-- Won't charge money for mods if the player's job is in the list
lib.callback.register('qbx_customs:server:pay', function(source, mod, level)
    if PIECES[mod] and mod ~= 'ordre' then
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
        if ok then
            piecesAchetees[source] = piecesAchetees[source] or {}
            piecesAchetees[source][mod] = (tonumber(level) or 1) - 1
        end
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

---------------------------------------------------------------- LUSO RP : pieces speciales (grand angle, kit large, anti-lag)
local function plaqueDe(veh)
    return ((GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

CreateThread(function()
    -- une colonne par piece dans player_vehicles (ajoutee une seule fois)
    for _, piece in ipairs(PIECES.ordre) do
        local col = PIECES[piece].colonne
        local existe = MySQL.query.await(("SHOW COLUMNS FROM player_vehicles LIKE '%s'"):format(col))
        if not existe or not existe[1] then
            MySQL.query.await(('ALTER TABLE player_vehicles ADD COLUMN `%s` TINYINT NOT NULL DEFAULT 0'):format(col))
            print(('[qbx_customs] colonne %s ajoutee a player_vehicles'):format(col))
        end
    end
end)

-- installation apres paiement (le niveau doit correspondre a ce qui vient d'etre paye)
RegisterNetEvent('qbx_customs:server:pieceSpeciale', function(netId, piece, niveau)
    local src = source
    local def = PIECES[piece]
    niveau = tonumber(niveau)
    if not def or piece == 'ordre' or niveau == nil then return end
    if not piecesAchetees[src] or piecesAchetees[src][piece] ~= niveau then return end
    piecesAchetees[src][piece] = nil
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 10.0 then return end
    Entity(veh).state:set(def.etat, niveau, true)
    MySQL.update(('UPDATE player_vehicles SET `%s` = ? WHERE plate = ?'):format(def.colonne), { niveau, plaqueDe(veh) })
end)

-- niveaux d'un vehicule possede : charges une fois dans l'etat du vehicule (visible de tous les joueurs)
lib.callback.register('qbx_customs:server:piecesDuVehicule', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local etat = Entity(veh).state
    if etat[PIECES.anglekit.etat] ~= nil then return true end
    local cols = {}
    for _, piece in ipairs(PIECES.ordre) do cols[#cols + 1] = '`' .. PIECES[piece].colonne .. '`' end
    local ligne = MySQL.single.await(('SELECT %s FROM player_vehicles WHERE plate = ?'):format(table.concat(cols, ', ')), { plaqueDe(veh) }) or {}
    for _, piece in ipairs(PIECES.ordre) do
        etat:set(PIECES[piece].etat, tonumber(ligne[PIECES[piece].colonne]) or 0, true)
    end
    return true
end)

AddEventHandler('playerDropped', function() piecesAchetees[source] = nil end)
