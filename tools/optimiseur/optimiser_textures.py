#!/usr/bin/env python3
"""Optimiseur de textures pour FiveM : ramene chaque fichier sous une taille cible (15 Mo par defaut, sous le seuil
de 16 Mo de l'avertissement "Oversized assets" de FiveM) en reduisant les plus grosses textures.
Fichiers traites : .ytd (dictionnaires de textures) et .ydr / .ydd / .yft (modeles avec textures integrees).

Usage :
  python3 tools/optimiseur/optimiser_textures.py DOSSIER_OU_FICHIER [...] [options]

Options :
  --cible 15          taille physique visee par fichier, en Mo (defaut 15, marge sous la limite de 16)
  --max-dim 0         reduire aussi toute texture plus large que N pixels, meme si le fichier est sous la cible
                      (ex. 2048 ; 0 = desactive)
  --min-dim 256       ne jamais descendre une texture sous N pixels (sauf si la cible l'exige : voir --forcer)
  --forcer            autoriser a descendre jusqu'a 64 px si la cible n'est pas atteinte autrement
  --sauvegarde DIR    copie des fichiers d'origine avant modification (defaut : ./textures_originales)
  --sans-sauvegarde   ne pas garder de copie (a utiliser seulement sous git ou avec une sauvegarde ailleurs)
  --simulation        n'ecrit rien, affiche ce qui serait fait

Fonctionnement :
  - textures avec mipmaps : on retire les niveaux les plus grands (aucune perte de qualite supplementaire,
    les niveaux suivants sont deja calcules) ;
  - textures sans mipmaps : decodage, reduction de moitie (filtre Lanczos), re-encodage dans le meme format
    (DXT1, DXT5, ATI1, ATI2, BC7, ARGB 32 bits, L8 / A8 ; DXT3 devient DXT5) ;
  - on reduit toujours la plus grosse texture en premier, jusqu'a passer sous la cible.
Dans un modele, la geometrie n'est jamais modifiee (deplacee telle quelle) : seules les textures integrees sont reduites.
Les modeles dont la memoire virtuelle depasse 16 Mo (geometrie trop detaillee) sont listes a la fin : ce n'est pas
un probleme de textures, seul un remodelage les allege.

Dependances : pip install etcpak texture2ddecoder pillow
"""
import argparse
import os
import shutil
import struct
import sys
import zlib

try:
    import etcpak
    import texture2ddecoder
    from PIL import Image
except ImportError:
    sys.exit('Il manque des modules : pip install etcpak texture2ddecoder pillow')

MO = 1024 * 1024

# ---------------------------------------------------------------------------------------------------------------
# RSC7 : tailles des segments (meme calcul que CodeWalker)


def taille_flags(f):
    unite = 0x200 << (f & 0xF)
    n = (((f >> 27) & 1) + (((f >> 26) & 1) << 1) + (((f >> 25) & 1) << 2) + (((f >> 24) & 1) << 3)
         + (((f >> 17) & 0x7F) << 4) + (((f >> 11) & 0x3F) << 5) + (((f >> 7) & 0xF) << 6)
         + (((f >> 5) & 0x3) << 7) + (((f >> 4) & 0x1) << 8))
    return n * unite


# compartiments de pages : (decalage du champ, nombre de bits, taille de page en unites)
COMPARTIMENTS = [(4, 1, 256), (5, 2, 128), (7, 4, 64), (11, 6, 32), (17, 7, 16), (24, 1, 8), (25, 1, 4), (26, 1, 2), (27, 1, 1)]
ALIGN = 16


