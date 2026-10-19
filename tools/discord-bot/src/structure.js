// Structure du serveur Discord LUSO RP : roles, categories, salons et qui peut voir / ecrire.
// Modifiable librement : /setup cree ce qui manque et ne supprime jamais rien.

const NOM = process.env.NOM_SERVEUR || 'LUSO RP';

// Roles, du plus haut au plus bas. perms : 'admin' | 'moderation' | 'aucune'
const ROLES = [
  { cle: 'fondateur', nom: '👑 Fondateur', couleur: 0xF1C40F, perms: 'admin', separe: true },
  { cle: 'admin', nom: '🛡️ Administrateur', couleur: 0xE74C3C, perms: 'admin', separe: true },
  { cle: 'modo', nom: '⚔️ Modérateur', couleur: 0xE67E22, perms: 'moderation', separe: true },
  { cle: 'support', nom: '🎧 Support', couleur: 0x3498DB, perms: 'aucune', separe: true },
  { cle: 'bots', nom: '🤖 Bots', couleur: 0x95A5A6, perms: 'aucune', separe: true },
  { cle: 'police', nom: '🚓 Police Nationale', couleur: 0x1F3A93, perms: 'aucune', separe: true },
  { cle: 'gendarmerie', nom: '🎖️ Gendarmerie', couleur: 0x2C3E50, perms: 'aucune', separe: true },
  { cle: 'secours', nom: '🚒 Pompiers / SAMU', couleur: 0xC0392B, perms: 'aucune', separe: true },
  { cle: 'mecano', nom: '🔧 Mécano', couleur: 0xD35400, perms: 'aucune', separe: true },
  { cle: 'whitelist', nom: '✅ Whitelisté', couleur: 0x2ECC71, perms: 'aucune', separe: false },
  { cle: 'citoyen', nom: '👤 Citoyen', couleur: 0xBDC3C7, perms: 'aucune', separe: false },
  { cle: 'muet', nom: '🔇 Muet', couleur: 0x7F8C8D, perms: 'aucune', separe: false },
];

const STAFF = ['fondateur', 'admin', 'modo', 'support'];

// acces : qui voit la categorie / le salon
//   'tous'      : tout le monde (meme non verifie)
//   'citoyens'  : membres verifies
//   'whitelist' : joueurs whitelistes
//   'staff'     : equipe
//   [cles]      : roles listes + staff
// ecriture : 'tous' (ceux qui voient) | 'staff' (lecture seule pour les autres)
const CATEGORIES = [
  {
    cle: 'accueil', nom: '📌 ACCUEIL', acces: 'tous',
    salons: [
      { cle: 'bienvenue', nom: '👋・bienvenue', ecriture: 'staff' },
      { cle: 'reglement', nom: '📜・règlement', ecriture: 'staff' },
      { cle: 'annonces', nom: '📢・annonces', ecriture: 'staff' },
      { cle: 'maj', nom: '🔄・mises-à-jour', ecriture: 'staff' },
      { cle: 'statut', nom: '📊・statut-serveur', ecriture: 'staff' },
    ],
  },
  {
    cle: 'communaute', nom: '💬 COMMUNAUTÉ', acces: 'citoyens',
    salons: [
      { cle: 'general', nom: '💬・général' },
      { cle: 'medias', nom: '📸・médias' },
      { cle: 'suggestions', nom: '💡・suggestions' },
      { cle: 'recherche', nom: '🤝・recherche-de-rp' },
    ],
  },
  {
    cle: 'roleplay', nom: '🎭 ROLEPLAY', acces: 'citoyens',
    salons: [
      { cle: 'candidature', nom: '📋・candidature-whitelist', ecriture: 'staff' },
      // alimentes par le serveur de jeu (webhooks pt-discord) : lecture seule sur Discord
      { cle: 'annoncesrp', nom: '📰・annonces-rp', ecriture: 'staff', acces: 'whitelist', webhook: 'annonces' },
      { cle: 'twitter', nom: '🐦・twitter-rp', ecriture: 'staff', acces: 'whitelist', webhook: 'twitter' },
      { cle: 'leboncoin', nom: '🛒・leboncoin', ecriture: 'staff', acces: 'whitelist', webhook: 'lbc' },
      { cle: 'entreprises', nom: '🏢・ouvertures-entreprises', ecriture: 'staff', acces: 'whitelist', webhook: 'entreprises' },
      { cle: 'illegal', nom: '🕶️・hrp-illégal', acces: 'whitelist' },
    ],
  },
  {
    cle: 'services', nom: '🚨 SERVICES PUBLICS', acces: ['police', 'gendarmerie', 'secours', 'mecano'],
    salons: [
      { cle: 'police', nom: '🚓・police', acces: ['police'] },
      { cle: 'gendarmerie', nom: '🎖️・gendarmerie', acces: ['gendarmerie'] },
      { cle: 'forces', nom: '🤝・forces-de-l-ordre', acces: ['police', 'gendarmerie'] },
      { cle: 'secours', nom: '🚒・secours', acces: ['secours'] },
      { cle: 'mecano', nom: '🔧・mécano', acces: ['mecano'] },
      { cle: 'vpolice', nom: '🚓 Radio Police', type: 'vocal', acces: ['police', 'gendarmerie'] },
      { cle: 'vsecours', nom: '🚒 Radio Secours', type: 'vocal', acces: ['secours'] },
    ],
  },
  {
    cle: 'support', nom: '🎫 SUPPORT', acces: 'tous',
    salons: [
      { cle: 'tickets', nom: '🎫・ouvrir-un-ticket', ecriture: 'staff' },
      { cle: 'faq', nom: '❓・faq', ecriture: 'staff' },
    ],
  },
  {
    cle: 'vocaux', nom: '🔊 VOCAUX', acces: 'citoyens',
    salons: [
      { cle: 'vgeneral', nom: '🔊 Général', type: 'vocal' },
      { cle: 'vrp1', nom: '🎭 RP 1', type: 'vocal', acces: 'whitelist' },
      { cle: 'vrp2', nom: '🎭 RP 2', type: 'vocal', acces: 'whitelist' },
      { cle: 'vattente', nom: '⏳ Attente support', type: 'vocal' },
      { cle: 'vsupport1', nom: '🎧 Support 1', type: 'vocal', acces: 'staff' },
      { cle: 'vsupport2', nom: '🎧 Support 2', type: 'vocal', acces: 'staff' },
    ],
  },
  {
    cle: 'staff', nom: '🛡️ STAFF', acces: 'staff',
    salons: [
      { cle: 'staffchat', nom: '💬・staff' },
      { cle: 'wldemandes', nom: '📋・whitelist-demandes' },
      { cle: 'sanctions', nom: '⚖️・sanctions' },
      { cle: 'logs', nom: '📁・logs', ecriture: 'staff' },
      { cle: 'vstaff', nom: '🔊 Réunion staff', type: 'vocal' },
    ],
  },
  { cle: 'ticketscat', nom: '📂 TICKETS', acces: 'staff', salons: [] },
];

