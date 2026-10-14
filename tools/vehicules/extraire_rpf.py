#!/usr/bin/env python3
"""Extracteur RPF7 (dlc.rpf de mods solo non chiffres 'OPEN') pour convertir une voiture en ressource FiveM.
Usage : python3 tools/vehicules/extraire_rpf.py dlc.rpf dossier_sortie
Les .yft/.ytd sont dans <sortie>/x64/vehicles.rpf_/ et les .meta dans <sortie>/data/."""
import os, struct, sys, zlib


def extraire(data, sortie, prefixe=''):
    magic, n, nlen, enc = struct.unpack_from('<4sIII', data, 0)
    if magic != b'7FPR':
        raise ValueError('pas un RPF7')
    if enc not in (0, 0x4E45504F):
        raise ValueError('archive chiffree (0x%x)' % enc)
    entrees = [data[16 + i * 16:32 + i * 16] for i in range(n)]
    noms = data[16 + n * 16:16 + n * 16 + nlen]

    def nom(off):
        return noms[off:noms.index(b'\0', off)].decode('utf-8', 'replace')

    def parcourir(idx, chemin):
        e = entrees[idx]
        name_off, typ = struct.unpack_from('<II', e, 0)
        if typ == 0x7FFFFF00:  # dossier
            _, _, first, count = struct.unpack('<IIII', e)
            for j in range(first, first + count):
                parcourir(j, chemin)
            return
        name_off = struct.unpack_from('<H', e, 0)[0]
        size = int.from_bytes(e[2:5], 'little')
        off = int.from_bytes(e[5:8], 'little')
        nm = nom(name_off)
        # reconstruire le chemin via les dossiers parents
        p = os.path.join(sortie, prefixe, chemins.get(idx, ''), nm)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if off & 0x800000:  # ressource (yft, ytd, ymap...) : copie brute avec en-tete RSC7
            off &= 0x7FFFFF
            debut = off * 512
            if size == 0xFFFFFF:
                # ressource > 16 Mo : les 16 premiers octets sont brouilles, on reconstruit l'en-tete RSC7
                h = data[debut:debut + 16]
                size = (h[7] << 0) | (h[14] << 8) | (h[5] << 16) | (h[2] << 24)
                sysf, gfxf = struct.unpack_from('<II', e, 8)
                version = (((sysf >> 28) & 0xF) << 4) | ((gfxf >> 28) & 0xF)
                blob = b'RSC7' + struct.pack('<III', version, sysf, gfxf) + data[debut + 16:debut + size]
            else:
                blob = data[debut:debut + size]
        else:  # fichier binaire
            usize, encr = struct.unpack_from('<II', e, 8)
            debut = off * 512
            if size == 0:
                blob = data[debut:debut + usize]
            else:
                blob = zlib.decompress(data[debut:debut + size], -15)
        open(p, 'wb').write(blob)
        if nm.lower().endswith('.rpf') and len(blob) >= 16:
            try:
                extraire(blob, os.path.join(sortie, prefixe, chemins.get(idx, ''), nm + '_'), '')
            except (ValueError, struct.error) as ex:
                print('  rpf imbrique %s : %s' % (nm, ex))

    # table des chemins (index -> chemin relatif du dossier parent)
    chemins = {}

    def chemin_dossiers(idx, chemin):
        e = entrees[idx]
        name_off, typ = struct.unpack_from('<II', e, 0)
        if typ == 0x7FFFFF00:
            _, _, first, count = struct.unpack('<IIII', e)
            sous = chemin if idx == 0 else os.path.join(chemin, nom(name_off))
            for j in range(first, first + count):
                chemins[j] = sous
                chemin_dossiers(j, sous)

    chemin_dossiers(0, '')
    parcourir(0, '')


if __name__ == '__main__':
    extraire(open(sys.argv[1], 'rb').read(), sys.argv[2])
    for b, _, fs in os.walk(sys.argv[2]):
        for f in fs:
            print(os.path.relpath(os.path.join(b, f), sys.argv[2]), os.path.getsize(os.path.join(b, f)))
