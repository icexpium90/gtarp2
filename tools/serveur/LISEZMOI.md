# Mettre à jour FXServer (artifacts)

La build 3889 du jeu demande des artifacts FXServer récents. Deux scripts font la mise à jour vers la version
**recommended** (conseillée) publiée par Cfx.re, gardent une sauvegarde et relancent le serveur.

## Pourquoi pas directement dans txAdmin ?

txAdmin fait partie des artifacts : il signale qu'une mise à jour existe (bandeau sur le tableau de bord), mais il ne
peut pas remplacer les fichiers du programme qui le fait tourner. La mise à jour se fait donc :

- **chez un hébergeur avec panel** (Pterodactyl, ZAP-Hosting, OuiHeberg…) : choisir « recommended » (ou la dernière
  version) dans le réglage de version FXServer du panel, puis redémarrer ;
- **sur un VPS / serveur dédié** : avec les scripts ci-dessous, à la main ou de façon programmée.

## Linux (VPS)

```bash
chmod +x tools/serveur/maj_fxserver.sh
./tools/serveur/maj_fxserver.sh /home/fivem/fxserver recommended fivem.service
```

- 1er argument : le dossier qui contient `run.sh` et `alpine/`.
- 2e : `recommended` (défaut), `latest` ou `optional`.
- 3e (facultatif) : le service systemd à arrêter puis relancer.
- L'ancienne version est gardée dans `alpine_ancien/` (retour arrière : la remettre à la place de `alpine/`).
- Si la version installée est déjà la bonne, le script ne fait rien.

Service systemd d'exemple (`/etc/systemd/system/fivem.service`) qui lance txAdmin :

```ini
[Unit]
Description=FXServer + txAdmin
After=network.target mariadb.service

[Service]
User=fivem
WorkingDirectory=/home/fivem/fxserver
ExecStart=/home/fivem/fxserver/run.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Mise à jour automatique chaque lundi à 5 h 50 (`crontab -e`, l'utilisateur doit pouvoir lancer `sudo systemctl` sans mot de passe pour ce service) :

```
50 5 * * 1 /home/fivem/fxserver/maj_fxserver.sh /home/fivem/fxserver recommended fivem.service >> /home/fivem/maj_fxserver.log 2>&1
```

## Windows

```powershell
powershell -ExecutionPolicy Bypass -File tools\serveur\maj_fxserver.ps1 -FxDir "C:\FXServer\server" -Relancer "C:\FXServer\server\FXServer.exe"
```

- `-FxDir` : le dossier qui contient `FXServer.exe` (les artifacts, pas `server-data`).
- `-Canal` : `recommended` (défaut), `latest` ou `optional`.
- `-Relancer` : ce qui doit être relancé après la mise à jour (FXServer.exe, qui démarre txAdmin, ou votre `.bat`).
- Une copie de l'ancienne version est gardée dans `<dossier>_ancien`.
- Les archives `.7z` sont extraites avec 7-Zip s'il est installé, sinon avec `tar.exe` de Windows 10/11.

Automatique : Planificateur de tâches > Créer une tâche > déclencheur hebdomadaire > action
`powershell.exe` avec les arguments `-ExecutionPolicy Bypass -File "C:\FXServer\maj_fxserver.ps1" -FxDir "C:\FXServer\server" -Relancer "C:\FXServer\server\FXServer.exe"`.

## Conseils

- Gardez le canal **recommended** : `latest` contient des builds encore en test.
- Dans txAdmin, **Paramètres > Redémarrages programmés** : prévoyez un redémarrage quotidien ; programmez la mise à jour
  quelques minutes avant un de ces créneaux, à une heure creuse.
- Après une mise à jour, vérifiez la console : la ligne `sv_enforceGameBuild 3889` doit être acceptée.
- Ces scripts n'ont pas pu être testés depuis l'environnement de préparation (téléchargements Cfx.re bloqués) :
  lancez-les une première fois à la main.
