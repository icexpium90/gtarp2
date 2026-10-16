#!/bin/bash
# LUSO RP : installe le service d'analyse du tempo de pt-dj (a lancer une fois sur le VPS, en root ou avec sudo)
set -e
ICI="$(cd "$(dirname "$0")" && pwd)"
apt-get update -qq
apt-get install -y -qq ffmpeg python3 python3-numpy curl
curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
chmod a+rx /usr/local/bin/yt-dlp
UTIL="${SUDO_USER:-$(whoami)}"
cat > /etc/systemd/system/pt-dj-analyse.service <<UNIT
[Unit]
Description=LUSO RP - analyse du tempo pour pt-dj
After=network.target

[Service]
User=$UTIL
WorkingDirectory=$ICI
ExecStart=/usr/bin/python3 $ICI/analyse_tempo.py 30125
Restart=always
Nice=10

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now pt-dj-analyse
sleep 1
curl -s http://127.0.0.1:30125/ping && echo "  -> service d'analyse en marche"
