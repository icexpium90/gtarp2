# Optimiseur de textures (voitures, MLO, cartes)

FiveM affiche `Asset ... uses XX MiB of physical memory. Oversized assets can and WILL lead to streaming issues`
quand un fichier de textures dépasse 16 Mo en mémoire. Résultat en jeu : textures qui ne chargent pas, voitures
invisibles ou grises, chutes de FPS. Ce script réduit les textures des `.ytd` jusqu'à passer sous la limite.

Déjà appliqué à tout le dépôt le 15/10/2026 : 70 fichiers `.ytd` ramenés sous 15 Mo (voitures addon et villa
moderne), par exemple `16challenger.ytd` 240 Mo → 15 Mo. Les fichiers d'origine restent dans l'historique git.

## Utilisation (sur le VPS ou un PC avec Python 3)

```bash
pip install etcpak texture2ddecoder pillow          # une seule fois (ajouter --break-system-packages si demandé)

# voir ce qui serait fait, sans rien modifier
python3 tools/optimiseur/optimiser_textures.py "resources/[Project-Terrific]/[vehicules]" --simulation

# appliquer (copie des originaux dans ./textures_originales)
python3 tools/optimiseur/optimiser_textures.py "resources/[Project-Terrific]/[vehicules]"

# un nouveau pack de voitures ou un MLO tout juste ajouté
python3 tools/optimiseur/optimiser_textures.py "resources/[Project-Terrific]/[cartes]/pt-carte-xxx"
```

Puis redémarrez le serveur. Les joueurs retéléchargent les fichiers modifiés (beaucoup plus légers).

| Option | Effet |
|---|---|
| `--cible 15` | taille visée par fichier en Mo (15 par défaut, marge sous la limite de 16) |
| `--min-dim 256` | ne jamais descendre une texture sous 256 px |
| `--forcer` | si la cible n'est pas atteinte, autorise jusqu'à 64 px |
| `--max-dim 2048` | réduit aussi toute texture plus grande que 2048 px, même dans un fichier sous la cible (allège le téléchargement) |
| `--simulation` | n'écrit rien |
| `--sans-sauvegarde` | pas de copie des originaux (seulement si vous avez une sauvegarde ailleurs) |

## Ce qu'il fait

- Il réduit toujours la plus grosse texture en premier, de moitié à chaque passe, jusqu'à la cible.
- Texture avec mipmaps : il retire les niveaux les plus grands, sans perte de qualité supplémentaire.
- Texture sans mipmaps : il la décode, la réduit (Lanczos, canal par canal pour ne pas abîmer l'alpha qui sert souvent
  de masque de brillance) et la ré-encode dans le même format (DXT1, DXT5, ATI1, ATI2, BC7, ARGB, L8 ; DXT3 → DXT5).
- Le fichier est relu après écriture ; s'il ne comprend pas la structure d'un fichier, il le laisse tel quel et le
  signale.

## Limites

- Seuls les `.ytd` (dictionnaires de textures) sont modifiés. À la fin, le script liste les `.yft`, `.ydr` et `.ydd`
  au-dessus de 16 Mo :
  - les jantes Dodge (`dodgewheels`, 20 à 64 Mo) ont leurs textures **intégrées** dans le modèle ;
  - plusieurs voitures (`.yft`, ~32 Mo) sont lourdes à cause de la **géométrie** (trop de polygones), pas des
    textures : seul un remodelage les allège.
- Une texture réduite est plus floue de près : sur une voiture, logos et compteurs perdent en netteté avant le reste.
  Si un rendu ne plaît pas, remettez l'original (`textures_originales/`) et relancez sur ce fichier seulement avec
  `--min-dim 512` : aucune texture ne descend sous 512 px, quitte à ce que le fichier reste un peu au-dessus de 16 Mo.
