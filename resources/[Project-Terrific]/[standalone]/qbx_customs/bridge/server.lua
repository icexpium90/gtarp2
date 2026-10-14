QbxCore = {
    GetPlayer = function(src) return QBCore.Functions.GetPlayer(src) end,
    Notify = function(src, msg, typ) TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary') end,
}