const REGLEMENT = [
  ['1. Respect', 'Aucune insulte, discrimination, harcèlement ni menace, en jeu (HRP) comme sur Discord.'],
  ['2. Roleplay', 'Restez dans votre personnage. Pas de HRP en jeu sauf nécessité (utiliser /ooc ou le support).'],
  ['3. Interdits RP', 'Pas de Freekill, Freepunch, Carkill, Metagaming, Powergaming, ni de No Fear / No Pain RP.'],
  ['4. Vie du personnage', 'Après une mort RP, oubliez la scène (New Life Rule). Respectez la valeur de votre vie.'],
  ['5. Zones safe', 'Commissariats, hôpitaux et lieux publics signalés : aucune action illégale violente.'],
  ['6. Triche', 'Mods, macros, exploits de bugs ou duplication = bannissement définitif. Signalez les bugs au support.'],
  ['7. Staff', 'Les décisions du staff s\'appliquent. Toute contestation se fait calmement par ticket.'],
  ['8. Discord', 'Pas de pub, pas de spam, pas de contenu choquant. Pseudo Discord = nom RP ou pseudo correct.'],
];

const FAQ = [
  ['Comment rejoindre le serveur ?', 'Faites votre **candidature whitelist** dans 📋・candidature-whitelist. Une fois acceptée, connectez-vous via F8 → `connect` ou le bouton dans 📊・statut-serveur.'],
  ['Le jeu ne se lance pas / crash', 'Videz le cache FiveM (`%localappdata%/FiveM/FiveM.app/data/cache`), puis relancez. Si ça continue, ouvrez un ticket avec la capture d\'erreur.'],
  ['J\'ai perdu un objet / argent à cause d\'un bug', 'Ouvrez un ticket avec la date, l\'heure et une preuve (clip ou capture). Sans preuve, pas de remboursement.'],
  ['Comment rejoindre la police / les secours ?', 'Les recrutements sont annoncés dans 📰・annonces-rp. Le rôle Discord est donné après recrutement en jeu.'],
];

module.exports = { NOM, ROLES, STAFF, CATEGORIES, REGLEMENT, FAQ };
