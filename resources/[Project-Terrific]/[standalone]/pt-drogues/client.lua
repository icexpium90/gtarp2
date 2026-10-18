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

local function majBlip(g)
    if not g then
        if blip then RemoveBlip(blip) blip = nil end
        return
    end
    if not blip or blipId ~= g.id then
        if blip then RemoveBlip(blip) end
        blip = AddBlipForRadius(g.zone.x, g.zone.y, g.zone.z, 300.0)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 110)
        blipId = g.id
    else
        SetBlipCoords(blip, g.zone.x, g.zone.y, g.zone.z)
    end
end

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

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() then return end
    if blip then RemoveBlip(blip) end
    for _, z in ipairs(zones) do exports['qb-target']:RemoveZone(z) end
end)
