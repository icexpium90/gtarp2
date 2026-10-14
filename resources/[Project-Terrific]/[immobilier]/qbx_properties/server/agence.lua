-- Agence immobiliere : gestion des biens par les agents (metier realestate), contrats de vente / location,
-- hausses de prix, appartements multiples, doubles de cles. Voir LISEZMOI.md.
local A = Bridge.Agence
local logger = Bridge.logger

local function notify(src, msg, typ) Bridge.Notify(src, msg, typ) end

local function exige(src, grade)
    if not Bridge.IsRealtor(src) then
        notify(src, 'Reserve aux agents immobiliers en service.', 'error')
        return false
    end
    if grade and Bridge.RealtorGrade(src) < grade then
        notify(src, 'Votre grade ne permet pas cette action.', 'error')
        return false
    end
    return true
end

local function nomJoueur(player)
    local c = player.PlayerData.charinfo or {}
    return ('%s %s'):format(c.firstname or '?', c.lastname or '')
end

local function getProperty(id)
    return MySQL.single.await('SELECT * FROM properties WHERE id = ?', { tonumber(id) })
end

local function rechargerClients()
    TriggerClientEvent('qbx_properties:client:reloadProperties', -1)
end

local function journal(src, message)
    local p = Bridge.GetPlayer(src)
    logger.log({ source = src, event = 'qbx_properties:agence', message = ('[%s] %s'):format(p and p.PlayerData.citizenid or src, message) })
end

local function nomLibre(nom, exclureId)
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM properties WHERE property_name = ? AND id <> ?', { nom, exclureId or 0 })
    return n == 0
end

lib.callback.register('qbx_properties:agence:config', function()
    return { prixDouble = A.prixDouble, prixSerrure = A.prixSerrure, gradeGestion = A.gradeGestion,
        gradeDirection = A.gradeDirection, job = A.job, commission = A.commission }
end)

lib.callback.register('qbx_properties:agence:estAgent', function(source)
    return Bridge.IsRealtor(source)
end)

---------------------------------------------------------------- liste des biens
lib.callback.register('qbx_properties:agence:liste', function(source, filtre)
    if not Bridge.IsRealtor(source) then return nil end
    local where = ''
    if filtre == 'vente' then where = 'WHERE p.owner IS NULL AND p.rent_interval IS NULL'
    elseif filtre == 'location' then where = 'WHERE p.owner IS NULL AND p.rent_interval IS NOT NULL'
    elseif filtre == 'occupe' then where = 'WHERE p.owner IS NOT NULL' end
    local rows = MySQL.query.await(([[
        SELECT p.id, p.property_name, p.price, p.rent_interval, p.owner, p.coords, p.interior, p.next_rent, p.impayes, p.garage IS NOT NULL AS garage,
               JSON_UNQUOTE(JSON_EXTRACT(pl.charinfo, '$.firstname')) AS prenom, JSON_UNQUOTE(JSON_EXTRACT(pl.charinfo, '$.lastname')) AS nom
        FROM properties p LEFT JOIN players pl ON pl.citizenid = p.owner %s ORDER BY p.property_name
    ]]):format(where)) or {}
    for _, r in ipairs(rows) do
        r.coords = json.decode(r.coords)
        r.proprietaire = r.owner and ((r.prenom or '?') .. ' ' .. (r.nom or '')) or nil
        r.prenom, r.nom = nil, nil
        r.garage = r.garage == 1 or r.garage == true
    end
    return { biens = rows, grade = Bridge.RealtorGrade(source), maintenant = os.time() }
end)

---------------------------------------------------------------- prix, loyer, nom
RegisterNetEvent('qbx_properties:agence:modifier', function(id, prix, loyerHeures, nom)
    local src = source
    if not exige(src, A.gradeGestion) then return end
    local property = getProperty(id)
    if not property then return end
    prix = math.floor(tonumber(prix) or property.price)
    if prix < 1 then return end
    loyerHeures = tonumber(loyerHeures)
    if loyerHeures and loyerHeures < 1 then loyerHeures = nil end
    if property.owner and ((loyerHeures == nil) ~= (property.rent_interval == nil)) then
        return notify(src, 'Bien occupe : impossible de passer de la vente a la location (expulsez ou attendez le depart).', 'error')
    end
    nom = type(nom) == 'string' and nom:gsub('^%s+', ''):gsub('%s+$', '') or property.property_name
    if #nom < 4 or #nom > 48 then nom = property.property_name end
    if nom ~= property.property_name and not nomLibre(nom, property.id) then
        return notify(src, 'Ce nom est deja utilise par un autre bien.', 'error')
    end
    MySQL.update.await('UPDATE properties SET price = ?, rent_interval = ?, property_name = ? WHERE id = ?', { prix, loyerHeures and math.floor(loyerHeures) or nil, nom, property.id })
    if nom ~= property.property_name and property.garage and property.owner then
        UnregisterPropertyGarage(property.property_name)
        RegisterPropertyGarage(nom, property.owner, json.decode(property.keyholders), json.decode(property.garage))
        SendGaragesToAll()
    end
    if property.owner and property.rent_interval and prix ~= property.price then
        local locataire = Bridge.GetPlayerByCitizenId(property.owner)
        if locataire then
            notify(locataire.PlayerData.source, ('Le loyer de %s passe de $%s a $%s'):format(nom, property.price, prix))
        end
    end
    notify(src, ('%s : $%s%s'):format(nom, prix, loyerHeures and (' toutes les %dh'):format(loyerHeures) or ' (vente)'), 'success')
    journal(src, ('modifie %s (#%d) : prix %s -> %s, loyer %s'):format(nom, property.id, property.price, prix, tostring(loyerHeures)))
end)

