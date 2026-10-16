# pt-dj : cabines DJ du festival

Les tables de mixage des 3 scènes de l'Ultra Music Festival deviennent jouables : la musique (lien YouTube ou MP3)
est entendue par tous les joueurs autour de la scène, au même moment, avec un son qui baisse avec la distance.
Le son passe par **xsound** (dans `[standalone]`, démarre tout seul).

## Utilisation

1. Un admin allume le festival : `/festival on`.
2. Le DJ va à une table de mixage (marqueur violet sur la scène) et appuie sur **E**.
3. Menu :
   - **Jouer un morceau** : coller un lien YouTube (`https://www.youtube.com/watch?v=...`) ou un MP3 en ligne ;
   - **Ajouter à la file d'attente** : les morceaux s'enchaînent tout seuls (20 au maximum) ;
   - pause / reprendre, morceau suivant, volume, boucle, vider la file, arrêter ;
   - **effets** : fumée, canons à confettis, feux d'artifice (vus par tous les joueurs proches).
4. `/festival off` arrête la musique et ferme les cabines.

Les joueurs qui arrivent en cours de morceau l'entendent à partir du bon moment.

## Qui peut mixer

- Les admins, toujours.
- Un joueur invité : `/autoriserdj [id]` (jusqu'au prochain redémarrage), `/retirerdj [id]` pour retirer.
- Pour ouvrir une cabine à un métier ou à tout le monde : `config.lua` > `acces = { metiers = { dj = true } }`
  ou `acces = { tous = true }`.

## Réglages (`config.lua`)

- Ajouter une cabine ailleurs (boîte de nuit, bar) : copier un bloc de `Config.Cabines`, changer `id`, `coords`
  (la table de mixage), `son` (centre de la piste) et `portee`. Sans `evenement`, la cabine est toujours ouverte.
- Volume par défaut, délai entre deux effets, effets disponibles.

## Bon à savoir

- Chaque joueur peut couper toute la musique pour lui avec `/streamermode` (commande de xsound, utile en stream pour
  les droits d'auteur).
- Une vidéo YouTube dont l'intégration est bloquée par son auteur ne se lance pas : prendre un autre lien.

## Jeu de lumieres sur le tempo

Quand de la musique joue, chaque scene a son spectacle : projecteurs de couleur qui balayent le public et frappent sur
chaque temps, eventail de lasers qui tourne, stroboscope sur la derniere mesure de chaque phrase, lasers du decor qui
clignotent, fumee automatique toutes les 8 mesures.

**Analyse automatique du tempo** : a chaque morceau lance, le serveur decode les 2 premieres minutes (ffmpeg, et yt-dlp
pour YouTube), calcule le tempo et la position des temps forts, et le spectacle se cale dessus pour tout le monde
(quelques secondes apres le debut du morceau ; 128 BPM en attendant). Un morceau deja analyse n'est pas re-analyse.

L'analyse donne aussi le **profil du morceau** (8 minutes max) : la force de chaque coup de grosse caisse et l'energie de
chaque temps. Le spectacle s'en sert :
- **breaks / intros** (energie basse) : projecteurs doux et lents, pas de lasers ni de strobo, lasers du decor eteints ;
- **montee** (la mesure suivante est beaucoup plus forte) : stroboscope en croches ;
- **drop** (l'energie saute d'un coup) : confettis, feux d'artifice et fumee en meme temps ;
- **passages forts** : flash sur chaque vrai coup, plus de lasers, balayages rapides, couleur qui change a chaque temps.

Installation sur le VPS (une seule fois) :
```bash
sudo apt install -y ffmpeg
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```
Sans ffmpeg / yt-dlp, l'analyse echoue proprement (message dans la console) et le DJ cale le tempo a la main.
YouTube bloque parfois les serveurs (« confirm you're not a bot ») : dans ce cas, utiliser des liens MP3 ou le tap tempo.

Menu de la table de mixage :
- **Tempo** : affiche le tempo et sa source (analyse, manuel) ; cliquer = taper le tempo (8 fois E) ;
- **Relancer l'analyse du tempo** ;
- **Regler le tempo a la main** : BPM ;
- **Jeu de lumieres** et **Fumee automatique** : allumer / eteindre.

Reglages (couleurs, distance, frequence de la fumee) : `Config.Lumieres` dans `config.lua`. Positions optionnelles par
cabine : `projecteurs`, `lasers`, `public`.
