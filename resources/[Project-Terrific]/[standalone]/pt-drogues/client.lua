local QBCore = exports['qb-core']:GetCoreObject()

-- ---------------------------------------------------------------------------------------------------------------
-- Postes de transformation (qb-target)

local zones = {}
local occupe = false

local function definition(id)
    for _, p in ipairs(Config.Postes) do
        if p.id == id then return p end
    end
end

local function transformer(id)
    if occupe then return end
    local p = definition(id)
    local lots, duree = lib.callback.await('pt-drogues:commencer', false, id)
    if not lots then return end
    occupe = true
    local ok = lib.progressBar({
        duration = duree,
        label = lots > 1 and ('%s (x%d)'):format(p.label, lots) or p.label,
        useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = p.anim and { dict = p.anim.dict, clip = p.anim.nom, flag = 1 } or nil,
    })
    occupe = false
    if ok then TriggerServerEvent('pt-drogues:terminer', id) end
end

local function creerZones(postes)
    for _, nom in ipairs(zones) do exports['qb-target']:RemoveZone(nom) end
    zones = {}
    for _, p in ipairs(Config.Postes) do
        local c = postes and postes[p.id] or p.coords
        local nom = 'pt_drogues_' .. p.id
        exports['qb-target']:AddBoxZone(nom, vector3(c.x, c.y, c.z), 1.6, 1.6, {
            name = nom, heading = 0.0, debugPoly = false, minZ = c.z - 1.5, maxZ = c.z + 1.5,
        }, {
            options = { { icon = p.icone or 'fas fa-hand', label = p.label, action = function() transformer(p.id) end } },
            distance = 2.0,
        })
        zones[#zones + 1] = nom
    end
end

CreateThread(function()
    Wait(1000)
    creerZones(GlobalState.pt_drogues_postes)
end)
AddStateBagChangeHandler('pt_drogues_postes', 'global', function(_, _, valeur)
    SetTimeout(0, function() creerZones(valeur) end)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Go-fast : zone sur la carte, conduite et combat de l'equipage (fait par le joueur qui "possede" les entites)

local blip, blipId, cibleVeh = nil, nil, nil
local groupe = joaat('PT_GOFAST')
AddRelationshipGroup('PT_GOFAST')

local centre = nil
local function majBlip(g)
    if not g or not g.zone then
        if blip then RemoveBlip(blip) blip = nil end
        if centre then RemoveBlip(centre) centre = nil end
        return
    end
    if not blip or blipId ~= g.id then
        if blip then RemoveBlip(blip) end
        if centre then RemoveBlip(centre) end
        -- zone rouge (approximative) + icone au centre pour la reperer de loin, et GPS pose dessus
        blip = AddBlipForRadius(g.zone.x + 0.0, g.zone.y + 0.0, g.zone.z + 0.0, 300.0)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 128)
        SetBlipDisplay(blip, 4)
        centre = AddBlipForCoord(g.zone.x + 0.0, g.zone.y + 0.0, g.zone.z + 0.0)
        SetBlipSprite(centre, 229)          -- voiture
        SetBlipColour(centre, 1)
        SetBlipScale(centre, 1.0)
        SetBlipFlashes(centre, true)
        SetBlipAsShortRange(centre, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Go-fast (zone approximative)')
        EndTextCommandSetBlipName(centre)
        SetNewWaypoint(g.zone.x + 0.0, g.zone.y + 0.0)
        blipId = g.id
        print(('[pt-drogues] go-fast : zone %.0f, %.0f'):format(g.zone.x, g.zone.y))
    else
        SetBlipCoords(blip, g.zone.x + 0.0, g.zone.y + 0.0, g.zone.z + 0.0)
        SetBlipCoords(centre, g.zone.x + 0.0, g.zone.y + 0.0, g.zone.z + 0.0)
    end
end

-- /gofast : remet le GPS sur la zone du go-fast en cours
RegisterCommand('gofast', function()
    local g = GlobalState.pt_gofast
    if not g or not g.zone then
        return TriggerEvent('QBCore:Notify', 'Aucun go-fast en cours.', 'error')
    end
    majBlip(g)
    SetNewWaypoint(g.zone.x + 0.0, g.zone.y + 0.0)
    TriggerEvent('QBCore:Notify', 'GPS pose sur la zone du go-fast.', 'success')
end, false)

AddStateBagChangeHandler('pt_gofast', 'global', function(_, _, g)
    majBlip(g)
    if not g and cibleVeh then
        if DoesEntityExist(cibleVeh) then exports['qb-target']:RemoveTargetEntity(cibleVeh) end
        cibleVeh = nil
    end
end)

local function entite(netId)
    if netId and NetworkDoesEntityExistWithNetworkId(netId) then return NetToEnt(netId) end
    return 0
end

local function equipageMort(g)
    for _, n in ipairs(g.peds or {}) do
        local p = entite(n)
        if p ~= 0 and not IsPedDeadOrDying(p, true) then return false end
    end
    return true
end

-- l'equipage passe a l'attaque : voiture arretee, conducteur mort, ou joueurs tout pres
local attaque = {}
local function preparerPed(p, g)
    SetPedRelationshipGroupHash(p, groupe)
    SetRelationshipBetweenGroups(5, groupe, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, groupe)
    SetPedAccuracy(p, g.precision or 35)
    SetPedCombatAttributes(p, 46, true)   -- se bat toujours
    SetPedCombatAttributes(p, 5, true)
    SetPedCombatAttributes(p, 2, true)    -- peut tirer depuis le vehicule
    SetPedFleeAttributes(p, 0, false)
    SetPedKeepTask(p, true)
    SetBlockingOfNonTemporaryEvents(p, false)
end

CreateThread(function()
    local arretDepuis, recale, aRoule, conduite = nil, {}, {}, {}
    while true do
        local g = GlobalState.pt_gofast
        if not g then
            Wait(2000)
        else
            Wait(500)
            if g.zone then majBlip(g) end
            local veh = entite(g.veh)
            if veh ~= 0 then
                -- coffre a fouiller (tous les joueurs)
                if cibleVeh ~= veh then
                    cibleVeh = veh
                    exports['qb-target']:AddTargetEntity(veh, {
                        options = { {
                            icon = 'fas fa-box-open', label = 'Fouiller le coffre',
                            canInteract = function() local s = GlobalState.pt_gofast return s and not s.fouille and equipageMort(s) end,
                            action = function()
                                local s = GlobalState.pt_gofast
                                if not s then return end
                                if lib.progressBar({ duration = 6000, label = 'Fouille du coffre...', canCancel = true,
                                    disable = { move = true, car = true, combat = true },
                                    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 } }) then
                                    TriggerServerEvent('pt-drogues:fouiller', s.id)
                                end
                            end,
                        } },
                        distance = 3.0,
                    })
                end
                -- pilotage : seulement par le joueur qui controle les entites
                local driver = GetPedInVehicleSeat(veh, -1)
                if NetworkHasControlOfEntity(veh) and not recale[g.id] then
                    -- departs approximatifs : on pose la voiture sur la route la plus proche
                    local p = GetEntityCoords(veh)
                    local ok, noeud, cap = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
                    if ok and #(noeud - p) < 150.0 and #(noeud - p) > 2.0 then
                        SetEntityCoords(veh, noeud.x, noeud.y, noeud.z + 0.5, false, false, false, false)
                        SetEntityHeading(veh, cap)
                    end
                    SetVehicleOnGroundProperly(veh)
                    recale[g.id] = true
                end
                local vitesse = GetEntitySpeed(veh)
                local moi = GetEntityCoords(PlayerPedId())
                local proche = #(moi - GetEntityCoords(veh)) < 30.0
                if vitesse > 8.0 then aRoule[g.id] = true end
                if vitesse < 2.0 then arretDepuis = arretDepuis or GetGameTimer() else arretDepuis = nil end
                local conducteurHS = driver == 0 or IsPedDeadOrDying(driver, true)
                -- voiture arretee (apres avoir roule) : bloquee ou forcee a s'arreter
                local bloque = aRoule[g.id] and arretDepuis and GetGameTimer() - arretDepuis > 4000
                for _, n in ipairs(g.peds or {}) do
                    local ped = entite(n)
                    if ped ~= 0 and NetworkHasControlOfEntity(ped) and not IsPedDeadOrDying(ped, true) then
                        preparerPed(ped, g)
                        local cle = g.id .. ':' .. n
                        if conducteurHS or bloque or GetVehicleEngineHealth(veh) < 300 or (proche and vitesse < 8.0) then
                            if not attaque[cle] then
                                attaque[cle] = true
                                ClearPedTasks(ped)
                                TaskLeaveVehicle(ped, veh, 256)
                                SetTimeout(1200, function()
                                    if DoesEntityExist(ped) then TaskCombatHatedTargetsAroundPed(ped, 120.0, 0) end
                                end)
                            end
                        elseif ped == driver and not attaque[cle] and (not conduite[cle] or (vitesse < 3.0 and GetGameTimer() - conduite[cle] > 10000)) then
                            -- conduite vers l'arrivee (relancee si la voiture n'avance plus, ex. apres un changement de proprietaire)
                            conduite[cle] = GetGameTimer()
                            TaskVehicleDriveToCoordLongrange(ped, veh, g.arrivee.x, g.arrivee.y, g.arrivee.z, g.vitesse or 32.0, 787004, 25.0)
                            SetDriverAbility(ped, 1.0)
                            SetDriverAggressiveness(ped, 0.8)
                        end
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Weed simple : champ de Grapeseed, PNJ transformateur, rachat au weed shop, vente aux passants

local W = Config.Weed
local PLANTS = PositionsPlants()
local plantsPoses = {}       -- [i] = objet
local transfoPed = nil

local function solSous(p)
    local ok, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 15.0, false)
    return ok and z or p.z
