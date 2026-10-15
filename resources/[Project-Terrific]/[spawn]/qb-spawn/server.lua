local QBCore = exports['qb-core']:GetCoreObject()

-- Project Terrific : les "maisons" proposees au spawn sont les biens qbx_properties (possedes ou avec cle)
QBCore.Functions.CreateCallback('qb-spawn:server:getOwnedHouses', function(_, cb, cid)
    if not cid or GetResourceState('qbx_properties') ~= 'started' then return cb({}) end
    local rows = MySQL.query.await('SELECT id, property_name, coords, owner FROM properties WHERE owner = ? OR keyholders LIKE ? ORDER BY owner = ? DESC, property_name', { cid, '%' .. cid .. '%', cid }) or {}
    local liste = {}
    for _, r in ipairs(rows) do
        local c = json.decode(r.coords)
        liste[#liste + 1] = { house = 'qbx_' .. r.id, label = r.property_name .. (r.owner == cid and '' or ' (cle)'), coords = { x = c.x, y = c.y, z = c.z } }
    end
    cb(liste)
end)
