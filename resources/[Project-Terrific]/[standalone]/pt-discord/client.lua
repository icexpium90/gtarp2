-- aide des commandes dans le chat
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/annonce', 'Annonce RP de ton entreprise (en jeu + Discord)', { { name = 'message', help = 'Texte de l\'annonce' } })
    TriggerEvent('chat:addSuggestion', '/ouverture', 'Annonce l\'ouverture de ton entreprise', { { name = 'message', help = 'Facultatif (ex. horaires, promo)' } })
    TriggerEvent('chat:addSuggestion', '/fermeture', 'Annonce la fermeture de ton entreprise', { { name = 'message', help = 'Facultatif' } })
end)