end

local function recolter(i)
    if occupe then return end
    if not lib.callback.await('pt-drogues:recolteDebut', false, i) then
        return TriggerEvent('QBCore:Notify', 'Ce plant n\'est pas pret (ou quelqu\'un le recolte deja).', 'error')
    end
    occupe = true
    local ok = lib.progressBar({ duration = W.dureeRecolte, label = 'Recolte du plant...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 } })
    occupe = false
    if ok then TriggerServerEvent('pt-drogues:recolteFin') end
end

local function majPlants()
    local etat = GlobalState.pt_weed_plants or {}
    local pres = #(GetEntityCoords(PlayerPedId()) - W.champ.centre) < 120.0
    local h = joaat(W.modelePlant)
    for i, p in ipairs(PLANTS) do
        local pret = (etat[i] or 0) == 0
        if pres and pret and not plantsPoses[i] then
            if lib.requestModel(h, 5000) then
                local o = CreateObject(h, p.x, p.y, solSous(p), false, false, false)
                FreezeEntityPosition(o, true)
                plantsPoses[i] = o
                exports['qb-target']:AddTargetEntity(o, {
                    options = { { icon = 'fas fa-cannabis', label = 'Recolter le plant', action = function() recolter(i) end } },
                    distance = 2.5,
                })
            end
        elseif (not pres or not pret) and plantsPoses[i] then
            exports['qb-target']:RemoveTargetEntity(plantsPoses[i])
            if DoesEntityExist(plantsPoses[i]) then DeleteEntity(plantsPoses[i]) end
            plantsPoses[i] = nil
        end
    end
end

local function transformer(action, titre)
    if occupe then return end
    local qte, duree = lib.callback.await('pt-drogues:transfoDebut', false, action)
    if not qte then return end
    occupe = true
    local ok = lib.progressBar({ duration = duree, label = ('%s (x%d)'):format(titre, qte), canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 } })
    occupe = false
    if ok then TriggerServerEvent('pt-drogues:transfoFin') end
end

local function majTransfo()
    local t = GlobalState.pt_weed_transfo
    if not t then return end
    local pres = #(GetEntityCoords(PlayerPedId()) - vector3(t.x, t.y, t.z)) < 60.0
    if pres and not transfoPed then
        local h = joaat(W.transformateur.ped)
        if not lib.requestModel(h, 5000) then return end
        local ped = CreatePed(4, h, t.x, t.y, t.z, t.w or 0.0, false, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING_POT', 0, true)
        transfoPed = ped
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                { icon = 'fas fa-box', label = ('Transformer les apex en pochons (%d apex = 1 pochon)'):format(W.apexParPochon),
                  action = function() transformer('pochons', 'Mise en pochons') end },
                { icon = 'fas fa-cannabis', label = ('Reconvertir les pochons en fleurs (1 pochon = %d fleurs)'):format(W.fleursParPochon),
                  action = function() transformer('fleurs', 'Reconversion en fleurs') end },
                { icon = 'fas fa-joint', label = ('Rouler des joints (1 fleur = %d joints)'):format(W.jointsParFleur),
                  action = function() transformer('joints', 'Il roule les joints') end },
            },
            distance = 2.5,
        })
    elseif not pres and transfoPed then
        exports['qb-target']:RemoveTargetEntity(transfoPed)
        if DoesEntityExist(transfoPed) then DeleteEntity(transfoPed) end
        transfoPed = nil
    end
