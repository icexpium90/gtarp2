local QBCore = exports['qb-core']:GetCoreObject()
local peds = {}           -- [id] = entite
local positions = {}      -- [id] = position utilisee pour le PNJ actuel

local function chargerModele(m)
    local h = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local limite = GetGameTimer() + 5000
    while not HasModelLoaded(h) do
        if GetGameTimer() > limite then return nil end
        Wait(0)
    end
    return h
end

-- cale le PNJ sur le sol : d'abord juste au-dessus de la position donnee, sinon depuis le ciel
local function sol(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    for _, depart in ipairs({ z + 3.0, z + 50.0, 400.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x, y, depart, false)
        if ok then return gz end
    end
    return z
end

local function supprimer(id)
    if peds[id] and DoesEntityExist(peds[id]) then
        exports['qb-target']:RemoveTargetEntity(peds[id])
        DeleteEntity(peds[id])
    end
    peds[id] = nil
    positions[id] = nil
end

local function animationEchange(ped)
    local dict = 'mp_common'
    RequestAnimDict(dict)
    local limite = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < limite do Wait(0) end
    TaskPlayAnim(PlayerPedId(), dict, 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
    if ped and DoesEntityExist(ped) then TaskPlayAnim(ped, dict, 'givetake1_b', 8.0, -8.0, 1500, 49, 0, false, false, false) end
    Wait(1500)
end

local function options(p)
    if p.type == 'deal' then
        return { {
            icon = 'fas fa-cannabis', label = 'Proposer de la marchandise',
            action = function(ent)
                animationEchange(ent)
                TriggerServerEvent('pt-illegal:server:vendre', p.id)
            end,
        } }
    elseif p.type == 'blanchisseur' then
        return { {
            icon = 'fas fa-money-bill-wave', label = 'Faire nettoyer des billets',
            action = function(ent)
                animationEchange(ent)
                TriggerServerEvent('pt-illegal:server:blanchir')
            end,
        } }
    elseif p.type == 'armurier' then
        return { {
            icon = 'fas fa-comment', label = 'Parler',
            action = function()
                QBCore.Functions.TriggerCallback('pt-illegal:server:accesArmurier', function(ok)
                    if not ok then
                        return QBCore.Functions.Notify('Je te connais pas. Degage.', 'error')
                    end
                    local items = {}
                    for i, it in ipairs(Config.Armurier.produits) do
                        items[i] = { name = it.name, price = it.price, amount = it.amount, info = {}, type = 'item', slot = i }
                    end
                    -- boutique "Dealer" : liquide uniquement, armes sans enregistrement au MDT
                    TriggerServerEvent('inventory:server:OpenInventory', 'shop', 'Dealer_armurier', { label = 'Marchandise', items = items })
                end)
            end,
        } }
    end
    return {}
end

local function creer(p)
    local h = chargerModele(p.ped)
    if not h then return end
    local z = sol(p.coords.x, p.coords.y, p.coords.z)
    local ent = CreatePed(4, h, p.coords.x, p.coords.y, z, p.coords.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(h)
    SetEntityInvincible(ent, true)
    FreezeEntityPosition(ent, true)
    SetBlockingOfNonTemporaryEvents(ent, true)
    SetPedFleeAttributes(ent, 0, false)
    SetPedCanRagdoll(ent, false)
    TaskStartScenarioInPlace(ent, p.type == 'armurier' and 'WORLD_HUMAN_SMOKING' or (p.type == 'blanchisseur' and 'WORLD_HUMAN_STAND_MOBILE' or 'WORLD_HUMAN_DRUG_DEALER'), 0, true)
    exports['qb-target']:AddTargetEntity(ent, { options = options(p), distance = 2.0 })
    peds[p.id] = ent
    positions[p.id] = p.coords
end

-- les PNJ n'existent que pres des joueurs (pas d'icone, rien sur la carte)
CreateThread(function()
    while true do
        local liste = GlobalState.pt_illegal_pnj or {}
        local pos = GetEntityCoords(PlayerPedId())
        for id, p in pairs(liste) do
            local d = #(pos - vector3(p.coords.x, p.coords.y, p.coords.z))
            local bouge = positions[id] and (positions[id].x ~= p.coords.x or positions[id].y ~= p.coords.y or positions[id].w ~= p.coords.w)
            if bouge then supprimer(id) end
            if d < 80.0 and not peds[id] then
                creer(p)
            elseif d > 100.0 and peds[id] then
                supprimer(id)
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('pt-illegal:client:alerte', function()
    if GetResourceState('ps-dispatch') == 'started' then
        pcall(function() exports['ps-dispatch']:DrugSale() end)
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do supprimer(id) end
end)