def disposer(tailles):
    """Range des blocs (tailles en octets) dans des pages RSC7. Renvoie (flags sans version, positions, taille totale)
    pour la disposition la plus compacte, ou None."""
    ordre = sorted(range(len(tailles)), key=lambda i: -tailles[i])
    meilleur = None
    for ss in range(16):
        unite = 0x200 << ss
        if tailles and max(tailles) > 256 * unite:
            continue
        comptes = {k: 0 for k in range(len(COMPARTIMENTS))}
        pages = []  # [compartiment, taille, rempli, [(bloc, decalage)]]
        ok = True
        for i in ordre:
            t = tailles[i]
            place = False
            for p in pages:
                debut = (p[2] + ALIGN - 1) // ALIGN * ALIGN
                if debut + t <= p[1]:
                    p[3].append((i, debut))
                    p[2] = debut + t
                    place = True
                    break
            if place:
                continue
            # nouvelle page : la plus petite qui contient le bloc et dont le compartiment n'est pas plein
            choix = None
            for k in range(len(COMPARTIMENTS) - 1, -1, -1):
                dec, bits, u = COMPARTIMENTS[k]
                if u * unite >= t and comptes[k] < (1 << bits) - 1:
                    choix = k
                    break
            if choix is None:
                ok = False
                break
            comptes[choix] += 1
            pages.append([choix, COMPARTIMENTS[choix][2] * unite, t, [(i, 0)]])
        if not ok:
            continue
        # pages rangees de la plus grande a la plus petite (ordre du format)
        pages.sort(key=lambda p: p[0])
        positions = [0] * len(tailles)
        pos = 0
        for p in pages:
            for i, d in p[3]:
                positions[i] = pos + d
            pos += p[1]
        flags = ss
        for k, n in comptes.items():
            dec, bits, u = COMPARTIMENTS[k]
            if n >= (1 << bits):
                ok = False
            flags |= n << dec
        if ok and taille_flags(flags) == pos and (meilleur is None or pos < meilleur[2]):
            meilleur = (flags, positions, pos)
    return meilleur


# ---------------------------------------------------------------------------------------------------------------
# Formats de texture

FMT_DXT1, FMT_DXT3, FMT_DXT5 = 0x31545844, 0x33545844, 0x35545844
FMT_ATI1, FMT_ATI2, FMT_BC7 = 0x31495441, 0x32495441, 0x20374342
FMT_A8R8G8B8, FMT_X8R8G8B8, FMT_A8B8G8R8, FMT_L8, FMT_A8 = 21, 22, 32, 50, 28
BLOCS = {FMT_DXT1: 8, FMT_ATI1: 8, FMT_DXT3: 16, FMT_DXT5: 16, FMT_ATI2: 16, FMT_BC7: 16}
OCTETS_PIXEL = {FMT_A8R8G8B8: 4, FMT_X8R8G8B8: 4, FMT_A8B8G8R8: 4, FMT_L8: 1, FMT_A8: 1}
NOMS = {FMT_DXT1: 'DXT1', FMT_DXT3: 'DXT3', FMT_DXT5: 'DXT5', FMT_ATI1: 'ATI1', FMT_ATI2: 'ATI2', FMT_BC7: 'BC7',
        FMT_A8R8G8B8: 'A8R8G8B8', FMT_X8R8G8B8: 'X8R8G8B8', FMT_A8B8G8R8: 'A8B8G8R8', FMT_L8: 'L8', FMT_A8: 'A8'}


def taille_niveau(fmt, w, h):
    if fmt in BLOCS:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * BLOCS[fmt]
    return w * h * OCTETS_PIXEL[fmt]


def pas(fmt, w):
    # convention GTA : octets par ligne de pixels (une rangee de blocs DXT couvre 4 lignes)
    if fmt in BLOCS:
        return max(1, (w + 3) // 4) * BLOCS[fmt] // 4
    return w * OCTETS_PIXEL[fmt]


def niveaux(st, h, n):
    """Tailles allouees pour chaque niveau de mipmap, avec la convention du jeu (et de CodeWalker) :
    niveau 0 = pas * hauteur, puis divise par 4 a chaque niveau."""
    tailles, t = [], st * h
    for _ in range(n):
        tailles.append(t)
        t //= 4
    return tailles


def decoder(fmt, data, w, h):
    """-> image PIL RGBA (ou L)"""
    if fmt == FMT_DXT1:
        return Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc1(data, w, h), 'raw', 'BGRA')
    if fmt in (FMT_DXT5, FMT_DXT3):
        if fmt == FMT_DXT3:
            return Image.frombytes('RGBA', (w, h), decoder_dxt3(data, w, h))
        return Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc3(data, w, h), 'raw', 'BGRA')
    if fmt == FMT_ATI1:
        return Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc4(data, w, h), 'raw', 'BGRA')
    if fmt == FMT_ATI2:
        return Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc5(data, w, h), 'raw', 'BGRA')
    if fmt == FMT_BC7:
        return Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc7(data, w, h), 'raw', 'BGRA')
    if fmt in (FMT_A8R8G8B8, FMT_X8R8G8B8):
        return Image.frombytes('RGBA', (w, h), data, 'raw', 'BGRA')
    if fmt == FMT_A8B8G8R8:
        return Image.frombytes('RGBA', (w, h), data, 'raw', 'RGBA')
    if fmt in (FMT_L8, FMT_A8):
        return Image.frombytes('L', (w, h), data)
    raise ValueError('format non gere')


