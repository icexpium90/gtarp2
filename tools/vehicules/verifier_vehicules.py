#!/usr/bin/env python3
"""
Verificateur de vehicules addon pour LUSO RP (FiveM / QBCore, build 3889).

Usage :
    python3 tools/vehicules/verifier_vehicules.py                      # analyse resources/[Project-Terrific]/[vehicules]
    python3 tools/vehicules/verifier_vehicules.py chemin/vers/dossier  # analyse un autre dossier
    python3 tools/vehicules/verifier_vehicules.py --apply              # + ajoute les vehicules valides dans qb-core

Pour chaque ressource vehicule, il controle :
  * fxmanifest.lua : fx_version, game 'gta5', files{} et data_file pour chaque .meta present
  * stream/        : <modele>.yft, <modele>_hi.yft, <modele>.ytd ; taille > 16 Mo (oversized asset)
  * vehicles.meta  : handlingId present dans handling.meta, txdParent / textureDict, doublons
  * carvariations  : chaque modele a une entree et des kits declares
  * carcols.meta   : les kits existent, ids de kit uniques sur tout le serveur (sinon mauvais tuning),
                     pieces de bodykit (visibleMods) dont le .yft est bien dans stream/,
                     pieces moteur (statMods) : ENGINE, BRAKES, GEARBOX, SUSPENSION, ARMOUR
  * conflits       : nom de modele deja utilise par le jeu de base ou par une autre ressource
Le rapport est ecrit dans tools/vehicules/rapport_vehicules.md
"""
import os
import re
import sys
import json
import xml.etree.ElementTree as ET

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, '..', '..'))
DOSSIER_DEFAUT = os.path.join(RACINE, 'resources', '[Project-Terrific]', '[vehicules]')
VEHICLES_LUA = os.path.join(RACINE, 'resources', '[Project-Terrific]', '[core-important]', 'qb-core', 'shared', 'vehicles.lua')
JEU_DE_BASE = os.path.join(ICI, 'modeles_jeu_de_base.txt')
RAPPORT = os.path.join(ICI, 'rapport_vehicules.md')

TAILLE_MAX = 16 * 1024 * 1024
STATMODS_ATTENDUS = ['VMT_ENGINE', 'VMT_BRAKES', 'VMT_GEARBOX', 'VMT_SUSPENSION', 'VMT_ARMOUR']
DATA_FILES = {
    'vehicles.meta': 'VEHICLE_METADATA_FILE',
    'carvariations.meta': 'VEHICLE_VARIATION_FILE',
    'carcols.meta': 'CARCOLS_FILE',
    'handling.meta': 'HANDLING_FILE',
    'vehiclelayouts.meta': 'VEHICLE_LAYOUTS_FILE',
}
CLASSES_QB = {
    'VC_COMPACT': 'Compacts', 'VC_SEDAN': 'Sedans', 'VC_SUV': 'SUVs', 'VC_COUPE': 'Coupes',
    'VC_MUSCLE': 'Muscle', 'VC_SPORT_CLASSIC': 'Sports Classics', 'VC_SPORT': 'Sports',
    'VC_SUPER': 'Super', 'VC_MOTORCYCLE': 'Motorcycles', 'VC_OFF_ROAD': 'Off Road', 'VC_VAN': 'Vans',
}


def lire_xml(chemin):
    """Parse un .meta ; tolere les commentaires et quelques erreurs courantes."""
    brut = open(chemin, encoding='utf-8', errors='ignore').read()
    brut = re.sub(r'<!--.*?-->', '', brut, flags=re.S)
    brut = brut.replace('&', '&amp;').replace('&amp;amp;', '&amp;')
    try:
        return ET.fromstring(brut.strip().lstrip('﻿')), None
    except ET.ParseError as e:
        return None, str(e)


def txt(el, chemin, defaut=''):
    n = el.find(chemin)
    return (n.text or '').strip() if n is not None and n.text else defaut


def trouver_metas(res):
    metas = {}
    for base, _, fichiers in os.walk(res):
        if os.sep + 'stream' in base:
            continue
        for f in fichiers:
            fl = f.lower()
            if fl.endswith('.meta'):
                for cle in DATA_FILES:
                    if fl == cle or fl.endswith(cle):
                        metas.setdefault(cle, []).append(os.path.join(base, f))
    return metas


