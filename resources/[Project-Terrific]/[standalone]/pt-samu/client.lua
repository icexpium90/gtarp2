local QBCore = exports['qb-core']:GetCoreObject()

local mission = nil         -- { veh, conducteur, medecin, blip, etape, debut }
local etat = { aTerreDepuis = nil, appele = false, alerteEnvoyee = false, attenteJoueurs = nil }

local function notifier(msg, type_)
    lib.notify({ title = 'Centre 15 (SAMU)', description = msg, type = type_ or 'inform', duration = 7000 })
end

local function joueurATerre()
    local m = QBCore.Functions.GetPlayerData().metadata
    return m and (m.isdead or m.inlaststand)
end

local function nettoyer(immediat)
    if not mission then return end
    local m = mission
    mission = nil
    if m.blip and DoesBlipExist(m.blip) then RemoveBlip(m.blip) end
    CreateThread(function()
        if not immediat and DoesEntityExist(m.veh) and DoesEntityExist(m.conducteur) then
            -- l'equipage remonte et repart, puis on supprime hors de vue
            if DoesEntityExist(m.medecin) then TaskEnterVehicle(m.medecin, m.veh, 10000, 0, 1.0, 1, 0) end
            Wait(6000)
            SetVehicleSiren(m.veh, false)
            TaskVehicleDriveWander(m.conducteur, m.veh, 15.0, 786603)
            local fin = GetGameTimer() + 40000
            while GetGameTimer() < fin and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(m.veh)) < 80.0 do Wait(1000) end
        end
        for _, e in ipairs({ m.medecin, m.conducteur, m.veh }) do
            if e and DoesEntityExist(e) then
                SetEntityAsMissionEntity(e, true, true)
                DeleteEntity(e)
            end
        end
    end)
end

local function charger(modele)
    local h = joaat(modele)
    if not lib.requestModel(h, 10000) then return nil end
    return h
end

local function pointDeDepart(cible)
    local mini, maxi = Config.DistanceApparition.min, Config.DistanceApparition.max
    for _ = 1, 12 do
        local angle = math.random() * 2.0 * math.pi
        local r = math.random(mini, maxi)
        local x, y = cible.x + math.cos(angle) * r, cible.y + math.sin(angle) * r
        local ok, pos, cap = GetClosestVehicleNodeWithHeading(x, y, cible.z, 1, 3.0, 0)
        if ok and #(pos - cible) > mini * 0.6 then return pos, cap end
    end
    local ok, pos, cap = GetClosestVehicleNodeWithHeading(cible.x, cible.y, cible.z, 1, 3.0, 0)
    if ok then return pos, cap end
    return cible + vector3(10.0, 10.0, 0.0), 0.0
end

local function envoyerVSAV()
    if mission then return end
    local hv, hc, hm = charger(Config.Vehicule), charger(Config.Conducteur), charger(Config.Medecin)
    if not (hv and hc and hm) then
        TriggerServerEvent('pt-samu:server:annule')
        notifier('Aucun VSAV disponible pour le moment.', 'error')
        return
    end
    local cible = GetEntityCoords(PlayerPedId())
    local pos, cap = pointDeDepart(cible)

    local veh = CreateVehicle(hv, pos.x, pos.y, pos.z, cap, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, Config.Plaque)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleSiren(veh, true)
    SetVehicleHasMutedSirens(veh, false)
    SetVehicleDoorsLocked(veh, 2)

    local conducteur = CreatePedInsideVehicle(veh, 26, hc, -1, true, false)
    local medecin = CreatePedInsideVehicle(veh, 26, hm, 0, true, false)
    for _, p in ipairs({ conducteur, medecin }) do
        SetEntityAsMissionEntity(p, true, true)
        SetBlockingOfNonTemporaryEvents(p, true)
        SetPedKeepTask(p, true)
        SetEntityInvincible(p, true)
        SetPedCanBeDraggedOut(p, false)
    end
    SetDriverAbility(conducteur, 1.0)
    SetDriverAggressiveness(conducteur, 0.6)
    SetModelAsNoLongerNeeded(hv); SetModelAsNoLongerNeeded(hc); SetModelAsNoLongerNeeded(hm)

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 61)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('VSAV du SAMU')
    EndTextCommandSetBlipName(blip)

    TaskVehicleDriveToCoordLongrange(conducteur, veh, cible.x, cible.y, cible.z, 28.0, 787004, 12.0)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    notifier('Un VSAV et un medecin du SMUR sont en route. Restez calme.', 'success')

    mission = { veh = veh, conducteur = conducteur, medecin = medecin, blip = blip, etape = 'route', debut = GetGameTimer() }
end

local function soigner()
    local m = mission
    m.etape = 'soins'
    local ped = PlayerPedId()
    local dict = 'mini@cpr@char_a@cpr_str'
    lib.requestAnimDict(dict, 5000)
    TaskTurnPedToFaceEntity(m.medecin, ped, 1000)
    Wait(1000)
    TaskPlayAnim(m.medecin, dict, 'cpr_pumpchest', 1.0, 1.0, -1, 9, 1.0, false, false, false)
    lib.progressBar({
        duration = Config.DureeSoins,
        label = 'Le medecin du SMUR vous prend en charge...',
        canCancel = false,
        disable = { move = true, car = true, combat = true },
    })
    ClearPedTasks(m.medecin)
    m.finSoins = GetGameTimer()
    TriggerServerEvent('pt-samu:server:soigne')
