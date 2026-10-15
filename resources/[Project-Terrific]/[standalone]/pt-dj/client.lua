local xs = exports.xsound
local ecart = 0           -- heure serveur - heure locale (secondes)
local locaux = {}         -- [id] = { v, volume, pause } : ce qui joue chez ce joueur

local function heureServeur()
    return GetCloudTimeAsInt() + ecart
end

CreateThread(function()
    local h = lib.callback.await('pt-dj:heure', false)
    if h then ecart = h - GetCloudTimeAsInt() end
end)

local function evenementAllume(c)
    return not c.evenement or GlobalState['pt_evenement_' .. c.evenement] == true
end

local function etat(id)
    return GlobalState['pt_dj_' .. id]
end

local function ecoule(e)
    if e.pause then return e.decalage end
    return e.decalage + (heureServeur() - e.debut)
end

local function nomSon(id)
    return 'pt_dj_' .. id
end

local function arreter(id)
    local n = nomSon(id)
    if xs:soundExists(n) then xs:Destroy(n) end
    locaux[id] = nil
end

-- ---------------------------------------------------------------------------------------------------------------
-- Synchronisation de la musique : chaque joueur proche joue le morceau au meme moment que les autres

local function synchroniser(c, pos)
    local e = etat(c.id)
    local n = nomSon(c.id)
    local proche = #(pos - c.son) < c.portee + 40.0
    if not e or not e.url or not proche or not evenementAllume(c) then
        if locaux[c.id] or xs:soundExists(n) then arreter(c.id) end
        return
    end
    local l = locaux[c.id]
    if e.duree and not e.boucle and ecoule(e) >= e.duree then return end
    if not l or l.v ~= e.v or not xs:soundExists(n) then
        if xs:soundExists(n) then xs:Destroy(n) end
        local v = e.v
        locaux[c.id] = { v = v, volume = e.volume, pause = false }
        xs:PlayUrlPos(n, e.url, e.volume / 100, c.son, false, {
            onPlayStart = function()
                local actuel = etat(c.id)
                if not actuel or actuel.v ~= v then return end
                local t = ecoule(actuel)
                if t > 2 then xs:setTimeStamp(n, t) end
                xs:Distance(n, c.portee)
                if actuel.pause then
                    xs:Pause(n)
                    if locaux[c.id] then locaux[c.id].pause = true end
                end
                if not actuel.duree then
                    SetTimeout(1500, function()
                        local d = xs:soundExists(n) and xs:getMaxDuration(n)
                        if d and d > 0 then TriggerServerEvent('pt-dj:server:duree', c.id, v, d) end
                    end)
                end
            end,
        })
        xs:Distance(n, c.portee)
        return
    end
    if l.volume ~= e.volume then
        xs:setVolume(n, e.volume / 100)
        l.volume = e.volume
    end
    if e.pause and not l.pause then
        xs:Pause(n)
        l.pause = true
    elseif not e.pause and l.pause then
        xs:Resume(n)
        xs:setTimeStamp(n, ecoule(e))
        l.pause = false
    end
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, c in ipairs(Config.Cabines) do
            synchroniser(c, pos)
        end
        Wait(1000)
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Menu de la table de mixage

local ouvrirMenu

local function demanderLien(titre)
    local r = lib.inputDialog(titre, {
        { type = 'input', label = 'Lien YouTube ou MP3', description = 'https://www.youtube.com/watch?v=... ou https://.../morceau.mp3', required = true },
    })
    return r and r[1] and r[1]:gsub('^%s+', ''):gsub('%s+$', '') or nil
end

