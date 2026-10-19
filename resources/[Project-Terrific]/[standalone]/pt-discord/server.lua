-- LUSO RP : le serveur parle a Discord par webhooks
--   Twitter (qb-phone)        -> #twitter-rp
--   petites annonces (qb-phone) -> #leboncoin
--   /annonce (entreprises)    -> #annonces-rp (+ affiche en jeu)
--   ouvertures / fermetures   -> #entreprises (+ affiche en jeu) ; automatiques ou /ouverture /fermeture
local QBCore = exports['qb-core']:GetCoreObject()

-- ---------------------------------------------------------------------------------------------------------------
-- Envoi des webhooks (file d'attente : 1 message par seconde et par webhook, limite de Discord)

local files = {}
local function envoyer(canal, corps)
    local url = GetConvar('pt_webhook_' .. canal, '')
    if url == '' or not url:find('^https://') then return end
    files[canal] = files[canal] or {}
    table.insert(files[canal], { url = url, corps = corps })
end

CreateThread(function()
    while true do
        for canal, f in pairs(files) do
            local m = table.remove(f, 1)
            if m then
                PerformHttpRequest(m.url, function(code, _, _)
                    if code ~= 204 and code ~= 200 then print(('[pt-discord] webhook %s : code %s'):format(canal, tostring(code))) end
                end, 'POST', json.encode(m.corps), { ['Content-Type'] = 'application/json' })
            end
        end
        Wait(1100)
    end
end)

local function nettoyer(t, max)
    t = tostring(t or ''):gsub('@everyone', '@\u{200b}everyone'):gsub('@here', '@\u{200b}here')
    return t:sub(1, max or 1000)
end

local function heure()
    return os.date('%H:%M')
end

local function embed(canal, auteur, titre, texte, couleur, image)
    envoyer(canal, {
        username = auteur,
        embeds = { {
            title = titre, description = texte, color = couleur or Config.Couleur,
            image = image and { url = image } or nil,
            footer = { text = Config.NomServeur .. ' • ' .. heure() },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
end

local function enJeu(titre, texte, icone)
    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div style="padding:6px 10px;margin:4px;background:rgba(201,162,39,0.85);border-radius:6px;color:#111"><b>{0}</b> {1}</div>',
        args = { (icone or '📢') .. ' ' .. titre, texte },
    })
end

local function nomRP(Player)
    local c = Player.PlayerData.charinfo or {}
    return ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', '')
end

-- ---------------------------------------------------------------------------------------------------------------
-- Twitter et petites annonces (on ecoute les evenements du telephone qb-phone, sans le modifier)

local dernier = {}
local function tropRapide(cle, delai)
    if dernier[cle] and os.time() - dernier[cle] < delai then return true end
    dernier[cle] = os.time()
    return false
end

local function image(url)
    url = tostring(url or '')
    if url:find('^https://') and (url:find('%.png') or url:find('%.jpe?g') or url:find('%.gif') or url:find('%.webp')) then return url end
end

RegisterNetEvent('qb-phone:server:UpdateTweets', function(_, tweet)
    if not Config.Twitter or type(tweet) ~= 'table' then return end
    local src = source
    if tropRapide('tw' .. src, 10) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local pseudo = ('@%s_%s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    embed('twitter', 'Twitter', pseudo, nettoyer(tweet.message, 1000), 1942002, image(tweet.url))
end)

RegisterNetEvent('qb-phone:server:AddAdvert', function(msg, url)
    if not Config.Leboncoin then return end
    local src = source
    if tropRapide('lbc' .. src, 30) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local texte = nettoyer(msg, 1000) .. ('\n\n📞 **%s** — %s'):format(Player.PlayerData.charinfo.phone or '?', nomRP(Player))
    embed('lbc', 'Leboncoin', '🛒 Nouvelle annonce', texte, 16737792, image(url))
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Entreprises : regroupement par nom (LS Customs = mechanic, mechanic2, mechanic3)

local function entrepriseDe(job)
    if not job or not job.name or Config.Entreprises.ignores[job.name] then return nil end
    local def = QBCore.Shared.Jobs[job.name]
    if not def then return nil end
    return def.label or job.name
end

local function enService(label)
    local n = 0
    for _, P in pairs(QBCore.Functions.GetQBPlayers()) do
        local j = P.PlayerData.job
        if j and j.onduty and entrepriseDe(j) == label then n = n + 1 end
    end
    return n
end

local ouvertes = {}         -- [label] = true
local fermeturePrevue = {}  -- [label] = os.time() prevu

local function annoncerOuverture(label, message, par)
    ouvertes[label] = true
    fermeturePrevue[label] = nil
    local texte = ('**%s** est ouvert depuis %s.%s'):format(label, heure(), message and message ~= '' and ('\n' .. nettoyer(message, 300)) or '')
    embed('entreprises', label, '🟢 Ouverture', texte, 3066993)
    enJeu(label, 'est OUVERT' .. (message and message ~= '' and (' : ' .. nettoyer(message, 150)) or ''), '🟢')
    if par then print(('[pt-discord] ouverture %s (%s)'):format(label, par)) end
end

local function annoncerFermeture(label, message)
    ouvertes[label] = nil
    fermeturePrevue[label] = nil
    local texte = ('**%s** a fermé à %s.%s'):format(label, heure(), message and message ~= '' and ('\n' .. nettoyer(message, 300)) or '')
    embed('entreprises', label, '🔴 Fermeture', texte, 15158332)
    enJeu(label, 'est FERME' .. (message and message ~= '' and (' : ' .. nettoyer(message, 150)) or ''), '🔴')
end

-- automatique : on verifie chaque entreprise a chaque changement de service, et toutes les 30 s (deconnexions)
local function verifier(label)
    if not label or not Config.Entreprises.auto then return end
    local n = enService(label)
    if n > 0 then
        fermeturePrevue[label] = nil
        if not ouvertes[label] then annoncerOuverture(label, nil, 'auto') end
    elseif ouvertes[label] and not fermeturePrevue[label] then
        fermeturePrevue[label] = os.time() + Config.Entreprises.delaiFermeture
    end
end

AddEventHandler('QBCore:Server:OnJobUpdate', function(_, job)
    local label = entrepriseDe(job)
    SetTimeout(500, function() verifier(label) end)
end)

CreateThread(function()
    Wait(20000)
    while true do
        for label in pairs(ouvertes) do verifier(label) end
        for label, t in pairs(fermeturePrevue) do
            if os.time() >= t then
                if enService(label) == 0 then annoncerFermeture(label) else fermeturePrevue[label] = nil end
            end
        end
        Wait(30000)
    end
end)

-- commandes manuelles (employe en service)
local function entrepriseDuJoueur(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local j = Player.PlayerData.job
    local label = entrepriseDe(j)
    if not label then
        TriggerClientEvent('QBCore:Notify', src, 'Tu dois travailler pour une entreprise.', 'error')
        return nil
    end
    if not j.onduty then
        TriggerClientEvent('QBCore:Notify', src, 'Prends ton service d\'abord.', 'error')
        return nil
    end
    return label, Player
end

RegisterCommand('ouverture', function(src, args)
    if src == 0 then return end
    local label = entrepriseDuJoueur(src)
    if not label then return end
    if tropRapide('ouv' .. label, Config.Entreprises.delaiCommande) then
        return TriggerClientEvent('QBCore:Notify', src, 'Annonce deja faite il y a peu.', 'error')
    end
    annoncerOuverture(label, table.concat(args, ' '), GetPlayerName(src))
end, false)

RegisterCommand('fermeture', function(src, args)
    if src == 0 then return end
    local label = entrepriseDuJoueur(src)
    if not label then return end
    if tropRapide('fer' .. label, Config.Entreprises.delaiCommande) then
        return TriggerClientEvent('QBCore:Notify', src, 'Annonce deja faite il y a peu.', 'error')
    end
    annoncerFermeture(label, table.concat(args, ' '))
end, false)

-- /annonce [texte] : annonce RP de l'entreprise
RegisterCommand('annonce', function(src, args)
    if src == 0 then return end
    local label, Player = entrepriseDuJoueur(src)
    if not label then return end
    local texte = nettoyer(table.concat(args, ' '), Config.Annonce.longueurMax)
    if #texte < 5 then return TriggerClientEvent('QBCore:Notify', src, 'Usage : /annonce [ton message]', 'error') end
    if tropRapide('ann' .. label, Config.Annonce.delai) then
        return TriggerClientEvent('QBCore:Notify', src, ('Une annonce de %s est deja passee il y a peu.'):format(label), 'error')
    end
    if (Config.Annonce.prix or 0) > 0 and not Player.Functions.RemoveMoney('bank', Config.Annonce.prix, 'annonce-rp') then
        dernier['ann' .. label] = nil
        return TriggerClientEvent('QBCore:Notify', src, ('Une annonce coute $%d.'):format(Config.Annonce.prix), 'error')
    end
    enJeu(label, texte, '📰')
    embed('annonces', label, '📰 ' .. label, texte .. ('\n\n— %s'):format(nomRP(Player)), Config.Couleur)
end, false)

