-- LUSO RP : diagnostic du serveur. /rapport (console txAdmin ou admin en jeu) ecrit un rapport texte a envoyer a Claude :
--   1. erreurs vues dans la console depuis le demarrage (SCRIPT ERROR, echecs de chargement...), regroupees par ressource
--   2. etat de chaque ressource (demarree / arretee / en erreur) et dependances manquantes
--   3. fichiers declares dans les fxmanifest mais absents
--   4. verification de syntaxe de TOUS les fichiers .lua (client et serveur), sans les executer
-- Les adresses IP, licences, identifiants et mots de passe sont masques avant ecriture.

local RES = GetCurrentResourceName()
local DEMARRAGE = os.time()
local MAX_LIGNES = 400

-- ---------------------------------------------------------------------------------------------------------------
-- Capture de la console

local lignes = {}          -- dernieres lignes "interessantes"
local parRessource = {}    -- [ressource] = { n = nombre, derniere = texte, pile = premiere ligne de pile }
local enCours = nil        -- erreur multi-lignes en cours de lecture

local MOTIFS = {
    'SCRIPT ERROR', 'Error loading script', 'Failed to load', 'Couldn\'t load resource', 'Could not find dependency',
    'error parsing script', 'attempt to ', 'stack traceback', 'Warning: ', 'warning: ', '%[ERROR%]', 'Error:',
    'failed to start', 'Couldn\'t start resource', 'is not a valid', 'Unexpected', 'oversized', 'Asset ',
}

local function nettoyer(t)
    t = t:gsub('%^%d', '')                                     -- couleurs de la console
    t = t:gsub('%d+%.%d+%.%d+%.%d+', 'x.x.x.x')                 -- adresses IP
    t = t:gsub('license2?:%x+', 'license:***')
    t = t:gsub('steam:%x+', 'steam:***'):gsub('discord:%d+', 'discord:***'):gsub('fivem:%d+', 'fivem:***')
    t = t:gsub('xbl:%d+', 'xbl:***'):gsub('live:%d+', 'live:***')
    t = t:gsub('cfxk_[%w_]+', 'cfxk_***')                       -- cle de licence
    t = t:gsub('mysql://[^%s"\']+', 'mysql://***')
    t = t:gsub('[Pp]assword=[^;%s"\']+', 'password=***')
    return t
end

local function ressourceDe(canal, msg)
    local r = msg:match('@([%w_%-]+)/') or msg:match('%[([%w_%-]+)%]') or msg:match('resource ([%w_%-]+)')
    if r and GetResourceState(r) ~= 'missing' then return r end
    local c = canal and canal:match('script:([%w_%-]+)')
    return c or r or (canal ~= '' and canal) or 'serveur'
end

local function interessant(msg)
    for _, m in ipairs(MOTIFS) do
        if msg:find(m) then return true end
    end
    return false
end

-- avertissements de "hitch" (gels de la machine) : comptes a part, jamais melanges aux vraies erreurs
local hitches = { total = 0, max = 0, parFil = {}, parHeure = {} }

