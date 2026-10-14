#!/usr/bin/env python3
"""
Importe des voitures addon deja au format FiveM/__resource.lua dans resources/[Project-Terrific]/[vehicules]
en corrigeant automatiquement les conflits qui cassent le tuning ou la conduite des autres voitures.

Usage : python3 tools/vehicules/importer_pack.py dossier_voiture [dossier_voiture ...]
        (un dossier = une ressource : metas + stream/)

Corrections appliquees a chaque voiture :
  * kits de tuning : nouvel id unique (>= 1600) et nom <id>_<modele>_modkit, references mises a jour
  * voiture sans kit : kit de performance ajoute (moteur, freins, boite, suspension, blindage)
  * eclairages / sirenes definis dans la voiture : nouvel id unique
  * handling portant le nom d'un vehicule du jeu ou deja pris : renomme d'apres le modele
  * pieces de bodykit au nom generique ou deja pris : prefixees par le nom du modele
  * __resource.lua remplace par un fxmanifest.lua propre
  * voiture dont le spawn code existe deja (jeu ou serveur) : ignoree
"""
import glob
import json
import os
import re
import shutil
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, '..', '..'))
DEST = os.path.join(RACINE, 'resources', '[Project-Terrific]', '[vehicules]')
JEU = set(l.strip().lower() for l in open(os.path.join(ICI, 'modeles_jeu_de_base.txt')) if l.strip())
HANDLING_JEU = os.path.join(ICI, 'handlings_jeu_de_base.txt')
HANDLING_JEU = set(l.strip().upper() for l in open(HANDLING_JEU) if l.strip()) if os.path.isfile(HANDLING_JEU) else set()
LIBELLES_JEU = set(l.strip().upper() for l in open(os.path.join(ICI, 'libelles_jeu_de_base.txt')) if l.strip())
LAYOUTS_JEU = set(l.strip().upper() for l in open(os.path.join(ICI, 'layouts_jeu_de_base.txt')) if l.strip())


def nettoyer_layouts(texte, veh):
    """Garde seulement les entrees de vehiclelayouts propres a la voiture (atteintes depuis vehicles.meta),
    jamais une copie d'une entree du jeu (layout du jeu ou nom contenant un modele du jeu)."""
    import xml.etree.ElementTree as ET
    try:
        racine = ET.fromstring(re.sub(r'<!--.*?-->', '', texte, flags=re.S).strip().lstrip('\ufeff'))
    except ET.ParseError:
        return ''
    entrees = {}
    for sec in racine:
        for it in sec:
            nom = it.findtext('Name')
            if nom:
                entrees[nom.strip()] = (sec, it)
    def du_jeu(n):
        return n.upper() in LAYOUTS_JEU or any(tok.lower() in JEU for tok in n.split('_'))
    gardes, a_voir = set(), [n for n in entrees if n in veh and not du_jeu(n)]
    while a_voir:
        n = a_voir.pop()
        if n in gardes:
            continue
        gardes.add(n)
        corps = ET.tostring(entrees[n][1], encoding='unicode')
        a_voir += [m for m in entrees if m not in gardes and m in corps and not du_jeu(m)]
    if not gardes:
        return ''
    for n, (sec, it) in entrees.items():
        if n not in gardes:
            sec.remove(it)
    arbre = ET.ElementTree(racine)
    ET.indent(arbre, space='  ')
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(racine, encoding='unicode') + '\n'

TYPES = {'vehicles.meta': 'VEHICLE_METADATA_FILE', 'handling.meta': 'HANDLING_FILE', 'carcols.meta': 'CARCOLS_FILE',
         'carvariations.meta': 'VEHICLE_VARIATION_FILE', 'vehiclelayouts.meta': 'VEHICLE_LAYOUTS_FILE'}
STREAM_EXT = ('.yft', '.ytd', '.ycd', '.ydr', '.ytyp', '.ybn')

STAT = ('        <Item>\n          <identifier />\n          <modifier value="%d" />\n          <audioApply value="1.000000" />\n'
        '          <weight value="%d" />\n          <type>%s</type>\n        </Item>')


def kit_perf(nom, kid):
    stats = []
    for t, mods, w in [('VMT_ENGINE', [25, 50, 75, 100], 20), ('VMT_BRAKES', [25, 50, 100], 5), ('VMT_GEARBOX', [25, 50, 100], 5),
                       ('VMT_SUSPENSION', [25, 50, 75, 100], 5), ('VMT_ARMOUR', [20, 40, 60, 80, 100], 0)]:
        stats += [STAT % (m, w, t) for m in mods]
    return ('    <Item>\n      <kitName>%s</kitName>\n      <id value="%d" />\n      <kitType>MKT_SPECIAL</kitType>\n'
            '      <visibleMods />\n      <linkMods />\n      <statMods>\n%s\n      </statMods>\n      <slotNames />\n'
            '      <liveryNames />\n    </Item>\n' % (nom, kid, '\n'.join(stats)))


