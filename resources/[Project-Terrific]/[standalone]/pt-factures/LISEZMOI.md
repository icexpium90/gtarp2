# pt-factures : factures des métiers

Un employé en service (mécano, EMS, taxi, dépanneuse, concession, avocat) envoie une facture à un client proche ;
le client la paie tout de suite ou plus tard. L'argent va au compte de l'entreprise (qb-management), moins une
commission versée à l'employé qui a facturé.

## Utilisation

- **Facturer** : `/facture` ou menu radial F1 > métier > **Facturer un client**. Choisir le client dans la liste des
  joueurs proches, le montant et le motif.
- **Le client** reçoit une fenêtre : **Payer** (banque, sinon liquide) ou **Plus tard**.
- **Payer plus tard** : `/factures`, menu radial F1 > Citizen > **Mes factures**, ou téléphone > application Factures.
- L'employé est prévenu du paiement et touche sa commission (s'il est connecté).

## LS Customs des mécaniciens (Burton)

Dans le LS Customs réservé aux mécaniciens, les pièces ne sont plus débitées au mécanicien : le script additionne le prix
de toutes les modifications et réparations faites. En fermant le menu, le mécanicien voit le total et peut l'envoyer
en facture au client (montant et motif pré-remplis, modifiables pour ajouter la main-d'œuvre).

## Réglages (`config.lua`)

- `Config.Metiers` : métiers autorisés, commission (0.10 = 10 %) et montant maximum.
- `Config.EnService` : obligation d'être en service. `Config.Distance` : distance maximum du client.

Les factures sont dans la table `phone_invoices` de qb-phone (colonne `motif` ajoutée automatiquement).
Le paiement depuis le téléphone passe aussi par pt-factures : montant lu en base et fonds vérifiés.
