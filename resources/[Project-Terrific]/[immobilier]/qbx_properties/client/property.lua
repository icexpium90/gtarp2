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

---------------------------------------------------------------- placement libre avec apercu
-- Vise avec la souris : un fantome du meuble (ou un marqueur) suit le viseur. Molette ou fleches : tourner.
-- Clic gauche / Entree : valider. Clic droit / Retour : annuler.
local HAUTEUR_POINT = 0.9 -- le point d'interaction est a hauteur de hanches au-dessus de la surface visee

function PlacementApercu(modele, titre, hauteur)
    local fantome
    if modele then
        lib.requestModel(modele, 5000)
        fantome = CreateObjectNoOffset(joaat(modele), GetEntityCoords(cache.ped), false, false, false)
        SetEntityAlpha(fantome, 170, false)
        SetEntityCollision(fantome, false, false)
        FreezeEntityPosition(fantome, true)
        SetModelAsNoLongerNeeded(joaat(modele))
    end
    local heading = (GetEntityHeading(cache.ped) + 180.0) % 360.0
    lib.showTextUI(('%s  \n[Souris] viser  \n[Molette / fleches] tourner  \n[Clic gauche / Entree] valider  \n[Clic droit / Retour] annuler'):format(titre or 'Placement'))
    local resultat
    while true do
        Wait(0)
        for _, c in ipairs({ 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 200, 257, 263 }) do DisableControlAction(0, c, true) end
        if IsDisabledControlPressed(0, 14) or IsControlPressed(0, 174) then heading = (heading - 3.0) % 360.0 end
        if IsDisabledControlPressed(0, 15) or IsControlPressed(0, 175) then heading = (heading + 3.0) % 360.0 end
        local hit, _, c = lib.raycast.fromCamera(1 | 16, 4, 10.0)
        local valide = hit and #(GetEntityCoords(cache.ped) - c) < 10.0
        if valide then
            if fantome then
                SetEntityCoordsNoOffset(fantome, c.x, c.y, c.z, false, false, false)
                SetEntityHeading(fantome, heading)
            end
            DrawMarker(25, c.x, c.y, c.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8, 60, 200, 120, 160, false, false, 2, false, nil, nil, false)
            local fx, fy = math.sin(math.rad(-heading)) * 0.5, math.cos(math.rad(-heading)) * 0.5
            DrawLine(c.x, c.y, c.z + 0.05, c.x + fx, c.y + fy, c.z + 0.05, 60, 200, 120, 255)
            if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then
                resultat = { x = c.x, y = c.y, z = c.z + (hauteur or HAUTEUR_POINT), w = heading }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end
    end
    lib.hideTextUI()
    if fantome and DoesEntityExist(fantome) then DeleteEntity(fantome) end
    return resultat
end