RegisterConsoleListener(function(canal, message)
    if not message or message == '' then return end
    local fil, ms = message:match('(%a+) thread hitch warning: timer interval of (%d+) milliseconds')
    if fil then
        ms = tonumber(ms)
        hitches.total = hitches.total + 1
        hitches.max = math.max(hitches.max, ms)
        hitches.parFil[fil] = (hitches.parFil[fil] or 0) + 1
        local h = os.date('%H:00')
        hitches.parHeure[h] = (hitches.parHeure[h] or 0) + 1
        return
    end
    local msg = nettoyer(message:gsub('\n+$', ''))
    if msg == '' then return end
    -- lignes de pile qui suivent une erreur
    if enCours and (msg:find('^%s') or msg:find('stack traceback') or msg:find('^%s*%[') ) then
        if not enCours.pile and msg:find('%.lua:%d+') then enCours.pile = msg:gsub('^%s+', '') end
        if #lignes < MAX_LIGNES * 2 then lignes[#lignes + 1] = '    ' .. msg end
        return
    end
    enCours = nil
    if not interessant(msg) then return end
    local r = ressourceDe(canal or '', msg)
    local e = parRessource[r] or { n = 0 }
    e.n = e.n + 1
    e.derniere = msg:sub(1, 400)
    e.quand = os.date('%H:%M:%S')
    parRessource[r] = e
    if msg:find('SCRIPT ERROR') or msg:find('stack traceback') then enCours = e end
    lignes[#lignes + 1] = ('[%s] [%s] %s'):format(os.date('%H:%M:%S'), r, msg:sub(1, 500))
    while #lignes > MAX_LIGNES do table.remove(lignes, 1) end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Verifications statiques

local function fichiersLua(chemin)
    local liste = {}
    local p = io.popen(('find "%s" -type f -name "*.lua" -not -path "*/node_modules/*" 2>/dev/null'):format(chemin))
    if p then
        for l in p:lines() do liste[#liste + 1] = l end
        p:close()
    end
    return liste
end

local function lire(chemin)
    local f = io.open(chemin, 'rb')
    if not f then return nil end
    local t = f:read('*a')
    f:close()
    return t
end

-- fichiers declares (client_script, server_script, shared_script, files) qui n'existent pas
local CLES = { 'client_script', 'server_script', 'shared_script', 'file', 'ui_page' }
local function fichiersManquants(res)
    local manquants = {}
    for _, cle in ipairs(CLES) do
        for i = 0, GetNumResourceMetadata(res, cle) - 1 do
            local f = GetResourceMetadata(res, cle, i)
            if f and not f:find('^@') and not f:find('[%*%?]') and not f:find('^https?://') and not f:find('^nui://') then
                local chemin = GetResourcePath(res) .. '/' .. f
                local h = io.open(chemin, 'rb')
                if h then h:close() else manquants[#manquants + 1] = f end
            elseif f and f:find('^@') then
                local autre = f:match('^@([^/]+)/')
                if autre and GetResourceState(autre) == 'missing' then manquants[#manquants + 1] = f .. ' (ressource absente)' end
            end
        end
    end
    return manquants
end

local function dependancesManquantes(res)
    local m = {}
    for _, cle in ipairs({ 'dependency' }) do
        for i = 0, GetNumResourceMetadata(res, cle) - 1 do
            local d = GetResourceMetadata(res, cle, i)
            if d and not d:find('^/') then
                local st = GetResourceState(d)
                if st ~= 'started' and st ~= 'starting' then m[#m + 1] = d .. ' (' .. st .. ')' end
            end
        end
    end
    return m
end

-- syntaxe Lua (compilation seulement : rien n'est execute)
local function verifierSyntaxe(res)
    local erreurs = {}
    local base = GetResourcePath(res)
    for _, chemin in ipairs(fichiersLua(base)) do
        local code = lire(chemin)
        if code then
            local relatif = chemin:sub(#base + 2)
            local ok, err = load(code, '@' .. res .. '/' .. relatif, 't', {})
            if not ok then erreurs[#erreurs + 1] = nettoyer(tostring(err)) end
        end
    end
    return erreurs
end

-- ---------------------------------------------------------------------------------------------------------------
-- Rapport

local function genererRapport()
    local out = {}
    local function L(t) out[#out + 1] = t or '' end
    local nbRes, demarrees, arretees = GetNumResources(), {}, {}
    local problemes = {}

    L('=== RAPPORT DE DIAGNOSTIC LUSO RP ===')
    L(('Date : %s | serveur en ligne depuis %d min | joueurs : %d | FXServer : %s'):format(
        os.date('%Y-%m-%d %H:%M'), (os.time() - DEMARRAGE) // 60, #GetPlayers(), GetConvar('version', '?'):sub(1, 60)))
    L(('OneSync : %s | ressources : %d'):format(GetConvar('onesync', '?'), nbRes))
    L()

    -- 1. erreurs de la console
    -- gels de la machine (hors erreurs de scripts)
    L('--- 0. GELS DU SERVEUR (hitch warnings, ecartes des erreurs ci-dessous) ---')
    if hitches.total == 0 then
        L('Aucun.')
    else
        local fils = {}
        for f, n in pairs(hitches.parFil) do fils[#fils + 1] = f .. ' ' .. n end
        local heures = {}
        for h, n in pairs(hitches.parHeure) do heures[#heures + 1] = { h = h, n = n } end
        table.sort(heures, function(a, b) return a.h < b.h end)
        local th = {}
        for _, x in ipairs(heures) do th[#th + 1] = x.h .. ' : ' .. x.n end
        L(('%d avertissements, pire gel %d ms (%s)'):format(hitches.total, hitches.max, table.concat(fils, ', ')))
        L('Par heure : ' .. table.concat(th, ' | '))
        L('Rappel : sur ce VPS, ces gels viennent de la machine (test python), pas des scripts.')
    end
    L()
    L('--- 1. ERREURS VUES DANS LA CONSOLE (depuis le demarrage de pt-diagnostic) ---')
    local tri = {}
    for r, e in pairs(parRessource) do tri[#tri + 1] = { r = r, e = e } end
    table.sort(tri, function(a, b) return a.e.n > b.e.n end)
    if #tri == 0 then L('Aucune erreur capturee.') end
    for _, x in ipairs(tri) do
        L(('* %s : %d fois (derniere a %s)'):format(x.r, x.e.n, x.e.quand or '?'))
        L('    ' .. (x.e.derniere or ''))
        if x.e.pile then L('    -> ' .. x.e.pile) end
    end
    L()

    -- 2/3/4. ressources
    L('--- 2. RESSOURCES : ETAT, DEPENDANCES, FICHIERS MANQUANTS, SYNTAXE LUA ---')
    local nbFichiers, nbSyntaxe = 0, 0
    for i = 0, nbRes - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= '_cfx_internal' then
            local st = GetResourceState(res)
            if st == 'started' then demarrees[#demarrees + 1] = res else arretees[#arretees + 1] = res .. ' (' .. st .. ')' end
            local pb = {}
            local dep = dependancesManquantes(res)
            if #dep > 0 and st ~= 'stopped' then pb[#pb + 1] = 'dependances non demarrees : ' .. table.concat(dep, ', ') end
            local manq = fichiersManquants(res)
            if #manq > 0 then pb[#pb + 1] = 'fichiers absents : ' .. table.concat(manq, ', ') nbFichiers = nbFichiers + #manq end
            local syn = verifierSyntaxe(res)
            for _, e in ipairs(syn) do pb[#pb + 1] = 'SYNTAXE : ' .. e end
            nbSyntaxe = nbSyntaxe + #syn
            if #pb > 0 then problemes[#problemes + 1] = { res = res, st = st, pb = pb } end
        end
    end
    if #problemes == 0 then L('Aucun probleme detecte dans les ressources.') end
    for _, p in ipairs(problemes) do
        L(('* %s [%s]'):format(p.res, p.st))
        for _, t in ipairs(p.pb) do L('    - ' .. t) end
    end
    L()
    L(('Ressources demarrees : %d | non demarrees : %d | fichiers absents : %d | erreurs de syntaxe : %d'):format(
        #demarrees, #arretees, nbFichiers, nbSyntaxe))
    L('Non demarrees : ' .. (#arretees > 0 and table.concat(arretees, ', ') or 'aucune'))
    L()

    -- 5. dernieres lignes brutes
    L('--- 3. DERNIERES LIGNES D\'ERREUR DE LA CONSOLE (brutes, anonymisees) ---')
    local debut = math.max(1, #lignes - 150)
    for i = debut, #lignes do L(lignes[i]) end
    if #lignes == 0 then L('(rien)') end
    L()
    L('=== FIN DU RAPPORT ===')
    return table.concat(out, '\n'), #tri, #problemes
end

local function ecrire(texte)
    local dossier = GetResourcePath(RES) .. '/rapports'
    os.execute(('mkdir -p "%s"'):format(dossier))
    local nom = ('rapport_%s.txt'):format(os.date('%Y%m%d_%H%M%S'))
    local f = io.open(dossier .. '/' .. nom, 'wb')
    if not f then
        dossier = GetResourcePath(RES)
        f = io.open(dossier .. '/' .. nom, 'wb')
    end
    if f then
        f:write(texte)
        f:close()
        -- copie "derniere" a nom fixe, plus simple a recuperer
        local g = io.open(dossier .. '/rapport_dernier.txt', 'wb')
        if g then g:write(texte) g:close() end
        return dossier .. '/' .. nom
    end
end

local function estAdmin(src)
    if src == 0 then return true end
    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore and (QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')) then return true end
    return IsPlayerAceAllowed(src, 'command')
end

RegisterCommand('rapport', function(src)
    if not estAdmin(src) then return end
    print('^3[pt-diagnostic] analyse en cours (syntaxe de tous les scripts, peut prendre 10-30 s)...^7')
    CreateThread(function()
        local texte, nbErr, nbPb = genererRapport()
        local chemin = ecrire(texte)
        local msg = ('[pt-diagnostic] rapport pret : %d ressource(s) avec erreurs console, %d avec problemes. Fichier : %s'):format(
            nbErr, nbPb, chemin or '(ecriture impossible)')
        print('^2' .. msg .. '^7')
        print('^3[pt-diagnostic] envoie le fichier rapport_dernier.txt a Claude (WinSCP/SFTP, meme dossier), ou affiche-le avec : cat "' ..
            (chemin and chemin:gsub('rapport_%d+_%d+%.txt$', 'rapport_dernier.txt') or '?') .. '"^7')
        if src ~= 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'Diagnostic', msg } }) end
    end)
end, false)

print('^2[pt-diagnostic] pret : tape "rapport" dans la console txAdmin (ou /rapport en jeu, admin) pour generer un rapport.^7')
