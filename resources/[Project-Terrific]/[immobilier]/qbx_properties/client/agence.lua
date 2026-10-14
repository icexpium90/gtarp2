-- Agence immobiliere : menu /immo des agents (metier realestate), bureau Dynasty 8, contrats, /mesbiens
local sharedConfig = require 'config.shared'
local agence = sharedConfig.agence

ClientAgence = { prixDouble = 250, prixSerrure = 1500, gradeGestion = 2, gradeDirection = 4, job = 'realestate', commission = 0.10 }
CreateThread(function()
    local cfg = lib.callback.await('qbx_properties:agence:config', false)
    if cfg then ClientAgence = cfg end
end)

local function argent(n)
    local s = tostring(math.floor(n or 0))
    local r = s:reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return '$' .. r:gsub('^ ', '')
end

local function duree(sec)
    if not sec then return '-' end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    return h > 0 and ('%dh%02d'):format(h, m) or ('%d min'):format(m)
end

local function typeInterieur(interior)
    if interior == Bridge.MLO then return 'MLO' end
    if tonumber(interior) then
        local d = sharedConfig.interiors[tonumber(interior)]
        return d and d.label or 'Shell'
    end
    local d = sharedConfig.interiors[interior]
    return d and d.label or tostring(interior)
end

local function estAgent()
    local job = QBX.PlayerData.job
    return job and job.name == ClientAgence.job
end

local function gpsVers(c)
    SetNewWaypoint(c.x, c.y)
    Bridge.Notify('Position placee sur le GPS.', 'success')
end

local ouvrirAgence

