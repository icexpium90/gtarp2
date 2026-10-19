// Bot Discord LUSO RP : setup automatique du serveur, bienvenue, verification, whitelist, tickets, statut FiveM, logs
require('dotenv').config();
const {
  Client, GatewayIntentBits, Partials, Events, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
  ModalBuilder, TextInputBuilder, TextInputStyle, ChannelType, PermissionFlagsBits: P, SlashCommandBuilder,
} = require('discord.js');
const { setup, reinitialiser, COULEUR } = require('./setup');
const { NOM, STAFF } = require('./structure');
const store = require('./store');

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers, GatewayIntentBits.GuildMessages],
  partials: [Partials.GuildMember],
});

const roles = () => store.get('roles', {});
const salons = () => store.get('salons', {});
const salon = (guild, cle) => guild.channels.cache.get(salons()[cle]);
const estStaff = (membre) => membre.permissions.has(P.Administrator)
  || STAFF.some((c) => membre.roles.cache.has(roles()[c]));

async function log(guild, titre, texte, couleur = 0x95A5A6) {
  const c = salon(guild, 'logs');
  if (c) await c.send({ embeds: [new EmbedBuilder().setColor(couleur).setTitle(titre).setDescription(texte).setTimestamp()] }).catch(() => {});
}

// ---------------------------------------------------------------------------------------------------------------
// Commandes

const COMMANDES = [
  new SlashCommandBuilder().setName('setup').setDescription(`Crée / complète tout le Discord ${NOM} (rôles, salons, messages)`)
    .setDefaultMemberPermissions(P.Administrator)
    .addBooleanOption((o) => o.setName('supprimer_existant')
      .setDescription('SUPPRIME tous les salons et rôles actuels avant de tout recréer (confirmation demandée)')),
  new SlashCommandBuilder().setName('statut').setDescription('Affiche le statut du serveur FiveM'),
  new SlashCommandBuilder().setName('annonce').setDescription('Publie une annonce')
    .setDefaultMemberPermissions(P.ManageMessages)
    .addStringOption((o) => o.setName('titre').setDescription('Titre').setRequired(true))
    .addStringOption((o) => o.setName('message').setDescription('Texte (\\n pour aller à la ligne)').setRequired(true))
    .addStringOption((o) => o.setName('salon').setDescription('Où publier').addChoices(
      { name: 'Annonces', value: 'annonces' }, { name: 'Mises à jour', value: 'maj' }, { name: 'Annonces RP', value: 'annoncesrp' }))
    .addBooleanOption((o) => o.setName('everyone').setDescription('Mentionner @everyone')),
];

client.once(Events.ClientReady, async () => {
  console.log(`[bot] connecte : ${client.user.tag}`);
  const corps = COMMANDES.map((c) => c.toJSON());
  for (const guild of client.guilds.cache.values()) {
    await guild.commands.set(corps).catch((e) => console.error('[bot] commandes', guild.name, e.message));
  }
  client.user.setActivity(`${NOM} | /setup`);
  majStatut();
  setInterval(majStatut, 60 * 1000);
});

client.on(Events.GuildCreate, (guild) => guild.commands.set(COMMANDES.map((c) => c.toJSON())).catch(() => {}));

// ---------------------------------------------------------------------------------------------------------------
// Statut du serveur FiveM (info.json / players.json exposes par FXServer)

async function lireFiveM() {
  const ip = process.env.FIVEM_IP;
  if (!ip) return null;
  const base = `http://${ip}:${process.env.FIVEM_PORT || 30120}`;
  try {
    const opts = { signal: AbortSignal.timeout(5000) };
    const [info, joueurs] = await Promise.all([
      fetch(`${base}/info.json`, opts).then((r) => r.json()),
      fetch(`${base}/players.json`, opts).then((r) => r.json()),
    ]);
    return { enLigne: true, joueurs: joueurs.length, max: Number(info?.vars?.sv_maxClients) || Number(process.env.FIVEM_MAX) || 64 };
  } catch {
    return { enLigne: false, joueurs: 0, max: Number(process.env.FIVEM_MAX) || 64 };
  }
}