def decoder_dxt3(data, w, h):
    """DXT3 (alpha explicite 4 bits + couleur DXT1) -> RGBA"""
    bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
    couleur = bytearray()
    alphas = []
    for b in range(bw * bh):
        bloc = data[b * 16:(b + 1) * 16]
        alphas.append(bloc[:8])
        couleur += bloc[8:]
    rgba = bytearray(Image.frombytes('RGBA', (w, h), texture2ddecoder.decode_bc1(bytes(couleur), w, h), 'raw', 'BGRA').tobytes())
    for by in range(bh):
        for bx in range(bw):
            a = alphas[by * bw + bx]
            for py in range(4):
                for px in range(4):
                    x, y = bx * 4 + px, by * 4 + py
                    if x < w and y < h:
                        n = py * 4 + px
                        v = (a[n // 2] >> (4 * (n % 2))) & 0xF
                        rgba[(y * w + x) * 4 + 3] = v * 17
    return bytes(rgba)


def encoder(fmt, img):
    w, h = img.size
    if fmt in (FMT_L8, FMT_A8):
        return img.convert('L').tobytes()
    img = img.convert('RGBA')
    if fmt == FMT_A8R8G8B8 or fmt == FMT_X8R8G8B8:
        return img.tobytes('raw', 'BGRA')
    if fmt == FMT_A8B8G8R8:
        return img.tobytes('raw', 'RGBA')
    rgba = img.tobytes('raw', 'RGBA')
    if fmt == FMT_DXT1:
        return etcpak.compress_bc1(rgba, w, h)
    if fmt == FMT_DXT5:
        return etcpak.compress_bc3(rgba, w, h)
    if fmt == FMT_ATI1:
        return etcpak.compress_bc4(rgba, w, h)
    if fmt == FMT_ATI2:
        return etcpak.compress_bc5(rgba, w, h)
    if fmt == FMT_BC7:
        return etcpak.compress_bc7(rgba, w, h)
    raise ValueError('format non gere')


# ---------------------------------------------------------------------------------------------------------------
# YTD


class Texture:
    def __init__(self, nom, decal, w, h, st, fmt, lv, donnees):
        self.nom, self.decal = nom, decal
        self.w, self.h, self.st, self.fmt, self.lv = w, h, st, fmt, lv
        self.donnees = donnees  # chaine de mipmaps complete
        self.reduite = 0

    def taille(self):
        return len(self.donnees)

    def reductible(self, min_dim):
        if getattr(self, 'fige', False):
            return False
        if min(self.w, self.h) // 2 < min_dim:
            return False
        if self.lv > 1:
            return self.st % 2 == 0
        # re-encodage seulement si le pas enregistre correspond au format (sinon convention inconnue)
        return self.st == pas(self.fmt, self.w)

    def reduire(self):
        if self.lv > 1:
            premier = self.st * self.h
            self.w, self.h, self.st, self.lv = max(1, self.w >> 1), max(1, self.h >> 1), self.st // 2, self.lv - 1
            total = sum(niveaux(self.st, self.h, self.lv))
            reste = self.donnees[premier:premier + total]
            self.donnees = reste + bytes(total - len(reste))
        else:
            vrai = taille_niveau(self.fmt, self.w, self.h)
            niveau0 = self.donnees[:vrai]
            img = decoder(self.fmt, niveau0 + bytes(vrai - len(niveau0)), self.w, self.h)
            nw, nh = max(4, (self.w // 2 + 3) // 4 * 4), max(4, (self.h // 2 + 3) // 4 * 4)
            if self.fmt in OCTETS_PIXEL:
                nw, nh = max(1, self.w // 2), max(1, self.h // 2)
            # canal par canal : l'alpha des textures GTA porte souvent autre chose que la transparence
            # (brillance, masque), un redimensionnement RGBA classique (premultiplie) abimerait les couleurs
            img = Image.merge(img.mode, [c.resize((nw, nh), Image.LANCZOS) for c in img.split()])
            if self.fmt == FMT_DXT3:
                self.fmt = FMT_DXT5
            self.donnees = encoder(self.fmt, img)
            self.w, self.h, self.st = nw, nh, pas(self.fmt, nw)
            attendu = taille_niveau(self.fmt, nw, nh)
            if len(self.donnees) != attendu or attendu != pas(self.fmt, nw) * nh:
                raise ValueError(f'{self.nom} : taille encodee {len(self.donnees)} au lieu de {attendu}')
        self.reduite += 1


VERSIONS = {'ytd': 13, 'ydr': 165, 'ydd': 165, 'yft': 162}


def pages_origine(gf):
    """Pages du segment graphique dans l'ordre du fichier (les plus grandes d'abord) : [(debut, taille)]"""
    unite = 0x200 << (gf & 0xF)
    pos, pages = 0, []
    for dec, bits, u in COMPARTIMENTS:
        for _ in range((gf >> dec) & ((1 << bits) - 1)):
            pages.append((pos, u * unite))
            pos += u * unite
    return pages


def lire_ressource(chemin):
    """Lit un .ytd / .ydr / .ydd / .yft et repere les textures (dictionnaire du fichier ou integre au modele).
    Renvoie None si le fichier n'a aucune texture dans son segment graphique."""
    ext = chemin.lower().rsplit('.', 1)[-1]
    brut = open(chemin, 'rb').read()
    if brut[:4] != b'RSC7':
        raise ValueError('pas une ressource RSC7')
    version, sf, gf = struct.unpack_from('<III', brut, 4)
    if VERSIONS.get(ext) != version:
        raise ValueError(f'version {version} non geree pour un .{ext}')
    data = bytearray(zlib.decompress(brut[16:], -15))
    S, G = taille_flags(sf), taille_flags(gf)
    if len(data) != S + G:
        raise ValueError('taille des segments incoherente')

    def q(o):
        return struct.unpack_from('<Q', data, o)[0]

    def sys_(p):
        if p >> 28 != 5 or (p & 0x0FFFFFFF) >= S:
            raise ValueError('pointeur systeme attendu')
        return p & 0x0FFFFFFF

    def dico_du_modele(drawable):
        sg = q(sys_(drawable) + 0x10)
        if sg >> 28 != 5:
            return []
        td = q(sys_(sg) + 0x08)
        return [sys_(td)] if td >> 28 == 5 else []

    if ext == 'ytd':
        dicos = [0]
    elif ext == 'ydr':
        dicos = dico_du_modele(0x50000000)
    elif ext == 'yft':
        dr = q(0x30)
        dicos = dico_du_modele(dr) if dr >> 28 == 5 else []
    else:  # ydd : dictionnaire de modeles
        lp, lc = struct.unpack_from('<QH', data, 0x30)
        dicos = []
        for k in range(lc):
            dicos += dico_du_modele(q(sys_(lp) + 8 * k))
    textures, vus = [], set()
    for t0 in dict.fromkeys(dicos):
        tp, tc = struct.unpack_from('<QH', data, t0 + 0x30)
        for i in range(tc):
            t = sys_(q(sys_(tp) + 8 * i))
            if t in vus:
                continue
            vus.add(t)
            o = sys_(q(t + 0x28))
            nom = bytes(data[o:o + 128]).split(b'\0')[0].decode('latin-1')
            w, h, d, st, fmt = struct.unpack_from('<HHHHI', data, t + 0x50)
            lv = data[t + 0x5D]
            dp = q(t + 0x70)
            if dp >> 28 != 6:
                raise ValueError(f'{nom} : pointeur de donnees inattendu')
            if fmt not in BLOCS and fmt not in OCTETS_PIXEL:
                raise ValueError(f'{nom} : format {hex(fmt)} non gere')
            if d != 1:
                raise ValueError(f'{nom} : texture 3D / cube non geree')
            if st == 0:
                raise ValueError(f'{nom} : pas de ligne nul')
            debut = dp & 0x0FFFFFFF
            total = sum(niveaux(st, h, lv))
            if debut + total > G:
                raise ValueError(f'{nom} : donnees hors du segment')
            tx = Texture(nom, t, w, h, st, fmt, lv, bytes(data[S + debut:S + debut + total]))
            tx.origine = (debut, debut + total)
            textures.append(tx)
    if not textures:
        return None

    # tous les pointeurs du segment systeme vers le segment graphique (tampons de sommets, d'indices, textures)
    refs = []
    for i in range(0, S, 8):
        v = q(i)
        # (les blocs du segment graphique sont alignes sur 16 octets : filtre les faux positifs, ex. du texte)
        if v >> 32 == 0 and v >> 28 == 6 and (v & 0x0FFFFFFF) < G and v % 16 == 0:
            refs.append((i, v & 0x0FFFFFFF))
    zones = sorted(t.origine for t in textures)
    for (a, b), (c, _) in zip(zones, zones[1:]):
        if b > c:
            raise ValueError('donnees de textures qui se chevauchent')
    debuts = {t.origine[0]: t for t in textures}
    if len(debuts) != len(textures):
        raise ValueError('donnees partagees entre textures')

    # le reste du segment graphique (geometrie) est garde par morceaux, deplaces d'un bloc
    pages = pages_origine(gf)
    if sum(p[1] for p in pages) != G:
        raise ValueError('pages graphiques incoherentes')
    morceaux = []
    for ps, pt in pages:
        pe = ps + pt
        curseur = ps
        for a, b in zones:
            if b <= ps or a >= pe:
                continue
            if a < ps or b > pe:
                raise ValueError('texture a cheval sur deux pages')
            if a > curseur:
                morceaux.append([curseur, a])
            curseur = max(curseur, b)
        if curseur < pe:
            morceaux.append([curseur, pe])
    cibles = sorted({c for _, c in refs if c not in debuts})
    utiles = []
    for m in morceaux:
        dedans = [c for c in cibles if m[0] <= c < m[1]]
        if dedans:
            utiles.append([min(dedans), m[1]])
    for _, c in refs:
        if c in debuts or any(a <= c < b for a, b in utiles):
            continue
        # pointeur vers l'interieur d'une texture (autre texture qui partage ses donnees, frequent dans les
        # modeles convertis) : la texture est deplacee telle quelle, sans etre reduite
        conteneur = next((t for t in textures if t.origine[0] < c < t.origine[1]), None)
        if conteneur is None:
            raise ValueError('pointeur graphique inattendu')
        conteneur.fige = True
    return {'ext': ext, 'version': version, 'sf': sf, 'gf': gf, 'S': S, 'G': G, 'data': data,
            'textures': textures, 'refs': refs, 'morceaux': utiles}


def blocs(res):
    return [b - a for a, b in res['morceaux']] + [t.taille() for t in res['textures']]


def ecrire_ressource(res, chemin):
    data, S, tex, morceaux = res['data'], res['S'], res['textures'], res['morceaux']
    disp = disposer(blocs(res))
    if not disp:
        raise ValueError('impossible de ranger les donnees dans des pages')
    flags, positions, total = disp
    pos_m, pos_t = positions[:len(morceaux)], positions[len(morceaux):]
    systeme = bytearray(data[:S])
    graphique = bytearray(total)
    for (a, b), pos in zip(morceaux, pos_m):
        graphique[pos:pos + b - a] = data[S + a:S + b]
    nouv_texture = {}
    for t, pos in zip(tex, pos_t):
        graphique[pos:pos + t.taille()] = t.donnees
        struct.pack_into('<HHHHI', systeme, t.decal + 0x50, t.w, t.h, 1, t.st, t.fmt)
        systeme[t.decal + 0x5D] = t.lv
        nouv_texture[t.origine[0]] = pos
    for i, c in res['refs']:
        if c in nouv_texture:
            n = nouv_texture[c]
        elif any(t.origine[0] < c < t.origine[1] for t in tex):
            t = next(t for t in tex if t.origine[0] < c < t.origine[1])
            n = nouv_texture[t.origine[0]] + (c - t.origine[0])
        else:
            k = next(k for k, (a, b) in enumerate(morceaux) if a <= c < b)
            n = pos_m[k] + (c - morceaux[k][0])
        struct.pack_into('<Q', systeme, i, 0x60000000 | n)
    gf = (res['gf'] & 0xF0000000) | flags
    corps = zlib.compress(bytes(systeme + graphique), 9)[2:-4]  # deflate brut
    tmp = chemin + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(b'RSC7' + struct.pack('<III', res['version'], res['sf'], gf) + corps)
    os.replace(tmp, chemin)
    return total


# compatibilite avec les premieres versions du script
lire_ytd = lire_ressource


def taille_physique(res):
    d = disposer(blocs(res))
    return d[2] if d else sum(blocs(res)) * 2


def optimiser(res, cible, max_dim, min_dim, forcer):
    tex = res['textures']
    if max_dim:
        for t in tex:
            while max(t.w, t.h) > max_dim and t.reductible(16):
                t.reduire()
    for plancher in ([min_dim] + ([128, 64] if forcer else [])):
        while taille_physique(res) > cible:
            candidats = [t for t in tex if t.reductible(plancher)]
            if not candidats:
                break
            max(candidats, key=lambda t: t.taille()).reduire()
        if taille_physique(res) <= cible:
            break
    return taille_physique(res)


# ---------------------------------------------------------------------------------------------------------------


def fichiers(chemins):
    for c in chemins:
        if os.path.isfile(c):
            yield c
        else:
            for base, _, fs in os.walk(c):
                for f in sorted(fs):
                    yield os.path.join(base, f)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('chemins', nargs='+')
    ap.add_argument('--cible', type=float, default=15.0)
    ap.add_argument('--max-dim', type=int, default=0)
    ap.add_argument('--min-dim', type=int, default=256)
    ap.add_argument('--forcer', action='store_true')
    ap.add_argument('--sauvegarde', default='textures_originales')
    ap.add_argument('--sans-sauvegarde', action='store_true')
    ap.add_argument('--simulation', action='store_true')
    a = ap.parse_args()
    cible = int(a.cible * MO)

    gain = 0
    n_ok = 0
    trop_gros = []
    erreurs = []
    restent = []
    for chemin in fichiers(a.chemins):
        ext = chemin.lower().rsplit('.', 1)[-1]
        if ext not in VERSIONS:
            continue
        try:
            with open(chemin, 'rb') as f:
                tete = f.read(16)
        except OSError:
            continue
        if tete[:4] != b'RSC7':
            continue
        _, sf, gf = struct.unpack_from('<III', tete, 4)
        physique, virtuel = taille_flags(gf), taille_flags(sf)
        if virtuel > 16 * MO:
            trop_gros.append((virtuel, chemin))
        if physique <= cible and not a.max_dim:
            continue
        try:
            res = lire_ressource(chemin)
            if res is None:
                if physique > 16 * MO:
                    erreurs.append((chemin, f'{physique / MO:.0f} Mo de geometrie, aucune texture integree'))
                continue
            avant_fichier = os.path.getsize(chemin)
            apres = optimiser(res, cible, a.max_dim, a.min_dim, a.forcer)
            reduites = [t for t in res['textures'] if t.reduite]
            if not reduites:
                if physique > cible:
                    restent.append((physique, chemin))
                continue
            if apres > cible:
                restent.append((apres, chemin))
            detail = ', '.join(f'{t.nom} {t.w}x{t.h}' for t in sorted(reduites, key=lambda t: -t.taille())[:4])
            print(f'{chemin}\n    {physique / MO:.1f} Mo -> {apres / MO:.1f} Mo, {len(reduites)} textures reduites ({detail}...)')
            if a.simulation:
                continue
            if not a.sans_sauvegarde:
                dest = os.path.join(a.sauvegarde, os.path.relpath(os.path.abspath(chemin), os.path.abspath(os.sep)))
                if not os.path.exists(dest):
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    shutil.copy2(chemin, dest)
            ecrire_ressource(res, chemin)
            verif = lire_ressource(chemin)  # relecture de controle
            if verif is None or len(verif['textures']) != len(res['textures']) or len(verif['refs']) != len(res['refs']):
                raise ValueError('relecture : contenu different')
            gain += avant_fichier - os.path.getsize(chemin)
            n_ok += 1
        except Exception as e:  # un fichier illisible ne bloque pas les autres
            erreurs.append((chemin, str(e)))

    print(f'\n{n_ok} fichier(s) optimise(s), {gain / MO:.0f} Mo gagnes sur le disque.')
    if not a.simulation and not a.sans_sauvegarde and n_ok:
        print(f'Originaux copies dans : {os.path.abspath(a.sauvegarde)}')
    if restent:
        print('\nToujours au-dessus de la cible (relancer avec --forcer ou --min-dim 128) :')
        for t, c in sorted(restent, reverse=True):
            print(f'  {t / MO:.1f} Mo  {c}')
    if erreurs:
        print('\nNon modifies (structure non geree, fichier laisse tel quel) :')
        for c, e in erreurs:
            print(f'  {c} : {e}')
    if trop_gros:
        print('\nMemoire virtuelle au-dessus de 16 Mo (geometrie et physique du modele, les textures n\'y sont pas) :')
        for t, c in sorted(trop_gros, reverse=True)[:40]:
            print(f'  {t / MO:.1f} Mo  {c}')
        if len(trop_gros) > 40:
            print(f'  ... et {len(trop_gros) - 40} autres')


if __name__ == '__main__':
    main()
