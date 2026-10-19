local QBCore = exports['qb-core']:GetCoreObject()
local CENTRE = vector3(1120.0, 240.0, -50.0)
local props = {}       -- [cle] = objet pose par le script (false = table deja presente dans le casino)
local tables = {}      -- [cle] = entite de la table (posee ou deja presente)
local croupiers = {}   -- [cle] = PNJ croupier
local occupe = false

local function etat() return GlobalState.pt_casino or {} end

local function texteAide(t)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(t)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- champs de mise : montant libre (pas de maximum si Config.MiseMax = 0) + case "Tout miser"
local function maxMise() return (Config.MiseMax or 0) > 0 and Config.MiseMax or nil end
local function champsMise(n, label)
    return {
        { type = 'number', label = (label or 'Mise') .. (' (vous avez %d jetons)'):format(n), min = Config.MiseMin, max = maxMise(),
          default = math.max(Config.MiseMin, math.min(100, n > 0 and n or 100)) },
        { type = 'checkbox', label = ('Tout miser (all in : %d jetons)'):format(maxMise() and math.min(n, maxMise()) or n) },
    }
end
local function lireMise(n, montant, tout)
    if tout then return maxMise() and math.min(n, maxMise()) or n end
    return tonumber(montant)
end

local function demanderMise(titre, label)
    local n = lib.callback.await('pt-casino:jetons', false) or 0
    local r = lib.inputDialog(titre, champsMise(n, label))
    return r and lireMise(n, r[1], r[2])
end

local function chargerAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local fin = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < fin do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- menu qui attend le choix du joueur (renvoie la valeur de l'option choisie)
local function choisir(id, titre, options)
    local p = promise.new()
    local opts = {}
    for _, o in ipairs(options) do
        local v = o.valeur
        opts[#opts + 1] = { title = o.titre, description = o.description, icon = o.icone, readOnly = o.info,
            onSelect = (not o.info) and function() p:resolve(v) end or nil }
    end
    lib.registerContext({ id = id, title = titre, canClose = false, options = opts })
    lib.showContext(id)
    return Citizen.Await(p)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Croupiers, chaises et camera

local ANIMS_CROUPIER = {
    blackjack = { dict = 'anim_casino_b@amb@casino@games@blackjack@dealer', idle = 'idle',
                  distribuer = 'deal_card_player_01', retourner = 'check_and_turn_card', ramasser = 'retrieve_cards_player_01' },
    roulette  = { dict = 'anim_casino_b@amb@casino@games@roulette@dealer', idle = 'idle',
                  lancer = 'spin_wheel', fin = 'no_more_bets', ramasser = 'clear_chips_zone1' },
    poker     = { dict = 'anim_casino_b@amb@casino@games@threecardpoker@dealer', idle = 'idle',
                  distribuer = 'deck_deal_player_01', retourner = 'reveal_hand', ramasser = 'retrieve_cards_player_01' },
}

local function animCroupier(cle, action)
    local ped = croupiers[cle]
    if not ped or not DoesEntityExist(ped) then return end
    local typ = cle:match('^(%a+)_')
    local a = ANIMS_CROUPIER[typ]
    if not a or not a[action] or not chargerAnim(a.dict) then return end
    TaskPlayAnim(ped, a.dict, a[action], 3.0, 3.0, -1, 0, 0, false, false, false)
    -- retour a l'attente apres l'action
    SetTimeout(3500, function()
        if DoesEntityExist(ped) and a.idle then TaskPlayAnim(ped, a.dict, a.idle, 3.0, 3.0, -1, 1, 0, false, false, false) end
    end)
end

RegisterNetEvent('pt-casino:anim', function(cle, action) animCroupier(cle, action) end)

local function annoncerAnim(cle, action)
    if cle then TriggerServerEvent('pt-casino:anim', cle, action) end
end

local function creerCroupier(cle, j, ent)
    if not Config.Croupier.actif or not ANIMS_CROUPIER[j.type] or croupiers[cle] then return end
    local modele = joaat(Config.Croupier.modeles[math.random(#Config.Croupier.modeles)])
    if not lib.requestModel(modele, 5000) then return end
    local d = Config.Croupier.decalage
    local pos = ent and GetOffsetFromEntityInWorldCoords(ent, d.x, d.y, d.z) or vector3(j.coords.x, j.coords.y, j.coords.z)
    local cap = ((j.coords.w or 0.0) + 180.0) % 360.0
    local ped = CreatePed(4, modele, pos.x, pos.y, pos.z, cap, false, false)
    SetModelAsNoLongerNeeded(modele)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    SetPedDefaultComponentVariation(ped)
    croupiers[cle] = ped
    local a = ANIMS_CROUPIER[j.type]
    if chargerAnim(a.dict) then TaskPlayAnim(ped, a.dict, a.idle, 3.0, 3.0, -1, 1, 0, false, false, false) end
end

local assis = nil   -- { cam }
local function sAsseoir(cle)
    local ent = tables[cle]
    if not ent or not DoesEntityExist(ent) then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local centre = GetEntityCoords(ent)
    local chaise, dmin = nil, 99.0
    for i = 1, 4 do
        local os_ = GetEntityBoneIndexByName(ent, ('Chair_Base_0%d'):format(i))
        if os_ ~= -1 then
            local p = GetWorldPositionOfEntityBone(ent, os_)
            local d = #(p - pos)
            if d < dmin then chaise, dmin = p, d end
        end
    end
    assis = {}
    if chaise and Config.Croupier.s_asseoir then
        local cap = GetHeadingFromVector_2d(centre.x - chaise.x, centre.y - chaise.y)
        TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER', chaise.x, chaise.y, chaise.z + 0.5, cap, 0, true, true)
    end
    if Config.Croupier.camera then
        local depuis = chaise or pos
        local dir = vector3(depuis.x - centre.x, depuis.y - centre.y, 0.0)
        local l = #dir
        dir = l > 0.01 and dir / l or vector3(0.0, -1.0, 0.0)
        local c = depuis + dir * 0.9 + vector3(0.0, 0.0, 1.55)
        local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, 0.0, 55.0, false, 0)
        PointCamAtCoord(cam, centre.x, centre.y, centre.z + 0.85)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 900, true, false)
        assis.cam = cam
    end
end

local function seLever()
    if not assis then return end
    if assis.cam then
        RenderScriptCams(false, true, 700, true, false)
        DestroyCam(assis.cam, false)
    end
    ClearPedTasks(PlayerPedId())
    assis = nil
end

-- ---------------------------------------------------------------------------------------------------------------
-- Entree / sortie / caisse

local function teleporter(p)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), p.w or 0.0)
    Wait(800)
    DoScreenFadeIn(500)