def fichiers_stream(res):
    out = {}
    for base, _, fichiers in os.walk(res):
        for f in fichiers:
            if f.lower().endswith(('.yft', '.ytd')):
                out[f.lower()] = os.path.join(base, f)
    return out


def analyser_ressource(res, jeu_de_base, global_yft=frozenset()):
    nom = os.path.basename(res)
    err, warn, infos = [], [], []
    vehicules, kits_declares, kits_utilises = [], {}, []

    manifest = os.path.join(res, 'fxmanifest.lua')
    if not os.path.isfile(manifest):
        manifest_txt = ''
        err.append('fxmanifest.lua absent (le vieux __resource.lua n\'est pas supporte proprement)')
    else:
        manifest_txt = open(manifest, encoding='utf-8', errors='ignore').read()
        if 'fx_version' not in manifest_txt:
            err.append('fxmanifest.lua : fx_version manquant')
        if not re.search(r"game[s]?\s*['\"{]", manifest_txt):
            err.append("fxmanifest.lua : game 'gta5' manquant")

    metas = trouver_metas(res)
    stream = fichiers_stream(res)
    if not stream:
        err.append('aucun .yft/.ytd trouve (dossier stream/ vide ou absent)')
    for f, p in stream.items():
        if os.path.getsize(p) > TAILLE_MAX:
            warn.append('%s fait %.1f Mo (> 16 Mo : "oversized asset", textures a compresser)' % (f, os.path.getsize(p) / 1048576))

    for cle, typ in DATA_FILES.items():
        if cle in metas and manifest_txt:
            if typ not in manifest_txt:
                err.append("fxmanifest.lua : data_file '%s' manquant pour %s" % (typ, cle))
    for cle in ('vehicles.meta', 'handling.meta', 'carvariations.meta'):
        if cle not in metas:
            err.append('%s absent' % cle)
    if 'carcols.meta' not in metas:
        warn.append('carcols.meta absent : aucun bodykit ni piece moteur, tuning limite au jeu de base')

    # handling
    handlings = set()
    for p in metas.get('handling.meta', []):
        x, e = lire_xml(p)
        if x is None:
            err.append('handling.meta illisible : %s' % e)
            continue
        for it in x.iter('Item'):
            h = txt(it, 'handlingName')
            if h:
                handlings.add(h.upper())

    # vehicles.meta
    for p in metas.get('vehicles.meta', []):
        x, e = lire_xml(p)
        if x is None:
            err.append('vehicles.meta illisible : %s' % e)
            continue
        for it in x.iter('Item'):
            modele = txt(it, 'modelName')
            if not modele:
                continue
            m = modele.lower()
            v = {
                'modele': m,
                'nom': txt(it, 'gameName', modele),
                'marque': txt(it, 'vehicleMakeName', ''),
                'classe': txt(it, 'vehicleClass', ''),
                'handling': txt(it, 'handlingId', ''),
                'txd': txt(it, 'txdName', m),
            }
            vehicules.append(v)
            if m in jeu_de_base:
                err.append("'%s' porte le nom d'un vehicule du jeu de base : il le remplacera (renommer le spawn code)" % m)
            for suffixe in ('.yft', '_hi.yft'):
                if m + suffixe not in stream:
                    (err if suffixe == '.yft' else warn).append('%s%s absent de stream/' % (m, suffixe))
            if v['txd'].lower() + '.ytd' not in stream:
                warn.append('%s.ytd absent (textures manquantes ou integrees au yft)' % v['txd'])
            hjeu = os.path.join(ICI, 'handlings_jeu_de_base.txt')
            hjeu = set(l.strip().upper() for l in open(hjeu)) if os.path.isfile(hjeu) else set()
            if v['handling'] and v['handling'].upper() not in handlings and v['handling'].upper() not in hjeu:
                err.append("'%s' : handlingId '%s' introuvable dans handling.meta" % (m, v['handling']))

    # carcols.meta : kits, bodykits, pieces moteur
    for p in metas.get('carcols.meta', []):
        x, e = lire_xml(p)
        if x is None:
            err.append('carcols.meta illisible : %s' % e)
            continue
        kits = x.find('Kits')
        for kit in (kits if kits is not None else []):
            kname = txt(kit, 'kitName')
            kid = kit.find('id')
            kid = kid.get('value') if kid is not None else None
            kits_declares[kname] = kid
            visibles = kit.find('visibleMods')
            pieces = list(visibles) if visibles is not None else []
            manquants = set()
            vides = set()
            types = set()
            for piece in pieces:
                mn = txt(piece, 'modelName').lower()
                types.add(txt(piece, 'type'))
                os_ = piece.find('turnOffBones')
                libelle = txt(piece, 'modShopLabel').replace('_', ' ')
                retire_piece = (os_ is not None and len(list(os_)) > 0
                                and re.search(r'\b(no|none|remove|removed|delete|stock|without|sans|off)\b', libelle, re.I))
                if mn in ('', 'null'):
                    continue  # emplacement vide volontaire (astuce de moddeur)
                if mn + '.yft' not in stream:
                    if mn in global_yft:
                        continue  # piece fournie par une autre ressource du serveur (stream global FiveM)
                    (vides if retire_piece else manquants).add(mn)
                lies = piece.find('linkedModels')
                for l in (lies if lies is not None else []):
                    ln = (l.text or '').strip().lower()
                    if ln and ln + '.yft' not in stream and ln not in global_yft:
                        manquants.add(ln)
            stat = kit.find('statMods')
            stats = set(txt(s, 'type') for s in (stat if stat is not None else []))
            infos.append('kit %s (id %s) : %d pieces de carrosserie sur %d emplacements, pieces moteur : %s'
                         % (kname, kid, len(pieces), len(types - {''}), ', '.join(sorted(stats)) or 'aucune'))
            for mn in sorted(manquants):
                err.append("bodykit %s : piece '%s.yft' absente de stream/ (piece invisible en jeu)" % (kname, mn))
            for mn in sorted(vides):
                infos.append("kit %s : option '%s' sans fichier, elle retire seulement une piece (normal pour une option \"sans\")" % (kname, mn))
            absents = [s for s in STATMODS_ATTENDUS if s not in stats]
            if absents:
                warn.append('kit %s : pieces moteur manquantes (%s) -> pas d\'amelioration possible au garage'
                            % (kname, ', '.join(a.replace('VMT_', '') for a in absents)))
            if kid is not None and kid.isdigit() and int(kid) < 1000:
                warn.append('kit %s : id %s < 1000, risque de collision avec les kits du jeu' % (kname, kid))

    # carvariations.meta
    for p in metas.get('carvariations.meta', []):
        x, e = lire_xml(p)
        if x is None:
            err.append('carvariations.meta illisible : %s' % e)
            continue
        vus = set()
        for it in x.iter('Item'):
            mn = txt(it, 'modelName').lower()
            if not mn:
                continue
            vus.add(mn)
            ks = it.find('kits')
            liste = [(k.text or '').strip() for k in (ks if ks is not None else []) if (k.text or '').strip()]
            if not liste:
                warn.append("'%s' : aucun kit dans carvariations.meta -> pas de tuning" % mn)
            for k in liste:
                kits_utilises.append(k)
                if k not in kits_declares and not k.startswith('0_default_modkit'):
                    err.append("'%s' utilise le kit '%s' qui n'existe pas dans carcols.meta" % (mn, k))
        for v in vehicules:
            if v['modele'] not in vus:
                err.append("'%s' absent de carvariations.meta" % v['modele'])

    return {'nom': nom, 'erreurs': err, 'avertissements': warn, 'infos': infos,
            'vehicules': vehicules, 'kits': kits_declares}


