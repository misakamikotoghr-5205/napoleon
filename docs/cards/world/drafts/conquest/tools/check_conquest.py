#!/usr/bin/env python3
"""Draft checker for the conquest package (trunk + 鹰飞 branch).

Run:  python3 -I tools/check_conquest.py            (from the conquest/ folder)

What it checks (mirrors ARCH §1.5, §2.2–2.8, §3, §4 as far as a draft can):
  templates  map size/chars per ARCH §4.2, routes (start gate/hatch/door or a spawn cell for ambush waves,
             end eagle, adjacent, walkable at first use and at the end), waves, gun/post 'at' cells,
             order cell standable, and a "do nothing" simulation per weather candidate at base/node/max level
             (enemies walk with ARCH step costs; costlier cells are waded over two turns; eagle −2 / −3).
  segments   kernel v1 _valid_definition rules + v2 extras (branch targets, requires, when, battle refs),
             VN body lines (speaker aliases), events (no branch/ending/advance), flag prefixes.
  maps       node/link shape, anchors in scene order (per theatre variant), muster gate, R1–R5 and R7, levels
             (battle ≤ boss−2, elite ≤ boss−1, bosses strictly increasing in play order, branch-first floor),
             templates exist (drafted / repo / templates_needed), rivals walk real links, marker spacing per frame.
  book       battle_pool bands inside each template's [base, base+11], scene_battles templates, R6 interludes.
  words      ARCH §6 banned pawnshop words and floats anywhere under data/ (0 allowed).
Exit code 1 when any ERROR is printed. WARN lines are design notes, not failures.
"""
import json, math, os, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)
ERR, WARN = [], []
def err(m): ERR.append(m)
def warn(m): WARN.append(m)

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

