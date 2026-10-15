# pt-illegal : points de deal, blanchisseur, armurier clandestin

Aucun de ces PNJ n'a d'icône sur la carte : il faut connaître les lieux (bouche-à-oreille en RP).
Interaction avec le **ciblage (ALT)** sur le PNJ.

## Points de deal (6)

Grove Street, Rancho, El Burro Heights, canaux de Vespucci, Sandy Shores, Paleto Bay.
- **Proposer de la marchandise** : le PNJ achète jusqu'à 10 unités de drogue (weed, joints, coke, crack, meth, ecstasy,
  oxy), payées en **billets marqués** (argent sale).
- Un même PNJ ne rachète qu'une fois toutes les 3 minutes (tous joueurs confondus).
- 25 % de chance d'alerte police (ps-dispatch) à chaque vente.
- Prix par drogue : `Config.Drogues`.

## Blanchisseur (derrière le Pawn Shop de Vinewood)

- **Faire nettoyer des billets** : reprend les billets marqués et rend **70 %** de leur valeur en liquide propre.
- De 10 000 $ minimum à 10 000 000 $ maximum par passage, un passage toutes les 10 minutes par joueur.

## Armurier clandestin (Stab City, caravanes au bord de l'Alamo Sea)

- **Parler** : armes sans permis (couteau à cran, poing américain, pistolets, pistolet-mitrailleur, micro SMG, fusil à
  canon scié, fusil compact) et munitions, **en liquide uniquement**, au prix du marché noir (2 à 3 fois
  l'Ammu-Nation : pistolet 2 200 $, micro SMG 8 000 $, fusil compact 12 000 $).
- Les armes n'ont pas de numéro enregistré au MDT de la police (contrairement à l'Ammu-Nation).
- Pour le réserver à certains gangs : `Config.Armurier.gangs = { ballas = true, vagos = true }`.

## Placer les PNJ

Les positions de départ sont approximatives. Un admin se place à l'endroit voulu, tourné dans la direction voulue, et tape :
- `/pnjillegal blanchisseur`, `/pnjillegal armurier`, `/pnjillegal deal1` … `deal6`
- `/pnjillegal` seul : liste des PNJ et de leur position.

La position est gardée après un redémarrage.

## Ammu-Nation (armes légales)

Toujours avec le permis de port d'arme (`/grantlicense`), à des prix proches du réel (`qb-shops/config.lua` >
`weapons`) : pistolet 650 $, pistolet SNS 450 $, pistolet vintage 900 $, munitions 40 $ la boîte, couteau 90 $, batte 60 $.
