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
