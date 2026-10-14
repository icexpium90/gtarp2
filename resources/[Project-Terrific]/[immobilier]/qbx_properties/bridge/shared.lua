-- Pont QBCore pour qbx_properties (Project Terrific)
-- Remplace qbx_core, ox_inventory et qbx_garages par QBCore, qb-inventory et qb-garages.
QBCore = exports['qb-core']:GetCoreObject()
Bridge = {}

-- Traductions : fichiers JSON imbriques -> cles a plat (ox_lib 3.6 ne gere pas les cles imbriquees)
do
    local resource = GetCurrentResourceName()
    local function charger(langue)
        local brut = LoadResourceFile(resource, ('locales/%s.json'):format(langue))
        return brut and json.decode(brut) or nil
    end
    local dico = {}
    local function aplatir(t, prefixe)
        for k, v in pairs(t) do
            local cle = prefixe and (prefixe .. '.' .. k) or k
            if type(v) == 'table' then aplatir(v, cle) else dico[cle] = v end
        end
    end
    aplatir(charger('en') or {})
    aplatir(charger(GetConvar('qbx_properties:locale', 'fr')) or {})

    function locale(cle, ...)
        local texte = dico[cle]
        if not texte then return cle end
        if select('#', ...) > 0 then return texte:format(...) end
        return texte
    end
end

-- Interieur de type MLO / batiment existant : coordonnees absolues saisies par l'agent immobilier
Bridge.MLO = 'mlo'
