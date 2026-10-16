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
DUREE_MAX, DUREE_TEMPO = 480, 120
LATENCE = WIN / SR
FPS = SR / HOP
ICI = os.path.dirname(os.path.abspath(__file__))
CACHE_FICHIER = os.path.join(ICI, 'cache_tempo.json')
# cookies d'un compte YouTube (format Netscape) : evite le blocage « Sign in to confirm you're not a bot »
COOKIES = os.environ.get('PT_DJ_COOKIES') or os.path.join(ICI, 'cookies.txt')


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
                           stdin=yt.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=150)
        yt.kill()
        erreur_yt = (yt.stderr.read() or b'').decode('utf-8', 'replace').strip().splitlines()
        if len(p.stdout) < SR * 2 * 10 and erreur_yt:
            raise RuntimeError(('yt-dlp (cookies %s) : ' % ('utilises' if os.path.isfile(COOKIES) else 'ABSENTS : ' + COOKIES))
                               + ' | '.join(erreur_yt[-3:])[:400])
    else:
        p = subprocess.run(ff + ['-i', url, '-t', str(DUREE_MAX), '-ac', '1', '-ar', str(SR), '-f', 's16le', 'pipe:1'],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=150)
    pcm = np.frombuffer(p.stdout, dtype=np.int16).astype(np.float64) / 32768.0
    if len(pcm) < SR * 10:
        raise RuntimeError('audio illisible ou trop court (lien prive, bloque par YouTube, ou outil manquant)')
    return pcm


def energies(x):
    cs = np.concatenate([[0.0], np.cumsum(x * x)])
    n = (len(x) - WIN) // HOP
    d = np.arange(n) * HOP
    return cs[d + WIN] - cs[d]


def enveloppe(pcm):
    # graves : moyenne glissante ~ passe-bas 150 Hz
    k = int(SR / 150)
    cs = np.concatenate([[0.0], np.cumsum(pcm)])
    bas = np.zeros_like(pcm)
    bas[k:] = (cs[k + 1:] - cs[1:-k]) / k
    lt, lb = np.log(1e-9 + energies(pcm)), np.log(1e-9 + energies(bas))
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


def profil(pcm, env, bpm, ancre):
    volume = np.sqrt(energies(pcm) / WIN)
    n = len(env)
    periode = 60 / bpm
    duree = n / FPS
    t0 = ancre - LATENCE
    croches = np.arange(t0, duree, periode / 2)
    brut = []
    for t in croches:
        f = int(round(t * FPS))
        a, b = max(0, f - 2), min(n, f + 3)
        brut.append(env[a:b].max() if b > a else 0.0)
    brut = np.array(brut)
    ref = np.quantile(brut, 0.95) or 1e-9
    coups = np.clip(np.round(9 * brut / ref), 0, 9).astype(int)
    temps = np.arange(t0, duree, periode)
    e = []
    for t in temps:
        f0, f1 = max(0, int(t * FPS)), min(n, int((t + periode) * FPS))
        e.append(volume[f0:f1].mean() if f1 > f0 else 0.0)
    e = np.array(e)
    lisse = np.array([e[max(0, i - 2):i + 2].mean() for i in range(len(e))])
    bas, haut = np.quantile(lisse, 0.10), np.quantile(lisse, 0.97)
    energie = np.clip(np.round(9 * (lisse - bas) / max(1e-9, haut - bas)), 0, 9).astype(int)
    return ''.join(map(str, coups)), ''.join(map(str, energie))