local function texteEtat(e)
    if not e or not e.url then return 'Rien en cours' end
    local t = math.floor(ecoule(e))
    local temps = ('%d:%02d'):format(t // 60, t % 60)
    if e.duree then temps = temps .. (' / %d:%02d'):format(math.floor(e.duree) // 60, math.floor(e.duree) % 60) end
    return ('%s %s | volume %d%%%s%s'):format(e.pause and 'En pause' or 'En lecture', temps, e.volume,
        e.boucle and ' | boucle' or '', (e.file and #e.file > 0) and (' | %d en attente'):format(#e.file) or '')
end

ouvrirMenu = function(c)
    local e = etat(c.id)
    local options = {
        { title = texteEtat(e), description = e and e.url or nil, icon = 'compact-disc', readOnly = true },
        {
            title = 'Jouer un morceau', description = 'Remplace le morceau en cours', icon = 'play',
            onSelect = function()
                local url = demanderLien('Jouer maintenant')
                if url then TriggerServerEvent('pt-dj:server:jouer', c.id, url, false) end
                Wait(300) ouvrirMenu(c)
            end,
        },
        {
            title = 'Ajouter a la file d\'attente', description = 'Joue apres le morceau en cours', icon = 'list',
            disabled = not (e and e.url),
            onSelect = function()
                local url = demanderLien('Ajouter a la file')
                if url then TriggerServerEvent('pt-dj:server:jouer', c.id, url, true) end
                Wait(300) ouvrirMenu(c)
            end,
        },
        {
            title = (e and e.pause) and 'Reprendre' or 'Pause', icon = (e and e.pause) and 'play' or 'pause',
            disabled = not (e and e.url),
            onSelect = function()
                TriggerServerEvent('pt-dj:server:commande', c.id, (e and e.pause) and 'reprendre' or 'pause')
                Wait(300) ouvrirMenu(c)
            end,
        },
        {
            title = 'Morceau suivant', icon = 'forward', disabled = not (e and e.url),
            onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'passer') Wait(300) ouvrirMenu(c) end,
        },
        {
            title = 'Volume', description = e and (e.volume .. ' %') or nil, icon = 'volume-high', disabled = not (e and e.url),
            onSelect = function()
                local r = lib.inputDialog('Volume', {
                    { type = 'number', label = 'Volume (0 a 100)', default = e and e.volume or Config.VolumeDefaut, min = 0, max = 100 },
                })
                if r and r[1] then TriggerServerEvent('pt-dj:server:commande', c.id, 'volume', r[1]) end
                Wait(300) ouvrirMenu(c)
            end,
        },
        {
            title = (e and e.boucle) and 'Boucle : activee' or 'Boucle : desactivee', icon = 'repeat', disabled = not (e and e.url),
            onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'boucle') Wait(300) ouvrirMenu(c) end,
        },
        {
            title = 'Vider la file d\'attente', icon = 'trash', disabled = not (e and e.file and #e.file > 0),
            onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'viderfile') Wait(300) ouvrirMenu(c) end,
        },
        {
            title = 'Arreter la musique', icon = 'stop', disabled = not (e and e.url),
            onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'stop') end,
        },
    }
    for cle, ef in pairs(Config.Effets) do
        if c.effets and c.effets[cle] then
            options[#options + 1] = {
                title = 'Effet : ' .. ef.label, icon = 'wand-magic-sparkles',
                onSelect = function() TriggerServerEvent('pt-dj:server:effet', c.id, cle) ouvrirMenu(c) end,
            }
        end
    end
    lib.registerContext({ id = 'pt_dj_menu', title = c.label, options = options })
    lib.showContext('pt_dj_menu')
end

-- Point d'interaction : marqueur sur la table de mixage, E pour ouvrir (si on a l'acces)
CreateThread(function()
    while true do
        local attente = 1000
        local pos = GetEntityCoords(PlayerPedId())
        for _, c in ipairs(Config.Cabines) do
            if evenementAllume(c) then
                local d = #(pos - c.coords)
                if d < 15.0 then
                    attente = 0
                    DrawMarker(2, c.coords.x, c.coords.y, c.coords.z + 0.9, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                        0.25, 0.25, 0.2, 160, 80, 255, 160, true, true, 2, false, nil, nil, false)
                    if d < 1.8 then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Table de mixage')
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustReleased(0, Config.Touche) then
                            if lib.callback.await('pt-dj:peutMixer', false, c.id) then
                                ouvrirMenu(c)
                            else
                                TriggerEvent('QBCore:Notify', 'Reserve au DJ (un admin peut vous autoriser).', 'error')
                            end
                        end
                    end
                end
            end
        end
        Wait(attente)
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Effets (fumee, confettis, feux d'artifice) vus par tous les joueurs proches

local function chargerDict(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local limite = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(dict) do
        if GetGameTimer() > limite then return false end
        Wait(0)
    end
    return true
end

RegisterNetEvent('pt-dj:client:effet', function(id, cle)
    local c
    for _, x in ipairs(Config.Cabines) do if x.id == id then c = x end end
    local ef = Config.Effets[cle]
    if not c or not ef or not c.effets or not c.effets[cle] then return end
    if #(GetEntityCoords(PlayerPedId()) - c.son) > 300.0 then return end
    if not chargerDict(ef.dict) then return end
    local boucles = {}
    for _, p in ipairs(c.effets[cle]) do
        UseParticleFxAsset(ef.dict)
        if ef.boucle then
            boucles[#boucles + 1] = StartParticleFxLoopedAtCoord(ef.nom, p.x, p.y, p.z, 0.0, 0.0, 0.0, ef.echelle or 1.0, false, false, false, false)
        else
            StartParticleFxNonLoopedAtCoord(ef.nom, p.x, p.y, p.z, 0.0, 0.0, 0.0, ef.echelle or 1.0, false, false, false)
        end
    end
    if #boucles > 0 then
        SetTimeout(ef.duree or 6000, function()
            for _, b in ipairs(boucles) do StopParticleFxLooped(b, false) end
        end)
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() then return end
    for _, c in ipairs(Config.Cabines) do arreter(c.id) end
end)
