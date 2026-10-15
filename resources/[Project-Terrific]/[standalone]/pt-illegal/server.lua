local QBCore = exports['qb-core']:GetCoreObject()

local dernierAchatPoint = {}     -- [id du point] = os.time()
local dernierBlanchiment = {}    -- [citizenid] = os.time()

local function notifier(src, texte, genre)
    TriggerClientEvent('QBCore:Notify', src, texte, genre or 'primary', 6000)
end

local function estAdmin(src)
    return src == 0 or QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
        or IsPlayerAceAllowed(src, 'command')
end

-- ---------------------------------------------------------------------------------------------------------------
-- Positions des PNJ (config, ou position choisie par un admin, gardee en KVP)

local pnj = {}
local function enregistrer(id, coords, ped, typ, label)
    local kvp = GetResourceKvpString('pos_' .. id)
    if kvp then
        local p = json.decode(kvp)
        if p then coords = vector4(p.x, p.y, p.z, p.w) end
    end
    pnj[id] = { id = id, coords = { x = coords.x, y = coords.y, z = coords.z, w = coords.w }, ped = ped, type = typ, label = label }
end

for _, d in ipairs(Config.PointsDeal) do enregistrer(d.id, d.coords, d.ped, 'deal', d.label) end
enregistrer('blanchisseur', Config.Blanchisseur.coords, Config.Blanchisseur.ped, 'blanchisseur', 'Blanchisseur')
enregistrer('armurier', Config.Armurier.coords, Config.Armurier.ped, 'armurier', 'Armurier clandestin')
GlobalState.pt_illegal_pnj = pnj

local function proche(src, id, distance)
    local p = pnj[id]
    if not p then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(p.coords.x, p.coords.y, p.coords.z)) < (distance or 4.0)
end

RegisterCommand('pnjillegal', function(src, args)
    if not estAdmin(src) then return end
    local id = args[1]
    if not id then
        for k, p in pairs(pnj) do
            local t = ('%s (%s) : %.1f, %.1f, %.1f'):format(k, p.label, p.coords.x, p.coords.y, p.coords.z)
            if src == 0 then print(t) else TriggerClientEvent('chat:addMessage', src, { args = { 'PNJ', t } }) end
        end
        return
    end
    if src == 0 or not pnj[id] then
        if src ~= 0 then notifier(src, 'Nom inconnu. /pnjillegal sans argument pour la liste.', 'error') end
        return
    end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local pos = { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
    SetResourceKvp('pos_' .. id, json.encode(pos))
    pnj[id].coords = pos
    GlobalState.pt_illegal_pnj = pnj
    notifier(src, ('%s deplace ici (garde apres redemarrage).'):format(pnj[id].label), 'success')
end, false)

-- ---------------------------------------------------------------------------------------------------------------
-- Vente de drogue a un point de deal

RegisterNetEvent('pt-illegal:server:vendre', function(id)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not pnj[id] or pnj[id].type ~= 'deal' or not proche(src, id) then return end
    if dernierAchatPoint[id] and os.time() - dernierAchatPoint[id] < Config.DelaiPoint then
        return notifier(src, 'Il n\'a besoin de rien pour le moment. Repasse plus tard.', 'error')
    end
    local reste = Config.MaxParVente
    local total, vendus = 0, 0
    for nom, prix in pairs(Config.Drogues) do
        if reste <= 0 then break end
        local item = Player.Functions.GetItemByName(nom)
        local qte = item and math.min(item.amount, reste) or 0
        if qte > 0 and Player.Functions.RemoveItem(nom, qte) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[nom], 'remove', qte)
            for _ = 1, qte do total = total + math.random(prix.min, prix.max) end
            vendus = vendus + qte
            reste = reste - qte
        end
    end
    if vendus == 0 then
        return notifier(src, 'Tu n\'as rien qui l\'interesse.', 'error')
    end
    dernierAchatPoint[id] = os.time()
    Player.Functions.AddItem('markedbills', 1, false, { worth = total })
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add')
    notifier(src, ('Vendu : %d unite(s) pour $%d en billets marques.'):format(vendus, total), 'success')
    if math.random(100) <= Config.ChanceAlertePolice then
        TriggerClientEvent('pt-illegal:client:alerte', src)
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Blanchisseur : billets marques -> liquide propre

RegisterNetEvent('pt-illegal:server:blanchir', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not proche(src, 'blanchisseur') then return end
    local cid = Player.PlayerData.citizenid
    local cfg = Config.Blanchisseur
    if dernierBlanchiment[cid] and os.time() - dernierBlanchiment[cid] < cfg.delai then
        local m = math.ceil((cfg.delai - (os.time() - dernierBlanchiment[cid])) / 60)
        return notifier(src, ('Pas si vite. Reviens dans %d min.'):format(m), 'error')
    end
    local disponible = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == 'markedbills' then
            disponible = disponible + (tonumber(item.info and item.info.worth) or 0) * (item.amount or 1)
        end
    end
    if disponible <= 0 then
        return notifier(src, 'Tu n\'as pas de billets marques.', 'error')
    end
    if disponible < (cfg.minParPassage or 0) then
        return notifier(src, ('Je ne me deplace pas pour moins de $%d.'):format(cfg.minParPassage), 'error')
    end
    local valeur = 0
    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == 'markedbills' then
            local worth = tonumber(item.info and item.info.worth) or 0
            local n = item.amount or 1
            for _ = 1, n do
                if valeur + worth > cfg.maxParPassage and valeur > 0 then break end
                if Player.Functions.RemoveItem('markedbills', 1, slot) then
                    valeur = valeur + worth
                end
            end
        end
        if valeur >= cfg.maxParPassage then break end
    end
    if valeur <= 0 then
        return notifier(src, 'Tu n\'as pas de billets marques.', 'error')
    end
    dernierBlanchiment[cid] = os.time()
    local propre = math.floor(valeur * cfg.taux)
    Player.Functions.AddMoney('cash', propre, 'blanchiment')
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'remove')
    notifier(src, ('$%d de billets marques blanchis : tu recois $%d en liquide.'):format(valeur, propre), 'success')
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Armurier clandestin (boutique "Dealer" de qb-inventory : liquide uniquement, armes non enregistrees)

QBCore.Functions.CreateCallback('pt-illegal:server:accesArmurier', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not proche(src, 'armurier') then return cb(false) end
    local gangs = Config.Armurier.gangs
    cb(not gangs or gangs[Player.PlayerData.gang.name] == true)
end)