local function choisirMeuble(titre)
    local options = {}
    for _, m in ipairs(sharedConfig.meubles or {}) do
        options[#options + 1] = { value = m.model or '', label = m.label }
    end
    return options
end

function OuvrirMenuPoints()
    local points = {
        { kind = 'safe', label = 'Coffre-fort (argent propre et sale)', icon = 'vault', modele = sharedConfig.coffreFort },
        { kind = 'clothing', label = locale('menu.place_clothing'), icon = 'shirt' },
        { kind = 'logout', label = locale('menu.place_logout'), icon = 'bed' },
        { kind = 'exit', label = locale('menu.place_exit'), icon = 'door-open' },
    }
    local opts = {
        {
            title = 'Ajouter un coffre',
            description = 'Taille, nom et meuble, puis placement libre (jusqu\'a 5 coffres)',
            icon = 'box',
            onSelect = function()
                local input = lib.inputDialog('Nouveau coffre', {
                    { type = 'select', label = 'Taille', required = true, default = 'moyen', options = {
                        { value = 'petit', label = 'Petit (30 places, 100 kg)' },
                        { value = 'moyen', label = 'Moyen (50 places, 250 kg)' },
                        { value = 'grand', label = 'Grand / armurerie (80 places, 600 kg)' } } },
                    { type = 'input', label = 'Nom (facultatif)', placeholder = 'Armurerie, Cave...', max = 30 },
                    { type = 'select', label = 'Meuble', required = true, default = 'prop_box_wood05a', options = choisirMeuble() },
                })
                if not input then return end
                local modele = input[3] ~= '' and input[3] or nil
                local pos = PlacementApercu(modele, 'Placer le coffre')
                if pos then TriggerServerEvent('qbx_properties:server:setInteraction', 'stash', input[1], input[2], pos, input[3]) end
            end
        },
        {
            title = 'Deplacer un coffre',
            description = 'Garde son contenu, change sa position et son meuble',
            icon = 'arrows-up-down-left-right',
            arrow = true,
            onSelect = function()
                local liste = lib.callback.await('qbx_properties:callback:listStashes', false) or {}
                local o = {}
                for _, c in ipairs(liste) do
                    o[#o + 1] = { title = c.label, description = ('%s places'):format(c.slots or '?'), icon = 'box', onSelect = function()
                        local input = lib.inputDialog(c.label, {
                            { type = 'select', label = 'Meuble', required = true, default = c.model or '', options = choisirMeuble() },
                        })
                        if not input then return end
                        local pos = PlacementApercu(input[1] ~= '' and input[1] or nil, 'Deplacer : ' .. c.label)
                        if pos then TriggerServerEvent('qbx_properties:server:setInteraction', 'stash', nil, nil, pos, input[1], c.index) end
                    end }
                end
                if #o == 0 then o[1] = { title = 'Aucun coffre', readOnly = true } end
                lib.registerContext({ id = 'qbx_properties_moveStash', title = 'Deplacer un coffre', menu = 'qbx_properties_pointsMenu', options = o })
                lib.showContext('qbx_properties_moveStash')
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
            description = 'Placement libre avec apercu',
            icon = pt.icon,
            onSelect = function()
                local pos = PlacementApercu(pt.modele, pt.label)
                if pos then TriggerServerEvent('qbx_properties:server:setInteraction', pt.kind, nil, nil, pos, pt.modele) end
            end
        }
    end
    lib.registerContext({ id = 'qbx_properties_pointsMenu', title = locale('menu.place_points'), menu = 'qbx_properties_manageMenu', options = opts })
    lib.showContext('qbx_properties_pointsMenu')
end

---------------------------------------------------------------- meubles des points (coffres, coffre-fort) visibles dans le bien
local meublesPoints = {}
local function retirerMeubles()
    for _, e in ipairs(meublesPoints) do if DoesEntityExist(e) then DeleteEntity(e) end end
    meublesPoints = {}
end
local function poserMeubles(liste)
    retirerMeubles()
    for _, it in ipairs(liste or {}) do
        if it.model then
            local h = joaat(it.model)
            if IsModelInCdimage(h) then
                lib.requestModel(h, 5000)
                local e = CreateObjectNoOffset(h, it.coords.x, it.coords.y, it.coords.z - HAUTEUR_POINT, false, false, false)
                SetEntityHeading(e, it.w or 0.0)
                FreezeEntityPosition(e, true)
                SetModelAsNoLongerNeeded(h)
                meublesPoints[#meublesPoints + 1] = e
            end
        end
    end
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
            title = 'Garage et ascenseurs',
            description = 'Biens MLO : places de parking (vehicules visibles), ascenseurs entre etages',
            icon = 'warehouse',
            arrow = true,
            onSelect = function()
                OuvrirMenuGarage()
            end
        },
        {
            title = locale('menu.place_points'),
            description = 'Coffres, coffre-fort, vestiaire, lit, sortie : placement libre avec apercu',
            icon = 'location-crosshairs',
            arrow = true,
            onSelect = function()
                OuvrirMenuPoints()
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

local interactOptions
local function construireActions()
    if interactOptions then return interactOptions end
    interactOptions = {
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
    return interactOptions
end

local function checkInteractions()
    construireActions()
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
    poserMeubles(interactionsData)
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
    retirerMeubles()
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

-- Menu proprietaire : touche F6 (modifiable : Echap > Parametres > Raccourcis > FiveM) ou /monbien, partout dans le bien
RegisterCommand('monbien', function()
    if not insideProperty and not (ProcheBien and ProcheBien.proprietaire) then
        return Bridge.Notify('Entrez dans votre bien pour ouvrir le menu proprietaire (ou /mesbiens pour la liste).', 'error')
    end
    prepareManageMenu()
end, false)
RegisterKeyMapping('monbien', 'Menu proprietaire (immobilier)', 'keyboard', 'F6')
RegisterNetEvent('qbx_properties:client:menuProprietaire', function() ExecuteCommand('monbien') end)


---------------------------------------------------------------- biens MLO : gestion sur place, garage physique, ascenseurs
ProcheBien = nil

local function menuAscenseur(asc)
    local opts = {}
    local pos = GetEntityCoords(cache.ped)
    for _, e in ipairs(asc.etages) do
        local ici = #(pos - vec3(e.x, e.y, e.z)) < 2.5
        opts[#opts + 1] = {
            title = e.nom, icon = ici and 'location-dot' or 'elevator', disabled = ici,
            description = ici and 'Vous etes ici' or nil,
            onSelect = function()
                local ped = cache.ped
                local veh = cache.vehicle
                local entite = (veh and asc.vehicule and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped
                DoScreenFadeOut(400)
                while not IsScreenFadedOut() do Wait(0) end
                RequestCollisionAtCoord(e.x, e.y, e.z)
                -- monte-charge : etage enregistre au niveau du sol ; ascenseur pieton : a hauteur du joueur
                local z = asc.vehicule and (e.z + (entite == ped and 1.0 or 0.5)) or e.z
                SetEntityCoords(entite, e.x, e.y, z, false, false, false, false)
                SetEntityHeading(entite, e.w or 0.0)
                Wait(500)
                DoScreenFadeIn(400)
            end,
        }
    end
    lib.registerContext({ id = 'qbx_properties_ascenseur', title = asc.nom, options = opts })
    lib.showContext('qbx_properties_ascenseur')
end

function OuvrirMenuGarage()
    local opts = {
        { title = 'Ajouter une place de parking', description = 'Visez le sol : la voiture fantome montre la place (biens MLO)', icon = 'square-parking',
          onSelect = function()
              local pos = PlacementApercu('sultanrs', 'Place de parking', 0.0)
              if pos then TriggerServerEvent('qbx_properties:server:ajouterPlace', pos) end
          end },
        { title = 'Retirer la place la plus proche', icon = 'trash', onSelect = function()
              TriggerServerEvent('qbx_properties:server:retirerPlace')
          end },
        { title = 'Creer un ascenseur', description = 'Placez chaque etage (2 a 12), puis validez', icon = 'elevator',
          onSelect = function()
              local input = lib.inputDialog('Nouvel ascenseur', {
                  { type = 'input', label = 'Nom', default = 'Ascenseur', max = 24, required = true },
                  { type = 'checkbox', label = 'Monte-charge (accepte les vehicules)' },
              })
              if not input then return end
              local etages = {}
              while #etages < 12 do
                  local nom = lib.inputDialog(('Etage %d'):format(#etages + 1), {
                      { type = 'input', label = 'Nom de l\'etage', default = (#etages == 0 and 'Rez-de-chaussee' or ('Etage %d'):format(#etages)), max = 24, required = true },
                  })
                  if not nom then break end
                  local pos = PlacementApercu(nil, ('Etage %d : %s'):format(#etages + 1, nom[1]), input[2] and 0.0 or 1.0)
                  if not pos then break end
                  pos.nom = nom[1]
                  etages[#etages + 1] = pos
                  if #etages >= 2 then
                      local encore = lib.alertDialog({ header = input[1], content = ('%d etages places. Ajouter un autre etage ?'):format(#etages), centered = true, cancel = true, labels = { confirm = 'Oui', cancel = 'Terminer' } })
                      if encore ~= 'confirm' then break end
                  end
              end
              if #etages >= 2 then
                  TriggerServerEvent('qbx_properties:server:creerAscenseur', input[1], input[2] == true, etages)
              else
                  Bridge.Notify('Il faut au moins 2 etages.', 'error')
              end
          end },
    }
    for i, a in ipairs(ProcheBien and ProcheBien.ascenseurs or {}) do
        opts[#opts + 1] = { title = ('Supprimer : %s'):format(a.nom), description = ('%d etages'):format(#a.etages), icon = 'xmark',
            onSelect = function()
                local ok = lib.alertDialog({ header = a.nom, content = 'Supprimer cet ascenseur ?', centered = true, cancel = true })
                if ok == 'confirm' then TriggerServerEvent('qbx_properties:server:supprimerAscenseur', i) end
            end }
    end
    lib.registerContext({ id = 'qbx_properties_garageMenu', title = 'Garage et ascenseurs', menu = 'qbx_properties_manageMenu', options = opts })
    lib.showContext('qbx_properties_garageMenu')
end

-- proprietes appliquees par le client qui possede l'entite d'un vehicule gare
AddStateBagChangeHandler('ptGarage', nil, function(bagName, _, value)
    if not value then return end
    local limite = GetGameTimer() + 5000
    local ent = GetEntityFromStateBagName(bagName)
    while (not ent or ent == 0) and GetGameTimer() < limite do Wait(50) ent = GetEntityFromStateBagName(bagName) end
    if not ent or ent == 0 or not NetworkHasControlOfEntity(ent) then return end
    if value.props and next(value.props) then QBCore.Functions.SetVehicleProperties(ent, value.props) end
    SetVehicleNumberPlateText(ent, value.plate)
    if value.engine then SetVehicleEngineHealth(ent, value.engine + 0.0) end
    if value.body then SetVehicleBodyHealth(ent, value.body + 0.0) end
    SetVehicleOnGroundProperly(ent)
end)

RegisterNetEvent('qbx_properties:client:vehiculePris', function(netId, fuel)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 then
        SetVehicleDoorsLocked(veh, 1)
        if fuel and GetResourceState('cdn-fuel') == 'started' then pcall(function() exports['cdn-fuel']:SetFuel(veh, fuel + 0.0) end) end
    end
end)

RegisterNetEvent('qbx_properties:client:quitterVehicule', function()
    if cache.vehicle then TaskLeaveVehicle(cache.ped, cache.vehicle, 0) end
end)

-- donnees du bien MLO a proximite (toutes les 3 s)
CreateThread(function()
    while true do
        if not insideProperty and LocalPlayer.state.isLoggedIn ~= false then
            local data = lib.callback.await('qbx_properties:callback:proximite', false)
            local avant = ProcheBien and ProcheBien.id
            ProcheBien = data
            if data then
                interactions = data.interactions
                poserMeubles(data.interactions)
            elseif avant then
                interactions = {}
                retirerMeubles()
            end
        end
        Wait(3000)
    end
end)

-- interactions sur place : coffres, coffre-fort, vestiaire, lit, ascenseurs, garage physique
CreateThread(function()
    while true do
        local attente = 750
        if ProcheBien and not insideProperty and not IsDecorating then
            local actions = construireActions()
            local pos = GetEntityCoords(cache.ped)
            for _, it in ipairs(ProcheBien.interactions or {}) do
                if #(pos - it.coords) < 1.5 then
                    attente = 0
                    local action = actions[it.type]
                    if action then action(it.coords, it) end
                end
            end
            for _, asc in ipairs(ProcheBien.ascenseurs or {}) do
                for _, e in ipairs(asc.etages) do
                    local d = #(pos - vec3(e.x, e.y, e.z))
                    local portee = (asc.vehicule and cache.vehicle) and 4.0 or 1.5
                    if d < 12.0 then
                        attente = 0
                        DrawMarker(asc.vehicule and 1 or 25, e.x, e.y, e.z - (asc.vehicule and -0.02 or 0.98), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            asc.vehicule and 3.0 or 0.9, asc.vehicule and 3.0 or 0.9, asc.vehicule and 0.3 or 0.9, 80, 160, 255, 120, false, false, 2, false, nil, nil, false)
                        if d < portee then
                            qbx.drawText3d({ coords = vec3(e.x, e.y, e.z + 0.3), text = ('[E] %s - %s'):format(asc.nom, e.nom) })
                            if IsControlJustPressed(0, 38) then menuAscenseur(asc) end
                        end
                    end
                end
            end
            -- garer : conducteur sur une place libre
            if cache.vehicle and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped then
                for _, p in ipairs(ProcheBien.places or {}) do
                    local d = #(GetEntityCoords(cache.vehicle) - vec3(p.x, p.y, p.z))
                    if d < 15.0 then
                        attente = 0
                        DrawMarker(1, p.x, p.y, p.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 4.5, 0.3, 60, 200, 120, 90, false, false, 2, false, nil, nil, false)
                        if d < 2.5 then
                            qbx.drawText3d({ coords = vec3(p.x, p.y, p.z + 1.0), text = '[E] Garer le vehicule ici' })
                            if IsControlJustPressed(0, 38) then
                                local veh = cache.vehicle
                                local fuel = GetVehicleFuelLevel(veh)
                                if GetResourceState('cdn-fuel') == 'started' then pcall(function() fuel = exports['cdn-fuel']:GetFuel(veh) end) end
                                TriggerServerEvent('qbx_properties:server:garerVehicule', VehToNet(veh), QBCore.Functions.GetVehicleProperties(veh),
                                    fuel, GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh))
                                Wait(1000)
                            end
                        end
                    end
                end
            elseif not cache.vehicle then
                -- prendre un vehicule gare (a pied, a cote)
                local veh = lib.getClosestVehicle(pos, 3.0, false)
                if veh and Entity(veh).state.ptGarage then
                    attente = 0
                    local c = GetEntityCoords(veh)
                    qbx.drawText3d({ coords = vec3(c.x, c.y, c.z + 1.0), text = ('[E] Prendre %s'):format(Entity(veh).state.ptGarage.plate or 'le vehicule') })
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('qbx_properties:server:prendreVehicule', VehToNet(veh))
                        Wait(1000)
                    end
                end
            end
        end
        Wait(attente)
    end
end)
