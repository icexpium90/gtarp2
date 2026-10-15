local QBCore = exports['qb-core']:GetCoreObject()

-- positions (config, ou choisies par un admin et gardees en KVP)
local points = {}
for metier, m in pairs(Config.Metiers) do
    local p = { point = m.point, sortie = m.sortie }
    for _, cle in ipairs({ 'point', 'sortie' }) do
        local kvp = GetResourceKvpString(('%s_%s'):format(metier, cle))
        local d = kvp and json.decode(kvp)
        if d then p[cle] = vector4(d.x, d.y, d.z, d.w) end
    end
    points[metier] = {
        point = { x = p.point.x, y = p.point.y, z = p.point.z, w = p.point.w },
        sortie = { x = p.sortie.x, y = p.sortie.y, z = p.sortie.z, w = p.sortie.w },
    }
end
GlobalState.pt_fonction_points = points

local function estAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') or IsPlayerAceAllowed(src, 'command')
end

RegisterCommand('pointfonction', function(src, args)
    if src == 0 or not estAdmin(src) then return end
    local metier, cle = args[1], args[2]
    if not Config.Metiers[metier] or (cle ~= 'point' and cle ~= 'sortie') then
        return TriggerClientEvent('QBCore:Notify', src, 'Usage : /pointfonction [metier] point|sortie', 'error')
    end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local v = { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
    SetResourceKvp(('%s_%s'):format(metier, cle), json.encode(v))
    points[metier][cle] = v
    GlobalState.pt_fonction_points = points
    TriggerClientEvent('QBCore:Notify', src, ('%s : %s place ici.'):format(metier, cle), 'success')
end, false)

-- verification du droit de sortir un vehicule (metier, service, grade)
QBCore.Functions.CreateCallback('pt-fonction:server:peutSortir', function(src, cb, metier, index)
    local P = QBCore.Functions.GetPlayer(src)
    local m = Config.Metiers[metier]
    local v = m and m.vehicules[tonumber(index) or 0]
    if not P or not v or P.PlayerData.job.name ~= metier then return cb(false) end
    if Config.EnService and not P.PlayerData.job.onduty then return cb(false, 'Prenez votre service.') end
    if (P.PlayerData.job.grade.level or 0) < v.grade then return cb(false, 'Grade insuffisant pour ce vehicule.') end
    local pt = points[metier].point
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(pt.x, pt.y, pt.z)) > 8.0 then return cb(false) end
    cb(true, ('%s%s'):format(m.plaque or 'PRO', math.random(1000, 9999)))
end)