---------------------------------------------------------------- fiche d'un bien
local function ficheBien(b, grade, retour)
    local options = {
        {
            title = b.property_name,
            description = ('%s | %s%s'):format(typeInterieur(b.interior), argent(b.price),
                b.rent_interval and (' / %dh'):format(b.rent_interval) or ' (vente)'),
            icon = 'circle-info',
            readOnly = true,
        },
        {
            title = b.proprietaire and ('Occupant : %s'):format(b.proprietaire) or 'Libre',
            description = b.next_rent and ('Prochain loyer dans %s%s'):format(duree(math.max(0, b.next_rent - os.time())),
                (b.impayes or 0) > 0 and (' | impayes : %d'):format(b.impayes) or '') or nil,
            icon = b.proprietaire and 'user' or 'door-open',
            readOnly = true,
        },
        { title = 'Mettre sur le GPS', icon = 'location-dot', onSelect = function() gpsVers(b.coords) end },
    }
    if not b.owner then
        options[#options + 1] = {
            title = b.rent_interval and 'Proposer un bail a un client' or 'Proposer la vente a un client',
            description = ('Le client signe sur son ecran, commission de %d %%'):format(math.floor(ClientAgence.commission * 100 + 0.5)),
            icon = 'file-signature',
            onSelect = function()
                local input = lib.inputDialog('Contrat : ' .. b.property_name, {
                    { type = 'number', label = 'ID du client (a cote de vous)', required = true, min = 1, icon = 'user' },
                    { type = 'number', label = b.rent_interval and 'Loyer negocie' or 'Prix negocie', default = b.price, required = true, min = 1, icon = 'dollar-sign' },
                })
                if input then TriggerServerEvent('qbx_properties:agence:proposer', b.id, input[1], input[2]) end
            end,
        }
    end
    if grade >= ClientAgence.gradeGestion then
        options[#options + 1] = {
            title = 'Modifier prix, loyer ou nom',
            icon = 'pen',
            onSelect = function()
                local input = lib.inputDialog(b.property_name, {
                    { type = 'input', label = 'Nom', default = b.property_name, min = 4, max = 48, required = true },
                    { type = 'number', label = 'Prix de vente ou loyer', default = b.price, min = 1, required = true, icon = 'dollar-sign' },
                    { type = 'number', label = 'Intervalle du loyer en heures (vide = a vendre)', default = b.rent_interval, min = 1, max = 168, icon = 'clock' },
                })
                if input then TriggerServerEvent('qbx_properties:agence:modifier', b.id, input[2], input[3], input[1]) end
            end,
        }
        options[#options + 1] = {
            title = 'Ajouter des appartements a cette porte',
            description = 'Cree N logements identiques (meme entree, menu de choix a la porte)',
            icon = 'building',
            onSelect = function()
                local input = lib.inputDialog('Immeuble : ' .. b.property_name, {
                    { type = 'number', label = 'Nombre d\'appartements', default = 4, min = 1, max = 50, required = true },
                    { type = 'input', label = 'Nom de l\'immeuble', default = b.property_name, min = 3, max = 36 },
                })
                if input then TriggerServerEvent('qbx_properties:agence:dupliquer', b.id, input[1], input[2]) end
            end,
        }
        options[#options + 1] = {
            title = 'Transferer a un joueur',
            icon = 'right-left',
            onSelect = function()
                local input = lib.inputDialog('Transfert : ' .. b.property_name, {
                    { type = 'number', label = 'ID du nouveau titulaire', required = true, min = 1 },
                })
                if input then TriggerServerEvent('qbx_properties:agence:transferer', b.id, input[1]) end
            end,
        }
        if b.owner then
            options[#options + 1] = {
                title = 'Expulser / reprendre le bien',
                description = 'Occupant et detenteurs de cles retires, serrure changee',
                icon = 'user-slash',
                onSelect = function()
                    local ok = lib.alertDialog({ header = 'Expulsion', content = ('Reprendre %s a %s ?'):format(b.property_name, b.proprietaire or '?'), centered = true, cancel = true })
                    if ok == 'confirm' then TriggerServerEvent('qbx_properties:agence:expulser', b.id) end
                end,
            }
        end
    end
    if grade >= ClientAgence.gradeDirection then
        options[#options + 1] = {
            title = 'Ajuster les prix de cet immeuble (%)',
            description = 'Tous les biens partageant cette porte',
            icon = 'percent',
            onSelect = function()
                local input = lib.inputDialog('Ajustement de l\'immeuble', {
                    { type = 'select', label = 'Biens concernes', required = true, default = 'tous', options = {
                        { value = 'tous', label = 'Tous' }, { value = 'vente', label = 'A vendre (libres)' }, { value = 'location', label = 'Loyers' } } },
                    { type = 'number', label = 'Variation en % (ex : 10 ou -5)', required = true, min = -90, max = 500 },
                })
                if input then TriggerServerEvent('qbx_properties:agence:ajuster', input[1], input[2], b.id) end
            end,
        }
        options[#options + 1] = {
            title = 'Supprimer le bien',
            icon = 'trash',
            onSelect = function()
                local ok = lib.alertDialog({ header = 'Suppression', content = ('Supprimer definitivement %s (meubles compris) ?'):format(b.property_name), centered = true, cancel = true })
                if ok == 'confirm' then TriggerServerEvent('qbx_properties:agence:supprimer', b.id) end
            end,
        }
    end
    lib.registerContext({ id = 'pt_immo_fiche', title = b.property_name, menu = retour, options = options })
    lib.showContext('pt_immo_fiche')
end

---------------------------------------------------------------- listes
local function listeBiens(filtre, titre)
    local data = lib.callback.await('qbx_properties:agence:liste', false, filtre)
    if not data then return Bridge.Notify('Reserve aux agents immobiliers en service.', 'error') end
    local options = {}
    if #data.biens == 0 then
        options[1] = { title = 'Aucun bien', readOnly = true }
    end
    for _, b in ipairs(data.biens) do
        options[#options + 1] = {
            title = b.property_name,
            description = ('%s%s | %s'):format(argent(b.price), b.rent_interval and (' / %dh'):format(b.rent_interval) or '',
                b.proprietaire or 'libre'),
            icon = b.owner and 'house-user' or (b.rent_interval and 'key' or 'tag'),
            arrow = true,
            onSelect = function() ficheBien(b, data.grade, 'pt_immo_liste') end,
        }
    end
    lib.registerContext({ id = 'pt_immo_liste', title = titre, menu = 'pt_immo_menu', options = options })
    lib.showContext('pt_immo_liste')
end

