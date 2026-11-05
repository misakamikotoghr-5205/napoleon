# Shared rules for the ocean battle drafts: terrain table (ARCH §4.2), level table (ARCH §3.2),
# template validation (battle_rules.validate_template extended per ARCH §4.5) and a do-nothing simulator.
import math

# char: (id, stand, enemy_walk, step, def, rdef, los_block, tier)
# stand: ground / high / top / none ; enemy_walk: True / False / "start" / "end" / "boat" / "through"
TERRAIN = {
    ".": ("plain", "ground", True, 1, 0, 0, False, 1),
    "^": ("high", "high", False, 0, 0, 0, False, 2),
    "=": ("road", "ground", True, 1, 0, 0, False, 1),
    "v": ("village", "ground", True, 1, 2, 0, False, 1),
    "w": ("woods", "ground", True, 1, 0, 2, False, 1),
    "~": ("river", "none", False, 0, 0, 0, False, 0),
    "b": ("bridge", "ground", True, 1, 0, 0, False, 1),
    "f": ("ford", "ground", True, 1, 0, 0, False, 1),
    "m": ("marsh", "none", False, 0, 0, 0, False, 0),
    "G": ("gate", "none", "start", 1, 0, 0, False, 1),
    "E": ("eagle", "none", "end", 1, 0, 0, False, 1),
    "+": ("earthwork", "high", False, 0, 0, 0, False, 2),
    "_": ("void", "none", False, 0, 0, 0, False, -1),
    "#": ("wall", "none", False, 0, 0, 0, True, 3),
    ";": ("rubble", "ground", True, 2, 1, 0, False, 1),
    "s": ("snow", "ground", True, 2, 0, 0, False, 1),
    "u": ("mud", "ground", True, 2, 0, 0, False, 1),
    "i": ("ice", "ground", True, 1, 0, 0, False, 1),
    "a": ("sand", "ground", True, 1, 0, 0, False, 1),
    "n": ("dune", "high", False, 0, 0, 0, False, 2),
    "o": ("well", "ground", True, 1, 0, 0, False, 1),
    "d": ("deck", "ground", True, 1, 0, 0, False, 1),
    "q": ("quarterdeck", "high", False, 0, 0, 0, False, 2),
    "t": ("rigging", "top", False, 0, 0, 0, False, 3),
    "|": ("mast", "none", False, 0, 0, 0, True, 3),
    "W": ("sea", "none", "boat", 0, 0, 0, False, 0),
    "-": ("shallows", "none", True, 2, 0, 0, False, 0),
    "*": ("reef", "none", False, 0, 0, 0, False, 0),
    ",": ("beach", "ground", True, 1, 0, 0, False, 1),
    "c": ("cave", "ground", True, 1, 0, 2, True, 1),
    "k": ("dock", "ground", True, 1, 0, 0, False, 1),
    "p": ("plank", "ground", True, 1, 0, 0, False, 1),
    "H": ("hatch", "none", "start", 1, 0, 0, False, 1),
    "S": ("street", "ground", True, 1, 0, 0, False, 1),
    "B": ("building", "ground", False, 0, 2, 0, True, 1),
    "R": ("rooftop", "top", False, 0, 0, 0, False, 3),
    "C": ("corridor", "ground", True, 1, 0, 0, False, 1),
    "L": ("cell", "ground", False, 0, 1, 0, False, 1),
    "D": ("door", "none", "through", 1, 0, 0, False, 1),
    "K": ("catacomb", "ground", True, 1, 0, 0, False, 1),
}
ID2CHAR = {v[0]: k for k, v in TERRAIN.items()}
SPAWN_CELLS_OK = {"village", "woods", "street", "catacomb", "plank"}

