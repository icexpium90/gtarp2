# Cartes : MLO, quartiers de gangs, éclairage, forêts

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
| pt-carte-malibu | Chumash, bord de mer (≈ -3223, 793) | **MLO** Malibu Mansion : garage 6 places, piscines intérieure et extérieure, studio, basket, héliport, ponton | villa de luxe (qbx_properties) |
| pt-carte-hlm | West Vinewood (≈ -498, 52) | immeuble HLM (1 736 objets) | immeuble d'appartements en shells, QG de gang |
| pt-carte-citylights | toute la carte | 4 421 éclairages LED de rues et d'autoroutes (version LOD bas, sans réglage du jeu) | ambiance de nuit |
| pt-carte-ikon | toute la carte | ikON Projects 3.08 : une quarantaine de MLO et retouches de bâtiments (voir plus bas) | entreprises, QG, lieux publics |
| pt-carte-ikon-cayo | Cayo Perico | portails et clôtures retirés, véhicules placés comme en ligne | île ouverte |
| pt-carte-mancave | La Mesa, entrepôt (entrée ≈ 806, -894) | **MLO** : showroom auto, garage VIP, mezzanine avec bar, cave à vin et billard, 3 portes sectionnelles automatiques | bien à vendre (qbx_properties), concession, QG |
| pt-carte-lively | plusieurs régions | Lively World Expansion : végétation et objets ajoutés (LOD optimisés, 3 Mo) | ambiance |
| pt-carte-gendarmerie-paleto | Paleto Bay, ancien bureau du shérif (≈ -449, 6013) | **MLO** Skotaz Modding : brigade de Gendarmerie complète (accueil, bureaux, cellules), abords refaits | Gendarmerie (prise de service, garage, menu patron) |
| pt-carte-commissariat-pn | sud de Pillbox Hill (≈ -290, -1060) | **MLO** NyRoYe : commissariat (accueil, bureaux, cellules, vestiaires, héliport). Le `server.lua` d'origine était une porte dérobée : il a été supprimé | Police Nationale |
| pt-carte-palmiers | Los Santos et Blaine County | 3 469 palmiers et plantes du jeu ajoutés | ambiance |
| pt-maploader : ultra_festival | plage de Vespucci (≈ -1331, -1311) | Ultra Music Festival : grande scène, écrans, enceintes, lasers, 55 danseurs (≈ 1 200 objets) | **événement : éteint par défaut**, `/festival on` |
| pt-maploader : mafia_mansion | Tongva Hills, domaine viticole (≈ -1899, 2044) | 23 voitures et 43 gardes de décor | QG de la Cosa Nostra |
| pt-maploader : underwater_hq | lac de Vinewood Hills (≈ -1041, 1045) | QG sous-marin + yacht-club, 2 042 objets, 8 téléporteurs | **désactivé par défaut** |

## ikON Projects (pt-carte-ikon)

Intérieurs MLO **à entrée libre** (porte ouverte) : Bean Machine (Magellan Ave, Morningwood, Heritage Way, Eclipse Medical
Tower, Peaceful St, Atlee St, Simmet Alley, observatoire), stations RON et 24/7, agences Maze Bank, bureaux de la
casse (Paleto, Grapeseed, Chiliad), bureau du port (Alpha Mail), club de yacht LSMYC, bureau de streaming (Vinewood),
grottes aménagées (labo et repaire du Lost MC).

Intérieurs **à téléporteur** (marqueur bleu, E ; en voiture pour les garages) : garage MOD (port, véhicules),
bureau Maibatsu, LSIA VIP (salon et garage), siège de Mors Mutual Insurance (et terrasse VIP), club souterrain (entrée
normale et VIP), bureau du Kortz Center, bureau du Vinewood Bowl, agence immobilière WOLFS, bureau de startup, laverie de
Pacific Bluffs, atelier Hawk & Little, serre « Smoke on the Water », dépôt Post OP de Paleto, QG de Gruppe Sechs,
hangar privé de LSIA, bureau Clucking Bell. Les 45 téléporteurs viennent du script solo de l'auteur (coordonnées
extraites), ils sont dans `pt-maploader/cartes/ikon_teleporteurs.lua`.

- **Appartement de Vespucci Beach** : pas de téléporteur public, c'est un bien immobilier à vendre
  (`/immo` > Lieux MLO disponibles).
- Non repris (propres au solo) : voyage payant vers Cayo Perico, réparation automatique au garage MOD et LSIA, scénarios
  de PNJ et `peds.meta`. Les émetteurs de musique (club) sont chargés.
- Le mod retouche des bâtiments du jeu (ouvertures de portes) : si un autre MLO payant occupe le même bâtiment, gardez-en
  un seul. `hei_ap1_02_strm_0` (aéroport) reste celui de qb-smallresources (mêmes objets, générateurs de voitures adaptés).
