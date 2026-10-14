local QBCore = exports['qb-core']:GetCoreObject()

local function autorise(src)
    if Config.permissionsBased then
        return IsPlayerAceAllowed(src, Config.permissionName)
    end
    if not Config.item then return true end
    local Player = QBCore.Functions.GetPlayer(src)
    return Player ~= nil and Player.Functions.GetItemByName(Config.item) ~= nil
end

RegisterNetEvent('driftmode:demande', function()
    local src = source
    if autorise(src) then
        TriggerClientEvent('driftmode:basculer', src)
    else
        TriggerClientEvent('QBCore:Notify', src,
            Config.permissionsBased and "Vous n'avez pas la permission d'utiliser le mode drift."
                or "Il vous faut une cle de drift (magasin de bricolage).", 'error')
    end
end)