local function menuLieux()
    local options = {}
    local pos = GetEntityCoords(cache.ped)
    for _, lieu in ipairs(sharedConfig.lieux or {}) do
        local dist = #(pos - lieu.zone)
        options[#options + 1] = {
            title = lieu.label,
            description = ('%s | %s%s | %.0f m'):format(lieu.type or 'MLO', argent(lieu.prix), lieu.loyer and (' / %dh'):format(lieu.loyer) or '', dist),
            icon = 'map-location-dot',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'pt_immo_lieu', title = lieu.label, menu = 'pt_immo_lieux',
                    options = {
                        { title = 'Mettre sur le GPS', icon = 'location-dot', onSelect = function() gpsVers(lieu.zone) end },
                        { title = 'Creer le bien ici', description = 'Placez-vous devant la porte avant de valider', icon = 'plus',
                          onSelect = function() CreerDepuisLieu(lieu) end },
                    },
                })
                lib.showContext('pt_immo_lieu')
            end,
        }
    end
    lib.registerContext({ id = 'pt_immo_lieux', title = 'Lieux MLO disponibles', menu = 'pt_immo_menu', options = options })
    lib.showContext('pt_immo_lieux')
end

ouvrirAgence = function()
    if not estAgent() and not lib.callback.await('qbx_properties:agence:estAgent', false) then
        return Bridge.Notify('Reserve aux agents immobiliers.', 'error')
    end
    local job = QBX.PlayerData.job or {}
    local grade = (job.grade and job.grade.level) or 0
    local options = {
        { title = 'Biens a vendre', icon = 'tag', arrow = true, onSelect = function() listeBiens('vente', 'Biens a vendre') end },
        { title = 'Biens a louer', icon = 'key', arrow = true, onSelect = function() listeBiens('location', 'Biens a louer') end },
        { title = 'Biens occupes', description = 'Proprietaires, locataires, loyers et impayes', icon = 'house-user', arrow = true, onSelect = function() listeBiens('occupe', 'Biens occupes') end },
        { title = 'Tous les biens', icon = 'list', arrow = true, onSelect = function() listeBiens('tous', 'Tous les biens') end },
        { title = 'Creer un bien a ma position', description = 'Shell, interieur du jeu ou MLO', icon = 'plus', onSelect = function() ExecuteCommand('createproperty') end },
        { title = 'Lieux MLO disponibles', description = 'Batiments deja sur la carte, prets a etre mis en vente', icon = 'map', arrow = true, onSelect = menuLieux },
    }
    if grade >= ClientAgence.gradeDirection or not estAgent() then
        options[#options + 1] = {
            title = 'Revision globale des prix (%)',
            description = 'Hausse ou baisse de tous les prix de vente et / ou loyers',
            icon = 'chart-line',
            onSelect = function()
                local input = lib.inputDialog('Revision des prix', {
                    { type = 'select', label = 'Biens concernes', required = true, default = 'location', options = {
                        { value = 'location', label = 'Tous les loyers (locataires prevenus)' },
                        { value = 'vente', label = 'Biens a vendre (libres)' },
                        { value = 'tous', label = 'Tous les biens' } } },
                    { type = 'number', label = 'Variation en % (ex : 5 ou -10)', required = true, min = -90, max = 500 },
                })
                if input then TriggerServerEvent('qbx_properties:agence:ajuster', input[1], input[2]) end
            end,
        }
    end
    if estAgent() then
        options[#options + 1] = {
            title = job.onduty and 'Quitter le service' or 'Prendre le service',
            icon = 'clock', onSelect = function() TriggerServerEvent('QBCore:ToggleDuty') end,
        }
        if job.isboss then
            options[#options + 1] = {
                title = 'Gestion de l\'entreprise', description = 'Employes, grades, compte de l\'agence',
                icon = 'briefcase', onSelect = function() TriggerEvent('qb-bossmenu:client:OpenMenu') end,
            }
        end
    end
    lib.registerContext({ id = 'pt_immo_menu', title = 'Agence immobiliere', options = options })
    lib.showContext('pt_immo_menu')
end

RegisterCommand('immo', function() ouvrirAgence() end, false)
RegisterNetEvent('qbx_properties:client:agence', function() ouvrirAgence() end)

