local QBCore = exports['qb-core']:GetCoreObject()
local actif = false
local vehicule = 0

local function notifier(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function modeleAutorise(veh)
    local modele = GetEntityModel(veh)
    for _, m in ipairs(Config.models) do
        if modele == joaat(m) then return true end
    end
    return false
end

local function classeAutorisee(veh)
    local classe = GetVehicleClass(veh)
    for _, c in ipairs(Config.classes) do
        if classe == c then return true end
    end
    return false
end

local function couper()
    if vehicule ~= 0 and DoesEntityExist(vehicule) then
        SetDriftTyresEnabled(vehicule, false)
        SetReduceDriftVehicleSuspension(vehicule, false)
    end
    actif = false
    vehicule = 0
end

-- angle (degres) entre l'axe de la voiture et sa trajectoire : > quelques degres = glissade
local function angleDeGlisse(veh)
    local v = GetEntityVelocity(veh)
    local vitesse = math.sqrt(v.x * v.x + v.y * v.y)
    if vitesse < 1.0 then return 0.0 end
    local avant = GetEntityForwardVector(veh)
    local cos = (avant.x * v.x + avant.y * v.y) / vitesse
    cos = math.max(-1.0, math.min(1.0, cos))
    return math.deg(math.acos(cos))
end

local function boucle()
    local ped = PlayerPedId()
    if Config.smoke and not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local t = GetGameTimer()
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() - t < 3000 do Wait(0) end
    end
    CreateThread(function()
        while actif do
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= vehicule or GetPedInVehicleSeat(veh, -1) ~= ped then
                couper()
                notifier('Mode drift desactive (vous avez quitte le vehicule).')
                break
            end
            if Config.smoke and GetEntitySpeed(veh) * 3.6 > Config.smokeMinSpeed
                and angleDeGlisse(veh) > Config.smokeMinAngle then
                local effets = {}
                for _, roue in ipairs({ 'wheel_lr', 'wheel_rr' }) do
                    UseParticleFxAssetNextCall('core')
                    effets[#effets + 1] = StartParticleFxLoopedOnEntityBone('exp_grd_bzgas_smoke', veh,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, GetEntityBoneIndexByName(veh, roue), 0.6, false, false, false)
                end
                Wait(400)
                for _, e in ipairs(effets) do StopParticleFxLooped(e, false) end
            else
                Wait(200)
            end
        end
    end)
    if Config.twostep then
        CreateThread(function()
            while actif do
                if GetVehicleCurrentRpm(vehicule) > 0.9 and GetPedInVehicleSeat(vehicule, -1) == ped then
                    AddExplosion(GetEntityCoords(vehicule), 61, 0.0, true, true, 0.0, true)
                    Wait(math.random(100, 400))
                else
                    Wait(100)
                end
            end
        end)
    end
end

RegisterNetEvent('driftmode:basculer', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if actif then
        couper()
        return notifier('Mode drift desactive.')
    end
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        return notifier('Vous devez conduire un vehicule.', 'error')
    end
    if Config.vehicleWhitelist and not modeleAutorise(veh) then
        return notifier("Ce vehicule n'est pas autorise pour le mode drift.", 'error')
    end
    if Config.vehicleClassWhitelist and not classeAutorisee(veh) then
        return notifier("Cette categorie de vehicule n'est pas autorisee pour le mode drift.", 'error')
    end
    vehicule = veh
    actif = true
    SetDriftTyresEnabled(veh, true)
    SetReduceDriftVehicleSuspension(veh, true)
    notifier('Mode drift active.', 'success')
    boucle()
end)

RegisterCommand('driftmode', function()
    TriggerServerEvent('driftmode:demande')
end, false)
RegisterKeyMapping('driftmode', 'Activer / desactiver le mode drift', 'keyboard', Config.defaultKey)
TriggerEvent('chat:addSuggestion', '/driftmode', 'Activer / desactiver le mode drift')

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and actif then couper() end
end)
