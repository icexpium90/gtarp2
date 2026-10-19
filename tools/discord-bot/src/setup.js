// /setup : cree (ou complete) tout le serveur Discord. Ne supprime jamais rien : relancer /setup est sans risque.
const {
  ChannelType, PermissionFlagsBits: P, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
} = require('discord.js');
const { NOM, ROLES, STAFF, CATEGORIES, REGLEMENT, FAQ } = require('./structure');
const store = require('./store');
const projet = require('./projet');
const fs = require('fs');

const COULEUR = 0xC9A227;

const PERMS_ROLE = {
  admin: [P.Administrator],
  moderation: [P.KickMembers, P.BanMembers, P.ModerateMembers, P.ManageMessages, P.MuteMembers, P.DeafenMembers,
    P.MoveMembers, P.ManageNicknames, P.ViewAuditLog, P.ManageThreads],
  aucune: [],
};

async function creerRoles(guild, journal) {
  const ids = store.get('roles', {});
  for (const r of ROLES) {
    let role = (ids[r.cle] && guild.roles.cache.get(ids[r.cle])) || guild.roles.cache.find((x) => x.name === r.nom);
    if (!role) {
      role = await guild.roles.create({
        name: r.nom, color: r.couleur, hoist: r.separe, permissions: PERMS_ROLE[r.perms], mentionable: true,
        reason: `${NOM} : setup automatique`,
      });
      journal.push(`➕ rôle ${r.nom}`);
    }
    ids[r.cle] = role.id;
  }
  store.set('roles', ids);
  return ids;
}

// liste des roles qui voient un salon selon son acces
function rolesAutorises(acces, roles) {
  const staff = STAFF.map((c) => roles[c]);
  if (acces === 'tous') return null; // tout le monde
  if (acces === 'citoyens') return [roles.citoyen, roles.whitelist, ...staff];
  if (acces === 'whitelist') return [roles.whitelist, ...staff];
  if (acces === 'staff') return staff;
  if (Array.isArray(acces)) return [...acces.map((c) => roles[c]), ...staff];
  return null;
}

function droits(guild, roles, acces, ecriture, vocal) {
  const staff = STAFF.map((c) => roles[c]);
  const vus = rolesAutorises(acces, roles);
  const ecrire = vocal ? [P.Connect, P.Speak] : [P.SendMessages, P.AddReactions, P.CreatePublicThreads];
  const ow = [];
  const ajouter = (id, allow = [], deny = []) => {
    const e = ow.find((o) => o.id === id);
    if (e) { e.allow.push(...allow); e.deny.push(...deny); } else ow.push({ id, allow: [...allow], deny: [...deny] });
  };
  // tout le monde
  if (vus) ajouter(guild.roles.everyone.id, [], [P.ViewChannel]);
  else ajouter(guild.roles.everyone.id, [P.ViewChannel], ecriture === 'staff' ? ecrire : []);
  // roles autorises
  for (const id of vus || []) {
    ajouter(id, [P.ViewChannel, ...(ecriture === 'staff' && !staff.includes(id) ? [] : ecrire)],
      ecriture === 'staff' && !staff.includes(id) ? ecrire : []);
  }
  // staff : toujours lecture + ecriture
  for (const id of staff) ajouter(id, [P.ViewChannel, ...ecrire, P.ReadMessageHistory]);
  // bots : partout
  ajouter(roles.bots, [P.ViewChannel, P.SendMessages, P.EmbedLinks, P.ReadMessageHistory, ...(vocal ? [P.Connect] : [])]);
  // muets : ni ecrire ni parler
  ajouter(roles.muet, [], [P.SendMessages, P.AddReactions, P.Speak, P.CreatePublicThreads, P.SendMessagesInThreads]);
  // dedoublonnage allow / deny
  return ow.map((o) => ({ id: o.id, allow: [...new Set(o.allow)], deny: [...new Set(o.deny)].filter((d) => !o.allow.includes(d)) }));
}

