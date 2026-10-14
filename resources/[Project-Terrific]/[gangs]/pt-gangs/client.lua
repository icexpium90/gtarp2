local QBCore = exports['qb-core']:GetCoreObject()

local Data = {}          -- snapshot des gangs (points, shell, couleurs)
local PlayerGang = nil   -- { name, grade, isboss }
local blip = nil
local shellObject = nil  -- shell cree localement quand on est dans un QG sans MLO
local shellExit = nil    -- position de sortie dans le shell

---------------------------------------------------------------- outils

local function notify(msg, typ) QBCore.Functions.Notify(msg, typ or 'primary') end

local function refreshPlayer()
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.gang then
        PlayerGang = { name = pd.gang.name, grade = tonumber(pd.gang.grade and pd.gang.grade.level) or 0, isboss = pd.gang.isboss }
    else
        PlayerGang = nil
    end
end

local function myGang()
    if not PlayerGang or PlayerGang.name == 'none' then return nil end
    return Data[PlayerGang.name], PlayerGang.name
end

local function color(index)
    return Config.Colors[index or 1] or Config.Colors[1]
end

local function text3d(coords, texte)
    local ok, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.2)
    if not ok then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(texte)
    EndTextCommandDisplayText(x, y)
    DrawRect(x, y + 0.0125, 0.02 + string.len(texte) / 370, 0.03, 0, 0, 0, 100)
end

local function teleport(c)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    local ped = PlayerPedId()
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 4000 do Wait(0) end
    DoScreenFadeIn(400)
end

local function shellConfig(model)
    for _, s in ipairs(Config.Shells) do if s.model == model then return s end end
end

---------------------------------------------------------------- blip du QG (visible par les membres)

local function updateBlip()
    if blip then RemoveBlip(blip) blip = nil end
    local gang = myGang()
    if not gang or not gang.blip or not gang.points.entree then return end
    local e = gang.points.entree
    blip = AddBlipForCoord(e.x, e.y, e.z)
    SetBlipSprite(blip, 437)
    SetBlipColour(blip, color(gang.color).blip)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('QG - ' .. gang.label)
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------- synchronisation

RegisterNetEvent('pt-gangs:client:sync', function(data)
    Data = data or {}
    refreshPlayer()
    updateBlip()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshPlayer()
    Data = lib.callback.await('pt-gangs:server:getData', false) or {}
    updateBlip()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
    refreshPlayer()
    updateBlip()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    local avant = PlayerGang and PlayerGang.name
    refreshPlayer()
    if (PlayerGang and PlayerGang.name) ~= avant then updateBlip() end
end)

CreateThread(function()
    Wait(2000)
    refreshPlayer()
    Data = lib.callback.await('pt-gangs:server:getData', false) or {}
    updateBlip()
end)

---------------------------------------------------------------- QG : entrer / sortir

local function enterHQ(gang)
    local p = gang.points
    if p.interieur then
        return teleport(p.interieur)
    end
    if gang.shell and p.entree then
        local s = shellConfig(gang.shell)
        if not s then return end
        local base = vec3(p.entree.x, p.entree.y, p.entree.z - Config.ShellOffset)
        local model = joaat(s.model)
        lib.requestModel(model, 5000)
        shellObject = CreateObjectNoOffset(model, base.x, base.y, base.z, false, false, false)
        FreezeEntityPosition(shellObject, true)
        SetModelAsNoLongerNeeded(model)
        shellExit = vec4(base.x + s.exit.x, base.y + s.exit.y, base.z + s.exit.z, s.exit.w)
        return teleport(shellExit)
    end
    notify('L\'interieur du QG n\'est pas encore configure (admin : /gangadmin).', 'error')
end

local function leaveHQ(gang)
    if gang.points.entree then teleport(gang.points.entree) end
    if shellObject and DoesEntityExist(shellObject) then DeleteEntity(shellObject) end
    shellObject, shellExit = nil, nil
end

---------------------------------------------------------------- flotte de vehicules

local function randomPlate(prefix)
    return (prefix .. tostring(math.random(1000, 9999))):sub(1, 8)
end