end

local function caisse()
    local n = lib.callback.await('pt-casino:jetons', false) or 0
    lib.registerContext({
        id = 'pt_casino_caisse',
        title = ('Caisse du casino (%d jetons)'):format(n),
        options = {
            { title = 'Acheter des jetons', description = ('1 jeton = $%d (liquide, sinon banque)'):format(Config.PrixJeton), icon = 'coins',
              onSelect = function()
                  local r = lib.inputDialog('Acheter des jetons', { { type = 'number', label = 'Nombre de jetons', min = 1, required = true } })
                  if r and r[1] then TriggerServerEvent('pt-casino:acheter', r[1]) end
              end },
            { title = 'Revendre des jetons', description = 'Contre du liquide, au meme prix', icon = 'money-bill',
              onSelect = function()
                  local r = lib.inputDialog('Revendre des jetons', { { type = 'number', label = ('Nombre (max %d)'):format(n), min = 1, max = math.max(n, 1), default = n, required = true } })
                  if r and r[1] then TriggerServerEvent('pt-casino:revendre', r[1]) end
              end },
        },
    })
    lib.showContext('pt_casino_caisse')
end

-- ---------------------------------------------------------------------------------------------------------------
-- Jeux

local function machine()
    local mise = demanderMise('Machine a sous')
    if not mise then return end
    local ped = PlayerPedId()
    local dict = 'anim_casino_a@amb@casino@games@slots@male'
    if chargerAnim(dict) then TaskPlayAnim(ped, dict, 'pull_spin_a', 3.0, 3.0, 2200, 0, 0, false, false, false) end
    PlaySoundFrontend(-1, 'SPINNING', 'dlc_vw_casino_slot_machine_ak_player_sounds', true)
    lib.progressCircle({ duration = 2200, label = 'Les rouleaux tournent...', position = 'bottom', canCancel = false, disable = { move = true, combat = true } })
    local r = lib.callback.await('pt-casino:machine', false, mise)
    if not r then return end
    local ligne = ('[ %s | %s | %s ]'):format(r.symboles[1], r.symboles[2], r.symboles[3])
    if r.gain > 0 then
        PlaySoundFrontend(-1, 'WIN', 'dlc_vw_casino_slot_machine_ak_player_sounds', true)
        lib.notify({ title = ligne, description = ('Gagne : %d jetons'):format(r.gain), type = 'success', duration = 6000 })
    else
        lib.notify({ title = ligne, description = ('Perdu (%d jetons)'):format(r.mise), type = 'error', duration = 5000 })
    end
