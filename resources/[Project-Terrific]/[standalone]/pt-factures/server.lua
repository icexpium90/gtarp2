local QBCore = exports['qb-core']:GetCoreObject()

-- Les factures sont dans la table phone_invoices de qb-phone : elles apparaissent aussi dans l'application
-- "Factures" du telephone. Colonne "motif" ajoutee si besoin.
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `phone_invoices` (
        `id` int(10) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) DEFAULT NULL,
        `amount` int(11) NOT NULL DEFAULT 0,
        `society` tinytext DEFAULT NULL,
        `sender` varchar(50) DEFAULT NULL,
        `sendercitizenid` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local col = MySQL.query.await("SHOW COLUMNS FROM phone_invoices LIKE 'motif'") or {}
    if #col == 0 then
        MySQL.query.await('ALTER TABLE phone_invoices ADD COLUMN `motif` VARCHAR(120) NULL DEFAULT NULL')
    end
end)

local function nom(P)
    return P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname
end

local function notifier(src, texte, genre)
    TriggerClientEvent('QBCore:Notify', src, texte, genre or 'primary', 6000)
end

local function argent(n)
    local s = tostring(math.floor(n))
    return '$' .. s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
end

-- noms des joueurs proches (pour la liste du client)
lib.callback.register('pt-factures:noms', function(src, ids)
    local res = {}
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(type(ids) == 'table' and ids or {}) do
        local P = QBCore.Functions.GetPlayer(tonumber(id))
        if P and #(GetEntityCoords(GetPlayerPed(P.PlayerData.source)) - pos) <= Config.Distance + 2.0 then
            res[#res + 1] = { id = P.PlayerData.source, nom = nom(P) }
        end
    end
    return res
end)

lib.callback.register('pt-factures:peutFacturer', function(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return { false } end
    local m = Config.Metiers[P.PlayerData.job.name]
    if not m then return { false, 'Votre metier ne peut pas facturer.' } end
    if Config.EnService and not P.PlayerData.job.onduty then return { false, 'Prenez votre service pour facturer.' } end
    return { true, m.label }
end)

RegisterNetEvent('pt-factures:server:envoyer', function(cible, montant, motif)
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    local C = QBCore.Functions.GetPlayer(tonumber(cible) or -1)
    if not P then return end
    local metier = P.PlayerData.job.name
    local m = Config.Metiers[metier]
    if not m then return notifier(src, 'Votre metier ne peut pas facturer.', 'error') end
    if Config.EnService and not P.PlayerData.job.onduty then return notifier(src, 'Prenez votre service pour facturer.', 'error') end
    if not C then return notifier(src, 'Client introuvable.', 'error') end
    if C.PlayerData.citizenid == P.PlayerData.citizenid then return notifier(src, 'Vous ne pouvez pas vous facturer.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(C.PlayerData.source))) > Config.Distance + 2.0 then
        return notifier(src, 'Le client est trop loin.', 'error')
    end
    montant = math.floor(tonumber(montant) or 0)
    if montant <= 0 or montant > m.max then
        return notifier(src, ('Montant invalide (1 a %s).'):format(argent(m.max)), 'error')
    end
    motif = type(motif) == 'string' and motif:sub(1, 120) or nil
    if motif == '' then motif = nil end
    local id = MySQL.insert.await('INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid, motif) VALUES (?, ?, ?, ?, ?, ?)',
        { C.PlayerData.citizenid, montant, metier, nom(P):sub(1, 50), P.PlayerData.citizenid, motif })
    if not id then return notifier(src, 'Erreur lors de l\'envoi de la facture.', 'error') end
    notifier(src, ('Facture de %s envoyee a %s.'):format(argent(montant), nom(C)), 'success')
    TriggerClientEvent('pt-factures:client:recue', C.PlayerData.source, {
        id = id, montant = montant, motif = motif, metier = m.label, emetteur = nom(P),
    })
    TriggerClientEvent('qb-phone:RefreshPhone', C.PlayerData.source)
end)

-- Paiement d'une facture (aussi utilise par l'application Factures du telephone)
local function payer(src, id)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local f = MySQL.single.await('SELECT * FROM phone_invoices WHERE id = ? AND citizenid = ?', { tonumber(id), P.PlayerData.citizenid })
    if not f then
        notifier(src, 'Facture introuvable ou deja payee.', 'error')
        return false
    end
    local montant = math.floor(tonumber(f.amount) or 0)
    local paye = false
    if P.Functions.GetMoney('bank') >= montant then
        paye = P.Functions.RemoveMoney('bank', montant, 'facture-' .. (f.society or ''))
    elseif P.Functions.GetMoney('cash') >= montant then
        paye = P.Functions.RemoveMoney('cash', montant, 'facture-' .. (f.society or ''))
    end
    if not paye then
        notifier(src, ('Fonds insuffisants pour payer %s (banque ou liquide).'):format(argent(montant)), 'error')
        return false
    end
    -- supprimee avant de verser l'argent : une facture ne peut pas etre payee deux fois
    local supprime = MySQL.update.await('DELETE FROM phone_invoices WHERE id = ?', { f.id })
    if not supprime or supprime == 0 then
        P.Functions.AddMoney('bank', montant, 'facture-remboursee')
        return false
    end
    local m = Config.Metiers[f.society]
    local commission = 0
    local emetteur = f.sendercitizenid and QBCore.Functions.GetPlayerByCitizenId(f.sendercitizenid)
    if m and emetteur then
        commission = math.floor(montant * (m.commission or 0))
        if commission > 0 then
            emetteur.Functions.AddMoney('bank', commission, 'commission-facture')
            notifier(emetteur.PlayerData.source, ('%s a paye sa facture de %s : commission de %s.'):format(nom(P), argent(montant), argent(commission)), 'success')
        else
            notifier(emetteur.PlayerData.source, ('%s a paye sa facture de %s.'):format(nom(P), argent(montant)), 'success')
        end
    end
    if f.society and GetResourceState('qb-management') == 'started' then
        exports['qb-management']:AddMoney(f.society, montant - commission)
    end
    notifier(src, ('Facture de %s payee.'):format(argent(montant)), 'success')
    TriggerClientEvent('qb-phone:RefreshPhone', src)
    return true
end
exports('Payer', payer)

RegisterNetEvent('pt-factures:server:payer', function(id)
    payer(source, id)
end)

lib.callback.register('pt-factures:liste', function(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return {} end
    local rows = MySQL.query.await('SELECT id, amount, society, sender, motif FROM phone_invoices WHERE citizenid = ? ORDER BY id DESC', { P.PlayerData.citizenid }) or {}
    for _, r in ipairs(rows) do
        r.metier = Config.Metiers[r.society] and Config.Metiers[r.society].label or r.society
    end
    return rows
end)

-- Travaux faits a l'atelier des mecaniciens (qbx_customs) : proposer la facture avec le total
exports('ProposerTravaux', function(src, total)
    if (tonumber(total) or 0) > 0 then
        TriggerClientEvent('pt-factures:client:facturer', src, math.floor(total), Config.MotifDefautTravaux)
    end
end)