end

AddStateBagChangeHandler('pt_weed_transfo', 'global', function()
    SetTimeout(0, function()
        if transfoPed then
            exports['qb-target']:RemoveTargetEntity(transfoPed)
            if DoesEntityExist(transfoPed) then DeleteEntity(transfoPed) end
            transfoPed = nil
        end
    end)
end)

CreateThread(function()
    while true do
        majPlants()
        majTransfo()
        Wait(2000)
    end
end)

-- rachat au weed shop (comptoir)
CreateThread(function()
    Wait(1500)
    local c = W.weedshop.coords
    exports['qb-target']:AddBoxZone('pt_weedshop_rachat', vector3(c.x - 0.9, c.y, c.z), 1.2, 2.0, {
        name = 'pt_weedshop_rachat', heading = 0.0, debugPoly = false, minZ = c.z - 1.2, maxZ = c.z + 1.0,
    }, {
        options = { { icon = 'fas fa-hand-holding-dollar', label = ('Revendre ta weed au shop (joint $%d, fleur $%d, pochon $%d)'):format(
            W.weedshop.prix.joint, W.weedshop.prix.fleur, W.weedshop.prix.pochon),
            action = function() TriggerServerEvent('pt-drogues:vendreWeedshop') end } },
        distance = 2.5,
    })
end)

