# Ajouter des voitures addon (Import Vehicle Shop)

Les voitures reelles (Renault, Alpine, BMW, Nissan, Honda, Toyota, Ford, Chevrolet, Dodge...) n'existent pas dans GTA V :
ce sont des mods addon a recuperer chez leurs auteurs. Ce dossier contient tout ce qu'il faut pour les integrer
et verifier qu'elles sont completes (bodykits, pieces moteur, conflits) avant de les mettre en ligne.

Elles sont vendues a l'**Import Vehicle Shop** (shop `tuner`, au port, `vector3(163.27, -3043.27, 5.10)`).

## Outils

| Outil | Role |
|---|---|
| `extraire_rpf.py dlc.rpf dossier` | decompresse un mod solo (dlc.rpf) pour recuperer modeles et .meta |
| `importer_pack.py dossier [dossier...]` | importe des voitures deja au format FiveM et corrige les conflits (kits, eclairages, handlings, libelles, pieces, layouts) |
| `nettoyer_kits.py ressource [--retirer modele]` | retire les options de bodykit sans fichier, ou un modele casse |
| `verifier_vehicules.py [--apply]` | verifie tout le dossier [vehicules] et ajoute les voitures valides au concessionnaire |

## Procedure

1. Placer chaque voiture dans son propre dossier : `resources/[Project-Terrific]/[vehicules]/<spawncode>/`
   avec `fxmanifest.lua` (modele : `modele_fxmanifest.lua`), `data/*.meta` et `stream/*.yft|*.ytd`.
2. Lancer le verificateur depuis la racine du serveur :
   `python3 tools/vehicules/verifier_vehicules.py`
   Il ecrit `tools/vehicules/rapport_vehicules.md`. Corriger toutes les lignes `ERREUR`.
3. Quand tout est OK : `python3 tools/vehicules/verifier_vehicules.py --apply`
   ajoute les voitures dans `qb-core/shared/vehicles.lua` (shop `tuner`, prix 150000 a ajuster).
4. Decommenter `ensure [vehicules]` dans `projectterrific.cfg`, puis redemarrer le serveur.

## Ce que le verificateur controle

| Point | Pourquoi |
|---|---|
| `data_file` presents dans le fxmanifest | sans eux, la voiture spawn avec le handling/tuning de base ou ne spawn pas |
| `.yft`, `_hi.yft`, `.ytd` dans `stream/` | modele invisible ou sans textures |
| `handlingId` existe dans `handling.meta` | voiture inconduisible |
| kits de `carvariations.meta` definis dans `carcols.meta` | aucun tuning au garage |
| chaque piece de bodykit (`visibleMods`, `linkedModels`) a son `.yft` | piece invisible une fois achetee |
| pieces moteur (`statMods`) : moteur, freins, boite, suspension, blindage | pas d'amelioration perf au mecano |
| id de kit unique sur tout le serveur, >= 1000 | sinon le menu de tuning affiche les pieces d'une autre voiture |
| spawn code different des 935 modeles du jeu (`modeles_jeu_de_base.txt`) | sinon il remplace la voiture du jeu |
| fichiers > 16 Mo | avertissement "oversized asset" et chargements lents |

## Liste demandee (a cocher au fur et a mesure)

**France** : Renault Megane 4 RS (Trophy / Trophy-R) · Alpine A110 (S, R, GT)

**BMW M jusqu'a 2025** : M1 · M3 E30 / E36 / E46 / E92 / F80 / G80 / G81 Touring · M4 F82 / G82 / CSL · M2 F87 / Competition / CS / G87 · 1M · M5 E28 / E34 / E39 / E60 / F10 / F90 / G90 · M6 E63 / F13 · M8 F92 · Z4 M / Z3 M Coupe · X3 M / X4 M · X5 M / X6 M · XM

**Nissan** : Skyline R32 / R33 / R34 GT-R · GT-R R35 (Nismo) · Silvia S13 / S14 / S15 · 180SX · Fairlady 240Z · 350Z · 370Z · Z (RZ34) · Patrol

**Honda** : Civic Type R EK9 / FD2 / FK8 / FL5 · Integra Type R DC2 · S2000 · NSX NA1 / NC1 · Prelude

**Toyota** : Supra A70 / A80 / A90 · AE86 Trueno/Levin · GR86 / GT86 · GR Yaris · Chaser JZX100 · MR2 · Celica · Land Cruiser

**Americaines** : Ford Mustang (GT, Shelby GT500) · Ford GT · F-150 Raptor · Chevrolet Camaro ZL1 · Corvette C7 / C8 · Silverado · Dodge Challenger / Charger (Hellcat, Demon) · Viper · RAM TRX · Jeep Wrangler / Grand Cherokee Trackhawk · Cadillac Escalade

## A savoir avant de telecharger

- Beaucoup de mods de voitures reelles sur gta5-mods.com interdisent l'utilisation sur serveur FiveM ou sont des
  conversions d'autres jeux : verifier la licence de l'auteur (ou acheter une version "FiveM ready") pour eviter un
  retrait du serveur.
- Les versions "FiveM ready / lore-friendly / optimisees" ont deja les bons fichiers et des textures < 16 Mo.
- Une voiture = un spawn code unique (ex. `m4g82`, `r34gtr`), jamais un nom du jeu de base.
