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
local tempsPrecis

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
        onSelect = function() TriggerServerEvent('pt-dj:server:co2', c.id) ouvrirMenu(c) end,
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
        if IsControlJustPressed(0, 38) then taps[#taps + 1] = { gt = GetGameTimer(), t = tempsPrecis(etat(c.id) or e) } end
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
    local centreRampe = c.son + avant * 2.0 + vec3(0.0, 0.0, L.hauteurRampe or 9.0)
    local function rampe(nb, dz)
        local liste = {}
        local w = L.largeurRampe or 34.0
        for i = 1, nb do
            local x = nb > 1 and (-w / 2 + w * (i - 1) / (nb - 1)) or 0.0
            liste[i] = centreRampe + cote * x + vec3(0.0, 0.0, dz)
        end
        return liste
    end
    local co2 = c.co2
    if not co2 then
        co2 = {}
        for _, p in ipairs(ef.fumee or {}) do co2[#co2 + 1] = p end
        if #co2 == 0 then
            for i = -2, 2 do co2[#co2 + 1] = c.son + avant * 3.0 + cote * (i * 6.0) + vec3(0.0, 0.0, -3.0) end
        end
    end
    local s = {
        lyres = c.lyres or c.projecteurs or rampe(L.lyres or 16, 0.0),
        strobos = c.strobos or rampe(L.strobos or 10, 0.8),
        lasers = c.lasers or { c.son + vec3(0.0, 0.0, 5.0), centreRampe + cote * -10.0, centreRampe + cote * 10.0 },
        co2 = co2,
        avant = avant, cote = cote,
        public = c.public or (c.son + avant * 25.0 + vec3(0.0, 0.0, -3.0)),
    }
    scenes[c.id] = s
    return s
end

-- jets de CO2 (effet du jeu oriente vers le ciel, premier effet disponible)
local effetCo2 = nil
local function jetsCo2(c, quels)
    local s = scene(c)
    local cfg = Config.Lumieres.co2
    if #(GetEntityCoords(PlayerPedId()) - c.son) > 250.0 then return end
    local r = cfg.rotation or vec3(90.0, 0.0, 0.0)
    local boucles = {}
    for i, p in ipairs(s.co2) do
        if not quels or quels(i) then
            local h = 0
            for _, ef in ipairs(effetCo2 and { effetCo2 } or cfg.effets) do
                if chargerDict(ef.dict) then
                    UseParticleFxAsset(ef.dict)
                    h = StartParticleFxLoopedAtCoord(ef.nom, p.x, p.y, p.z, r.x, r.y, r.z, ef.echelle or 2.0, false, false, false, false)
                    if h and h ~= 0 then effetCo2 = ef break end
                end
            end
            if h and h ~= 0 then boucles[#boucles + 1] = h end
        end
    end
    if #boucles > 0 then
        SetTimeout(cfg.duree or 1400, function()
            for _, b in ipairs(boucles) do StopParticleFxLooped(b, false) end
        end)
    end
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
local function musique(c, e)
    local bpm = e.bpm or Config.BpmDefaut
    local t = tempsPrecis(e) - (e.ancre or 0)
    local temps = t * bpm / 60.0
    local n = math.floor(temps)
    local phase = temps - n
    local croche = math.floor(temps * 2)
    local phaseCroche = temps * 2 - croche
    local energie = lire(e.energie, n)
    local coup = lire(e.coups, croche)
    local m = {
        t = t, temps = temps, n = n, phase = phase, mesure = n // 4,
        analyse = energie ~= nil,
        energie = energie and (energie / 9.0) or 0.6,
        -- sans analyse : un coup sur chaque temps
        coup = coup and (coup / 9.0) * (1.0 - phaseCroche) ^ 2 or (1.0 - phase) ^ 2,
        coupFort = coup and coup >= 7 and phaseCroche < 0.35 or false,
        drop = false,
    }
    -- drop : debut de mesure ou l'energie saute fortement par rapport a la mesure precedente
    if m.analyse and n % 4 == 0 then
        local avant = 0
        for k = n - 4, n - 1 do avant = avant + (lire(e.energie, k) or 0) end
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

local dernierCo2 = {}

local function spectacle(c, e)
    local s = scene(c)
    local m = musique(c, e)
    local E = m.energie
    local calme = E < 0.3                       -- break / intro
    local fort = E >= 0.7                       -- drop / refrain
    local enorme = E >= 0.88                    -- le plus fort du morceau
    local c1, c2 = couleur(fort and m.n or m.mesure), couleur((fort and m.n or m.mesure) + 3)
    local motif = m.mesure % 4                  -- figure des lyres, change a chaque mesure
    local nbL = #s.lyres

    -- veille de drop (montee) et drop
    local veilleDeDrop
    if m.analyse then
        veilleDeDrop = ((lire(e.energie, (m.mesure + 1) * 4) or 0) / 9.0) - E >= 0.4
    else
        veilleDeDrop = (m.mesure % 8) == 7
    end

    ---------------------------------------------------------------- lyres
    local vitesse = 0.5 + 2.5 * E
    local blinder = m.drop or (m.analyse and m.n % 4 == 0 and m.phase < 0.12 and enorme)
    for i, p in ipairs(s.lyres) do
        local x = nbL > 1 and ((i - 1) / (nbL - 1) * 2.0 - 1.0) or 0.0   -- -1 (gauche) .. 1 (droite)
        local cible
        if calme then
            -- break : balayage lent et large, tous ensemble
            cible = s.public + s.cote * (math.sin(m.t * 0.35) * 18.0 + x * 6.0) + s.avant * 4.0
        elseif motif == 0 then
            -- eventail qui s'ouvre et se ferme sur le temps
            cible = s.public + s.cote * (x * (6.0 + 16.0 * math.abs(math.sin(m.t * vitesse * 0.5)))) + s.avant * (x * x * 6.0)
        elseif motif == 1 then
            -- croisement : gauche vers la droite et inversement
            cible = s.public + s.cote * (-x * 14.0 * math.sin(m.t * vitesse * 0.6)) + s.avant * (math.cos(m.t * vitesse + i) * 5.0)
        elseif motif == 2 then
            -- cercles decales (chaque lyre en retard sur la voisine)
            local a = m.t * vitesse + i * 0.45
            cible = s.public + s.cote * (math.cos(a) * 12.0 + x * 4.0) + s.avant * (math.sin(a) * 8.0)
        else
            -- ballyhoo : vers le ciel et retour, rapide sur les passages forts
            local a = m.t * vitesse * 1.3 + i * 0.9
            cible = p + s.avant * 20.0 + s.cote * (math.sin(a) * 14.0) + vec3(0.0, 0.0, -8.0 + 14.0 * math.abs(math.sin(a * 0.5)))
        end
        local dir = cible - p
        local longueur = #dir
        dir = dir / longueur
        -- couleur : alternee, ou en chenillard sur les passages forts
        local col = fort and couleur(m.n + i // 2) or ((i % 2 == 0) and c1 or c2)
        if blinder then col = { 255, 255, 255 } end
        -- intensite : base selon l'energie + eclat sur chaque coup ; chenillard en croches sur les passages forts
        local chenillard = fort and ((math.floor(m.temps * 2) % nbL) + 1 == i) and 1.0 or 0.0
        local lumiere = (calme and 3.0 or 5.0 + 14.0 * E) + 55.0 * m.coup * (0.4 + E) + 40.0 * chenillard + (blinder and 90.0 or 0.0)
        DrawSpotLight(p.x, p.y, p.z, dir.x, dir.y, dir.z, col[1], col[2], col[3], 80.0, lumiere, 0.0, 6.0 + 7.0 * E, 1.0)
        if Config.Lumieres.faisceaux ~= false then
            local alpha = math.floor(math.min(160, (calme and 25 or 35 + 70 * E) + 90 * m.coup + 80 * chenillard + (blinder and 120 or 0)))
            faisceau(p, dir, math.min(longueur, 45.0), col, alpha, 0.35 + 0.35 * E)
        end
    end

    ---------------------------------------------------------------- lasers
    if not calme then
        local nb = math.floor(3 + 9 * E)
        local sens = (m.mesure % 2 == 0) and 1.0 or -1.0
        local allume = fort and (m.coup > 0.12 or m.phase < 0.5) or (m.n % 2 == 0) or m.phase < 0.5
        if allume then
            for oi, o in ipairs(s.lasers) do
                for k = -nb, nb do
                    local angle = k * (0.42 / math.max(1, nb / 2)) + math.sin(m.t * (0.8 + 2.6 * E) * sens + oi) * 0.7
                    local dirH = s.avant * math.cos(angle) + s.cote * math.sin(angle)
                    local hauteur = enorme and (math.sin(m.t * 6.0 + k * 0.5) * 6.0) or (math.sin(m.t * 2.0 + k) * 4.0 - 2.0)
                    local fin = o + dirH * 70.0 + vec3(0.0, 0.0, hauteur)
                    local col = (k % 2 == 0) and c1 or c2
                    DrawLine(o.x, o.y, o.z, fin.x, fin.y, fin.z, col[1], col[2], col[3], 255)
                end
            end
        end
    end

    ---------------------------------------------------------------- stroboscopes
    local double = (m.temps * 4) % 1.0 < 0.3        -- en double-croches
    local nbS = #s.strobos
    for i, p in ipairs(s.strobos) do
        local flash = false
        if veilleDeDrop then
            -- montee : tous en double-croches, de plus en plus vite sur la fin de la mesure
            local vitesseMontee = (m.n % 4 == 3) and 8 or 4
            flash = (m.temps * vitesseMontee) % 1.0 < 0.3
        elseif enorme then
            -- le plus fort : chenillard gauche-droite en double-croches + tous sur les gros coups
            flash = ((math.floor(m.temps * 4) % nbS) + 1 == i and double) or m.coupFort
        elseif fort then
            flash = m.coupFort and (i % 2 == m.n % 2)
        end
        if blinder or flash then
            DrawLightWithRange(p.x, p.y, p.z, 255, 255, 255, 40.0, blinder and 40.0 or 22.0)
        end
    end

    ---------------------------------------------------------------- jets de CO2
    if not calme then
        local cle
        if m.drop then
            cle = 'drop' .. m.n
            if dernierCo2[c.id] ~= cle then dernierCo2[c.id] = cle CreateThread(function() jetsCo2(c) end) end
        elseif enorme and m.n % 8 == 0 and m.phase < 0.2 then
            -- toutes les 2 mesures au plus fort : tous les jets
            cle = 'fort' .. m.n
            if dernierCo2[c.id] ~= cle then dernierCo2[c.id] = cle CreateThread(function() jetsCo2(c) end) end
        elseif fort and m.n % 4 == 2 and m.phase < 0.2 then
            -- passages forts : un jet sur deux, en alternance
            cle = 'alt' .. m.n
            local pair = (m.n // 4) % 2
            if dernierCo2[c.id] ~= cle then dernierCo2[c.id] = cle CreateThread(function() jetsCo2(c, function(i) return i % 2 == pair end) end) end
        end
    end

    ---------------------------------------------------------------- drop : confettis, feux d'artifice, fumee
    if m.drop and dernierDrop[c.id] ~= m.n then
        dernierDrop[c.id] = m.n
        CreateThread(function()
            if c.effets and c.effets.confettis then JouerEffet(c, 'confettis') end
            if c.effets and c.effets.feux then JouerEffet(c, 'feux') end
            if e.fumeeAuto ~= false and c.effets and c.effets.fumee then JouerEffet(c, 'fumee') end
        end)
    end

    -- fumee automatique au debut de chaque groupe de N mesures (pas pendant les breaks)
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

RegisterNetEvent('pt-dj:client:co2', function(id)
    for _, x in ipairs(Config.Cabines) do
        if x.id == id then jetsCo2(x) return end
    end
end)
