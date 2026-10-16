// LUSO RP : contenu des panneaux LED (pt-dj). Rendu dans une texture du jeu (DUI) et affiche sur les ecrans places
// par les admins. Le jeu envoie le morceau (tempo, analyse par instrument) puis la position de lecture ~10 fois/s.
const cv = document.getElementById('c');
const g = cv.getContext('2d');
const W = cv.width, H = cv.height;

let M = null;                 // morceau : bpm, ancre, energie, coups, bandes{}, couleurs, palette[]
let tRef = 0, perfRef = 0, joue = false;
let texte = 'LUSO RP';

window.addEventListener('message', (ev) => {
    let d = ev.data;
    if (typeof d === 'string') { try { d = JSON.parse(d); } catch (e) { return; } }
    if (!d || !d.type) return;
    if (d.type === 'morceau') { M = d; texte = d.texte || texte; }
    if (d.type === 'temps') { tRef = d.t; perfRef = performance.now(); joue = d.joue; }
    if (d.type === 'arret') { joue = false; }
});

const lire = (ch, i) => (ch && i >= 0 && i < ch.length) ? (ch.charCodeAt(i) - 48) / 9 : null;
const hasard = (n, s) => { const x = Math.sin(n * 12.9898 + (s || 0) * 78.233) * 43758.5453; return x - Math.floor(x); };
const rgb = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a === undefined ? 1 : a})`;

function etat() {
    const t = joue ? tRef + (performance.now() - perfRef) / 1000 : tRef;
    const bpm = (M && M.bpm) || 128;
    const temps = (t - ((M && M.ancre) || 0)) * bpm / 60;
    const n = Math.floor(temps), croche = Math.floor(temps * 2);
    const B = (M && M.bandes) || {};
    const b = (k, def) => { const v = lire(B[k], croche); return v === null ? def : v; };
    const E = M ? (lire(M.energie, n) ?? 0.6) : 0.4;
    const pal = (M && M.palette) || [[255, 0, 120], [0, 180, 255], [140, 0, 255], [255, 60, 0], [0, 255, 120], [255, 255, 255]];
    const pi = M ? (lire(M.couleurs, n) !== null ? Math.round(lire(M.couleurs, n) * 9) : Math.floor(n / 32)) : 0;
    let drop = false;
    if (M && n % 4 === 0) {
        let av = 0; for (let k = n - 4; k < n; k++) av += (lire(M.energie, k) ?? 0);
        drop = E - av / 4 >= 0.44 && E >= 0.66;
    }
    return {
        t, temps, n, phase: temps - n, croche, pc: temps * 2 - croche, mesure: Math.floor(n / 4), E, drop,
        kick: b('kick', 1 - (temps - n)), sub: b('sub', 0.4), bass: b('bass', E), mid: b('mid', 0.5),
        lead: b('lead', 0.3), growl: b('growl', 0), high: b('high', 0),
        c1: pal[(pi * 2) % pal.length], c2: pal[(pi * 2 + 1) % pal.length], pi,
    };
}

// ---------------------------------------------------------------- motifs
function spectre(s) {
    const nb = 32, lw = W / nb;
    const val = [s.kick, s.sub, s.bass, s.mid, s.lead, s.high];
    for (let i = 0; i < nb; i++) {
        const k = val[Math.floor(i / nb * val.length)];
        const h = H * Math.min(1, 0.08 + k * (0.6 + 0.4 * hasard(s.croche, i)) * (1 - s.pc * 0.5));
        const grad = g.createLinearGradient(0, H, 0, H - h);
        grad.addColorStop(0, rgb(s.c1)); grad.addColorStop(1, rgb(s.c2));
        g.fillStyle = grad;
        for (let y = H; y > H - h; y -= 18) g.fillRect(i * lw + 3, y - 14, lw - 6, 14);   // pixels LED
    }
}
function vagues(s) {
    for (let x = 0; x < W; x += 16) {
        const v = 0.5 + 0.5 * Math.sin(x / 90 - s.t * (1 + 3 * s.E));
        g.fillStyle = v > 0.5 ? rgb(s.c1, 0.3 + 0.7 * v) : rgb(s.c2, 0.3 + 0.7 * (1 - v));
        g.fillRect(x, 0, 14, H);
    }
}
function chevrons(s) {
    const dec = (s.temps % 1) * 120;
    g.lineWidth = 34;
    for (let k = -2; k < 10; k++) {
        const x = k * 120 + dec;
        g.strokeStyle = k % 2 ? rgb(s.c1) : rgb(s.c2);
        g.beginPath(); g.moveTo(W / 2 - x, 0); g.lineTo(W / 2 - x - 160, H / 2); g.lineTo(W / 2 - x, H); g.stroke();
        g.beginPath(); g.moveTo(W / 2 + x, 0); g.lineTo(W / 2 + x + 160, H / 2); g.lineTo(W / 2 + x, H); g.stroke();
    }
}
function tunnel(s) {
    const z = (s.temps % 1);
    for (let k = 8; k >= 0; k--) {
        const f = ((k + z) / 9);
        const w = W * f * f * 1.6, h = H * f * f * 1.6;
        g.strokeStyle = k % 2 ? rgb(s.c1, 0.4 + 0.6 * s.kick) : rgb(s.c2, 0.4 + 0.6 * s.kick);
        g.lineWidth = 6 + 22 * f;
        g.strokeRect(W / 2 - w / 2, H / 2 - h / 2, w, h);
    }
}
function damier(s) {
    const c = 64;
    for (let x = 0; x < W; x += c) for (let y = 0; y < H; y += c) {
        const on = hasard(s.croche * 7 + x * 3 + y, 3) < 0.25 + 0.5 * s.high;
        if (on) { g.fillStyle = (x / c + y / c) % 2 ? rgb(s.c1) : rgb(s.c2); g.fillRect(x + 4, y + 4, c - 8, c - 8); }
    }
}
function logo(s, glitch) {
    const taille = 150 + 60 * s.kick;
    g.font = `900 ${taille}px Arial Black, Arial, sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    if (glitch) {
        for (let k = 0; k < 6; k++) {
            const y = hasard(s.croche * 4 + k, 9) * H;
            const h = 20 + 40 * hasard(s.croche, k);
            g.save(); g.beginPath(); g.rect(0, y, W, h); g.clip();
            g.fillStyle = k % 2 ? 'rgb(255,0,60)' : 'rgb(0,255,120)';
            g.fillText(texte, W / 2 + (hasard(s.croche, k + 20) - 0.5) * 120, H / 2);
            g.restore();
        }
    }
    g.fillStyle = rgb(s.c1); g.fillText(texte, W / 2 - 6, H / 2 + 4);
    g.fillStyle = '#fff'; g.fillText(texte, W / 2, H / 2);
}
function cercles(s) {
    for (let k = 0; k < 6; k++) {
        const r = ((s.temps * 0.5 + k / 6) % 1) * W * 0.7;
        g.strokeStyle = k % 2 ? rgb(s.c1, 1 - r / (W * 0.7)) : rgb(s.c2, 1 - r / (W * 0.7));
        g.lineWidth = 24;
        g.beginPath(); g.arc(W / 2, H / 2, r, 0, Math.PI * 2); g.stroke();
    }
}
const MOTIFS = [spectre, vagues, chevrons, tunnel, damier, cercles];

