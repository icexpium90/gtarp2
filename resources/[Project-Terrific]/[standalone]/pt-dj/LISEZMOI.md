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

L'analyse tourne dans un petit service a cote du serveur (FXServer interdit aux ressources de lancer ffmpeg) :
installation une seule fois avec `sudo bash tools/dj-analyse/installer.sh` (voir `tools/dj-analyse/LISEZMOI.md`).
Sans ce service, l'analyse echoue proprement (message dans la console) et le DJ cale le tempo a la main.
YouTube bloque parfois les serveurs (« confirm you're not a bot ») : dans ce cas, utiliser des liens MP3 ou le tap tempo.

Menu de la table de mixage :
- **Tempo** : affiche le tempo et sa source (analyse, manuel) ; cliquer = taper le tempo (8 fois E) ;
- **Relancer l'analyse du tempo** ;
- **Regler le tempo a la main** : BPM ;
- **Jeu de lumieres** et **Fumee automatique** : allumer / eteindre.

Reglages (couleurs, distance, frequence de la fumee) : `Config.Lumieres` dans `config.lua`. Positions optionnelles par
cabine : `projecteurs`, `lasers`, `public`.

## Rampe lumiere (version « festival »)

Au-dessus de chaque scene, une rampe calculee automatiquement (ou positions donnees par cabine) :
- **16 lyres** avec faisceaux visibles dans l'air : une figure par mesure (eventail, croisement, cercles decales,
  ballyhoo), chenillard de couleurs sur les passages forts, blinder blanc sur les drops ;
- **10 stroboscopes** : double-croches qui accelerent pendant les montees, chenillard gauche-droite au plus fort,
  flash sur les gros coups ;
- **jets de CO2** au pied de la scene : tous ensemble sur les drops et toutes les 2 mesures au plus fort, en
  alternance sur les passages forts, et a la demande du DJ (menu > Effet : Jets de CO2) ;
- lasers (3 sources, jusqu'a 19 faisceaux chacune), confettis, feux d'artifice et fumee sur les drops.

Reglages dans `Config.Lumieres` : nombre de lyres et de strobos, largeur et hauteur de la rampe, faisceaux visibles,
effet et orientation des jets de CO2.

## Reaction par instrument (analyse v2)

Le service d'analyse decoupe le son par instrument, a chaque croche : kick, sub-bass, basse, accords (mid), lead,
growl, charley. Le spectacle s'en sert :
- **kick** : eclats des lyres, strobos, lasers qui claquent, jets de CO2 alternes sur les gros kicks ;
- **sub-bass** : lueur au sol qui pulse, lance-flammes sur les gros subs ;
- **basse** : ouverture de l'eventail de lasers ;
- **accords** : nappe de lumiere des lyres ; **les couleurs changent quand l'accord change** (au plus une fois par
  mesure), sinon toutes les 8 mesures ;
- **lead** : lasers qui montent, lyres vers le ciel, feux d'artifice sur les grosses leads ;
- **growl** : lasers vert / rouge en saccades depuis toute la rampe, lyres erratiques qui scintillent, flammes ;
- **charley** : etincelles des strobos.
Figures des lyres : 7 motifs (eventail, croisement, cercles, ballyhoo, vague, rideau, convergence) qui tournent
toutes les 2 mesures. CO2 incline vers le public (`co2.angleTir`), lance-flammes (`Config.Lumieres.flammes`),
boutons « Jets de CO2 » et « Lance-flammes » dans le menu du DJ.

Synchronisation : le spectacle suit la position reelle du lecteur de chaque joueur (xsound modifie : position lue
4 fois par seconde et lissee), donc il est cale sur ce que chacun entend, a quelques millisecondes pres.
Apres la mise a jour, relancer l'analyse des morceaux deja joues (les anciens resultats n'ont pas les instruments).

## Panneaux LED

Des motifs animes (spectre, vagues, chevrons, tunnel, damier, cercles, logo « LUSO RP » avec glitch sur les growls)
s'affichent par-dessus les panneaux LED existants, cales sur la musique comme les lumieres.
- `/ecranled ajouter [largeur] [hauteur]` (admin) : vise la surface du panneau et tape la commande ; l'ecran se colle
  dessus (taille en metres, 8 x 4,5 par defaut). Recommencer pour chaque panneau.
- `/ecranled retirer` : retire l'ecran le plus proche ; `/ecranled liste`.
- Les ecrans sont gardes apres un redemarrage. Sans musique, ils affichent le logo. Texte : `Config.TexteEcrans`.
