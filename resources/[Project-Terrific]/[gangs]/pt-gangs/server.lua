local QBCore = exports['qb-core']:GetCoreObject()

local Gangs = {}     -- [name] = { label, color, plate }
local Points = {}    -- [gang] = { [kind] = vec4 }
local Settings = {}  -- [gang] = { shell = model|nil, blip = bool }
local Vehicles = {}  -- [gang] = { { id, model, label, mingrade } }
local Spawned = {}   -- [plate] = gang  (vehicules de flotte sortis)

---------------------------------------------------------------- outils

local function isAdmin(src)
    for _, groupe in ipairs(Config.AdminGroups) do
        if QBCore.Functions.HasPermission(src, groupe) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function playerGang(src)
    local p = QBCore.Functions.GetPlayer(src)
    if not p then return nil end
    return p.PlayerData.gang.name, tonumber(p.PlayerData.gang.grade.level) or 0, p
end

local function vecToJson(v)
    return json.encode({ x = v.x, y = v.y, z = v.z, w = v.w or 0.0 })
end

local function jsonToVec(s)
    local t = json.decode(s)
    return t and vec4(t.x, t.y, t.z, t.w or 0.0) or nil
end

-- donnees envoyees aux clients
local function snapshot()
    local gangs = {}
    for name, g in pairs(Gangs) do
        gangs[name] = {
            label = g.label,
            color = g.color,
            plate = g.plate,
            points = Points[name] or {},
            shell = Settings[name] and Settings[name].shell or nil,
            blip = not Settings[name] or Settings[name].blip ~= false,
        }
    end
    return gangs
end

local function syncAll()
    TriggerClientEvent('pt-gangs:client:sync', -1, snapshot())
end

---------------------------------------------------------------- chargement

local function registerGang(name, label, gradesTable)
    if QBCore.Shared.Gangs[name] then
        -- gang deja connu de QBCore : on traduit seulement les grades si la structure est identique
        local actuel = QBCore.Shared.Gangs[name].grades or {}
        local identique = true
        for k in pairs(gradesTable) do if not actuel[k] then identique = false end end
        for k in pairs(actuel) do if not gradesTable[k] then identique = false end end
        if identique then
            exports['qb-core']:UpdateGang(name, { label = label, grades = gradesTable })
        end
    else
        exports['qb-core']:AddGang(name, { label = label, grades = gradesTable })
    end
end