end

local function roulette(cle)
    local jetonsRoulette = lib.callback.await('pt-casino:jetons', false) or 0
    local r = lib.inputDialog('Roulette', {
        { type = 'select', label = 'Pari', required = true, default = 'rouge', options = {
            { value = 'rouge', label = 'Rouge (x2)' }, { value = 'noir', label = 'Noir (x2)' },
            { value = 'pair', label = 'Pair (x2)' }, { value = 'impair', label = 'Impair (x2)' },
            { value = 'manque', label = '1 a 18 (x2)' }, { value = 'passe', label = '19 a 36 (x2)' },
            { value = 'douzaine', label = 'Douzaine 1, 2 ou 3 (x3)' }, { value = 'numero', label = 'Numero plein 0 a 36 (x36)' } } },
        { type = 'number', label = 'Numero (0-36) ou douzaine (1-3), si besoin', min = 0, max = 36 },
        table.unpack(champsMise(jetonsRoulette)),
    })
    if not r then return end
    local mise = lireMise(jetonsRoulette, r[3], r[4])
    annoncerAnim(cle, 'lancer')
    lib.progressCircle({ duration = 4500, label = 'La bille tourne... Rien ne va plus !', position = 'bottom', canCancel = false, disable = { move = true, combat = true } })
    local res = lib.callback.await('pt-casino:roulette', false, r[1], r[2], mise)
    if not res then return end
    annoncerAnim(cle, 'ramasser')
    local titre = ('Le %d %s'):format(res.numero, res.couleur)
    if res.gain > 0 then
        lib.notify({ title = titre, description = ('Gagne : %d jetons'):format(res.gain), type = 'success', duration = 6000 })
    else
        lib.notify({ title = titre, description = ('Perdu (%d jetons)'):format(res.mise), type = 'error', duration = 5000 })
    end
end

local RESULTATS = { blackjack = 'Blackjack ! ', gagne = 'Gagne ! ', egalite = 'Egalite, mise rendue. ', perdu = 'Perdu. ' }