def bandes(pcm, bpm, ancre):
    """Analyse par instrument, a chaque croche : kick, sub, bass, mid (accords), lead, growl, high (charley),
    et couleurs : numero d'accord par temps (change quand l'harmonie change), pour changer les couleurs au bon moment."""
    nfft = 1024
    n = (len(pcm) - nfft) // HOP
    if n <= 10:
        return {}, ''
    fen = np.hanning(nfft)
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    spec = np.empty((n, len(freqs)), dtype=np.float32)
    for i0 in range(0, n, 2048):                       # par blocs (memoire)
        i1 = min(n, i0 + 2048)
        idx = (np.arange(i0, i1) * HOP)[:, None] + np.arange(nfft)[None, :]
        spec[i0:i1] = np.abs(np.fft.rfft(pcm[idx] * fen, axis=1))
    def bande(f0, f1):
        sel = (freqs >= f0) & (freqs < f1)
        return spec[:, sel]
    energie = lambda b: np.log1p(b.sum(axis=1))
    flux = lambda b: np.maximum(0, np.diff(np.log1p(b), axis=0, prepend=np.log1p(b[:1]))).sum(axis=1)
    sub = energie(bande(20, 60))
    bass = energie(bande(60, 250))
    kick = flux(bande(40, 130))
    mid_b = bande(250, 2000)
    mid = energie(mid_b)
    lead_b = bande(2000, 5000)
    lead = energie(lead_b) * (lead_b.max(axis=1) / (lead_b.mean(axis=1) + 1e-9)) ** 0.5   # tonal : pics marques
    high = flux(bande(4500, 5500))
    growl_b = bande(250, 3000)
    growl = flux(growl_b) * np.log1p(growl_b.sum(axis=1))                                  # gros son medium qui bouge vite
    periode = 60 / bpm
    t0 = ancre - LATENCE
    croches = np.arange(t0, n / FPS, periode / 2)
    def par_croche(x, mode):
        out = []
        for t in croches:
            if mode == 'max':   # attaque : seulement le debut de la croche (~70 ms)
                f0, f1 = max(0, int(round(t * FPS)) - 1), min(n, int(round(t * FPS)) + 3)
            else:
                f0, f1 = max(0, int(t * FPS) - 1), min(n, int((t + periode / 2) * FPS))
            seg = x[f0:f1]
            out.append((seg.max() if mode == 'max' else seg.mean()) if len(seg) else 0.0)
        out = np.array(out)
        bas, haut = np.quantile(out, 0.2), np.quantile(out, 0.97)
        return ''.join(map(str, np.clip(np.round(9 * (out - bas) / max(1e-9, haut - bas)), 0, 9).astype(int)))
    res = {
        'kick': par_croche(kick, 'max'), 'sub': par_croche(sub, 'mean'), 'bass': par_croche(bass, 'mean'),
        'mid': par_croche(mid, 'mean'), 'lead': par_croche(lead, 'mean'), 'growl': par_croche(growl, 'mean'),
        'high': par_croche(high, 'max'),
    }
    # harmonie : chroma (12 notes) par temps, nouvelle couleur quand l'accord change nettement (au plus une par mesure)
    sel = (freqs >= 100) & (freqs < 2000)
    notes = np.round(12 * np.log2(freqs[sel] / 440.0)).astype(int) % 12
    chroma_trames = np.zeros((n, 12), dtype=np.float32)
    for k in range(12):
        chroma_trames[:, k] = spec[:, sel][:, notes == k].sum(axis=1)
    couleurs, num, precedent, derniere_mesure = [], 0, None, -99
    for i, t in enumerate(np.arange(t0, n / FPS, periode)):
        f0, f1 = max(0, int(t * FPS)), min(n, int((t + 2 * periode) * FPS))
        v = chroma_trames[f0:f1].mean(axis=0) if f1 > f0 else np.zeros(12)
        v = v / (np.linalg.norm(v) + 1e-9)
        if precedent is not None and float(np.dot(v, precedent)) < 0.82 and i // 4 != derniere_mesure and i % 2 == 0:
            num += 1
            derniere_mesure = i // 4
        if precedent is None or i % 2 == 0:
            precedent = v
        couleurs.append(str(num % 10))
    return res, ''.join(couleurs)


def analyser(url):
    pcm = decoder(lien_propre(url))
    env = enveloppe(pcm)
    r = tempo(env[:int(DUREE_TEMPO * FPS)])
    r['coups'], r['energie'] = profil(pcm, env, r['bpm'], r['ancre'])
    r['bandes'], r['couleurs'] = bandes(pcm, r['bpm'], r['ancre'])
    r['version'] = 2
    return r


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
        if not url.startswith(('http://', 'https://')):
            return self.repondre(400, {'erreur': 'lien invalide'})
        if url in CACHE and CACHE[url].get('version') == 2:
            return self.repondre(200, CACHE[url])
        try:
            with verrou:
                r = CACHE.get(url) if (CACHE.get(url) or {}).get('version') == 2 else analyser(url)
            CACHE[url] = r
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