async function creerSalons(guild, roles, journal) {
  const ids = store.get('salons', {});
  await guild.channels.fetch();
  for (const cat of CATEGORIES) {
    let categorie = (ids[cat.cle] && guild.channels.cache.get(ids[cat.cle]))
      || guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && c.name === cat.nom);
    const owCat = droits(guild, roles, cat.acces, 'tous', false);
    if (!categorie) {
      categorie = await guild.channels.create({ name: cat.nom, type: ChannelType.GuildCategory, permissionOverwrites: owCat });
      journal.push(`➕ catégorie ${cat.nom}`);
    } else {
      await categorie.permissionOverwrites.set(owCat);
    }
    ids[cat.cle] = categorie.id;
    for (const s of cat.salons) {
      const vocal = s.type === 'vocal';
      const type = vocal ? ChannelType.GuildVoice : ChannelType.GuildText;
      const ow = droits(guild, roles, s.acces || cat.acces, s.ecriture || 'tous', vocal);
      let salon = (ids[s.cle] && guild.channels.cache.get(ids[s.cle]))
        || guild.channels.cache.find((c) => c.type === type && c.name === s.nom && c.parentId === categorie.id);
      if (!salon) {
        salon = await guild.channels.create({ name: s.nom, type, parent: categorie.id, permissionOverwrites: ow });
        journal.push(`➕ salon ${s.nom}`);
      } else {
        if (salon.parentId !== categorie.id) await salon.setParent(categorie.id, { lockPermissions: false });
        await salon.permissionOverwrites.set(ow);
      }
      ids[s.cle] = salon.id;
    }
  }
  store.set('salons', ids);
  return ids;
}

// message "panneau" : poste une fois, puis mis a jour (pas de doublon si /setup est relance)
async function panneau(guild, salonId, cle, contenu) {
  const salon = guild.channels.cache.get(salonId);
  if (!salon) return;
  const msgs = store.get('messages', {});
  if (msgs[cle]) {
    const ancien = await salon.messages.fetch(msgs[cle]).catch(() => null);
    if (ancien) { await ancien.edit(contenu); return; }
  }
  const m = await salon.send(contenu);
  msgs[cle] = m.id;
  store.set('messages', msgs);
}

async function posterPanneaux(guild, salons) {
  const lien = (cle) => `<#${salons[cle]}>`;
  await panneau(guild, salons.bienvenue, 'bienvenue', {
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle(`Bienvenue sur ${NOM} !`)
      .setDescription([
        `Serveur GTA V RolePlay français sur FiveM.`,
        '',
        `1️⃣ Lis et accepte le ${lien('reglement')} pour débloquer le Discord.`,
        `2️⃣ Fais ta candidature dans ${lien('candidature')}.`,
        `3️⃣ Une fois whitelisté, rejoins-nous en jeu : ${lien('statut')}.`,
        '',
        `Un souci ? ${lien('tickets')}`,
      ].join('\n'))],
  });
  await panneau(guild, salons.reglement, 'reglement', {
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle(`📜 Règlement de ${NOM}`)
      .setDescription('Le non-respect du règlement entraîne un avertissement, une exclusion ou un bannissement selon la gravité.')
      .addFields(REGLEMENT.map(([n, v]) => ({ name: n, value: v })))
      .setFooter({ text: 'En cliquant, tu confirmes avoir lu et accepté le règlement.' })],
    components: [new ActionRowBuilder().addComponents(
      new ButtonBuilder().setCustomId('verifier').setLabel("J'accepte le règlement").setEmoji('✅').setStyle(ButtonStyle.Success))],
  });
  await panneau(guild, salons.candidature, 'candidature', {
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle('📋 Candidature whitelist')
      .setDescription([
        'Pour jouer sur le serveur, remplis le formulaire en cliquant sur le bouton.',
        'Prends le temps de soigner ton **background** : c\'est lui qui fait la différence.',
        '',
        'Réponse du staff en message privé (garde tes MP ouverts).',
      ].join('\n'))],
    components: [new ActionRowBuilder().addComponents(
      new ButtonBuilder().setCustomId('wl_postuler').setLabel('Postuler').setEmoji('📝').setStyle(ButtonStyle.Primary))],
  });
  await panneau(guild, salons.tickets, 'tickets', {
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle('🎫 Support')
      .setDescription('Un bug, un remboursement, une plainte, une question ? Ouvre un ticket : un salon privé avec le staff sera créé.')],
    components: [new ActionRowBuilder().addComponents(
      new ButtonBuilder().setCustomId('ticket_ouvrir').setLabel('Ouvrir un ticket').setEmoji('🎫').setStyle(ButtonStyle.Primary))],
  });
  await panneau(guild, salons.faq, 'faq', {
    embeds: [new EmbedBuilder().setColor(COULEUR).setTitle('❓ Questions fréquentes')
      .addFields(FAQ.map(([n, v]) => ({ name: n, value: v })))],
  });
}

