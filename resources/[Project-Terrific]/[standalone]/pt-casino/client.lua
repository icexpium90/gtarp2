local QBCore = exports['qb-core']:GetCoreObject()
local props = {}
local occupe = false

local function etat() return GlobalState.pt_casino or {} end

local function texteAide(t)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(t)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function demanderMise(titre)
    local n = lib.callback.await('pt-casino:jetons', false) or 0
    local r = lib.inputDialog(titre, {
        { type = 'number', label = ('Mise (vous avez %d jetons)'):format(n), min = Config.MiseMin, max = Config.MiseMax,
          default = math.min(math.max(Config.MiseMin, 100), Config.MiseMax), required = true },
    })
    return r and tonumber(r[1])
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
    occupe = true
    PlaySoundFrontend(-1, 'SPINNING', 'dlc_vw_casino_slot_machine_ak_player_sounds', true)
    lib.progressCircle({ duration = 2200, label = 'Les rouleaux tournent...', position = 'bottom', canCancel = false, disable = { move = true, combat = true } })
    local r = lib.callback.await('pt-casino:machine', false, mise)
    occupe = false
    if not r then return end
    local ligne = ('[ %s | %s | %s ]'):format(r.symboles[1], r.symboles[2], r.symboles[3])
    if r.gain > 0 then
        lib.notify({ title = ligne, description = ('Gagne : %d jetons'):format(r.gain), type = 'success', duration = 6000 })
    else
        lib.notify({ title = ligne, description = ('Perdu (%d jetons)'):format(r.mise), type = 'error', duration = 5000 })
    end
end

local function roulette()
    local r = lib.inputDialog('Roulette', {
        { type = 'select', label = 'Pari', required = true, default = 'rouge', options = {
            { value = 'rouge', label = 'Rouge (x2)' }, { value = 'noir', label = 'Noir (x2)' },
            { value = 'pair', label = 'Pair (x2)' }, { value = 'impair', label = 'Impair (x2)' },
            { value = 'manque', label = '1 a 18 (x2)' }, { value = 'passe', label = '19 a 36 (x2)' },
            { value = 'douzaine', label = 'Douzaine 1, 2 ou 3 (x3)' }, { value = 'numero', label = 'Numero plein 0 a 36 (x36)' } } },
        { type = 'number', label = 'Numero (0-36) ou douzaine (1-3), si besoin', min = 0, max = 36 },
        { type = 'number', label = 'Mise (jetons)', min = Config.MiseMin, max = Config.MiseMax, default = 100, required = true },
    })
    if not r then return end
    occupe = true
    lib.progressCircle({ duration = 3000, label = 'La bille tourne...', position = 'bottom', canCancel = false, disable = { move = true, combat = true } })
    local res = lib.callback.await('pt-casino:roulette', false, r[1], r[2], r[3])
    occupe = false
    if not res then return end
    local titre = ('Le %d %s'):format(res.numero, res.couleur)
    if res.gain > 0 then
        lib.notify({ title = titre, description = ('Gagne : %d jetons'):format(res.gain), type = 'success', duration = 6000 })
    else
        lib.notify({ title = titre, description = ('Perdu (%d jetons)'):format(res.mise), type = 'error', duration = 5000 })
    end
end

local RESULTATS = { blackjack = 'Blackjack ! ', gagne = 'Gagne ! ', egalite = 'Egalite, mise rendue. ', perdu = 'Perdu. ' }