def etat_serveur():
    """ids de kits/eclairages, handlings, fichiers stream et modeles deja utilises sur le serveur."""
    ids, hand, fichiers, modeles = set(), set(), set(), set()
    for res in glob.glob(os.path.join(glob.escape(DEST), '*', '')):
        for m in glob.glob(glob.escape(res) + '**/*.meta', recursive=True):
            t = open(m, encoding='utf-8', errors='ignore').read()
            ids |= set(int(i) for i in re.findall(r'<id value="(\d+)"', t))
            hand |= set(h.upper() for h in re.findall(r'<handlingName>([^<]+)</handlingName>', t))
            modeles |= set(x.lower() for x in re.findall(r'<modelName>([^<]+)</modelName>', t)) if m.endswith('vehicles.meta') else set()
        for f in glob.glob(glob.escape(res) + 'stream/**/*', recursive=True):
            if f.lower().endswith(STREAM_EXT):
                fichiers.add(os.path.basename(f).lower())
    return ids, hand, fichiers, modeles


def lire_metas(src):
    metas = {}
    for f in glob.glob(os.path.join(glob.escape(src), '**', '*.meta'), recursive=True):
        b = os.path.basename(f).lower()
        if '/stream/' in f.replace('\\', '/'):
            continue
        for cle in TYPES:
            if b == cle or (b.endswith(cle) and cle != 'vehicles.meta') or b == cle:
                metas.setdefault(cle, []).append(f)
    def propre(texte):
        # coupe le texte parasite laisse apres la balise racine (erreur frequente dans les mods)
        m = re.search(r'<([A-Za-z_][\w]*)[^>?!]*>', re.sub(r'<\?.*?\?>|<!--.*?-->', '', texte, flags=re.S))
        if m:
            fin = texte.rfind('</%s>' % m.group(1))
            if fin != -1:
                return texte[:fin + len(m.group(1)) + 3] + '\n'
        return texte
    return {k: propre(open(v[0], encoding='utf-8', errors='ignore').read()) for k, v in metas.items()}


