// LUSO RP : analyse du tempo des morceaux (cote serveur).
// Le serveur decode les ~2 premieres minutes du morceau avec ffmpeg (et yt-dlp pour YouTube), calcule le tempo (BPM)
// et la position du premier temps fort, puis le jeu de lumieres se cale dessus pour tous les joueurs.
// Prerequis sur la machine du serveur : ffmpeg, et yt-dlp pour les liens YouTube (voir LISEZMOI.md).
const { spawn } = require('child_process');

const SR = 11025;          // frequence d'echantillonnage de l'analyse
const HOP = 256;           // pas entre deux trames (~23 ms)
const WIN = 512;
const DUREE_MAX = 480;     // secondes decodees (profil d'energie de tout le morceau, 8 min max)
const DUREE_TEMPO = 120;   // secondes utilisees pour trouver le tempo
const DELAI_MAX = 90000;   // ms avant abandon
const LATENCE = WIN / SR;  // ecart entre la trame detectee et le debut reel de l'attaque (s)

function estYoutube(url) {
    return /(^https?:\/\/)?(www\.|m\.|music\.)?(youtube\.com|youtu\.be)\//i.test(url);
}

// Decode l'audio en PCM 16 bits mono 11025 Hz
function decoder(url) {
    return new Promise((resolve, reject) => {
        const procs = [];
        let ffIn = url;
        let source = null;
        if (estYoutube(url)) {
            source = (process.platform === 'linux' ? spawn('nice', ['-n', '15', 'yt-dlp', '-q', '--no-playlist', '-f', 'bestaudio', '-o', '-', url], { stdio: ['ignore', 'pipe', 'ignore'] }) : null) || spawn('yt-dlp', ['-q', '--no-playlist', '-f', 'bestaudio', '-o', '-', url], { stdio: ['ignore', 'pipe', 'ignore'] });
            procs.push(source);
            ffIn = 'pipe:0';
        }
        // priorite basse sous Linux pour ne pas ralentir le serveur de jeu
        const bas = (cmd, args, opts) => process.platform === 'linux' ? spawn('nice', ['-n', '15', cmd, ...args], opts) : spawn(cmd, args, opts);
        const ff = bas('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-i', ffIn, '-t', String(DUREE_MAX),
            '-ac', '1', '-ar', String(SR), '-f', 's16le', 'pipe:1'],
            { stdio: [source ? 'pipe' : 'ignore', 'pipe', 'ignore'] });
        procs.push(ff);
        if (source) {
            source.stdout.pipe(ff.stdin);
            ff.stdin.on('error', () => {});
            source.on('error', (e) => reject(new Error(e.code === 'ENOENT' ? 'yt-dlp absent' : e.message)));
        }
        const morceaux = [];
        ff.stdout.on('data', (d) => morceaux.push(d));
        ff.on('error', (e) => reject(new Error(e.code === 'ENOENT' ? 'ffmpeg absent' : e.message)));
        const minuteur = setTimeout(() => { procs.forEach((p) => p.kill('SIGKILL')); reject(new Error('delai depasse')); }, DELAI_MAX);
        ff.on('close', () => {
            clearTimeout(minuteur);
            procs.forEach((p) => { try { p.kill('SIGKILL'); } catch (e) { } });
            const buf = Buffer.concat(morceaux);
            if (buf.length < SR * 2 * 10) return reject(new Error('audio illisible ou trop court'));
            resolve(new Int16Array(buf.buffer, buf.byteOffset, Math.floor(buf.length / 2)));
        });
    });
}

