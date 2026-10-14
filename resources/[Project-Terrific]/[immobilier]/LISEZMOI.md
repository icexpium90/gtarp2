# Immobilier : qbx_properties adapté à QBCore

Maisons, appartements, entrepôts, villas, bureaux et commerces à acheter ou à louer, avec ou sans MLO.
qb-houses et qb-realestatejob sont désactivés (rangés dans `resources/[Project-Terrific]/[desactive]`).

## Créer un bien (agent immobilier ou admin)

1. Placez-vous devant la porte du bien et tapez `/createproperty`.
2. Faites défiler les intérieurs avec les flèches gauche/droite (aperçu en direct), puis validez :
   - **[MLO] Bâtiment existant** : pour un MLO ou n'importe quel bâtiment de la carte ;
   - **shells** (sans MLO) : appartement, maisons, ranch, villa, entrepôt, garage, bureau, magasin, container ;
   - **intérieurs du jeu** : appartements et maisons GTA Online, entrepôts, bunker, garages du cartel, clubhouses, boîte de nuit, penthouse et manoirs.
3. Renseignez le nom, le prix et, pour une location, l'intervalle de loyer en heures (vide = à vendre).
4. Option « Ajouter un garage » : visez l'emplacement de la voiture, flèches pour tourner, Entrée pour valider.
5. Pour un MLO : entrez dans le bâtiment, puis E pour valider le point d'arrivée.

## Pour les joueurs

- Devant la porte : E pour voir le bien (acheter, louer, sonner, entrer).
- À l'intérieur, au point de sortie : E pour sortir, G pour gérer :
  - clés (ajouter ou retirer des détenteurs) ;
  - sonnette (faire entrer un visiteur) ;
  - décoration (meubles) ;
  - **Placer les points** : coffre, vestiaire, déconnexion ou sortie, à votre position ;
  - arrêt de location.
- Le garage du bien apparaît quand on s'en approche (propriétaire et détenteurs de clés).

## Bon à savoir

- Pour les shells et les MLO, seule la sortie est placée à la création : le propriétaire (ou l'agent) place le coffre, le vestiaire et la déconnexion avec « Placer les points ».
- Les entrepôts et villas du jeu partent d'une position d'origine d'intérieur : le joueur est recalé au sol à l'entrée. Si la sortie tombe mal, replacez-la avec « Placer la sortie ici ».
- L'appartement de départ des nouveaux personnages reste géré par qb-apartments.
- Tables créées automatiquement : `properties`, `properties_decorations`.
