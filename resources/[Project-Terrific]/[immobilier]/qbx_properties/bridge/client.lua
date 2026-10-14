-- Pont client : QBX.PlayerData, notifications, texte 3D, raycast, recalage au sol
QBX = { PlayerData = QBCore.Functions.GetPlayerData() or {} }

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBX.PlayerData = QBCore.Functions.GetPlayerData() or {}
end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    QBX.PlayerData = data
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    QBX.PlayerData = {}
end)

function Bridge.Notify(message, typ)
    QBCore.Functions.Notify(message, typ or 'primary')
end

qbx = qbx or {}
function qbx.drawText3d(params)
    local coords = params.coords
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(params.text)
    EndTextCommandDisplayText(x, y)
    local largeur = string.len(params.text) / 370
    DrawRect(x, y + 0.0125, 0.015 + largeur, 0.03, 0, 0, 0, 90)
end

-- ox_lib 3.6 : raycast.cam a la meme signature que raycast.fromCamera
local raycast = lib.raycast
if raycast and not raycast.fromCamera then raycast.fromCamera = raycast.cam end

-- Pose le joueur sur le sol reel apres une teleportation dans un interieur a coordonnees fixes
function Bridge.SnapToGround(coords)
    local ped = cache.ped
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local debut = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - debut < 5000 do Wait(0) end
    for _, hauteur in ipairs({ 1.5, 3.0, 6.0 }) do
        local trouve, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + hauteur, false)
        if trouve and math.abs(z - coords.z) < hauteur + 2.0 then
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, z + 0.05, false, false, false)
            return
        end
    end
end