local function loadAll()
    -- une requete par CREATE TABLE (oxmysql refuse les requetes multiples par defaut)
    local sql = LoadResourceFile(GetCurrentResourceName(), 'pt_gangs.sql') or ''
    for requete in sql:gmatch('[^;]+') do
        if requete:find('%S') then MySQL.query.await(requete) end
    end

    -- colonne "flotte" (version de la flotte par defaut) pour les bases creees avant son ajout
    local col = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pt_gangs_settings' AND COLUMN_NAME = 'flotte'")
    if col == 0 then
        MySQL.query.await('ALTER TABLE pt_gangs_settings ADD COLUMN `flotte` INT NOT NULL DEFAULT 1')
    end

    -- gangs de la config : flotte par defaut a la premiere installation, ou remplacee quand
    -- la version "flotte" de la config augmente (les vehicules ajoutes en jeu a ce gang sont alors remplaces)
    for name, g in pairs(Config.Gangs) do
        Gangs[name] = { label = g.label, color = g.color, plate = g.plate }
        registerGang(name, g.label, g.grades)
        local version = g.flotte or 1
        local stockee = MySQL.scalar.await('SELECT flotte FROM pt_gangs_settings WHERE gang = ?', { name })
        local deja = MySQL.scalar.await('SELECT COUNT(*) FROM pt_gangs_vehicles WHERE gang = ?', { name })
        local remplacer = stockee and stockee < version
        if (not stockee and deja == 0) or remplacer then
            if remplacer then
                MySQL.query.await('DELETE FROM pt_gangs_vehicles WHERE gang = ?', { name })
                print(('[pt-gangs] %s : nouvelle flotte par defaut (version %d)'):format(name, version))
            end
            for _, v in ipairs(g.vehicles or {}) do
                MySQL.insert.await('INSERT INTO pt_gangs_vehicles (gang, model, label, mingrade) VALUES (?, ?, ?, ?)', { name, v[1], v[2], v[3] or 0 })
            end
        end
        MySQL.insert.await('INSERT INTO pt_gangs_settings (gang, flotte) VALUES (?, ?) ON DUPLICATE KEY UPDATE flotte = GREATEST(flotte, VALUES(flotte))', { name, version })
    end

    -- gangs crees en jeu par les admins
    for _, row in ipairs(MySQL.query.await('SELECT * FROM pt_gangs') or {}) do
        Gangs[row.name] = { label = row.label, color = row.color, plate = row.plate }
        registerGang(row.name, row.label, json.decode(row.grades))
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM pt_gangs_points') or {}) do
        Points[row.gang] = Points[row.gang] or {}
        Points[row.gang][row.kind] = jsonToVec(row.coords)
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM pt_gangs_settings') or {}) do
        Settings[row.gang] = { shell = row.shell, blip = row.blip == 1 }
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM pt_gangs_vehicles ORDER BY mingrade, label') or {}) do
        Vehicles[row.gang] = Vehicles[row.gang] or {}
        table.insert(Vehicles[row.gang], { id = row.id, model = row.model, label = row.label, mingrade = row.mingrade })
    end
    syncAll()
    print(('[pt-gangs] %d gangs charges'):format((function() local n = 0 for _ in pairs(Gangs) do n += 1 end return n end)()))
end

CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    loadAll()
end)