-- vente aux passants (Alt sur n'importe quel PNJ a pied)
local function aDeLaWeed()
    for _, it in ipairs({ 'weed_pochon', 'weed_apex', 'weed_fleur', 'joint' }) do
        if QBCore.Functions.HasItem(it) then return true end
    end
    return false
end

CreateThread(function()
    Wait(1500)
    exports['qb-target']:AddGlobalPed({
        options = { {
            icon = 'fas fa-cannabis', label = 'Proposer de la weed',
            canInteract = function(ent)
                return not IsPedAPlayer(ent) and not IsPedDeadOrDying(ent, true) and not IsPedInAnyVehicle(ent, false)
                    and NetworkGetEntityIsNetworked(ent) and GetPedType(ent) ~= 28 and not occupe and aDeLaWeed()
            end,
            action = function(ent)
                if occupe then return end
                occupe = true
                local moi = PlayerPedId()
                ClearPedTasks(ent)
                TaskTurnPedToFaceEntity(ent, moi, 1500)
                TaskTurnPedToFaceEntity(moi, ent, 1500)
                Wait(1200)
                TaskStandStill(ent, 5000)
                local r = lib.callback.await('pt-drogues:venteRue', false, NetworkGetNetworkIdFromEntity(ent))
                if r == 'ok' then
                    if lib.requestAnimDict('mp_common', 2000) then
                        TaskPlayAnim(moi, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 49, 0, false, false, false)
                        TaskPlayAnim(ent, 'mp_common', 'givetake1_b', 8.0, -8.0, 2000, 49, 0, false, false, false)
                    end
                    Wait(2000)
                end
                if DoesEntityExist(ent) then TaskWanderStandard(ent, 10.0, 10) end
                occupe = false
            end,
        } },
        distance = 2.0,
    })
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() then return end
    for _, o in pairs(plantsPoses) do if DoesEntityExist(o) then DeleteEntity(o) end end
    if transfoPed and DoesEntityExist(transfoPed) then DeleteEntity(transfoPed) end
    exports['qb-target']:RemoveZone('pt_weedshop_rachat')
    exports['qb-target']:RemoveGlobalPed({ 'Proposer de la weed' })
    if blip then RemoveBlip(blip) end
    if centre then RemoveBlip(centre) end
    for _, z in ipairs(zones) do exports['qb-target']:RemoveZone(z) end
end)
