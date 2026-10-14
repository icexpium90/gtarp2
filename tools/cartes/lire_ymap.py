#!/usr/bin/env python3
"""Lit un ou plusieurs .ymap (RSC7) et affiche l'emprise des entites, le nombre d'objets et les instances MLO.
Usage : python3 lire_ymap.py fichier.ymap [...]   (--json pour une sortie machine)"""
import json, struct, sys, zlib


# identifiants des structures meta (CodeWalker MetaName)
H_MAP, H_ENT, H_MLO = 0xD3593FA6, 0xCE501483, 0x09CC28BE


def taille_pages(flags):
    base = 0x2000 << (flags & 0xF)
    s = base * ((flags >> 4) & 1) + base * 2 * ((flags >> 5) & 3) + base * 4 * ((flags >> 7) & 0xF)
    s += base * 8 * ((flags >> 11) & 0x3F) + base * 16 * ((flags >> 17) & 0x7F) + base * 32 * ((flags >> 24) & 1)
    s += (base >> 1) * ((flags >> 25) & 1) + (base >> 2) * ((flags >> 26) & 1) + (base >> 3) * ((flags >> 27) & 1)
    return s


def lire(chemin):
    raw = open(chemin, 'rb').read()
    if raw[:4] != b'RSC7':
        raise ValueError('pas une ressource RSC7')
    sysf = struct.unpack_from('<I', raw, 8)[0]
    data = zlib.decompress(raw[16:], -15)
    def off(ptr):
        return ptr & 0x0FFFFFFF if (ptr >> 28) == 5 else (ptr & 0x0FFFFFFF) + taille_pages(sysf)
    nblocs = struct.unpack_from('<H', data, 0x4C)[0]
    blocs = off(struct.unpack_from('<Q', data, 0x30)[0])
    res = {'fichier': chemin, 'entites': [], 'mlo': [], 'nom': None}
    for i in range(nblocs):
        h, ln, ptr = struct.unpack_from('<IIQ', data, blocs + i * 16)
        o = off(ptr)
        if h == H_MAP:
            res['nom'] = struct.unpack_from('<I', data, o + 8)[0]
            res['emprise'] = [struct.unpack_from('<3f', data, o + 64), struct.unpack_from('<3f', data, o + 80)]
        elif h in (H_ENT, H_MLO):
            taille = 128 if h == H_ENT else 160
            for k in range(ln // taille):
                b = o + k * taille
                arch = struct.unpack_from('<I', data, b + 8)[0]
                pos = struct.unpack_from('<3f', data, b + 32)
                (res['mlo'] if h == H_MLO else res['entites']).append((arch, pos))
    return res


if __name__ == '__main__':
    sortie = []
    for f in [a for a in sys.argv[1:] if not a.startswith('--')]:
        try:
            r = lire(f)
        except Exception as ex:
            print(f'{f} : erreur {ex}')
            continue
        tous = r['entites'] + r['mlo']
        if tous:
            xs = [p[1][0] for p in tous]; ys = [p[1][1] for p in tous]; zs = [p[1][2] for p in tous]
            r['centre'] = (round(sum(xs) / len(xs), 1), round(sum(ys) / len(ys), 1), round(sum(zs) / len(zs), 1))
            r['boite'] = (round(min(xs)), round(max(xs)), round(min(ys)), round(max(ys)))
        sortie.append(r)
        if '--json' not in sys.argv:
            print(f"{f.split('/')[-1]} : {len(r['entites'])} objets, {len(r['mlo'])} MLO, centre {r.get('centre')}, boite {r.get('boite')}")
            for a, p in r['mlo']:
                print(f'   MLO {a:#010x} a ({p[0]:.2f}, {p[1]:.2f}, {p[2]:.2f})')
    if '--json' in sys.argv:
        print(json.dumps(sortie))
