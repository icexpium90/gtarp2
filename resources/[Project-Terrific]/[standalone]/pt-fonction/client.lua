local QBCore = exports['qb-core']:GetCoreObject()
local vehiculeSorti = nil

local function monMetier()
    local pd = QBCore.Functions.GetPlayerData()
    return pd and pd.job and pd.job.name, pd and pd.job
end

local function sortir(metier, index)
    QBCore.Functions.TriggerCallback('pt-fonction:server:peutSortir', function(ok, info)
        if not ok then
            return QBCore.Functions.Notify(info or 'Impossible de sortir ce vehicule.', 'error')
        end
        local m = Config.Metiers[metier]
        local v = m.vehicules[index]
        local s = (GlobalState.pt_fonction_points or {})[metier].sortie
        if vehiculeSorti and DoesEntityExist(vehiculeSorti) then
            return QBCore.Functions.Notify('Rangez d\'abord votre vehicule de fonction.', 'error')
        end
        if IsAnyVehicleNearPoint(s.x, s.y, s.z, 3.0) then
            return QBCore.Functions.Notify('L\'emplacement de sortie est occupe.', 'error')
        end
        QBCore.Functions.SpawnVehicle(v.modele, function(veh)
            SetVehicleNumberPlateText(veh, info)
            SetEntityHeading(veh, s.w or 0.0)
            if m.couleur then SetVehicleColours(veh, m.couleur[1], m.couleur[2]) end
            SetVehicleDirtLevel(veh, 0.0)
            if GetResourceState('cdn-fuel') == 'started' then
                pcall(function() exports['cdn-fuel']:SetFuel(veh, 100.0) end)
            else
                SetVehicleFuelLevel(veh, 100.0)
            end
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            SetVehicleEngineOn(veh, true, true, false)
            vehiculeSorti = veh
            QBCore.Functions.Notify(('%s sortie. Ramenez-la au meme endroit pour la ranger.'):format(v.label), 'success')
        end, vector3(s.x, s.y, s.z + 0.5), true)
    end, metier, index)
end

local function menu(metier)
    local m = Config.Metiers[metier]
    local _, job = monMetier()
    local grade = job and job.grade and job.grade.level or 0
    local items = { { header = m.label, isMenuHeader = true } }
    for i, v in ipairs(m.vehicules) do
        items[#items + 1] = {
            header = v.label,
            txt = grade >= v.grade and 'Sortir ce vehicule' or ('Grade %d minimum'):format(v.grade),
            disabled = grade < v.grade,
            params = { isAction = true, event = function() sortir(metier, i) end },
        }
    end
    exports['qb-menu']:openMenu(items)
end

local texteActuel = nil
local function texte(t)
    if t == texteActuel then return end
    texteActuel = t
    if t then exports['qb-core']:DrawText(t, 'left') else exports['qb-core']:HideText() end
end

CreateThread(function()
    while true do
        local attente = 1000
        local voulu = nil
        local metier, job = monMetier()
        local m = metier and Config.Metiers[metier]
        local pts = GlobalState.pt_fonction_points or {}
        if m and pts[metier] and (not Config.EnService or (job and job.onduty)) then
            local p = pts[metier].point
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local d = #(pos - vector3(p.x, p.y, p.z))
            if d < 20.0 then
                attente = 0
                DrawMarker(36, p.x, p.y, p.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8, 0, 150, 70, 180, true, true, 2, false, nil, nil, false)
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and d < 4.0 and veh == vehiculeSorti and GetPedInVehicleSeat(veh, -1) == ped then
                    voulu = '[E] Ranger le vehicule de fonction'
                    if IsControlJustReleased(0, 38) then
                        texte(nil)
                        TaskLeaveVehicle(ped, veh, 0)
                        Wait(1500)
                        QBCore.Functions.DeleteVehicle(veh)
                        vehiculeSorti = nil
                        voulu = nil
                    end
                elseif veh == 0 and d < 1.8 then
                    voulu = '[E] Vehicules de fonction'
                    if IsControlJustReleased(0, 38) then
                        texte(nil)
                        menu(metier)
                        voulu = nil
                    end
                end
            end
        end
        texte(voulu)
        Wait(attente)
    end
end)