- `pt-carte-ikon-cayo` est séparé : s'il gêne un script de braquage de Cayo, ajoutez `stop pt-carte-ikon-cayo`.

## Forêts de San Andreas ([cartes-lourdes], désactivé par défaut)

13 766 arbres, buissons et cactus (nord : Paleto, mont Chiliad, Raton Canyon ; sud : Tongva, Vinewood Hills, Tataviam).
Version 5.7 « Legacy » (la v6 « Enhanced » n'est pas compatible FiveM), sans les modèles de reflets qui demandent un
shader modifié (les arbres ajoutés n'apparaissent simplement pas dans les reflets).
L'auteur prévient que, avec les cartes du mode en ligne (toujours chargées sur FiveM), le jeu peut atteindre ses limites
d'objets : activez-les après un essai à plusieurs joueurs, en décommentant `ensure [cartes-lourdes]` dans
`projectterrific.cfg`. En cas de plantage au chargement, recommentez la ligne.

## GTA V Remastered ([cartes-lourdes], désactivé par défaut)

`pt-carte-remastered` : 13 400 objets ajoutés par Larcius (3 400 palmiers, 5 000 arbres, buissons, cactus, mobilier
urbain), version 5.6 « Legacy », sans les modèles de reflets (même raison que les forêts). Il utilise les textures LOD
de `pt-vegetation-lod` (dans `[cartes]`, toujours chargé) et il est prévu pour aller avec les forêts (aucun doublon d'objets entre les deux).
47 Mo de plus à télécharger. Il démarre avec `ensure [cartes-lourdes]`, comme les forêts.
Si les palmiers semblent doublés quelque part avec `pt-carte-palmiers` ou `pt-carte-lively`, ajoutez
`stop pt-carte-palmiers` (ou `stop pt-carte-lively`).

## Mancave (pt-carte-mancave)

Les portes de garage s'ouvrent seules à l'approche. Le mod remplace les fichiers de cet entrepôt (bâtiment, collisions,
occlusion) : la collision du quartier `id2_15` était aussi modifiée par ikON (bureau Maibatsu, accessible par
téléporteur) ; c'est celle de la Mancave qui est gardée pour pouvoir entrer en voiture. Si quelque chose bloque dans le
bureau Maibatsu, prévenez-moi. Mise en vente : `/immo` > Lieux MLO disponibles > Mancave.

## Ultra Music Festival (événement)

Éteint par défaut : rien sur la plage tant qu'un admin ne l'allume pas. Pour tous les joueurs en même temps :
- `/festival on` : la scène, les écrans, les lasers et les danseurs apparaissent ;
- `/festival off` : tout disparaît (`/festival` seul bascule) ;
- `/evenement` : liste des cartes d'événement et leur état.

L'état est gardé après un redémarrage du serveur : pensez à l'éteindre à la fin. Les projecteurs « allumés » du pack
(qui remplaçaient des modèles du jeu partout sur la carte) ne sont pas repris.
Pour transformer une autre carte en événement : `evenement = true` dans son entrée de `pt-maploader/config.lua`.

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
- Poids à télécharger par les joueurs à la première connexion : environ 250 Mo pour `[cartes]` (dont ikON 122 Mo et
  Malibu 96 Mo), 60 Mo de plus pour les forêts et 47 Mo pour GTA V Remastered.
- La piscine du Malibu Mansion est décorative : l'auteur conseille un mod d'eau « nageable partout » qui remplace l'eau
  du jeu, non inclus.
- Ces cartes viennent de gta5-mods (auteurs : Patoche pour Ballas, Vagos et l'immeuble HLM, zaforr / Sarbatore pour
  Families, lafa2k pour la villa, mixtro pour le QG sous-marin, bsnk pour Malibu Mansion, ikON pour ikON Projects,
  VisualParadox pour CityLights, Larcius / JRod pour les forêts, Larcius / le__AK pour GTA V Remastered,
  tonilopez_6 pour la Mancave, Gidoxy pour Ultra Music Festival, l'équipe Lively World Expansion). Gardez les crédits et respectez leurs conditions.

## Caserne des sapeurs-pompiers (pt-maploader)

La caserne SDIS 45 (ZE45_GaminG, El Burro Heights ≈ 1176, -1470) est une carte Map Editor chargée par `pt-maploader`
(`cartes/caserne_sdis.lua`) : objets, véhicules et pompiers de décor. Le SAMU / pompiers y a une prise de garde et un
garage. L'auteur demande qu'on lui écrive avant d'utiliser sa caserne sur FiveM (Discord ZE45_GaminG).
