local QBCore = exports['qb-core']:GetCoreObject()
local enTenue = false

local function autorise(t)
    local job = QBCore.Functions.GetPlayerData().job
    if not job or not job.onduty or not Config.Metiers[job.name] then return false end
    return t == nil or (t.metiers or {})[job.name] == true
end

local function remettreCivil()
    if not enTenue then return end
    enTenue = false
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

local function appliquer(t)
    local h = joaat(t.modele)
    if not lib.requestModel(h, 10000) then
        lib.notify({ description = 'Tenue introuvable (ressource pt-tenues-ordre demarree ?)', type = 'error' })
        return
    end
    local ped = PlayerPedId()
    local vie, armure = GetEntityHealth(ped), GetPedArmour(ped)
    SetPlayerModel(PlayerId(), h)
    SetModelAsNoLongerNeeded(h)
    ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    ClearAllPedProps(ped)
    SetEntityHealth(ped, vie)
    SetPedArmour(ped, armure)
    enTenue = true
end

local function couvreChef(index)
    local ped = PlayerPedId()
    if index < 0 then ClearPedProp(ped, 0) return end
    if GetNumberOfPedPropDrawableVariations(ped, 0) > index then
        SetPedPropIndex(ped, 0, index, 0, true)
    else
        lib.notify({ description = 'Pas de couvre-chef supplementaire pour cette tenue', type = 'inform' })
    end
end

local function variante(composant, sens)
    local ped = PlayerPedId()
    local n = GetNumberOfPedDrawableVariations(ped, composant)
    if n <= 1 then return end
    local d = (GetPedDrawableVariation(ped, composant) + sens) % n
    SetPedComponentVariation(ped, composant, d, 0, 0)
end

-- tenues de service enregistrees par le chef (vestiaire du metier, illenium-appearance)
local function tenuesDuMetier()
    if GetResourceState('illenium-appearance') ~= 'started' then return {} end
    local genre = GetEntityModel(PlayerPedId()) == joaat('mp_f_freemode_01') and 'Female' or 'Male'
    return lib.callback.await('illenium-appearance:server:getManagementOutfits', false, 'Job', genre) or {}
end

local function mettreTenueDuMetier(t)
    TriggerEvent('illenium-appearance:client:changeOutfit', {
        type = 'Job', name = t.name, model = t.model, components = t.components, props = t.props, disableSave = true,
    })
    enTenue = true
end

local function menu()
    if not autorise() then
        lib.notify({ description = 'Reserve aux forces de l\'ordre en service', type = 'error' })
        return
    end
    local options = {}
    for _, t in ipairs(tenuesDuMetier()) do
        options[#options + 1] = { title = t.name or 'Tenue', description = 'Tenue de service du metier', icon = 'user-tie',
            onSelect = function()
                if enTenue and GetEntityModel(PlayerPedId()) ~= joaat('mp_m_freemode_01') and GetEntityModel(PlayerPedId()) ~= joaat('mp_f_freemode_01') then
                    remettreCivil() Wait(1500)
                end
                mettreTenueDuMetier(t)
            end }
    end
    for _, t in ipairs(Config.Tenues) do
        if autorise(t) then
            options[#options + 1] = { title = t.label, icon = 'shirt', onSelect = function() appliquer(t) menu() end }
        end
    end
    if enTenue then
        options[#options + 1] = { title = 'Couvre-chef : aucun', icon = 'xmark', onSelect = function() couvreChef(-1) menu() end }
        options[#options + 1] = { title = 'Couvre-chef 1 (casque / calot)', icon = 'helmet-safety', onSelect = function() couvreChef(0) menu() end }
        options[#options + 1] = { title = 'Couvre-chef 2', icon = 'hat-cowboy', onSelect = function() couvreChef(1) menu() end }
        options[#options + 1] = { title = 'Variante du haut', icon = 'repeat', onSelect = function() variante(11, 1) variante(3, 1) menu() end }
        options[#options + 1] = { title = 'Variante du bas', icon = 'repeat', onSelect = function() variante(4, 1) menu() end }
        options[#options + 1] = { title = 'Variante equipement', icon = 'repeat', onSelect = function() variante(9, 1) variante(8, 1) menu() end }
        options[#options + 1] = { title = 'Reprendre ma tenue civile', icon = 'user', onSelect = remettreCivil }
    end
    if #options == 0 then
        lib.notify({ description = 'Aucune tenue disponible pour ton metier', type = 'inform' })
        return
    end
    lib.registerContext({ id = 'pt_tenues_ordre', title = 'Vestiaire', options = options })
    lib.showContext('pt_tenues_ordre')
end

RegisterCommand('tenue', menu, false)
TriggerEvent('chat:addSuggestion', '/tenue', 'Vestiaire des forces de l\'ordre (en service)')
exports('OuvrirVestiaire', menu)
RegisterNetEvent('pt-tenues-ordre:client:ouvrir', menu)

-- Tenue automatique a la prise de service
local function tenueAuto()
    local pd = QBCore.Functions.GetPlayerData()
    local job = pd.job
    if not job or not job.onduty then return end
    local def = Config.TenueAuto[job.name]
    if not def then return end
    if pd.metadata and (pd.metadata.isdead or pd.metadata.inlaststand) then return end
    if enTenue then return end
    if def.tenueDuMetier then
        local liste = tenuesDuMetier()
        if #liste > 0 then
            local choix = liste[1]
            for _, t in ipairs(liste) do
                if (t.name or ''):lower():find('^service') then choix = t break end
            end
            mettreTenueDuMetier(choix)
            lib.notify({ description = ('Tenue de service mise (%s). /tenue pour en changer.'):format(choix.name or ''), type = 'inform' })
            return
        end
    end
    local femme = pd.charinfo and tonumber(pd.charinfo.gender) == 1
    local modele = femme and def.femme or (not femme and def.homme)
    if not modele then return end
    if GetEntityModel(PlayerPedId()) == joaat(modele) then return end
    appliquer({ modele = modele })
    lib.notify({ description = 'Tenue de service mise. /tenue pour en changer.', type = 'inform' })
end

-- Prise / fin de service, changement de metier
RegisterNetEvent('QBCore:Client:SetDuty', function(service)
    if service then SetTimeout(500, tenueAuto) else remettreCivil() end
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not job.onduty or not Config.Metiers[job.name] then
        remettreCivil()
    else
        SetTimeout(500, tenueAuto)
    end
end)
-- Connexion : on attend que l'apparence du personnage soit chargee
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if not Config.TenueAutoALaConnexion then return end
    SetTimeout(8000, tenueAuto)
end)