end

-- Suivi de l'intervention
CreateThread(function()
    while true do
        local attente = 1000
        local m = mission
        if m then
            attente = 250
            local ped = PlayerPedId()
            local pj = GetEntityCoords(ped)
            if not DoesEntityExist(m.veh) or not DoesEntityExist(m.medecin) then
                nettoyer(true)
                TriggerServerEvent('pt-samu:server:annule')
                etat.appele = false
            elseif m.etape == 'soins' and m.finSoins and GetGameTimer() - m.finSoins > 10000 then
                -- pas de reponse du serveur : on libere l'equipage, un nouvel appel reste possible
                m.etape = 'fin'
                nettoyer(false)
                etat.appele = false
            elseif not joueurATerre() and m.etape ~= 'fin' and m.etape ~= 'soins' then
                -- releve par quelqu'un d'autre entre temps
                m.etape = 'fin'
                TriggerServerEvent('pt-samu:server:annule')
                nettoyer(false)
            elseif m.etape == 'route' then
                local dv = #(GetEntityCoords(m.veh) - pj)
                local trop = (GetGameTimer() - m.debut) > Config.TempsMaxTrajet * 1000
                if trop and dv > 40.0 then
                    -- bloque ou route impossible : on rapproche le VSAV sur la route la plus proche
                    local ok, pos, cap = GetClosestVehicleNodeWithHeading(pj.x, pj.y, pj.z, 1, 3.0, 0)
                    if ok then
                        SetEntityCoords(m.veh, pos.x, pos.y, pos.z, false, false, false, false)
                        SetEntityHeading(m.veh, cap)
                        dv = #(pos - pj)
                    end
                    m.debut = GetGameTimer()
                end
                if dv < 25.0 or (trop and dv <= 40.0) then
                    m.etape = 'apied'
                    m.debutPied = GetGameTimer()
                    TaskVehicleTempAction(m.conducteur, m.veh, 27, 3000)
                    TaskLeaveVehicle(m.medecin, m.veh, 0)
                    Wait(1500)
                    TaskGoToEntity(m.medecin, ped, -1, 1.2, 2.0, 1073741824, 0)
                end
            elseif m.etape == 'apied' then
                local dm = #(GetEntityCoords(m.medecin) - pj)
                if dm < 1.8 then
                    soigner()
                elseif GetGameTimer() - m.debutPied > 30000 then
                    -- acces impossible a pied (interieur, toit...) : le medecin arrive directement
                    SetEntityCoords(m.medecin, pj.x + 0.8, pj.y + 0.8, pj.z, false, false, false, false)
                    m.debutPied = GetGameTimer()
                elseif GetGameTimer() % 3000 < 300 then
                    TaskGoToEntity(m.medecin, ped, -1, 1.2, 2.0, 1073741824, 0)
                end
            end
        end
        Wait(attente)
    end
end)

-- Appel au 15 : automatique apres Config.DelaiAppelAuto secondes a terre, ou manuel (touche G de qb-ambulancejob)
local function appeler(forcerIA)
    if mission then return end
    local r = lib.callback.await('pt-samu:demander', false, forcerIA)
    if r == 'ia' then
        etat.appele = true
        envoyerVSAV()
    elseif r == 'secouristes' then
        etat.appele = true
        etat.attenteJoueurs = etat.attenteJoueurs or GetGameTimer()
        if not etat.alerteEnvoyee then
            etat.alerteEnvoyee = true
            TriggerServerEvent('hospital:server:ambulanceAlert', 'Appel au 15 : victime au sol')
            notifier('Les equipes du SAMU de garde ont ete prevenues.')
        end
    elseif r == 'argent' then
        etat.appele = true
        notifier('Vous n\'avez pas de quoi payer l\'intervention.', 'error')
    end
end
exports('Appeler', function() CreateThread(function() appeler(false) end) end)

CreateThread(function()
    while true do
        Wait(2000)
        if LocalPlayer.state.isLoggedIn ~= false and joueurATerre() then
            etat.aTerreDepuis = etat.aTerreDepuis or GetGameTimer()
            if not etat.appele and GetGameTimer() - etat.aTerreDepuis >= Config.DelaiAppelAuto * 1000 then
                appeler(false)
            elseif etat.attenteJoueurs and not mission and Config.AttenteSecouristes > 0
                and GetGameTimer() - etat.attenteJoueurs >= Config.AttenteSecouristes * 1000 then
                etat.attenteJoueurs = GetGameTimer() -- nouvel essai plus tard si refuse
                notifier('Aucune equipe disponible n\'a pu se liberer : un VSAV de reserve est engage.')
                appeler(true)
            end
        elseif etat.aTerreDepuis then
            etat = { aTerreDepuis = nil, appele = false, alerteEnvoyee = false, attenteJoueurs = nil }
            TriggerServerEvent('pt-samu:server:releve')
        end
    end
end)

RegisterNetEvent('pt-samu:client:fin', function(paye)
    if paye > 0 then
        notifier(('Vous avez ete pris en charge par le SAMU. Intervention facturee $%d.'):format(paye), 'success')
    else
        notifier('Vous avez ete pris en charge par le SAMU (pris en charge par la Securite sociale).', 'success')
    end
    if mission then mission.etape = 'fin' end
    nettoyer(false)
end)

AddEventHandler('onResourceStop', function(nom)
    if nom == GetCurrentResourceName() then nettoyer(true) end
end)
