#!/usr/bin/env python3
"""Optimiseur de textures (.ytd) pour FiveM : ramene chaque dictionnaire de textures sous une taille cible
(16 Mo par defaut, seuil de l'avertissement "oversized asset" de FiveM) en reduisant les plus grosses textures.

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
Seuls les .ytd sont modifies. Les .yft / .ydr / .ydd trop gros (textures integrees ou geometrie) sont listes a la fin.

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


def lire_ytd(chemin):
    brut = open(chemin, 'rb').read()
    if brut[:4] != b'RSC7':
        raise ValueError('pas une ressource RSC7')
    version, sf, gf = struct.unpack_from('<III', brut, 4)
    if version != 13:
        raise ValueError(f'version {version} (13 attendue)')
    data = bytearray(zlib.decompress(brut[16:], -15))
    S, G = taille_flags(sf), taille_flags(gf)
    if len(data) != S + G:
        raise ValueError('taille des segments incoherente')

    def sys_(p):
        if p >> 28 != 5:
            raise ValueError('pointeur systeme attendu')
        return p & 0x0FFFFFFF

    tp, tc = struct.unpack_from('<QH', data, 0x30)
    textures = []
    vus = set()
    for i in range(tc):
        t = sys_(struct.unpack_from('<Q', data, sys_(tp) + 8 * i)[0])
        np_ = struct.unpack_from('<Q', data, t + 0x28)[0]
        o = sys_(np_)
        nom = bytes(data[o:o + 128]).split(b'\0')[0].decode('latin-1')
        w, h, d, st, fmt = struct.unpack_from('<HHHHI', data, t + 0x50)
        lv = data[t + 0x5D]
        dp = struct.unpack_from('<Q', data, t + 0x70)[0]
        if dp >> 28 != 6:
            raise ValueError(f'{nom} : pointeur de donnees inattendu')
        if fmt not in BLOCS and fmt not in OCTETS_PIXEL:
            raise ValueError(f'{nom} : format {hex(fmt)} non gere')
        if d != 1:
            raise ValueError(f'{nom} : texture 3D / cube non geree')
        if st == 0:
            raise ValueError(f'{nom} : pas de ligne nul')
        debut = S + (dp & 0x0FFFFFFF)
        total = sum(niveaux(st, h, lv))
        if (dp & 0x0FFFFFFF) + total > G:
            raise ValueError(f'{nom} : donnees hors du segment')
        if dp in vus:
            raise ValueError(f'{nom} : donnees partagees entre textures')
        vus.add(dp)
        textures.append(Texture(nom, t, w, h, st, fmt, lv, bytes(data[debut:debut + total])))
    # verifie que les donnees ne se chevauchent pas
    zones = sorted((struct.unpack_from('<Q', data, x.decal + 0x70)[0] & 0x0FFFFFFF, x.taille()) for x in textures)
    for (a, ta), (b, _) in zip(zones, zones[1:]):
        if a + ta > b:
            raise ValueError('donnees de textures qui se chevauchent')
    return {'version': version, 'sf': sf, 'gf': gf, 'S': S, 'G': G, 'data': data, 'textures': textures}


def ecrire_ytd(ytd, chemin):
    data, S, tex = ytd['data'], ytd['S'], ytd['textures']
    disp = disposer([t.taille() for t in tex])
    if not disp:
        raise ValueError('impossible de ranger les textures dans des pages')
    flags, positions, total = disp
    systeme = bytearray(data[:S])
    graphique = bytearray(total)
    for t, pos in zip(tex, positions):
        graphique[pos:pos + t.taille()] = t.donnees
        struct.pack_into('<HHHHI', systeme, t.decal + 0x50, t.w, t.h, 1, t.st, t.fmt)
        systeme[t.decal + 0x5D] = t.lv
        struct.pack_into('<Q', systeme, t.decal + 0x70, 0x60000000 | pos)
    gf = (ytd['gf'] & 0xF0000000) | flags
    corps = zlib.compress(bytes(systeme + graphique), 9)[2:-4]  # deflate brut
    tmp = chemin + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(b'RSC7' + struct.pack('<III', ytd['version'], ytd['sf'], gf) + corps)
    os.replace(tmp, chemin)
    return total


def taille_physique(tex):
    d = disposer([t.taille() for t in tex])
    return d[2] if d else sum(t.taille() for t in tex) * 2


def optimiser(ytd, cible, max_dim, min_dim, forcer):
    tex = ytd['textures']
    if max_dim:
        for t in tex:
            while max(t.w, t.h) > max_dim and t.reductible(16):
                t.reduire()
    for plancher in ([min_dim] + ([128, 64] if forcer else [])):
        while taille_physique(tex) > cible:
            candidats = [t for t in tex if t.reductible(plancher)]
            if not candidats:
                break
            max(candidats, key=lambda t: t.taille()).reduire()
        if taille_physique(tex) <= cible:
            break
    return taille_physique(tex)


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
        if ext not in ('ytd', 'yft', 'ydr', 'ydd'):
            continue
        try:
            with open(chemin, 'rb') as f:
                tete = f.read(16)
        except OSError:
            continue
        if tete[:4] != b'RSC7':
            continue
        _, sf, gf = struct.unpack_from('<III', tete, 4)
        physique = taille_flags(gf)
        if ext != 'ytd':
            if physique > 16 * MO:
                trop_gros.append((physique, chemin))
            continue
        if physique <= cible and not a.max_dim:
            continue
        try:
            ytd = lire_ytd(chemin)
            avant_fichier = os.path.getsize(chemin)
            apres = optimiser(ytd, cible, a.max_dim, a.min_dim, a.forcer)
            reduites = [t for t in ytd['textures'] if t.reduite]
            if not reduites:
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
            ecrire_ytd(ytd, chemin)
            verif = lire_ytd(chemin)  # relecture de controle
            if len(verif['textures']) != len(ytd['textures']):
                raise ValueError('relecture : nombre de textures different')
            gain += avant_fichier - os.path.getsize(chemin)
            n_ok += 1
        except Exception as e:  # un fichier illisible ne bloque pas les autres
            erreurs.append((chemin, str(e)))

    print(f'\n{n_ok} fichier(s) .ytd optimise(s), {gain / MO:.0f} Mo gagnes sur le disque.')
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
        print('\nModeles (.yft / .ydr / .ydd) au-dessus de 16 Mo : textures integrees ou geometrie, non modifies ici :')
        for t, c in sorted(trop_gros, reverse=True)[:40]:
            print(f'  {t / MO:.1f} Mo  {c}')
        if len(trop_gros) > 40:
            print(f'  ... et {len(trop_gros) - 40} autres')


if __name__ == '__main__':
    main()
