Config = {}

-- Objet necessaire (vendu dans les magasins de bricolage). false = pas d'objet requis.
Config.item = 'driftkey'

-- Permission ACE au lieu de l'objet (ex. add_ace group.admin driftmode.use allow)
Config.permissionsBased = false
Config.permissionName = 'driftmode.use'

-- Limiter a certains modeles / classes de vehicules
Config.vehicleWhitelist = false
Config.models = { 'adder' }
Config.vehicleClassWhitelist = false
Config.classes = { 0, 1, 2, 3, 4, 5, 6, 7 } -- https://docs.fivem.net/natives/?_0x29439776AAA00A62

-- Touche par defaut (chaque joueur peut la changer dans Parametres > Raccourcis > FiveM)
Config.defaultKey = 'F7'

-- Fumee sous les roues arriere pendant les glissades
Config.smoke = true
Config.smokeMinSpeed = 20.0  -- km/h
Config.smokeMinAngle = 10.0  -- degres entre la direction de la voiture et sa trajectoire

-- Explosions d'echappement a haut regime (desactive par defaut)
Config.twostep = false
