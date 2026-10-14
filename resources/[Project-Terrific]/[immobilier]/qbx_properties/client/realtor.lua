local sharedConfig = require 'config.shared'
-- liste triee par nom ; l'option MLO en premier
local entries = {}
for k, v in pairs(sharedConfig.interiors) do
    entries[#entries + 1] = { key = k, label = v.label or tostring(k) }
end
table.sort(entries, function(a, b) return a.label < b.label end)
local values, labels = { Bridge.MLO }, { '[MLO] Batiment existant (se placer a l\'interieur)' }
for i = 1, #entries do
    values[#values + 1] = entries[i].key
    labels[#labels + 1] = entries[i].label
end

local car = 0
local shell = 0
local playerCoords = vec3(0, 0, 0)
local garageCoords = nil
local garageHeading = 0.0
local isPreviewing = false

local function showText()
    lib.showTextUI('RETOUR ARRIERE - Annuler  \n FLECHE GAUCHE / DROITE - Tourner  \n ENTREE - Valider l\'emplacement')
end

local function spawnCar()
    local model = lib.requestModel('sultanrs', 2500)
    car = CreateVehicle(model, 0.0, 0.0, 0.0, 0.0, false, false)
    SetEntityCompletelyDisableCollision(car, false, false)
    SetModelAsNoLongerNeeded(model)
end

local function previewProperty(propertyIndex)
    if DoesEntityExist(shell) then DeleteEntity(shell) end
    if propertyIndex == Bridge.MLO then
        SetEntityCoords(cache.ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
        return
    end
    if type(propertyIndex) == 'number' then
        lib.requestModel(propertyIndex, 5000)
        shell = CreateObject(propertyIndex, playerCoords.x, playerCoords.y, playerCoords.z - sharedConfig.shellUndergroundOffset, false, false, false)
        FreezeEntityPosition(shell, true)
        SetModelAsNoLongerNeeded(propertyIndex)
        local teleportCoords = CalculateOffsetCoords(playerCoords, sharedConfig.interiors[propertyIndex].exit)
        SetEntityCoords(cache.ped, teleportCoords.x, teleportCoords.y, teleportCoords.z, false, false, false, false)
    else
        local teleportCoords = sharedConfig.interiors[propertyIndex].exit
        SetEntityCoords(cache.ped, teleportCoords.x, teleportCoords.y, teleportCoords.z, false, false, false, false)
        Bridge.SnapToGround(teleportCoords)
    end
end

-- MLO : l'agent marche jusqu'a l'interieur du batiment et valide le point d'entree avec E
local function pickMloPoint()
    lib.showTextUI('Allez a l\'interieur du batiment  \n E - Valider le point d\'entree  \n RETOUR ARRIERE - Annuler')
    local point = nil
    while true do
        Wait(0)
        if IsControlJustPressed(0, 38) then
            local c = GetEntityCoords(cache.ped)
            point = vec4(c.x, c.y, c.z, GetEntityHeading(cache.ped))
            break
        end
        if IsControlJustPressed(0, 202) then break end
    end
    lib.hideTextUI()
    return point
end

local function stopPreview()
    isPreviewing = false
    if DoesEntityExist(shell) then DeleteEntity(shell) end
    SetEntityCoords(cache.ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
    local players = GetActivePlayers()
    for i = 1, #players do
        if players[i] ~= cache.playerId then
            NetworkConcealPlayer(players[i], false, false)
        end
    end
end

local function addGaragePoint()
    local isAddingGarage = true
    garageCoords = nil

    showText()
    spawnCar()

    while isAddingGarage do
        Wait(0)

        local hit, _, endCoords = lib.raycast.fromCamera(511, 4, 25.0)

        if not hit then
            SetEntityCoords(car, 0.0, 0.0, 0.0, false, false, false, false)
        else
            SetEntityCoords(car, endCoords.x, endCoords.y, endCoords.z + 1.0, false, false, false, false)
            SetVehicleOnGroundProperly(car)
        end

        if IsControlJustPressed(0, 202) then
            if DoesEntityExist(car) then
                DeleteEntity(car)
            end
            isAddingGarage = false
        end

        if IsControlPressed(0, 190) then
            garageHeading = (garageHeading + 2.5) % 360.0
            SetEntityHeading(car, garageHeading)
            Wait(100)
        end

        if IsControlPressed(0, 189) then
            garageHeading = (garageHeading - 2.5) % 360.0
            SetEntityHeading(car, garageHeading)
            Wait(100)
        end

        if IsControlJustPressed(0, 18) then
            if hit then
                garageCoords = endCoords
                garageHeading = GetEntityHeading(car)
                if DoesEntityExist(car) then
                    DeleteEntity(car)
                end
                isAddingGarage = false
            else
                lib.notify({type = 'error', title = 'Erreur', description = 'Emplacement de garage invalide.'})
            end
        end

        SetEntityHeading(car, garageHeading) -- Prevent the car from rotating
    end

    lib.hideTextUI()
end

lib.registerMenu({
    id = 'qbx_properties_realtor_menu',
    title = locale('menu.interior_preview'),
    position = 'top-right',
    onSideScroll = function(_, scrollIndex, args)
        previewProperty(args[scrollIndex])
    end,
    onClose = function()
        stopPreview()
    end,
    options = {
        { label = 'Interieur', values = labels, args = values, icon = 'house' },
    }
}, function(_, scrollIndex, args)
    stopPreview()
    local input = lib.inputDialog('Creation d\'un bien', {
        {type = 'input', label = locale('alert.property_name'), description = locale('alert.property_name_description'), required = true, min = 4, max = 32, icon = 'home'},
        {type = 'number', label = locale('alert.price'), description = locale('alert.price_description'), icon = 'dollar-sign', required = true, min = 1},
        {type = 'number', label = locale('alert.rent_interval'), description = locale('alert.rent_interval_description'), icon = 'clock', min = 1, max = 24, step = 1},
        {type = 'checkbox', label = locale('alert.add_garage')},
    })
    if not input then return end

    local garageData = nil
    
    if input[4] then
        addGaragePoint()
        if garageCoords then
            garageData = vec4(garageCoords.x, garageCoords.y, garageCoords.z + 1.0, garageHeading)
        end
    end

    local mloPoint = nil
    if args[scrollIndex] == Bridge.MLO then
        mloPoint = pickMloPoint()
        if not mloPoint then return end
    end

    TriggerServerEvent('qbx_properties:server:createProperty', args[scrollIndex], input, playerCoords, garageData, mloPoint)
end)

RegisterNetEvent('qbx_properties:client:createProperty', function()
    playerCoords = GetEntityCoords(cache.ped)
    garageCoords = nil
    isPreviewing = true
    previewProperty(values[1])
    lib.showMenu('qbx_properties_realtor_menu')
    while isPreviewing do
        local players = GetActivePlayers()
        for i = 1, #players do
            if players[i] ~= cache.playerId then
                NetworkConcealPlayer(players[i], true, false)
            end
        end
        Wait(3000)
    end
end)

-- Creation depuis un lieu MLO du catalogue (config.shared lieux) : l'agent est devant la porte,
-- nom et prix pre-remplis, puis il entre et valide le point d'arrivee.
function CreerDepuisLieu(lieu)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - lieu.zone) > 80.0 then
        SetNewWaypoint(lieu.zone.x, lieu.zone.y)
        return Bridge.Notify('Rendez-vous d\'abord sur place (GPS place).', 'error')
    end
    if lieu.ressource and GetResourceState(lieu.ressource) ~= 'started' then
        return Bridge.Notify(('La carte %s n\'est pas demarree sur le serveur.'):format(lieu.ressource), 'error')
    end
    local input = lib.inputDialog(('Nouveau bien : %s'):format(lieu.label), {
        {type = 'input', label = locale('alert.property_name'), required = true, min = 4, max = 32, icon = 'home', default = lieu.label:gsub(' %(.*%)', '')},
        {type = 'number', label = locale('alert.price'), icon = 'dollar-sign', required = true, min = 1, default = lieu.prix},
        {type = 'number', label = locale('alert.rent_interval'), description = locale('alert.rent_interval_description'), icon = 'clock', min = 1, max = 24, step = 1, default = lieu.loyer},
        {type = 'checkbox', label = locale('alert.add_garage')},
    })
    if not input then return end
    playerCoords = GetEntityCoords(cache.ped)
    local garageData = nil
    if input[4] then
        addGaragePoint()
        if garageCoords then
            garageData = vec4(garageCoords.x, garageCoords.y, garageCoords.z + 1.0, garageHeading)
        end
    end
    if lieu.interieur then
        -- interieur accessible seulement par teleportation : point d'arrivee connu
        local porte = GetEntityCoords(cache.ped)
        local i = lieu.interieur
        DoScreenFadeOut(300)
        Wait(350)
        SetEntityCoords(cache.ped, i.x, i.y, i.z, false, false, false, false)
        Wait(1200)
        TriggerServerEvent('qbx_properties:server:createProperty', Bridge.MLO, input, playerCoords, garageData, vec4(i.x, i.y, i.z, i.w or 0.0))
        Wait(800)
        SetEntityCoords(cache.ped, porte.x, porte.y, porte.z, false, false, false, false)
        DoScreenFadeIn(300)
        return
    end
    Bridge.Notify('Porte enregistree. Entrez maintenant dans le batiment.', 'primary')
    local mloPoint = pickMloPoint()
    if not mloPoint then return end
    TriggerServerEvent('qbx_properties:server:createProperty', Bridge.MLO, input, playerCoords, garageData, mloPoint)
end
