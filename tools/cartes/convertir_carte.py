#!/usr/bin/env python3
"""Convertit une carte Map Editor (.xml <Map>) ou Menyoo Spooner (.xml <SpoonerPlacements>)
en fichier de donnees Lua pour pt-maploader.

Usage :
    python3 convertir_carte.py sortie.lua fichier1.xml [fichier2.xml ...]

Les objets, vehicules, pnj et marqueurs de teleportation sont repris. Les pickups sont ignores.
"""
import math
import sys
import xml.etree.ElementTree as ET

ACTIONS = {
    'smoke': 'WORLD_HUMAN_SMOKING', 'drinking': 'WORLD_HUMAN_DRINKING', 'picnic': 'WORLD_HUMAN_PICNIC',
    'clipboard': 'WORLD_HUMAN_CLIPBOARD', 'guard': 'WORLD_HUMAN_GUARD_STAND', 'musician': 'WORLD_HUMAN_MUSICIAN',
    'lean': 'WORLD_HUMAN_LEANING', 'phone': 'WORLD_HUMAN_STAND_MOBILE', 'sitting': 'PROP_HUMAN_SEAT_CHAIR',
    'partying': 'WORLD_HUMAN_PARTYING', 'cop': 'WORLD_HUMAN_COP_IDLES', 'binoculars': 'WORLD_HUMAN_BINOCULARS',
    'drill': 'WORLD_HUMAN_CONST_DRILL', 'hammering': 'WORLD_HUMAN_HAMMERING', 'muscleflex': 'WORLD_HUMAN_MUSCLE_FLEX',
    'pushups': 'WORLD_HUMAN_PUSH_UPS', 'situps': 'WORLD_HUMAN_SIT_UPS', 'yoga': 'WORLD_HUMAN_YOGA',
    'cheering': 'WORLD_HUMAN_CHEERING', 'stripwatch': 'WORLD_HUMAN_STRIP_WATCH_STAND',
}
MARQUEURS = ['UpsideDownCone', 'VerticalCylinder', 'ThickChevronUp', 'ThinChevronUp', 'CheckeredFlagRect',
             'CheckeredFlagCircle', 'VerticleCircle', 'PlaneModel', 'LostMCDark', 'LostMCLight',
             'Number0', 'Number1', 'Number2', 'Number3', 'Number4', 'Number5', 'Number6', 'Number7', 'Number8',
             'Number9', 'ChevronUpx1', 'ChevronUpx2', 'ChevronUpx3', 'HorizontalCircleFat', 'ReplayIcon',
             'HorizontalCircleSkinny', 'HorizontalCircleSkinny_Arrow', 'HorizontalSplitArrowCircle', 'DebugSphere']


def f(v, d=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def signe(h):
    h = int(h, 16) if str(h).lower().startswith('0x') else int(h)
    h &= 0xFFFFFFFF
    return h - (1 << 32) if h >= (1 << 31) else h


def vec(el, *noms, n=4):
    return [round(f(el.findtext(x)), n) for x in noms] if el is not None else [0.0] * len(noms)


def lire(chemin, data):
    racine = ET.parse(chemin).getroot()
    if racine.tag == 'Map':
        for o in racine.iter('MapObject'):
            t = o.findtext('Type')
            pos = vec(o.find('Position'), 'X', 'Y', 'Z')
            rot = vec(o.find('Rotation'), 'X', 'Y', 'Z')
            q = vec(o.find('Quaternion'), 'X', 'Y', 'Z', 'W', n=6) if o.find('Quaternion') is not None else None
            h = signe(o.findtext('Hash'))
            dyn = (o.findtext('Dynamic') or 'false').lower() == 'true'
            e = {'h': h, 'p': pos, 'r': rot, 'q': q, 'dyn': dyn}
            if t == 'Prop':
                data['objets'].append(e)
            elif t == 'Vehicle':
                e['c1'] = int(f(o.findtext('PrimaryColor')))
                e['c2'] = int(f(o.findtext('SecondaryColor')))
                data['vehicules'].append(e)
            elif t == 'Ped':
                act = (o.findtext('Action') or 'None').lower()
                e['scenario'] = ACTIONS.get(act)
                arme = o.findtext('Weapon') or 'Unarmed'
                e['arme'] = None if arme.lower() == 'unarmed' else 'WEAPON_' + arme.upper()
                data['pnj'].append(e)
        for m in racine.iter('Marker'):
            cible = m.find('TeleportTarget')
            if cible is None or cible.find('X') is None:
                continue
            typ = m.findtext('Type') or 'UpsideDownCone'
            data['marqueurs'].append({
                'type': MARQUEURS.index(typ) if typ in MARQUEURS else 0,
                'p': vec(m.find('Position'), 'X', 'Y', 'Z'),
                'cible': vec(cible, 'X', 'Y', 'Z'),
                'taille': vec(m.find('Scale'), 'X', 'Y', 'Z'),
                'rgba': [int(f(m.findtext(c), 255)) for c in ('Red', 'Green', 'Blue', 'Alpha')],
            })
    elif racine.tag == 'SpoonerPlacements':
        for p in racine.iter('Placement'):
            t = p.findtext('Type')
            pr = p.find('PositionRotation')
            pos = vec(pr, 'X', 'Y', 'Z')
            rot = vec(pr, 'Pitch', 'Roll', 'Yaw')
            e = {'h': signe(p.findtext('ModelHash')), 'p': pos, 'r': rot, 'q': None,
                 'dyn': (p.findtext('Dynamic') or 'false').lower() == 'true'}
            tex = p.findtext('ObjectProperties/TextureVariation')
            if tex:
                e['tex'] = int(f(tex))
            if t == '3':
                data['objets'].append(e)
            elif t == '2':
                data['vehicules'].append(e)
            elif t == '1':
                e['scenario'] = None
                e['arme'] = None
                data['pnj'].append(e)
    else:
        raise SystemExit(f'{chemin} : format inconnu ({racine.tag})')


def lua(v):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return "'" + v.replace("\\", "\\\\").replace("'", "\\'") + "'"
    if isinstance(v, list):
        return '{' + ','.join(lua(x) for x in v) + '}'
    if isinstance(v, dict):
        return '{' + ','.join(f'{k}={lua(x)}' for k, x in v.items() if x is not None) + '}'
    raise TypeError(v)


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    data = {'objets': [], 'vehicules': [], 'pnj': [], 'marqueurs': []}
    for chemin in sys.argv[2:]:
        lire(chemin, data)
    pts = [e['p'] for k in ('objets', 'vehicules', 'pnj') for e in data[k]]
    if not pts:
        raise SystemExit('carte vide')
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    rayon = max(math.hypot(p[0] - cx, p[1] - cy) for p in pts)
    with open(sys.argv[1], 'w', encoding='utf-8') as out:
        out.write('-- Genere par tools/cartes/convertir_carte.py, ne pas modifier a la main\n')
        out.write(f'return {{\n  centre = vector3({cx:.2f}, {cy:.2f}, {cz:.2f}),\n  rayon = {rayon:.1f},\n')
        for k in ('objets', 'vehicules', 'pnj', 'marqueurs'):
            out.write(f'  {k} = {{\n')
            for e in data[k]:
                out.write('    ' + lua(e) + ',\n')
            out.write('  },\n')
        out.write('}\n')
    print(f"{sys.argv[1]} : {len(data['objets'])} objets, {len(data['vehicules'])} vehicules, "
          f"{len(data['pnj'])} pnj, {len(data['marqueurs'])} teleporteurs, centre ({cx:.0f}, {cy:.0f}), rayon {rayon:.0f} m")


if __name__ == '__main__':
    main()