---------------------------------------------------------------- hausse / baisse globale (direction)
-- cible : 'vente' (biens a vendre libres), 'location' (tous les loyers), 'tous' ; porte : coords d'un immeuble ou nil
RegisterNetEvent('qbx_properties:agence:ajuster', function(cible, pourcent, porteId)
    local src = source
    if not exige(src, A.gradeDirection) then return end
    pourcent = tonumber(pourcent)
    if not pourcent or pourcent == 0 or pourcent < -90 or pourcent > 500 then return end
    local where, params = {}, {}
    if cible == 'vente' then
        where[#where + 1] = 'rent_interval IS NULL AND owner IS NULL'
    elseif cible == 'location' then
        where[#where + 1] = 'rent_interval IS NOT NULL'
    elseif cible ~= 'tous' then
        return
    end
    if porteId then
        -- immeuble : tous les biens qui partagent la porte du bien choisi
        local ref = MySQL.scalar.await('SELECT coords FROM properties WHERE id = ?', { tonumber(porteId) })
        if not ref then return end
        where[#where + 1] = 'coords = ?'
        params[#params + 1] = ref
    end
    local facteur = 1 + pourcent / 100
    local sql = 'SELECT id, owner, price, rent_interval, property_name FROM properties' .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '')
    local biens = MySQL.query.await(sql, params) or {}
    for _, b in ipairs(biens) do
        local nouveau = math.max(1, math.floor(b.price * facteur + 0.5))
        MySQL.update.await('UPDATE properties SET price = ? WHERE id = ?', { nouveau, b.id })
        if b.owner and b.rent_interval then
            local locataire = Bridge.GetPlayerByCitizenId(b.owner)
            if locataire then
                notify(locataire.PlayerData.source, ('Revision du loyer de %s : $%s -> $%s'):format(b.property_name, b.price, nouveau))
            end
        end
    end
    notify(src, ('%d bien(s) ajuste(s) de %s%s %%'):format(#biens, pourcent > 0 and '+' or '', pourcent), 'success')
    journal(src, ('ajustement %s %s%% sur %d biens'):format(cible, pourcent, #biens))
end)

---------------------------------------------------------------- expulsion, transfert, suppression
RegisterNetEvent('qbx_properties:agence:expulser', function(id)
    local src = source
    if not exige(src, A.gradeGestion) then return end
    local property = getProperty(id)
    if not property or not property.owner then return end
    ReleaseProperty(property.id, ('L\'agence immobiliere a repris %s'):format(property.property_name))
    notify(src, ('%s est de nouveau libre (serrure changee).'):format(property.property_name), 'success')
    journal(src, ('expulse %s de %s (#%d)'):format(property.owner, property.property_name, property.id))
end)

RegisterNetEvent('qbx_properties:agence:transferer', function(id, cibleId)
    local src = source
    if not exige(src, A.gradeGestion) then return end
    local property = getProperty(id)
    local cible = Bridge.GetPlayer(tonumber(cibleId) or -1)
    if not property or not cible then return notify(src, 'Joueur introuvable.', 'error') end
    local cid = cible.PlayerData.citizenid
    if property.owner == cid then return end
    if property.owner then ReleaseProperty(property.id) end
    MySQL.update.await('UPDATE properties SET owner = ?, next_rent = ?, impayes = 0 WHERE id = ?',
        { cid, property.rent_interval and (os.time() + property.rent_interval * 3600) or nil, property.id })
    if property.garage then
        RegisterPropertyGarage(property.property_name, cid, {}, json.decode(property.garage))
    end
    SendGaragesToAll()
    notify(src, ('%s transfere a %s'):format(property.property_name, nomJoueur(cible)), 'success')
    notify(cible.PlayerData.source, ('Vous etes maintenant titulaire de %s'):format(property.property_name), 'success')
    journal(src, ('transfere %s (#%d) a %s'):format(property.property_name, property.id, cid))
end)

RegisterNetEvent('qbx_properties:agence:supprimer', function(id)
    local src = source
    if not exige(src, A.gradeDirection) then return end
    local property = getProperty(id)
    if not property then return end
    if property.owner then ReleaseProperty(property.id) end
    MySQL.query.await('DELETE FROM properties_decorations WHERE property_id = ?', { property.id })
    MySQL.query.await('DELETE FROM properties WHERE id = ?', { property.id })
    rechargerClients()
    notify(src, ('%s supprime'):format(property.property_name), 'success')
    journal(src, ('supprime %s (#%d)'):format(property.property_name, property.id))
end)

---------------------------------------------------------------- immeuble : plusieurs appartements a la meme porte
RegisterNetEvent('qbx_properties:agence:dupliquer', function(id, nombre, base)
    local src = source
    if not exige(src, A.gradeGestion) then return end
    local property = getProperty(id)
    nombre = math.floor(tonumber(nombre) or 0)
    if not property or nombre < 1 or nombre > 50 then return end
    base = (type(base) == 'string' and #base >= 3) and base:sub(1, 36) or property.property_name
    local crees, k = 0, 1
    while crees < nombre and k < 500 do
        local nom = ('%s - Apt %d'):format(base, k)
        if nomLibre(nom) then
            MySQL.insert.await('INSERT INTO properties (property_name, coords, price, interior, interact_options, stash_options, rent_interval) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { nom, property.coords, property.price, property.interior, property.interact_options, property.stash_options, property.rent_interval })
            crees += 1
        end
        k += 1
    end
    rechargerClients()
    notify(src, ('%d appartement(s) ajoute(s) a la porte de %s'):format(crees, property.property_name), 'success')
    if property.interior == Bridge.MLO then
        notify(src, 'Attention : pour un MLO, chaque appartement doit avoir sa propre sortie (Placer les points > Sortie).', 'primary')
    end
    journal(src, ('duplique %s (#%d) en %d appartements'):format(property.property_name, property.id, crees))
end)

---------------------------------------------------------------- contrats : l'agent propose, le client signe
local contrats = {}
local prochainContrat = 0

RegisterNetEvent('qbx_properties:agence:proposer', function(id, clientId, prix)
    local src = source
    if not exige(src) then return end
    local property = getProperty(id)
    local client = Bridge.GetPlayer(tonumber(clientId) or -1)
    if not property or not client then return notify(src, 'Client introuvable.', 'error') end
    if property.owner then return notify(src, 'Ce bien est deja occupe.', 'error') end
    if client.PlayerData.source == src and not Bridge.IsAdmin(src) then return notify(src, 'Vous ne pouvez pas signer avec vous-meme.', 'error') end
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(client.PlayerData.source)))
    if dist > A.contratDistance then return notify(src, 'Le client doit etre a cote de vous.', 'error') end
    prix = math.floor(tonumber(prix) or property.price)
    -- un agent peut negocier jusqu'a -15 %, la direction sans limite
    if prix < property.price * 0.85 and Bridge.RealtorGrade(src) < A.gradeDirection then
        return notify(src, ('Remise trop forte (minimum $%d).'):format(math.ceil(property.price * 0.85)), 'error')
    end
    prochainContrat += 1
    local cid = prochainContrat
    contrats[cid] = { agent = src, client = client.PlayerData.source, id = property.id, prix = prix, expire = os.time() + 120 }
    TriggerClientEvent('qbx_properties:client:contrat', client.PlayerData.source, {
        contrat = cid,
        nom = property.property_name,
        prix = prix,
        loyer = property.rent_interval,
        agent = nomJoueur(Bridge.GetPlayer(src)),
    })
    notify(src, ('Contrat envoye a %s'):format(nomJoueur(client)), 'success')
end)

RegisterNetEvent('qbx_properties:agence:repondre', function(cid, accepte)
    local src = source
    local c = contrats[cid]
    if not c or c.client ~= src then return end
    contrats[cid] = nil
    local agent = Bridge.GetPlayer(c.agent)
    if not accepte then
        if agent then notify(c.agent, 'Le client a refuse le contrat.', 'error') end
        return
    end
    if os.time() > c.expire then return notify(src, 'Contrat expire.', 'error') end
    local property = getProperty(c.id)
    local client = Bridge.GetPlayer(src)
    if not property or property.owner or not client then return notify(src, 'Ce bien n\'est plus disponible.', 'error') end
    local libelle = (property.rent_interval and 'Loyer %s' or 'Achat %s'):format(property.property_name)
    local paye = client.Functions.RemoveMoney('bank', c.prix, libelle)
    if not paye and not property.rent_interval then paye = client.Functions.RemoveMoney('cash', c.prix, libelle) end
    if not paye then
        notify(src, 'Fonds insuffisants.', 'error')
        if agent then notify(c.agent, 'Le client n\'a pas les fonds.', 'error') end
        return
    end
    local commission = agent and math.floor(c.prix * A.commission) or 0
    Bridge.SocietyDeposit(c.prix - commission, libelle)
    if agent and commission > 0 then
        agent.Functions.AddMoney('bank', commission, ('Commission %s'):format(property.property_name))
    end
    -- location : le loyer negocie devient le loyer du bail
    MySQL.update.await('UPDATE properties SET owner = ?, keyholders = ?, next_rent = ?, impayes = 0, price = ? WHERE id = ?',
        { client.PlayerData.citizenid, '[]', property.rent_interval and (os.time() + property.rent_interval * 3600) or nil,
          property.rent_interval and c.prix or property.price, property.id })
    if property.garage then
        RegisterPropertyGarage(property.property_name, client.PlayerData.citizenid, {}, json.decode(property.garage))
    end
    SendGaragesToAll()
    notify(src, ('Contrat signe : %s'):format(property.property_name), 'success')
    if agent then notify(c.agent, ('Contrat signe ! Commission : $%d'):format(commission), 'success') end
    journal(c.agent, ('contrat %s (#%d) avec %s pour $%d'):format(property.property_name, property.id, client.PlayerData.citizenid, c.prix))
end)

---------------------------------------------------------------- doubles de cles et serrures (proprietaire, depuis l'interieur)
RegisterNetEvent('qbx_properties:server:faireDouble', function()
    local src = source
    local propertyId = GetEnteredProperty(src)
    local player = Bridge.GetPlayer(src)
    if not propertyId or not player then return end
    local property = getProperty(propertyId)
    if not property or property.owner ~= player.PlayerData.citizenid then
        return notify(src, locale('notify.no_access'), 'error')
    end
    if not player.Functions.RemoveMoney('bank', A.prixDouble, 'Double de cle') and not player.Functions.RemoveMoney('cash', A.prixDouble, 'Double de cle') then
        return notify(src, ('Il faut $%d pour un double.'):format(A.prixDouble), 'error')
    end
    local info = { property = property.id, serrure = property.serrure or 1, label = property.property_name,
        description = ('Double de cle : %s'):format(property.property_name) }
    if not player.Functions.AddItem(Bridge.KeyItem, 1, false, info) then
        player.Functions.AddMoney('bank', A.prixDouble, 'Remboursement double de cle')
        return notify(src, 'Inventaire plein.', 'error')
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Bridge.KeyItem], 'add')
    Bridge.SocietyDeposit(A.prixDouble, 'Double de cle')
    notify(src, ('Double de cle de %s cree : donnez-le a qui vous voulez.'):format(property.property_name), 'success')
end)

RegisterNetEvent('qbx_properties:server:changerSerrures', function()
    local src = source
    local propertyId = GetEnteredProperty(src)
    local player = Bridge.GetPlayer(src)
    if not propertyId or not player then return end
    local property = getProperty(propertyId)
    if not property or property.owner ~= player.PlayerData.citizenid then
        return notify(src, locale('notify.no_access'), 'error')
    end
    if not player.Functions.RemoveMoney('bank', A.prixSerrure, 'Changement de serrure') then
        return notify(src, ('Il faut $%d en banque.'):format(A.prixSerrure), 'error')
    end
    MySQL.update.await('UPDATE properties SET serrure = serrure + 1 WHERE id = ?', { property.id })
    Bridge.SocietyDeposit(A.prixSerrure, 'Changement de serrure')
    notify(src, 'Serrures changees : les anciens doubles ne fonctionnent plus.', 'success')
end)

---------------------------------------------------------------- mes biens (tout joueur)
lib.callback.register('qbx_properties:callback:mesBiens', function(source)
    local player = Bridge.GetPlayer(source)
    if not player then return {} end
    local cid = player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, property_name, coords, owner, keyholders, rent_interval, price, next_rent FROM properties WHERE owner = ? OR keyholders LIKE ?', { cid, '%' .. cid .. '%' }) or {}
    local liste = {}
    for _, r in ipairs(rows) do
        liste[#liste + 1] = { nom = r.property_name, coords = json.decode(r.coords), proprietaire = r.owner == cid,
            loyer = r.rent_interval and r.price or nil, prochain = r.next_rent and math.max(0, r.next_rent - os.time()) or nil }
    end
    return liste
end)