def ligne_qb(v, prix=150000):
    cat = CLASSES_QB.get(v['classe'].upper(), 'Sports')
    nom = v['nom'].replace("'", "\\'")
    marque = (v['marque'] or '').replace("'", "\\'")
    return ("    {['model'] = '%s', ['name'] = '%s', ['brand'] = '%s', ['price'] = %d, "
            "['categoryLabel'] = '%s', ['shop'] = 'tuner'}," % (v['modele'], nom, marque, prix, cat))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    appliquer = '--apply' in sys.argv
    dossier = os.path.abspath(args[0]) if args else DOSSIER_DEFAUT
    jeu = set()
    if os.path.isfile(JEU_DE_BASE):
        jeu = set(l.strip().lower() for l in open(JEU_DE_BASE) if l.strip())
    if not os.path.isdir(dossier):
        print('Dossier introuvable :', dossier)
        return 1
    ressources = sorted(os.path.join(dossier, d) for d in os.listdir(dossier)
                        if os.path.isdir(os.path.join(dossier, d)) and not d.startswith(('.', '_')))
    global_yft = set()
    for r in ressources:
        for base, _, fs in os.walk(r):
            global_yft |= set(f.lower()[:-4] for f in fs if f.lower().endswith('.yft'))
    # packs accessoires (jantes, sons) : pas de vehicles.meta ni de handling, on ne les traite pas comme des voitures
    accessoires = [r for r in ressources if not any(f.endswith('vehicles.meta') for _, _, fs in os.walk(r) for f in fs)]
    ressources = [r for r in ressources if r not in accessoires]
    resultats = [analyser_ressource(r, jeu, global_yft) for r in ressources]

    # conflits inter-ressources
    modeles, ids = {}, {}
    for r in resultats:
        for v in r['vehicules']:
            modeles.setdefault(v['modele'], []).append(r['nom'])
        for k, kid in r['kits'].items():
            if kid:
                ids.setdefault(kid, []).append('%s (%s)' % (k, r['nom']))
    conflits = ["modele '%s' declare dans plusieurs ressources : %s" % (m, ', '.join(l)) for m, l in modeles.items() if len(l) > 1]
    conflits += ['id de kit %s utilise plusieurs fois : %s -> le tuning affichera les pieces d\'une autre voiture'
                 % (i, ', '.join(l)) for i, l in ids.items() if len(l) > 1]

    deja = set()
    if os.path.isfile(VEHICLES_LUA):
        deja = set(m.lower() for m in re.findall(r"\['model'\]\s*=\s*'([^']+)'", open(VEHICLES_LUA, encoding='utf-8').read()))

    lignes = ['# Rapport vehicules addon', '', 'Dossier analyse : `%s`' % dossier, '',
              '%d ressource(s), %d vehicule(s).' % (len(resultats), sum(len(r['vehicules']) for r in resultats)), '']
    if accessoires:
        lignes += ['Packs accessoires (jantes, sons) non verifies comme des voitures : ' + ', '.join(os.path.basename(a) for a in accessoires), '']
    if conflits:
        lignes += ['## Conflits entre ressources', ''] + ['- ' + c for c in conflits] + ['']
    a_ajouter = []
    for r in resultats:
        statut = 'OK' if not r['erreurs'] else 'A CORRIGER'
        lignes += ['## %s : %s' % (r['nom'], statut), '']
        lignes += ['- Vehicules : ' + (', '.join('`%s` (%s)' % (v['modele'], v['nom']) for v in r['vehicules']) or 'aucun')]
        lignes += ['- ' + i for i in r['infos']]
        lignes += ['- ERREUR : ' + e for e in r['erreurs']]
        lignes += ['- attention : ' + w for w in r['avertissements']]
        lignes.append('')
        if not r['erreurs']:
            a_ajouter += [v for v in r['vehicules'] if v['modele'] not in deja]
    if a_ajouter:
        lignes += ['## Lignes qb-core a ajouter (shop "tuner")', '', '```lua'] + [ligne_qb(v) for v in a_ajouter] + ['```', '']
    open(RAPPORT, 'w', encoding='utf-8').write('\n'.join(lignes))
    print('\n'.join(lignes))

    if appliquer and a_ajouter:
        src = open(VEHICLES_LUA, encoding='utf-8').read()
        bloc = '    --- Vehicules addon (verifies par tools/vehicules/verifier_vehicules.py)\n' + \
               '\n'.join(ligne_qb(v) for v in a_ajouter) + '\n'
        idx = src.rindex('\n}\n\nfor i=1') + 1
        open(VEHICLES_LUA, 'w', encoding='utf-8').write(src[:idx] + bloc + src[idx:])
        print('\n%d vehicule(s) ajoute(s) a qb-core/shared/vehicles.lua (prix par defaut 150000 a ajuster).' % len(a_ajouter))
    return 1 if any(r['erreurs'] for r in resultats) or conflits else 0


if __name__ == '__main__':
    sys.exit(main())