local function afficherBJ(v)
    if v.fin then
        local desc = ('Vous : %s (%d)\nCroupier : %s (%d)'):format(v.joueur, v.totalJoueur, v.croupier, v.totalCroupier)
        lib.alertDialog({ header = (RESULTATS[v.resultat] or '') .. (v.gain > 0 and ('+%d jetons'):format(v.gain) or ''), content = desc, centered = true })
        return
    end
    local options = {
        { title = ('Vous : %d'):format(v.totalJoueur), description = v.joueur, icon = 'user', readOnly = true },
        { title = 'Croupier', description = v.croupier, icon = 'user-tie', readOnly = true },
        { title = 'Tirer une carte', icon = 'plus', onSelect = function() afficherBJ(lib.callback.await('pt-casino:bj_action', false, 'tirer')) end },
        { title = 'Rester', icon = 'hand', onSelect = function() afficherBJ(lib.callback.await('pt-casino:bj_action', false, 'rester')) end },
    }
    if v.peutDoubler then
        options[#options + 1] = { title = ('Doubler (+%d jetons, une seule carte)'):format(v.mise), icon = 'angles-up',
            onSelect = function() afficherBJ(lib.callback.await('pt-casino:bj_action', false, 'doubler')) end }
    end
    lib.registerContext({ id = 'pt_casino_bj', title = ('Blackjack - mise %d'):format(v.mise), canClose = false, options = options })
    lib.showContext('pt_casino_bj')
end

local function blackjack()
    local mise = demanderMise('Blackjack')
    if not mise then return end
    local v = lib.callback.await('pt-casino:bj_debut', false, mise)
    if v then afficherBJ(v) end
end

local JEUX = { machine = { texte = 'Jouer a la machine a sous', f = machine },
               roulette = { texte = 'Jouer a la roulette', f = roulette },
               blackjack = { texte = 'Jouer au blackjack', f = blackjack } }

-- ---------------------------------------------------------------------------------------------------------------
-- Tables posees si le casino n'en a pas deja a cet endroit

local function cle(j) return ('%s_%.1f_%.1f'):format(j.type, j.coords.x, j.coords.y) end

local function poserTables(jeux)
    local voulues = {}
    for _, j in ipairs(jeux or {}) do
        local k = cle(j)
        voulues[k] = true
        if props[k] == nil then
            local h = joaat(Config.Modeles[j.type])
            local existant = GetClosestObjectOfType(j.coords.x, j.coords.y, j.coords.z, 2.0, h, false, false, false)
            if existant ~= 0 then
                props[k] = false
            else
                lib.requestModel(h, 5000)
                local o = CreateObjectNoOffset(h, j.coords.x, j.coords.y, j.coords.z, false, false, false)
                SetEntityHeading(o, j.coords.w or 0.0)
                FreezeEntityPosition(o, true)
                SetModelAsNoLongerNeeded(h)
                props[k] = o
            end
        end
    end
    for k, o in pairs(props) do
        if not voulues[k] then
            if o and DoesEntityExist(o) then DeleteEntity(o) end
            props[k] = nil
        end
    end
end

local function retirerTables()
    for k, o in pairs(props) do
        if o and DoesEntityExist(o) then DeleteEntity(o) end
        props[k] = nil
    end
end

-- ---------------------------------------------------------------------------------------------------------------

CreateThread(function()
    local dedans = false
    while true do
        local attente = 1000
        local e = etat()
        local pos = GetEntityCoords(PlayerPedId())
        local auCasino = #(pos - vector3(1120.0, 240.0, -50.0)) < 90.0
        if auCasino and not dedans then poserTables(e.jeux) end
        if not auCasino and dedans then retirerTables() end
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
            for _, j in ipairs(e.jeux or {}) do
                local d = #(pos - vector3(j.coords.x, j.coords.y, j.coords.z))
                if d < 2.2 and JEUX[j.type] then
                    attente = 0
                    texteAide('~INPUT_CONTEXT~ ' .. JEUX[j.type].texte)
                    if IsControlJustReleased(0, 38) then JEUX[j.type].f() end
                    break
                elseif d < 8.0 then
                    attente = math.min(attente, 200)
                end
            end
        end
        Wait(attente)
    end
end)

AddStateBagChangeHandler('pt_casino', 'global', function(_, _, valeur)
    if valeur and #(GetEntityCoords(PlayerPedId()) - vector3(1120.0, 240.0, -50.0)) < 90.0 then
        poserTables(valeur.jeux)
    end
end)

AddEventHandler('onResourceStop', function(nom)
    if nom == GetCurrentResourceName() then retirerTables() end
end)