function embedStatut(s) {
  const e = new EmbedBuilder().setTitle(`📊 Statut de ${NOM}`).setTimestamp();
  if (!s) return e.setColor(0x95A5A6).setDescription('Statut non configuré (FIVEM_IP dans .env).');
  e.setColor(s.enLigne ? 0x2ECC71 : 0xE74C3C)
    .addFields(
      { name: 'Serveur', value: s.enLigne ? '🟢 En ligne' : '🔴 Hors ligne', inline: true },
      { name: 'Joueurs', value: `${s.joueurs} / ${s.max}`, inline: true },
    );
  if (process.env.CONNECT_URL) e.addFields({ name: 'Rejoindre', value: process.env.CONNECT_URL });
  return e;
}

function boutonsStatut() {
  if (!process.env.CONNECT_URL) return [];
  return [new ActionRowBuilder().addComponents(
    new ButtonBuilder().setStyle(ButtonStyle.Link).setLabel('Se connecter').setEmoji('🎮').setURL(process.env.CONNECT_URL))];
}

async function majStatut() {
  const guild = client.guilds.cache.get(store.get('guildId'));
  if (!guild) return;
  const c = salon(guild, 'statut');
  if (!c) return;
  const s = await lireFiveM();
  const contenu = { embeds: [embedStatut(s)], components: boutonsStatut() };
  const msgs = store.get('messages', {});
  const ancien = msgs.statut && await c.messages.fetch(msgs.statut).catch(() => null);
  if (ancien) await ancien.edit(contenu).catch(() => {});
  else {
    const m = await c.send(contenu).catch(() => null);
    if (m) { msgs.statut = m.id; store.set('messages', msgs); }
  }
  // nom du salon vocal / activite avec le nombre de joueurs
  if (s) client.user.setActivity(s.enLigne ? `${s.joueurs}/${s.max} joueurs sur ${NOM}` : `${NOM} : hors ligne`);
}

// ---------------------------------------------------------------------------------------------------------------
// Bienvenue / depart

client.on(Events.GuildMemberAdd, async (membre) => {
  const guild = membre.guild;
  const c = salon(guild, 'bienvenue');
  const s = salons();
  if (c) {
    const e = new EmbedBuilder().setColor(COULEUR)
      .setAuthor({ name: `Bienvenue sur ${NOM}`, iconURL: guild.iconURL() || undefined })
      .setTitle(`👋 Salut ${membre.user.username} !`)
      .setDescription([
        `Bienvenue ${membre}, tu es notre **${guild.memberCount}ᵉ membre** !`,
        '',
        `📜 Commence par accepter le <#${s.reglement}>`,
        `📋 Puis fais ta candidature dans <#${s.candidature}>`,
        `🎫 Une question ? <#${s.tickets}>`,
      ].join('\n'))
      .setThumbnail(membre.user.displayAvatarURL({ size: 256 }))
      .setImage(process.env.IMAGE_BIENVENUE || null)
      .setFooter({ text: `${NOM} • GTA V RolePlay` })
      .setTimestamp();
    await c.send({ content: `${membre}`, embeds: [e] }).catch(() => {});
  }
  // message prive
  await membre.send({
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle(`Bienvenue sur ${NOM} !`)
      .setDescription(`Pour accéder au Discord, accepte le règlement dans <#${s.reglement}>, puis postule pour la whitelist dans <#${s.candidature}>. Bon jeu !`)],
  }).catch(() => {});
  await log(guild, '📥 Arrivée', `${membre} (${membre.user.tag}) — compte créé <t:${Math.floor(membre.user.createdTimestamp / 1000)}:R>`, 0x2ECC71);
});

client.on(Events.GuildMemberRemove, async (membre) => {
  await log(membre.guild, '📤 Départ', `${membre.user?.tag || membre.id} a quitté le serveur.`, 0xE74C3C);
});

// ---------------------------------------------------------------------------------------------------------------
// Interactions

