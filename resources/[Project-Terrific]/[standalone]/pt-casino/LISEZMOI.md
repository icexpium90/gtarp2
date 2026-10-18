# pt-casino : Diamond Casino jouable (argent du jeu uniquement)

## Pour les joueurs

1. **Entrée** : devant la porte principale du Diamond Casino (marqueur doré), **E** pour entrer ; même chose dans le hall
   pour ressortir.
2. **Caisse** (dans le hall) : acheter des jetons (1 jeton = 1 $, liquide puis banque) ou les revendre contre du liquide.
3. **Jeux** (s'approcher et **E**) :
   - **Machine à sous** : 3 identiques = de x5 (cerises) à x500 (diamants), deux cerises = mise rendue ;
   - **Roulette européenne** : rouge / noir / pair / impair / 1-18 / 19-36 (x2), douzaine (x3), numéro plein (x36) ;
   - **Blackjack** contre le croupier : tirer, rester, doubler ; blackjack payé 3 pour 2, le croupier tire jusqu'à 17.
   - **Three Card Poker** contre le croupier : ante, puis jouer (même mise) ou se coucher ; le croupier se qualifie avec
     une Dame haute ; bonus d'ante pour suite (x1), brelan (x4), quinte flush (x5) ;
   - **Courses de chevaux (Inside Track)** : 6 chevaux, cotes x3 à x15, course affichée à l'écran ;
   - **Roue de la fortune** (à côté de l'entrée du hall) : un tour gratuit par personnage et par jour ; jetons, liquide,
     ou la **voiture du podium** (livrée au parking du casino).
4. **Croupiers** derrière chaque roulette, table de blackjack et de poker : ils distribuent, lancent la bille et
   ramassent ; le joueur s'assoit à la table et la caméra passe au-dessus du tapis pendant la partie.
- Mise de 10 à 50 000 jetons. Tirages faits par le serveur (impossible à tricher côté joueur).
- L'avantage de la maison est comparable à un vrai casino (machines environ 92 % redistribués, roulette 97,3 %).

## Pour les admins (placer en jeu)

- `/casinopos entree` : devant la porte, dehors. `/casinopos sortie` : point d'arrivée dans le hall.
  `/casinopos caisse` : la caisse.
- `/casinojeu machine`, `/casinojeu roulette`, `/casinojeu blackjack`, `/casinojeu poker`, `/casinojeu courses` : ajoute un jeu à ta position (une table / machine du
  jeu est posée si le casino n'en a pas déjà une à cet endroit). `/casinojeu retirer` : retire le jeu le plus proche.
- Les positions sont gardées après un redémarrage. Réglages (mises, gains, cases de la roue, voiture du podium,
  chevaux, croupiers) : `config.lua`. Si la flèche de la roue ne tombe pas pile sur la case gagnée, régler
  `Config.Roue.decalageAngle` (par pas de 18°). Les gains sont toujours décidés par le serveur.

## Règles FiveM

Les jetons ne s'achètent qu'avec l'argent du jeu. Ne jamais vendre de jetons, de mises, de « tours gratuits » ou de
gains sur la boutique Tebex : les jeux d'argent en argent réel sont interdits par les conditions FiveM. Les conditions de
janvier 2026 sont ambiguës même pour un casino en argent du jeu : à surveiller.