---------------------------------------------------------------- contrat recu par un client
RegisterNetEvent('qbx_properties:client:contrat', function(c)
    local texte
    if c.loyer then
        texte = ('%s vous propose un bail pour **%s** : %s preleves toutes les %d heure(s) (premier loyer aujourd\'hui).'):format(c.agent, c.nom, argent(c.prix), c.loyer)
    else
        texte = ('%s vous propose l\'achat de **%s** pour %s.'):format(c.agent, c.nom, argent(c.prix))
    end
    local ok = lib.alertDialog({ header = 'Contrat immobilier', content = texte, centered = true, cancel = true, labels = { confirm = 'Signer', cancel = 'Refuser' } })
    TriggerServerEvent('qbx_properties:agence:repondre', c.contrat, ok == 'confirm')
end)

---------------------------------------------------------------- /mesbiens : biens du joueur
RegisterCommand('mesbiens', function()
    local liste = lib.callback.await('qbx_properties:callback:mesBiens', false) or {}
    local options = {}
    if #liste == 0 then options[1] = { title = 'Aucun bien', description = 'Contactez Dynasty 8 pour acheter ou louer', readOnly = true } end
    for _, b in ipairs(liste) do
        options[#options + 1] = {
            title = b.nom,
            description = (b.proprietaire and 'Titulaire' or 'Detenteur de cle') .. (b.loyer and (' | loyer %s, prochain dans %s'):format(argent(b.loyer), duree(b.prochain)) or ''),
            icon = b.proprietaire and 'house' or 'key',
            onSelect = function() gpsVers(b.coords) end,
        }
    end
    lib.registerContext({ id = 'pt_mes_biens', title = 'Mes biens', options = options })
    lib.showContext('pt_mes_biens')
end, false)

---------------------------------------------------------------- bureau Dynasty 8
CreateThread(function()
    local b = agence.blip
    local blip = AddBlipForCoord((agence.entree or agence.bureau).x, (agence.entree or agence.bureau).y, (agence.entree or agence.bureau).z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.couleur)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(b.label)
    EndTextCommandSetBlipName(blip)

    while true do
        local attente = 1000
        local dist = #(GetEntityCoords(cache.ped) - agence.bureau)
        if dist < 10.0 and estAgent() then
            attente = 0
            DrawMarker(2, agence.bureau.x, agence.bureau.y, agence.bureau.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.25, 0.25, 0.2, 60, 180, 90, 180, false, true, 2, false, nil, nil, false)
            if dist < 1.5 then
                qbx.drawText3d({ coords = agence.bureau + vec3(0.0, 0.0, 0.5), text = '[E] Agence immobiliere' })
                if IsControlJustPressed(0, 38) then ouvrirAgence() end
            end
        end
        Wait(attente)
    end
end)


---------------------------------------------------------------- icones des biens possedes (maison rose) et des biens dont on a la cle
local blipsBiens = {}
local function rafraichirBlips()
    for _, b in ipairs(blipsBiens) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blipsBiens = {}
    if not LocalPlayer.state.isLoggedIn then return end
    local liste = lib.callback.await('qbx_properties:callback:mesBiens', false) or {}
    local vus = {}
    for _, b in ipairs(liste) do
        local cle = ('%.1f:%.1f'):format(b.coords.x, b.coords.y)
        if not vus[cle] or (b.proprietaire and not vus[cle].proprietaire) then
            if vus[cle] then RemoveBlip(vus[cle].blip) end
            local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
            SetBlipSprite(blip, 40)                         -- maison
            SetBlipColour(blip, b.proprietaire and 8 or 48) -- rose : possede ; rose clair : cle
            SetBlipScale(blip, b.proprietaire and 0.85 or 0.7)
            SetBlipAsShortRange(blip, false)
            SetBlipCategory(blip, 11)                       -- categorie "proprietes" de la legende
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(b.proprietaire and b.nom or (b.nom .. ' (cle)'))
            EndTextCommandSetBlipName(blip)
            vus[cle] = { blip = blip, proprietaire = b.proprietaire }
            blipsBiens[#blipsBiens + 1] = blip
        end
    end
end

RegisterNetEvent('qbx_properties:client:rafraichirBlips', function()
    SetTimeout(math.random(200, 1500), rafraichirBlips) -- etale les requetes quand tout le monde est prevenu
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(2000, rafraichirBlips) end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    for _, b in ipairs(blipsBiens) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blipsBiens = {}
end)
CreateThread(function() Wait(3000) rafraichirBlips() end)
