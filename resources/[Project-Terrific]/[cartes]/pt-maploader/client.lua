local ressource = GetCurrentResourceName()
local cartes = {}
local eauChargee = false

local function charger(carte)
    local src = LoadResourceFile(ressource, carte.fichier)
    if not src then
        print(('^1[pt-maploader] fichier introuvable : %s^7'):format(carte.fichier))
        return nil
    end
    local fn, err = load(src, '@' .. ressource .. '/' .. carte.fichier, 't')
    if not fn then
        print(('^1[pt-maploader] %s : %s^7'):format(carte.fichier, err))
        return nil
    end
    return fn()
end

local function modele(h)
    if not IsModelInCdimage(h) then return false end
    RequestModel(h)
    local limite = GetGameTimer() + 5000
    while not HasModelLoaded(h) do
        if GetGameTimer() > limite then return false end
        Wait(0)
    end
    return true
end

local function orienter(ent, e)
    if e.q then
        SetEntityQuaternion(ent, e.q[1], e.q[2], e.q[3], e.q[4])
    else
        SetEntityRotation(ent, e.r[1], e.r[2], e.r[3], 2, true)
    end
end

local creer = {}

function creer.objets(e)
    local ent = CreateObjectNoOffset(e.h, e.p[1], e.p[2], e.p[3], false, false, false)
    orienter(ent, e)
    if e.tex then SetObjectTextureVariation(ent, e.tex) end
    if not e.dyn then FreezeEntityPosition(ent, true) end
    return ent
end

function creer.vehicules(e)
    local ent = CreateVehicle(e.h, e.p[1], e.p[2], e.p[3], e.r[3], false, false)
    orienter(ent, e)
    if e.c1 then SetVehicleColours(ent, e.c1, e.c2 or 0) end
    SetVehicleDoorsLocked(ent, 2)
    SetEntityInvincible(ent, true)
    SetVehicleCanBeVisiblyDamaged(ent, false)
    FreezeEntityPosition(ent, true)
    return ent
end

function creer.pnj(e)
    local ent = CreatePed(4, e.h, e.p[1], e.p[2], e.p[3] - 1.0, e.r[3], false, false)
    SetEntityInvincible(ent, true)
    SetBlockingOfNonTemporaryEvents(ent, true)
    SetPedFleeAttributes(ent, 0, false)
    SetPedCanRagdoll(ent, false)
    SetPedDiesWhenInjured(ent, false)
    if e.arme then
        GiveWeaponToPed(ent, joaat(e.arme), 0, false, true)
    end
    local scenario = e.scenario or (e.arme and 'WORLD_HUMAN_GUARD_STAND') or nil
    if scenario then
        TaskStartScenarioInPlace(ent, scenario, 0, true)
    end
    return ent
end

local function supprimer(ent)
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local TYPES = { 'objets', 'vehicules', 'pnj' }

local function mettreAJour(carte, pos)
    local d = carte.data
    local portee = Config.DistanceApparition
    local portee2 = portee * portee
    local sortie2 = (portee + 50.0) ^ 2
    local crees = 0
    for _, typ in ipairs(TYPES) do
        if typ == 'objets' or carte[typ] then
            local liste, ents = d[typ], carte.ents[typ]
            for i = 1, #liste do
                local e = liste[i]
                local dx, dy = e.p[1] - pos.x, e.p[2] - pos.y
                local dist2 = dx * dx + dy * dy
                local ent = ents[i]
                if dist2 < portee2 then
                    if not ent and not carte.invalides[e.h] then
                        if modele(e.h) then
                            ents[i] = creer[typ](e)
                            SetModelAsNoLongerNeeded(e.h)
                            crees = crees + 1
                            if crees % Config.ParFrame == 0 then Wait(0) end
                        else
                            carte.invalides[e.h] = true
                            print(('^3[pt-maploader] %s : modele %s absent du jeu, ignore^7'):format(carte.nom, e.h))
                        end
                    end
                elseif ent and dist2 > sortie2 then
                    supprimer(ent)
                    ents[i] = nil
                end
            end
        end
    end
