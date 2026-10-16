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

-- MP3 local (pt-dj/musique/nom.mp3) -> adresse NUI ; un lien https reste tel quel
local function adresseSon(url)
    if url:match('^https?://') then return url end
    return ('https://cfx-nui-%s/musique/%s'):format(GetCurrentResourceName(), (url:gsub('[^%w%-_%.~]', function(ch) return ('%%%02X'):format(ch:byte()) end)))
end

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
        xs:PlayUrlPos(n, adresseSon(e.url), e.volume / 100, c.son, false, {
            onError = function(erreur)
                lib.notify({ title = 'DJ', description = 'Musique illisible : ' .. tostring(e.url) .. ' (fichier absent du dossier musique ? fais refresh puis ensure pt-dj)', type = 'error', duration = 8000 })
                print(('^1[pt-dj] lecture impossible %s -> %s^7'):format(tostring(e.url), tostring(erreur)))
            end,
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
local tempsPrecis
local tempsAudio

local function demanderLien(titre)
    local r = lib.inputDialog(titre, {
        { type = 'input', label = 'Lien ou fichier MP3', description = 'https://soundcloud.com/... , https://.../morceau.mp3 , YouTube, ou le nom d\'un MP3 du dossier pt-dj/musique (ex. monset.mp3)', required = true },
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
            title = 'Jouer un MP3 du serveur', description = 'Fichiers du dossier pt-dj/musique (analyse sans YouTube)', icon = 'folder-open',
            onSelect = function()
                local liste = lib.callback.await('pt-dj:listeMp3', false) or {}
                local opts = {}
                for _, nom in ipairs(liste) do
                    opts[#opts + 1] = {
                        title = nom, icon = 'music',
                        description = 'Jouer maintenant',
                        onSelect = function() TriggerServerEvent('pt-dj:server:jouer', c.id, nom, false) Wait(300) ouvrirMenu(c) end,
                    }
                    if e and e.url then
                        opts[#opts + 1] = {
                            title = '  + file d\'attente : ' .. nom, icon = 'list',
                            onSelect = function() TriggerServerEvent('pt-dj:server:jouer', c.id, nom, true) Wait(300) ouvrirMenu(c) end,
                        }
                    end
                end
                if #opts == 0 then
                    opts[1] = { title = 'Aucun MP3', description = 'Mets tes fichiers .mp3 dans resources/.../pt-dj/musique puis redemarre pt-dj', icon = 'circle-info', readOnly = true }
                end
                lib.registerContext({ id = 'pt_dj_mp3', title = 'MP3 du serveur', menu = 'pt_dj_menu', options = opts })
                lib.showContext('pt_dj_mp3')
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
    options[#options + 1] = {
        title = ('Tempo : %s BPM %s'):format(e and math.floor((e.bpm or Config.BpmDefaut) + 0.5) or Config.BpmDefaut,
            not e and '' or e.bpmManuel and '(manuel)' or e.analyse == 'ok' and '(analyse)' or e.analyse == 'encours' and '(analyse en cours...)'
            or e.analyse == 'echec' and '(analyse impossible)' or ''), icon = 'drum',
        description = 'Taper le tempo a la main : appuyez 8 fois sur E au rythme (remplace l\'analyse pour ce morceau)',
        disabled = not (e and e.url),
        onSelect = function() TaperTempo(c) end,
    }
    options[#options + 1] = {
        title = 'Relancer l\'analyse du tempo', icon = 'wave-square', disabled = not (e and e.url) or (e and e.analyse == 'encours'),
        onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'reanalyser') Wait(300) ouvrirMenu(c) end,
    }
    options[#options + 1] = {
        title = 'Regler le tempo a la main', icon = 'gauge', disabled = not (e and e.url),
        onSelect = function()
            local r = lib.inputDialog('Tempo', { { type = 'number', label = 'BPM (60 a 200)', default = e and e.bpm or Config.BpmDefaut, min = 60, max = 200 } })
            if r and r[1] then TriggerServerEvent('pt-dj:server:commande', c.id, 'bpm', r[1]) end
            Wait(300) ouvrirMenu(c)
        end,
    }
    options[#options + 1] = {
        title = (e and e.lumieres == false) and 'Jeu de lumieres : eteint' or 'Jeu de lumieres : allume', icon = 'lightbulb',
        disabled = not (e and e.url),
        onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'lumieres') Wait(300) ouvrirMenu(c) end,
    }
    options[#options + 1] = {
        title = (e and e.fumeeAuto == false) and 'Fumee automatique : non' or 'Fumee automatique : oui', icon = 'cloud',
        disabled = not (e and e.url and c.effets and c.effets.fumee),
        onSelect = function() TriggerServerEvent('pt-dj:server:commande', c.id, 'fumeeauto') Wait(300) ouvrirMenu(c) end,
    }
    options[#options + 1] = {
        title = 'Effet : Jets de CO2', icon = 'wind',
        onSelect = function() TriggerServerEvent('pt-dj:server:co2', c.id, 'co2') ouvrirMenu(c) end,
    }
    options[#options + 1] = {
        title = 'Effet : Lance-flammes', icon = 'fire',
        onSelect = function() TriggerServerEvent('pt-dj:server:co2', c.id, 'flammes') ouvrirMenu(c) end,
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

local function demarrerBoucle(ef, p)
    UseParticleFxAsset(ef.dict)
    return StartParticleFxLoopedAtCoord(ef.nom, p.x, p.y, p.z, 0.0, 0.0, 0.0, ef.echelle or 1.0, false, false, false, false)
end

function JouerEffet(c, cle)
    local ef = Config.Effets[cle]
    if not c or not ef or not c.effets or not c.effets[cle] then return end
    if #(GetEntityCoords(PlayerPedId()) - c.son) > 300.0 then return end
    if not chargerDict(ef.dict) then return end
    local boucles = {}
    for _, p in ipairs(c.effets[cle]) do
        if ef.boucle then
            local h = demarrerBoucle(ef, p)
            -- effet indisponible sur cette version du jeu : effet de secours
            if (not h or h == 0) and ef.secours and chargerDict(ef.secours.dict) then
                h = demarrerBoucle(ef.secours, p)
            end
            if h and h ~= 0 then boucles[#boucles + 1] = h end
        else
            UseParticleFxAsset(ef.dict)
            StartParticleFxNonLoopedAtCoord(ef.nom, p.x, p.y, p.z, 0.0, 0.0, 0.0, ef.echelle or 1.0, false, false, false)
        end
    end
    if #boucles > 0 then
        SetTimeout(ef.duree or 6000, function()
            for _, b in ipairs(boucles) do StopParticleFxLooped(b, false) end
        end)
    end
end

RegisterNetEvent('pt-dj:client:effet', function(id, cle)
    for _, x in ipairs(Config.Cabines) do
        if x.id == id then JouerEffet(x, cle) return end
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom ~= GetCurrentResourceName() then return end
    for _, c in ipairs(Config.Cabines) do arreter(c.id) end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Jeu de lumieres synchronise sur le tempo du DJ (projecteurs, lasers, stroboscope, fumee automatique).
-- Le jeu ne peut pas « ecouter » le son : le DJ donne le tempo (tap tempo ou BPM) et chaque joueur calcule les temps
-- a partir de l'heure du serveur, donc tout le monde voit les memes flashs au meme moment.

local repere = { s = 0, gt = 0 }
tempsPrecis = function(e)
    if e.pause then return e.decalage end
    local s = heureServeur()
    if s ~= repere.s then repere.s, repere.gt = s, GetGameTimer() end
    return e.decalage + (s - e.debut) + math.min(GetGameTimer() - repere.gt, 999) / 1000.0
end

function TaperTempo(c)
    local e = etat(c.id)
    if not e or not e.url then return end
    lib.showTextUI('[E] au rythme de la musique (8 fois)  -  [Retour] annuler', { position = 'top-center', icon = 'drum' })
    local taps, limite = {}, GetGameTimer() + 15000
    while #taps < 8 and GetGameTimer() < limite do
        if IsControlJustPressed(0, 38) then taps[#taps + 1] = { gt = GetGameTimer(), t = tempsAudio(c, etat(c.id) or e) } end
        if IsControlJustPressed(0, 177) then break end
        Wait(0)
    end
    lib.hideTextUI()
    if #taps < 4 then
        TriggerEvent('QBCore:Notify', 'Tempo non pris (il faut au moins 4 appuis).', 'error')
        return ouvrirMenu(c)
    end
    local intervalle = (taps[#taps].gt - taps[1].gt) / (#taps - 1) / 1000.0
    local bpm = 60.0 / intervalle
    while bpm < 70 do bpm = bpm * 2 end
    while bpm > 190 do bpm = bpm / 2 end
    local periode = 60.0 / bpm
    TriggerServerEvent('pt-dj:server:commande', c.id, 'bpm', { bpm, taps[#taps].t % periode })
    TriggerEvent('QBCore:Notify', ('Tempo cale : %d BPM'):format(math.floor(bpm + 0.5)), 'success')
    Wait(300)
    ouvrirMenu(c)
end

-- geometrie d'une scene (calculee une fois) : projecteurs, lasers, centre du public
local scenes = {}
local function moyenne(points)
    local x, y, z = 0.0, 0.0, 0.0
    for _, p in ipairs(points) do x, y, z = x + p.x, y + p.y, z + p.z end
    return vec3(x / #points, y / #points, z / #points)
end

local function scene(c)
    if scenes[c.id] then return scenes[c.id] end
    local L = Config.Lumieres
    local ef = c.effets or {}
    local devant = (ef.confettis and #ef.confettis > 0) and moyenne(ef.confettis) or (c.son + vec3(0.0, 8.0, 0.0))
    local avant = devant - c.son
    avant = vec3(avant.x, avant.y, 0.0)
    local l = #avant
    avant = l > 0.1 and (avant / l) or vec3(0.0, 1.0, 0.0)
    local cote = vec3(-avant.y, avant.x, 0.0)
    local w = L.largeurRampe or 26.0
    local centreRampe = c.son + avant * 2.0 + vec3(0.0, 0.0, L.hauteurRampe or 6.0)
    local sol = c.son.z - 3.0
    if ef.fumee and #ef.fumee > 0 then sol = moyenne(ef.fumee).z end
    local function rampe(nb, dz)
        local liste = {}
        for i = 1, nb do
            local x = nb > 1 and (-w / 2 + w * (i - 1) / (nb - 1)) or 0.0
            liste[i] = centreRampe + cote * x + vec3(0.0, 0.0, dz)
        end
        return liste
    end
    local function ligneSol(nb, decale)
        local liste = {}
        local lw = w * 0.9
        for i = 1, nb do
            local x = nb > 1 and (-lw / 2 + lw * (i - 1 + (decale or 0)) / (nb - 1 + (decale and 1 or 0))) or 0.0
            local p = c.son + avant * 5.0 + cote * x
            liste[i] = vec3(p.x, p.y, sol)
        end
        return liste
    end
    -- pyrotechnie (CO2, flammes) : posee SUR la scene, au bord avant, et tiree vers le ciel
    local function ligneScene(nb, decale, reglage)
        local liste = {}
        local lw = w * 0.9
        reglage = reglage or {}
        -- hauteur comptee depuis le plancher de la scene (pieds du DJ a la table de mixage), pareil sur toutes les scenes
        local plancher = (c.coords and c.coords.z or c.son.z) - 1.0
        local z = plancher + (reglage.hauteur or L.pyroHauteur or 0.0)
        for i = 1, nb do
            local x = nb > 1 and (-lw / 2 + lw * (i - 1 + (decale or 0)) / (nb - 1 + (decale and 1 or 0))) or 0.0
            local p = c.son + avant * (reglage.avant or L.pyroAvant or 3.0) + cote * x
            liste[i] = vec3(p.x, p.y, z)
        end
        return liste
    end
    local cap = math.deg(math.atan(-avant.x, avant.y))
    local s = {
        lyres = c.lyres or c.projecteurs or rampe(L.lyres or 16, 0.0),
        strobos = c.strobos or rampe(L.strobos or 10, 0.8),
        -- lasers : centre de scene, bouts et quarts de la rampe, coins avant au sol
        lasers = c.lasers or {
            c.son + vec3(0.0, 0.0, 5.0),
            centreRampe + cote * (-w / 2), centreRampe + cote * (w / 2),
            centreRampe + cote * (-w / 4), centreRampe + cote * (w / 4),
            vec3(0, 0, 0) + c.son + avant * 5.0 + cote * (-w / 2) + vec3(0.0, 0.0, sol - c.son.z + 0.5),
            vec3(0, 0, 0) + c.son + avant * 5.0 + cote * (w / 2) + vec3(0.0, 0.0, sol - c.son.z + 0.5),
        },
        co2 = c.co2 or ligneScene(L.jetsDevant or 6, nil, L.co2),
        flammes = c.flammes or ligneScene((L.flammes and L.flammes.nombre) or 4, 0.5, L.flammes),
        sol = sol, cap = cap,
        avant = avant, cote = cote, centreRampe = centreRampe,
        public = c.public or (c.son + avant * 25.0 + vec3(0.0, 0.0, -3.0)),
    }
    scenes[c.id] = s
    return s
end

-- effets de particules pyrotechniques (CO2, flammes) : premier effet disponible, oriente
local effetsTrouves = {}
local function tir(cle, cfg, points, rotation, quels)
    local boucles = {}
    for i, p in ipairs(points) do
        if not quels or quels(i) then
            local h = 0
            for _, ef in ipairs(effetsTrouves[cle] and { effetsTrouves[cle] } or cfg.effets) do
                if chargerDict(ef.dict) then
                    UseParticleFxAsset(ef.dict)
                    h = StartParticleFxLoopedAtCoord(ef.nom, p.x, p.y, p.z, rotation.x, rotation.y, rotation.z, ef.echelle or 2.0, false, false, false, false)
                    if h and h ~= 0 then
                        effetsTrouves[cle] = ef
                        if cfg.couleur then SetParticleFxLoopedColour(h, cfg.couleur[1], cfg.couleur[2], cfg.couleur[3], false) end
                        break
                    end
                end
            end
            if h and h ~= 0 then boucles[#boucles + 1] = h end
        end
    end
    if #boucles > 0 then
        SetTimeout(cfg.duree or 1200, function()
            for _, b in ipairs(boucles) do StopParticleFxLooped(b, false) end
        end)
    end
end

-- jets de CO2 inclines vers le public
local function jetsCo2(c, quels)
    if #(GetEntityCoords(PlayerPedId()) - c.son) > 250.0 then return end
    local s = scene(c)
    local cfg = Config.Lumieres.co2
    tir('co2', cfg, s.co2, vec3(cfg.angleTir or 90.0, 0.0, s.cap), quels)
end

local function lanceFlammes(c, quels)
    if #(GetEntityCoords(PlayerPedId()) - c.son) > 250.0 then return end
    local s = scene(c)
    local cfg = Config.Lumieres.flammes
    if not cfg then return end
    tir('flammes', cfg, s.flammes, cfg.rotation or vec3(90.0, 0.0, 0.0), quels)
end

local function couleur(n)
    local liste = Config.Lumieres.couleurs
    return liste[(n % #liste) + 1]
end

local dernierTempsFumee = {}
local dernierDrop = {}

-- valeur (0-9) d'un profil analyse a l'index i (0 = premier element) ; nil sans analyse
local function lire(chaine, i)
    if not chaine or i < 0 or i >= #chaine then return nil end
    return chaine:byte(i + 1) - 48
end

-- Etat musical a l'instant t : temps, phase, energie du passage (0-1), force du coup en cours (0-1), drop
-- Horloge du spectacle calee sur ce que CE joueur entend : position reelle du lecteur (xsound, 4 fois par seconde),
-- lissee contre l'horloge du jeu (precision de l'ordre de quelques millisecondes). Sans mesure : heure du serveur.
local horloges = {}
tempsAudio = function(c, e)
    local n = nomSon(c.id)
    local ok, reel, quand = pcall(function() return xs:getRealTimeStamp(n) end)
    local h = horloges[c.id]
    if not h or h.v ~= e.v then h = { v = e.v } horloges[c.id] = h end
    if ok and reel and quand and not e.pause then
        if quand ~= h.quand then
            h.quand = quand
            local decalage = reel - quand / 1000.0
            if not h.decalage or math.abs(decalage - h.decalage) > 0.25 then
                h.decalage = decalage                                  -- saut (debut, pause, avance) : on recale
            else
                h.decalage = h.decalage + (decalage - h.decalage) * 0.08 -- lissage du bruit de mesure
            end
        end
        if h.decalage then return GetGameTimer() / 1000.0 + h.decalage end
    end
    return tempsPrecis(e)
end

-- Analyse detaillee (grille des temps du set, instruments, couleurs) : recue du serveur une fois par morceau
local donnees, demandes = {}, {}
RegisterNetEvent('pt-dj:client:donnees', function(id, v, d)
    if type(d) == 'table' then donnees[id] = { v = v, d = d } end
end)

local function donneesDe(c, e)
    if e.analyse ~= 'ok' or e.bpmManuel then return nil end
    local D = donnees[c.id]
    if D and D.v == e.v then return D.d end
    local q = demandes[c.id]
    if not q or q.v ~= e.v or GetGameTimer() - q.quand > 8000 then
        demandes[c.id] = { v = e.v, quand = GetGameTimer() }
        TriggerServerEvent('pt-dj:server:donnees', c.id, e.v)
    end
    return nil
end

-- position en temps (0 = premier temps du morceau, 12.5 = milieu du 13e) sur la grille detectee :
-- suit les changements de tempo et les transitions d'un set DJ
local function positionTemps(D, x)
    local T = D.temps
    local nb = #T
    if x < T[1] then return (x - T[1]) / (T[2] - T[1]) end
    if x >= T[nb] then return (nb - 1) + (x - T[nb]) / (T[nb] - T[nb - 1]) end
    local i = D.dernier or 1
    if not (T[i] <= x and T[i + 1] and x < T[i + 1]) then
        local lo, hi = 1, nb
        while hi - lo > 1 do
            local mi = (lo + hi) // 2
            if T[mi] <= x then lo = mi else hi = mi end
        end
        i = lo
        D.dernier = i
    end
    return (i - 1) + (x - T[i]) / (T[i + 1] - T[i])
end

local function musique(c, e)
    local D = donneesDe(c, e) or {}
    local bpm = e.bpm or Config.BpmDefaut
    local ta = tempsAudio(c, e)
    local t = ta - (e.ancre or 0)
    local temps
    if D.temps and #D.temps > 1 then
        temps = positionTemps(D, ta)
    else
        temps = t * bpm / 60.0
    end
    local n = math.floor(temps)
    local phase = temps - n
    local croche = math.floor(temps * 2)
    local phaseCroche = temps * 2 - croche
    local energie = lire(D.energie, n)
    local coup = lire(D.coups, croche)
    local B = D.bandes or {}
    local function bande(nom) local v = lire(B[nom], croche) return v and v / 9.0 or nil end
    local m = {
        t = t, temps = temps, n = n, phase = phase, mesure = n // 4,
        analyse = energie ~= nil,
        energie = energie and (energie / 9.0) or 0.6,
        -- sans analyse : un coup sur chaque temps
        coup = coup and (coup / 9.0) * (1.0 - phaseCroche) ^ 2 or (1.0 - phase) ^ 2,
        coupFort = coup and coup >= 7 and phaseCroche < 0.35 or false,
        drop = false,
        -- instruments (0-1, nil sans analyse) a la croche en cours
        kick = bande('kick'), sub = bande('sub'), bass = bande('bass'), mid = bande('mid'),
        lead = bande('lead'), growl = bande('growl'), high = bande('high'),
        phaseCroche = phaseCroche, croche = croche,
        -- couleur : numero d'accord (change avec l'harmonie), sinon toutes les 8 mesures
        palette = lire(D.couleurs, n) or (n // 32),
        donnees = D,
    }
    -- drop : debut de mesure ou l'energie saute fortement par rapport a la mesure precedente
    if m.analyse and n % 4 == 0 then
        local avant = 0
        for k = n - 4, n - 1 do avant = avant + (lire(D.energie, k) or 0) end
        avant = avant / 4
        if energie - avant >= 4 and energie >= 6 then m.drop = true end
    end
    return m
end

-- faisceau visible d'une lyre : cylindre colore et transparent de la lyre vers sa cible
local function faisceau(p, dir, longueur, col, alpha, largeur)
    DrawMarker(1, p.x, p.y, p.z, dir.x, dir.y, dir.z, 0.0, 0.0, 0.0, largeur, largeur, longueur,
        col[1], col[2], col[3], alpha, false, false, 2, false, nil, nil, false)
end

local dernierCo2, dernierFeu, dernierFlamme = {}, {}, {}

local function unefois(tab, id, cle, f)
    if tab[id] ~= cle then tab[id] = cle CreateThread(f) end
end

-- nombre pseudo-aleatoire identique chez tous les joueurs (a partir du numero de temps)
local function hasard(n, graine)
    local x = math.sin(n * 12.9898 + (graine or 0) * 78.233) * 43758.5453
    return x - math.floor(x)
end

local function spectacle(c, e)
    local s = scene(c)
    local m = musique(c, e)
    local E = m.energie
    local calme = E < 0.3
    local fort = E >= 0.7
    local enorme = E >= 0.88
    -- instruments (valeurs par defaut sans analyse)
    local kick = m.kick or m.coup
    local sub = m.sub or (fort and 0.7 or 0.3)
    local bass = m.bass or E
    local mid = m.mid or 0.5
    local lead = m.lead or 0.3
    local growl = m.growl or 0.0
    local high = m.high or 0.0
    local punch = kick * (1.0 - (m.phaseCroche or 0)) ^ 2        -- eclat qui retombe sur la croche
    local growlFort = growl >= 0.65 and fort

    -- couleurs : une paire par accord / section, pas a chaque temps
    local c1, c2 = couleur(m.palette * 2), couleur(m.palette * 2 + 1)
    local nbL = #s.lyres

    local veilleDeDrop
    if m.analyse then
        veilleDeDrop = ((lire(m.donnees.energie, (m.mesure + 1) * 4) or 0) / 9.0) - E >= 0.4
    else
        veilleDeDrop = (m.mesure % 8) == 7
    end
    local blinder = m.drop and m.phase < 0.5

    ---------------------------------------------------------------- lyres
    -- figure choisie toutes les 2 mesures parmi 7 (meme choix chez tous les joueurs)
    local motif = math.floor(hasard(m.mesure // 2, m.palette) * 7)
    if lead >= 0.75 and fort then motif = 3 end                   -- grosse lead : ballyhoo vers le ciel
    if growlFort then motif = 7 end                                 -- growl : mouvements erratiques
    local vitesse = 0.4 + 2.2 * E
    for i, p in ipairs(s.lyres) do
        local x = nbL > 1 and ((i - 1) / (nbL - 1) * 2.0 - 1.0) or 0.0
        local cible
        if calme then
            cible = s.public + s.cote * (math.sin(m.t * 0.3) * 16.0 + x * 6.0) + s.avant * 4.0
        elseif motif == 0 then      -- eventail
            cible = s.public + s.cote * (x * (6.0 + 16.0 * math.abs(math.sin(m.t * vitesse * 0.5)))) + s.avant * (x * x * 6.0)
        elseif motif == 1 then      -- croisement
            cible = s.public + s.cote * (-x * 14.0 * math.sin(m.t * vitesse * 0.6)) + s.avant * (math.cos(m.t * vitesse + i) * 5.0)
        elseif motif == 2 then      -- cercles decales
            local a2 = m.t * vitesse + i * 0.45
            cible = s.public + s.cote * (math.cos(a2) * 12.0 + x * 4.0) + s.avant * (math.sin(a2) * 8.0)
        elseif motif == 3 then      -- ballyhoo vers le ciel
            local a2 = m.t * vitesse * 1.3 + i * 0.9
            cible = p + s.avant * 20.0 + s.cote * (math.sin(a2) * 14.0) + vec3(0.0, 0.0, -8.0 + 16.0 * math.abs(math.sin(a2 * 0.5)))
        elseif motif == 4 then      -- vague : chaque lyre plonge a son tour
            local a2 = m.t * vitesse * 1.2 - i * 0.35
            cible = s.public + s.cote * (x * 14.0) + s.avant * (math.sin(a2) * 10.0) + vec3(0.0, 0.0, math.sin(a2) * 3.0)
        elseif motif == 5 then      -- rideau : toutes paralleles, balayage d'un bloc
            cible = p + s.avant * 22.0 + s.cote * (math.sin(m.t * vitesse * 0.5) * 16.0) + vec3(0.0, 0.0, -9.0)
        elseif motif == 6 then      -- convergence au centre qui respire sur le kick
            cible = s.public + s.cote * (x * 10.0 * (1.0 - punch)) + vec3(0.0, 0.0, 3.0 * punch)
        else                        -- growl : saccades aleatoires a chaque croche
            local r1, r2 = hasard(m.croche, i), hasard(m.croche, i + 50)
            cible = s.public + s.cote * ((r1 - 0.5) * 34.0) + s.avant * ((r2 - 0.5) * 16.0) + vec3(0.0, 0.0, (r2 - 0.3) * 10.0)
        end
        local dir = cible - p
        local longueur = #dir
        dir = dir / longueur
        local col = (i % 2 == 0) and c1 or c2
        if blinder then col = { 255, 255, 255 } end
        -- intensite : accords (mid) = nappe, kick = eclat, growl = scintillement
        local scint = growlFort and (hasard(math.floor(m.temps * 8), i) > 0.5 and 1.0 or 0.2) or 1.0
        local lumiere = ((calme and 3.0 or 4.0 + 10.0 * E) + 8.0 * mid + 55.0 * punch * (0.4 + E)) * scint + (blinder and 90.0 or 0.0)
        DrawSpotLight(p.x, p.y, p.z, dir.x, dir.y, dir.z, col[1], col[2], col[3], 80.0, lumiere, 0.0, 6.0 + 7.0 * E, 1.0)
        if Config.Lumieres.faisceaux ~= false then
            local alpha = math.floor(math.min(170, ((calme and 25 or 30 + 60 * E) + 30 * mid + 90 * punch) * scint + (blinder and 120 or 0)))
            faisceau(p, dir, math.min(longueur, 45.0), col, alpha, 0.35 + 0.35 * E)
        end
    end

    ---------------------------------------------------------------- lasers
    if not calme then
        -- la basse ouvre l'eventail, la lead fait monter les lasers, le kick les fait claquer
        local nb = math.floor(3 + 7 * bass + 3 * E)
        local sens = (m.mesure % 2 == 0) and 1.0 or -1.0
        local allume = (punch > 0.08) or (bass > 0.55 and m.phaseCroche < 0.6) or (not m.analyse and m.phase < 0.5)
        local montee = lead * 8.0
        if allume then
            for oi, o in ipairs(s.lasers) do
                local auSol = oi >= 6
                for k = -nb, nb do
                    local angle = k * (0.42 / math.max(1, nb / 2)) + math.sin(m.t * (0.6 + 2.4 * E) * sens + oi) * 0.7
                    local dirH = s.avant * math.cos(angle) + s.cote * math.sin(angle)
                    local hauteur = auSol and (6.0 + montee + math.sin(m.t * 3.0 + k) * 3.0)
                        or (math.sin(m.t * 2.0 + k) * 4.0 - 2.0 + montee * 0.5)
                    local fin = o + dirH * 70.0 + vec3(0.0, 0.0, hauteur)
                    local col = (k % 2 == 0) and c1 or c2
                    DrawLine(o.x, o.y, o.z, fin.x, fin.y, fin.z, col[1], col[2], col[3], 255)
                end
            end
        end
        -- growl : lasers supplementaires vert / rouge qui balayent par saccades depuis toute la rampe
        if growl >= 0.5 and fort then
            for g = 1, 8 do
                local o = s.centreRampe + s.cote * ((g - 4.5) / 3.5 * (Config.Lumieres.largeurRampe or 26.0) / 2) + vec3(0.0, 0.0, 0.3)
                for k = 1, 3 do
                    local r1, r2 = hasard(math.floor(m.temps * 4), g * 10 + k), hasard(math.floor(m.temps * 4), g * 10 + k + 5)
                    local fin = o + s.avant * 60.0 + s.cote * ((r1 - 0.5) * 70.0) + vec3(0.0, 0.0, (r2 - 0.6) * 20.0)
                    local vert = (g + k) % 2 == 0
                    DrawLine(o.x, o.y, o.z, fin.x, fin.y, fin.z, vert and 0 or 255, vert and 255 or 0, vert and 60 or 30, 255)
                end
            end
        end
    end

    ---------------------------------------------------------------- stroboscopes
    local nbS = #s.strobos
    for i, p in ipairs(s.strobos) do
        local flash = false
        if veilleDeDrop then
            local v2 = (m.n % 4 == 3) and 8 or 4
            flash = (m.temps * v2) % 1.0 < 0.3
        elseif enorme then
            flash = (((math.floor(m.temps * 4) % nbS) + 1 == i) and (m.temps * 4) % 1.0 < 0.3) or (kick >= 0.8 and m.phaseCroche < 0.3)
        elseif fort then
            flash = kick >= 0.8 and m.phaseCroche < 0.3 and (i % 2 == m.n % 2)
        end
        -- charley : petites etincelles sur les hi-hats
        local etincelle = (not flash) and high >= 0.7 and m.phaseCroche < 0.2 and hasard(m.croche, i) > 0.6
        if blinder or flash then
            DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 40.0, blinder and 40.0 or 22.0)
        elseif etincelle then
            DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 12.0, 10.0)
        end
    end

    -- sub-bass : lueur au sol qui pulse
    if not calme and sub > 0.4 then
        local g = s.public
        DrawLightWithRange(g.x, g.y, s.sol + 1.0, c1[1], c1[2], c1[3], 25.0, 4.0 + 10.0 * sub * punch)
    end

    ---------------------------------------------------------------- CO2 (vers le public)
    if veilleDeDrop then
        if m.phase < 0.2 then
            local tous = (m.n % 4 == 3)
            local pair = m.n % 2
            unefois(dernierCo2, c.id, 'montee' .. m.n, function() jetsCo2(c, not tous and function(i) return i % 2 == pair end or nil) end)
        end
    elseif not calme then
        if m.drop then
            unefois(dernierCo2, c.id, 'drop' .. m.n, function() jetsCo2(c) end)
        elseif enorme and m.n % 8 == 0 and m.phase < 0.2 then
            unefois(dernierCo2, c.id, 'fort' .. m.n, function() jetsCo2(c) end)
        elseif fort and kick >= 0.9 and m.n % 4 == 2 and m.phase < 0.2 then
            local pair = (m.n // 4) % 2
            unefois(dernierCo2, c.id, 'alt' .. m.n, function() jetsCo2(c, function(i) return i % 2 == pair end) end)
        end
    end

    ---------------------------------------------------------------- lance-flammes (sub-bass, growls, drops + automatique)
    local cfgF = Config.Lumieres.flammes
    if not calme and cfgF then
        local chaque = cfgF.toutesLesMesures or 0
        if m.drop then
            unefois(dernierFlamme, c.id, 'drop' .. m.n, function() lanceFlammes(c) end)
        elseif fort and sub >= 0.85 and m.n % 4 == 0 and m.phase < 0.15 then
            unefois(dernierFlamme, c.id, 'sub' .. m.n, function() lanceFlammes(c) end)
        elseif growlFort and growl >= 0.85 and m.phaseCroche < 0.2 and m.croche % 4 == 0 then
            local cote = (m.croche // 4) % 2
            unefois(dernierFlamme, c.id, 'growl' .. m.croche, function() lanceFlammes(c, function(i) return i % 2 == cote end) end)
        elseif chaque > 0 and m.energie >= 0.6 and m.n % (chaque * 4) == 0 and m.phase < 0.15 then
            -- automatique : sur le 1er temps toutes les X mesures, des que la musique est forte
            unefois(dernierFlamme, c.id, 'auto' .. m.n, function() lanceFlammes(c) end)
        end
    end

    ---------------------------------------------------------------- confettis et feux d'artifice
    if m.drop then
        unefois(dernierFeu, c.id, 'drop' .. m.n, function()
            if c.effets and c.effets.confettis then JouerEffet(c, 'confettis') end
            if c.effets and c.effets.feux then JouerEffet(c, 'feux') end
            if e.fumeeAuto ~= false and c.effets and c.effets.fumee then JouerEffet(c, 'fumee') end
        end)
    elseif enorme and m.n % 64 == 0 and m.phase < 0.2 then
        unefois(dernierFeu, c.id, 'enorme' .. m.n, function()
            if c.effets and c.effets.confettis then JouerEffet(c, 'confettis') end
        end)
    elseif fort and lead >= 0.9 and m.n % 16 == 0 and m.phase < 0.2 then
        unefois(dernierFeu, c.id, 'lead' .. m.n, function()
            if c.effets and c.effets.feux then JouerEffet(c, 'feux') end
        end)
    end

    -- fumee automatique (pas pendant les breaks)
    if e.fumeeAuto ~= false and c.effets and c.effets.fumee and not calme then
        local par = Config.Lumieres.fumeeToutesLesMesures or 8
        local groupe = m.mesure // par
        if m.mesure % par == 0 and dernierTempsFumee[c.id] ~= groupe then
            dernierTempsFumee[c.id] = groupe
            CreateThread(function() JouerEffet(c, 'fumee') end)
        end
    end
    return m
end

-- les lasers du decor (pt-maploader) clignotent sur le tempo
local LASER_DECOR = 1429741918
local laserDecor = {}
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local liste = {}
        for _, o in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(o) == LASER_DECOR and #(GetEntityCoords(o) - pos) < 200.0 then liste[#liste + 1] = o end
        end
        laserDecor = liste
        Wait(3000)
    end
end)

CreateThread(function()
    while true do
        local attente = 500
        local pos = GetEntityCoords(PlayerPedId())
        local actif = false
        for _, c in ipairs(Config.Cabines) do
            local e = etat(c.id)
            if e and e.url and not e.pause and e.lumieres ~= false and evenementAllume(c)
                and #(pos - c.son) < (Config.Lumieres.distance or 150.0) then
                attente = 0
                actif = true
                local m = spectacle(c, e)
                -- lasers du decor : allumes sur les coups, eteints pendant les breaks
                local visible = m.energie >= 0.3 and (m.coup > 0.2 or (not m.analyse and m.phase < 0.5))
                for _, o in ipairs(laserDecor) do
                    if #(GetEntityCoords(o) - c.son) < 150.0 then SetEntityVisible(o, visible, false) end
                end
            end
        end
        if not actif then
            for _, o in ipairs(laserDecor) do
                if DoesEntityExist(o) and not IsEntityVisible(o) then SetEntityVisible(o, true, false) end
            end
        end
        Wait(attente)
    end
end)

RegisterNetEvent('pt-dj:client:co2', function(id, genre)
    for _, x in ipairs(Config.Cabines) do
        if x.id == id then
            if genre == 'flammes' then lanceFlammes(x) else jetsCo2(x) end
            return
        end
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Panneaux LED : une page web (html/led.html) dessine les motifs ; elle est rendue dans une texture du jeu (DUI)
-- et affichee par-dessus les panneaux existants, aux positions placees par les admins (/ecranled).

local dui, duiPret = nil, false
local TXD, TXN = 'pt_dj_led', 'ecran'
local dernierMorceau, dernierEnvoiTemps = nil, 0

local function creerDui()
    if dui then return end
    dui = CreateDui(('https://cfx-nui-%s/html/led.html'):format(GetCurrentResourceName()), 1024, 576)
    local txd = CreateRuntimeTxd(TXD)
    CreateRuntimeTextureFromDuiHandle(txd, TXN, GetDuiHandle(dui))
    duiPret = true
end

local function detruireDui()
    if dui then DestroyDui(dui) end
    dui, duiPret, dernierMorceau = nil, false, nil
end

local function envoyer(msg)
    if dui then SendDuiMessage(dui, json.encode(msg)) end
end

-- coins d'un ecran (vertical, face a sa normale), legerement decolle du panneau
local function coins(ec)
    local n = vec3(ec.nx, ec.ny, ec.nz)
    local p = vec3(ec.x, ec.y, ec.z) + n * 0.05
    local r = vec3(-n.y, n.x, 0.0)
    local lr = #r
    r = lr > 0.01 and (r / lr) or vec3(1.0, 0.0, 0.0)
    local u = vec3(n.y * r.z - n.z * r.y, n.z * r.x - n.x * r.z, n.x * r.y - n.y * r.x)
    local lu = #u
    u = lu > 0.01 and (u / lu) or vec3(0.0, 0.0, 1.0)
    local hw, hh = ec.w / 2, ec.h / 2
    return p - r * hw + u * hh, p + r * hw + u * hh, p - r * hw - u * hh, p + r * hw - u * hh
end

local function tri(a, b, c, ua, va, ub, vb, uc, vc)
    DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, TXD, TXN,
        ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

local function dessinerEcran(ec)
    local hg, hd, bg, bd = coins(ec)
    tri(hg, bg, hd, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0)
    tri(hd, bg, bd, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0)
    -- face arriere (au cas ou le jeu masque une face selon le sens de dessin)
    tri(hg, hd, bg, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    tri(hd, bd, bg, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0)
end

-- la cabine la plus proche dont l'evenement est allume pilote les ecrans
local function cabineProche(pos)
    local meilleure, dmin = nil, 250.0
    for _, c in ipairs(Config.Cabines) do
        local d = #(pos - c.son)
        if evenementAllume(c) and d < dmin then meilleure, dmin = c, d end
    end
    return meilleure
end

CreateThread(function()
    while true do
        local ecrans = GlobalState.pt_dj_ecrans or {}
        local pos = GetEntityCoords(PlayerPedId())
        local proches = {}
        for _, ec in ipairs(ecrans) do
            if #(pos - vec3(ec.x, ec.y, ec.z)) < 200.0 then proches[#proches + 1] = ec end
        end
        local c = #proches > 0 and cabineProche(pos) or nil
        if not c then
            if dui then detruireDui() end
            Wait(1000)
        else
            if not dui then creerDui() Wait(500) end
            local e = etat(c.id)
            -- nouveau morceau ou analyse arrivee : on envoie tout le profil a la page
            local D = e and e.url and donneesDe(c, e) or {}
            local cle = e and e.url and (tostring(e.v) .. ':' .. tostring(e.analyse) .. ':' .. tostring(e.bpm) .. ':' .. tostring(e.ancre) .. ':' .. tostring(D.temps ~= nil)) or 'rien'
            if cle ~= dernierMorceau then
                dernierMorceau = cle
                if e and e.url then
                    envoyer({ type = 'morceau', bpm = e.bpm or Config.BpmDefaut, ancre = e.ancre or 0, energie = D.energie,
                        coups = D.coups, bandes = D.bandes, couleurs = D.couleurs, temps = D.temps, palette = Config.Lumieres.couleurs,
                        texte = Config.TexteEcrans or 'LUSO RP' })
                else
                    envoyer({ type = 'arret' })
                end
            end
            -- position de lecture 10 fois par seconde (la page extrapole entre deux)
            if GetGameTimer() - dernierEnvoiTemps > 100 then
                dernierEnvoiTemps = GetGameTimer()
                if e and e.url then
                    envoyer({ type = 'temps', t = tempsAudio(c, e), joue = not e.pause and e.lumieres ~= false })
                end
            end
            if duiPret then
                for _, ec in ipairs(proches) do dessinerEcran(ec) end
            end
            Wait(0)
        end
    end
end)

-- /ecranled ajouter : vise le panneau, l'ecran se colle a la surface visee
RegisterNetEvent('pt-dj:client:viserEcran', function(w, h)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local fin = cam + dir * 80.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, fin.x, fin.y, fin.z, 1 + 16, PlayerPedId(), 7)
    local _, touche, point, normale = GetShapeTestResult(ray)
    if touche ~= 1 then
        TriggerEvent('QBCore:Notify', 'Vise la surface du panneau LED (a moins de 80 m).', 'error')
        return
    end
    TriggerServerEvent('pt-dj:server:ecranAjouter', { x = point.x, y = point.y, z = point.z,
        nx = normale.x, ny = normale.y, nz = normale.z, w = w, h = h })
end)

AddEventHandler('onResourceStop', function(nom)
    if nom == GetCurrentResourceName() then detruireDui() end
end)

-- /testpyro [co2|flammes] : tire 3 jets (visibles par toi seul) avec 3 orientations pour trouver celle qui monte droit
RegisterCommand('testpyro', function(_, args)
    local genre = (args[1] == 'flammes') and 'flammes' or 'co2'
    local c = cabineProche(GetEntityCoords(PlayerPedId()))
    if not c then return lib.notify({ title = 'DJ', description = 'Aucune scene proche (evenement allume).', type = 'error' }) end
    local s = scene(c)
    local cfg = Config.Lumieres[genre]
    local pts = s[genre]
    local essais = { { pts[1], 0.0 }, { pts[math.max(1, #pts // 2)], 90.0 }, { pts[#pts], -90.0 } }
    for _, e in ipairs(essais) do
        tir(genre .. 'test', cfg, { e[1] }, vec3(e[2], 0.0, s.cap))
    end
    lib.notify({ title = 'Test ' .. genre, type = 'inform', duration = 10000,
        description = 'Gauche = 0 | milieu = 90 | droite = -90. Celui qui monte droit : mets ce chiffre dans config.lua ('
            .. (genre == 'co2' and 'co2.angleTir' or 'flammes.rotation = vec3(X, 0.0, 0.0)') .. ').' })
end, false)
