# pt-gangs : gangs et organisations

Gangs de rue, mafias et organisations avec un QG complet, une flotte de véhicules et un réglage admin entièrement en jeu.

## Gangs fournis

| Identifiant | Nom | Grades |
|---|---|---|
| ballas, families, vagos, marabunta, aztecas | gangs de rue | Recrue, Soldat, Lieutenant, Chef |
| lostmc | The Lost MC | Prospect, Membre, Sergent d'armes, Président |
| cartel | Cartel Madrazo | Halcón, Sicario, Lugarteniente, Patrón |
| triads | Triades | Recrue, Combattant, Bâton rouge, Tête de dragon |
| mafia | Cosa Nostra | Associé, Soldat, Capo, Consigliere, Parrain |
| schatten | Schattenkartell (mafia allemande) | Kurier, Soldat, Vollstrecker, Unterboss, Der Pate |
| sanguenwe | Sangue Nwè (mafia luso-martiniquaise) | Menino, Soldado, Tenente, Majò, Patrão |
| yakuza | Yakuza | Kobun, Shatei, Wakagashira, Saiko-komon, Oyabun |
| bratva | Bratva | Shestyorka, Boyevik, Brigadier, Sovietnik, Pakhan |

Le dernier grade est le chef : il a accès au menu du chef (recrutement, grades, argent du gang via qb-management).
D'autres gangs se créent en jeu avec `/gangadmin` > « Créer un gang ».

## Mettre en place un QG (admin)

Tapez `/gangadmin`, choisissez le gang, puis placez chaque point en vous tenant à l'endroit voulu :

| Point | Rôle |
|---|---|
| Entrée du QG | porte extérieure (marqueur pour les membres, blip sur la carte) |
| Intérieur (MLO / IPL) | où l'on arrive en entrant ; c'est aussi le point de sortie. Pour un MLO, placez-le juste à l'intérieur du bâtiment |
| Dépôt du gang | coffre partagé (`gang_<identifiant>`, 100 places) |
| Vestiaire | tenues enregistrées (illenium-appearance) |
| Menu du chef | qb-management, réservé au grade chef |
| Garage (menu) | sortir un véhicule de la flotte ; en voiture : ranger le véhicule |
| Sortie des véhicules | où apparaissent les véhicules (orientation = votre direction) |

**Sans MLO** : « Intérieur en shell » crée un intérieur sous l'entrée (entrepôt, garage, villa, ranch…). Placez ensuite le dépôt, le vestiaire et le menu du chef en vous tenant dans le shell.
Choisir un intérieur MLO/IPL retire le shell, et inversement.

## Flotte de véhicules

- `/gangadmin` > gang > « Flotte de véhicules » : ajouter un modèle (spawn code, y compris les voitures addon), son nom et le grade minimum.
- Les membres sortent les véhicules au garage : couleur du gang, plaque `PRÉFIXE + 4 chiffres`, plein fait, clés données automatiquement.
- `/gangcles [id]` : donner les clés d'un véhicule de la flotte à un autre membre du gang (à moins de 5 m).
- Ranger : revenir au point garage en voiture et appuyer sur E.

## Membres

- `/gangadmin` > gang > « Ajouter / modifier un membre » (ID serveur + grade), ou la commande QBCore `/setgang [id] [gang] [grade]`.
- Le chef recrute et promeut lui-même depuis son menu.

## Notes

- Nécessite OneSync (les clés ne sont données qu'après vérification du véhicule côté serveur).
- Le coffre utilise qb-inventory : comme tous les coffres qb-inventory, l'accès est contrôlé côté client (seuls les membres voient le point).
- Tables créées automatiquement : `pt_gangs`, `pt_gangs_points`, `pt_gangs_settings`, `pt_gangs_vehicles`.