local function spawnFleetVehicle(gang, v)
    local spawn = gang.points.garage_spawn or gang.points.garage
    if not spawn then return notify('Aucune sortie de vehicules configuree.', 'error') end
    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then return notify('La sortie est encombree.', 'error') end
    QBCore.Functions.SpawnVehicle(v.model, function(veh)
        local plate = randomPlate(gang.plate or 'GANG')
        SetVehicleNumberPlateText(veh, plate)
        SetEntityHeading(veh, spawn.w or 0.0)
        local rgb = color(gang.color).rgb
        SetVehicleCustomPrimaryColour(veh, rgb[1], rgb[2], rgb[3])
        SetVehicleCustomSecondaryColour(veh, rgb[1], rgb[2], rgb[3])
        SetVehicleDirtLevel(veh, 0.0)
        if GetResourceState('cdn-fuel') == 'started' then exports['cdn-fuel']:SetFuel(veh, 100.0) end
        SetVehicleEngineOn(veh, true, true, false)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerServerEvent('pt-gangs:server:vehicleSpawned', v.id, NetworkGetNetworkIdFromEntity(veh), QBCore.Functions.GetPlate(veh))
    end, vec3(spawn.x, spawn.y, spawn.z), true)
end

local function fleetMenu(gang)
    local liste = lib.callback.await('pt-gangs:server:getVehicles', false) or {}
    local options = {}
    for _, v in ipairs(liste) do
        options[#options + 1] = {
            title = v.label,
            description = v.allowed and v.model or ('Grade minimum : %s'):format(v.mingrade),
            icon = 'car',
            disabled = not v.allowed,
            onSelect = function() spawnFleetVehicle(gang, v) end,
        }
    end
    if #options == 0 then options[1] = { title = 'Aucun vehicule dans la flotte', disabled = true } end
    lib.registerContext({ id = 'ptgangs_fleet', title = 'Garage - ' .. gang.label, options = options })
    lib.showContext('ptgangs_fleet')
end

local function storeFleetVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    local plate = QBCore.Functions.GetPlate(veh)
    if not lib.callback.await('pt-gangs:server:isFleetVehicle', false, plate) then
        return notify('Ce vehicule n\'appartient pas a la flotte du gang.', 'error')
    end
    TaskLeaveVehicle(PlayerPedId(), veh, 0)
    Wait(1500)
    TriggerServerEvent('pt-gangs:server:vehicleStored', plate)
    QBCore.Functions.DeleteVehicle(veh)
    notify('Vehicule range.', 'success')
end

-- /gangcles [id] : donner les cles du vehicule de flotte (dans lequel on est ou le plus proche) a un membre
RegisterCommand('gangcles', function(_, args)
    local id = tonumber(args[1])
    if not id then return notify('Utilisation : /gangcles [id du joueur]', 'error') end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, false) or 0 end
    if veh == 0 then return notify('Aucun vehicule a proximite.', 'error') end
    TriggerServerEvent('pt-gangs:server:shareKeys', id, QBCore.Functions.GetPlate(veh))
end, false)
TriggerEvent('chat:addSuggestion', '/gangcles', 'Donner les cles d\'un vehicule du gang a un membre', { { name = 'id', help = 'ID serveur du joueur' } })

---------------------------------------------------------------- points d'interaction

