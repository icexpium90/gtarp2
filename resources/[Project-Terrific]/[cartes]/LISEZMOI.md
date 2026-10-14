# Cartes : quartiers de gangs, villa MLO, domaine mafia, QG sous-marin

Toutes les cartes de ce dossier démarrent avec `ensure [cartes]` (dans `projectterrific.cfg`).
Pour en retirer une, déplacez son dossier hors de `[cartes]` ou ajoutez `stop nom-de-la-ressource` après l'ensure.

| Ressource | Lieu | Contenu | Usage conseillé |
|---|---|---|---|
| pt-carte-ballas | Davis (≈ 81, -1961) | décor de quartier (309 objets) | QG des Ballas |
| pt-carte-vagos | Rancho (≈ 352, -2054) | décor de quartier (324 objets) | QG des Vagos |
| pt-carte-families | Grove Street (≈ -203, -1721) | décor de quartier + 3 ymaps du jeu modifiés | QG des Families |
| pt-carte-marabunta | El Burro Heights (≈ 1149, -1643) | décor (39 objets) | QG de la Marabunta |
| pt-carte-bloods | Vespucci Canals (≈ -1104, -1656) | « Gang District » (30 objets) | QG d'un gang créé en jeu, ou Sangue Nwè |
| pt-carte-villa-moderne | Tongva Hills (≈ -2654, 1321) | **MLO** : villa moderne avec intérieur et piscine | bien de luxe (qbx_properties) |
| pt-maploader : mafia_mansion | Tongva Hills, domaine viticole (≈ -1899, 2044) | 23 voitures et 43 gardes de décor | QG de la Cosa Nostra |
| pt-maploader : underwater_hq | lac de Vinewood Hills (≈ -1041, 1045) | QG sous-marin + yacht-club, 2 042 objets, 8 téléporteurs | **désactivé par défaut** |

## Brancher les QG de gangs

Allez sur place, puis `/gangadmin` > gang > placez l'entrée, l'intérieur (pour un MLO, juste à l'intérieur),
le dépôt, le vestiaire, le menu du chef et le garage. Voir `[gangs]/pt-gangs/LISEZMOI.md`.

## Mettre la villa moderne en vente

Agent immobilier ou admin : `/immo` > **Lieux MLO disponibles** > Villa moderne > GPS, puis devant la porte
« Créer le bien ici » (nom et prix pré-remplis), entrez dans la villa et validez avec E.

## pt-maploader (cartes Map Editor / Menyoo)

Les cartes solo au format XML (Map Editor, Menyoo Spooner) ne se streament pas comme des ymaps : elles sont converties
en données (`pt-maploader/cartes/*.lua`) et les objets sont créés chez chaque joueur à moins de 350 m, puis supprimés
quand il s'éloigne. Les véhicules sont verrouillés et indestructibles, les gardes sont passifs.
Réglages : `pt-maploader/config.lua` (`actif`, `vehicules`, `pnj`, distance d'apparition).

### QG sous-marin (underwater_hq)

Désactivé par défaut : c'est une carte très lourde (≈ 2 000 objets, chute de FPS annoncée par l'auteur), et elle crée
un lac en **remplaçant toute l'eau du jeu** par un `water.xml` de 2016 (chargé avec `LoadWaterFromPath`).
Pour l'essayer : `actif = true` dans `config.lua`, redémarrez la ressource, puis vérifiez l'eau ailleurs sur la carte
(ports, plages, Cayo Perico). En cas de souci, remettez `actif = false` : l'eau d'origine revient au redémarrage du jeu.

### Convertir une autre carte XML

```bash
python3 tools/cartes/convertir_carte.py "resources/[Project-Terrific]/[cartes]/pt-maploader/cartes/ma_carte.lua" ma_carte.xml [autre.xml ...]
```

Puis ajoutez une entrée dans `Config.Cartes`. Les pickups sont ignorés ; les marqueurs avec destination deviennent des
téléporteurs (E).

## Bon à savoir

- **pt-carte-families** remplace 3 ymaps du jeu (`lr_sc1_rd`, `lr_sc1_rd_strm_0`, `lr_sc1_10_strm_2` : routes et décor
  de Grove Street jusqu'à Davis). Ils datent d'avant la build 3889 : si un élément récent de Rockstar manque dans le
  secteur, supprimez le dossier `stream/remplacements` (le décor Families reste, avec quelques chevauchements possibles).
- Ces cartes viennent de gta5-mods (auteurs : Patoche pour Ballas et Vagos, zaforr / Sarbatore pour Families,
  lafa2k pour la villa, mixtro pour le QG sous-marin). Gardez les crédits et respectez leurs conditions.