function image() {
    requestAnimationFrame(image);
    const s = etat();
    g.globalAlpha = 1;
    g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
    if (!joue) {                                 // pas de musique : logo calme
        s.kick = 0.2 + 0.1 * Math.sin(performance.now() / 600);
        logo(s, false);
        return;
    }
    if (s.E < 0.3) {                             // break : degrade lent + logo
        g.globalAlpha = 0.6; vagues(Object.assign({}, s, { E: 0.05 })); g.globalAlpha = 1;
        logo(s, false);
    } else {
        let m = Math.floor(hasard(Math.floor(s.mesure / 2), s.pi) * MOTIFS.length);
        if (s.growl >= 0.65 && s.E >= 0.7) { logo(s, true); }
        else {
            MOTIFS[m](s);
            if (s.lead >= 0.8 && s.E >= 0.7) { g.globalAlpha = 0.85; logo(s, false); g.globalAlpha = 1; }
        }
    }
    // eclat sur les kicks des passages forts, blanc sur les drops, stroboscope en montee
    if (s.E >= 0.7 && s.kick >= 0.8 && s.pc < 0.25) { g.fillStyle = 'rgba(255,255,255,0.55)'; g.fillRect(0, 0, W, H); }
    if (s.drop && s.phase < 0.5) { g.fillStyle = `rgba(255,255,255,${1 - s.phase * 2})`; g.fillRect(0, 0, W, H); }
}
requestAnimationFrame(image);
