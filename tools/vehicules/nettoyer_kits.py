#!/usr/bin/env python3
"""
Retire des bodykits les options dont le modele 3D n'existe nulle part sur le serveur
(sinon : piece invisible, ou piece d'origine qui disparait quand on la choisit).
Une option sans fichier est gardee seulement si son libelle indique une suppression (No / None / Remove / Stock...).
Peut aussi retirer completement un modele d'une ressource (--retirer modele).

Usage : python3 tools/vehicules/nettoyer_kits.py <dossier_ressource> [--retirer modele ...]
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, '..', '..'))
DEST = os.path.join(RACINE, 'resources', '[Project-Terrific]', '[vehicules]')
SANS = re.compile(r'\b(no|none|remove|removed|delete|stock|without|sans|off)\b', re.I)


def tous_les_modeles_stream():
    noms = set()
    for f in glob.glob(os.path.join(glob.escape(DEST), '*', 'stream', '**', '*.yft'), recursive=True):
        noms.add(os.path.basename(f).lower()[:-4])
    return noms


def charger(p):
    brut = open(p, encoding='utf-8', errors='ignore').read()
    return ET.ElementTree(ET.fromstring(brut.strip().lstrip('﻿')))


def ecrire(arbre, p):
    ET.indent(arbre, space='  ')
    arbre.write(p, encoding='UTF-8', xml_declaration=True)


def nettoyer(res, retirer=()):
    flux = tous_les_modeles_stream()
    data = os.path.join(res, 'data')
    retires = 0
    p = os.path.join(data, 'carcols.meta')
    if os.path.isfile(p):
        a = charger(p)
        for vis in a.getroot().iter('visibleMods'):
            for piece in list(vis):
                nm = (piece.findtext('modelName') or '').strip().lower()
                lab = (piece.findtext('modShopLabel') or '').replace('_', ' ')
                if nm and nm != 'null' and nm not in flux and not SANS.search(lab):
                    vis.remove(piece)
                    retires += 1
                    continue
                lies = piece.find('linkedModels')
                if lies is not None:
                    for l in list(lies):
                        if (l.text or '').strip().lower() not in flux:
                            lies.remove(l)
        ecrire(a, p)
    for modele in retirer:
        for f, cle in (('vehicles.meta', 'modelName'), ('carvariations.meta', 'modelName'), ('handling.meta', 'handlingName')):
            pf = os.path.join(data, f)
            if not os.path.isfile(pf):
                continue
            a = charger(pf)
            for parent in a.getroot().iter():
                for it in list(parent):
                    if it.tag == 'Item' and ((it.findtext(cle) or '').strip().lower() == modele
                                             or (it.findtext('child') or '').strip().lower() == modele):
                        parent.remove(it)
            ecrire(a, pf)
    return retires


if __name__ == '__main__':
    args = sys.argv[1:]
    res = os.path.abspath(args[0])
    retirer = [a.lower() for a in args[args.index('--retirer') + 1:]] if '--retirer' in args else []
    n = nettoyer(res, retirer)
    print('%s : %d option(s) de bodykit sans fichier retiree(s)%s' % (os.path.basename(res), n,
          (', modele(s) retire(s) : ' + ', '.join(retirer)) if retirer else ''))