// Enveloppe des attaques : flux d'energie (graves + toutes frequences), positif uniquement
function enveloppe(pcm) {
    const n = Math.floor((pcm.length - WIN) / HOP);
    const env = new Float64Array(n);
    // passe-bas a un pole (~150 Hz) pour faire ressortir la grosse caisse
    const a = Math.exp(-2 * Math.PI * 150 / SR);
    const bas = new Float64Array(pcm.length);
    let y = 0;
    for (let i = 0; i < pcm.length; i++) { y = (1 - a) * (pcm[i] / 32768) + a * y; bas[i] = y; }
    let precTout = 0, precBas = 0;
    for (let f = 0; f < n; f++) {
        let eTout = 0, eBas = 0;
        const d = f * HOP;
        for (let i = 0; i < WIN; i++) {
            const s = pcm[d + i] / 32768;
            eTout += s * s;
            eBas += bas[d + i] * bas[d + i];
        }
        const lt = Math.log(1e-9 + eTout), lb = Math.log(1e-9 + eBas);
        env[f] = (f > 0 ? Math.max(0, lt - precTout) + 2 * Math.max(0, lb - precBas) : 0);
        precTout = lt; precBas = lb;
    }
    // retire la tendance (moyenne glissante ~0,5 s) et normalise
    const k = 11;
    const out = new Float64Array(n);
    let somme = 0;
    for (let f = 0; f < n; f++) {
        somme += env[f];
        if (f >= 2 * k + 1) somme -= env[f - 2 * k - 1];
        const centre = f - k;
        if (centre >= 0) out[centre] = Math.max(0, env[centre] - somme / Math.min(f + 1, 2 * k + 1));
    }
    let max = 0;
    for (let f = 0; f < n; f++) if (out[f] > max) max = out[f];
    if (max > 0) for (let f = 0; f < n; f++) out[f] /= max;
    return out;
}

// Tempo par autocorrelation de l'enveloppe, avec preference pour 90-160 BPM ; phase par peigne
function tempo(env) {
    const fps = SR / HOP;
    const lagMin = Math.floor(60 * fps / 200), lagMax = Math.ceil(60 * fps / 60);
    const ac = new Float64Array(lagMax + 2);
    for (let lag = lagMin; lag <= lagMax + 1; lag++) {
        let s = 0;
        for (let i = 0; i + lag < env.length; i++) s += env[i] * env[i + lag];
        ac[lag] = s / (env.length - lag);
    }
    let meilleur = -1, meilleurLag = 0;
    for (let lag = lagMin; lag <= lagMax; lag++) {
        const bpm = 60 * fps / lag;
        // somme avec les multiples (temps, mesure) pour stabiliser, ponderee autour de 125 BPM
        let score = ac[lag];
        if (2 * lag <= lagMax + 1) score += 0.5 * ac[2 * lag];
        if (4 * lag <= lagMax + 1) score += 0.25 * ac[4 * lag];
        const poids = Math.exp(-0.5 * Math.pow(Math.log2(bpm / 125) / 0.6, 2));
        score *= poids;
        if (score > meilleur) { meilleur = score; meilleurLag = lag; }
    }
    // interpolation parabolique pour un tempo a la decimale
    let lagFin = meilleurLag;
    const g = ac[meilleurLag - 1], c = ac[meilleurLag], d = ac[meilleurLag + 1];
    const den = g - 2 * c + d;
    if (den !== 0 && isFinite(den)) lagFin = meilleurLag + 0.5 * (g - d) / den;
    let bpm = 60 * fps / lagFin;
    while (bpm < 85) bpm *= 2;
    while (bpm > 175) bpm /= 2;
    // affinage conjoint tempo + phase : la grille de temps qui tombe le mieux sur les attaques de tout le morceau
    const val = (t) => {
        const i = Math.floor(t), f = t - i;
        return (env[i] || 0) * (1 - f) + (env[i + 1] || 0) * f;
    };
    let meilleurePhase = 0, scorePhase = -1, bpmFin = bpm;
    for (let bb = bpm - 1.5; bb <= bpm + 1.5; bb += 0.05) {
        const periode = 60 * fps / bb;
        for (let p = 0; p < periode; p += 0.5) {
            let s = 0;
            for (let t = p; t < env.length - 1; t += periode) s += val(t);
            if (s > scorePhase) { scorePhase = s; meilleurePhase = p; bpmFin = bb; }
        }
    }
    bpm = bpmFin;
    // confiance : rapport entre le pic retenu et la moyenne de l'autocorrelation
    let moy = 0, nb = 0;
    for (let lag = lagMin; lag <= lagMax; lag++) { moy += ac[lag]; nb++; }
    const confiance = nb > 0 && moy > 0 ? ac[meilleurLag] / (moy / nb) : 0;
    const ancre = meilleurePhase / fps + LATENCE;
    return { bpm: Math.round(bpm * 100) / 100, ancre, confiance };
}

