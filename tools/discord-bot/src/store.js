// Petit stockage JSON (ids des roles, salons et messages crees par le bot)
const fs = require('fs');
const path = require('path');

const FICHIER = path.join(__dirname, '..', 'data.json');
let data = {};
try { data = JSON.parse(fs.readFileSync(FICHIER, 'utf8')); } catch { data = {}; }

function sauver() {
  fs.writeFileSync(FICHIER, JSON.stringify(data, null, 2));
}

module.exports = {
  get: (cle, defaut) => (data[cle] !== undefined ? data[cle] : defaut),
  set: (cle, valeur) => { data[cle] = valeur; sauver(); },
};
