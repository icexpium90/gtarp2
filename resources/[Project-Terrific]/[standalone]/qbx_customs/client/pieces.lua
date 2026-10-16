-- LUSO RP : pieces speciales (menu Performance des LS Customs)
--   anglekit : angle de braquage augmente (drift)          -> applique par le conducteur
--   kitlarge : roues deportees vers l'exterieur              -> applique par tous les joueurs proches (visible de tous)
--   antilag  : petarades / flammes au lever de pied + turbo  -> declenche par le conducteur, flammes en reseau
-- Niveaux gardes dans l'etat du vehicule (state bags) et en base (player_vehicles), demandes au serveur a la prise du volant.
local cfg = require('config.shared').piecesSpeciales
local CLASSES_EXCLUES = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

function PieceCompatible(veh)
    return veh ~= 0 and DoesEntityExist(veh) and not CLASSES_EXCLUES[GetVehicleClass(veh)]
end
AngleKitCompatible = PieceCompatible

local apercu = {}  -- [vehicule][piece] = niveau affiche pendant le menu (avant achat)

function NiveauPiece(veh, piece)
    if apercu[veh] and apercu[veh][piece] ~= nil then return apercu[veh][piece] end
    return Entity(veh).state[cfg[piece].etat] or 0
end

---------------------------------------------------------------- kit grand angle
local basesAngle = {}
local function appliquerAngle(veh, niveau)
    if not PieceCompatible(veh) then return end
    local base = basesAngle[veh]
    if not base then
        base = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock')
        basesAngle[veh] = base
    end
    local ajout = cfg.anglekit.ajouts[(tonumber(niveau) or 0) + 1] or 0
    local angle = ajout > 0 and math.min(base + ajout, cfg.anglekit.max) or base
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSteeringLock', angle + 0.0)
end

---------------------------------------------------------------- kit large (tous les clients, chaque image)
local basesRoues = {}   -- [vehicule] = { offsets d'origine par roue }
local larges = {}       -- [vehicule] = ecart en metres, vehicules proches equipes
local function basesDe(veh)
    local b = basesRoues[veh]
    if not b then
        b = {}
        for i = 0, GetVehicleNumberOfWheels(veh) - 1 do b[i] = GetVehicleWheelXOffset(veh, i) end
        basesRoues[veh] = b
    end
    return b
end

local function remettreRoues(veh)
    local b = basesRoues[veh]
    if b and DoesEntityExist(veh) then
        for i, x in pairs(b) do SetVehicleWheelXOffset(veh, i, x) end
    end
end

CreateThread(function()   -- liste des vehicules proches avec un kit large (toutes les 500 ms)
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local liste = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - pos) < 120.0 and PieceCompatible(veh) then
                local n = NiveauPiece(veh, 'kitlarge')
                local ecart = cfg.kitlarge.ecarts[n + 1] or 0
                if ecart > 0 then liste[veh] = ecart end
            end
        end
        for veh in pairs(larges) do
            if not liste[veh] then remettreRoues(veh) end
        end
        larges = liste
        for veh in pairs(basesRoues) do
            if not DoesEntityExist(veh) then basesRoues[veh] = nil basesAngle[veh] = nil apercu[veh] = nil end
        end
        Wait(500)
    end
end)

CreateThread(function()   -- le jeu recalcule la position des roues : on la reimpose a chaque image
    while true do
        if next(larges) then
            for veh, ecart in pairs(larges) do
                if DoesEntityExist(veh) then
                    for i, x in pairs(basesDe(veh)) do
                        SetVehicleWheelXOffset(veh, i, x + (x < 0 and -ecart or ecart))
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------- rolling anti-lag (conducteur)
local ECHAPPEMENTS = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6', 'exhaust_7', 'exhaust_8' }

local function petarade(veh)
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local fin = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < fin do Wait(0) end
    end
    for _, os_ in ipairs(ECHAPPEMENTS) do
        local idx = GetEntityBoneIndexByName(veh, os_)
        if idx ~= -1 then
            UseParticleFxAssetNextCall('core')
            StartNetworkedParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, idx, 1.2, false, false, false)
        end
    end
end

local boucleActive = {}
local function boucleAntiLag(veh)
    if boucleActive[veh] then return end
    boucleActive[veh] = true
    pcall(function() Citizen.InvokeNative(0x2BE4BC731D039D5A, veh, true) end) -- ENABLE_VEHICLE_EXHAUST_POPS
    local gazAvant = false
    while cache.vehicle == veh and GetPedInVehicleSeat(veh, -1) == cache.ped and NiveauPiece(veh, 'antilag') > 0 do
        local gaz = IsControlPressed(0, 71)
        local regime = GetVehicleCurrentRpm(veh)
        -- lever de pied a haut regime : 2 a 4 petarades
        if gazAvant and not gaz and regime >= cfg.antilag.regimeMin and GetEntitySpeed(veh) > 3.0 then
            for _ = 1, math.random(2, 4) do
                petarade(veh)
                Wait(math.random(70, 160))
            end
        end
        -- turbo maintenu en pression pendant les changements de rapport / lever de pied
        if not gaz and IsToggleModOn(veh, 18) and regime > 0.3 then
            SetVehicleTurboPressure(veh, math.max(GetVehicleTurboPressure(veh), 0.8))
        end
        gazAvant = gaz
        Wait(0)
    end
    boucleActive[veh] = nil
end

---------------------------------------------------------------- application
function AppliquerPiece(veh, piece, niveau, apercuSeulement)
    if not PieceCompatible(veh) then return end
    if apercuSeulement then
        apercu[veh] = apercu[veh] or {}
        apercu[veh][piece] = niveau
    elseif apercu[veh] then
        apercu[veh][piece] = nil
    end
    if piece == 'anglekit' then appliquerAngle(veh, niveau) end
end

function FinApercu(veh)
    apercu[veh] = nil
    if DoesEntityExist(veh) then appliquerAngle(veh, NiveauPiece(veh, 'anglekit')) end
end

-- prise du volant : niveaux demandes au serveur la premiere fois, puis appliques
local verifies = {}
CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped and PieceCompatible(veh) then
            if not verifies[veh] then
                verifies[veh] = true
                if Entity(veh).state[cfg.anglekit.etat] == nil then
                    lib.callback.await('qbx_customs:server:piecesDuVehicule', false, NetworkGetNetworkIdFromEntity(veh))
                    Wait(200)
                end
                appliquerAngle(veh, NiveauPiece(veh, 'anglekit'))
                if NiveauPiece(veh, 'antilag') > 0 then CreateThread(function() boucleAntiLag(veh) end) end
            end
        elseif not veh then
            verifies = {}
        end
        Wait(1000)
    end
end)

-- changement apres un achat (ou par un autre joueur) pendant que je conduis
for _, piece in ipairs(cfg.ordre) do
    AddStateBagChangeHandler(cfg[piece].etat, nil, function(bagName, _, valeur)
        local veh = GetEntityFromStateBagName(bagName)
        if veh == 0 or veh ~= cache.vehicle or GetPedInVehicleSeat(veh, -1) ~= cache.ped then return end
        if piece == 'anglekit' then
            appliquerAngle(veh, valeur)
        elseif piece == 'antilag' and (valeur or 0) > 0 then
            SetTimeout(100, function() CreateThread(function() boucleAntiLag(veh) end) end)
        end
    end)
end
