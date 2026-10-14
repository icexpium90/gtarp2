#!/usr/bin/env bash
# Met a jour les artifacts FXServer (Linux) vers la version "recommended" (ou "latest" / "optional").
#
# Usage :
#   ./maj_fxserver.sh /chemin/vers/fxserver [recommended|latest|optional] [service-systemd]
#
#   /chemin/vers/fxserver : dossier qui contient run.sh et alpine/
#   canal                 : recommended par defaut (conseille), latest = derniere build (moins testee)
#   service-systemd       : ex. fivem.service ; s'il est donne, le serveur est arrete puis relance
#
# Automatique (cron, chaque lundi a 5h50, avant un redemarrage txAdmin programme a 6h) :
#   50 5 * * 1 /chemin/maj_fxserver.sh /home/fivem/fxserver recommended fivem.service >> /home/fivem/maj_fxserver.log 2>&1
set -euo pipefail

FX_DIR="${1:?Indiquez le dossier FXServer (celui qui contient run.sh)}"
CANAL="${2:-recommended}"
SERVICE="${3:-}"
API="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"

case "$CANAL" in recommended|latest|optional) ;; *) echo "Canal inconnu : $CANAL"; exit 1;; esac
[ -f "$FX_DIR/run.sh" ] || { echo "run.sh introuvable dans $FX_DIR"; exit 1; }
command -v curl >/dev/null || { echo "curl est requis"; exit 1; }
command -v tar >/dev/null || { echo "tar est requis"; exit 1; }

JSON="$(curl -fsSL "$API")"
# extraction sans jq : "recommended": "1234" et "recommended_download": "https://..."
VERSION="$(printf '%s' "$JSON" | sed -n "s/.*\"$CANAL\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([0-9][0-9]*\).*/\1/p")"
URL="$(printf '%s' "$JSON" | sed -n "s/.*\"${CANAL}_download\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")"
[ -n "$VERSION" ] && [[ "$URL" == https://* ]] || { echo "Reponse de l'API inattendue"; exit 1; }

ACTUELLE="$(cat "$FX_DIR/.fxversion" 2>/dev/null || echo aucune)"
echo "Version installee : $ACTUELLE | $CANAL disponible : $VERSION"
if [ "$ACTUELLE" = "$VERSION" ]; then
    echo "Deja a jour."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Telechargement de $URL"
curl -fL --retry 3 -o "$TMP/fx.tar.xz" "$URL"
mkdir "$TMP/extrait"
tar -xJf "$TMP/fx.tar.xz" -C "$TMP/extrait"
[ -d "$TMP/extrait/alpine" ] || { echo "Archive invalide (pas de dossier alpine)"; exit 1; }

if [ -n "$SERVICE" ]; then
    echo "Arret de $SERVICE"
    sudo systemctl stop "$SERVICE"
fi

# sauvegarde de la version precedente (retour arriere : remettre alpine_ancien a la place d'alpine)
rm -rf "$FX_DIR/alpine_ancien"
[ -d "$FX_DIR/alpine" ] && mv "$FX_DIR/alpine" "$FX_DIR/alpine_ancien"
mv "$TMP/extrait/alpine" "$FX_DIR/alpine"
cp -f "$TMP/extrait/run.sh" "$FX_DIR/run.sh" 2>/dev/null || true
chmod +x "$FX_DIR/run.sh"
echo "$VERSION" > "$FX_DIR/.fxversion"
echo "FXServer mis a jour : $ACTUELLE -> $VERSION"

if [ -n "$SERVICE" ]; then
    echo "Redemarrage de $SERVICE"
    sudo systemctl start "$SERVICE"
fi