def importer(src, nom_res, ids, hand, fichiers, modeles, log):
    metas = lire_metas(src)
    if 'vehicles.meta' not in metas:
        log.append('%s : pas de vehicles.meta, ignore' % nom_res)
        return None
    veh = metas['vehicles.meta']
    mods = [m.lower() for m in re.findall(r'<modelName>([^<]+)</modelName>', veh)]
    mods_uniques = sorted(set(mods))
    conflits = [m for m in mods_uniques if m in JEU or m in modeles]
    if conflits:
        log.append('%s : ignore, spawn code deja utilise (%s)' % (nom_res, ', '.join(conflits)))
        return None
    cc = metas.get('carcols.meta', '')
    cv = metas.get('carvariations.meta', '')
    hd = metas.get('handling.meta', '')
    notes = []

    def nouvel_id():
        i = 1600
        while i in ids:
            i += 1
        ids.add(i)
        return i

    # kits
    renomme_kits = {}
    principal = mods_uniques[0]
    for m in re.finditer(r'<kitName>([^<]+)</kitName>(\s*)<id value="(\d+)"\s*/>', cc):
        ancien = m.group(1)
        kid = nouvel_id()
        base = re.sub(r'^\d+_', '', ancien).replace('_modkit', '')
        neuf = '%d_%s_modkit' % (kid, base if base.lower() in mods_uniques else principal)
        neuf = re.sub(r'[^A-Za-z0-9_]', '', neuf)
        renomme_kits[ancien] = (neuf, kid)
    for ancien, (neuf, kid) in renomme_kits.items():
        cc = re.sub(r'<kitName>%s</kitName>(\s*)<id value="\d+"\s*/>' % re.escape(ancien),
                    lambda mm: '<kitName>%s</kitName>%s<id value="%d" />' % (neuf, mm.group(1), kid), cc, count=1)
    if renomme_kits:
        notes.append('kits renumerotes : ' + ', '.join('%s -> %s' % (a, n[0]) for a, n in renomme_kits.items()))

    # carvariations : remappe les kits, ajoute un kit perf aux modeles sans kit valide
    def remap_kits(bloc):
        items = re.findall(r'<Item>([^<]*)</Item>', bloc)
        valides = [renomme_kits[i][0] for i in items if i in renomme_kits]
        return valides
    sans_kit = []
    nouveaux_blocs = []
    for item in re.finditer(r'(<modelName>([^<]+)</modelName>.*?)(<kits>.*?</kits>|<kits\s*/>)', cv, re.S):
        modele = item.group(2).lower()
        valides = remap_kits(item.group(3))
        if not valides:
            sans_kit.append(modele)
        nouveaux_blocs.append((item.start(3), item.end(3), valides, modele))
    ajout_kits = ''
    for debut, fin, valides, modele in reversed(nouveaux_blocs):
        if not valides:
            kid = nouvel_id()
            nomk = '%d_%s_modkit' % (kid, re.sub(r'[^A-Za-z0-9_]', '', modele))
            ajout_kits += kit_perf(nomk, kid)
            valides = [nomk]
        bloc = '<kits>\n' + ''.join('        <Item>%s</Item>\n' % v for v in valides) + '      </kits>'
        cv = cv[:debut] + bloc + cv[fin:]
    if sans_kit:
        notes.append('kit de performance ajoute pour : ' + ', '.join(sans_kit))
    if ajout_kits:
        if not cc.strip():
            cc = '<?xml version="1.0" encoding="UTF-8"?>\n<CVehicleModelInfoVarGlobal>\n  <Kits>\n%s  </Kits>\n  <Lights />\n</CVehicleModelInfoVarGlobal>\n' % ajout_kits
        elif re.search(r'<Kits\s*/>', cc):
            cc = re.sub(r'<Kits\s*/>', lambda _: '<Kits>\n%s  </Kits>' % ajout_kits, cc, count=1)
        elif '</Kits>' in cc:
            cc = cc.replace('</Kits>', ajout_kits + '  </Kits>', 1)
        else:
            cc = re.sub(r'(<CVehicleModelInfoVarGlobal[^>]*>)', lambda mm: mm.group(1) + '\n  <Kits>\n%s  </Kits>' % ajout_kits, cc, count=1)

    # eclairages et sirenes definis localement
    for section, attr in (('Lights', 'lightSettings'), ('Sirens', 'sirenSettings')):
        m = re.search(r'<%s>(.*?)</%s>' % (section, section), cc, re.S)
        if not m:
            continue
        corps = m.group(1)
        remap = {}
        for i in re.findall(r'<id value="(\d+)"', corps):
            if i not in remap:
                remap[i] = nouvel_id()
        corps2 = re.sub(r'<id value="(\d+)"', lambda mm: '<id value="%d"' % remap[mm.group(1)], corps)
        cc = cc[:m.start(1)] + corps2 + cc[m.end(1):]
        cv = re.sub(r'<%s value="(\d+)"' % attr, lambda mm: '<%s value="%s"' % (attr, remap.get(mm.group(1), mm.group(1))), cv)
        if remap:
            notes.append('%s renumerotes : %s' % (section.lower(), ', '.join('%s -> %d' % kv for kv in remap.items())))

    # handling
    for h in sorted(set(re.findall(r'<handlingId>([^<]+)</handlingId>', veh))):
        if h.upper() in HANDLING_JEU or h.upper() in hand:
            modele = re.search(r'<modelName>([^<]+)</modelName>(?:(?!<modelName>).)*?<handlingId>%s</handlingId>' % re.escape(h), veh, re.S)
            neuf = (modele.group(1) if modele else principal).upper()
            n = 2
            base = neuf
            while neuf in hand or neuf in HANDLING_JEU:
                neuf = '%s%d' % (base, n)
                n += 1
            veh = veh.replace('<handlingId>%s</handlingId>' % h, '<handlingId>%s</handlingId>' % neuf)
            hd = re.sub(r'<handlingName>%s</handlingName>' % re.escape(h), '<handlingName>%s</handlingName>' % neuf, hd, flags=re.I)
            notes.append('handling %s renomme %s (evite d\'ecraser une autre voiture)' % (h, neuf))
            hand.add(neuf)
        else:
            hand.add(h.upper())

    # fichiers stream
    flux = [f for f in glob.glob(os.path.join(glob.escape(src), '**', '*'), recursive=True)
            if f.lower().endswith(STREAM_EXT) and '.git' not in f]
    noms = {}
    principaux = set()
    for m in mods_uniques:
        principaux |= {m + '.yft', m + '_hi.yft', m + '.ytd', m + '+hi.ytd'}
    pieces = set(p.lower() for p in re.findall(r'<modelName>([^<]+)</modelName>', cc))
    pieces |= set(p.lower() for p in re.findall(r'<linkedModels>(.*?)</linkedModels>', cc, re.S) for p in re.findall(r'<Item>([^<]+)</Item>', p))
    renomme_pieces = {}
    for f in flux:
        b = os.path.basename(f).lower()
        if b in noms:
            continue
        cible = b
        racine_nom = b.rsplit('.', 1)[0]
        if b not in principaux and racine_nom in pieces:
            if not racine_nom.startswith(tuple(mods_uniques)) or b in fichiers:
                cible = '%s_%s' % (principal, b)
                renomme_pieces[racine_nom] = cible.rsplit('.', 1)[0]
        if cible in fichiers and b not in principaux:
            cible = '%s_%s' % (principal, b)
        if cible in fichiers:
            log.append('%s : ignore, fichier %s deja present sur le serveur' % (nom_res, cible))
            return None
        noms[b] = (f, cible)
    for ancien, neuf in renomme_pieces.items():
        cc = re.sub(r'(<modelName>|<Item>)%s(</modelName>|</Item>)' % re.escape(ancien), lambda mm: mm.group(1) + neuf + mm.group(2), cc, flags=re.I)
    if renomme_pieces:
        notes.append('%d piece(s) de bodykit prefixee(s) par %s_' % (len(renomme_pieces), principal))

    # libelles : ne jamais reutiliser un libelle du jeu (sinon le nom d'une voiture du jeu change)
    def libelle(mm):
        it = mm.group(0)
        mo = re.search(r'<modelName>([^<]+)</modelName>', it)
        g = re.search(r'<gameName>([^<]+)</gameName>', it)
        if mo and g and g.group(1).upper() in LIBELLES_JEU:
            notes.append('libelle %s (du jeu) remplace par %s' % (g.group(1), mo.group(1).upper()))
            it = it.replace(g.group(0), '<gameName>%s</gameName>' % mo.group(1).upper())
        return it
    veh = re.sub(r'<Item>.*?</Item>', libelle, veh, flags=re.S)
    if metas.get('vehiclelayouts.meta'):
        avant = metas['vehiclelayouts.meta']
        metas['vehiclelayouts.meta'] = nettoyer_layouts(avant, veh)
        if not metas['vehiclelayouts.meta']:
            notes.append('vehiclelayouts.meta retire (il ne faisait que recopier des reglages du jeu)')

    # ecriture
    d = os.path.join(DEST, nom_res)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(os.path.join(d, 'data'))
    os.makedirs(os.path.join(d, 'stream'))
    contenus = {'vehicles.meta': veh, 'handling.meta': hd, 'carcols.meta': cc, 'carvariations.meta': cv,
                'vehiclelayouts.meta': metas.get('vehiclelayouts.meta', '')}
    presents = []
    for k, v in contenus.items():
        if v.strip():
            open(os.path.join(d, 'data', k), 'w', encoding='utf-8').write(v)
            presents.append(k)
    for b, (f, cible) in noms.items():
        shutil.copy(f, os.path.join(d, 'stream', cible))
        fichiers.add(cible)
    scripts = []
    for lua in glob.glob(os.path.join(glob.escape(src), '*.lua')):
        b = os.path.basename(lua)
        if b in ('__resource.lua', 'fxmanifest.lua'):
            continue
        shutil.copy(lua, os.path.join(d, b))
        scripts.append(b)
    man = ["fx_version 'cerulean'", "game 'gta5'", "lua54 'yes'", '',
           "description '%s (importe par tools/vehicules/importer_pack.py)'" % nom_res, '', 'files {']
    man += [",\n".join("    'data/%s'" % p for p in presents), '}', '']
    man += ["data_file '%s' 'data/%s'" % (TYPES[p], p) for p in presents]
    if scripts:
        man += ['', 'client_scripts {', ",\n".join("    '%s'" % s for s in scripts), '}']
    open(os.path.join(d, 'fxmanifest.lua'), 'w', encoding='utf-8').write('\n'.join(man) + '\n')
    modeles |= set(mods_uniques)
    log.append('%s : OK (%s)%s' % (nom_res, ', '.join(mods_uniques), ''.join('\n    - ' + n for n in notes)))
    return mods_uniques


def main():
    ids, hand, fichiers, modeles = etat_serveur()
    log = []
    resultat = {}
    for src in sys.argv[1:]:
        src = os.path.abspath(src)
        nom = re.sub(r'[^a-z0-9_]', '', os.path.basename(src.rstrip('/')).lower())
        r = importer(src, nom, ids, hand, fichiers, modeles, log)
        if r:
            resultat[nom] = r
    print('\n'.join(log))
    json.dump(resultat, open(os.path.join(ICI, 'dernier_import.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