// Profil du morceau sur la grille trouvee :
//   coups  : force de l'attaque a chaque croche (0-9), pour flasher sur les vrais coups de grosse caisse
//   energie: volume de chaque temps (0-9) lisse sur la mesure, pour les montees, les drops et les breaks
function profil(pcm, env, bpm, ancre) {
    const fps = SR / HOP;
    const nTrames = env.length;
    const volume = new Float64Array(nTrames);
    for (let f = 0; f < nTrames; f++) {
        let e = 0;
        const d = f * HOP;
        for (let i = 0; i < WIN; i += 2) { const x = pcm[d + i] / 32768; e += x * x; }
        volume[f] = Math.sqrt(e / (WIN / 2));
    }
    const periode = 60 / bpm;
    const duree = nTrames / fps;
    const coups = [], energie = [];
    const quantile = (arr, q) => { const t = Float64Array.from(arr).sort(); return t[Math.min(t.length - 1, Math.floor(q * t.length))] || 1e-9; };
    // croches
    const brutCoups = [];
    for (let t = ancre - LATENCE; t < duree; t += periode / 2) {
        const f = Math.round(t * fps);
        let m = 0;
        for (let k = f - 2; k <= f + 2; k++) if (k >= 0 && k < nTrames && env[k] > m) m = env[k];
        brutCoups.push(m);
    }
    const refCoups = quantile(brutCoups, 0.95);
    for (const c of brutCoups) coups.push(Math.max(0, Math.min(9, Math.round(9 * c / refCoups))));
    // temps
    const brutEnergie = [];
    for (let t = ancre - LATENCE; t < duree; t += periode) {
        const f0 = Math.max(0, Math.floor(t * fps)), f1 = Math.min(nTrames, Math.floor((t + periode) * fps));
        let s = 0;
        for (let f = f0; f < f1; f++) s += volume[f];
        brutEnergie.push(f1 > f0 ? s / (f1 - f0) : 0);
    }
    // lissage sur 4 temps puis echelle entre le 10e et le 97e centile du morceau
    const lisse = brutEnergie.map((_, i) => {
        let s = 0, n = 0;
        for (let k = i - 2; k <= i + 1; k++) if (k >= 0 && k < brutEnergie.length) { s += brutEnergie[k]; n++; }
        return s / n;
    });
    const bas = quantile(lisse, 0.10), haut = quantile(lisse, 0.97);
    for (const v of lisse) energie.push(Math.max(0, Math.min(9, Math.round(9 * (v - bas) / Math.max(1e-9, haut - bas)))));
    return { coups: coups.join(''), energie: energie.join('') };
}

async function analyser(url) {
    const pcm = await decoder(url);
    const env = enveloppe(pcm);
    const r = tempo(env.subarray(0, Math.min(env.length, Math.floor(DUREE_TEMPO * SR / HOP))));
    const p = profil(pcm, env, r.bpm, r.ancre);
    r.coups = p.coups;
    r.energie = p.energie;
    return r;
}

if (typeof on === 'function') {
    on('pt-dj:analyser', (id, v, url) => {
        analyser(url).then((r) => {
            emit('pt-dj:analyseFaite', id, v, r.bpm, r.ancre, r.confiance, null, r.coups, r.energie);
        }).catch((e) => {
            emit('pt-dj:analyseFaite', id, v, null, null, 0, String(e && e.message || e));
        });
    });
} else {
    module.exports = { analyser, tempo, enveloppe, profil };
}
