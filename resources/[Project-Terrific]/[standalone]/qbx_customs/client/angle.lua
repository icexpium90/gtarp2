-- LUSO RP : kit grand angle (angle de braquage augmente, style drift)
-- Le niveau est garde dans l'etat du vehicule (state bag 'ptAngle') et en base (player_vehicles.anglekit).
-- La maniabilite est locale a chaque client : le conducteur applique l'angle quand il prend le volant.
local cfg = require('config.shared').angleKit
local bases = {}   -- [vehicule] = angle d'origine (lu avant toute modification)

local CLASSES_EXCLUES = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

function AngleKitCompatible(veh)
    return veh ~= 0 and DoesEntityExist(veh) and not CLASSES_EXCLUES[GetVehicleClass(veh)]
end

function AppliquerAngle(veh, niveau)
    if not AngleKitCompatible(veh) then return end
    local base = bases[veh]
    if not base then
        base = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock')
        bases[veh] = base
    end
    local ajout = cfg.ajouts[(tonumber(niveau) or 0) + 1] or 0
    local angle = ajout > 0 and math.min(base + ajout, cfg.max) or base
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock', angle + 0.0)
end

function NiveauAngle(veh)
    return Entity(veh).state.ptAngle or 0
end

-- prise du volant : niveau demande au serveur la premiere fois (vehicule possede), puis applique
local verifies = {}
CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped and AngleKitCompatible(veh) then
            if not verifies[veh] then
                verifies[veh] = true
                local niveau = Entity(veh).state.ptAngle
                if niveau == nil then
                    niveau = lib.callback.await('qbx_customs:server:angleDuVehicule', false, NetworkGetNetworkIdFromEntity(veh)) or 0
                end
                AppliquerAngle(veh, niveau)
            end
        end
        -- menage des vehicules disparus
        for v in pairs(verifies) do
            if not DoesEntityExist(v) then verifies[v] = nil bases[v] = nil end
        end
        Wait(1000)
    end
end)

-- changement de niveau (atelier, autre joueur) pendant que je conduis
AddStateBagChangeHandler('ptAngle', nil, function(bagName, _, valeur)
    local veh = GetEntityFromStateBagName(bagName)
    if veh ~= 0 and veh == cache.vehicle and GetPedInVehicleSeat(veh, -1) == cache.ped then
        AppliquerAngle(veh, valeur)
    end
end)
