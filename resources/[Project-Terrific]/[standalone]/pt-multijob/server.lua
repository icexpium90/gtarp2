local QBCore = exports['qb-core']:GetCoreObject()

local actif = {}       -- [source] = metier actif connu
local enChangement = {} -- [source] = true pendant un changement fait par ce script
local dernier = {}     -- [source] = os.time() du dernier changement

local function notify(src, msg, typ) TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary') end

local function jobValide(job, grade)
    local j = QBCore.Shared.Jobs[job]
    return j ~= nil and j.grades[tostring(grade)] ~= nil
end

local function getJobs(cid)
    return MySQL.query.await('SELECT job, grade, actif FROM pt_multijob WHERE citizenid = ? ORDER BY job', { cid }) or {}
end

local function compte(cid, sauf)
    return MySQL.scalar.await('SELECT COUNT(*) FROM pt_multijob WHERE citizenid = ? AND job <> ?', { cid, sauf or '' }) or 0
end

local function marquerActif(cid, job)
    MySQL.update.await('UPDATE pt_multijob SET actif = (job = ?) WHERE citizenid = ?', { job or '', cid })
end

local function upsert(cid, job, grade)
    MySQL.insert.await('INSERT INTO pt_multijob (citizenid, job, grade) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grade = VALUES(grade)', { cid, job, tonumber(grade) or 0 })
end

