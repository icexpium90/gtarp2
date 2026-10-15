local QBCore = exports['qb-core']:GetCoreObject()
local timeOut = false

local cachedPoliceAmount = {}
local flags = {}

-- Callback

QBCore.Functions.CreateCallback('qb-jewellery:server:getCops', function(source, cb)
	local amount = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if (v.PlayerData.job.type == "leo") and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cachedPoliceAmount[source] = amount
    cb(amount)
end)

QBCore.Functions.CreateCallback('qb-jewellery:server:getVitrineState', function(_, cb)
	cb(Config.Locations)
end)

-- Functions

-- LUSO RP : plus de bannissement automatique (trop de faux positifs : admins, joueurs legitimes).
-- L'action est refusee, le joueur est prevenu, et l'alerte part dans la console et chez les admins en ligne.
local function signalerExploit(id, raison, ressource)
	local nom = GetPlayerName(id) or tostring(id)
	print(('^3[%s] action suspecte de %s (id %s) : %s (refusee, pas de ban)^7'):format(ressource, nom, tostring(id), tostring(raison)))
	TriggerEvent('qb-log:server:CreateLog', 'bans', 'Action suspecte', 'orange', ('%s (%s) : %s'):format(nom, ressource, tostring(raison)), false)
	TriggerClientEvent('QBCore:Notify', id, 'Action refusee.', 'error')
	for _, sid in pairs(QBCore.Functions.GetPlayers()) do
		if QBCore.Functions.HasPermission(sid, 'admin') and sid ~= id then
			TriggerClientEvent('QBCore:Notify', sid, ('[Anti-triche] %s : %s'):format(nom, tostring(raison)), 'error', 10000)
		end
	end
end

local function exploitBan(id, reason)
	signalerExploit(id, reason, 'qb-jewelery')
end

-- Events

RegisterNetEvent('qb-jewellery:server:setVitrineState', function(stateType, state, k)
    if stateType == "isBusy" and type(state) == "boolean" and Config.Locations[k] then
        Config.Locations[k][stateType] = state
        TriggerClientEvent('qb-jewellery:client:setVitrineState', -1, stateType, state, k)
    end
end)

RegisterNetEvent('qb-jewellery:server:vitrineReward', function(vitrineIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local otherchance = math.random(1, 4)
    local odd = math.random(1, 4)
    local cheating = false

    if Config.Locations[vitrineIndex] == nil or Config.Locations[vitrineIndex].isOpened ~= false then
        exploitBan(src, "Trying to trigger an exploitable event \"qb-jewellery:server:vitrineReward\"")
        return
    end
    if cachedPoliceAmount[source] == nil then
        signalerExploit(src, "vitrineReward sans compteur police", "qb-jewelery")
        return
    end

    local plrPed = GetPlayerPed(src)
    local plrCoords = GetEntityCoords(plrPed)
    local vitrineCoords = Config.Locations[vitrineIndex].coords

    if cachedPoliceAmount[source] >= Config.RequiredCops then
        if plrPed then
            local dist = #(plrCoords - vitrineCoords)
            if dist <= 25.0 then
                Config.Locations[vitrineIndex]["isOpened"] = true
                Config.Locations[vitrineIndex]["isBusy"] = false
                TriggerClientEvent('qb-jewellery:client:setVitrineState', -1, "isOpened", true, vitrineIndex)
                TriggerClientEvent('qb-jewellery:client:setVitrineState', -1, "isBusy", false, vitrineIndex)

                if otherchance == odd then
                    local item = math.random(1, #Config.VitrineRewards)
                    local amount = math.random(Config.VitrineRewards[item]["amount"]["min"], Config.VitrineRewards[item]["amount"]["max"])
                    if Player.Functions.AddItem(Config.VitrineRewards[item]["item"], amount) then
                        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.VitrineRewards[item]["item"]], 'add')
                    else
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.to_much'), 'error')
                    end
                else
                    local amount = math.random(2, 4)
                    if Player.Functions.AddItem("10kgoldchain", amount) then
                        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["10kgoldchain"], 'add')
                    else
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.to_much'), 'error')
                    end
                end
            else
                cheating = true
            end
        end
    else
        cheating = true
    end

    if cheating then
        local license = Player.PlayerData.license
        if flags[license] then
            flags[license] = flags[license] + 1
        else
            flags[license] = 1
        end
        if flags[license] >= 3 then
            exploitBan(src, "Getting flagged many times from exploiting the \"qb-jewellery:server:vitrineReward\" event")
        else
            signalerExploit(src, "vitrineReward suspect", "qb-jewelery")
        end
    end
end)

RegisterNetEvent('qb-jewellery:server:setTimeout', function()
    if not timeOut then
        timeOut = true
        TriggerEvent('qb-scoreboard:server:SetActivityBusy', "jewellery", true)
        Citizen.CreateThread(function()
            Citizen.Wait(Config.Timeout)

            for k, _ in pairs(Config.Locations) do
                Config.Locations[k]["isOpened"] = false
                TriggerClientEvent('qb-jewellery:client:setVitrineState', -1, 'isOpened', false, k)
                TriggerClientEvent('qb-jewellery:client:setAlertState', -1, false)
                TriggerEvent('qb-scoreboard:server:SetActivityBusy', "jewellery", false)
            end
            timeOut = false
        end)
    end
end)