local function blackjack(cle)
    local mise = demanderMise('Blackjack')
    if not mise then return end
    annoncerAnim(cle, 'distribuer')
    local v = lib.callback.await('pt-casino:bj_debut', false, mise)
    while v and not v.fin do
        local options = {
            { titre = ('Vous : %d'):format(v.totalJoueur), description = v.joueur, icone = 'user', info = true },
            { titre = 'Croupier', description = v.croupier, icone = 'user-tie', info = true },
            { titre = 'Tirer une carte', icone = 'plus', valeur = 'tirer' },
            { titre = 'Rester', icone = 'hand', valeur = 'rester' },
        }
        if v.peutDoubler then
            options[#options + 1] = { titre = ('Doubler (+%d jetons, une seule carte)'):format(v.mise), icone = 'angles-up', valeur = 'doubler' }
        end
        local action = choisir('pt_casino_bj', ('Blackjack - mise %d'):format(v.mise), options)
        annoncerAnim(cle, action == 'tirer' and 'distribuer' or 'retourner')
        v = lib.callback.await('pt-casino:bj_action', false, action)
    end
    if not v then return end
    Wait(600)
    annoncerAnim(cle, 'ramasser')
    local desc = ('Vous : %s (%d)\nCroupier : %s (%d)'):format(v.joueur, v.totalJoueur, v.croupier, v.totalCroupier)
    lib.alertDialog({ header = (RESULTATS[v.resultat] or '') .. (v.gain > 0 and ('+%d jetons'):format(v.gain) or ''), content = desc, centered = true })
end

local RES_POKER = {
    couche = 'Couche. Ante perdu.', non_qualifie = 'Le croupier ne se qualifie pas : ante paye !',
    gagne = 'Gagne !', egalite = 'Egalite, mises rendues.', perdu = 'Perdu.',
}

local function poker(cle)
    local ante = demanderMise('Three Card Poker', 'Ante')
    if not ante then return end
    annoncerAnim(cle, 'distribuer')
    local d = lib.callback.await('pt-casino:poker_debut', false, ante)
    if not d then return end
    local jouer = choisir('pt_casino_poker', ('Three Card Poker - ante %d'):format(d.ante), {
        { titre = ('Vos cartes : %s'):format(d.main), description = d.joueur, icone = 'user', info = true },
        { titre = ('Jouer (+%d jetons)'):format(d.ante), description = 'Le croupier doit avoir une Dame haute ou mieux pour se qualifier', icone = 'check', valeur = true },
        { titre = 'Se coucher', description = 'Vous perdez l\'ante', icone = 'xmark', valeur = false },
    })
    annoncerAnim(cle, 'retourner')
    local r = lib.callback.await('pt-casino:poker_action', false, jouer)
    if not r then return end
    Wait(800)
    annoncerAnim(cle, 'ramasser')
    local desc = ('Vous : %s (%s)\nCroupier : %s (%s)'):format(r.joueur, r.mainJ, r.croupier, r.mainC)
    if r.bonus and r.bonus > 0 then desc = desc .. ('\nBonus d\'ante : +%d jetons'):format(r.bonus) end
    lib.alertDialog({ header = (RES_POKER[r.resultat] or '') .. (r.gain > 0 and (' +%d jetons'):format(r.gain) or ''), content = desc, centered = true })
end

-- Courses : la course s'affiche a l'ecran, le classement final est celui tire par le serveur
local function afficherCourse(r)
    local n = #Config.Chevaux
    local rang = {}
    for pos, i in ipairs(r.ordre) do rang[i] = pos end
    local alea = {}
    for i = 1, n do alea[i] = { math.random() * 6.28, 0.6 + math.random() * 0.8 } end
    local duree = Config.DureeCourse * 1000
    local debut = GetGameTimer()
    PlaySoundFrontend(-1, 'race_start', 'dlc_vw_casino_inside_track_sounds', true)
    while GetGameTimer() - debut < duree + 3000 do
        local t = math.min(1.0, (GetGameTimer() - debut) / duree)
        DrawRect(0.5, 0.5, 0.52, 0.06 + n * 0.05, 0, 0, 0, 190)
        SetTextFont(4) SetTextScale(0.5, 0.5) SetTextColour(255, 210, 80, 255) SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(t < 1.0 and 'INSIDE TRACK' or ('Vainqueur : ' .. Config.Chevaux[r.ordre[1]].nom))
        EndTextCommandDisplayText(0.5, 0.5 - (n * 0.05) / 2 - 0.03)
        for i = 1, n do
            -- arrivee : le 1er a 100 %, les suivants un peu derriere ; pendant la course, ca bouge
            local final = 1.0 - (rang[i] - 1) * 0.045
            local agite = (1.0 - t) * 0.08 * math.sin(alea[i][1] + t * 9.0 * alea[i][2])
            local avance = math.max(0.0, math.min(1.0, final * (t ^ 0.9) + agite * t))
            local y = 0.5 - (n * 0.05) / 2 + (i - 0.5) * 0.05 + 0.01
            DrawRect(0.5 + 0.03, y, 0.40, 0.03, 60, 60, 60, 200)
            local c = i == r.cheval and { 255, 200, 40 } or { 120, 200, 255 }
            DrawRect(0.33 + 0.40 * avance / 2, y, 0.40 * avance, 0.03, c[1], c[2], c[3], 230)
            SetTextFont(4) SetTextScale(0.36, 0.36) SetTextColour(255, 255, 255, 255)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('%d. %s (x%d)'):format(i, Config.Chevaux[i].nom, Config.Chevaux[i].cote))
            EndTextCommandDisplayText(0.245, y - 0.014)
        end
        Wait(0)
    end
    if r.gain > 0 then
        lib.notify({ title = 'Inside Track', description = ('Votre cheval gagne ! +%d jetons'):format(r.gain), type = 'success', duration = 7000 })
    else
        lib.notify({ title = 'Inside Track', description = ('%s gagne. Perdu (%d jetons)'):format(Config.Chevaux[r.ordre[1]].nom, r.mise), type = 'error', duration = 6000 })
    end
