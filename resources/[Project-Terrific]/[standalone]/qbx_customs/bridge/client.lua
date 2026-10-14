QBX = { PlayerData = QBCore.Functions.GetPlayerData() or {} }
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() QBX.PlayerData = QBCore.Functions.GetPlayerData() or {} end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) QBX.PlayerData = data end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() QBX.PlayerData = {} end)

QbxCore = {
    Notify = function(msg, typ) QBCore.Functions.Notify(msg, typ or 'primary') end,
}

qbx = qbx or {}
function qbx.playAudio(params)
    PlaySoundFrontend(-1, params.audioName, params.audioRef, true)
end

-- proprietes au format QBCore (lues par qb-garages / qb-vehicleshop)
function QbxGetVehicleProperties(vehicle)
    return QBCore.Functions.GetVehicleProperties(vehicle)
end
