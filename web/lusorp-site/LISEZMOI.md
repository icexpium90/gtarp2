# Site web LUSO RP (PHP + Apache) : rp.luostatis.fr

Page d'accueil du serveur : présentation, statut en direct (joueurs connectés), bouton « Se connecter »,
activités, galerie, FAQ, liens Discord. Aux couleurs du logo (noir, vert, rouge, or).

```
lusorp-site/
├── app/            config.php (à modifier), statut.php  -> jamais servi par Apache
├── public/         racine du site (index.php, api/status.php, assets/)
└── apache/         rp.luostatis.fr.conf (virtual host)
```

## 1. DNS

Chez le registrar de `luostatis.fr`, créer un enregistrement **A** : `rp` → IP du VPS.
(Vérifier l'orthographe du domaine : `luostatis.fr`.)

## 2. Installation sur le VPS (Debian / Ubuntu)

```bash
sudo apt update
sudo apt install -y apache2 php libapache2-mod-php php-gd certbot python3-certbot-apache
sudo a2enmod headers expires deflate rewrite

# copier le dossier lusorp-site sur le VPS (WinSCP / FileZilla), puis :
sudo mkdir -p /var/www/lusorp
sudo cp -r lusorp-site/app lusorp-site/public /var/www/lusorp/
sudo chown -R www-data:www-data /var/www/lusorp
# dossiers ou le site ecrit : donnees de l'admin et photos envoyees depuis /admin
sudo chmod -R u+rwX,g+rwX /var/www/lusorp/app/donnees /var/www/lusorp/public/assets/img

sudo cp lusorp-site/apache/rp.luostatis.fr.conf /etc/apache2/sites-available/
sudo a2ensite rp.luostatis.fr
sudo apache2ctl configtest && sudo systemctl reload apache2

# certificat HTTPS gratuit (Let's Encrypt), redirection http -> https automatique
sudo certbot --apache -d rp.luostatis.fr --redirect
```

Ouvrir les ports 80 et 443 du pare-feu si besoin : `sudo ufw allow 'Apache Full'`.

## 3. Réglages (`app/config.php`)

- `serveur_ip` / `serveur_port` : adresse du serveur FiveM (statut en direct et bouton « Se connecter »).
- `cfx_code` : code cfx.re du serveur (dans txAdmin) ; s'il est rempli, le bouton ouvre `cfx.re/join/...`.
- `discord`, `boutique` (Tebex, bouton masqué si vide), `reseaux` (YouTube, TikTok...).

Le statut est demandé au serveur FiveM (`http://IP:30120/dynamic.json`) par le serveur web lui-même, puis gardé
30 secondes en cache : les visiteurs ne contactent jamais directement le serveur de jeu. Si le site est sur le même VPS
que FiveM, rien d'autre à faire.

## 4. Administration des photos : rp.luostatis.fr/admin

Change la **photo de fond** de l'accueil et les **3 photos de la galerie** (JPG, PNG ou WEBP, 10 Mo maximum).

1. Première visite sur `https://rp.luostatis.fr/admin` : la page demande un **code d'installation**. Il est créé à ce
   moment-là sur le serveur, dans `/var/www/lusorp/app/donnees/code_installation.txt` :
   `sudo cat /var/www/lusorp/app/donnees/code_installation.txt` (ou l'ouvrir avec WinSCP / FileZilla).
2. Saisir ce code et choisir un mot de passe (10 caractères minimum). Le code est ensuite supprimé.
3. Connexions suivantes : mot de passe seul. 5 erreurs = blocage 15 minutes pour cette adresse IP.

Mot de passe oublié : supprimer `app/donnees/admin.json` sur le serveur, puis recommencer l'étape 1.
Les images sont ré-encodées à l'envoi (données cachées retirées). Sans photo, la galerie affiche un cadre aux couleurs du logo.

## 5. Mise à jour

Remplacer les fichiers de `public/` et `app/` sauf `app/config.php` et le dossier `app/donnees/` (mot de passe admin).
Les photos envoyées depuis /admin sont dans `public/assets/img/` : ne pas les écraser.
Après une modification du CSS ou du JS, augmenter le `?v=1` correspondant dans `index.php` pour vider le cache des navigateurs.
