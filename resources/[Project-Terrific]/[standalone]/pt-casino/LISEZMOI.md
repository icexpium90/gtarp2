# pt-casino : Diamond Casino jouable (argent du jeu uniquement)

## Pour les joueurs

1. **Entrée** : devant la porte principale du Diamond Casino (marqueur doré), **E** pour entrer ; même chose dans le hall
   pour ressortir.
2. **Caisse** (dans le hall) : acheter des jetons (1 jeton = 1 $, liquide puis banque) ou les revendre contre du liquide.
3. **Jeux** (s'approcher et **E**) :
   - **Machine à sous** : 3 identiques = de x5 (cerises) à x500 (diamants), deux cerises = mise rendue ;
   - **Roulette européenne** : rouge / noir / pair / impair / 1-18 / 19-36 (x2), douzaine (x3), numéro plein (x36) ;
   - **Blackjack** contre le croupier : tirer, rester, doubler ; blackjack payé 3 pour 2, le croupier tire jusqu'à 17.
- Mise de 10 à 50 000 jetons. Tirages faits par le serveur (impossible à tricher côté joueur).
- L'avantage de la maison est comparable à un vrai casino (machines environ 92 % redistribués, roulette 97,3 %).

## Pour les admins (placer en jeu)

- `/casinopos entree` : devant la porte, dehors. `/casinopos sortie` : point d'arrivée dans le hall.
  `/casinopos caisse` : la caisse.
- `/casinojeu machine`, `/casinojeu roulette`, `/casinojeu blackjack` : ajoute un jeu à ta position (une table / machine du
  jeu est posée si le casino n'en a pas déjà une à cet endroit). `/casinojeu retirer` : retire le jeu le plus proche.
- Les positions sont gardées après un redémarrage. Réglages (mises, gains) : `config.lua`.

## Règles FiveM

Les jetons ne s'achètent qu'avec l'argent du jeu. Ne jamais vendre de jetons, de mises, de « tours gratuits » ou de
gains sur la boutique Tebex : les jeux d'argent en argent réel sont interdits par les conditions FiveM. Les conditions de
janvier 2026 sont ambiguës même pour un casino en argent du jeu : à surveiller.
