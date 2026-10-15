local function argent(n)
    local s = tostring(math.floor(n))
    return '$' .. s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
end

local function joueursProches()
    local moi = PlayerId()
    local pos = GetEntityCoords(PlayerPedId())
    local ids = {}
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= moi and #(GetEntityCoords(GetPlayerPed(p)) - pos) <= Config.Distance then
            ids[#ids + 1] = GetPlayerServerId(p)
        end
    end
    if #ids == 0 then return {} end
    return lib.callback.await('pt-factures:noms', false, ids) or {}
end

-- Formulaire de facture (montant et motif pre-remplis pour les travaux LS Customs)
local function facturer(montant, motif)
    local r0 = lib.callback.await('pt-factures:peutFacturer', false) or {}
    local ok, info = r0[1], r0[2]
    if not ok then
        return lib.notify({ description = info or 'Vous ne pouvez pas facturer.', type = 'error' })
    end
    local proches = joueursProches()
    if #proches == 0 then
        return lib.notify({ description = 'Aucun client a proximite.', type = 'error' })
    end
    local options = {}
    for _, p in ipairs(proches) do
        options[#options + 1] = { value = tostring(p.id), label = ('%s (ID %d)'):format(p.nom, p.id) }
    end
    local r = lib.inputDialog('Facture - ' .. info, {
        { type = 'select', label = 'Client', options = options, default = options[1].value, required = true },
        { type = 'number', label = 'Montant ($)', default = montant, min = 1, required = true },
        { type = 'input', label = 'Motif', default = motif or '', placeholder = 'Reparation, peinture, transport...', max = 120 },
    })
    if not r then return end
    TriggerServerEvent('pt-factures:server:envoyer', tonumber(r[1]), tonumber(r[2]), r[3])
end

RegisterCommand('facture', function() facturer() end, false)
RegisterNetEvent('pt-factures:client:ouvrirFacture', function() facturer() end)
RegisterNetEvent('pt-factures:client:facturer', function(montant, motif)
    -- fin des travaux a l'atelier : le mecanicien choisit s'il facture le client
    local choix = lib.alertDialog({
        header = 'Facturer les travaux ?',
        content = ('Montant des modifications et reparations : **%s**.  \nEnvoyer la facture au client ?'):format(argent(montant)),
        centered = true,
        cancel = true,
        labels = { confirm = 'Facturer', cancel = 'Non' },
    })
    if choix == 'confirm' then facturer(montant, motif) end
end)

-- Facture recue : payer tout de suite ou plus tard (/factures, ou telephone > Factures)
RegisterNetEvent('pt-factures:client:recue', function(f)
    local choix = lib.alertDialog({
        header = 'Facture recue',
        content = ('**%s** (%s) vous facture **%s**.%s  \n  \nPayer maintenant ? Sinon : /factures ou telephone > Factures.')
            :format(f.metier, f.emetteur, argent(f.montant), f.motif and ('  \nMotif : ' .. f.motif) or ''),
        centered = true,
        cancel = true,
        labels = { confirm = 'Payer', cancel = 'Plus tard' },
    })
    if choix == 'confirm' then TriggerServerEvent('pt-factures:server:payer', f.id) end
end)

local function mesFactures()
    local liste = lib.callback.await('pt-factures:liste', false) or {}
    local options = {}
    local total = 0
    for _, f in ipairs(liste) do
        total = total + f.amount
        options[#options + 1] = {
            title = ('%s - %s'):format(argent(f.amount), f.metier or '?'),
            description = ('De %s%s'):format(f.sender or '?', f.motif and (' : ' .. f.motif) or ''),
            icon = 'file-invoice-dollar',
            onSelect = function()
                local ok = lib.alertDialog({ header = 'Payer la facture', content = ('Payer %s a %s ?'):format(argent(f.amount), f.metier or '?'),
                    centered = true, cancel = true, labels = { confirm = 'Payer', cancel = 'Annuler' } })
                if ok == 'confirm' then TriggerServerEvent('pt-factures:server:payer', f.id) end
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Aucune facture a payer', icon = 'check' } end
    lib.registerContext({ id = 'pt_factures_liste', title = ('Mes factures (%s)'):format(argent(total)), options = options })
    lib.showContext('pt_factures_liste')
end

RegisterCommand('factures', mesFactures, false)
RegisterNetEvent('pt-factures:client:mesFactures', mesFactures)

TriggerEvent('chat:addSuggestion', '/facture', 'Envoyer une facture a un client proche (metiers autorises, en service)')
TriggerEvent('chat:addSuggestion', '/factures', 'Voir et payer vos factures')
