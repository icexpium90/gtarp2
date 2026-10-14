local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'
local interiorShell
DecorationObjects = {}
local properties = {}
local insideProperty = false
local isPropertyRental = false
local interactions
local isConcealing = false
local concealWhitelist = {}
local blips = {}

local function createBlip(apartmentCoords, label)
	local blip = AddBlipForCoord(apartmentCoords.x, apartmentCoords.y, apartmentCoords.z)
	SetBlipSprite(blip, 40)
	SetBlipAsShortRange(blip, true)
	SetBlipScale(blip, 0.8)
	SetBlipColour(blip, 2)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentString(label)
	EndTextCommandSetBlipName(blip)
	return blip
end

local function prepareKeyMenu()
    local keyholders = lib.callback.await('qbx_properties:callback:requestKeyHolders')
    local options = {
        {
            title = locale('menu.add_keyholder'),
            icon = 'plus',
            arrow = true,
            onSelect = function()
                local insidePlayers = lib.callback.await('qbx_properties:callback:requestPotentialKeyholders')
                local options = {}
                for i = 1, #insidePlayers do
                    options[#options + 1] = {
                        title = insidePlayers[i].name,
                        icon = 'user',
                        arrow = true,
                        onSelect = function()
                            local alert = lib.alertDialog({
                                header = insidePlayers[i].name,
                                content = locale('alert.give_keys'),
                                centered = true,
                                cancel = true
                            })
                            if alert == 'confirm' then
                                TriggerServerEvent('qbx_properties:server:addKeyholder', insidePlayers[i].citizenid)
                            end
                        end
                    }
                end
                lib.registerContext({
                    id = 'qbx_properties_insideMenu',
                    title = locale('menu.people_inside'),
                    menu = 'qbx_properties_keyMenu',
                    options = options
                })
                lib.showContext('qbx_properties_insideMenu')
            end
        }
    }
    for i = 1, #keyholders do
        options[#options + 1] = {
            title = keyholders[i].name,
            icon = 'user',
            arrow = true,
            onSelect = function()
                local alert = lib.alertDialog({
                    header = keyholders[i].name,
                    content = locale('alert.want_remove_keys'),
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    TriggerServerEvent('qbx_properties:server:removeKeyholder', keyholders[i].citizenid)
                end
            end
        }
    end
    lib.registerContext({
        id = 'qbx_properties_keyMenu',
        title = locale('menu.keyholders'),
        menu = 'qbx_properties_manageMenu',
        options = options
    })
    lib.showContext('qbx_properties_keyMenu')
end

local function prepareDoorbellMenu()
    local ringers = lib.callback.await('qbx_properties:callback:requestRingers')
    local options = {}
    for i = 1, #ringers do
        options[#options + 1] = {
            title = ringers[i].name,
            icon = 'user',
            arrow = true,
            onSelect = function()
                local alert = lib.alertDialog({
                    header = ringers[i].name,
                    content = locale('alert.want_let_person_in'),
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    TriggerServerEvent('qbx_properties:server:letRingerIn', ringers[i].citizenid)
                end
            end
        }
    end
    lib.registerContext({
        id = 'qbx_properties_doorbellMenu',
        title = locale('menu.doorbell_ringers'),
        menu = 'qbx_properties_manageMenu',
        options = options
    })
    lib.showContext('qbx_properties_doorbellMenu')
end

local function prepareManageMenu()
    local hasAccess = lib.callback.await('qbx_properties:callback:checkAccess')
    if not hasAccess then Bridge.Notify(locale('notify.no_access'), 'error') return end
    local options = {
        {
            title = locale('menu.manage_keys'),
            icon = 'key',
            arrow = true,
            onSelect = function()
                prepareKeyMenu()
            end
        },
        {
            title = locale('menu.doorbell'),
            icon = 'bell',
            arrow = true,
            onSelect = function()
                prepareDoorbellMenu()
            end
        },
        {
            title = locale('menu.start_decorating'),
            icon = 'couch',
            onSelect = function()
                ToggleDecorating()
            end
        },
        {
            title = 'Cles et serrures',
            description = 'Doubles de cle a donner, changement des serrures',
            icon = 'key',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'qbx_properties_doublesMenu',
                    title = 'Cles et serrures',
                    menu = 'qbx_properties_manageMenu',
                    options = {
                        {
                            title = 'Faire un double de cle',
                            description = ('Objet a donner a un proche : ouvre la porte et le coffre ($%d)'):format(ClientAgence.prixDouble),
                            icon = 'key',
                            serverEvent = 'qbx_properties:server:faireDouble',
                        },
                        {
                            title = 'Changer les serrures',
                            description = ('Tous les doubles existants deviennent inutilisables ($%d)'):format(ClientAgence.prixSerrure),
                            icon = 'lock',
                            onSelect = function()
                                local ok = lib.alertDialog({ header = 'Changer les serrures', content = 'Les doubles de cle deja distribues ne fonctionneront plus. Continuer ?', centered = true, cancel = true })
                                if ok == 'confirm' then TriggerServerEvent('qbx_properties:server:changerSerrures') end
                            end,
                        },
                    },
                })
                lib.showContext('qbx_properties_doublesMenu')
            end
        },
        {
            title = locale('menu.place_points'),
            description = locale('menu.place_points_description'),
            icon = 'location-crosshairs',
            arrow = true,
            onSelect = function()
                local points = {
                    { kind = 'clothing', label = locale('menu.place_clothing'), icon = 'shirt' },
                    { kind = 'logout', label = locale('menu.place_logout'), icon = 'bed' },
                    { kind = 'exit', label = locale('menu.place_exit'), icon = 'door-open' },
                    { kind = 'safe', label = 'Coffre-fort (argent propre et sale) ici', icon = 'vault' },
                }
                local opts = {
                    {
                        title = 'Ajouter un coffre ici',
                        description = 'Armes, objets, billets marques... (jusqu\'a 5 coffres)',
                        icon = 'box',
                        onSelect = function()
                            local input = lib.inputDialog('Nouveau coffre', {
                                { type = 'select', label = 'Taille', required = true, default = 'moyen', options = {
                                    { value = 'petit', label = 'Petit (30 places, 100 kg)' },
                                    { value = 'moyen', label = 'Moyen (50 places, 250 kg)' },
                                    { value = 'grand', label = 'Grand / armurerie (80 places, 600 kg)' } } },
                                { type = 'input', label = 'Nom (facultatif)', placeholder = 'Armurerie, Cave...', max = 30 },
                            })
                            if input then TriggerServerEvent('qbx_properties:server:setInteraction', 'stash', input[1], input[2]) end
                        end
                    },
                    {
                        title = 'Retirer le coffre le plus proche',
                        description = 'Videz-le avant : son contenu ne sera plus accessible',
                        icon = 'trash',
                        onSelect = function()
                            local ok = lib.alertDialog({ header = 'Retirer le coffre', content = 'Le contenu du coffre le plus proche ne sera plus accessible. Continuer ?', centered = true, cancel = true })
                            if ok == 'confirm' then TriggerServerEvent('qbx_properties:server:removeStash') end
                        end
                    },
                }
                for _, pt in ipairs(points) do
                    opts[#opts + 1] = {
                        title = pt.label,
                        icon = pt.icon,
                        onSelect = function()
                            TriggerServerEvent('qbx_properties:server:setInteraction', pt.kind)
                        end
                    }
                end
                lib.registerContext({ id = 'qbx_properties_pointsMenu', title = locale('menu.place_points'), menu = 'qbx_properties_manageMenu', options = opts })
                lib.showContext('qbx_properties_pointsMenu')
            end
        }
    }
    if isPropertyRental then
        options[#options+1] = {
            title = 'Arreter la location',
            icon = 'file-invoice-dollar',
            arrow = true,
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Arreter la location',
                    content = 'Voulez-vous vraiment arreter de louer ce bien ?',
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    TriggerServerEvent('qbx_properties:server:stopRenting')
                end
            end
        }
    end
    lib.registerContext({
        id = 'qbx_properties_manageMenu',
        title = locale('menu.manage_property'),
        options = options
    })
    lib.showContext('qbx_properties_manageMenu')
end

-- coffre-fort : argent propre (liquide) et argent sale (billets marques)
function OpenPropertySafe()
    local d = lib.callback.await('qbx_properties:callback:getSafe', false)
    if not d then return Bridge.Notify(locale('notify.no_access'), 'error') end
    local function montant(titre, max)
        local input = lib.inputDialog(titre, { { type = 'number', label = ('Montant (max $%d)'):format(max), required = true, min = 1, max = max } })
        return input and input[1]
    end
    lib.registerContext({
        id = 'qbx_properties_safe',
        title = 'Coffre-fort',
        options = {
            { title = ('Argent propre : $%d'):format(d.propre), description = ('Liquide sur vous : $%d'):format(d.liquide), icon = 'money-bill', readOnly = true },
            { title = 'Deposer de l\'argent propre', icon = 'arrow-down', disabled = d.liquide <= 0, onSelect = function()
                local m = montant('Deposer de l\'argent propre', d.liquide)
                if m then TriggerServerEvent('qbx_properties:server:safe', 'deposer', 'propre', m) end
            end },
            { title = 'Retirer de l\'argent propre', icon = 'arrow-up', disabled = d.propre <= 0, onSelect = function()
                local m = montant('Retirer de l\'argent propre', d.propre)
                if m then TriggerServerEvent('qbx_properties:server:safe', 'retirer', 'propre', m) end
            end },
            { title = ('Argent sale : $%d'):format(d.sale), description = ('Billets marques sur vous : $%d'):format(d.billets), icon = 'sack-dollar', readOnly = true },
            { title = 'Deposer tous mes billets marques', icon = 'arrow-down', disabled = d.billets <= 0, onSelect = function()
                TriggerServerEvent('qbx_properties:server:safe', 'deposer', 'sale', d.billets)
            end },
            { title = 'Retirer de l\'argent sale (billets marques)', icon = 'arrow-up', disabled = d.sale <= 0, onSelect = function()
                local m = montant('Retirer de l\'argent sale', d.sale)
                if m then TriggerServerEvent('qbx_properties:server:safe', 'retirer', 'sale', m) end
            end },
        },
    })
    lib.showContext('qbx_properties_safe')
end

local function checkInteractions()
    local interactOptions = {
        ['stash'] = function(coords, data)
            qbx.drawText3d({ coords = coords, text = data and data.label and ('[E] ' .. data.label) or locale('drawtext.stash') })
            if IsControlJustPressed(0, 38) then
                TriggerServerEvent('qbx_properties:server:openStash', data and data.index)
            end
        end,
        ['safe'] = function(coords)
            qbx.drawText3d({ coords = coords, text = '[E] Coffre-fort' })
            if IsControlJustPressed(0, 38) then
                OpenPropertySafe()
            end
        end,
        ['exit'] = function(coords)
            qbx.drawText3d({ coords = coords, text = locale('drawtext.exit') })
            if IsControlJustPressed(0, 38) then
                DoScreenFadeOut(1000)
                while not IsScreenFadedOut() do Wait(0) end
                TriggerServerEvent('qbx_properties:server:exitProperty')
            end
            if IsControlJustPressed(0, 47) then
                prepareManageMenu()
            end
        end,
        ['clothing'] = function(coords)
            qbx.drawText3d({ coords = coords, text = locale('drawtext.clothing') })
            if IsControlJustPressed(0, 38) then
                exports['illenium-appearance']:startPlayerCustomization(function(appearance)
                    if appearance then
                        TriggerServerEvent("illenium-appearance:server:saveAppearance", appearance)
                    end
                end, {
                    components = true, componentConfig = { masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true, scarfAndChains = true, bodyArmor = true, shirts = true, decals = true, jackets = true },
                    props = true, propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
                    enableExit = true,
                })
            end
            if IsControlJustPressed(0, 47) then
                TriggerEvent('illenium-appearance:client:openOutfitMenu')
            end
        end,
        ['logout'] = function(coords)
            qbx.drawText3d({ coords = coords, text = locale('drawtext.logout') })
            if IsControlJustPressed(0, 38) then
                DoScreenFadeOut(1000)
                while not IsScreenFadedOut() do Wait(0) end
                TriggerServerEvent('qbx_properties:server:logoutProperty')
            end
        end,
    }
    CreateThread(function()
        while insideProperty do
            local sleep = 800
            local playerCoords = GetEntityCoords(cache.ped)
            for i = 1, #interactions do
                if #(playerCoords - interactions[i].coords) < 1.5 and not IsDecorating then
                    sleep = 0
                    local action = interactOptions[interactions[i].type]
                    if action then action(interactions[i].coords, interactions[i]) end
                end
            end
            Wait(sleep)
        end
    end)
end

local function hideExterior(name)
    local models = clientConfig.exteriorHashs[name]
    if not models then return end
    CreateThread(function()
        while insideProperty do
            for i = 1, #models, 1 do
                EnableExteriorCullModelThisFrame(models[i])
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('qbx_properties:client:updateInteractions', function(interactionsData, interiorString, isRental, snapToGround)
    if snapToGround then
        for i = 1, #interactionsData do
            if interactionsData[i].type == 'exit' then Bridge.SnapToGround(interactionsData[i].coords) break end
        end
    end
    DoScreenFadeIn(1000)
    interactions = interactionsData
    isPropertyRental = isRental
    if not insideProperty then
        insideProperty = true
        checkInteractions()
        hideExterior(interiorString)
    end
end)

-- coffre de propriete via qb-inventory
RegisterNetEvent('qbx_properties:client:openStash', function(stashId, slots, maxWeight)
    TriggerEvent('inventory:client:SetCurrentStash', stashId)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', stashId, { maxweight = maxWeight, slots = slots })
end)

-- garages de propriete : on active le garage qb-garages quand on s'approche d'un garage accessible
local propertyGarages = {}
RegisterNetEvent('qbx_properties:client:setGarages', function(list)
    propertyGarages = list or {}
end)
CreateThread(function()
    local actif = nil
    while true do
        local sleep = 2000
        local pos = GetEntityCoords(cache.ped)
        local proche = nil
        for i = 1, #propertyGarages do
            local c = propertyGarages[i].coords
            if #(pos - vec3(c.x, c.y, c.z)) < 25.0 then proche = propertyGarages[i].id break end
        end
        if proche ~= actif then
            if proche then TriggerEvent('qb-garages:client:setHouseGarage', proche, true) end
            actif = proche
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('qbx_properties:client:createInterior', function(interiorHash, interiorCoords)
    lib.requestModel(interiorHash, 2000)
    interiorShell = CreateObjectNoOffset(interiorHash, interiorCoords.x, interiorCoords.y, interiorCoords.z, false, false, false)
    FreezeEntityPosition(interiorShell, true)
    SetModelAsNoLongerNeeded(interiorHash)
end)

RegisterNetEvent('qbx_properties:client:loadDecorations', function(decorations)
    for i = 1, #decorations do
        local decoration = decorations[i]
        lib.requestModel(decoration.model, 5000)
        DecorationObjects[decoration.id] = CreateObjectNoOffset(decoration.model, decoration.coords.x, decoration.coords.y, decoration.coords.z, false, false, false)
        SetEntityCollision(DecorationObjects[decoration.id], true, true)
        FreezeEntityPosition(DecorationObjects[decoration.id], true)
        SetEntityRotation(DecorationObjects[decoration.id], decoration.rotation.x, decoration.rotation.y, decoration.rotation.z, 2, false)
        SetModelAsNoLongerNeeded(decoration.model)
    end
end)

RegisterNetEvent('qbx_properties:client:addDecoration', function(id, hash, coords, rotation)
    lib.requestModel(hash, 5000)
    DecorationObjects[id] = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    FreezeEntityPosition(DecorationObjects[id], true)
    SetEntityRotation(DecorationObjects[id], rotation.x, rotation.y, rotation.z, 2, false)
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('qbx_properties:client:removeDecoration', function(objectId)
    if DoesEntityExist(DecorationObjects[objectId]) then DeleteEntity(DecorationObjects[objectId]) end
    DecorationObjects[objectId] = nil
end)

RegisterNetEvent('qbx_properties:client:unloadProperty', function()
    DoScreenFadeIn(1000)
    insideProperty = false
    if DoesEntityExist(interiorShell) then DeleteEntity(interiorShell) end
    for _, v in pairs(DecorationObjects) do
        if DoesEntityExist(v) then DeleteEntity(v) end
    end
    interiorShell = nil
    DecorationObjects = {}
end)

local function singlePropertyMenu(property, noBackMenu)
    local options = {}
    if property.acces then
        options[#options + 1] = {
            title = locale('menu.enter'),
            icon = 'cog',
            arrow = true,
            onSelect = function()
                DoScreenFadeOut(1000)
                while not IsScreenFadedOut() do Wait(0) end
            end,
            serverEvent = 'qbx_properties:server:enterProperty',
            args = { id = property.id }
        }
    elseif property.owner == nil then
        if property.rent_interval then
            options[#options + 1] = {
                title = 'Louer',
                icon = 'dollar-sign',
                arrow = true,
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = string.format('Location - %s', property.property_name),
                        content = string.format('Louer %s pour $%s, preleves toutes les %s heure(s) ?', property.property_name, property.price, property.rent_interval),
                        centered = true,
                        cancel = true
                    })
                    if alert == 'confirm' then
                        TriggerServerEvent('qbx_properties:server:rentProperty', property.id)
                    end
                end,
            }
        else
            options[#options + 1] = {
                title = 'Acheter',
                icon = 'dollar-sign',
                arrow = true,
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = string.format('Achat - %s', property.property_name),
                        content = string.format('Acheter %s pour $%s ?', property.property_name, property.price),
                        centered = true,
                        cancel = true
                    })
                    if alert == 'confirm' then
                        TriggerServerEvent('qbx_properties:server:buyProperty', property.id)
                    end
                end,
            }
        end
    else
        options[#options + 1] = {
            title = locale('menu.ring_doorbell'),
            icon = 'bell',
            arrow = true,
            serverEvent = 'qbx_properties:server:ringProperty',
            args = { id = property.id }
        }
    end
    local menu = 'qbx_properties_propertiesMenu'
    ---@diagnostic disable-next-line: cast-local-type
    if noBackMenu then menu = nil end
    lib.registerContext({
        id = 'qbx_properties_propertyMenu',
        title = property.property_name,
        menu = menu,
        options = options
    })
    lib.showContext('qbx_properties_propertyMenu')
end

local function propertyMenu(propertyList, owned)
    local options = {
        {
            title = locale('menu.retrieve_properties'),
            description = locale('menu.show_owned_properties'),
            icon = 'bars',
            onSelect = function()
                propertyMenu(propertyList, true)
            end
        }
    }
    for i = 1, #propertyList do
        if owned and propertyList[i].acces then
            options[#options + 1] = {
                title = propertyList[i].property_name,
                icon = 'home',
                arrow = true,
                onSelect = function()
                    singlePropertyMenu(propertyList[i])
                end
            }
        elseif not owned then
            options[#options + 1] = {
                title = propertyList[i].property_name,
                icon = 'home',
                arrow = true,
                onSelect = function()
                    singlePropertyMenu(propertyList[i])
                end
            }
        end
    end
    lib.registerContext({
        id = 'qbx_properties_propertiesMenu',
        title = locale('menu.properties'),
        options = options
    })
    lib.showContext('qbx_properties_propertiesMenu')
end

function PreparePropertyMenu(propertyCoords)
    local propertyList = lib.callback.await('qbx_properties:callback:requestProperties', false, propertyCoords)
    if #propertyList == 1 then
        singlePropertyMenu(propertyList[1], true)
    else
        propertyMenu(propertyList)
    end
end

CreateThread(function()
    for i = 1, #sharedConfig.apartmentOptions do
        local data = sharedConfig.apartmentOptions[i]

        if not blips[data.enter] then
            blips[data.enter] = createBlip(data.enter, data.label)
        end
    end

    properties = lib.callback.await('qbx_properties:callback:loadProperties')
    while true do
        local sleep = 800
        local playerCoords = GetEntityCoords(cache.ped)
        for i = 1, #properties do
            if #(playerCoords - properties[i].xyz) < 1.6 then
                sleep = 0
                qbx.drawText3d({ coords = properties[i].xyz, text = locale('drawtext.view_property') })
                if IsControlJustPressed(0, 38) then
                    PreparePropertyMenu(properties[i])
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('qbx_properties:client:concealPlayers', function(playerIds)
    local players = GetActivePlayers()
    for i = 1, #players do NetworkConcealPlayer(players[i], false, false) end
    concealWhitelist = playerIds
    if not isConcealing then
        isConcealing = true
        while isConcealing do
            players = GetActivePlayers()
            for i = 1, #players do
                if not lib.table.contains(concealWhitelist, GetPlayerServerId(players[i])) then
                    NetworkConcealPlayer(players[i], true, false)
                end
            end
            Wait(3000)
        end
    end
end)

RegisterNetEvent('qbx_properties:client:revealPlayers', function()
    local players = GetActivePlayers()
    for i = 1, #players do NetworkConcealPlayer(players[i], false, false) end
    isConcealing = false
end)

RegisterNetEvent('qbx_properties:client:addProperty', function(propertyCoords)
    if lib.table.contains(properties, propertyCoords) then return end
    properties[#properties + 1] = propertyCoords
end)
-- liste des portes rechargee apres une suppression ou la creation d'appartements
RegisterNetEvent('qbx_properties:client:reloadProperties', function()
    properties = lib.callback.await('qbx_properties:callback:loadProperties') or properties
end)