// Gangs et entreprises du projet FiveM : un role + un salon ecrit et un vocal prives chacun
const COULEURS_GANGS = [0x8E44AD, 0x27AE60, 0xF39C12, 0x16A085, 0xC0392B, 0x2980B9, 0xD35400, 0x7F8C8D, 0x2C3E50, 0xE84393];

function slug(t) {
  return t.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
}

async function creerProjet(guild, roles, journal) {
  const p = await projet.charger();
  if (p.erreurBase) journal.push(`⚠️ base MySQL inaccessible (${p.erreurBase}) : gangs / entreprises lus dans les fichiers seulement`);
  const ids = store.get('roles', {});
  const sal = store.get('salons', {});
  const groupes = [
    { cle: 'gangs', nom: '🔫 GANGS', prefixe: 'gang', liste: p.gangs, icone: '🔫', vocal: true },
    { cle: 'entreprisescat', nom: '🏢 ENTREPRISES', prefixe: 'job', liste: p.entreprises, icone: '💼', vocal: false },
  ];
  for (const g of groupes) {
    if (!g.liste.length) continue;
    // roles
    for (const [i, x] of g.liste.entries()) {
      const cleRole = `${g.prefixe}_${x.cle}`;
      const nom = `${g.icone} ${x.label}`.slice(0, 100);
      let role = (ids[cleRole] && guild.roles.cache.get(ids[cleRole])) || guild.roles.cache.find((r) => r.name === nom);
      if (!role) {
        role = await guild.roles.create({ name: nom, color: g.prefixe === 'gang' ? COULEURS_GANGS[i % COULEURS_GANGS.length] : 0x5D6D7E,
          hoist: false, mentionable: true, reason: `${NOM} : ${g.prefixe} du serveur FiveM` });
        journal.push(`➕ rôle ${nom}`);
      }
      ids[cleRole] = role.id;
      roles[cleRole] = role.id;
    }
    // categorie : visible par les membres de n'importe quel gang / entreprise
    const tous = g.liste.map((x) => `${g.prefixe}_${x.cle}`);
    const owCat = droits(guild, roles, tous, 'tous', false);
    let cat = (sal[g.cle] && guild.channels.cache.get(sal[g.cle]))
      || guild.channels.cache.find((c) => c.type === ChannelType.GuildCategory && c.name === g.nom);
    if (!cat) {
      cat = await guild.channels.create({ name: g.nom, type: ChannelType.GuildCategory, permissionOverwrites: owCat });
      journal.push(`➕ catégorie ${g.nom}`);
    } else await cat.permissionOverwrites.set(owCat);
    sal[g.cle] = cat.id;
    // salons prives par gang / entreprise
    for (const x of g.liste) {
      const cleRole = `${g.prefixe}_${x.cle}`;
      const types = [{ suffixe: '', type: ChannelType.GuildText, nom: `${g.icone}・${slug(x.label)}` }];
      if (g.vocal) types.push({ suffixe: '_v', type: ChannelType.GuildVoice, nom: `${g.icone} ${x.label}`.slice(0, 100) });
      for (const t of types) {
        const cleSalon = `${cleRole}${t.suffixe}`;
        const ow = droits(guild, roles, [cleRole], 'tous', t.type === ChannelType.GuildVoice);
        let c = (sal[cleSalon] && guild.channels.cache.get(sal[cleSalon]))
          || guild.channels.cache.find((y) => y.type === t.type && y.name === t.nom && y.parentId === cat.id);
        if (!c) {
          c = await guild.channels.create({ name: t.nom, type: t.type, parent: cat.id, permissionOverwrites: ow,
            topic: t.type === ChannelType.GuildText ? `Salon privé : ${x.label}${x.membres ? ` (${x.membres} membre(s) en jeu)` : ''}` : undefined });
          journal.push(`➕ salon ${t.nom}`);
        } else await c.permissionOverwrites.set(ow);
        sal[cleSalon] = c.id;
      }
    }
  }
  store.set('roles', ids);
  store.set('salons', sal);
  journal.push(`ℹ️ ${p.gangs.length} gang(s) et ${p.entreprises.length} entreprise(s) lus depuis : ${p.source}`);
}

