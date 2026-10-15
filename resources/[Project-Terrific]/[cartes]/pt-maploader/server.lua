-- Cartes d'evenement (evenement = true dans config.lua) : allumees / eteintes par un admin, pour tous les joueurs.
-- L'etat est garde apres un redemarrage (il faut l'eteindre a la fin de l'evenement).

local evenements = {}
for _, carte in ipairs(Config.Cartes) do
    if carte.actif and carte.evenement then
        evenements[carte.nom] = carte
        GlobalState['pt_evenement_' .. carte.nom] = GetResourceKvpInt('evenement_' .. carte.nom) == 1
    end
end

local function estAdmin(src)
    if src == 0 then return true end
    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and QBCore and (QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')) then
            return true
        end
    end
    return IsPlayerAceAllowed(src, 'command')
end

local function message(src, texte, genre)
    if src == 0 then
        print('[pt-maploader] ' .. texte)
    else
        TriggerClientEvent('QBCore:Notify', src, texte, genre or 'primary', 6000)
    end
end

local function basculer(src, nom, choix)
    local carte = evenements[nom]
    if not carte then
        local noms = {}
        for n in pairs(evenements) do noms[#noms + 1] = n end
        message(src, ('Evenement inconnu. Disponibles : %s'):format(#noms > 0 and table.concat(noms, ', ') or 'aucun'), 'error')
        return
    end
    local cle = 'pt_evenement_' .. nom
    local allume
    if choix == 'on' then allume = true
    elseif choix == 'off' then allume = false
    else allume = not GlobalState[cle] end
    GlobalState[cle] = allume
    SetResourceKvpInt('evenement_' .. nom, allume and 1 or 0)
    message(src, ('%s : %s'):format(carte.label or nom, allume and 'ALLUME' or 'eteint'), allume and 'success' or 'primary')
    print(('[pt-maploader] %s %s par %s'):format(nom, allume and 'allume' or 'eteint', src == 0 and 'la console' or GetPlayerName(src)))
end

-- /evenement                      -> liste et etat
-- /evenement ultra_festival on|off
RegisterCommand('evenement', function(src, args)
    if not estAdmin(src) then return message(src, 'Reserve aux admins.', 'error') end
    if not args[1] then
        for nom, carte in pairs(evenements) do
            message(src, ('%s (%s) : %s'):format(nom, carte.label or '', GlobalState['pt_evenement_' .. nom] and 'allume' or 'eteint'))
        end
        return
    end
    basculer(src, args[1], args[2] and args[2]:lower())
end, false)

-- Raccourci : /festival on | off (sans argument : bascule)
RegisterCommand('festival', function(src, args)
    if not estAdmin(src) then return message(src, 'Reserve aux admins.', 'error') end
    basculer(src, 'ultra_festival', args[1] and args[1]:lower())
end, false)
