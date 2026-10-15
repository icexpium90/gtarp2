#!/usr/bin/env bash
# Optimise toutes les textures du serveur (voitures, MLO, cartes) sous 16 Mo par fichier.
# Usage, depuis le dossier du serveur (celui qui contient resources/) :
#   bash tools/optimiseur/optimiser.sh              -> applique (originaux copies dans textures_originales/)
#   bash tools/optimiseur/optimiser.sh --simulation -> montre seulement ce qui serait fait
set -e
cd "$(dirname "$0")/../.."
if ! python3 -c "import etcpak, texture2ddecoder, PIL" 2>/dev/null; then
    echo "Installation des modules Python (etcpak, texture2ddecoder, pillow)..."
    python3 -m pip install --quiet etcpak texture2ddecoder pillow 2>/dev/null \
        || python3 -m pip install --quiet --break-system-packages etcpak texture2ddecoder pillow
fi
python3 tools/optimiseur/optimiser_textures.py resources --forcer "$@"
echo
echo "Termine. Redemarrez le serveur (txAdmin > Restart) pour que les joueurs recoivent les fichiers allégés."
