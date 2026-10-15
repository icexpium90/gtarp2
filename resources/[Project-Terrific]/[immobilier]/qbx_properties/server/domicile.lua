-- Domicile : le bien avec garage le plus cher du joueur.
--  * tousLesVehicules : le garage du domicile donne acces a tous les vehicules ranges du joueur (voir qb-garages et garage.lua)
--  * retourAuto       : les vehicules sortis reviennent au domicile (deconnexion / crash du jeu, redemarrage du serveur,
--                       vehicule disparu ou detruit et abandonne). Sans domicile : retour au dernier garage utilise.
local config = require 'config.server'
local reglages = config.domicile or {}

local AIR_EAU = { helicopters = true, planes = true, boats = true }

---------------------------------------------------------------- domicile d'un joueur (cache 60 s)
local cache = {}
local function garageDomicile(cid)
    if not cid then return nil end
    local c = cache[cid]
    if c and os.time() - c.t < 60 then return c.id end
    local nom = MySQL.scalar.await([[
        SELECT property_name FROM properties
        WHERE owner = ? AND (garage IS NOT NULL OR (places IS NOT NULL AND places <> '' AND places <> '[]'))
        ORDER BY price DESC LIMIT 1]], { cid })
    local id = nom and PropertyGarageId(nom) or nil
    cache[cid] = { id = id, t = os.time() }
    return id
end
GarageDomicile = garageDomicile
function OublierDomicile(cid) if cid then cache[cid] = nil else cache = {} end end

exports('GarageDomicile', garageDomicile)
-- qb-garages : ce garage de propriete est-il le domicile de ce joueur (et l'option est-elle active) ?
exports('TousVehiculesAuDomicile', function(cid, garageId)
    return reglages.tousLesVehicules == true and garageId ~= nil and garageDomicile(cid) == garageId
end)

-- vehicule de route (pas bateau / helico / avion) : seuls ceux-la vont dans un garage de maison
local function vehiculeDeRoute(modele)
    local v = QBCore.Shared.Vehicles[modele]
    local cat = v and (v.category or '') or ''
    return not AIR_EAU[cat]
end
VehiculeDeRoute = vehiculeDeRoute

-- garage physique (MLO) du domicile : vehicules du proprietaire ranges dans un garage public, a faire venir
function VehiculesAFaireVenir(bien, garageNom)
    if reglages.tousLesVehicules ~= true or not bien.owner then return {} end
    if garageDomicile(bien.owner) ~= garageNom then return {} end
    local rows = MySQL.query.await([[
        SELECT plate, vehicle, hash, mods, fuel, engine, body FROM player_vehicles
        WHERE citizenid = ? AND state = 1 AND garage <> ? AND (garage IS NULL OR garage NOT LIKE 'property\_%')]],
        { bien.owner, garageNom }) or {}
    local liste = {}
    for _, v in ipairs(rows) do
        if vehiculeDeRoute(v.vehicle) then v.aDeplacer = true liste[#liste + 1] = v end
    end
    return liste
end

---------------------------------------------------------------- retour automatique
local function nettoyer(plaque) return ((plaque or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper() end

local function vehiculesDuMonde()
    local t = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then t[nettoyer(GetVehicleNumberPlateText(veh))] = veh end
    end
    return t
end

local function conducteurJoueur(veh, sauf)
    for siege = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, siege)
        if ped ~= 0 and IsPedAPlayer(ped) and ped ~= sauf then return true end
    end
    return false
end

local function rapatrier(ligne, veh)
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    local dest = garageDomicile(ligne.citizenid) or ligne.garage
    if not dest or dest == '' then dest = 'motelgarage' end
    MySQL.update.await('UPDATE player_vehicles SET state = 1, garage = ?, depotprice = 0 WHERE plate = ? AND state = 0', { dest, ligne.plate })
    return dest
end

-- citizenid par source (le joueur QBCore peut deja etre retire au moment de playerDropped)
local cidParSource = {}
local function retenir(src)
    local p = QBCore.Functions.GetPlayer(src)
    if p then cidParSource[src] = p.PlayerData.citizenid end
end
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() retenir(source) end)
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then cidParSource[Player.PlayerData.source] = Player.PlayerData.citizenid end
end)

-- deconnexion ou crash du jeu : les vehicules sortis du joueur rentrent a la maison
AddEventHandler('playerDropped', function()
    local src = source
    local p = QBCore.Functions.GetPlayer(src)
    local cid = (p and p.PlayerData.citizenid) or cidParSource[src]
    cidParSource[src] = nil
    if not cid or reglages.retourAuto ~= true then return end
    local ped = GetPlayerPed(src)
    SetTimeout(1500, function()
        local lignes = MySQL.query.await('SELECT plate, citizenid, garage FROM player_vehicles WHERE citizenid = ? AND state = 0', { cid }) or {}
        if #lignes == 0 then return end
        local monde = vehiculesDuMonde()
        local n = 0
        for _, l in ipairs(lignes) do
            local veh = monde[nettoyer(l.plate)]
            -- un autre joueur est dedans (passager reste, vehicule emprunte...) : on n'y touche pas
            if not (veh and conducteurJoueur(veh, ped)) then
                rapatrier(l, veh)
                n = n + 1
            end
        end
        if n > 0 then print(('[qbx_properties] %d vehicule(s) de %s ramene(s) au domicile (deconnexion)'):format(n, cid)) end
    end)
end)

-- redemarrage : tout vehicule sorti qui n'existe plus dans le monde rentre au domicile
CreateThread(function()
    while not PropertiesReady do Wait(1000) end
    Wait(10000)
    if reglages.retourAuto ~= true then return end
    for _, src in ipairs(GetPlayers()) do retenir(tonumber(src)) end
    local lignes = MySQL.query.await('SELECT plate, citizenid, garage FROM player_vehicles WHERE state = 0') or {}
    local monde = vehiculesDuMonde()
    local n = 0
    for _, l in ipairs(lignes) do
        if not monde[nettoyer(l.plate)] then rapatrier(l, nil) n = n + 1 end
    end
    if n > 0 then print(('[qbx_properties] %d vehicule(s) sorti(s) ramene(s) au domicile au demarrage'):format(n)) end

    -- surveillance : vehicule disparu, ou detruit sans personne a bord, pendant delaiAbandon secondes
    local abandon = {}
    local delai = tonumber(reglages.delaiAbandon) or 120
    while true do
        Wait(30000)
        lignes = MySQL.query.await('SELECT plate, citizenid, garage FROM player_vehicles WHERE state = 0') or {}
        monde = vehiculesDuMonde()
        local vus = {}
        for _, l in ipairs(lignes) do
            local cle = nettoyer(l.plate)
            vus[cle] = true
            local veh = monde[cle]
            local probleme = false
            if not veh then
                probleme = true
            elseif not conducteurJoueur(veh) and (GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= -3900.0) then
                probleme = true
            end
            if probleme then
                abandon[cle] = abandon[cle] or os.time()
                if os.time() - abandon[cle] >= delai then
                    local dest = rapatrier(l, veh)
                    abandon[cle] = nil
                    local p = QBCore.Functions.GetPlayerByCitizenId(l.citizenid)
                    if p then
                        Bridge.Notify(p.PlayerData.source, ('Votre vehicule %s a ete ramene au garage (%s).'):format(l.plate,
                            dest:find('^property_') and 'domicile' or dest), 'inform')
                    end
                end
            else
                abandon[cle] = nil
            end
        end
        for cle in pairs(abandon) do if not vus[cle] then abandon[cle] = nil end end
    end
end)
