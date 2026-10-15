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

Bridge.Agence = require('config.server').agence
Bridge.KeyItem = 'property_key'
Bridge.DirtyItem = 'markedbills' -- argent sale (billets marques, valeur dans info.worth)

function Bridge.IsAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

-- agent immobilier (metier realestate, en service) ou admin
function Bridge.IsRealtor(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player and player.PlayerData.job.name == Bridge.Agence.job and player.PlayerData.job.onduty ~= false then return true end
    return Bridge.IsAdmin(src)
end

-- grade de l'agent dans l'agence (les admins ont tous les droits)
function Bridge.RealtorGrade(src)
    if Bridge.IsAdmin(src) then return 99 end
    local player = QBCore.Functions.GetPlayer(src)
    if not player or player.PlayerData.job.name ~= Bridge.Agence.job then return -1 end
    return tonumber(player.PlayerData.job.grade and player.PlayerData.job.grade.level) or 0
end

-- argent encaisse par l'agence (compte de societe qb-management)
function Bridge.SocietyDeposit(montant, raison)
    montant = math.floor(tonumber(montant) or 0)
    if montant <= 0 or not Bridge.Agence.societe then return end
    if GetResourceState('qb-management') == 'started' then
        exports['qb-management']:AddMoney(Bridge.Agence.societe, montant)
    end
    Bridge.logger.log({ message = ('Agence : +$%d (%s)'):format(montant, raison or '') })
end

-- ox_lib 3.6 n'a pas lib.triggerClientEvent. Attention : "lib.triggerClientEvent" n'est jamais nil (ox_lib renvoie un appel
-- vers un export inexistant -> "No such export triggerClientEvent"), on le definit donc toujours ici.
rawset(lib, 'triggerClientEvent', function(eventName, targets, ...)
    if targets == nil then return end
    if type(targets) == 'table' then
        for _, id in pairs(targets) do TriggerClientEvent(eventName, id, ...) end
    else
        TriggerClientEvent(eventName, targets, ...)
    end
end)

-- journal simple (remplace le logger de qbx_core). Activer avec : set qbx_properties:logs 1
Bridge.logger = {
    log = function(data)
        if GetConvarInt('qbx_properties:logs', 0) == 1 then
            print(('[qbx_properties] %s'):format(data.message or data.event or ''))
        end
    end
}
