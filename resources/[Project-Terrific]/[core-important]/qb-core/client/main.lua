QBCore = {}
QBCore.PlayerData = {}
QBCore.Config = QBConfig
QBCore.Shared = QBShared
QBCore.ClientCallbacks = {}
QBCore.ServerCallbacks = {}

exports('GetCoreObject', function()
    return QBCore
end)

Citizen.CreateThread(function()

    Citizen.Wait(10000)
    
    -- Print the message
    print("Project Terrific | https://discord.gg/MuFbeK87B4")
	Citizen.Wait(20000)
	print("Project Terrific | https://discord.gg/MuFbeK87B4")
    print("Project Terrific | https://discord.gg/MuFbeK87B4")		
end)

-- To use this export in a script instead of manifest method
-- Just put this line of code below at the very top of the script
-- local QBCore = exports['qb-core']:GetCoreObject()
