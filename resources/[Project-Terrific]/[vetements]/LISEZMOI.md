# Vêtements ajoutés (packs « addon clothing »)

Les magasins de vêtements (illenium-appearance) affichent automatiquement **tous** les vêtements présents dans le jeu,
y compris ceux d'un pack ajouté : pas de liste à remplir. Les joueurs les achètent dans n'importe quelle boutique de
vêtements (blips sur la carte), au prix `Config.ClothingCost` (100 $ par passage en caisse, dans
`[core-important]/illenium-appearance/shared/config.lua`).

## Installer un pack

1. Placez le dossier du pack ici, dans `[vetements]`. Il doit contenir un `fxmanifest.lua` et un dossier `stream`
   (fichiers `mp_m_freemode_01_...^jbib_000_u.ydd`, `.ytd`, et souvent un `.ymt` ou un `.meta`).
2. Dans `projectterrific.cfg`, retirez le `#` devant `ensure [vetements]`.
3. Redémarrez le serveur (pas seulement la ressource : les joueurs doivent reconnecter pour télécharger les vêtements).

## À savoir

- **Packs « replace »** (qui remplacent des vêtements existants) : ils écrasent les vêtements d'origine, y compris les
  uniformes. Préférez les packs **addon**.
- **Poids** : un pack de plusieurs centaines de Mo rallonge le premier chargement de chaque joueur. Évitez les textures
  4K (fichiers `.ytd` de plus de 16 Mo).
- **Vêtements réservés** (police, gang…) : `[core-important]/illenium-appearance/shared/blacklist.lua`.
- **Plusieurs packs** : chaque pack doit avoir un nom de collection différent, sinon ils se remplacent entre eux.
