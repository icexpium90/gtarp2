// Lecture du projet FiveM : gangs et metiers (qb-core/shared/*.lua) + ceux vraiment utilises en base (table players).
// Sert a creer un role + des salons prives par gang et par entreprise.
const fs = require('fs');
const path = require('path');

// metiers deja couverts par la categorie SERVICES PUBLICS, ou sans interet pour un salon
// + petits boulots interim (pas de salon dedie)
const METIERS_IGNORES = new Set(['unemployed', 'police', 'gendarmerie', 'ambulance',
  ...(process.env.METIERS_SANS_SALON || 'bus,garbage,hotdog,trucker,vineyard').split(',').map((x) => x.trim())]);

function lireLua(fichier) {
  try { return fs.readFileSync(fichier, 'utf8'); } catch { return null; }
}

// ['ballas'] = { label = 'Ballas', ...  ou  ballas = { label = "Ballas"
function extraire(code) {
  const liste = {};
  if (!code) return liste;
  const re = /\[?['"]?([A-Za-z0-9_]+)['"]?\]?\s*=\s*\{\s*(?:--[^\n]*\n\s*)*label\s*=\s*(['"])((?:\\.|(?!\2).)*)\2(?:[^}]*?type\s*=\s*['"]([a-z]+)['"])?/g;
  let m;
  while ((m = re.exec(code))) {
    liste[m[1]] = { cle: m[1], label: m[3].replace(/\\'/g, "'"), type: m[4] || null };
  }
  return liste;
}

async function depuisBase() {
  const url = process.env.DB_URL;
  if (!url) return { gangs: {}, jobs: {} };
  let mysql;
  try { mysql = require('mysql2/promise'); } catch { return { gangs: {}, jobs: {} }; }
  const co = await mysql.createConnection(url);
  try {
    const [lignes] = await co.query('SELECT job, gang FROM players');
    const gangs = {}; const jobs = {};
    const lire = (txt) => { try { return JSON.parse(txt || '{}'); } catch { return {}; } };
    for (const l of lignes) {
      const g = lire(l.gang); const j = lire(l.job);
      if (g.name && g.name !== 'none') {
        gangs[g.name] = gangs[g.name] || { cle: g.name, label: g.label || g.name, membres: 0 };
        gangs[g.name].membres += 1;
      }
      if (j.name && !METIERS_IGNORES.has(j.name)) {
        jobs[j.name] = jobs[j.name] || { cle: j.name, label: j.label || j.name, membres: 0, type: j.type || null };
        jobs[j.name].membres += 1;
      }
    }
    return { gangs, jobs };
  } finally {
    await co.end();
  }
}

// Renvoie { gangs: [...], entreprises: [...], source } ; les metiers d'un meme label (LS Customs x3) sont regroupes
async function charger() {
  const dossier = process.env.QBCORE_SHARED;   // ex. /root/fivem/server/txData/gtarp2/resources/[Project-Terrific]/[core-important]/qb-core/shared
  const gangsLua = dossier ? extraire(lireLua(path.join(dossier, 'gangs.lua'))) : {};
  const jobsLua = dossier ? extraire(lireLua(path.join(dossier, 'jobs.lua'))) : {};
  let base = { gangs: {}, jobs: {} };
  let erreurBase = null;
  try { base = await depuisBase(); } catch (e) { erreurBase = e.message; }

  const gangs = { ...gangsLua };
  for (const [k, g] of Object.entries(base.gangs)) gangs[k] = { ...(gangs[k] || {}), ...g, label: gangs[k]?.label || g.label };
  delete gangs.none;

  const jobs = { ...jobsLua };
  for (const [k, j] of Object.entries(base.jobs)) jobs[k] = { ...(jobs[k] || {}), ...j, label: jobs[k]?.label || j.label };
  for (const k of METIERS_IGNORES) delete jobs[k];

  // regroupement par label (plusieurs garages "LS Customs" -> une seule entreprise)
  const parLabel = {};
  for (const j of Object.values(jobs)) {
    const cle = j.label.toLowerCase();
    parLabel[cle] = parLabel[cle] || { cle: j.cle, label: j.label, metiers: [], membres: 0 };
    parLabel[cle].metiers.push(j.cle);
    parLabel[cle].membres += j.membres || 0;
  }
  return {
    gangs: Object.values(gangs).sort((a, b) => a.label.localeCompare(b.label)),
    entreprises: Object.values(parLabel).sort((a, b) => a.label.localeCompare(b.label)),
    source: [dossier ? 'fichiers qb-core' : null, process.env.DB_URL && !erreurBase ? 'base MySQL' : null].filter(Boolean).join(' + ') || 'aucune',
    erreurBase,
  };
}

module.exports = { charger, extraire };
