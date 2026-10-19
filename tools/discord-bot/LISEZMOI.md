# Bot Discord LUSO RP

Monte tout le Discord du serveur GTA RP en une commande (`/setup`) puis le fait vivre.

## Ce que fait `/setup`

- **Rôles** : Fondateur, Administrateur, Modérateur, Support, Bots, Police Nationale, Gendarmerie, Pompiers / SAMU,
  Mécano, Whitelisté, Citoyen, Muet.
- **Un rôle + un salon écrit + un salon vocal privés par gang** (Ballas, Vagos, Lost MC, Cosa Nostra, Yakuza…) et
  **un rôle + un salon par entreprise** (LS Customs, Benny's, Dynasty 8, Taxi, Reporter…), lus directement dans le
  projet FiveM (`qb-core/shared/gangs.lua` et `jobs.lua`) et dans la base (gangs / métiers vraiment utilisés par les
  joueurs). Un nouveau gang ajouté au serveur ? Relancer `/setup`.
- **Catégories et salons** avec les bonnes permissions : Accueil (bienvenue, règlement, annonces, mises à jour,
  statut), Communauté, Roleplay (candidature, annonces RP, twitter RP…), Services publics (privés par métier),
  Support (tickets, FAQ), Vocaux, Staff (whitelist, sanctions, logs).
- **Messages prêts** : règlement avec bouton « J'accepte », panneau de candidature, panneau de tickets, FAQ.

`/setup` seul ne supprime jamais rien : on peut le relancer à volonté (il complète et remet les permissions).

**`/setup supprimer_existant:True`** : repart de zéro. Après une confirmation par bouton, le bot **supprime tous
les salons (et leurs messages) et tous les rôles** (sauf `@everyone`, les rôles des autres bots et ceux au-dessus du
sien), puis recrée tout le Discord. Les membres restent mais perdent leurs rôles. **Irréversible.** Le bilan est envoyé
en message privé. Les salons imposés par le mode Communauté de Discord (règles, mises à jour) ne peuvent pas être
supprimés : désactive la Communauté avant si tu veux qu'ils partent aussi.

## En continu

- **Bienvenue** : embed avec avatar, numéro de membre, étapes à suivre (+ message privé).
- **Vérification** : bouton dans le règlement → rôle Citoyen → accès au Discord.
- **Whitelist** : formulaire (nom RP, âge, expérience, background) → salon staff avec Accepter / Refuser (raison
  envoyée au joueur en MP) → rôle Whitelisté.
- **Tickets** : salon privé joueur + staff, bouton Fermer, transcription envoyée dans les logs.
- **Statut FiveM** : joueurs connectés mis à jour chaque minute + bouton « Se connecter ».
- **Logs** : arrivées, départs, tickets, décisions whitelist.
- `/annonce` (staff) : annonce en embed dans Annonces, Mises à jour ou Annonces RP.

## Installation (sur le VPS, à côté de tes autres bots PM2)

1. **Créer le bot** sur https://discord.com/developers/applications → New Application → Bot → **Reset Token**
   (copie le jeton) et active **Server Members Intent**.
2. **L'inviter** : OAuth2 → URL Generator → `bot` + `applications.commands`, permission **Administrator** → ouvre le
   lien et choisis ton serveur.
3. **Base de données : créer un utilisateur en lecture seule** (ne jamais donner `root` au bot) :
   ```sql
   CREATE USER 'lusobot'@'localhost' IDENTIFIED BY 'un_mot_de_passe_solide';
   GRANT SELECT ON projectterrific.players TO 'lusobot'@'localhost';
   FLUSH PRIVILEGES;
   ```
4. Sur le VPS :
   ```bash
   cd /srv/BOTS/lusorp-bot        # le dossier ou tu as mis le bot
   cp .env.exemple .env && nano .env   # jeton, DB_URL (utilisateur lusobot), QBCORE_SHARED, CONNECT_URL
   npm install
   pm2 start ecosystem.config.js && pm2 save
   ```
5. Sur Discord : **glisse le rôle du bot tout en haut** de la liste des rôles (Paramètres du serveur → Rôles),
   puis tape **`/setup`**.
6. Donne-toi le rôle 👑 Fondateur.

Logs du bot : `pm2 logs lusorp-bot`. Les ids des salons créés sont gardés dans `data.json`.

## Personnaliser

- Salons, rôles, règlement, FAQ : `src/structure.js`, puis `/setup` à nouveau.
- Métiers sans salon (petits boulots) : `METIERS_SANS_SALON` dans `.env`.
- Image de l'embed de bienvenue : `IMAGE_BIENVENUE` dans `.env`.
