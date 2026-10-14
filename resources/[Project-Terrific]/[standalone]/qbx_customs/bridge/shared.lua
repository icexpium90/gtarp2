-- Pont QBCore pour qbx_customs (Project Terrific) : remplace qbx_core et le systeme de traduction d'ox_lib recent
QBCore = exports['qb-core']:GetCoreObject()

do
    local resource = GetCurrentResourceName()
    local dico = {}
    local function charger(langue)
        local brut = LoadResourceFile(resource, ('locales/%s.json'):format(langue))
        return brut and json.decode(brut) or nil
    end
    local function aplatir(t, prefixe)
        for k, v in pairs(t) do
            local cle = prefixe and (prefixe .. '.' .. k) or k
            if type(v) == 'table' then aplatir(v, cle) else dico[cle] = v end
        end
    end
    aplatir(charger('en') or {})
    aplatir(charger(GetConvar('qbx_customs:locale', 'fr')) or {})
    function locale(cle, ...)
        local texte = dico[cle]
        if not texte then return cle end
        if select('#', ...) > 0 then return texte:format(...) end
        return texte
    end
end

-- ox_lib 3.6 n'a pas lib.math.clamp
lib.math = lib.math or {}
lib.math.clamp = lib.math.clamp or function(v, mini, maxi) return math.max(mini, math.min(maxi, v)) end
