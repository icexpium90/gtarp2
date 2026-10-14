-- Pont serveur : fonctions qbx_core -> QBCore
function Bridge.GetPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

function Bridge.GetPlayerByCitizenId(citizenid)
    return QBCore.Functions.GetPlayerByCitizenId(citizenid)
end

function Bridge.GetOfflinePlayer(citizenid)
    local enLigne = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if enLigne then return enLigne end
    local horsLigne = QBCore.Player.GetOfflinePlayer(citizenid)
    if horsLigne then horsLigne.Offline = true end
    return horsLigne
end

function Bridge.SaveOffline(playerData)
    QBCore.Player.SaveOffline(playerData)
end

function Bridge.Notify(src, message, typ)
    TriggerClientEvent('QBCore:Notify', src, message, typ or 'primary')
end

function Bridge.Logout(src)
    -- le Logout de QBCore 1.2.6 ne sauvegarde pas (contrairement a qbx_core)
    local player = QBCore.Functions.GetPlayer(src)
    if player then player.Functions.Save() end
    QBCore.Player.Logout(src)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end

-- agent immobilier ou admin
function Bridge.IsRealtor(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player and player.PlayerData.job.name == 'realestate' then return true end
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

-- ox_lib 3.6 n'a pas lib.triggerClientEvent
if not lib.triggerClientEvent then
    function lib.triggerClientEvent(eventName, targets, ...)
        if type(targets) == 'table' then
            for _, id in pairs(targets) do TriggerClientEvent(eventName, id, ...) end
        else
            TriggerClientEvent(eventName, targets, ...)
        end
    end
end

-- journal simple (remplace le logger de qbx_core). Activer avec : set qbx_properties:logs 1
Bridge.logger = {
    log = function(data)
        if GetConvarInt('qbx_properties:logs', 0) == 1 then
            print(('[qbx_properties] %s'):format(data.message or data.event or ''))
        end
    end
}