# L -> hp%, morale%, atk+, def+, boss_hunters, boss_elites, elite_hunters, skirmish_hunters, boss_turns, elite_turns, skirmish_turns, stars
LEVELS = {
    1: (100, 100, 0, 0, 0, 1, 0, 0, 11, 8, 6, 1), 2: (108, 104, 0, 0, 0, 1, 0, 0, 11, 8, 6, 1),
    3: (115, 109, 0, 0, 1, 2, 0, 0, 11, 8, 6, 1), 4: (122, 113, 0, 0, 1, 2, 0, 0, 11, 8, 6, 1),
    5: (130, 117, 1, 0, 1, 2, 0, 0, 11, 8, 6, 1), 6: (137, 125, 1, 0, 1, 2, 0, 0, 11, 8, 6, 2),
    7: (145, 134, 1, 0, 2, 3, 0, 0, 12, 8, 6, 2), 8: (152, 138, 1, 0, 2, 3, 0, 0, 12, 8, 6, 2),
    9: (160, 142, 2, 0, 2, 3, 1, 0, 12, 8, 6, 2), 10: (170, 154, 2, 0, 2, 3, 1, 0, 12, 8, 6, 2),
    11: (180, 167, 2, 0, 3, 4, 1, 0, 12, 8, 6, 3), 12: (188, 172, 2, 0, 3, 4, 1, 0, 12, 8, 6, 3),
    13: (196, 177, 3, 0, 3, 4, 1, 1, 13, 9, 7, 3), 14: (204, 182, 3, 0, 3, 4, 1, 1, 13, 9, 7, 3),
    15: (212, 187, 3, 1, 4, 5, 1, 1, 13, 9, 7, 3), 16: (220, 192, 3, 1, 4, 5, 1, 1, 13, 9, 7, 4),
    17: (228, 197, 4, 1, 4, 5, 2, 1, 13, 9, 7, 4), 18: (236, 202, 4, 1, 4, 5, 2, 1, 13, 9, 7, 4),
    19: (244, 207, 4, 1, 5, 6, 2, 1, 14, 9, 7, 4), 20: (252, 212, 4, 1, 5, 6, 2, 1, 14, 9, 7, 4),
    21: (260, 217, 5, 2, 5, 6, 2, 2, 14, 9, 7, 5), 22: (270, 222, 5, 2, 5, 6, 2, 2, 14, 9, 7, 5),
    23: (280, 227, 5, 2, 6, 6, 2, 2, 14, 9, 7, 5), 24: (290, 232, 5, 2, 6, 6, 2, 2, 14, 9, 7, 5),
}

SCALES = {  # default size; ARCH §3.3 caps at L>=13
    "skirmish": {"cols": 7, "rows": 3, "kind": "battle"},
    "elite": {"cols": 8, "rows": 4, "kind": "elite"},
    "major": {"cols": 9, "rows": 5, "kind": "boss"},
    "grand": {"cols": 10, "rows": 6, "kind": "boss"},
    "epic": {"cols": 12, "rows": 7, "kind": "boss"},
}
# ARCH §3.3 expected sizes per node kind and level band (one of)
SIZE_BAND = {
    "battle": {(13, 18): [(8, 4)], (19, 24): [(8, 4), (9, 4)]},
    "elite": {(13, 18): [(9, 5)], (19, 24): [(10, 5)]},
    "boss": {(13, 18): [(10, 6)], (19, 24): [(11, 6), (12, 7)]},
}

KILL_MORALE = {"infantry": 1, "wagon": 1, "cavalry": 2, "gun": 2, "elite": 3, "leader": 4}


def eagle_loss(etype):
    return 3 if etype in ("elite", "leader") else 2


def label(c, r):
    return "%s%d" % (chr(65 + c), r + 1)


def parse_label(s):
    return (ord(s[0]) - 65, int(s[1:]) - 1)


def expand_route(spec):
    """'J2>C2>C3>A3' -> list of labels along axis-aligned segments"""
    pts = [parse_label(p) for p in spec.split(">")]
    out = [pts[0]]
    for (c1, r1) in pts[1:]:
        c0, r0 = out[-1]
        if c0 != c1 and r0 != r1:
            raise ValueError("diagonal segment in %s" % spec)
        dc = (c1 > c0) - (c1 < c0)
        dr = (r1 > r0) - (r1 < r0)
        while (c0, r0) != (c1, r1):
            c0 += dc
            r0 += dr
            out.append((c0, r0))
    return [label(c, r) for c, r in out]