local function interactions(gang, name)
    local p = gang.points
    local liste = {}
    if p.entree then
        liste[#liste + 1] = { c = p.entree, txt = '[E] Entrer dans le QG', act = function() enterHQ(gang) end }
    end
    if p.interieur then
        liste[#liste + 1] = { c = p.interieur, txt = '[E] Sortir du QG', act = function() leaveHQ(gang) end }
    end
    if shellExit then
        liste[#liste + 1] = { c = shellExit, txt = '[E] Sortir du QG', act = function() leaveHQ(gang) end }
    end
    if p.depot then
        liste[#liste + 1] = { c = p.depot, txt = '[E] Depot du gang', act = function()
            local id = 'gang_' .. name
            TriggerEvent('inventory:client:SetCurrentStash', id)
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, Config.Stash)
        end }
    end
    if p.vestiaire then
        liste[#liste + 1] = { c = p.vestiaire, txt = '[E] Vestiaire', act = function()
            TriggerEvent('qb-clothing:client:openOutfitMenu')
        end }
    end
    if p.chef then
        liste[#liste + 1] = { c = p.chef, txt = '[E] Menu du chef', act = function()
            if PlayerGang and PlayerGang.isboss then
                TriggerEvent('qb-gangmenu:client:OpenMenu')
            else
                notify('Reserve au chef du gang.', 'error')
            end
        end }
    end
    if p.garage then
        local enVehicule = IsPedInAnyVehicle(PlayerPedId(), false)
        liste[#liste + 1] = { c = p.garage, txt = enVehicule and '[E] Ranger le vehicule' or '[E] Garage du gang',
            dist = enVehicule and 6.0 or nil,
            act = function()
                if IsPedInAnyVehicle(PlayerPedId(), false) then storeFleetVehicle() else fleetMenu(gang) end
            end }
    end
    return liste
end

CreateThread(function()
    while true do
        local sleep = 1000
        local gang, name = myGang()
        if gang then
            local pos = GetEntityCoords(PlayerPedId())
            for _, it in ipairs(interactions(gang, name)) do
                local d = #(pos - vec3(it.c.x, it.c.y, it.c.z))
                if d < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(27, it.c.x, it.c.y, it.c.z - 0.97, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.8, 255, 255, 255, 90, false, false, 2, false, nil, nil, false)
                    if d < (it.dist or Config.InteractDistance) then
                        text3d(it.c, it.txt)
                        if IsControlJustPressed(0, Config.InteractKey) then it.act() end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if shellObject and DoesEntityExist(shellObject) then DeleteEntity(shellObject) end
    if blip then RemoveBlip(blip) end
end)

---------------------------------------------------------------- menu admin (/gangadmin)

local openGangAdmin

local function gradeOptions(name)
    local g = QBCore.Shared.Gangs[name]
    local opts = {}
    if g then
        for k, v in pairs(g.grades) do opts[#opts + 1] = { value = k, label = ('%s - %s'):format(k, v.name) } end
        table.sort(opts, function(a, b) return tonumber(a.value) < tonumber(b.value) end)
    end
    return opts
end

local function adminVehicles(name, vehicles)
    local options = {
        { title = 'Ajouter un vehicule', icon = 'plus', onSelect = function()
            local input = lib.inputDialog('Ajouter a la flotte', {
                { type = 'input', label = 'Modele (spawn code)', required = true },
                { type = 'input', label = 'Nom affiche', required = true },
                { type = 'select', label = 'Grade minimum', options = gradeOptions(name), default = '0', required = true },
            })
            if not input then return end
            TriggerServerEvent('pt-gangs:server:addVehicle', name, input[1], input[2], tonumber(input[3]))
            Wait(300)
            openGangAdmin(name)
        end },
    }
    for _, v in ipairs(vehicles or {}) do
        options[#options + 1] = {
            title = v.label, description = ('%s - grade %s minimum (cliquer pour retirer)'):format(v.model, v.mingrade), icon = 'car',
            onSelect = function()
                if lib.alertDialog({ header = 'Retirer ' .. v.label, content = 'Retirer ce vehicule de la flotte ?', centered = true, cancel = true }) == 'confirm' then
                    TriggerServerEvent('pt-gangs:server:removeVehicle', name, v.id)
                    Wait(300)
                    openGangAdmin(name)
                end
            end
        }
    end
    lib.registerContext({ id = 'ptgangs_admin_veh', title = 'Flotte de vehicules', menu = 'ptgangs_admin_gang', options = options })
    lib.showContext('ptgangs_admin_veh')
end

openGangAdmin = function(name)
    local data = lib.callback.await('pt-gangs:server:adminData', false)
    if not data then return end
    local gang = data.gangs[name]
    if not gang then return end
    local options = {}
    local ordre = { 'entree', 'interieur', 'depot', 'vestiaire', 'chef', 'garage', 'garage_spawn' }
    for _, kind in ipairs(ordre) do
        local place = gang.points[kind] ~= nil
        options[#options + 1] = {
            title = ('Placer ici : %s'):format(Config.PointLabels[kind]),
            description = place and 'Deja place (sera deplace a votre position)' or 'Non place',
            icon = place and 'circle-check' or 'location-dot',
            onSelect = function()
                TriggerServerEvent('pt-gangs:server:setPoint', name, kind)
                Wait(300)
                openGangAdmin(name)
            end
        }
    end
    options[#options + 1] = {
        title = 'Interieur en shell (sans MLO)', description = gang.shell and ('Shell actuel : %s'):format(gang.shell) or 'Aucun shell',
        icon = 'cube', arrow = true,
        onSelect = function()
            local opts = { { title = 'Aucun shell', icon = 'xmark', onSelect = function() TriggerServerEvent('pt-gangs:server:setShell', name, nil) end } }
            for _, s in ipairs(Config.Shells) do
                opts[#opts + 1] = { title = s.label, description = s.model, icon = 'cube', onSelect = function()
                    TriggerServerEvent('pt-gangs:server:setShell', name, s.model)
                end }
            end
            lib.registerContext({ id = 'ptgangs_admin_shell', title = 'Shell du QG', menu = 'ptgangs_admin_gang', options = opts })
            lib.showContext('ptgangs_admin_shell')
        end
    }
    options[#options + 1] = {
        title = 'Supprimer un point', icon = 'trash', arrow = true,
        onSelect = function()
            local opts = {}
            for _, kind in ipairs(ordre) do
                if gang.points[kind] then
                    opts[#opts + 1] = { title = Config.PointLabels[kind], icon = 'trash', onSelect = function()
                        TriggerServerEvent('pt-gangs:server:removePoint', name, kind)
                    end }
                end
            end
            if #opts == 0 then opts[1] = { title = 'Aucun point place', disabled = true } end
            lib.registerContext({ id = 'ptgangs_admin_del', title = 'Supprimer un point', menu = 'ptgangs_admin_gang', options = opts })
            lib.showContext('ptgangs_admin_del')
        end
    }
    options[#options + 1] = { title = 'Flotte de vehicules', icon = 'car', arrow = true, onSelect = function() adminVehicles(name, data.vehicles[name]) end }
    options[#options + 1] = {
        title = 'Ajouter / modifier un membre', description = 'Par ID serveur', icon = 'user-plus',
        onSelect = function()
            local input = lib.inputDialog('Membre de ' .. gang.label, {
                { type = 'number', label = 'ID serveur du joueur', required = true },
                { type = 'select', label = 'Grade', options = gradeOptions(name), default = '0', required = true },
            })
            if input then TriggerServerEvent('pt-gangs:server:setMember', input[1], name, tonumber(input[2])) end
        end
    }
    options[#options + 1] = {
        title = gang.blip and 'Blip du QG : active' or 'Blip du QG : desactive', icon = 'map-pin',
        onSelect = function() TriggerServerEvent('pt-gangs:server:toggleBlip', name) Wait(300) openGangAdmin(name) end
    }
    if gang.points.entree then
        options[#options + 1] = { title = 'Se teleporter a l\'entree', icon = 'location-arrow', onSelect = function() teleport(gang.points.entree) end }
    end
    lib.registerContext({ id = 'ptgangs_admin_gang', title = ('%s (%s)'):format(gang.label, name), menu = 'ptgangs_admin', options = options })
    lib.showContext('ptgangs_admin_gang')
end

RegisterNetEvent('pt-gangs:client:adminMenu', function()
    local data = lib.callback.await('pt-gangs:server:adminData', false)
    if not data then return end
    local options = {
        { title = 'Creer un gang', icon = 'plus', onSelect = function()
            local couleurs = {}
            for i, c in ipairs(Config.Colors) do couleurs[#couleurs + 1] = { value = tostring(i), label = c.label } end
            local input = lib.inputDialog('Nouveau gang', {
                { type = 'input', label = 'Identifiant (ex : armeniens)', required = true, min = 3, max = 30 },
                { type = 'input', label = 'Nom affiche', required = true },
                { type = 'input', label = 'Prefixe de plaque (4 lettres)', required = true, min = 2, max = 4 },
                { type = 'select', label = 'Couleur', options = couleurs, default = '1', required = true },
                { type = 'checkbox', label = 'Organisation (5 grades : Associe > Chef) plutot que gang de rue (4 grades)' },
            })
            if not input then return end
            TriggerServerEvent('pt-gangs:server:createGang', { name = input[1], label = input[2], plate = input[3], color = tonumber(input[4]), orga = input[5] })
        end },
    }
    local noms = {}
    for name in pairs(data.gangs) do noms[#noms + 1] = name end
    table.sort(noms, function(a, b) return data.gangs[a].label < data.gangs[b].label end)
    for _, name in ipairs(noms) do
        local g = data.gangs[name]
        local n = 0
        for _ in pairs(g.points) do n += 1 end
        options[#options + 1] = {
            title = g.label, description = ('%s - %d point(s) place(s)%s'):format(name, n, g.shell and ' - shell' or ''),
            icon = 'people-group', arrow = true,
            onSelect = function() openGangAdmin(name) end
        }
    end
    lib.registerContext({ id = 'ptgangs_admin', title = 'Administration des gangs', options = options })
    lib.showContext('ptgangs_admin')
end)
