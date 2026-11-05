"""First-volume trunk battlefields, authored against WORLD_MAP_DESIGN sections 8/13.

Only new templates are returned.  Original battle templates are never changed.
Coordinates and all combat values are integers; source enemy stats are authoritative.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENEMIES = json.loads((ROOT / 'docs/cards/world/drafts/spec/data/enemies_final.json').read_text())['enemies']
# The first twelve rows of BattleRules.LEVELS: hp %, attack bonus, defence bonus.
LEVELS = [(100, 0, 0), (108, 0, 0), (115, 0, 0), (122, 0, 0),
          (130, 1, 0), (137, 1, 0), (145, 1, 0), (152, 1, 0),
          (160, 2, 0), (170, 2, 0), (180, 2, 0), (188, 2, 0)]


def _power(kind: str, level: int) -> int:
    base = ENEMIES[kind]
    hp_pct, atk_bonus, def_bonus = LEVELS[level - 1]
    hp = max(1, base['hp'] * hp_pct // 100)
    atk = base['atk'] + (atk_bonus if base['atk'] else 0)
    defense = base['def'] + (def_bonus if base['def'] else 0)
    factor = atk + 4 if base['type'] == 'gun' else atk + defense + 2 * base['spd'] + (2 if base['range'] else 0)
    return hp * factor // 10


def _unit_power(spec, level):
    return _power(spec['kind'] if isinstance(spec, dict) else spec, level)


def _label(x, y):
    return chr(65 + x) + str(y + 1)


def _lane(width, row):
    return [_label(x, row - 1) for x in range(width - 1, -1, -1)]


def _paint(grid, label, char):
    grid[int(label[1:]) - 1][ord(label[0]) - 65] = char


def _base(name, date, scale, level, size, ground, routes, scenery, weather, turns, target, core, guns, fillers, objective):
    width, height = size
    grid = [[ground for _ in range(width)] for _ in range(height)]
    for labels in routes.values():
        for label in labels:
            _paint(grid, label, '=' if ground == '.' else ground)
        _paint(grid, labels[0], 'G')
        _paint(grid, labels[-1], 'E')
    for char, labels in scenery.items():
        for label in labels:
            _paint(grid, label, char)
    waves = []
    route_ids = list(routes)
    # First two routes start independently. A single blocker cannot defend both exits.
    for index, specs in enumerate(core):
        waves.append({'turn': 1 + index // len(route_ids), 'route': route_ids[index % len(route_ids)], 'units': specs[:]})
    for at, kind in guns:
        waves.append({'turn': 1, 'at': at, 'units': [kind], 'first_fire': 3})
    current = sum(_unit_power(u, level) for wave in waves for u in wave['units'])
    remaining = target - current
    choices = []
    p = [_power(kind, level) for kind in fillers]
    for a in range(24):
        for b in range(24):
            for c in range(24):
                if a + b + c < 6 or a + b + c > 22:
                    continue
                value = a * p[0] + b * p[1] + c * p[2]
                if value == remaining:
                    choices.append((abs(a + b + c - 12), abs(a - b) + c, a, b, c))
    if not choices:
        raise ValueError(f'{name}: cannot fill exact power {target}, core {current}, fillers {p}')
    _, _, a, b, c = min(choices)
    extra = [fillers[0]] * a + [fillers[1]] * b + [fillers[2]] * c
    # Spread pressure across both lanes and several turns, rather than a single lethal wave.
    for index, unit in enumerate(extra):
        lane = index % len(route_ids)
        turn = 3 + (index // len(route_ids)) % 3
        wave = next((w for w in waves if w.get('route') == route_ids[lane] and w['turn'] == turn), None)
        if wave is None:
            wave = {'turn': turn, 'route': route_ids[lane], 'units': []}
            waves.append(wave)
        wave['units'].append(unit)
    return {'name': name, 'date': date, 'segment': 'trunk', 'scale': scale, 'size': list(size), 'level': level,
            'turn_limit': turns, 'enemy_morale': 24 + level, 'weather': [weather],
            'map': [''.join(row) for row in grid], 'routes': routes, 'waves': sorted(waves, key=lambda w: w['turn']),
            'order': {'type': 'no_leak', 'desc': '军令：守住撤离通道，不让敌军越过鹰旗。'},
            'objective': {'type': 'hold', 'desc': objective},
            'notes': '第一卷正式战场。独立通道同时受压，单个主角不能替代两翼布阵；高地炮位与援军波次可预览。'}


def build_templates() -> dict:
    out = {}
    out['pyramids'] = _base('金字塔下的方阵', '1798-07-21', 'elite', 4, (8, 4), 'a',
        {'desert': _lane(8, 2), 'village': _lane(8, 4)},
        {'n': ['B1', 'D1', 'F1', 'G3'], 'o': ['C2', 'C4'], 'v': ['D4', 'E4'], '^': ['G1']},
        'desert', 8, 112,
        [[{'kind': 'mamluk', 'tags': ['hunter']}, 'nizam'], ['mamluk', 'nizam'], ['janissary'], ['bedouin']],
        [('G1', 'ottoman_gun')], ['nizam', 'bedouin', 'mamluk'],
        '在水井与村庄之间组成方阵，挡住马穆鲁克的骑兵冲击。')
    out['acre'] = _base('阿卡城下的撤离线', '1799-05-20', 'major', 5, (9, 5), 'a',
        {'breach': _lane(9, 2), 'trench': _lane(9, 4)},
        {'#': ['D1', 'E1', 'D3', 'E3', 'D5'], 'm': ['F3', 'G3'], 'n': ['B1', 'B5', 'H5'],
         'o': ['C2', 'B4'], '^': ['H1'], ';': ['E2', 'E4']},
        'desert', 11, 150,
        [[{'kind': 'mamluk', 'tags': ['hunter']}, 'nizam'], ['janissary', 'nizam'], ['janissary'], ['bey']],
        [('H1', 'ottoman_gun')], ['nizam', 'bedouin', 'mamluk'],
        '利用城墙遮蔽与壕沟阵地，守住伤员西撤的两条道路直到最后一队离开。')
    out['austerlitz'] = _base('奥斯特里茨的冰湖', '1805-12-02', 'major', 7, (9, 5), '.',
        {'pratzen': _lane(9, 2), 'lakeside': _lane(9, 4)},
        {'^': ['B1', 'C1', 'D1', 'B3', 'D3', 'H1'], 'i': ['E5', 'F5', 'G5'], 'v': ['C4'], 'w': ['B5', 'D5']},
        'fog', 12, 172,
        [['cossack', 'ru_line'], ['cossack', 'ru_line'], ['ru_grenadier'], ['hungarian'], ['ru_grenadier']],
        [('H1', 'ru_gun')], ['ru_line', 'ru_jaeger', 'whitecoat'],
        '占住普拉岑高地与湖岸通道；冰面在第七回合破裂，及时撤离上面的部队。')
    out['austerlitz']['events'] = [{'turn': 7, 'cell': p, 'terrain': 'river'} for p in ['E5', 'F5', 'G5']]
    out['saragossa'] = _base('萨拉戈萨的巷战', '1809-02-20', 'major', 9, (9, 5), 'S',
        {'avenue': _lane(9, 2), 'cloister': _lane(9, 4)},
        {'B': ['B1', 'D1', 'F1', 'D3', 'F3', 'B5', 'D5'], 'R': ['C1', 'E3'], ';': ['E2', 'F4'], '^': ['H1']},
        'clear', 12, 200,
        [[{'kind': 'es_lancer', 'tags': ['hunter']}, 'es_regular'], [{'kind': 'es_lancer', 'tags': ['hunter']}, 'guerrillero'],
         ['highlander'], ['highlander'], ['highlander']],
        [('H1', 'british_gun')], ['es_regular', 'guerrillero', 'bandolero'],
        '把街道口连成防线，提防屋后游击队与广场枪骑兵；屋顶猎兵能掩护瓦砾路口。')
    # Street ambush starts inside the town but has its own previewed entrance.
    out['saragossa']['spawns'] = ['G3']
    out['saragossa']['routes']['alley'] = ['G3', 'G2', 'F2', 'E2', 'D2', 'C2', 'B2', 'A2']
    # Move an existing ambush unit, preserving exact authored power.
    for wave in out['saragossa']['waves']:
        if 'guerrillero' in wave['units']:
            wave['units'].remove('guerrillero')
            out['saragossa']['waves'].append({'turn': 3, 'route': 'alley', 'units': ['guerrillero']})
            break
    out['saragossa']['waves'] = [w for w in out['saragossa']['waves'] if w['units']]
    out['borodino'] = _base('博罗季诺大堡垒', '1812-09-07', 'grand', 9, (10, 6), '.',
        {'redoubt': _lane(10, 2), 'valley': _lane(10, 5)},
        {'+': ['B1', 'D1', 'B3', 'D3', 'F3', 'B6'], 'v': ['C5', 'D5'], '~': ['E4', 'F4', 'G4'],
         '^': ['H1', 'I3', 'I6'], 'w': ['F6', 'G6']},
        'clear', 12, 210,
        [['cossack', 'ru_line'], ['cossack', 'ru_line'], ['ru_grenadier'], ['ru_grenadier'], ['ru_grenadier']],
        [('H1', 'ru_gun'), ('I3', 'ru_gun'), ('I6', 'ru_gun')], ['ru_line', 'ru_jaeger', 'opolchenie'],
        '凭借胸墙抵住三组俄军炮位，在村庄和河谷两翼建立交叉火力。')
    out['berezina'] = _base('别列津纳的两座桥', '1812-11-28', 'major', 10, (9, 5), 's',
        {'upper_bridge': _lane(9, 2), 'lower_bridge': _lane(9, 4)},
        {'~': ['E1', 'E3', 'E5'], 'b': ['E2', 'E4'], 'i': ['D3', 'F3', 'D5', 'F5'],
         '^': ['B1', 'C3', 'H1'], 'v': ['B4'], '+': ['B5']},
        'snow', 12, 228,
        [['cossack', 'ru_line'], ['cossack', 'ru_line'], ['ru_grenadier'], ['ru_grenadier'], ['ru_grenadier']],
        [('H1', 'ru_gun')], ['ru_line', 'ru_jaeger', 'cossack'],
        '守住两座桥，把辎重和伤员送过冰河。严寒减少军令点，冰裂会迫使岸边部队撤回。')
    out['berezina']['events'] = [{'turn': 8, 'cell': p, 'terrain': 'river'} for p in ['D3', 'F3', 'D5', 'F5']]
    # Snow movement is slow: the bridge approaches have been cleared by engineers.
    for y in (1, 3):
        line = list(out['berezina']['map'][y])
        for x in range(1, 8):
            if line[x] == 's': line[x] = '='
        out['berezina']['map'][y] = ''.join(line)
    out['leipzig'] = _base('莱比锡诸国会战', '1813-10-18', 'grand', 11, (10, 6), '.',
        {'east': _lane(10, 2), 'south': _lane(10, 5),
         'north_gate': ['F1', 'F2', 'E2', 'D2', 'C2', 'B2', 'A2'],
         'south_gate': ['F6', 'F5', 'E5', 'D5', 'C5', 'B5', 'A5']},
        {'#': ['D1', 'E1', 'D6'], 'v': ['C2', 'D5'], '~': ['G3', 'G4'],
         '^': ['I1', 'I6'], '+': ['C3', 'D3', 'C4'], 'b': ['G2', 'G5']},
        'rain', 12, 262,
        [['cossack', 'ru_line'], ['uhlan', 'fusilier'], ['dragoon', 'whitecoat'], ['ru_grenadier'],
         ['pr_grenadier'], ['hungarian'], ['ru_grenadier']],
        [('I1', 'rocket'), ('I6', 'pr_gun')], ['ru_line', 'fusilier', 'whitecoat'],
        '东西道路与南北城门同时受压；火箭炮覆盖河桥附近，预留撤退和轮换的位置。')
    out['elba_cove'] = _base('厄尔巴岛的出航口', '1815-02-26', 'major', 12, (9, 5), ',',
        {'quay': _lane(9, 2), 'beach': _lane(9, 4)},
        {'k': ['B2', 'C2', 'D2', 'E2'], 'W': ['F1', 'G1', 'H1', 'I1', 'F5', 'G5', 'H5', 'I5'],
         '^': ['B1', 'D1', 'C3', 'G3'], '*': ['E1', 'E5'], 'p': ['F2'], 'v': ['B4']},
        'night', 12, 300,
        [[{'kind': 'mounted_orderly', 'tags': ['hunter']}, 'marine'], [{'kind': 'mounted_orderly', 'tags': ['hunter']}, 'redcoat'],
         [{'kind': 'mounted_orderly', 'tags': ['hunter']}], ['redcoat_grenadier'], ['redcoat_grenadier'],
         ['redcoat_grenadier'], ['redcoat_grenadier']],
        [('G3', 'coast_gun'), ('H1', 'gunboat')], ['marine', 'redcoat', 'sailor'],
        '在夜色中守住码头和沙滩，让鹰旗登船；岸防炮与海上的英国炮艇必须分别处理。')
    for key, template in out.items():
        template['id'] = key
    return out


if __name__ == '__main__':
    print(json.dumps(build_templates(), ensure_ascii=False, indent=2))