end

local function courses()
    local opts = {}
    for i, c in ipairs(Config.Chevaux) do opts[#opts + 1] = { value = i, label = ('%d. %s (x%d)'):format(i, c.nom, c.cote) } end
    local n = lib.callback.await('pt-casino:jetons', false) or 0
    local r = lib.inputDialog('Inside Track - courses de chevaux', {
        { type = 'select', label = 'Cheval', options = opts, required = true, default = 1 },
        table.unpack(champsMise(n)),
    })
    if not r then return end
    local res = lib.callback.await('pt-casino:courses', false, r[1], lireMise(n, r[2], r[3]))
    if res then afficherCourse(res) end
end

local JEUX = {
    machine   = { texte = 'Jouer a la machine a sous', f = machine },
    roulette  = { texte = 'Jouer a la roulette', f = roulette, table = true },
    blackjack = { texte = 'Jouer au blackjack', f = blackjack, table = true },
    poker     = { texte = 'Jouer au Three Card Poker', f = poker, table = true },
    courses   = { texte = 'Parier sur les courses (Inside Track)', f = courses },
}

local function cle(j) return ('%s_%.1f_%.1f'):format(j.type, j.coords.x, j.coords.y) end

local function lancerJeu(j)
    if occupe then return end
    occupe = true
    local k = cle(j)
    local jeu = JEUX[j.type]
    if jeu.table then sAsseoir(k) end
    local ok, err = pcall(jeu.f, k)
    if not ok then print('[pt-casino] ' .. tostring(err)) end
    if jeu.table then seLever() end
    occupe = false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Tables posees si le casino n'en a pas deja a cet endroit

local function poserTables(jeux)
    local voulues = {}
    for _, j in ipairs(jeux or {}) do
        local k = cle(j)
        voulues[k] = true
        local modele = Config.Modeles[j.type]
        if props[k] == nil and modele then
            local h = joaat(modele)
            local existant = GetClosestObjectOfType(j.coords.x, j.coords.y, j.coords.z, 2.0, h, false, false, false)
            if existant ~= 0 then
                props[k] = false
                tables[k] = existant
            else
                lib.requestModel(h, 5000)
                local o = CreateObjectNoOffset(h, j.coords.x, j.coords.y, j.coords.z, false, false, false)
                SetEntityHeading(o, j.coords.w or 0.0)
                FreezeEntityPosition(o, true)
                SetModelAsNoLongerNeeded(h)
                props[k] = o
                tables[k] = o
            end
            creerCroupier(k, j, tables[k])
        end
    end
    for k, o in pairs(props) do
        if not voulues[k] then
            if o and DoesEntityExist(o) then DeleteEntity(o) end
            if croupiers[k] and DoesEntityExist(croupiers[k]) then DeleteEntity(croupiers[k]) end
            props[k], tables[k], croupiers[k] = nil, nil, nil
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Roue de la fortune et voiture du podium

local roue, socle, podium, roueCree = nil, nil, nil, false
local roueTourne = false

local function poserRoue()
    local R = Config.Roue
    if not R then return end
    local c = R.coords
    local hS, hR = `vw_prop_vw_luckywheel_01a`, `vw_prop_vw_luckywheel_02a`
    if not socle then
        local e = GetClosestObjectOfType(c.x, c.y, c.z, 2.0, hS, false, false, false)
        if e == 0 and lib.requestModel(hS, 5000) then
            e = CreateObjectNoOffset(hS, c.x, c.y, c.z, false, false, false)
            SetEntityHeading(e, c.w or 0.0)
            FreezeEntityPosition(e, true)
            socle = e
        end
    end
    if not roue then
        local p = vector3(c.x, c.y + 0.0087, c.z + 1.5073)
        local e = GetClosestObjectOfType(p.x, p.y, p.z, 2.0, hR, false, false, false)
        if e == 0 and lib.requestModel(hR, 5000) then
            e = CreateObjectNoOffset(hR, p.x, p.y, p.z, false, false, false)
            SetEntityHeading(e, c.w or 0.0)
            FreezeEntityPosition(e, true)
            roueCree = true
        end
        roue = e ~= 0 and e or nil
    end
    if not podium and R.voiture and R.podium then
        local h = joaat(R.voiture)
        if lib.requestModel(h, 8000) then
            local v = CreateVehicle(h, R.podium.x, R.podium.y, R.podium.z, R.podium.w or 0.0, false, false)
            SetModelAsNoLongerNeeded(h)
            SetEntityInvincible(v, true)
            SetVehicleDoorsLocked(v, 2)
            SetVehicleDirtLevel(v, 0.0)
            FreezeEntityPosition(v, true)
            SetEntityCollision(v, false, false)
            podium = v
        end
    end
end

local function retirerRoue()
    if socle and DoesEntityExist(socle) then DeleteEntity(socle) end
    if roue and roueCree and DoesEntityExist(roue) then DeleteEntity(roue) end
    if podium and DoesEntityExist(podium) then DeleteEntity(podium) end
    socle, roue, podium, roueCree = nil, nil, nil, false
end

RegisterNetEvent('pt-casino:roueTourne', function(case, joueur)
    if not roue or not DoesEntityExist(roue) then return end
    roueTourne = true
    local nb = #Config.Roue.cases
    local depart = GetEntityRotation(roue, 2).y % 360.0
    local cible = 360.0 * 6 + (case - 1) * (360.0 / nb) + (Config.Roue.decalageAngle or 0.0)
    local duree, debut = 10000, GetGameTimer()
    if GetPlayerServerId(PlayerId()) == joueur then
        local dict = 'anim_casino_a@amb@casino@games@lucky7wheel@male'
        if chargerAnim(dict) then TaskPlayAnim(PlayerPedId(), dict, 'armraisedidle_to_spinningidle_high', 3.0, 3.0, 2500, 0, 0, false, false, false) end
    end
    CreateThread(function()
        local cran = -1
        while GetGameTimer() - debut < duree do
            local t = (GetGameTimer() - debut) / duree
            local e = 1.0 - (1.0 - t) ^ 3        -- ralentit a la fin
            local angle = depart + (cible - depart) * e
            SetEntityRotation(roue, 0.0, angle, Config.Roue.coords.w or 0.0, 2, true)
            local c = math.floor(angle / (360.0 / nb))
            if c ~= cran then
                cran = c
                PlaySoundFromEntity(-1, 'Spin_Single_Ticks', roue, 'dlc_vw_casino_lucky_wheel_sounds', false, 0)
            end
            Wait(0)
        end
        SetEntityRotation(roue, 0.0, cible % 360.0, Config.Roue.coords.w or 0.0, 2, true)
        PlaySoundFromEntity(-1, 'Win', roue, 'dlc_vw_casino_lucky_wheel_sounds', false, 0)
        roueTourne = false
    end)
end)

-- ---------------------------------------------------------------------------------------------------------------

local function retirerTout()
    for k, o in pairs(props) do
        if o and DoesEntityExist(o) then DeleteEntity(o) end
        props[k] = nil
    end
    for k, p in pairs(croupiers) do
        if DoesEntityExist(p) then DeleteEntity(p) end
        croupiers[k] = nil
    end
    tables = {}
    retirerRoue()
end

-- machines a sous du casino (modeles du jeu)
local SLOTS = {}
for i = 1, 8 do SLOTS[#SLOTS + 1] = joaat(('vw_prop_casino_slot_0%da'):format(i)) end
SLOTS[#SLOTS + 1] = joaat(Config.Modeles.machine)
local slotProche, derniereRecherche = nil, 0

CreateThread(function()
    local dedans = false
    while true do
        local attente = 1000
        local e = etat()
        local pos = GetEntityCoords(PlayerPedId())
        local auCasino = #(pos - CENTRE) < 90.0
        if auCasino and not dedans then poserTables(e.jeux) poserRoue() end
        if not auCasino and dedans then retirerTout() end
        dedans = auCasino

        if e.entree and #(pos - vector3(e.entree.x, e.entree.y, e.entree.z)) < 10.0 then
            attente = 0
            DrawMarker(1, e.entree.x, e.entree.y, e.entree.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.3, 242, 194, 48, 120, false, false, 2, false, nil, nil, false)
            if #(pos - vector3(e.entree.x, e.entree.y, e.entree.z)) < 1.5 then
                texteAide('~INPUT_CONTEXT~ Entrer dans le Diamond Casino')
                if IsControlJustReleased(0, 38) then teleporter(e.sortie) end
            end
        end
        if auCasino and not occupe then
            -- voiture du podium qui tourne
            if podium and DoesEntityExist(podium) then
                SetEntityHeading(podium, (GetEntityHeading(podium) + 0.25) % 360.0)
                attente = 0
            end
            if e.sortie and #(pos - vector3(e.sortie.x, e.sortie.y, e.sortie.z)) < 10.0 then
                attente = 0
                DrawMarker(1, e.sortie.x, e.sortie.y, e.sortie.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.3, 242, 194, 48, 120, false, false, 2, false, nil, nil, false)
                if #(pos - vector3(e.sortie.x, e.sortie.y, e.sortie.z)) < 1.5 then
                    texteAide('~INPUT_CONTEXT~ Sortir du casino')
                    if IsControlJustReleased(0, 38) then teleporter(e.entree) end
                end
            end
            if e.caisse and #(pos - vector3(e.caisse.x, e.caisse.y, e.caisse.z)) < 2.0 then
                attente = 0
                texteAide('~INPUT_CONTEXT~ Caisse : jetons')
                if IsControlJustReleased(0, 38) then caisse() end
            end
            local R = Config.Roue
            if R and #(pos - vector3(R.coords.x, R.coords.y, R.coords.z)) < 2.5 and not roueTourne then
                attente = 0
                texteAide('~INPUT_CONTEXT~ Tourner la roue de la fortune (gratuit, 1 fois par jour)')
                if IsControlJustReleased(0, 38) then TriggerServerEvent('pt-casino:roue') end
            end
            local proposee = false
            for _, j in ipairs(e.jeux or {}) do
                local d = #(pos - vector3(j.coords.x, j.coords.y, j.coords.z))
                if d < 2.2 and JEUX[j.type] then
                    attente = 0
                    proposee = true
                    texteAide('~INPUT_CONTEXT~ ' .. JEUX[j.type].texte)
                    if IsControlJustReleased(0, 38) then CreateThread(function() lancerJeu(j) end) end
                    break
                elseif d < 8.0 then
                    attente = math.min(attente, 200)
                end
            end
            -- toutes les machines a sous du casino sont jouables (pas besoin de les placer une par une)
            if not proposee then
                attente = math.min(attente, 200)
                if GetGameTimer() - derniereRecherche > 250 then
                    derniereRecherche = GetGameTimer()
                    slotProche = nil
                    for _, h in ipairs(SLOTS) do
                        local o = GetClosestObjectOfType(pos.x, pos.y, pos.z, 1.4, h, false, false, false)
                        if o ~= 0 then slotProche = o break end
                    end
                end
                if slotProche and DoesEntityExist(slotProche) then
                    attente = 0
                    texteAide('~INPUT_CONTEXT~ Jouer a la machine a sous')
                    if IsControlJustReleased(0, 38) then
                        local c = GetEntityCoords(slotProche)
                        CreateThread(function() lancerJeu({ type = 'machine', coords = { x = c.x, y = c.y, z = c.z } }) end)
                    end
                end
            end
        end
        Wait(attente)
    end
end)

AddStateBagChangeHandler('pt_casino', 'global', function(_, _, valeur)
    if valeur and #(GetEntityCoords(PlayerPedId()) - CENTRE) < 90.0 then
        CreateThread(function() poserTables(valeur.jeux) end)
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom == GetCurrentResourceName() then
        seLever()
        retirerTout()
    end
end)