end

local function viderCarte(carte)
    for _, typ in ipairs(TYPES) do
        for i, ent in pairs(carte.ents[typ]) do
            supprimer(ent)
            carte.ents[typ][i] = nil
        end
    end
end

local function toutSupprimer()
    for _, carte in ipairs(cartes) do
        viderCarte(carte)
    end
end

-- Cartes d'evenement : affichees seulement quand un admin les allume (/evenement), etat partage par le serveur
local function evenementAllume(carte)
    return not carte.evenement or GlobalState['pt_evenement_' .. carte.nom] == true
end

CreateThread(function()
    for _, carte in ipairs(Config.Cartes) do
        if carte.actif and (not carte.ressource or GetResourceState(carte.ressource) == 'started') then
            local data = charger(carte)
            if data then
                carte.data = data
                carte.ents = { objets = {}, vehicules = {}, pnj = {} }
                carte.invalides = {}
                cartes[#cartes + 1] = carte
                if carte.eau then
                    if LoadWaterFromPath then
                        eauChargee = LoadWaterFromPath(ressource, carte.eau) and true or false
                        if not eauChargee then
                            print(('^3[pt-maploader] %s : water.xml non charge^7'):format(carte.nom))
                        end
                    else
                        print('^3[pt-maploader] LoadWaterFromPath indisponible : mettez a jour les artifacts FXServer^7')
                    end
                end
            end
        end
    end
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, carte in ipairs(cartes) do
            if not evenementAllume(carte) then
                if next(carte.ents.objets) or next(carte.ents.vehicules) or next(carte.ents.pnj) then
                    viderCarte(carte)
                end
            else
                local c = carte.data.centre
                local dx, dy = c.x - pos.x, c.y - pos.y
                local loin = carte.data.rayon + Config.DistanceApparition + 100.0
                if dx * dx + dy * dy < loin * loin or next(carte.ents.objets) or next(carte.ents.vehicules) or next(carte.ents.pnj) then
                    mettreAJour(carte, pos)
                end
            end
        end
        Wait(1500)
    end
end)

-- Teleporteurs des cartes (marqueurs Map Editor avec destination, entrees d'interieurs)
CreateThread(function()
    while true do
        local attente = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehicule = GetVehiclePedIsIn(ped, false)
        for _, carte in ipairs(cartes) do
            for _, m in ipairs(evenementAllume(carte) and carte.data.marqueurs or {}) do
                local dist = #(pos - vector3(m.p[1], m.p[2], m.p[3]))
                if dist < 25.0 then
                    attente = 0
                    DrawMarker(m.type, m.p[1], m.p[2], m.p[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        m.taille[1], m.taille[2], m.taille[3], m.rgba[1], m.rgba[2], m.rgba[3], m.rgba[4],
                        false, true, 2, false, nil, nil, false)
                    local enVoiture = vehicule ~= 0
                    local portee = (m.vehicule and enVoiture) and 3.0 or 1.5
                    if dist < portee and (not enVoiture or m.vehicule) then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. (m.texte or 'Se rendre de l\'autre cote'))
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, Config.ToucheTeleport) then
                            DoScreenFadeOut(400)
                            Wait(450)
                            local entite = (enVoiture and GetPedInVehicleSeat(vehicule, -1) == ped) and vehicule or ped
                            RequestCollisionAtCoord(m.cible[1], m.cible[2], m.cible[3])
                            SetEntityCoords(entite, m.cible[1], m.cible[2], m.cible[3], false, false, false, false)
                            if m.h then SetEntityHeading(entite, m.h) end
                            Wait(600)
                            DoScreenFadeIn(400)
                        end
                    end
                end
            end
        end
        Wait(attente)
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= ressource then return end
    toutSupprimer()
    if eauChargee and ResetWater then ResetWater() end
end)
