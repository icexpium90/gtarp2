local function menu()
    local data = lib.callback.await('pt-multijob:liste', false)
    if not data then return end
    local options = {}
    for _, m in ipairs(data.metiers) do
        options[#options + 1] = {
            title = (m.actif and '● ' or '') .. m.label,
            description = ('%s%s%s'):format(m.gradeLabel, m.salaire and (' | salaire $%d'):format(m.salaire) or '', m.actif and ' | actif' or ''),
            icon = 'briefcase',
            arrow = true,
            onSelect = function()
                local sous = {}
                if not m.actif then
                    sous[#sous + 1] = { title = 'Prendre ce metier', description = 'Devient votre metier actif (salaire, service, acces)', icon = 'right-to-bracket',
                        onSelect = function() TriggerServerEvent('pt-multijob:server:changer', m.job) end }
                end
                sous[#sous + 1] = { title = 'Demissionner', icon = 'door-open', onSelect = function()
                    local ok = lib.alertDialog({ header = m.label, content = ('Quitter definitivement votre poste de %s ?'):format(m.gradeLabel), centered = true, cancel = true })
                    if ok == 'confirm' then TriggerServerEvent('pt-multijob:server:quitter', m.job) end
                end }
                lib.registerContext({ id = 'pt_multijob_metier', title = m.label, menu = 'pt_multijob', options = sous })
                lib.showContext('pt_multijob_metier')
            end,
        }
    end
    if #options == 0 then
        options[1] = { title = 'Aucun metier', description = 'Passez a la mairie ou faites-vous embaucher', readOnly = true }
    end
    lib.registerContext({ id = 'pt_multijob', title = ('Mes metiers (%d/%d)'):format(#data.metiers, data.max), options = options })
    lib.showContext('pt_multijob')
end

RegisterCommand('metiers', menu, false)
RegisterNetEvent('pt-multijob:client:menu', menu)
TriggerEvent('chat:addSuggestion', '/metiers', 'Changer de metier actif (multi-metiers)')