local function incompatible(cid, job)
    for _, autre in ipairs(Config.Incompatibles[job] or {}) do
        if MySQL.scalar.await('SELECT COUNT(*) FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, autre }) > 0 then
            return autre
        end
    end
end

-- active un metier de la liste (ou "unemployed")
local function activer(src, job, grade)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    enChangement[src] = true
    local ok = player.Functions.SetJob(job, grade)
    enChangement[src] = nil
    if ok then
        actif[src] = job
        marquerActif(player.PlayerData.citizenid, job)
    end
    return ok
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pt_multijob` (
            `citizenid` VARCHAR(50) NOT NULL,
            `job` VARCHAR(50) NOT NULL,
            `grade` INT NOT NULL DEFAULT 0,
            `actif` TINYINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`, `job`),
            KEY `job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end)

-- connexion : on enregistre le metier actif ; un metier retire hors ligne (licenciement) est enleve de la liste
local function chargement(player)
    local src, cid, job = player.PlayerData.source, player.PlayerData.citizenid, player.PlayerData.job
    if Config.Ignores[job.name] then
        local precedent = MySQL.scalar.await('SELECT job FROM pt_multijob WHERE citizenid = ? AND actif = 1', { cid })
        if precedent then
            MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, precedent })
        end
    else
        upsert(cid, job.name, job.grade.level)
    end
    marquerActif(cid, job.name)
    actif[src] = job.name
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData then chargement(player) end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(2000, function()
        for _, player in pairs(QBCore.Functions.GetQBPlayers()) do chargement(player) end
    end)
end)

AddEventHandler('playerDropped', function()
    actif[source], dernier[source], enChangement[source] = nil, nil, nil
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    actif[src] = nil
end)

-- tout changement de metier fait par un autre script (embauche, licenciement, promotion, /setjob, mairie...)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if enChangement[src] then return end
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid
    local precedent = actif[src]
    if job.name == precedent then
        -- promotion ou prise / fin de service
        if not Config.Ignores[job.name] then upsert(cid, job.name, job.grade.level) end
        return
    end
    if Config.Ignores[job.name] then
        -- licencie ou demission du metier actif : il quitte la liste, un autre metier devient actif s'il en reste
        if precedent and not Config.Ignores[precedent] then
            MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, precedent })
            local reste = getJobs(cid)
            if reste[1] and jobValide(reste[1].job, reste[1].grade) then
                SetTimeout(500, function()
                    if activer(src, reste[1].job, reste[1].grade) then
                        notify(src, ('Metier actif : %s'):format(QBCore.Shared.Jobs[reste[1].job].label))
                    end
                end)
            end
        end
        actif[src] = job.name
        marquerActif(cid, job.name)
        return
    end
    -- nouveau metier (embauche, /setjob, mairie) : les metiers incompatibles quittent la liste
    for _, autre in ipairs(Config.Incompatibles[job.name] or {}) do
        if MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, autre }).affectedRows > 0 then
            notify(src, ('%s et %s ne se cumulent pas : %s retire'):format(job.label, autre, autre), 'error')
        end
    end
    local deja = MySQL.scalar.await('SELECT COUNT(*) FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, job.name }) > 0
    if not deja and compte(cid) >= Config.MaxJobs then
        -- liste pleine : le nouveau metier remplace le metier actif precedent (comportement QBCore classique)
        if precedent and not Config.Ignores[precedent] then
            MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, precedent })
            notify(src, ('Limite de %d metiers : %s est remplace par %s'):format(Config.MaxJobs,
                QBCore.Shared.Jobs[precedent] and QBCore.Shared.Jobs[precedent].label or precedent, job.label), 'error')
        end
    end
    upsert(cid, job.name, job.grade.level)
    actif[src] = job.name
    marquerActif(cid, job.name)
end)

---------------------------------------------------------------- menu du joueur
lib.callback.register('pt-multijob:liste', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return {} end
    local liste = {}
    for _, r in ipairs(getJobs(player.PlayerData.citizenid)) do
        local j = QBCore.Shared.Jobs[r.job]
        if j then
            local g = j.grades[tostring(r.grade)] or {}
            liste[#liste + 1] = { job = r.job, label = j.label, grade = r.grade, gradeLabel = g.name or tostring(r.grade),
                salaire = g.payment, actif = r.job == player.PlayerData.job.name }
        end
    end
    return { metiers = liste, max = Config.MaxJobs }
end)

RegisterNetEvent('pt-multijob:server:changer', function(job)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or type(job) ~= 'string' then return end
    if player.PlayerData.job.name == job then return end
    local maintenant = os.time()
    if dernier[src] and maintenant - dernier[src] < Config.Cooldown then
        return notify(src, ('Patientez encore %d s avant de changer de metier.'):format(Config.Cooldown - (maintenant - dernier[src])), 'error')
    end
    if Config.HorsServiceSeulement and player.PlayerData.job.onduty and not Config.Ignores[player.PlayerData.job.name] then
        return notify(src, 'Quittez d\'abord le service.', 'error')
    end
    if player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or player.PlayerData.metadata.ishandcuffed then
        return notify(src, 'Impossible maintenant.', 'error')
    end
    local grade = MySQL.scalar.await('SELECT grade FROM pt_multijob WHERE citizenid = ? AND job = ?', { player.PlayerData.citizenid, job })
    if not grade or not jobValide(job, grade) then return notify(src, 'Metier introuvable.', 'error') end
    if activer(src, job, grade) then
        dernier[src] = maintenant
        notify(src, ('Metier actif : %s'):format(QBCore.Shared.Jobs[job].label), 'success')
    end
end)

RegisterNetEvent('pt-multijob:server:quitter', function(job)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or type(job) ~= 'string' then return end
    local cid = player.PlayerData.citizenid
    MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, job })
    if player.PlayerData.job.name == job then
        local reste = getJobs(cid)
        if reste[1] and jobValide(reste[1].job, reste[1].grade) then
            activer(src, reste[1].job, reste[1].grade)
        else
            activer(src, 'unemployed', 0)
        end
    end
    notify(src, ('Vous avez quitte : %s'):format(QBCore.Shared.Jobs[job] and QBCore.Shared.Jobs[job].label or job), 'success')
end)

---------------------------------------------------------------- exports (utilises par qb-management)
local function AddJob(cid, job, grade)
    if Config.Ignores[job] or not jobValide(job, grade) then return false, 'invalide' end
    local deja = MySQL.scalar.await('SELECT COUNT(*) FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, job }) > 0
    if not deja then
        if compte(cid) >= Config.MaxJobs then return false, 'plein' end
        local conflit = incompatible(cid, job)
        if conflit then return false, 'incompatible', conflit end
    end
    upsert(cid, job, grade)
    local p = QBCore.Functions.GetPlayerByCitizenId(cid)
    if p and p.PlayerData.job.name == job then activer(p.PlayerData.source, job, grade) end
    return true
end

local function RemoveJob(cid, job)
    MySQL.query.await('DELETE FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, job })
    local p = QBCore.Functions.GetPlayerByCitizenId(cid)
    if p then
        if p.PlayerData.job.name == job then
            local reste = getJobs(cid)
            if reste[1] and jobValide(reste[1].job, reste[1].grade) then
                activer(p.PlayerData.source, reste[1].job, reste[1].grade)
            else
                activer(p.PlayerData.source, 'unemployed', 0)
            end
        end
        return true
    end
    -- hors ligne : si c'etait le metier actif, on bascule la ligne players sur un autre metier ou chomeur
    local row = MySQL.single.await('SELECT job FROM players WHERE citizenid = ?', { cid })
    local actuel = row and json.decode(row.job)
    if actuel and actuel.name == job then
        local reste = getJobs(cid)
        local nom, niveau = 'unemployed', 0
        if reste[1] and jobValide(reste[1].job, reste[1].grade) then nom, niveau = reste[1].job, reste[1].grade end
        local j = QBCore.Shared.Jobs[nom]
        local g = j.grades[tostring(niveau)]
        local data = { name = nom, label = j.label, payment = g.payment or 0, onduty = j.defaultDuty, isboss = g.isboss or false,
            grade = { name = g.name, level = niveau } }
        MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(data), cid })
        marquerActif(cid, nom)
    end
    return true
end

local function SetGrade(cid, job, grade)
    if not jobValide(job, grade) then return false end
    local p = QBCore.Functions.GetPlayerByCitizenId(cid)
    if p and p.PlayerData.job.name == job then
        return p.Functions.SetJob(job, grade)
    end
    local n = MySQL.update.await('UPDATE pt_multijob SET grade = ? WHERE citizenid = ? AND job = ?', { grade, cid, job })
    return n and n > 0
end

local function GetJobs(cid) return getJobs(cid) end
local function HasJob(cid, job)
    return MySQL.scalar.await('SELECT COUNT(*) FROM pt_multijob WHERE citizenid = ? AND job = ?', { cid, job }) > 0
end
-- employes d'un metier (actif ou secondaire) : { citizenid, grade, actif }
local function GetEmployees(job)
    return MySQL.query.await('SELECT citizenid, grade, actif FROM pt_multijob WHERE job = ?', { job }) or {}
end

exports('AddJob', AddJob)
exports('RemoveJob', RemoveJob)
exports('SetGrade', SetGrade)
exports('GetJobs', GetJobs)
exports('HasJob', HasJob)
exports('GetEmployees', GetEmployees)

---------------------------------------------------------------- commandes admin
QBCore.Commands.Add('addjob', 'Ajouter un metier secondaire (sans le rendre actif)', {
    { name = 'id', help = 'ID du joueur' }, { name = 'job', help = 'Nom du metier' }, { name = 'grade', help = 'Grade' },
}, true, function(source, args)
    local cible = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not cible then return notify(source, 'Joueur introuvable.', 'error') end
    local ok, raison, conflit = AddJob(cible.PlayerData.citizenid, args[2], tonumber(args[3]) or 0)
    if ok then
        notify(source, 'Metier ajoute.', 'success')
        notify(cible.PlayerData.source, ('Nouveau metier : %s (menu Mes metiers)'):format(QBCore.Shared.Jobs[args[2]].label), 'success')
    else
        notify(source, ({ plein = ('Deja %d metiers.'):format(Config.MaxJobs), invalide = 'Metier ou grade invalide.',
            incompatible = ('Incompatible avec %s.'):format(conflit or '?') })[raison] or 'Erreur.', 'error')
    end
end, Config.AdminGroup)

QBCore.Commands.Add('removejob', 'Retirer un metier a un joueur', {
    { name = 'id', help = 'ID du joueur' }, { name = 'job', help = 'Nom du metier' },
}, true, function(source, args)
    local cible = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not cible then return notify(source, 'Joueur introuvable.', 'error') end
    RemoveJob(cible.PlayerData.citizenid, args[2])
    notify(source, 'Metier retire.', 'success')
end, Config.AdminGroup)
