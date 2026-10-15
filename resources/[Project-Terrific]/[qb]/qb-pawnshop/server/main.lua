local QBCore = exports['qb-core']:GetCoreObject()

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
	signalerExploit(id, reason, 'qb-pawnshop')
end

RegisterNetEvent('qb-pawnshop:server:sellPawnItems', function(itemName, itemAmount, itemPrice)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local totalPrice = (tonumber(itemAmount) * itemPrice)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then exploitBan(src, 'sellPawnItems Exploiting') return end
    if Player.Functions.RemoveItem(itemName, tonumber(itemAmount)) then
        if Config.BankMoney then
            Player.Functions.AddMoney('bank', totalPrice)
        else
            Player.Functions.AddMoney('cash', totalPrice)
        end
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.sold', { value = tonumber(itemAmount), value2 = QBCore.Shared.Items[itemName].label, value3 = totalPrice }),'success')
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
    end
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

RegisterNetEvent('qb-pawnshop:server:meltItemRemove', function(itemName, itemAmount, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.Functions.RemoveItem(itemName, itemAmount) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
        local meltTime = (tonumber(itemAmount) * item.time)
        TriggerClientEvent('qb-pawnshop:client:startMelting', src, item, tonumber(itemAmount), (meltTime * 60000 / 1000))
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.melt_wait', { value = meltTime }), 'primary')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
    end
end)

RegisterNetEvent('qb-pawnshop:server:pickupMelted', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then exploitBan(src, 'pickupMelted Exploiting') return end
    for _, v in pairs(item.items) do
        local meltedAmount = v.amount
        for _, m in pairs(v.item.reward) do
            local rewardAmount = m.amount
            if Player.Functions.AddItem(m.item, (meltedAmount * rewardAmount)) then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[m.item], 'add')
                TriggerClientEvent('QBCore:Notify', src, Lang:t('success.items_received',{ value = (meltedAmount * rewardAmount), value2 = QBCore.Shared.Items[m.item].label }), 'success')
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.inventory_full', { value = QBCore.Shared.Items[m.item].label}), 'warning', 7500)
            end
        end
    end
    TriggerClientEvent('qb-pawnshop:client:resetPickup', src)
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

QBCore.Functions.CreateCallback('qb-pawnshop:server:getInv', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local inventory = Player.PlayerData.items
    return cb(inventory)
end)