def unit_specs(opt):
    out = []
    for s in opt:
        if isinstance(s, str):
            out.append({"kind": s, "tags": [], "lv_min": 1})
        else:
            out.append({"kind": s["kind"], "tags": s.get("tags", []), "lv_min": int(s.get("lv_min", 1))})
    return out


def terrain_grid(tpl, turn):
    rows = [list(r) for r in tpl["map"]]
    for ev in tpl.get("events", []):
        if "turn" in ev and int(ev["turn"]) <= turn:
            c, r = parse_label(ev["cell"])
            rows[r][c] = ID2CHAR[ev["terrain"]]
    return rows


def validate(tid, tpl, enemies):
    errs, warns = [], []
    scale = tpl.get("scale")
    if scale not in SCALES:
        return ["bad scale"], warns
    cols, rows = tpl.get("size", [SCALES[scale]["cols"], SCALES[scale]["rows"]])
    if not (5 <= cols <= 12 and 3 <= rows <= 7):
        errs.append("size out of 5x3..12x7")
    mp = tpl["map"]
    if len(mp) != rows:
        errs.append("map must have %d rows" % rows)
    for i, line in enumerate(mp):
        if len(line) != cols:
            errs.append("row %d has %d cells, want %d" % (i + 1, len(line), cols))
        for ch in line:
            if ch not in TERRAIN:
                errs.append("row %d unknown char %r" % (i + 1, ch))
    if errs:
        return errs, warns
    flat = "".join(mp)
    if "E" not in flat:
        errs.append("no eagle")
    if not set("GHD") & set(flat):
        errs.append("no start cell (gate / hatch / door)")
    if "_" in flat:
        pass
    limit = int(tpl["turn_limit"])
    waves = tpl["waves"]
    routes = {k: expand_route(v) if isinstance(v, str) else v for k, v in tpl["routes"].items()}
    tpl["_routes"] = routes
    spawns = set(tpl.get("spawns", []))
    for s in spawns:
        c, r = parse_label(s)
        if TERRAIN[mp[r][c]][0] not in SPAWN_CELLS_OK:
            errs.append("spawn %s on %s" % (s, TERRAIN[mp[r][c]][0]))
    first_use, wave_tags = {}, {}
    for w in waves:
        if "route" in w:
            rid = w["route"]
            if rid not in routes:
                errs.append("wave t%d unknown route %s" % (w["turn"], rid))
                continue
            first_use[rid] = min(first_use.get(rid, 999), int(w["turn"]))
            opts = [w["units"]] + w.get("alt", [])
            alltag = True
            for opt in opts:
                for s in unit_specs(opt):
                    tg = set(enemies[s["kind"]]["tags"]) | set(s["tags"])
                    if not ({"boarder", "ambush"} & tg):
                        alltag = False
            wave_tags.setdefault(rid, []).append(alltag)
    for rid, cells in routes.items():
        until = tpl.get("route_until", {}).get(rid)
        t0 = first_use.get(rid, limit)
        checks = [t0, 999] if until is None else list(range(t0, min(limit, until + len(cells)) + 1))
        for tt in checks:
            grid = terrain_grid(tpl, tt)
            for i, lb in enumerate(cells):
                c, r = parse_label(lb)
                if not (0 <= c < cols and 0 <= r < rows):
                    errs.append("route %s cell %s out of map" % (rid, lb))
                    break
                ch = grid[r][c]
                tid_ = TERRAIN[ch][0]
                walk = TERRAIN[ch][2]
                if i == 0:
                    ok = tid_ in ("gate", "hatch", "door")
                    if not ok and lb in spawns and all(wave_tags.get(rid, [False])):
                        ok = True
                    if not ok and tid_ == "plank" and all(wave_tags.get(rid, [False])):
                        ok = True
                    if not ok:
                        errs.append("route %s must start at gate/hatch/door (or tagged spawn): %s is %s @t%d" % (rid, lb, tid_, tt))
                elif i == len(cells) - 1:
                    if tid_ != "eagle":
                        errs.append("route %s must end at eagle: %s is %s" % (rid, lb, tid_))
                else:
                    if walk is not True and walk != "through":
                        errs.append("route %s: %s (%s) not walkable @t%d" % (rid, lb, tid_, tt))
                if i > 0:
                    pc, pr = parse_label(cells[i - 1])
                    if abs(pc - c) + abs(pr - r) != 1:
                        errs.append("route %s: %s-%s not adjacent" % (rid, cells[i - 1], lb))
            if errs:
                break
    route_cells = set(lb for cells in routes.values() for lb in cells)
    for w in waves:
        if ("route" in w) == ("at" in w):
            errs.append("wave t%d needs exactly one of route/at" % w["turn"])
            continue
        if not (1 <= int(w["turn"]) <= limit):
            errs.append("wave turn out of range")
        opts = [w["units"]] + w.get("alt", [])
        for opt in opts:
            for s in unit_specs(opt):
                if s["kind"] not in enemies:
                    errs.append("unknown enemy %s" % s["kind"])
                    continue
                en = enemies[s["kind"]]
                static = en["type"] == "gun" or "post" in (set(en["tags"]) | set(s["tags"]))
                if static != ("at" in w):
                    errs.append("wave t%d: %s %s" % (w["turn"], s["kind"], "must stand on an at cell" if static else "must walk a route"))
                if "at" in w:
                    c, r = parse_label(w["at"])
                    tr = TERRAIN[terrain_grid(tpl, int(w["turn"]))[r][c]][0]
                    allowed = en.get("at_terrain", ["high", "plain"])
                    if tr not in allowed:
                        errs.append("wave t%d: %s at %s on %s, allowed %s" % (w["turn"], s["kind"], w["at"], tr, allowed))
                    if w["at"] in route_cells:
                        errs.append("at cell %s lies on a route" % w["at"])
        if "first_fire" in w:
            if "at" not in w or not (int(w["turn"]) + 1 <= int(w["first_fire"]) <= limit):
                errs.append("bad first_fire at t%d" % w["turn"])
    for ev in tpl.get("events", []):
        if ev.get("terrain") not in ID2CHAR:
            errs.append("bad event terrain %s" % ev)
    od = tpl.get("order", {})
    if od.get("type") == "hold":
        c, r = parse_label(od["cell"])
        if TERRAIN[mp[r][c]][1] == "none":
            errs.append("hold cell %s cannot be stood on" % od["cell"])
    return errs, warns