-- (pas d'envoi sur QBCore:Server:OnPlayerLoaded : le client recupere les donnees lui-meme a son chargement,
-- et cet evenement peut arriver avec l'ancien identifiant temporaire du joueur)
lib.callback.register('pt-gangs:server:getData', function()
    return snapshot()
end)

---------------------------------------------------------------- membres : flotte de vehicules

lib.callback.register('pt-gangs:server:getVehicles', function(src)
    local gang, grade = playerGang(src)
    if not gang or not Gangs[gang] then return {} end
    local liste = {}
    for _, v in ipairs(Vehicles[gang] or {}) do
        liste[#liste + 1] = { id = v.id, model = v.model, label = v.label, mingrade = v.mingrade, allowed = grade >= v.mingrade }
    end
    return liste
end)

-- le client a fait apparaitre le vehicule : on verifie puis on donne les cles
RegisterNetEvent('pt-gangs:server:vehicleSpawned', function(vehicleId, netId, plate)
    local src = source
    local gang, grade = playerGang(src)
    if not gang or not Gangs[gang] then return end
    local veh
    for _, v in ipairs(Vehicles[gang] or {}) do if v.id == vehicleId then veh = v end end
    if not veh or grade < veh.mingrade then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or GetEntityModel(entity) ~= joaat(veh.model) then return end
    local spawn = Points[gang] and Points[gang].garage_spawn
    if spawn and #(GetEntityCoords(entity) - spawn.xyz) > 30.0 then return end
    Spawned[plate] = gang
    exports['qb-vehiclekeys']:GiveKeys(src, plate)
end)

-- un membre donne les cles d'un vehicule de la flotte a un autre membre du gang
RegisterNetEvent('pt-gangs:server:shareKeys', function(targetId, plate)
    local src = source
    local gang = playerGang(src)
    local cible = playerGang(tonumber(targetId) or -1)
    if not gang or Spawned[plate] ~= gang then return notify(src, 'Ce vehicule n\'appartient pas a la flotte de votre gang.', 'error') end
    if cible ~= gang then return notify(src, 'Ce joueur ne fait pas partie de votre gang.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 5.0 then return notify(src, 'Joueur trop loin.', 'error') end
    exports['qb-vehiclekeys']:GiveKeys(targetId, plate)
    notify(src, 'Cles donnees.', 'success')
end)

RegisterNetEvent('pt-gangs:server:vehicleStored', function(plate)
    Spawned[plate] = nil
end)

lib.callback.register('pt-gangs:server:isFleetVehicle', function(src, plate)
    local gang = playerGang(src)
    return gang ~= nil and Spawned[plate] == gang
end)

---------------------------------------------------------------- administration

local function adminOnly(src)
    if isAdmin(src) then return true end
    notify(src, 'Reserve aux admins.', 'error')
    return false
end

lib.addCommand('gangadmin', { help = 'Gestion des gangs et de leurs QG (admin)' }, function(src)
    if not adminOnly(src) then return end
    TriggerClientEvent('pt-gangs:client:adminMenu', src)
end)

lib.callback.register('pt-gangs:server:adminData', function(src)
    if not isAdmin(src) then return nil end
    local vehicles = {}
    for g, l in pairs(Vehicles) do vehicles[g] = l end
    return { gangs = snapshot(), vehicles = vehicles }
end)

RegisterNetEvent('pt-gangs:server:createGang', function(data)
    local src = source
    if not adminOnly(src) then return end
    local name = tostring(data.name or ''):lower():gsub('[^a-z0-9_]', '')
    if #name < 3 or #name > 30 then return notify(src, 'Identifiant invalide (3 a 30 lettres/chiffres).', 'error') end
    if Gangs[name] or QBCore.Shared.Gangs[name] then return notify(src, 'Ce gang existe deja.', 'error') end
    local label = tostring(data.label or name):sub(1, 60)
    local plate = tostring(data.plate or 'GANG'):upper():gsub('[^A-Z0-9]', ''):sub(1, 4)
    if #plate < 2 then plate = 'GANG' end
    local color = math.max(1, math.min(#Config.Colors, tonumber(data.color) or 1))
    local noms = data.orga and Config.ORGA or { 'Recrue', 'Soldat', 'Lieutenant', 'Chef' }
    local grades = {}
    for i, n in ipairs(noms) do grades[tostring(i - 1)] = { name = n, isboss = (i == #noms) or nil } end
    MySQL.insert.await('INSERT INTO pt_gangs (name, label, color, plate, grades) VALUES (?, ?, ?, ?, ?)', { name, label, color, plate, json.encode(grades) })
    MySQL.insert.await('INSERT IGNORE INTO pt_gangs_settings (gang) VALUES (?)', { name })
    Gangs[name] = { label = label, color = color, plate = plate }
    Settings[name] = { blip = true }
    registerGang(name, label, grades)
    syncAll()
    notify(src, ('Gang %s cree (%s).'):format(label, name), 'success')
end)

RegisterNetEvent('pt-gangs:server:setPoint', function(gang, kind)
    local src = source
    if not adminOnly(src) or not Gangs[gang] or not Config.PointLabels[kind] then return end
    local ped = GetPlayerPed(src)
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local v = vec4(c.x, c.y, c.z, h)
    MySQL.query.await('REPLACE INTO pt_gangs_points (gang, kind, coords) VALUES (?, ?, ?)', { gang, kind, vecToJson(v) })
    Points[gang] = Points[gang] or {}
    Points[gang][kind] = v
    -- un interieur MLO/IPL remplace le shell
    if kind == 'interieur' then
        MySQL.update.await('UPDATE pt_gangs_settings SET shell = NULL WHERE gang = ?', { gang })
        if Settings[gang] then Settings[gang].shell = nil end
    end
    syncAll()
    notify(src, ('%s place pour %s.'):format(Config.PointLabels[kind], Gangs[gang].label), 'success')
end)

RegisterNetEvent('pt-gangs:server:removePoint', function(gang, kind)
    local src = source
    if not adminOnly(src) or not Gangs[gang] then return end
    MySQL.query.await('DELETE FROM pt_gangs_points WHERE gang = ? AND kind = ?', { gang, kind })
    if Points[gang] then Points[gang][kind] = nil end
    syncAll()
    notify(src, 'Point supprime.', 'success')
end)

RegisterNetEvent('pt-gangs:server:setShell', function(gang, model)
    local src = source
    if not adminOnly(src) or not Gangs[gang] then return end
    local ok = model == nil
    for _, s in ipairs(Config.Shells) do if s.model == model then ok = true end end
    if not ok then return end
    MySQL.insert.await('INSERT INTO pt_gangs_settings (gang, shell) VALUES (?, ?) ON DUPLICATE KEY UPDATE shell = VALUES(shell)', { gang, model })
    Settings[gang] = Settings[gang] or { blip = true }
    Settings[gang].shell = model
    if model then
        -- un shell remplace l'interieur MLO/IPL
        MySQL.query.await('DELETE FROM pt_gangs_points WHERE gang = ? AND kind = ?', { gang, 'interieur' })
        if Points[gang] then Points[gang].interieur = nil end
    end
    syncAll()
    notify(src, model and 'Shell defini pour le QG.' or 'Shell retire.', 'success')
end)

RegisterNetEvent('pt-gangs:server:toggleBlip', function(gang)
    local src = source
    if not adminOnly(src) or not Gangs[gang] then return end
    Settings[gang] = Settings[gang] or { blip = true }
    Settings[gang].blip = not (Settings[gang].blip ~= false)
    MySQL.insert.await('INSERT INTO pt_gangs_settings (gang, blip) VALUES (?, ?) ON DUPLICATE KEY UPDATE blip = VALUES(blip)', { gang, Settings[gang].blip and 1 or 0 })
    syncAll()
end)

RegisterNetEvent('pt-gangs:server:addVehicle', function(gang, model, label, mingrade)
    local src = source
    if not adminOnly(src) or not Gangs[gang] then return end
    model = tostring(model or ''):lower():gsub('[^a-z0-9_]', '')
    if model == '' then return end
    if not QBCore.Shared.Vehicles[model] then
        notify(src, ('Attention : %s n\'est pas dans qb-core/shared/vehicles.lua (il apparaitra quand meme s\'il existe).'):format(model), 'error')
    end
    local id = MySQL.insert.await('INSERT INTO pt_gangs_vehicles (gang, model, label, mingrade) VALUES (?, ?, ?, ?)',
        { gang, model, tostring(label or model):sub(1, 60), math.max(0, tonumber(mingrade) or 0) })
    Vehicles[gang] = Vehicles[gang] or {}
    table.insert(Vehicles[gang], { id = id, model = model, label = label or model, mingrade = tonumber(mingrade) or 0 })
    notify(src, 'Vehicule ajoute a la flotte.', 'success')
end)

RegisterNetEvent('pt-gangs:server:removeVehicle', function(gang, id)
    local src = source
    if not adminOnly(src) or not Vehicles[gang] then return end
    MySQL.query.await('DELETE FROM pt_gangs_vehicles WHERE id = ? AND gang = ?', { id, gang })
    for i, v in ipairs(Vehicles[gang]) do
        if v.id == id then table.remove(Vehicles[gang], i) break end
    end
    notify(src, 'Vehicule retire de la flotte.', 'success')
end)

RegisterNetEvent('pt-gangs:server:setMember', function(targetId, gang, grade)
    local src = source
    if not adminOnly(src) then return end
    local target = QBCore.Functions.GetPlayer(tonumber(targetId) or -1)
    if not target then return notify(src, 'Joueur introuvable (ID serveur).', 'error') end
    if gang ~= 'none' and not QBCore.Shared.Gangs[gang] then return end
    target.Functions.SetGang(gang, tonumber(grade) or 0)
    notify(src, 'Gang du joueur mis a jour.', 'success')
    notify(target.PlayerData.source, ('Vous faites maintenant partie de : %s'):format(QBCore.Shared.Gangs[gang].label), 'success')
end)