client.on(Events.InteractionCreate, async (it) => {
  try {
    if (!it.inGuild()) return;
    const guild = it.guild;

    // ---- commandes
    if (it.isChatInputCommand()) {
      if (it.commandName === 'setup' && it.options.getBoolean('supprimer_existant')) {
        if (it.user.id !== guild.ownerId && !it.member.permissions.has(P.Administrator)) {
          return it.reply({ content: 'Réservé au propriétaire / administrateurs.', ephemeral: true });
        }
        return it.reply({
          ephemeral: true,
          content: [
            '⚠️ **Tout supprimer et repartir de zéro ?**',
            `Les **${guild.channels.cache.size} salons** (et leurs messages) et tous les rôles (sauf ceux des autres bots et ceux au-dessus de moi) seront **définitivement supprimés**, puis le Discord ${NOM} sera recréé.`,
            'Les membres restent sur le serveur mais perdent leurs rôles. **Impossible à annuler.**',
          ].join('\n'),
          components: [new ActionRowBuilder().addComponents(
            new ButtonBuilder().setCustomId('reset_ok').setLabel('Oui, tout supprimer et recréer').setEmoji('🗑️').setStyle(ButtonStyle.Danger),
            new ButtonBuilder().setCustomId('reset_non').setLabel('Annuler').setStyle(ButtonStyle.Secondary))],
        });
      }
      if (it.commandName === 'setup') {
        await it.deferReply({ ephemeral: true });
        const journal = await setup(guild);
        await majStatut();
        return it.editReply(journal.length
          ? `✅ Setup terminé :\n${journal.slice(0, 40).join('\n')}${journal.length > 40 ? `\n… (+${journal.length - 40})` : ''}`
          : '✅ Tout était déjà en place : permissions et messages mis à jour.');
      }
      if (it.commandName === 'statut') {
        const s = await lireFiveM();
        return it.reply({ embeds: [embedStatut(s)], components: boutonsStatut(), ephemeral: true });
      }
      if (it.commandName === 'annonce') {
        const cle = it.options.getString('salon') || 'annonces';
        const c = salon(guild, cle);
        if (!c) return it.reply({ content: 'Salon introuvable : lance /setup.', ephemeral: true });
        const e = new EmbedBuilder().setColor(COULEUR).setTitle(it.options.getString('titre'))
          .setDescription(it.options.getString('message').replace(/\\n/g, '\n'))
          .setFooter({ text: `${NOM} • ${it.user.username}` }).setTimestamp();
        await c.send({ content: it.options.getBoolean('everyone') ? '@everyone' : undefined, embeds: [e] });
        return it.reply({ content: `Annonce publiée dans ${c}.`, ephemeral: true });
      }
    }

    // ---- boutons
    if (it.isButton()) {
      const [action, cible] = it.customId.split(':');

      if (action === 'reset_non') return it.update({ content: 'Annulé, rien n\'a été supprimé.', components: [] });
      if (action === 'reset_ok') {
        if (it.user.id !== guild.ownerId && !it.member.permissions.has(P.Administrator)) return it.reply({ content: 'Refusé.', ephemeral: true });
        await it.update({ content: '🗑️ Suppression en cours… Je t\'envoie le bilan en message privé (le salon actuel va disparaître).', components: [] });
        const auteur = it.user;
        const bilan = await reinitialiser(guild);
        const journal = await setup(guild);
        await majStatut();
        const texte = [
          `✅ **${NOM} : Discord recréé.**`,
          `Supprimés : ${bilan.salons} salon(s), ${bilan.roles} rôle(s).`,
          bilan.echecs.length ? `Non supprimés (protégés par Discord, ex. salons de la Communauté) : ${bilan.echecs.slice(0, 15).join(', ')}` : '',
          `Créés : ${journal.filter((l) => l.startsWith('➕')).length} éléments.`,
          'Pense à te redonner le rôle 👑 Fondateur.',
        ].filter(Boolean).join('\n');
        await auteur.send(texte.slice(0, 1900)).catch(() => {});
        await log(guild, '🗑️ Réinitialisation complète', `Par ${auteur}. ${bilan.salons} salons et ${bilan.roles} rôles supprimés, Discord recréé.`, 0xE74C3C);
        return;
      }

      if (action === 'verifier') {
        const r = roles().citoyen;
        if (!r) return it.reply({ content: 'Le serveur n\'est pas configuré (/setup).', ephemeral: true });
        if (it.member.roles.cache.has(r)) return it.reply({ content: 'Tu as déjà accepté le règlement ✅', ephemeral: true });
        await it.member.roles.add(r);
        await log(guild, '✅ Règlement accepté', `${it.member}`, 0x2ECC71);
        return it.reply({ content: `Merci ! Tu as maintenant accès au Discord. Prochaine étape : <#${salons().candidature}>`, ephemeral: true });
      }

      if (action === 'wl_postuler') {
        if (it.member.roles.cache.has(roles().whitelist)) return it.reply({ content: 'Tu es déjà whitelisté ✅', ephemeral: true });
        const m = new ModalBuilder().setCustomId('wl_form').setTitle('Candidature whitelist');
        const champ = (id, label, style, requis = true, max = 100) => new ActionRowBuilder().addComponents(
          new TextInputBuilder().setCustomId(id).setLabel(label).setStyle(style).setRequired(requis).setMaxLength(max));
        m.addComponents(
          champ('nom', 'Nom et prénom de ton personnage', TextInputStyle.Short),
          champ('age', 'Ton âge (réel)', TextInputStyle.Short, true, 3),
          champ('exp', 'Ton expérience en RP (serveurs, durée)', TextInputStyle.Paragraph, true, 500),
          champ('bg', 'Background de ton personnage', TextInputStyle.Paragraph, true, 1500),
          champ('steam', 'Pseudo FiveM / lien Steam (facultatif)', TextInputStyle.Short, false, 150),
        );
        return it.showModal(m);
      }

      if (action === 'wl_ok' || action === 'wl_non') {
        if (!estStaff(it.member)) return it.reply({ content: 'Réservé au staff.', ephemeral: true });
        if (action === 'wl_non') {
          const m = new ModalBuilder().setCustomId(`wl_refus:${cible}`).setTitle('Refuser la candidature');
          m.addComponents(new ActionRowBuilder().addComponents(new TextInputBuilder().setCustomId('raison')
            .setLabel('Raison (envoyée au joueur)').setStyle(TextInputStyle.Paragraph).setRequired(true).setMaxLength(500)));
          return it.showModal(m);
        }
        const membre = await guild.members.fetch(cible).catch(() => null);
        if (membre) {
          await membre.roles.add(roles().whitelist).catch(() => {});
          await membre.send({ embeds: [new EmbedBuilder().setColor(0x2ECC71).setTitle('✅ Candidature acceptée !')
            .setDescription(`Bienvenue dans l'aventure ${NOM} ! Tu peux maintenant te connecter au serveur.${process.env.CONNECT_URL ? `\n${process.env.CONNECT_URL}` : ''}`)] }).catch(() => {});
        }
        const e = EmbedBuilder.from(it.message.embeds[0]).setColor(0x2ECC71).setFooter({ text: `Acceptée par ${it.user.username}` });
        await it.update({ embeds: [e], components: [] });
        return log(guild, '📋 Whitelist acceptée', `<@${cible}> par ${it.member}`, 0x2ECC71);
      }

      if (action === 'ticket_ouvrir') {
        const cat = salons().ticketscat;
        const existant = guild.channels.cache.find((c) => c.parentId === cat && c.topic === it.user.id);
        if (existant) return it.reply({ content: `Tu as déjà un ticket ouvert : ${existant}`, ephemeral: true });
        const staff = STAFF.map((c) => roles()[c]).filter(Boolean);
        const c = await guild.channels.create({
          name: `ticket-${it.user.username}`.toLowerCase().replace(/[^a-z0-9-]/g, '').slice(0, 90),
          type: ChannelType.GuildText, parent: cat, topic: it.user.id,
          permissionOverwrites: [
            { id: guild.roles.everyone.id, deny: [P.ViewChannel] },
            { id: it.user.id, allow: [P.ViewChannel, P.SendMessages, P.AttachFiles, P.ReadMessageHistory] },
            ...staff.map((id) => ({ id, allow: [P.ViewChannel, P.SendMessages, P.AttachFiles, P.ReadMessageHistory] })),
            ...(roles().bots ? [{ id: roles().bots, allow: [P.ViewChannel, P.SendMessages] }] : []),
          ],
        });
        await c.send({
          content: `${it.user} ${staff.slice(0, 4).map((id) => `<@&${id}>`).join(' ')}`,
          embeds: [new EmbedBuilder().setColor(COULEUR).setTitle('🎫 Ticket ouvert')
            .setDescription('Explique ton problème en détail (date, heure, captures ou clips). Un membre du staff va te répondre.')],
          components: [new ActionRowBuilder().addComponents(
            new ButtonBuilder().setCustomId('ticket_fermer').setLabel('Fermer le ticket').setEmoji('🔒').setStyle(ButtonStyle.Danger))],
        });
        await log(guild, '🎫 Ticket ouvert', `${c} par ${it.user}`, 0x3498DB);
        return it.reply({ content: `Ticket créé : ${c}`, ephemeral: true });
      }

      if (action === 'ticket_fermer') {
        const proprio = it.channel.topic;
        if (!estStaff(it.member) && it.user.id !== proprio) return it.reply({ content: 'Tu ne peux pas fermer ce ticket.', ephemeral: true });
        await it.reply('🔒 Ticket fermé, suppression dans 5 secondes…');
        // transcription simple dans les logs
        const msgs = await it.channel.messages.fetch({ limit: 100 }).catch(() => null);
        if (msgs) {
          const texte = [...msgs.values()].reverse().filter((m) => !m.author.bot)
            .map((m) => `[${new Date(m.createdTimestamp).toLocaleString('fr-FR')}] ${m.author.username} : ${m.content}`).join('\n');
          const logs = salon(guild, 'logs');
          if (logs && texte) {
            await logs.send({ content: `🗂️ Transcription de **${it.channel.name}** (fermé par ${it.user.username})`,
              files: [{ attachment: Buffer.from(texte, 'utf8'), name: `${it.channel.name}.txt` }] }).catch(() => {});
          }
        }
        setTimeout(() => it.channel.delete().catch(() => {}), 5000);
        return;
      }
    }

    // ---- formulaires
    if (it.isModalSubmit()) {
      if (it.customId === 'wl_form') {
        const v = (id) => it.fields.getTextInputValue(id) || '—';
        const c = salon(guild, 'wldemandes');
        if (!c) return it.reply({ content: 'Le serveur n\'est pas configuré (/setup).', ephemeral: true });
        const e = new EmbedBuilder().setColor(0xF1C40F).setTitle(`📋 Candidature de ${it.user.username}`)
          .setThumbnail(it.user.displayAvatarURL())
          .addFields(
            { name: 'Joueur', value: `${it.user} (${it.user.id})` },
            { name: 'Personnage', value: v('nom'), inline: true },
            { name: 'Âge', value: v('age'), inline: true },
            { name: 'Expérience RP', value: v('exp').slice(0, 1024) },
            { name: 'Background', value: v('bg').slice(0, 1024) },
            { name: 'FiveM / Steam', value: v('steam') },
          ).setTimestamp();
        await c.send({ embeds: [e], components: [new ActionRowBuilder().addComponents(
          new ButtonBuilder().setCustomId(`wl_ok:${it.user.id}`).setLabel('Accepter').setEmoji('✅').setStyle(ButtonStyle.Success),
          new ButtonBuilder().setCustomId(`wl_non:${it.user.id}`).setLabel('Refuser').setEmoji('❌').setStyle(ButtonStyle.Danger))] });
        return it.reply({ content: '📨 Candidature envoyée ! Le staff te répondra en message privé.', ephemeral: true });
      }
      if (it.customId.startsWith('wl_refus:')) {
        const cible = it.customId.split(':')[1];
        const raison = it.fields.getTextInputValue('raison');
        const membre = await guild.members.fetch(cible).catch(() => null);
        if (membre) {
          await membre.send({ embeds: [new EmbedBuilder().setColor(0xE74C3C).setTitle('❌ Candidature refusée')
            .setDescription(`Raison : ${raison}\n\nTu peux retenter ta chance en améliorant ta candidature.`)] }).catch(() => {});
        }
        const e = EmbedBuilder.from(it.message.embeds[0]).setColor(0xE74C3C)
          .setFooter({ text: `Refusée par ${it.user.username} : ${raison}`.slice(0, 2000) });
        await it.update({ embeds: [e], components: [] });
        return log(guild, '📋 Whitelist refusée', `<@${cible}> par ${it.member} : ${raison}`, 0xE74C3C);
      }
    }
  } catch (e) {
    console.error('[bot] interaction', e);
    const msg = { content: `Erreur : ${e.message}`, ephemeral: true };
    if (it.deferred || it.replied) it.editReply(msg).catch(() => {}); else it.reply?.(msg).catch(() => {});
  }
});

if (!process.env.DISCORD_TOKEN) {
  console.error('[bot] DISCORD_TOKEN manquant : copie .env.exemple en .env et remplis-le.');
  process.exit(1);
}
client.login(process.env.DISCORD_TOKEN);
