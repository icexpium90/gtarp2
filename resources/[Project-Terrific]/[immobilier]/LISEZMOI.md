# Immobilier : qbx_properties adapté à QBCore + agence Dynasty 8

Maisons, appartements, immeubles, entrepôts, villas, bureaux et commerces à acheter ou à louer, avec ou sans MLO,
gérés par le métier **realestate** (agence Dynasty 8).
qb-houses et qb-realestatejob sont désactivés (rangés dans `resources/[Project-Terrific]/[desactive]`).

## L'agence (métier realestate)

| Grade | Nom | Droits |
|---|---|---|
| 0 | Stagiaire | voir les biens, créer un bien, proposer des contrats |
| 1 | Agent immobilier | idem |
| 2 | Agent commercial | + modifier prix / loyer / nom, ajouter des appartements, transférer, expulser |
| 3 | Courtier | idem |
| 4 | Directeur | + révision globale des prix (%), suppression d'un bien, gestion de l'entreprise |

- Bureau : agence immobilière MLO à Burton (blip sur la carte, entrée par le marqueur bleu dans la rue). Au point vert près de l'arrivée : **E** = menu de l'agence.
- Partout : `/immo` (ou le menu radial F1 > métier).
- **Gestion de l'entreprise** (directeur) : recrutement, grades, licenciement, compte de l'agence (qb-management).
- Embaucher : le directeur passe par la gestion de l'entreprise, ou un admin fait `/setjob [id] realestate [grade]`.
- Il faut être **en service** pour agir (menu de l'agence > Prendre le service).

### Argent

- Ventes, loyers, doubles de clés et changements de serrure vont sur le **compte de l'agence** (`realestate`).
- Contrat signé par l'intermédiaire d'un agent : l'agent touche une **commission** (10 % par défaut), le reste va à l'agence.
- Un agent peut accorder jusqu'à 15 % de remise ; le directeur sans limite.
- Réglages : `qbx_properties/config/server.lua` > `agence` (commission, achat direct à la porte autorisé ou non,
  impayés avant expulsion, prix des doubles et des serrures, grades).

### Menu de l'agence (`/immo`)

- **Biens à vendre / à louer / occupés / tous** : prix, occupant, prochain loyer, impayés. Pour chaque bien :
  - GPS ;
  - **Proposer la vente / un bail** : ID du client à côté de vous et prix négocié ; le client signe sur son écran ;
  - **Modifier prix, loyer ou nom** (loyer vide = bien à vendre) ; les locataires sont prévenus d'un changement de loyer ;
  - **Ajouter des appartements à cette porte** : crée N logements identiques (« Immeuble - Apt 1 », « Apt 2 »…).
    À la porte, les joueurs choisissent leur appartement dans une liste ;
  - **Ajuster les prix de cet immeuble (%)** (directeur) ;
  - Transférer à un joueur, Expulser / reprendre (serrure changée), Supprimer (directeur).
- **Révision globale des prix (%)** (directeur) : tous les loyers, tous les biens à vendre, ou tout.
  Exemple : +5 % sur les loyers = indexation annuelle.
- **Créer un bien à ma position** : même chose que `/createproperty`.
- **Lieux MLO disponibles** : bâtiments déjà présents sur la carte (Malibu Mansion, appartement de Vespucci Beach, villa moderne de `[cartes]`, maisons de Michael,
  Franklin, Lester, caravane de Trevor, appartement de Floyd…). GPS, puis « Créer le bien ici » devant la porte : nom et
  prix pré-remplis, vous entrez et validez le point d'arrivée avec E (pour l'appartement de Vespucci Beach, accessible
  seulement par téléportation, le point d'arrivée est déjà connu). La liste se complète dans
  `qbx_properties/config/shared.lua` > `lieux`.

## Créer un bien (agent ou admin)

1. Placez-vous devant la porte et tapez `/createproperty` (ou `/immo` > Créer un bien).
2. Faites défiler les intérieurs (aperçu en direct), puis validez :
   - **[MLO] Bâtiment existant** : pour un MLO ou n'importe quel bâtiment de la carte ;
   - **shells** (sans MLO) : appartement, maisons, ranch, villa, entrepôt, garage, bureau, magasin, container ;
   - **intérieurs du jeu** : appartements et maisons GTA Online, entrepôts, bunker, garages, clubhouses, boîte de nuit,
     penthouse et manoirs.
3. Nom, prix et, pour une location, l'intervalle de loyer en heures (vide = à vendre).
4. « Ajouter un garage » : visez l'emplacement de la voiture, flèches pour tourner, Entrée pour valider.
5. Pour un MLO : entrez dans le bâtiment, puis E pour valider le point d'arrivée.

Immeuble d'appartements : créez un premier logement, puis `/immo` > le bien > « Ajouter des appartements à cette porte ».
Avec des shells ou des intérieurs du jeu, chaque appartement est un espace séparé (les autres occupants sont masqués).
Avec un MLO, placez une sortie différente pour chaque appartement (Placer les points > Sortie).

## Pour les joueurs

- Devant la porte : E pour voir le bien (acheter, louer, sonner, entrer, ou choisir l'appartement).
- À l'intérieur, au point de sortie : E pour sortir, G pour gérer :
  - clés numériques (ajouter ou retirer des détenteurs) ;
  - **clés et serrures** : faire un **double de clé** (objet « Double de clé » à donner ou à prêter : il ouvre la porte et le
    coffre) et **changer les serrures** (tous les doubles distribués deviennent inutilisables) ;
  - sonnette, décoration (meubles), fin de location ;
  - **Placer les points** : vestiaire, déconnexion, sortie, et :
    - **Ajouter un coffre ici** (jusqu'à 5 par bien) : petit (30 places), moyen (50) ou grand / armurerie (80),
      avec un nom au choix (« Armurerie », « Cave »…). Armes, munitions, objets, billets marqués ;
    - **Retirer le coffre le plus proche** (à vider avant) ;
    - **Coffre-fort ici** : argent **propre** (déposer / retirer du liquide) et argent **sale** (dépose tous les
      billets marqués de l'inventaire, retrait en billets marqués). Accès : propriétaire, détenteurs de clés et
      doubles de clés.
- `/mesbiens` : vos biens et ceux dont vous avez la clé, avec le prochain loyer (GPS au clic).
- Le garage du bien apparaît quand on s'en approche (propriétaire et détenteurs de clés numériques).

## Loyers

- Le premier loyer est payé à la signature, les suivants sont prélevés automatiquement en banque à chaque échéance,
  même hors ligne (plus de double prélèvement au redémarrage du serveur).
- Loyer impayé : nouvelle tentative à l'échéance suivante ; après 2 impayés (réglable), expulsion automatique.

## Bon à savoir

- Pour les shells et les MLO, seule la sortie est placée à la création : le propriétaire (ou l'agent) place le coffre,
  le vestiaire et la déconnexion avec « Placer les points ».
- Les entrepôts et villas du jeu partent d'une position d'origine d'intérieur : le joueur est recalé au sol à l'entrée.
  Si la sortie tombe mal, replacez-la avec « Placer les points ».
- L'appartement de départ des nouveaux personnages reste géré par qb-apartments.
- Tables : `properties` (colonnes `serrure`, `next_rent`, `impayes` ajoutées automatiquement aux bases existantes),
  `properties_decorations`.
- Objet ajouté : `property_key` (qb-core/shared/items.lua, image dans qb-inventory).
