#!/usr/bin/env python3
"""LUSO RP : service d'analyse du tempo pour pt-dj.

FXServer interdit aux ressources de lancer des programmes (ffmpeg, yt-dlp) : ce petit service tourne a cote du
serveur de jeu, sur la meme machine, et pt-dj l'interroge en HTTP (127.0.0.1 uniquement).

    GET /analyse?url=<lien YouTube ou MP3>
    -> {"bpm": 128.0, "ancre": 0.38, "confiance": 10.6, "coups": "9080...", "energie": "0012...."}

Prerequis : python3, numpy (apt install python3-numpy), ffmpeg, et yt-dlp pour YouTube.
Lancement : python3 analyse_tempo.py [port]   (30125 par defaut ; voir LISEZMOI.md pour le service systemd)
"""
import json
import os
import subprocess
import sys
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np

SR, HOP, WIN = 11025, 256, 512
DUREE_MAX, DUREE_TEMPO = 3 * 3600, 120   # sets DJ jusqu'a 3 h ; tempo de depart sur les 2 premieres minutes
VERSION = 3
LATENCE = WIN / SR
FPS = SR / HOP
CORRECTION = 0.015   # retard propre du detecteur d'attaques (s)
ICI = os.path.dirname(os.path.abspath(__file__))
CACHE_FICHIER = os.path.join(ICI, 'cache_tempo.json')
# cookies d'un compte YouTube (format Netscape) : evite le blocage « Sign in to confirm you're not a bot »
COOKIES = os.environ.get('PT_DJ_COOKIES') or os.path.join(ICI, 'cookies.txt')


EXTENSIONS_LOCALES = ('.mp3', '.ogg', '.wav', '.m4a', '.flac')


def lien_propre(url):
    # liens YouTube : on garde seulement la video (pas la playlist / radio / suivi)
    if est_youtube(url):
        u = urllib.parse.urlparse(url)
        v = urllib.parse.parse_qs(u.query).get('v')
        if v:
            return 'https://www.youtube.com/watch?v=' + v[0]
    return url
verrou = threading.Lock()          # une analyse a la fois (ne pas surcharger la machine du serveur)


def est_youtube(url):
    h = urllib.parse.urlparse(url).netloc.lower()
    return h.endswith('youtube.com') or h.endswith('youtu.be')


