local QBCore = exports['qb-core']:GetCoreObject()

-- Etat d'une cabine (partage avec tous les joueurs par GlobalState 'pt_dj_<id>') :
--   url, debut (heure serveur du lancement), decalage (secondes deja jouees), pause, volume (0-100),
--   boucle, duree (secondes, donnee par le premier joueur qui charge le morceau), file (urls suivantes), v (numero du morceau)
local etats = {}
local autorises = {}     -- [citizenid] = true (autorisations donnees par /autoriserdj, jusqu'au redemarrage)
local dernierEffet = {}
-- reglages du jeu de lumieres, gardes d'un morceau a l'autre : bpm, ancre (calage du temps), lumieres, fumeeAuto
local reglages = {}
local function reglagesDe(id)
    reglages[id] = reglages[id] or { bpm = Config.BpmDefaut or 128, ancre = 0, lumieres = true, fumeeAuto = true }
    return reglages[id]
end

local function cabine(id)
    for _, c in ipairs(Config.Cabines) do
        if c.id == id then return c end
    end
end

local function evenementAllume(c)
    return not c.evenement or GlobalState['pt_evenement_' .. c.evenement] == true
end

local function estAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
        or IsPlayerAceAllowed(src, 'command')
end

local function peutMixer(src, c)
    if estAdmin(src) then return true end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if autorises[P.PlayerData.citizenid] then return true end
    local acces = c.acces or {}
    if acces.tous then return true end
    if acces.metiers and acces.metiers[P.PlayerData.job.name] then return true end
    return false
end

local function aPortee(src, c)
    return #(GetEntityCoords(GetPlayerPed(src)) - c.coords) < 6.0
end

local function publier(id)
    GlobalState['pt_dj_' .. id] = etats[id]
end

local function maintenant()
    return os.time()
end

local function ecoule(e)
    if e.pause then return e.decalage end
    return e.decalage + (maintenant() - e.debut)
end

-- MP3 poses dans pt-dj/musique/ : on tape juste le nom du fichier (ex. monset.mp3)
local DOSSIER_MP3 = GetResourcePath(GetCurrentResourceName()) .. '/musique/'
local function nomMp3(nom)
    return type(nom) == 'string' and #nom < 120 and not nom:find('[/\\]') and not nom:find('%.%.')
        and nom:lower():match('%.mp3$') ~= nil
end
local function mp3Existe(nom)
    local f = io.open(DOSSIER_MP3 .. nom, 'rb')
    if f then f:close() return true end
    return false
end

local function urlValide(url)
    if type(url) ~= 'string' or #url >= 400 then return false end
    if url:match('^https?://') then return true end
    return nomMp3(url) and mp3Existe(url)
end

-- liste des MP3 du dossier musique (menu de la table de mixage)
lib.callback.register('pt-dj:listeMp3', function()
    local liste = {}
    local ok, p = pcall(io.popen, ('ls -1 "%s" 2>/dev/null || dir /b "%s" 2>nul'):format(DOSSIER_MP3, DOSSIER_MP3:gsub('/', '\\')))
    if ok and p then
        for brut in p:lines() do
            local ligne = brut:gsub('\r$', '')
            if nomMp3(ligne) then liste[#liste + 1] = ligne end
        end
        p:close()
    end
    table.sort(liste, function(a, b) return a:lower() < b:lower() end)
    return liste
end)

-- analyse du tempo (analyse.js) : resultat garde par lien pour ne pas re-analyser un morceau deja joue
local analyses = {}
local function analyserMorceau(id, e)
    local deja = analyses[e.url]
    if deja then
        e.bpm, e.ancre, e.analyse, e.coups, e.energie, e.bandes, e.couleurs = deja.bpm, deja.ancre, 'ok', deja.coups, deja.energie, deja.bandes, deja.couleurs
        return
    end
    e.analyse = 'encours'
    local v, url = e.v, e.url
    if not url:match('^https?://') then url = DOSSIER_MP3 .. url end   -- MP3 local : chemin du fichier
    local encode = url:gsub('[^%w%-_%.~]', function(ch) return ('%%%02X'):format(ch:byte()) end)
    -- service d'analyse a cote du serveur (tools/dj-analyse) : FXServer interdit de lancer ffmpeg depuis une ressource
    PerformHttpRequest((Config.AnalyseAdresse or 'http://127.0.0.1:30125') .. '/analyse?url=' .. encode, function(code, corps)
        local ok, r = pcall(json.decode, corps or '')
        if code == 200 and ok and type(r) == 'table' and r.bpm then
            TriggerEvent('pt-dj:analyseFaite', id, v, r.bpm, r.ancre, r.confiance, nil, r.coups, r.energie, r.bandes, r.couleurs)
        else
            local raison = (ok and type(r) == 'table' and r.erreur) or (code == 0 and 'service d\'analyse injoignable (tools/dj-analyse lance ?)') or ('code ' .. tostring(code))
            TriggerEvent('pt-dj:analyseFaite', id, v, nil, nil, 0, raison)
        end
    end, 'GET', '', {}, { timeout = 180000 })
end

local function lancer(id, url, garder)
    local e = etats[id] or { volume = Config.VolumeDefaut, boucle = false, file = {}, v = 0 }
    e.url, e.debut, e.decalage, e.pause, e.duree = url, maintenant(), 0, false, nil
    e.v = (e.v or 0) + 1
    if not garder then e.file = e.file or {} end
    local r = reglagesDe(id)
    e.bpm, e.ancre, e.lumieres, e.fumeeAuto = r.bpm, 0, r.lumieres, r.fumeeAuto
    e.bpmManuel, e.coups, e.energie, e.bandes, e.couleurs = nil, nil, nil, nil, nil
    if Config.AnalyseTempo ~= false then analyserMorceau(id, e) end
    etats[id] = e
    publier(id)
end

local function suivant(id)
    local e = etats[id]
    if not e then return end
    if e.file and #e.file > 0 then
        lancer(id, table.remove(e.file, 1), true)
    else
        etats[id] = nil
        publier(id)
    end
end

local function notifier(src, texte, genre)
    TriggerClientEvent('QBCore:Notify', src, texte, genre or 'primary')
end

-- Controle d'acces commun a toutes les actions
local function verifier(src, id)
    local c = cabine(id)
    if not c then return nil end
    if not evenementAllume(c) then
        notifier(src, 'La scene est fermee (evenement eteint).', 'error')
        return nil
    end
    if not aPortee(src, c) or not peutMixer(src, c) then
        notifier(src, 'Vous n\'avez pas acces a cette table de mixage.', 'error')
        return nil
    end
    return c
end

-- heure du serveur, pour que chaque joueur reprenne le morceau au bon moment
lib.callback.register('pt-dj:heure', function()
    return maintenant()
end)

lib.callback.register('pt-dj:peutMixer', function(src, id)
    local c = cabine(id)
    return c and evenementAllume(c) and peutMixer(src, c) or false
end)

RegisterNetEvent('pt-dj:server:jouer', function(id, url, ajouter)
    local src = source
    if not verifier(src, id) then return end
    if not urlValide(url) then return notifier(src, 'Lien invalide : https://... ou nom d\'un MP3 du dossier pt-dj/musique (ex. monset.mp3).', 'error') end
    local e = etats[id]
    if ajouter and e and e.url then
        e.file = e.file or {}
        if #e.file >= 20 then return notifier(src, 'File d\'attente pleine (20 morceaux).', 'error') end
        e.file[#e.file + 1] = url
        publier(id)
        notifier(src, ('Ajoute a la file (%d en attente).'):format(#e.file), 'success')
    else
        lancer(id, url, true)
        notifier(src, 'Morceau lance.', 'success')
    end
end)

RegisterNetEvent('pt-dj:server:commande', function(id, action, valeur)
    local src = source
    if not verifier(src, id) then return end
    local e = etats[id]
    if action == 'stop' then
        etats[id] = nil
        publier(id)
        return
    end
    if not e then return end
    if action == 'pause' and not e.pause then
        e.decalage, e.pause = ecoule(e), true
    elseif action == 'reprendre' and e.pause then
        e.debut, e.pause = maintenant(), false
    elseif action == 'volume' then
        e.volume = math.max(0, math.min(100, math.floor(tonumber(valeur) or e.volume)))
    elseif action == 'boucle' then
        e.boucle = not e.boucle
    elseif action == 'passer' then
        return suivant(id)
    elseif action == 'viderfile' then
        e.file = {}
    elseif action == 'bpm' then
        -- valeur = { bpm, ancre } : ancre = position (s) d'un temps fort dans le morceau, donnee par le tap tempo
        local bpm = tonumber(type(valeur) == 'table' and valeur[1] or valeur)
        if not bpm or bpm < 60 or bpm > 200 then return end
        local r = reglagesDe(id)
        r.bpm = math.floor(bpm * 10 + 0.5) / 10
        e.bpm = r.bpm
        e.ancre = type(valeur) == 'table' and tonumber(valeur[2]) or e.ancre or 0
        e.bpmManuel = true
        e.coups, e.energie, e.bandes, e.couleurs = nil, nil, nil, nil
    elseif action == 'reanalyser' then
        analyses[e.url] = nil
        e.bpmManuel = nil
        analyserMorceau(id, e)
    elseif action == 'lumieres' then
        local r = reglagesDe(id)
        r.lumieres = not r.lumieres
        e.lumieres = r.lumieres
    elseif action == 'fumeeauto' then
        local r = reglagesDe(id)
        r.fumeeAuto = not r.fumeeAuto
        e.fumeeAuto = r.fumeeAuto
    else
        return
    end
    publier(id)
end)

-- Le premier joueur qui charge le morceau donne sa duree (pour enchainer la file d'attente)
RegisterNetEvent('pt-dj:server:duree', function(id, v, duree)
    local e = etats[id]
    duree = tonumber(duree)
    if e and e.v == v and not e.duree and duree and duree > 0 and duree < 6 * 3600 then
        e.duree = duree
        publier(id)
    end
end)

-- resultat de l'analyse (analyse.js)
AddEventHandler('pt-dj:analyseFaite', function(id, v, bpm, ancre, confiance, erreur, coups, energie, bandes, couleurs)
    local e = etats[id]
    bpm, ancre = tonumber(bpm), tonumber(ancre)
    if type(coups) ~= 'string' then coups = nil end
    if type(energie) ~= 'string' then energie = nil end
    if type(bandes) ~= 'table' then bandes = nil end
    if type(couleurs) ~= 'string' then couleurs = nil end
    if bpm and e and e.url and e.v == v then
        analyses[e.url] = { bpm = bpm, ancre = ancre, coups = coups, energie = energie, bandes = bandes, couleurs = couleurs }
    end
    if not e or e.v ~= v then return end
    if not bpm then
        e.analyse = 'echec'
        print(('^3[pt-dj] analyse du tempo impossible (%s) : %s^7'):format(tostring(erreur), tostring(e.url)))
    elseif not e.bpmManuel then
        e.bpm, e.ancre, e.analyse, e.coups, e.energie, e.bandes, e.couleurs = bpm, ancre or 0, 'ok', coups, energie, bandes, couleurs
    end
    publier(id)
end)

-- jets de CO2 a la demande du DJ
RegisterNetEvent('pt-dj:server:co2', function(id, genre)
    local src = source
    local c = verifier(src, id)
    if not c then return end
    genre = genre == 'flammes' and 'flammes' or 'co2'
    local cle = id .. genre
    if dernierEffet[cle] and os.time() - dernierEffet[cle] < 2 then return end
    dernierEffet[cle] = os.time()
    TriggerClientEvent('pt-dj:client:co2', -1, id, genre)
end)

RegisterNetEvent('pt-dj:server:effet', function(id, effet)
    local src = source
    local c = verifier(src, id)
    if not c or not Config.Effets[effet] or not (c.effets and c.effets[effet]) then return end
    local cle = id .. effet
    if dernierEffet[cle] and os.time() - dernierEffet[cle] < Config.DelaiEffets then return end
    dernierEffet[cle] = os.time()
    TriggerClientEvent('pt-dj:client:effet', -1, id, effet)
end)

-- Fin de morceau : boucle, morceau suivant de la file, ou arret ; arret aussi quand l'evenement est eteint
CreateThread(function()
    while true do
        Wait(1000)
        for _, c in ipairs(Config.Cabines) do
            local e = etats[c.id]
            if e then
                if not evenementAllume(c) then
                    etats[c.id] = nil
                    publier(c.id)
                elseif not e.pause and e.duree and ecoule(e) >= e.duree + 1 then
                    if e.boucle then
                        e.debut, e.decalage, e.v = maintenant(), 0, e.v + 1
                        publier(c.id)
                    else
                        suivant(c.id)
                    end
                end
            end
        end
    end
end)

-- /autoriserdj [id] et /retirerdj [id] : donner ou retirer l'acces aux tables de mixage a un joueur (DJ invite)
local function commandeAcces(src, args, donner)
    if src ~= 0 and not estAdmin(src) then return end
    local cible = QBCore.Functions.GetPlayer(tonumber(args[1] or ''))
    if not cible then
        if src ~= 0 then notifier(src, 'Joueur introuvable.', 'error') end
        return
    end
    autorises[cible.PlayerData.citizenid] = donner or nil
    local nom = cible.PlayerData.charinfo.firstname .. ' ' .. cible.PlayerData.charinfo.lastname
    if src ~= 0 then notifier(src, (donner and '%s peut maintenant mixer.' or '%s ne peut plus mixer.'):format(nom), 'success') end
    notifier(cible.PlayerData.source, donner and 'Vous etes DJ : allez a une table de mixage et appuyez sur E.'
        or 'Votre acces DJ a ete retire.')
end

RegisterCommand('autoriserdj', function(src, args) commandeAcces(src, args, true) end, false)
RegisterCommand('retirerdj', function(src, args) commandeAcces(src, args, false) end, false)

---------------------------------------------------------------- panneaux LED (ecrans places par les admins)
-- /ecranled ajouter [largeur] [hauteur] : vise le panneau existant (le motif s'affiche par-dessus)
-- /ecranled retirer : retire l'ecran le plus proche ; /ecranled liste
local ecrans = json.decode(GetResourceKvpString('pt_dj_ecrans') or '[]') or {}
local function publierEcrans()
    SetResourceKvp('pt_dj_ecrans', json.encode(ecrans))
    GlobalState.pt_dj_ecrans = ecrans
end
GlobalState.pt_dj_ecrans = ecrans

RegisterCommand('ecranled', function(src, args)
    if src == 0 or not estAdmin(src) then return end
    local action = args[1] or ''
    if action == 'ajouter' then
        TriggerClientEvent('pt-dj:client:viserEcran', src, tonumber(args[2]) or 8.0, tonumber(args[3]) or 4.5)
    elseif action == 'retirer' then
        local pos = GetEntityCoords(GetPlayerPed(src))
        local idx, dmin = nil, 25.0
        for i, e in ipairs(ecrans) do
            local d = #(pos - vector3(e.x, e.y, e.z))
            if d < dmin then idx, dmin = i, d end
        end
        if not idx then return notifier(src, 'Aucun ecran a moins de 25 m.', 'error') end
        table.remove(ecrans, idx)
        publierEcrans()
        notifier(src, 'Ecran retire.', 'success')
    elseif action == 'liste' then
        notifier(src, ('%d ecran(s) LED place(s).'):format(#ecrans))
    else
        notifier(src, '/ecranled ajouter [largeur] [hauteur] | retirer | liste')
    end
end, false)

RegisterNetEvent('pt-dj:server:ecranAjouter', function(d)
    local src = source
    if not estAdmin(src) or type(d) ~= 'table' then return end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    local nx, ny, nz = tonumber(d.nx), tonumber(d.ny), tonumber(d.nz)
    if not (x and y and z and nx and ny and nz) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z)) > 80.0 then return end
    ecrans[#ecrans + 1] = { x = x, y = y, z = z, nx = nx, ny = ny, nz = nz,
        w = math.max(0.5, math.min(40.0, tonumber(d.w) or 8.0)), h = math.max(0.5, math.min(25.0, tonumber(d.h) or 4.5)) }
    publierEcrans()
    notifier(src, ('Ecran LED ajoute (%d au total).'):format(#ecrans), 'success')
end)