def scaled(en, L, extra_tags=()):
    hp_pct, mor, atkb, defb = LEVELS[L][:4]
    hp = max(1, en["hp"] * hp_pct // 100)
    atk = en["atk"] + (atkb if en["atk"] > 0 else 0)
    df = en["def"] + (defb if en["def"] > 0 else 0)
    return hp, atk, df


def wave_units(tpl, w, L, alt_index=0):
    if int(w.get("lv_min", 1)) > L:
        return []
    opts = [w["units"]] + w.get("alt", [])
    opt = opts[min(alt_index, len(opts) - 1)]
    out = [s for s in unit_specs(opt) if s["lv_min"] <= L]
    pad = tpl.get("pad")
    if pad and "route" in w and out:
        n = max(0, (L - int(tpl["base_level"])) // int(pad["every"]))
        out += [{"kind": pad["kind"], "tags": [], "lv_min": 1}] * n
    return out


def simulate_idle(tpl, enemies, L, weather="clear"):
    """Nobody deployed: enemies walk their routes; returns (outcome, turn, loss_by_limit, timeline)."""
    routes = tpl["_routes"]
    grid_by_turn = {}
    movers, loss, timeline = [], 0, []
    limit = int(tpl["turn_limit"])
    for t in range(1, limit + 1):
        grid = terrain_grid(tpl, t)
        for w in tpl["waves"]:
            if int(w["turn"]) == t and "route" in w:
                for s in wave_units(tpl, w, L):
                    en = enemies[s["kind"]]
                    movers.append({"kind": s["kind"], "type": en["type"], "spd": en["spd"], "route": w["route"], "step": 0, "budget": 0, "alive": True})
        for m in movers:
            if not m["alive"]:
                continue
            cells = routes[m["route"]]
            m["budget"] += m["spd"]
            while m["step"] < len(cells) - 1:
                c, r = parse_label(cells[m["step"] + 1])
                cost = TERRAIN[grid[r][c]][3] or 1
                if weather == "mud" and m["type"] == "cavalry":
                    cost += 1
                if m["budget"] < cost:
                    break
                m["budget"] -= cost
                m["step"] += 1
            if m["step"] >= len(cells) - 1:
                m["alive"] = False
                loss += eagle_loss(m["type"])
                timeline.append((t, m["kind"], loss))
        if loss >= 10:
            return "defeat", t, loss, timeline
    return "hold_win", limit, loss, timeline


def counts(tpl, enemies, L):
    hunters = elites = leaders = n = 0
    kill_value = 0
    power = 0
    hp_total = 0
    for w in tpl["waves"]:
        for s in wave_units(tpl, w, L):
            en = enemies[s["kind"]]
            tg = set(en["tags"]) | set(s["tags"])
            n += 1
            if "hunter" in tg:
                hunters += 1
            if en["type"] == "elite":
                elites += 1
            if en["type"] == "leader":
                leaders += 1
            kill_value += KILL_MORALE[en["type"]]
            hp, atk, df = scaled(en, L)
            hp_total += hp
            if en["type"] == "gun":
                power += hp * (atk + 4) // 10
            else:
                power += hp * (atk + df + 2 * en["spd"] + (2 if en["range"] > 0 else 0)) // 10
    return {"enemy_hp_total": hp_total, "enemies": n, "hunters": hunters, "elites": elites, "leaders": leaders, "kill_value": kill_value, "power": power}


def los_clear(grid, a, b):
    """Bresenham between cells a,b (exclusive) — ARCH §4.3: ties go to the smaller row."""
    (c0, r0), (c1, r1) = a, b
    dc, dr = abs(c1 - c0), abs(r1 - r0)
    sc = 1 if c1 > c0 else -1
    sr = 1 if r1 > r0 else -1
    cells = []
    if dc >= dr:
        for i in range(1, dc):
            c = c0 + sc * i
            num = dr * i * 2
            r = r0 + sr * ((num + dc) // (2 * dc)) if dc else r0
            cells.append((c, r))
    else:
        for i in range(1, dr):
            r = r0 + sr * i
            num = dc * i * 2
            c = c0 + sc * ((num + dr) // (2 * dr)) if dr else c0
            cells.append((c, r))
    return all(not TERRAIN[grid[r][c]][6] for c, r in cells)


def coverage(tpl):
    """For each route: blockable ground cells, and our shooting posts (high/top) that can hit some route cell."""
    mp = tpl["map"]
    rows, cols = len(mp), len(mp[0])
    out = {}
    for rid, cells in tpl["_routes"].items():
        mid = cells[1:-1]
        block = [lb for lb in mid if TERRAIN[mp[parse_label(lb)[1]][parse_label(lb)[0]]][1] == "ground"]
        posts = set()
        for r in range(rows):
            for c in range(cols):
                st = TERRAIN[mp[r][c]][1]
                if st not in ("high", "top"):
                    continue
                if label(c, r) in tpl.get("_reserved", set()):
                    continue
                reach = 3 + (1 if st == "top" else 0)  # jager front 1-3 (+1 on top), same row/col
                for lb in mid:
                    tc, tr = parse_label(lb)
                    if (tc == c or tr == r) and 0 < abs(tc - c) + abs(tr - r) <= reach and los_clear(mp, (c, r), (tc, tr)):
                        posts.add(label(c, r))
                        break
        out[rid] = {"len": len(cells), "blockable": len(block), "first_block": block[0] if block else None, "shoot_posts": sorted(posts)}
    return out