// Webhooks des salons alimentes par le serveur de jeu (Twitter, Leboncoin, annonces RP, entreprises).
// Les liens sont ecrits dans webhooks.cfg (WEBHOOKS_CFG) que server.cfg charge avec : exec webhooks.cfg
async function creerWebhooks(guild, salons, journal) {
  const liens = {};
  for (const cat of CATEGORIES) {
    for (const s of cat.salons) {
      if (!s.webhook) continue;
      const c = guild.channels.cache.get(salons[s.cle]);
      if (!c || !c.fetchWebhooks) continue;
      const nom = `${NOM} - ${s.webhook}`;
      const existants = await c.fetchWebhooks().catch(() => null);
      let w = existants && existants.find((x) => x.name === nom && x.token);
      if (!w) {
        w = await c.createWebhook({ name: nom, reason: `${NOM} : liaison avec le serveur de jeu` });
        journal.push(`➕ webhook ${s.nom}`);
      }
      liens[s.webhook] = w.url;
    }
  }
  store.set('webhooks', liens);
  const lignes = [
    `# ${NOM} : webhooks Discord pour pt-discord (genere par le bot, ne pas partager)`,
    ...Object.entries(liens).map(([k, u]) => `set pt_webhook_${k} "${u}"`),
  ].join('\n') + '\n';
  if (process.env.WEBHOOKS_CFG) {
    try {
      fs.writeFileSync(process.env.WEBHOOKS_CFG, lignes, { mode: 0o600 });
      journal.push(`ℹ️ webhooks écrits dans ${process.env.WEBHOOKS_CFG} (server.cfg : exec webhooks.cfg, puis redémarrer)`);
    } catch (e) {
      journal.push(`⚠️ impossible d'écrire ${process.env.WEBHOOKS_CFG} : ${e.message}`);
    }
  } else {
    journal.push('ℹ️ WEBHOOKS_CFG non défini : utilise /webhooks pour récupérer les lignes à mettre dans server.cfg');
  }
  return lignes;
}

async function setup(guild) {
  const journal = [];
  const roles = await creerRoles(guild, journal);
  // le bot recoit le role Bots
  const moi = await guild.members.fetchMe();
  if (!moi.roles.cache.has(roles.bots)) await moi.roles.add(roles.bots).catch(() => {});
  const salons = await creerSalons(guild, roles, journal);
  await creerProjet(guild, roles, journal);
  await creerWebhooks(guild, salons, journal);
  await posterPanneaux(guild, salons);
  store.set('guildId', guild.id);
  return journal;
}

// Mode "supprimer_existant" (confirme par le proprietaire) : supprime les salons et roles existants
// (sauf @everyone, roles geres par Discord / d'autres bots, et roles au-dessus du bot), puis /setup recree tout.
async function reinitialiser(guild) {
  const bilan = { salons: 0, roles: 0, echecs: [] };
  await guild.channels.fetch();
  const salons = [...guild.channels.cache.values()].sort((a, b) => (a.type === ChannelType.GuildCategory) - (b.type === ChannelType.GuildCategory));
  for (const c of salons) {
    try { await c.delete(`${NOM} : reinitialisation`); bilan.salons += 1; } catch (e) { bilan.echecs.push(`#${c.name} (${e.message})`); }
  }
  await guild.roles.fetch();
  const moi = await guild.members.fetchMe();
  const plafond = moi.roles.highest.position;
  for (const r of guild.roles.cache.values()) {
    if (r.id === guild.roles.everyone.id || r.managed || r.position >= plafond) continue;
    try { await r.delete(`${NOM} : reinitialisation`); bilan.roles += 1; } catch (e) { bilan.echecs.push(`@${r.name} (${e.message})`); }
  }
  store.set('roles', {});
  store.set('salons', {});
  store.set('messages', {});
  return bilan;
}

module.exports = { setup, reinitialiser, COULEUR };
