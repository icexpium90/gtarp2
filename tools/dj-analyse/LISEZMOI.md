# dj-analyse : service d'analyse du tempo pour pt-dj

FXServer interdit aux ressources de lancer des programmes (« Use --allow-child-process »). L'analyse du tempo
(ffmpeg + yt-dlp + calcul) tourne donc dans ce petit service, a cote du serveur de jeu, sur la meme machine.
pt-dj l'interroge en HTTP sur `127.0.0.1:30125` (jamais expose sur internet).

## Installation (une fois, sur le VPS)

```bash
cd /chemin/du/serveur/tools/dj-analyse
sudo bash installer.sh
```

Le script installe ffmpeg, python3-numpy et yt-dlp, puis cree et demarre le service `pt-dj-analyse`
(redemarre tout seul avec la machine).

- Etat : `systemctl status pt-dj-analyse` ; journal : `journalctl -u pt-dj-analyse -f`
- Test : `curl "http://127.0.0.1:30125/analyse?url=https://www.youtube.com/watch?v=..."`
- Les resultats sont gardes dans `cache_tempo.json` (un morceau n'est analyse qu'une fois).
- Mettre a jour yt-dlp si YouTube change : `sudo yt-dlp -U`