# ---------------------------------------------------------------- terrain (ARCH §4.2)
# char: (id, stand, enemy_walk, step_cost, los_block)
T = {
 ".": ("plain", "ground", True, 1, False), "^": ("high", "high", False, 0, False), "=": ("road", "ground", True, 1, False),
 "v": ("village", "ground", True, 1, False), "w": ("woods", "ground", True, 1, False), "~": ("river", None, False, 0, False),
 "b": ("bridge", "ground", True, 1, False), "f": ("ford", "ground", True, 1, False), "m": ("marsh", None, False, 0, False),
 "G": ("gate", None, "start", 1, False), "E": ("eagle", None, "end", 1, False), "+": ("earthwork", "high", False, 0, False),
 "_": ("void", None, False, 0, False), "#": ("wall", None, False, 0, True), ";": ("rubble", "ground", True, 2, False),
 "s": ("snow", "ground", True, 2, False), "u": ("mud", "ground", True, 2, False), "i": ("ice", "ground", True, 1, False),
 "a": ("sand", "ground", True, 1, False), "n": ("dune", "high", False, 0, False), "o": ("well", "ground", True, 1, False),
 "d": ("deck", "ground", True, 1, False), "q": ("quarterdeck", "high", False, 0, False), "t": ("rigging", "top", False, 0, False),
 "|": ("mast", None, False, 0, True), "W": ("sea", None, False, 0, False), "-": ("shallows", None, True, 2, False),
 "*": ("reef", None, False, 0, False), ",": ("beach", "ground", True, 1, False), "c": ("cave", "ground", True, 1, True),
 "k": ("dock", "ground", True, 1, False), "p": ("plank", "ground", True, 1, False), "H": ("hatch", None, "start", 1, False),
 "S": ("street", "ground", True, 1, False), "B": ("building", "ground", False, 0, True), "R": ("rooftop", "top", False, 0, False),
 "C": ("corridor", "ground", True, 1, False), "L": ("cell", "ground", False, 0, False), "D": ("door", None, "start_or_mid", 1, False),
 "K": ("catacomb", "ground", True, 1, False),
}
BY_ID = {v[0]: k for k, v in T.items()}
SCALE_SIZE = {"skirmish": (7, 3), "elite": (8, 4), "major": (9, 5), "grand": (10, 6), "epic": (12, 7)}
SPAWN_OK = {"village", "woods", "street", "catacomb", "plank"}
LEVEL_TURNS = lambda L: (11 + (L - 1) // 6, 8 + (L - 1) // 12, 6 + (L - 1) // 12)  # boss, elite, skirmish

def lbl(c, r): return "%s%d" % (chr(65 + c), r + 1)
def parse(l): return (ord(l[0]) - 65, int(l[1:]) - 1)

def enemies_table():
    e = load(P("data/campaigns/napoleon/enemies_trunk_conquest.json"))["enemies"]
    # ARCH §5 ocean / cristo units referenced by the Elba coalition (stats from ARCH)
    extra = {
        "pirate": {"hp": 6, "atk": 4, "def": 0, "spd": 1, "type": "infantry", "range": 0, "tags": ["loot", "boarder"]},
        "pirate_captain": {"hp": 12, "atk": 5, "def": 1, "spd": 1, "type": "leader", "range": 0, "tags": ["officer", "loot"]},
        "gendarme": {"hp": 7, "atk": 3, "def": 2, "spd": 1, "type": "infantry", "range": 0, "tags": ["arrest"]},
        "carronade": {"hp": 8, "atk": 8, "def": 0, "spd": 0, "type": "gun", "range": 99, "tags": ["short"], "at_terrain": ["deck", "quarterdeck"]},
        "gunboat": {"hp": 10, "atk": 6, "def": 2, "spd": 0, "type": "gun", "range": 99, "tags": ["boat"], "at_terrain": ["sea"]},
    }
    for k, v in extra.items():
        e.setdefault(k, v)
    return e

def terrain_at(grid, events, turn):
    g = [row[:] for row in grid]
    for ev in events:
        if ev["turn"] <= turn:
            c, r = parse(ev["cell"])
            g[r][c] = BY_ID[ev["terrain"]]
    return g

def check_template(tid, t, EN):
    scale = t.get("scale")
    if scale not in SCALE_SIZE:
        err("%s: bad scale %s" % (tid, scale)); return
    cols, rows = t.get("size", SCALE_SIZE[scale])
    if not (5 <= cols <= 12 and 3 <= rows <= 7):
        err("%s: size %sx%s outside 5x3..12x7" % (tid, cols, rows))
    mp = t.get("map", [])
    if len(mp) != rows:
        err("%s: map has %d rows, want %d" % (tid, len(mp), rows)); return
    grid = []
    for r, line in enumerate(mp):
        if len(line) != cols:
            err("%s: row %d has %d cells, want %d" % (tid, r + 1, len(line), cols)); return
        for ch in line:
            if ch not in T:
                err("%s: unknown terrain char %r" % (tid, ch))
        grid.append(list(line))
    flat = "".join(mp)
    if "E" not in flat: err("%s: no eagle" % tid)
    limit = t.get("turn_limit", 0)
    events = t.get("events", [])
    for ev in events:
        if ev.get("terrain") not in BY_ID or not (1 <= ev.get("turn", 0) <= limit):
            err("%s: bad event %s" % (tid, ev))
    spawns = set(t.get("spawns", []))
    for s in spawns:
        c, r = parse(s)
        if T[grid[r][c]][0] not in SPAWN_OK:
            err("%s: spawn %s on %s" % (tid, s, T[grid[r][c]][0]))
    routes = t.get("routes", {})
    waves = t.get("waves", [])
    first_use, users = {}, collections.defaultdict(list)
    for w in waves:
        if "route" in w:
            first_use[w["route"]] = min(first_use.get(w["route"], 99), w["turn"])
            users[w["route"]].append(w)
    def wave_tags(w):
        tags = set(w.get("tags", []))
        for u in w["units"]:
            k = u["kind"] if isinstance(u, dict) else u
            tags |= set(EN.get(k, {}).get("tags", []))
            if isinstance(u, dict): tags |= set(u.get("tags", []))
        return tags
    route_cells = set()
    for rid, cells in routes.items():
        if rid not in first_use:
            warn("%s: route %s never used" % (tid, rid))
        pcs = [parse(x) for x in cells]
        for (c, r) in pcs:
            if not (0 <= c < cols and 0 <= r < rows):
                err("%s: route %s cell out of map" % (tid, rid))
        route_cells |= set(cells)
        for chk_turn in (first_use.get(rid, limit), 999):
            g = terrain_at(grid, events, chk_turn)
            for i, (c, r) in enumerate(pcs):
                tr = T[g[r][c]]
                if i == 0:
                    ok = tr[2] in ("start", "start_or_mid")
                    if not ok and cells[0] in spawns and users[rid] and all({"ambush", "boarder"} & wave_tags(w) for w in users[rid]):
                        ok = True
                    if not ok:
                        err("%s: route %s must start at gate/hatch/door or a spawn for ambush waves (%s is %s)" % (tid, rid, cells[0], tr[0]))
                elif i == len(pcs) - 1:
                    if tr[0] != "eagle":
                        err("%s: route %s must end at eagle (%s is %s)" % (tid, rid, cells[i], tr[0]))
                else:
                    if not (tr[2] is True or tr[2] == "start_or_mid"):
                        err("%s: route %s cell %s (%s) not walkable at turn %s" % (tid, rid, cells[i], tr[0], chk_turn))
                if i > 0:
                    pc, pr = pcs[i - 1]
                    if abs(pc - c) + abs(pr - r) != 1:
                        err("%s: route %s %s→%s not adjacent" % (tid, rid, cells[i - 1], cells[i]))
    hunters = 0
    L_node = t.get("level", 1)
    for w in waves:
        wt = w.get("turn", 0)
        if not (1 <= wt <= limit): err("%s: wave turn %s out of range" % (tid, wt))
        if ("route" in w) == ("at" in w): err("%s: wave at turn %d needs exactly one of route/at" % (tid, wt)); continue
        if "route" in w and w["route"] not in routes: err("%s: unknown route %s" % (tid, w["route"]))
        for u in w["units"]:
            k = u["kind"] if isinstance(u, dict) else u
            if k not in EN: err("%s: unknown enemy %s" % (tid, k)); continue
            e = EN[k]
            tags = set(e.get("tags", [])) | (set(u.get("tags", [])) if isinstance(u, dict) else set())
            if "hunter" in tags and w.get("lv_min", 1) <= L_node and not (isinstance(u, dict) and u.get("lv_min", 1) > L_node):
                hunters += 1
            fixed = e["type"] == "gun" or "post" in tags
            if fixed != ("at" in w):
                err("%s: %s at turn %d: guns/post stand on 'at' cells, others walk a route" % (tid, k, wt))
            if "at" in w:
                c, r = parse(w["at"])
                tr = T[terrain_at(grid, events, wt)[r][c]][0]
                allowed = e.get("at_terrain", ["high", "plain"])
                if tr not in allowed: err("%s: %s at %s stands on %s, allowed %s" % (tid, k, w["at"], tr, allowed))
                if w["at"] in route_cells: err("%s: at cell %s lies on a route" % (tid, w["at"]))
        if "first_fire" in w and not ("at" in w and wt + 1 <= w["first_fire"] <= limit):
            err("%s: bad first_fire in wave %d" % (tid, wt))
    order = t.get("order", {})
    if order.get("type") == "hold":
        c, r = parse(order["cell"])
        if T[grid[r][c]][1] is None: err("%s: order cell %s not standable" % (tid, order["cell"]))
        if not (1 <= order.get("turn", 0) <= limit): err("%s: order turn" % tid)
    elif order.get("type") not in ("no_leak", None):
        err("%s: order type %s" % (tid, order.get("type")))
    # level targets (warnings only, ARCH §3.2 says these are authoring targets)
    L = t.get("level", 1)
    tb, te, ts = LEVEL_TURNS(L)
    want = {"major": tb, "grand": tb, "epic": tb, "elite": te, "skirmish": ts}[scale]
    if limit != want and not t.get("tutorial"):
        warn("%s: turn_limit %d vs level-%d target %d" % (tid, limit, L, want))
    hunt_target = {"skirmish": max(0, (L - 5) // 8), "elite": (L - 1) // 8}.get(scale, (L + 1) // 4)
    if hunters > hunt_target and not t.get("tutorial"):
        warn("%s: %d hunters > level-%d target %d" % (tid, hunters, L, hunt_target))
    # do nothing
    b = t.get("base_level", L)
    for lv in sorted({b, L, min(24, b + 11)}):
        for wx in t.get("weather", ["clear"]):
            res = do_nothing(t, grid, events, routes, waves, EN, lv, wx)
            if res["outcome"] != "defeat":
                err("%s: doing nothing at L%d/%s does NOT lose (%s)" % (tid, lv, wx, res))
            t.setdefault("_sim", {})["L%d/%s" % (lv, wx)] = res

def do_nothing(t, grid, events, routes, waves, EN, L, weather):
    pad = t.get("pad")
    npad = max(0, (L - t.get("base_level", L)) // pad["every"]) if pad else 0
    live, morale, leaks, limit = [], 10, [], t["turn_limit"]
    spawned = [False] * len(waves)
    for turn in range(1, limit + 1):
        g = terrain_at(grid, events, turn)
        for i, w in enumerate(waves):
            if spawned[i] or w["turn"] != turn: continue
            spawned[i] = True
            if w.get("lv_min", 1) > L or "at" in w: continue
            kinds = [u["kind"] if isinstance(u, dict) else u for u in w["units"] if not (isinstance(u, dict) and u.get("lv_min", 1) > L)]
            kinds += [pad["kind"]] * npad if pad else []
            for k in kinds:
                live.append({"k": k, "route": routes[w["route"]], "step": 0, "carry": 0})
        live.sort(key=lambda e: (len(e["route"]) - e["step"]))
        for e in list(live):
            en = EN[e["k"]]
            budget = en["spd"] + e["carry"]
            e["carry"] = 0
            while e["step"] < len(e["route"]) - 1:
                c, r = parse(e["route"][e["step"] + 1])
                ch = g[r][c]
                cost = T[ch][3] + (1 if weather == "mud" and en["type"] == "cavalry" else 0)
                if cost <= budget:
                    budget -= cost
                    e["step"] += 1
                    if e["step"] == len(e["route"]) - 1:
                        live.remove(e)
                        loss = 3 if en["type"] in ("elite", "leader") else 2
                        morale -= loss
                        leaks.append((turn, e["k"]))
                        break
                else:
                    e["carry"] = budget if budget > 0 else 0
                    break
        if morale <= 0:
            return {"outcome": "defeat", "turn": turn, "leaks": len(leaks)}
        if all(spawned) and not live:
            return {"outcome": "victory(spent)", "turn": turn, "morale": morale}
    return {"outcome": "victory(hold)", "morale": morale, "leaks": len(leaks)}

def check_templates():
    EN = enemies_table()
    lib = load(P("data/campaigns/battle_templates_conquest.json"))
    for tid, t in lib["templates"].items():
        check_template(tid, t, EN)
    return lib["templates"]

def check_world(tpls):
    import check_world as CW
    patch = load(P("data/campaigns/napoleon/book_conquest_patch.json"))
    sb = dict(patch["scene_battles"]["trunk"]); sb.update(patch["scene_battles"]["conquest"])
    repo_tpl = load(os.path.join(CW.REPO, "data/campaigns/battle_templates.json"))["templates"]
    needed = {t["id"]: t for t in patch["templates_needed"]}
    def tpl_ok(tid, node):
        L = node.get("level")
        if tid in tpls:
            b = tpls[tid].get("base_level", tpls[tid].get("level", 1))
            if L is not None and not (b <= L <= b + 11): err("template %s used at L%s outside [%d, %d]" % (tid, L, b, b + 11))
            return True
        if tid in repo_tpl: return True
        if tid in needed:
            if L is not None and L != needed[tid]["level"] and node.get("type") != "slot": warn("template %s (to be written by B) wanted at L%d, used at L%s" % (tid, needed[tid]["level"], L))
            return True
        err("unknown template %s" % tid); return False
    for seg, m in sb.items():
        tpl_ok(m["template"], m)
    for seg_pool in patch["battle_pool"].values():
        for band, ids in seg_pool.items():
            lo, hi = map(int, band.split("-"))
            for tid in ids:
                if tid not in tpls and tid not in repo_tpl: err("battle_pool %s: %s does not exist" % (band, tid))
                elif tid in tpls:
                    b = tpls[tid].get("base_level", 1)
                    if lo < b or hi > b + 11: err("battle_pool %s: %s only valid L%d-%d" % (band, tid, b, b + 11))
    comp_path = P("data/campaigns/napoleon/companions_conquest.json")
    companions = load(comp_path)["companions"] if os.path.exists(comp_path) else {}
    if not companions: warn("companions_conquest.json missing")
    ec_path = P("data/campaigns/napoleon/events_common.json")
    ec = load(ec_path) if os.path.exists(ec_path) else {"events": []}
    common_ids = CW.check_events_common(ec, companions, err, warn)
    segs = {"trunk": "trunk.json", "conquest": "conquest.json"}
    maps = {"trunk": "maps/europe.json", "conquest": "maps/europe_late.json"}
    known_segments = ("trunk", "conquest", "ocean", "cristo")
    trail, info = [], {}
    for seg, fn in segs.items():
        path = P("data/campaigns/napoleon", fn)
        if not os.path.exists(path):
            warn("%s missing" % fn); continue
        d = load(path)
        info[seg] = CW.check_segment(seg, d, ec, companions, known_segments, err, warn)
        mp = load(P("data/campaigns/napoleon", maps[seg]))
        CW.check_map(mp, seg, d, sb, tpl_ok, info[seg]["events"] | common_ids, err, warn, trail)
    CW.check_level_trail(trail, err, warn)
    # branch-first rule as read by this package (CONQUEST.md §5)
    t_last = max(l for s, c, lv, sh in trail if s == "trunk" for l in lv) if any(s == "trunk" for s, *_ in trail) else 0
    for s, c, lv, sh in trail:
        if s == "conquest" and c == "hundred_days":
            for n in sh["nodes"]:
                L = n.get("level") or (n.get("slot", {}).get("level")) or (sb.get(n.get("scene"), {}).get("level") if n["type"] == "story" else None)
                if L is None: continue
                floor = t_last + 1 if n["type"] == "elite" else t_last
                if L < floor: err("conquest ch1 %s L%d below floor L%d" % (n["id"], L, floor))
    # interludes alternate (R6)
    for s in ("trunk", "conquest"):
        il = [sh.get("interlude") for seg, c, lv, sh in trail if seg == s]
        for a, b in zip(il, il[1:]):
            if a and a == b: err("R6: two chapters in a row with interlude %s in %s" % (a, s))
        for x in il:
            if x and not any(e.get("pool") == "interlude:" + x for e in ec.get("events", [])): warn("no events for interlude:%s" % x)
    return trail, info

BANNED = ["当铺", "典当", "当票", "流当", "估值铺", "掌柜", "挂牌", "柜台", "活当", "收当", "盘库", "鉴定", "营业", "经营须知"]
def check_words_and_ints():
    """ARCH §6 anti-regression word list (0 hits in player-visible data) and the kernel's integers-only rule."""
    import glob
    def walk(x, where):
        if isinstance(x, float): err("%s: float %s (data must be integers)" % (where, x))
        elif isinstance(x, dict):
            for k, v in x.items(): walk(v, where + "." + k)
        elif isinstance(x, list):
            for i, v in enumerate(x): walk(v, "%s[%d]" % (where, i))
        elif isinstance(x, str):
            for w in BANNED:
                if w in x: err("%s: banned word %s" % (where, w))
    for f in glob.glob(P("data", "**", "*.json"), recursive=True):
        walk(load(f), os.path.relpath(f, ROOT))

if __name__ == "__main__":
    tpls = check_templates()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    trail, info = check_world(tpls)
    check_words_and_ints()
    if "--days" in sys.argv:
        for seg, c, lv, sh in trail:
            print(seg, c, "boss", lv, "route days", sh.get("_route_days"), "days_max", sh["days_max"])
    if "--sim" in sys.argv:
        for tid, t in tpls.items():
            print(tid, json.dumps(t.get("_sim"), ensure_ascii=False))
    for m in WARN: print("WARN ", m)
    for m in ERR: print("ERROR", m)
    print("%d errors, %d warnings" % (len(ERR), len(WARN)))
    sys.exit(1 if ERR else 0)