def decoder(url):
    ff = ['nice', '-n', '15', 'ffmpeg', '-hide_banner', '-loglevel', 'error']
    if est_youtube(url):
        cmd = ['nice', '-n', '15', 'yt-dlp', '-q', '--no-warnings', '--no-playlist', '-f', 'bestaudio/best']
        if os.path.isfile(COOKIES):
            cmd += ['--cookies', COOKIES]
        yt = subprocess.Popen(cmd + ['-o', '-', url], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        p = subprocess.run(ff + ['-i', 'pipe:0', '-t', str(DUREE_MAX), '-ac', '1', '-ar', str(SR), '-f', 's16le', 'pipe:1'],
                           stdin=yt.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=1200)
        yt.kill()
        erreur_yt = (yt.stderr.read() or b'').decode('utf-8', 'replace').strip().splitlines()
        if len(p.stdout) < SR * 2 * 10 and erreur_yt:
            raise RuntimeError(('yt-dlp (cookies %s) : ' % ('utilises' if os.path.isfile(COOKIES) else 'ABSENTS : ' + COOKIES))
                               + ' | '.join(erreur_yt[-3:])[:400])
    else:
        p = subprocess.run(ff + ['-i', url, '-t', str(DUREE_MAX), '-ac', '1', '-ar', str(SR), '-f', 's16le', 'pipe:1'],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=1200)
    pcm = np.frombuffer(p.stdout, dtype=np.int16).astype(np.float32) / np.float32(32768.0)   # float32 : 1 h = 160 Mo
    if len(pcm) < SR * 10:
        raise RuntimeError('audio illisible ou trop court (lien prive, bloque par YouTube, ou outil manquant)')
    return pcm


def _energies_blocs(blocs_de, longueur):
    """energie par fenetre WIN (pas HOP) calculee par morceaux : pas de gros tableau temporaire sur un set d'1 h"""
    m = longueur // HOP
    blk = np.zeros(m, dtype=np.float64)
    for a in range(0, m, 4096):
        b = min(m, a + 4096)
        seg = blocs_de(a * HOP, b * HOP).reshape(b - a, HOP).astype(np.float64)
        blk[a:b] = np.einsum('ij,ij->i', seg, seg)
    n = max(0, (longueur - WIN) // HOP)
    return (blk[:-1] + blk[1:])[:n]


def energies(x):
    return _energies_blocs(lambda a, b: x[a:b], len(x))


def energies_graves(x, k):
    """energie apres passe-bas (moyenne glissante sur k echantillons)"""
    noyau = np.ones(k, dtype=np.float32) / np.float32(k)

    def bloc(a, b):
        debut = max(0, a - k + 1)
        seg = np.convolve(x[debut:b], noyau, mode='valid')     # valeurs pour j dans [debut + k - 1, b)
        out = np.zeros(b - a, dtype=np.float32)
        j0 = debut + k - 1
        if j0 < b:
            out[max(0, j0 - a):] = seg[max(0, a - j0):]
        return out
    return _energies_blocs(bloc, len(x))


def enveloppe(pcm, e_tout=None):
    # graves : moyenne glissante ~ passe-bas 150 Hz
    e_tout = energies(pcm) if e_tout is None else e_tout
    lt, lb = np.log(1e-9 + e_tout), np.log(1e-9 + energies_graves(pcm, int(SR / 150)))
    env = np.zeros_like(lt)
    env[1:] = np.maximum(0, np.diff(lt)) + 2 * np.maximum(0, np.diff(lb))
    noyau = np.ones(23) / 23
    tendance = np.convolve(env, noyau, mode='same')
    out = np.maximum(0, env - tendance)
    m = out.max()
    return out / m if m > 0 else out


def tempo(env):
    lag_min, lag_max = int(60 * FPS / 200), int(np.ceil(60 * FPS / 60))
    ac = np.zeros(lag_max * 4 + 2)
    for lag in range(lag_min, len(ac)):
        if lag >= len(env):
            break
        ac[lag] = np.dot(env[:-lag], env[lag:]) / (len(env) - lag)
    meilleur, meilleur_lag = -1, lag_min
    for lag in range(lag_min, lag_max + 1):
        bpm = 60 * FPS / lag
        score = ac[lag] + 0.5 * ac[2 * lag] + 0.25 * ac[4 * lag]
        score *= np.exp(-0.5 * (np.log2(bpm / 125) / 0.6) ** 2)
        if score > meilleur:
            meilleur, meilleur_lag = score, lag
    g, c, d = ac[meilleur_lag - 1], ac[meilleur_lag], ac[meilleur_lag + 1]
    den = g - 2 * c + d
    lag_fin = meilleur_lag + 0.5 * (g - d) / den if den != 0 else meilleur_lag
    bpm = 60 * FPS / lag_fin
    while bpm < 85:
        bpm *= 2
    while bpm > 175:
        bpm /= 2
    # affinage conjoint tempo + phase
    idx = np.arange(len(env))
    meilleur_score, phase, bpm_fin = -1, 0.0, bpm
    for bb in np.arange(bpm - 1.5, bpm + 1.5 + 1e-9, 0.05):
        periode = 60 * FPS / bb
        for p in np.arange(0, periode, 0.5):
            t = np.arange(p, len(env) - 1, periode)
            s = np.interp(t, idx, env).sum()
            if s > meilleur_score:
                meilleur_score, phase, bpm_fin = s, p, bb
    moy = ac[lag_min:lag_max + 1].mean()
    return {'bpm': round(float(bpm_fin), 2), 'ancre': float(phase / FPS + LATENCE),
            'confiance': float(ac[meilleur_lag] / moy) if moy > 0 else 0.0}


def tempo_local(env, centre):
    """tempo d'une fenetre de ~20 s, favorise le tempo precedent (un set DJ change de tempo doucement)"""
    lag_min, lag_max = int(60 * FPS / 180), int(np.ceil(60 * FPS / 80))
    ac = np.zeros(2 * lag_max + 2)
    for lag in range(lag_min, len(ac)):
        if lag >= len(env) - 1:
            break
        ac[lag] = np.dot(env[:-lag], env[lag:]) / (len(env) - lag)
    meilleur, m_lag = -1.0, None
    for lag in range(lag_min, lag_max + 1):
        bpm = 60 * FPS / lag
        score = (ac[lag] + 0.5 * ac[2 * lag]) * np.exp(-0.5 * (np.log2(bpm / centre) / 0.2) ** 2)
        if score > meilleur:
            meilleur, m_lag = score, lag
    if not m_lag or ac[m_lag] <= 0:
        return centre
    g, c, d = ac[m_lag - 1], ac[m_lag], ac[m_lag + 1]
    den = g - 2 * c + d
    lag_fin = m_lag + 0.5 * (g - d) / den if den != 0 else m_lag
    bpm = 60 * FPS / lag_fin
    while bpm < 85:
        bpm *= 2
    while bpm > 175:
        bpm /= 2
    return bpm


def carte_tempo(env, bpm_depart):
    """periode du temps (en trames) pour chaque trame : suit les changements de morceau d'un set"""
    n = len(env)
    fen, pas = int(20 * FPS), int(10 * FPS)
    centres, bpms, prec = [], [], bpm_depart
    for a in range(0, max(1, n - fen // 2), pas):
        seg = env[a:a + fen]
        if len(seg) < fen // 2:
            break
        b = tempo_local(seg, prec)
        if abs(b / prec - 1) < 0.015:      # meme morceau : on garde le tempo (stabilite)
            b = prec
        centres.append(a + len(seg) / 2)
        bpms.append(b)
        prec = b
    if not bpms:
        return np.full(n, 60 * FPS / bpm_depart)
    bpms = np.array(bpms)
    lisses = np.array([np.median(bpms[max(0, i - 2):i + 3]) for i in range(len(bpms))])
    return 60 * FPS / np.interp(np.arange(n), centres, lisses)


def battements(env, periodes):
    """suivi des temps par programmation dynamique (Ellis 2007) : grille qui se recale a chaque transition"""
    n = len(env)
    loc = env / (env.std() + 1e-9)
    C = np.zeros(n)
    P = np.full(n, -1, dtype=np.int64)
    serrage = 100.0
    for t in range(n):
        tau = periodes[t]
        hi = t - int(round(tau / 2))
        if hi <= 0:
            C[t] = loc[t]
            continue
        lo = max(0, t - int(round(2 * tau)))
        ecarts = t - np.arange(lo, hi + 1)
        sc = C[lo:hi + 1] - serrage * np.log(ecarts / tau) ** 2
        i = int(np.argmax(sc))
        C[t] = loc[t] + sc[i]
        P[t] = lo + i
    fin_tau = int(round(periodes[-1]))
    t = n - fin_tau - 1 + int(np.argmax(C[max(0, n - fin_tau - 1):])) if n > fin_tau else int(np.argmax(C))
    t = min(max(0, t), n - 1)
    liste = []
    while t >= 0:
        liste.append(t)
        t = P[t]
    f = np.array(liste[::-1], dtype=np.float64)
    # precision sous la trame : dans un passage stable, chaque temps est recale sur la droite des temps voisins
    lisse = f.copy()
    for i in range(len(f)):
        a, b = max(0, i - 8), min(len(f), i + 9)
        if b - a < 6:
            continue
        d = np.diff(f[a:b])
        if d.max() / max(1e-9, d.min()) < 1.12:
            x = np.arange(a, b)
            pente, origine = np.polyfit(x, f[a:b], 1)
            lisse[i] = pente * i + origine
    return lisse


def caracteristiques(pcm):
    """par trame : instruments (energie / attaques par bande) et chroma, STFT calculee par blocs (memoire)"""
    nfft = 1024
    n = (len(pcm) - nfft) // HOP
    if n <= 10:
        return None, None
    fen = np.hanning(nfft).astype(np.float32)
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    m = lambda f0, f1: (freqs >= f0) & (freqs < f1)
    M = {'sub': m(20, 60), 'bass': m(60, 250), 'kick': m(40, 130), 'mid': m(250, 2000), 'lead': m(2000, 5000),
         'high': m(4500, 5500), 'growl': m(250, 3000)}
    selc = m(100, 2000)
    notes = np.round(12 * np.log2(freqs[selc] / 440.0)).astype(int) % 12
    out = {k: np.zeros(n, dtype=np.float32) for k in M}
    chroma = np.zeros((n, 12), dtype=np.float32)
    prec = {}
    for i0 in range(0, n, 2048):
        i1 = min(n, i0 + 2048)
        idx = (np.arange(i0, i1) * HOP)[:, None] + np.arange(nfft)[None, :]
        spec = np.abs(np.fft.rfft(pcm[idx] * fen, axis=1)).astype(np.float32)
        for k in ('sub', 'bass', 'mid'):
            out[k][i0:i1] = np.log1p(spec[:, M[k]].sum(axis=1))
        lb = spec[:, M['lead']]
        out['lead'][i0:i1] = np.log1p(lb.sum(axis=1)) * (lb.max(axis=1) / (lb.mean(axis=1) + 1e-9)) ** 0.5   # tonal
        for k in ('kick', 'high', 'growl'):
            L = np.log1p(spec[:, M[k]])
            avant = prec.get(k, L[:1])
            flux = np.maximum(0, np.diff(np.vstack([avant, L]), axis=0)).sum(axis=1)
            prec[k] = L[-1:]
            out[k][i0:i1] = flux * np.log1p(spec[:, M[k]].sum(axis=1)) if k == 'growl' else flux   # growl : gros son qui bouge
        sc = spec[:, selc]
        for k in range(12):
            chroma[i0:i1, k] = sc[:, notes == k].sum(axis=1)
    return out, chroma


def chiffres(v, q_bas, q_haut):
    v = np.asarray(v, dtype=np.float64)
    if len(v) == 0:
        return ''
    bas, haut = np.quantile(v, q_bas), np.quantile(v, q_haut)
    return ''.join(map(str, np.clip(np.round(9 * (v - bas) / max(1e-9, haut - bas)), 0, 9).astype(int)))


def analyser(url):
    pcm = decoder(lien_propre(url))
    e_tout = energies(pcm)
    env = enveloppe(pcm, e_tout)
    r = tempo(env[:int(DUREE_TEMPO * FPS)])
    # grille des temps sur tout le morceau / set (tempo et calage suivis a chaque transition)
    f = battements(env, carte_tempo(env, r['bpm']))
    if len(f) < 8:
        raise RuntimeError('pas assez de temps detectes')
    ecart = np.diff(f)
    fin = np.append(f, f[-1] + ecart[-1])
    croches = np.empty(2 * len(f) + 1)
    croches[0::2] = fin
    croches[1::2] = (fin[:-1] + fin[1:]) / 2
    n = len(env)
    # coups : attaque (~70 ms) au debut de chaque croche
    coups = [env[max(0, int(round(t)) - 2):min(n, int(round(t)) + 3)].max() if int(round(t)) < n else 0.0 for t in croches[:-1]]
    ref = np.quantile(coups, 0.95) or 1e-9
    coups = ''.join(map(str, np.clip(np.round(9 * np.array(coups) / ref), 0, 9).astype(int)))
    # energie du passage, par temps
    volume = np.sqrt(e_tout / WIN)
    e = np.array([volume[max(0, int(a)):min(n, int(b))].mean() if min(n, int(b)) > max(0, int(a)) else 0.0
                  for a, b in zip(fin[:-1], fin[1:])])
    lisse = np.array([e[max(0, i - 2):i + 2].mean() for i in range(len(e))])
    energie = chiffres(lisse, 0.10, 0.97)
    # instruments par croche, couleurs par temps (changement d'accord)
    feats, chroma = caracteristiques(pcm)
    del pcm
    bandes_, couleurs = {}, ''
    if feats is not None:
        nf = len(chroma)
        def par_croche(x, mode):
            out = []
            for k in range(len(croches) - 1):
                t = croches[k]
                if mode == 'max':   # attaque : seulement le debut de la croche
                    f0, f1 = max(0, int(round(t)) - 1), min(nf, int(round(t)) + 3)
                else:
                    f0, f1 = max(0, int(t) - 1), min(nf, int(croches[k + 1]))
                seg = x[f0:f1]
                out.append((seg.max() if mode == 'max' else seg.mean()) if len(seg) else 0.0)
            return chiffres(out, 0.2, 0.97)
        bandes_ = {k: par_croche(feats[k], 'max' if k in ('kick', 'high') else 'mean')
                   for k in ('kick', 'sub', 'bass', 'mid', 'lead', 'growl', 'high')}
        cl, num, precedent, derniere_mesure = [], 0, None, -99
        for i in range(len(f)):
            f0, f1 = max(0, int(fin[i])), min(nf, int(fin[min(len(fin) - 1, i + 2)]))
            v = chroma[f0:f1].mean(axis=0) if f1 > f0 else np.zeros(12)
            v = v / (np.linalg.norm(v) + 1e-9)
            if precedent is not None and float(np.dot(v, precedent)) < 0.82 and i // 4 != derniere_mesure and i % 2 == 0:
                num += 1
                derniere_mesure = i // 4
            if precedent is None or i % 2 == 0:
                precedent = v
            cl.append(str(num % 10))
        couleurs = ''.join(cl)
    temps = [round(float(x / FPS + LATENCE - CORRECTION), 3) for x in f]   # CORRECTION : mesuree sur des kicks de test
    return {
        'bpm': round(float(60 * FPS / np.median(ecart)), 2), 'ancre': temps[0], 'confiance': r['confiance'],
        'temps': temps, 'coups': coups, 'energie': energie, 'bandes': bandes_, 'couleurs': couleurs,
        'duree': round(n / FPS, 1), 'version': VERSION,
    }


def charger_cache():
    try:
        with open(CACHE_FICHIER) as f:
            return json.load(f)
    except Exception:
        return {}


CACHE = charger_cache()


class Gestionnaire(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def repondre(self, code, data):
        corps = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(corps)))
        self.end_headers()
        self.wfile.write(corps)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == '/ping':
            return self.repondre(200, {'ok': True})
        if u.path != '/analyse':
            return self.repondre(404, {'erreur': 'inconnu'})
        url = (urllib.parse.parse_qs(u.query).get('url') or [''])[0]
        cle = url
        if not url.startswith(('http://', 'https://')):
            # fichier audio local (MP3 du dossier pt-dj/musique, chemin absolu envoye par le serveur FiveM)
            if not (os.path.isabs(url) and url.lower().endswith(EXTENSIONS_LOCALES)):
                return self.repondre(400, {'erreur': 'lien invalide'})
            if not os.path.isfile(url):
                return self.repondre(404, {'erreur': 'fichier introuvable ou illisible : ' + url})
            cle = '%s|%d' % (url, int(os.path.getmtime(url)))   # fichier remplace = nouvelle analyse
        if cle in CACHE and CACHE[cle].get('version') == VERSION:
            return self.repondre(200, CACHE[cle])
        try:
            with verrou:
                r = CACHE.get(cle) if (CACHE.get(cle) or {}).get('version') == VERSION else analyser(url)
            CACHE[cle] = r
            try:
                with open(CACHE_FICHIER, 'w') as f:
                    json.dump(CACHE, f)
            except Exception:
                pass
            print('[analyse] %s BPM  %s' % (r['bpm'], url), flush=True)
            self.repondre(200, r)
        except Exception as ex:
            print('[analyse] echec %s : %s' % (url, ex), flush=True)
            self.repondre(500, {'erreur': str(ex)})


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--fichier':
        print(json.dumps(analyser(sys.argv[2]))[:300])
        sys.exit(0)
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 30125
    print('[analyse] service pt-dj sur 127.0.0.1:%d' % port, flush=True)
    print('[analyse] cookies YouTube : %s (%s)' % ('trouves' if os.path.isfile(COOKIES) else 'ABSENTS', COOKIES), flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), Gestionnaire).serve_forever()
