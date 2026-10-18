local QBCore = exports['qb-core']:GetCoreObject()
math.randomseed(os.time() + GetGameTimer())

local CENTRE = vector3(1120.0, 240.0, -50.0)   -- interieur du casino
local RAYON = 80.0

-- ---------------------------------------------------------------------------------------------------------------
-- Positions (config, modifiables en jeu par les admins, gardees en KVP)

local function v4(t) return { x = t.x, y = t.y, z = t.z, w = t.w or 0.0 } end
local function lirePos(cle, defaut)
    local d = json.decode(GetResourceKvpString('pos_' .. cle) or 'null')
    return d or v4(defaut)
end

local etat = {
    entree = lirePos('entree', Config.Entree),
    sortie = lirePos('sortie', Config.Sortie),
    caisse = lirePos('caisse', Config.Caisse),
    jeux = json.decode(GetResourceKvpString('jeux') or 'null'),
}
if not etat.jeux then
    etat.jeux = {}
    for _, j in ipairs(Config.Jeux) do etat.jeux[#etat.jeux + 1] = { type = j.type, coords = v4(j.coords) } end
end
-- jeux ajoutes par une mise a jour (poker, courses) : ajoutes une fois aux positions deja enregistrees
local presents = {}
for _, j in ipairs(etat.jeux) do presents[j.type] = true end
if (GetResourceKvpInt('version_jeux') or 0) < 2 then
    for _, j in ipairs(Config.Jeux) do
        if not presents[j.type] and Config.Modeles[j.type] ~= nil then etat.jeux[#etat.jeux + 1] = { type = j.type, coords = v4(j.coords) } end
    end
    SetResourceKvpInt('version_jeux', 2)
end
local function publier()
    SetResourceKvp('jeux', json.encode(etat.jeux))
    GlobalState.pt_casino = etat
end
publier()

local function estAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') or IsPlayerAceAllowed(src, 'command')
end

local function notifier(src, t, g) TriggerClientEvent('QBCore:Notify', src, t, g or 'primary', 6000) end

local function posJoueur(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z - 1.0, w = GetEntityHeading(ped) }
end

RegisterCommand('casinopos', function(src, args)
    if src == 0 or not estAdmin(src) then return end
    local cle = args[1]
    if cle ~= 'entree' and cle ~= 'sortie' and cle ~= 'caisse' then
        return notifier(src, 'Usage : /casinopos entree|sortie|caisse', 'error')
    end
    local p = posJoueur(src)
    if cle ~= 'caisse' then p.z = p.z + 1.0 end
    etat[cle] = p
    SetResourceKvp('pos_' .. cle, json.encode(p))
    publier()
    notifier(src, 'Position "' .. cle .. '" enregistree.', 'success')
end, false)

RegisterCommand('casinojeu', function(src, args)
    if src == 0 or not estAdmin(src) then return end
    local t = args[1]
    if t == 'retirer' then
        local c = GetEntityCoords(GetPlayerPed(src))
        local meilleur, dist = nil, 4.0
        for i, j in ipairs(etat.jeux) do
            local d = #(c - vector3(j.coords.x, j.coords.y, j.coords.z))
            if d < dist then meilleur, dist = i, d end
        end
        if not meilleur then return notifier(src, 'Aucun jeu a moins de 4 m.', 'error') end
        table.remove(etat.jeux, meilleur)
        publier()
        return notifier(src, 'Jeu retire.', 'success')
    end
    if Config.Modeles[t] == nil then return notifier(src, 'Usage : /casinojeu machine|roulette|blackjack|poker|courses|retirer', 'error') end
    etat.jeux[#etat.jeux + 1] = { type = t, coords = posJoueur(src) }
    publier()
    notifier(src, t .. ' ajoute(e) ici.', 'success')
end, false)

-- ---------------------------------------------------------------------------------------------------------------
-- Jetons

local function joueurAuCasino(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    if #(GetEntityCoords(GetPlayerPed(src)) - CENTRE) > RAYON then return nil end
    return P
end

local function jetons(P)
    local it = P.Functions.GetItemByName(Config.Jeton)
    return it and it.amount or 0
end

local function miser(P, src, mise)
    mise = math.floor(tonumber(mise) or 0)
    if mise < Config.MiseMin or mise > Config.MiseMax then
        notifier(src, ('Mise entre %d et %d jetons.'):format(Config.MiseMin, Config.MiseMax), 'error')
        return nil
    end
    if jetons(P) < mise or not P.Functions.RemoveItem(Config.Jeton, mise) then
        notifier(src, 'Pas assez de jetons (caisse du casino).', 'error')
        return nil
    end
    return mise
end

local function payer(P, n)
    n = math.floor(n)
    if n > 0 then P.Functions.AddItem(Config.Jeton, n) end
end

lib.callback.register('pt-casino:jetons', function(src)
    local P = QBCore.Functions.GetPlayer(src)
    return P and jetons(P) or 0
end)

RegisterNetEvent('pt-casino:acheter', function(n)
    local src = source
    local P = joueurAuCasino(src)
    n = math.floor(tonumber(n) or 0)
    if not P or n <= 0 or n > 1000000 then return end
    local prix = n * Config.PrixJeton
    if P.Functions.RemoveMoney('cash', prix, 'casino-jetons') or P.Functions.RemoveMoney('bank', prix, 'casino-jetons') then
        payer(P, n)
        notifier(src, ('%d jetons achetes ($%d).'):format(n, prix), 'success')
    else
        notifier(src, 'Fonds insuffisants.', 'error')
    end
end)

RegisterNetEvent('pt-casino:revendre', function(n)
    local src = source
    local P = joueurAuCasino(src)
    n = math.floor(tonumber(n) or 0)
    if not P or n <= 0 then return end
    if jetons(P) < n or not P.Functions.RemoveItem(Config.Jeton, n) then return notifier(src, 'Pas assez de jetons.', 'error') end
    P.Functions.AddMoney('cash', n * Config.PrixJeton, 'casino-revente')
    notifier(src, ('%d jetons revendus : $%d en liquide.'):format(n, n * Config.PrixJeton), 'success')
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Machine a sous

local poidsTotal = 0
for _, s in ipairs(Config.Symboles) do poidsTotal = poidsTotal + s.poids end
local function tirerSymbole()
    local r = math.random(poidsTotal)
    for i, s in ipairs(Config.Symboles) do
        r = r - s.poids
        if r <= 0 then return i end
    end
    return 1
end

lib.callback.register('pt-casino:machine', function(src, mise)
    local P = joueurAuCasino(src)
    if not P then return nil end
    mise = miser(P, src, mise)
    if not mise then return nil end
    local r = { tirerSymbole(), tirerSymbole(), tirerSymbole() }
    local gain = 0
    if r[1] == r[2] and r[2] == r[3] then
        gain = mise * Config.Symboles[r[1]].gain
    else
        local cerises = 0
        for _, i in ipairs(r) do if i == 1 then cerises = cerises + 1 end end
        if cerises == 2 then gain = mise end
    end
    payer(P, gain)
    return { symboles = { Config.Symboles[r[1]].nom, Config.Symboles[r[2]].nom, Config.Symboles[r[3]].nom }, gain = gain, mise = mise }
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Roulette europeenne (0 a 36)

local ROUGES = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do ROUGES[n] = true end

local function gagneRoulette(pari, valeur, n)
    if pari == 'numero' then return n == tonumber(valeur), 36 end
    if n == 0 then return false, 0 end
    if pari == 'rouge' then return ROUGES[n] == true, 2 end
    if pari == 'noir' then return not ROUGES[n], 2 end
    if pari == 'pair' then return n % 2 == 0, 2 end
    if pari == 'impair' then return n % 2 == 1, 2 end
    if pari == 'manque' then return n <= 18, 2 end
    if pari == 'passe' then return n >= 19, 2 end
    if pari == 'douzaine' then
        local d = tonumber(valeur)
        return d and math.ceil(n / 12) == d, 3
    end
    return false, 0
end

lib.callback.register('pt-casino:roulette', function(src, pari, valeur, mise)
    local P = joueurAuCasino(src)
    if not P then return nil end
    if pari == 'numero' and not (tonumber(valeur) and tonumber(valeur) >= 0 and tonumber(valeur) <= 36) then return nil end
    if pari == 'douzaine' and not (tonumber(valeur) and tonumber(valeur) >= 1 and tonumber(valeur) <= 3) then return nil end
    mise = miser(P, src, mise)
    if not mise then return nil end
    local n = math.random(0, 36)
    local ok, mult = gagneRoulette(pari, valeur, n)
    local gain = ok and mise * mult or 0
    payer(P, gain)
    return { numero = n, couleur = n == 0 and 'vert' or (ROUGES[n] and 'rouge' or 'noir'), gain = gain, mise = mise }
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Blackjack (un joueur contre le croupier, le croupier tire jusqu'a 17, blackjack paye 3 pour 2)

local parties = {}
local COULEURS = { 'Pique', 'Coeur', 'Carreau', 'Trefle' }
local NOMS = { 'As', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Valet', 'Dame', 'Roi' }

local function carte()
    return { r = math.random(13), c = math.random(4) }
end
local function valeur(main)
    local total, as = 0, 0
    for _, k in ipairs(main) do
        if k.r == 1 then total = total + 11; as = as + 1
        elseif k.r >= 10 then total = total + 10
        else total = total + k.r end
    end
    while total > 21 and as > 0 do total = total - 10; as = as - 1 end
    return total
end
local function texte(main)
    local t = {}
    for _, k in ipairs(main) do t[#t + 1] = NOMS[k.r] .. ' de ' .. COULEURS[k.c] end
    return table.concat(t, ', ')
end
local function vue(p, fin)
    return {
        joueur = texte(p.joueur), totalJoueur = valeur(p.joueur),
        croupier = fin and texte(p.croupier) or (texte({ p.croupier[1] }) .. ', carte cachee'),
        totalCroupier = fin and valeur(p.croupier) or nil,
        mise = p.mise, fin = fin, peutDoubler = #p.joueur == 2,
    }
end

local function terminer(src, P, p)
    local j = valeur(p.joueur)
    while valeur(p.croupier) < 17 do p.croupier[#p.croupier + 1] = carte() end
    local c = valeur(p.croupier)
    local gain, res = 0, 'perdu'
    local bjJoueur = #p.joueur == 2 and j == 21
    local bjCroupier = #p.croupier == 2 and c == 21
    if j > 21 then res = 'perdu'
    elseif bjJoueur and not bjCroupier then gain = math.floor(p.mise * 2.5); res = 'blackjack'
    elseif c > 21 or j > c then gain = p.mise * 2; res = 'gagne'
    elseif j == c then gain = p.mise; res = 'egalite' end
    payer(P, gain)
    parties[src] = nil
    local v = vue(p, true)
    v.resultat, v.gain = res, gain
    return v
end

lib.callback.register('pt-casino:bj_debut', function(src, mise)
    local P = joueurAuCasino(src)
    if not P or parties[src] then return nil end
    mise = miser(P, src, mise)
    if not mise then return nil end
    local p = { mise = mise, joueur = { carte(), carte() }, croupier = { carte(), carte() } }
    parties[src] = p
    if valeur(p.joueur) == 21 or valeur(p.croupier) == 21 then return terminer(src, P, p) end
    return vue(p, false)
end)

lib.callback.register('pt-casino:bj_action', function(src, action)
    local P = joueurAuCasino(src)
    local p = parties[src]
    if not P or not p then return nil end
    if action == 'tirer' then
        p.joueur[#p.joueur + 1] = carte()
        if valeur(p.joueur) >= 21 then return terminer(src, P, p) end
        return vue(p, false)
    elseif action == 'doubler' and #p.joueur == 2 then
        if not miser(P, src, p.mise) then return vue(p, false) end
        p.mise = p.mise * 2
        p.joueur[#p.joueur + 1] = carte()
        return terminer(src, P, p)
    end
    return terminer(src, P, p)   -- rester
end)

AddEventHandler('playerDropped', function()
    local src = source
    local p = parties[src]
    if p then
        -- partie abandonnee : la mise est perdue (comme en vrai), rien a rendre
        parties[src] = nil
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Animations des croupiers : relayees aux joueurs proches (chacun voit le croupier distribuer / lancer la bille)

local derniereAnim = {}
RegisterNetEvent('pt-casino:anim', function(cle, action)
    local src = source
    if type(cle) ~= 'string' or type(action) ~= 'string' or #cle > 64 or #action > 32 then return end
    if derniereAnim[src] and GetGameTimer() - derniereAnim[src] < 800 then return end
    derniereAnim[src] = GetGameTimer()
    if not joueurAuCasino(src) then return end
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if #(GetEntityCoords(GetPlayerPed(id)) - CENTRE) < RAYON then TriggerClientEvent('pt-casino:anim', id, cle, action, src) end
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Three Card Poker (contre le croupier). Ante, puis Jouer (mise egale a l'ante) ou se coucher.
-- Le croupier se qualifie avec une Dame haute ou mieux.

local poker = {}
local function paquet()
    local p = {}
    for c = 1, 4 do for r = 2, 14 do p[#p + 1] = { r = r, c = c } end end
    for i = #p, 2, -1 do local j = math.random(i) p[i], p[j] = p[j], p[i] end
    return p
end

-- force d'une main de 3 cartes : categorie (6 quinte flush, 5 brelan, 4 suite, 3 couleur, 2 paire, 1 hauteur) + departage
local function forcePoker(m)
    local r = { m[1].r, m[2].r, m[3].r }
    table.sort(r, function(a, b) return a > b end)
    local couleur = m[1].c == m[2].c and m[2].c == m[3].c
    local suite = (r[1] - r[2] == 1 and r[2] - r[3] == 1)
    local hautSuite = r[1]
    if r[1] == 14 and r[2] == 3 and r[3] == 2 then suite, hautSuite = true, 3 end   -- As-2-3
    if suite and couleur then return { 6, hautSuite } end
    if r[1] == r[2] and r[2] == r[3] then return { 5, r[1] } end
    if suite then return { 4, hautSuite } end
    if couleur then return { 3, r[1], r[2], r[3] } end
    if r[1] == r[2] then return { 2, r[1], r[3] } end
    if r[2] == r[3] then return { 2, r[2], r[1] } end
    return { 1, r[1], r[2], r[3] }
end
local function comparer(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end
local NOMS_P = { [11] = 'Valet', [12] = 'Dame', [13] = 'Roi', [14] = 'As' }
local CAT = { 'Hauteur', 'Paire', 'Couleur', 'Suite', 'Brelan', 'Quinte flush' }
local function textePoker(m)
    local t = {}
    for _, k in ipairs(m) do t[#t + 1] = (NOMS_P[k.r] or tostring(k.r)) .. ' de ' .. COULEURS[k.c] end
    return table.concat(t, ', ')
end

lib.callback.register('pt-casino:poker_debut', function(src, ante)
    local P = joueurAuCasino(src)
    if not P or poker[src] then return nil end
    ante = miser(P, src, ante)
    if not ante then return nil end
    local d = paquet()
    local p = { ante = ante, joueur = { d[1], d[2], d[3] }, croupier = { d[4], d[5], d[6] } }
    poker[src] = p
    return { joueur = textePoker(p.joueur), main = CAT[forcePoker(p.joueur)[1]], ante = ante }
end)

lib.callback.register('pt-casino:poker_action', function(src, jouer)
    local P = joueurAuCasino(src)
    local p = poker[src]
    if not P or not p then return nil end
    poker[src] = nil
    local fj, fc = forcePoker(p.joueur), forcePoker(p.croupier)
    local res = { joueur = textePoker(p.joueur), croupier = textePoker(p.croupier), mainJ = CAT[fj[1]], mainC = CAT[fc[1]], ante = p.ante }
    if not jouer then
        res.resultat, res.gain = 'couche', 0
        return res
    end
    if not miser(P, src, p.ante) then
        res.resultat, res.gain = 'couche', 0   -- pas assez de jetons pour suivre : couche d'office
        return res
    end
    local gain = 0
    -- bonus d'ante
    local bonus = 0
    if fj[1] == 6 then bonus = Config.BonusPoker.quinte elseif fj[1] == 5 then bonus = Config.BonusPoker.brelan
    elseif fj[1] == 4 then bonus = Config.BonusPoker.suite end
    gain = gain + p.ante * bonus
    local qualifie = comparer(fc, { 1, 12, 0, 0 }) >= 0
    if not qualifie then
        res.resultat = 'non_qualifie'
        gain = gain + p.ante * 2 + p.ante              -- ante paye 1:1, mise de jeu rendue
    else
        local c = comparer(fj, fc)
        if c > 0 then res.resultat = 'gagne' gain = gain + p.ante * 4      -- ante et jeu payes 1:1
        elseif c == 0 then res.resultat = 'egalite' gain = gain + p.ante * 2
        else res.resultat = 'perdu' end
    end
    res.bonus = bonus > 0 and p.ante * bonus or 0
    res.gain = gain
    payer(P, gain)
    return res
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Courses de chevaux : probabilite de victoire proportionnelle a 1 / cote

local totalInv = 0
for _, c in ipairs(Config.Chevaux) do totalInv = totalInv + 1 / c.cote end
local enCourse = {}

lib.callback.register('pt-casino:courses', function(src, cheval, mise)
    local P = joueurAuCasino(src)
    cheval = tonumber(cheval)
    if not P or enCourse[src] or not cheval or not Config.Chevaux[cheval] then return nil end
    mise = miser(P, src, mise)
    if not mise then return nil end
    enCourse[src] = true
    -- tirage du gagnant, puis classement des autres au hasard
    local r, gagnant = math.random() * totalInv, #Config.Chevaux
    for i, c in ipairs(Config.Chevaux) do
        r = r - 1 / c.cote
        if r <= 0 then gagnant = i break end
    end
    local ordre = { gagnant }
    local reste = {}
    for i = 1, #Config.Chevaux do if i ~= gagnant then reste[#reste + 1] = i end end
    for i = #reste, 2, -1 do local j = math.random(i) reste[i], reste[j] = reste[j], reste[i] end
    for _, i in ipairs(reste) do ordre[#ordre + 1] = i end
    local gain = gagnant == cheval and mise * Config.Chevaux[cheval].cote or 0
    -- gains verses a la fin de la course (le temps de la regarder)
    SetTimeout(Config.DureeCourse * 1000, function()
        enCourse[src] = nil
        local P2 = QBCore.Functions.GetPlayer(src)
        if P2 and gain > 0 then payer(P2, gain) end
    end)
    return { ordre = ordre, gain = gain, mise = mise, cheval = cheval }
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Roue de la fortune

local roueEnCours = false
local poidsRoue = 0
for _, c in ipairs(Config.Roue.cases) do poidsRoue = poidsRoue + c.chance end

local function plaqueLibre()
    for _ = 1, 20 do
        local p = ('CAS%05d'):format(math.random(0, 99999))
        if not MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { p }) then return p end
    end
    return ('C%07d'):format(math.random(0, 9999999))
end

RegisterNetEvent('pt-casino:roue', function()
    local src = source
    local P = joueurAuCasino(src)
    if not P or roueEnCours then return notifier(src, 'La roue tourne deja, attends ton tour.', 'error') end
    local roue = Config.Roue
    if #(GetEntityCoords(GetPlayerPed(src)) - vector3(roue.coords.x, roue.coords.y, roue.coords.z)) > 4.0 then return end
    local cid = P.PlayerData.citizenid
    local dernier = GetResourceKvpInt('roue_' .. cid) or 0
    local reste = roue.delai - (os.time() - dernier)
    if dernier > 0 and reste > 0 then
        return notifier(src, ('Prochain tour gratuit dans %dh%02d.'):format(reste // 3600, (reste % 3600) // 60), 'error')
    end
    SetResourceKvpInt('roue_' .. cid, os.time())
    roueEnCours = true
    local r, case = math.random() * poidsRoue, #roue.cases
    for i, c in ipairs(roue.cases) do
        r = r - c.chance
        if r <= 0 then case = i break end
    end
    -- tout le casino voit la roue tourner
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if #(GetEntityCoords(GetPlayerPed(id)) - CENTRE) < RAYON then TriggerClientEvent('pt-casino:roueTourne', id, case, src) end
    end
    SetTimeout(11000, function()
        roueEnCours = false
        local P2 = QBCore.Functions.GetPlayer(src)
        if not P2 then return end
        local c = roue.cases[case]
        if c.type == 'jetons' then
            payer(P2, c.montant)
            notifier(src, ('Roue de la fortune : %d jetons !'):format(c.montant), 'success')
        elseif c.type == 'argent' then
            P2.Functions.AddMoney('cash', c.montant, 'casino-roue')
            notifier(src, ('Roue de la fortune : $%d en liquide !'):format(c.montant), 'success')
        elseif c.type == 'voiture' then
            local plaque = plaqueLibre()
            MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                P2.PlayerData.license, cid, roue.voiture, joaat(roue.voiture), '{}', plaque, roue.garage, 1,
            })
            notifier(src, ('GROS LOT ! La voiture du podium est a toi (plaque %s), au parking du casino.'):format(plaque), 'success')
            TriggerClientEvent('chat:addMessage', -1, { args = { 'Diamond Casino', GetPlayerName(src) .. ' vient de gagner la voiture du podium !' } })
        else
            notifier(src, 'Roue de la fortune : perdu, retente demain !', 'error')
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    poker[src], enCourse[src], derniereAnim[src] = nil, nil, nil
end)
