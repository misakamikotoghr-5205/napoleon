#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Build all cristo-branch JSON drafts, run the static checks and the battle evidence, render map previews.
#   python3 -I build_cristo.py            (writes ../data/**, ../maps/preview_*.png, ../tools/out/*.json)
import copy, heapq, json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(HERE)                     # .../wm/cristo
WM = os.path.dirname(ROOT)
REPO = "/home/user/dehoudang"

import cristo_story as ST
import cristo_more as MO
import cristo_maps as MP
import cristo_art as AR
import cristo_planned as PL
from cristo_enemies import E as ENEMIES
from cristo_templates import T as TEMPLATES
import cristo_uses as US
import battle_lib as B
import try_battle as TB

ERR, WARN = [], []


def err(m):
    ERR.append(m)


def warn(m):
    WARN.append(m)


def dump(path, obj):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
        f.write("\n")
    json.load(open(path, encoding="utf-8"))
    return path


def floats(o, where):
    if isinstance(o, float):
        err("float in %s: %r" % (where, o))
    elif isinstance(o, dict):
        for k, v in o.items():
            floats(v, where + "." + str(k))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            floats(v, "%s[%d]" % (where, i))


# ============================================================================ segment definition
EVENTS = ST.EVENTS + MO.COUNCILS + MO.INTERLUDES
SEGMENT = {
    "id": "cristo", "version": 2, "title": "伊夫堡 · 一八一五—一八三八",
    "source": "Alexandre Dumas, Le Comte de Monte-Cristo (1844—1846)，公有领域；不借用任何现代改编。",
    "brand": "伊夫堡",
    "initial": {"treasury": 2000, "morale": 55, "heat": 35, "vitality": 70, "construction": 0, "exploration": 0},
    "gauges": ST.GAUGES,
    "chapters": ST.CHAPTERS, "characters": ST.CHARACTERS, "items": ST.ITEMS,
    "rules": ST.RULES, "big_fate_extra": ST.BIG_FATE_EXTRA,
    "scenes": ST.SCENES, "events": EVENTS, "endings": ST.ENDINGS,
    "tuning": {"wealth_limit": 60000},
    "design_notes": ST.DESIGN_NOTES,
}

SHEETS = MP.finish()
MAPFILE = {"id": "med", "version": 1, "segment": "cristo",
           "_doc": "草稿（标签 cristo，2026-11-02）：伊夫堡分支五张图。形状同 ARCH §2.2。geo = [经度×100, 纬度×100]；xy = 1920×1080 画布坐标；offset 是同城节点的像素错位（同 conquest 草稿）。由 tools/build_cristo.py 生成。",
           "views": MP.VIEWS, "sheets": SHEETS}

# ============================================================================ companions
SHARED_BATTLE = {}
try:
    ob = json.load(open(os.path.join(REPO, "data/campaigns/ocean_battle.json"), encoding="utf-8"))
    for k in ("dantes", "faria", "morel"):
        SHARED_BATTLE[k] = ob["companions"][k]
except Exception as e:  # pragma: no cover
    warn("ocean_battle.json not readable: %s" % e)
COMPANIONS = {
    "version": 1,
    "_doc": "草稿（标签 cristo）：全书伙伴总表（ARCH §1.9 companions.json）里伊夫堡段新增的 8 行，以及 6 个跨段伙伴的补丁（只加伊夫堡段的招募点、阵营标签、宿命之地；battle 数值逐字沿用远洋 / 主干，不改）。"
            "bonds_by_segment 是本稿的小提议：同一个人在不同段属于不同阵营（唐泰斯在远洋是远洋同盟，在伊夫堡是马赛老街坊和伯爵府），每段最多 3 个标签；A 不采纳时取并集的前 3 个。",
    "companions": MO.COMPANIONS,
    "shared_patch": MO.SHARED_PATCH,
    "shared_battle_reference": SHARED_BATTLE,
    "pairs": MO.PAIRS,
    "bond_set_napoleon_add": MO.BOND_FACTIONS,
}

# ============================================================================ battles
def expand_routes(t):
    t = copy.deepcopy(t)
    t["routes"] = {k: B.expand_route(v) if isinstance(v, str) else v for k, v in t["routes"].items()}
    return t


SCENE_BATTLES = {
    "c_white_june": {"template": "marseille_arrest", "level": 14, "order_flag": "m_morrel_kept"},
    "c_morgiou": {"template": "morgiou_cove", "level": 15, "order_flag": "m_cargo_saved"},
    "c_if_night": {"template": "if_corridors", "level": 16, "order_flag": "m_escape_clean"},
    "c_tiboulen": {"template": "tiboulen_swim", "level": 17, "order_flag": "m_tiboulen_clean", "planned": True},
    "c_montecristo": {"template": "monte_cristo_cave", "level": 18, "order_flag": "m_all_chests", "planned": True},
    "c_san_sebastiano": {"template": "san_sebastiano", "level": 21, "order_flag": "m_albert_unharmed", "planned": True},
    "c_auteuil": {"template": "auteuil_garden", "level": 22, "order_flag": "m_box_kept", "planned": True},
    "c_trial": {"template": "cristo_final", "level": 24, "order_flag": "m_witness_alive", "planned": True},
}
BOSS_SCENE = {"marseille": "c_white_june", "if_years": "c_if_night", "montecristo": "c_montecristo", "mediterranean": "c_san_sebastiano", "paris_1838": "c_trial"}
BATTLE_POOL = {"cristo": {"12-17": ["alley_ambush", "coast_road"], "18-23": ["alley_ambush", "coast_road"]}}


def evidence():
    out = {}
    for tid in TEMPLATES:
        tpl = copy.deepcopy(TEMPLATES[tid])
        errs, warns = B.validate(tid, copy.deepcopy(tpl), ENEMIES)
        for e in errs:
            err("template %s: %s" % (tid, e))
        rows = []
        for L in US.levels_of(tid):
            idle, _ = TB.run(tid, L, [], US.PLANS[tid]["roster"], hero=False, passive=True)
            hero = TB.hero_best(tid, L)
            res, _ = TB.run(tid, L, US.PLANS[tid]["plan"], US.PLANS[tid]["roster"], cp_bonus=US.PLANS[tid].get("cp_bonus", 0))
            c = B.counts(TB.prep(tid), ENEMIES, L)
            rows.append({"L": L, "idle": "%s t%d" % (idle["outcome"], idle["turn"]), "hero_only": "%s t%d (%s)" % (hero["outcome"], hero["turn"], hero["kind"].split("@")[-1]),
                         "plan": {k: res[k] for k in ("outcome", "turn", "morale", "leaks", "kills", "fallen", "order_done")}, "counts": c})
            if idle["outcome"] == "victory":
                err("template %s L%d: doing nothing wins" % (tid, L))
            if hero["outcome"] == "victory":
                err("template %s L%d: hero alone wins" % (tid, L))
            if res["outcome"] != "victory":
                err("template %s L%d: reference plan loses (%s)" % (tid, L, res))
        out[tid] = {"validate": errs or "ok", "warnings": warns, "rows": rows}
    return out


def boss_curve(ev):
    curve = []
    for ch in ST.CHAPTERS:
        sid = BOSS_SCENE[ch["id"]]
        sb = SCENE_BATTLES[sid]
        if sb.get("planned"):
            curve.append({"chapter": ch["id"], "template": sb["template"], "L": sb["level"], "power": PL.PLANNED[sb["template"]]["power_target"], "planned": True})
        else:
            p = [r for r in ev[sb["template"]]["rows"] if r["L"] == sb["level"]][0]["counts"]["power"]
            curve.append({"chapter": ch["id"], "template": sb["template"], "L": sb["level"], "power": p})
    for a, b in zip(curve, curve[1:]):
        if b["power"] * 100 < a["power"] * 112:
            err("A5: boss power %s %d -> %s %d below x1.12" % (a["template"], a["power"], b["template"], b["power"]))
    return curve


# ============================================================================ static checks
def ids_elsewhere():
    """scene / chapter / event ids already used by trunk, conquest, ocean (book-wide uniqueness)"""
    used = {"scene": set(), "chapter": set(), "event": set()}
    srcs = [os.path.join(WM, "conquest/data/campaigns/napoleon/trunk.json"), os.path.join(WM, "conquest/data/campaigns/napoleon/conquest.json"),
            os.path.join(REPO, "data/campaigns/ocean_pawn.json")]
    for p in srcs:
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            warn("cannot read %s" % p)
            continue
        used["scene"] |= {s["id"] for s in d.get("scenes", [])}
        used["chapter"] |= {c["id"] for c in d.get("chapters", [])}
        used["event"] |= {e["id"] for e in d.get("events", [])}
    for p in [os.path.join(WM, "conquest/data/campaigns/napoleon/events_common.json"), os.path.join(WM, "ocean/ocean_events.json")]:
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        evs = d.get("events", d) if isinstance(d, dict) else d
        if isinstance(evs, dict):
            evs = list(evs.values())
        used["event"] |= {e["id"] for e in evs if isinstance(e, dict) and "id" in e}
    return used


COMPANION_IDS = set(MO.COMPANIONS) | set(MO.SHARED_PATCH)
SHARED_FLAGS_READ = {"faria_half_letter", "t_pharaon_known", "t_dantes_letter", "t_morrel_credit", "t_went_home"}
PAWN_WORDS = ["当铺", "典当", "当票", "流当", "估值铺", "掌柜", "挂牌", "柜台", "活当", "收当", "盘库", "鉴定", "营业", "经营须知"]


def check_segment():
    seg = SEGMENT
    floats(seg, "cristo.json")
    used = ids_elsewhere()
    chap_ids = [c["id"] for c in seg["chapters"]]
    scene_ids = [s["id"] for s in seg["scenes"]]
    event_ids = [e["id"] for e in seg["events"]]
    item_ids = {i["id"] for i in seg["items"]}
    char_ids = {c["id"] for c in seg["characters"]}
    for kind, ids in (("chapter", chap_ids), ("scene", scene_ids), ("event", event_ids)):
        if len(ids) != len(set(ids)):
            err("duplicate %s ids" % kind)
        for i in ids:
            if i in used[kind]:
                err("%s id %s already used elsewhere in the book" % (kind, i))
    if "prologue" in chap_ids:
        err("chapter id prologue is reserved")
    by_scene = {s["id"]: s for s in seg["scenes"]}
    for c in seg["chapters"]:
        for sid in c["scene_ids"]:
            if sid not in by_scene:
                err("chapter %s lists missing scene %s" % (c["id"], sid))
            elif by_scene[sid]["chapter"] != c["id"]:
                err("scene %s chapter mismatch" % sid)
    if sum(len(c["scene_ids"]) for c in seg["chapters"]) != len(scene_ids):
        err("scenes not all in chapters")
    flags_set, flags_read = set(), set()
    for s in list(seg["scenes"]) + list(seg["events"]):
        is_event = s in seg["events"]
        if s["speaker"] not in char_ids:
            err("%s: speaker %s not a character" % (s["id"], s["speaker"]))
        clues = {a["id"] for a in s.get("appraisals", [])}
        for a in s.get("appraisals", []):
            if a["kind"] not in ("spot", "weigh", "ring", "decode"):
                err("%s: appraisal kind %s" % (s["id"], a["kind"]))
        for it in s.get("item_ids", []):
            if it not in item_ids:
                err("%s: item %s" % (s["id"], it))
        if not is_event and not (6 <= len(s["body"]) <= 12) and s.get("draft") != "outline":
            warn("%s: VN body has %d lines (target 6-12)" % (s["id"], len(s["body"])))
        cids = [c["id"] for c in s["choices"]]
        if len(cids) != len(set(cids)):
            err("%s: duplicate choice ids" % s["id"])
        free = 0
        for c in s["choices"]:
            if is_event:
                for bad in ("branch", "ending", "advance"):
                    if bad in c:
                        err("event %s choice %s has %s" % (s["id"], c["id"], bad))
            elif not c.get("advance"):
                err("scene %s choice %s does not advance" % (s["id"], c["id"]))
            for cl in c.get("requires_clues", []):
                if cl not in clues:
                    err("%s/%s requires missing clue %s" % (s["id"], c["id"], cl))
            for f in c.get("flags", []):
                flags_set.add(f)
                if not f.startswith("m_"):
                    err("%s/%s sets non-m_ flag %s" % (s["id"], c["id"], f))
            for f in c.get("requires_flags", []):
                flags_read.add(f)
            rq = c.get("requires", {})
            for k in ("flags", "not_flags"):
                flags_read |= set(rq.get(k, []))
            if "not" in rq:
                flags_read |= set(rq["not"].get("flags", []))
            for it in c.get("items", []) + rq.get("items", []):
                if it not in item_ids:
                    err("%s/%s item %s" % (s["id"], c["id"], it))
            for who in rq.get("alive", []) + (rq.get("not", {}).get("alive", [])):
                if who not in COMPANION_IDS:
                    err("%s/%s alive check on unknown companion %s" % (s["id"], c["id"], who))
            rg = c.get("rogue", {})
            for who in rg.get("recruit", []):
                if who not in COMPANION_IDS:
                    err("%s/%s recruits unknown companion %s" % (s["id"], c["id"], who))
            for k in c.get("effects", {}):
                if k not in seg["initial"]:
                    err("%s/%s unknown metric %s" % (s["id"], c["id"], k))
            if "boss_mod" in c and not set(c["boss_mod"]) <= {"cp_bonus", "enemy_morale", "prep_turn"}:
                err("%s/%s boss_mod keys" % (s["id"], c["id"]))
            if not c.get("requires_clues") and not c.get("requires_flags") and not c.get("requires"):
                free += 1
        if free == 0:
            # allowed only when two choices are complementary on one flag (requires_flags [f] vs requires.not_flags [f])
            pos = {f for c in s["choices"] for f in c.get("requires_flags", [])}
            neg = {f for c in s["choices"] for f in c.get("requires", {}).get("not_flags", [])}
            if not (pos & neg):
                err("%s: every choice is gated (dead end)" % s["id"])
    for e in seg["rules"]["endings"]:
        flags_read |= set(e["when"].get("flags", []))
    flags_read |= set(seg["big_fate_extra"][0]["when"].get("not_flags", []))
    flags_set |= set(f for b in seg["big_fate_extra"] for f in b.get("flags", []))
    for f in sorted(flags_read):
        if f not in flags_set and f not in SHARED_FLAGS_READ:
            err("flag %s is read but never set" % f)
    ending_ids = {e["id"] for e in seg["endings"]}
    for e in seg["rules"]["endings"]:
        if e["id"] not in ending_ids:
            err("rules ending %s has no text" % e["id"])
    if seg["rules"]["default_ending"] not in ending_ids:
        err("default ending missing")
    if len(seg["rules"]["endings"]) < 2:
        err("need >= 2 fixed endings")
    # final scene must be able to reach every fixed ending
    last = by_scene[seg["chapters"][-1]["scene_ids"][-1]]
    final_flags = {f for c in last["choices"] for f in c["flags"]}
    for e in seg["rules"]["endings"]:
        if not set(e["when"].get("flags", [])) & final_flags:
            warn("ending %s is not keyed by a final-scene flag" % e["id"])
    # de-pawnshop scan over every player-visible string
    blob = json.dumps({k: v for k, v in seg.items() if k != "design_notes"}, ensure_ascii=False)
    for w in PAWN_WORDS:
        if w in blob:
            err("pawnshop word %s in cristo.json" % w)
    return flags_set


# ---------------------------------------------------------------------------- map checks
def graph(sheet, phase_all=True):
    adj = {n["id"]: [] for n in sheet["nodes"]}
    for l in sheet["links"]:
        cost = (l.get("legs", 0), l.get("voyage_days", 0))
        adj[l["a"]].append((l["b"], cost, l))
        if not l.get("oneway"):
            adj[l["b"]].append((l["a"], cost, l))
    return adj


def shortest(adj, a, b, banned=()):
    """legs + 3*voyage_days, as MP-equivalent"""
    dist = {a: 0}
    pq = [(0, a)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == b:
            return d
        if d > dist.get(u, 1e9):
            continue
        for v, (legs, vd), _ in adj[u]:
            if v in banned and v != b:
                continue
            nd = d + legs + 3 * vd
            if nd < dist.get(v, 1e9):
                dist[v] = nd
                heapq.heappush(pq, (nd, v))
    return None


def reachable(adj, a, banned=()):
    seen, st = {a}, [a]
    while st:
        u = st.pop()
        for v, _, _ in adj[u]:
            if v not in seen and v not in banned:
                seen.add(v)
                st.append(v)
    return seen


def battle_like(n, scene_battle_scenes):
    if n["type"] in ("battle", "elite", "boss"):
        return True
    if n["type"] == "slot" and "battle" in n["slot"]["kinds"]:
        return True
    if n["type"] == "story" and n.get("scene") in scene_battle_scenes:
        return True
    return False


def check_maps():
    floats(MAPFILE, "med.json")
    seg = SEGMENT
    by_ch = {c["id"]: c for c in seg["chapters"]}
    ev_ids = {e["id"] for e in seg["events"]}
    tpls = set(TEMPLATES) | set(PL.PLANNED)
    boss_level = {}
    report = []
    sb_scenes = {s for s, v in SCENE_BATTLES.items() if v["template"] not in ("marseille_arrest", "if_corridors", "monte_cristo_cave", "san_sebastiano", "cristo_final")}
    all_node_ids = []
    for sh in SHEETS:
        ch = sh["chapter"]
        nodes = {n["id"]: n for n in sh["nodes"]}
        all_node_ids += list(nodes)
        if len(nodes) != len(sh["nodes"]):
            err("%s: duplicate node ids" % ch)
        adj = graph(sh)
        for l in sh["links"]:
            for k in ("a", "b"):
                if l[k] not in nodes:
                    err("%s: link to missing node %s" % (ch, l[k]))
            if "legs" in l and not 1 <= l["legs"] <= 4:
                err("%s: legs out of range %s" % (ch, l))
            if "legs" not in l and not l.get("voyage_days"):
                err("%s: link without legs or voyage %s" % (ch, l))
        for k in ("start", "muster", "boss"):
            if sh[k] not in nodes:
                err("%s: %s node missing" % (ch, k))
        if nodes[sh["muster"]].get("role") != "muster":
            err("%s: muster role" % ch)
        # anchors
        anchors = [n for n in sh["nodes"] if n.get("scene")]
        if [n["scene"] for n in anchors] != by_ch[ch]["scene_ids"]:
            err("%s: anchor order %s != scene_ids %s" % (ch, [n["scene"] for n in anchors], by_ch[ch]["scene_ids"]))
        if nodes[sh["boss"]].get("scene") != by_ch[ch]["scene_ids"][-1]:
            err("%s: boss is not the last scene" % ch)
        for n in sh["nodes"]:
            if n["type"] == "event" and n.get("event") not in ev_ids:
                err("%s: node %s event %s missing" % (ch, n["id"], n.get("event")))
            if n["type"] in ("elite", "battle") and n.get("template") not in tpls:
                err("%s: node %s template %s unknown" % (ch, n["id"], n.get("template")))
            if "geo" not in n and "xy" not in n:
                err("%s: node %s has no position" % (ch, n["id"]))
            if MP.VIEWS[sh["view"]]["proj"] == "canvas" and "xy" not in n:
                err("%s: canvas view needs xy (%s)" % (ch, n["id"]))
        # reachability
        reach = reachable(adj, sh["start"])
        for nid in nodes:
            if nid not in reach:
                err("%s: node %s unreachable" % (ch, nid))
        # levels
        bossL = SCENE_BATTLES[BOSS_SCENE[ch]]["level"]
        boss_level[ch] = bossL
        for n in sh["nodes"]:
            L = None
            if n["type"] == "elite":
                L = n["level"]
                if L > bossL - 1:
                    err("%s: elite %s L%d > boss-1" % (ch, n["id"], L))
            if n["type"] == "slot" and "level" in n["slot"]:
                L = n["slot"]["level"]
                if L > bossL - 2:
                    err("%s: slot %s L%d > boss-2" % (ch, n["id"], L))
                if L != US.GENERIC_LEVELS[ch]:
                    err("%s: slot %s level %d != generic %d" % (ch, n["id"], L, US.GENERIC_LEVELS[ch]))
            if L is not None and L < 12:
                err("%s: %s below the branch floor" % (ch, n["id"]))
        for r in sh.get("rivals", []):
            for p in r["path"]:
                if p not in nodes:
                    err("%s: rival %s path node %s" % (ch, r["id"], p))
            bt = r["meet"].get("battle")
            if bt and bt["level"] > bossL - 2:
                err("%s: rival battle L%d > boss-2" % (ch, bt["level"]))
        for sid in by_ch[ch]["scene_ids"][:-1]:
            if sid in SCENE_BATTLES and SCENE_BATTLES[sid]["level"] > bossL - 1:
                err("%s: anchor battle %s > boss-1" % (ch, sid))
        # R1
        camps = {i for i, n in nodes.items() if n["type"] == "camp"}
        sup = {i for i, n in nodes.items() if n["type"] in ("supply", "shop")}
        if sh["boss"] in reachable(adj, sh["start"], camps):
            err("%s R1: a path to the boss avoids every camp" % ch)
        if sh["boss"] in reachable(adj, sh["start"], sup):
            err("%s R1: a path to the boss avoids every supply/shop" % ch)
        # R2
        for l in sh["links"]:
            a, b = nodes[l["a"]], nodes[l["b"]]
            if battle_like(a, sb_scenes) and battle_like(b, sb_scenes) and not l.get("rush"):
                err("%s R2: battle nodes adjacent %s-%s" % (ch, a["id"], b["id"]))
        # R3
        slots = [n for n in sh["nodes"] if n["type"] == "slot"]
        exp_ev = sum(n["slot"]["kinds"].get("event", 0) / sum(n["slot"]["kinds"].values()) for n in slots)
        if len(slots) * 100 < 30 * len(nodes):
            err("%s R3: slots %d/%d < 30%%" % (ch, len(slots), len(nodes)))
        if exp_ev < 3:
            err("%s R3: expected events %.1f < 3" % (ch, exp_ev))
        # R4
        for n in sh["nodes"]:
            if n["type"] == "elite" and sh["boss"] not in reachable(adj, sh["start"], {n["id"]}):
                err("%s R4: elite %s is on the mandatory path" % (ch, n["id"]))
        # R5: muster -> council -> ... camp -> boss
        council = [n for n in sh["nodes"] if n.get("role") == "council"]
        if len(council) != 1 or council[0]["id"] not in [v for v, _, _ in adj[sh["muster"]]]:
            err("%s R5: council not adjacent to muster" % ch)
        boss_nb = [v for v, _, _ in adj[sh["boss"]]]
        if not any(nodes[v]["type"] == "camp" and nodes[v].get("phase") == "campaign" for v in boss_nb):
            err("%s R5: no campaign camp right before the boss" % ch)
        for v in boss_nb:
            if nodes[v].get("phase") != "campaign":
                err("%s: boss reachable from accumulate node %s" % (ch, v))
        # R7 (MP 3 a day; voyages count their days)
        tour = [sh["start"]] + [n["id"] for n in anchors[1:-1]] + [sh["muster"], council[0]["id"]]
        mp = 0
        for a, b in zip(tour, tour[1:]):
            d = shortest(adj, a, b)
            if d is None:
                err("%s: no path %s -> %s" % (ch, a, b))
                d = 0
            mp += d
        posts = [i for i, n in nodes.items() if n.get("role") == "post"]
        if len(posts) < sh["stamps_need"]:
            err("%s: only %d posts for %d stamps" % (ch, len(posts), sh["stamps_need"]))
        detour = sorted(min((shortest(adj, t, p) or 99) for t in tour) * 2 for p in posts)[:sh["stamps_need"]]
        mp += sum(detour)
        cam = shortest(adj, council[0]["id"], sh["boss"]) or 0
        days = math.ceil((mp + cam) / 3)
        if sh["days_max"] < days + 3:
            err("%s R7: days_max %d < shortest %d + 3" % (ch, sh["days_max"], days))
        # R6
        report.append({"chapter": ch, "view": sh["view"], "nodes": len(nodes), "links": len(sh["links"]), "slots": len(slots),
                       "expected_events": round(exp_ev, 1), "shortest_days": days, "days_max": sh["days_max"], "boss_L": bossL, "interlude": sh["interlude"]})
    for a, b in zip(SHEETS, SHEETS[1:]):
        if a["interlude"].split(":")[0] == b["interlude"].split(":")[0] and a["interlude"] == b["interlude"]:
            err("R6: interlude repeats %s" % a["interlude"])
    Ls = [boss_level[c["id"]] for c in ST.CHAPTERS]
    if Ls != sorted(set(Ls)):
        err("boss levels not strictly increasing %s" % Ls)
    if Ls[0] < 13:
        err("first boss below branch floor")
    labels = json.dumps(MAPFILE, ensure_ascii=False)
    for w in PAWN_WORDS:
        if w in labels:
            err("pawnshop word %s in med.json" % w)
    return report


def check_companions():
    for cid, c in MO.COMPANIONS.items():
        b = c["battle"]
        if b["cls"] not in ("line", "grenadier", "jager", "hussar", "artillery", "medic", "engineer", "drummer"):
            err("companion %s cls %s" % (cid, b["cls"]))
        if b["skill"] not in ("bayonet_charge", "fortify", "mark_target", "raise_flag", "pay_chest"):
            err("companion %s skill" % cid)
        if len(c["bonds"]) > 3:
            err("companion %s too many bonds" % cid)
    tags = {f["tag"] for f in MO.BOND_FACTIONS} | {"far_sea", "shadow", "scholar", "imperial", "quartermaster", "italy", "family"}
    for cid, c in MO.COMPANIONS.items():
        for t in c["bonds"]:
            if t not in tags:
                err("companion %s bond tag %s unknown" % (cid, t))
    for p in MO.PAIRS:
        for k in ("a", "b"):
            if p[k] != "hero" and p[k] not in COMPANION_IDS:
                err("pair %s member %s" % (p["id"], p[k]))
    # every companion has a recruit point that exists
    scene_ids = {s["id"] for s in SEGMENT["scenes"]}
    ev_ids = {e["id"] for e in SEGMENT["events"]}
    recruited = set()
    for s in SEGMENT["scenes"] + SEGMENT["events"]:
        for c in s["choices"]:
            recruited |= set(c.get("rogue", {}).get("recruit", []))
    for cid in MO.COMPANIONS:
        if cid not in recruited:
            err("companion %s is never recruited by any choice" % cid)


# ============================================================================ previews
def previews():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except Exception:
        warn("PIL missing: no previews")
        return []
    font = None
    for fp in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc"]:
        if os.path.exists(fp):
            font = ImageFont.truetype(fp, 18)
            break
    geo = json.load(open(os.path.join(WM, "geo", "med.json")))
    v = geo["view"]

    def proj(lon, lat):
        x = v["scale"] * (math.radians(lon) - math.radians(v["lon_min"]))
        y = v["scale"] * (v["y_top"] - math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)))
        return x, y
    colors = {"story": (200, 60, 40), "boss": (140, 0, 0), "elite": (180, 90, 0), "battle": (200, 120, 0), "event": (60, 90, 200), "camp": (40, 140, 60),
              "supply": (90, 70, 40), "shop": (150, 60, 160), "slot": (120, 120, 120), "branch": (0, 0, 0)}
    out = []
    for sh in SHEETS:
        W, H = 1920, 1080
        img = Image.new("RGB", (W, H), (235, 228, 210))
        d = ImageDraw.Draw(img)
        pos = {}
        if MP.VIEWS[sh["view"]]["proj"] == "mercator":
            pts = {}
            for n in sh["nodes"]:
                x, y = proj(n["geo"][0] / 100, n["geo"][1] / 100)
                pts[n["id"]] = (x, y, n.get("offset", [0, 0]))
            xs = [p[0] for p in pts.values()]
            ys = [p[1] for p in pts.values()]
            cx0, cx1, cy0, cy1 = min(xs) - 60, max(xs) + 60, min(ys) - 60, max(ys) + 60
            s = min(W / (cx1 - cx0), H / (cy1 - cy0))
            ox = (W - (cx1 - cx0) * s) / 2
            oy = (H - (cy1 - cy0) * s) / 2
            tr = lambda x, y: (ox + (x - cx0) * s, oy + (y - cy0) * s)
            d.rectangle([0, 0, W, H], fill=(190, 210, 225))
            for poly in geo["land"]:
                ring = poly if isinstance(poly[0], (int, float)) else poly[0]
                pp = [tr(ring[i], ring[i + 1]) for i in range(0, len(ring) - 1, 2)]
                if len(pp) > 2:
                    d.polygon(pp, fill=(235, 228, 210), outline=(150, 140, 120))
            for nid, (x, y, off) in pts.items():
                X, Y = tr(x, y)
                pos[nid] = (X + off[0] * 1.6, Y + off[1] * 1.6)
        else:
            for n in sh["nodes"]:
                pos[n["id"]] = tuple(n["xy"])
        for l in sh["links"]:
            a, b = pos[l["a"]], pos[l["b"]]
            col = (60, 110, 180) if l.get("voyage_days") else (90, 80, 60)
            d.line([a, b], fill=col, width=3 if not l.get("voyage_days") else 2)
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            lab = ("~%dd" % l["voyage_days"]) if l.get("voyage_days") else str(l["legs"])
            d.text((mx + 4, my - 10), lab, fill=(40, 40, 40), font=font)
        for n in sh["nodes"]:
            x, y = pos[n["id"]]
            r = 16 if n["type"] in ("story", "boss") else 12
            col = colors.get(n["type"], (0, 0, 0))
            outline = (255, 215, 0) if n.get("phase") == "campaign" else (20, 20, 20)
            d.ellipse([x - r, y - r, x + r, y + r], fill=col, outline=outline, width=3)
            d.text((x + r + 4, y - 10), n["label"] + (" [%s]" % n.get("scene", n.get("template", n.get("event", ""))) if n["type"] != "slot" else ""), fill=(10, 10, 10), font=font)
        d.text((20, 20), "%s · %s · days_max %d · boss %s" % (sh["chapter"], sh["view"], sh["days_max"], sh["boss"]), fill=(0, 0, 0), font=font)
        p = os.path.join(ROOT, "maps", "preview_%s.png" % sh["chapter"])
        os.makedirs(os.path.dirname(p), exist_ok=True)
        img.save(p)
        out.append(p)
    return out


# ============================================================================ main
def main():
    flags = check_segment()
    map_report = check_maps()
    check_companions()
    ev = evidence()
    curve = boss_curve(ev)

    templates_out = {}
    for tid, t in TEMPLATES.items():
        tt = expand_routes(t)
        templates_out[tid] = {"template": tt, "uses": [dict(scene=s, **v) for s, v in SCENE_BATTLES.items() if v["template"] == tid]
                              + ([dict(node=US.MAP_BATTLES[tid]["node"], sheet=US.MAP_BATTLES[tid]["sheet"], level=US.MAP_BATTLES[tid]["level"])] if tid in US.MAP_BATTLES else [])
                              + ([{"pool": "cristo", "levels": sorted(US.GENERIC_LEVELS.values())}] if tid in ("alley_ambush", "coast_road") else []),
                              "plan": {"roster": US.PLANS[tid]["roster"], "deploy": US.PLANS[tid]["plan"], "text": US.PLANS[tid]["text"]},
                              "evidence": ev[tid]}
    tags_used = sorted({tg for e in ENEMIES.values() for tg in e["tags"]})
    battles = {
        "_doc": "草稿（标签 cristo）：伊夫堡分支的战斗。templates 是 battle_templates.json 的形状加 ARCH §3/§4 的扩展（size、level / base_level + pad、weather、新地形字符、spawns、events.on_kill、lv_min），"
                "外加本稿提议的三种命令 escape / extract / protect，每种都带 order_fallback（内核没有时退回 hold / no_leak）。planned 是 B2 要画的模板规格。"
                "evidence 是 tools/battle_sim.py（battle_rules.gd 的简化 Python 版，比真人弱：没有军令牌的“佯攻 / 齐射 / 后撤”、没有方阵和撤退）跑出来的：什么都不做必输、只放主角必输、参考打法能赢。",
        "enemies": {k: {kk: vv for kk, vv in v.items() if kk not in ("src", "note")} for k, v in ENEMIES.items()},
        "enemy_notes": {k: {"src": v["src"], "note": v["note"]} for k, v in ENEMIES.items()},
        "new_tags_used": tags_used,
        "orders_proposed": {
            "escape": "命令 {type:escape, unit, cells, turn}：第 turn 回合结束时，指定伙伴站在 cells 里任一格。没上场或倒下就算没完成。",
            "extract": "命令 {type:extract, cell, turns}：我方有人站在 cell 上的回合累计满 turns 个（不必连续）。",
            "protect": "命令 {type:protect, unit} 或 {type:protect, npc:{…}}：指定伙伴（或场上的一个不可控 NPC）上场并且打完都没有倒下。",
        },
        "templates": templates_out,
        "planned": PL.PLANNED,
        "scene_battles": SCENE_BATTLES,
        "map_battles": {"catalans_cove": US.MAP_BATTLES["catalans_cove"], "janina_lake": {"sheet": "if_years", "node": "janina_lake", "level": 15, "planned": True},
                        "appian_way": {"sheet": "mediterranean", "node": "appian_way", "level": 20, "planned": True},
                        "paris_rooftops": {"sheet": "paris_1838", "node": "rooftops", "level": 23, "planned": True}},
        "battle_pool": BATTLE_POOL,
        "generic_levels": US.GENERIC_LEVELS,
        "chapter_boss_levels": {c["id"]: SCENE_BATTLES[BOSS_SCENE[c["id"]]]["level"] for c in ST.CHAPTERS},
        "boss_curve": curve,
        "sim_notes": __import__("battle_sim").SIM_NOTES,
    }
    floats(battles, "battles")

    book_patch = {
        "_doc": "草稿（标签 cristo）：给 data/campaigns/napoleon/book.json 的补丁，只含伊夫堡段的内容字段（ARCH §8.4：结构字段归 A）。level 一律是全局等级 L（绝对值）。",
        "segments": {"cristo": {"file": "res://data/campaigns/napoleon/cristo.json", "map": "res://data/campaigns/napoleon/maps/med.json", "kind": "branch", "brand": "伊夫堡",
                                "scene_battles": {s: {"template": v["template"], "level": v["level"]} for s, v in SCENE_BATTLES.items()},
                                "order_flags": {s: v["order_flag"] for s, v in SCENE_BATTLES.items()}}},
        "branches": {"cristo": {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "",
                                "requires": {"any": [{"flags": ["faria_half_letter"]}, {"flags": ["t_pharaon_known"]}]},
                                "reasons": {"any": "你和马赛没有交集：没拿到法利亚的半封信，也没见过莫雷尔或法老号"},
                                "offer_text": {"ok": "伊夫堡 · 奉命携密信去马赛：法老号、雷瑟夫酒家、王家检察官的书房。", "locked": "伊夫堡（未开放）"},
                                "soft_hooks": {"t_dantes_letter": "开场多一行旁白：唐泰斯身上那封信，是你在费拉约港亲手交给他的（人心 −3，第一章唐泰斯信赖 +1）。",
                                               "t_morrel_credit": "莫雷尔记得土伦围城那年的担保：c_landfall 起手金币 +1。",
                                               "t_went_home": "你 1814 年回过马赛：第一章地图雾少一圈（开局揭开 fort_post、catalans）。",
                                               "faria_half_letter": "c_faria_27 的“拼上那半封信”可选（藏宝的位置）。"}}},
        "shared_flags_add": ["t_dantes_letter", "t_morrel_credit", "t_went_home"],
        "carry_items_note": "book.carry.items 已含 elba_watch、faria_half（ARCH §1.4）；伊夫堡段第一场还要发一件 emperor_letter（皇帝的第二封信），由 elba_1815 的 carry_the_letter 抉择的 items 发出，或由 c_landfall 的 item_ids 展示。",
        "battle_pool": BATTLE_POOL,
        "debug_carry": {"cristo": {"from": "branch_point", "flags_add": ["faria_half_letter", "t_pharaon_known", "m_letter_carried"],
                                   "stage_overrides": {"2": {"flags_add": ["m_denunciation", "m_bargain", "m_stay_marseille"], "companions_add": {"morel": 1, "caderousse": 1}},
                                                       "3": {"flags_add": ["m_faria_lives", "m_escape_clean", "m_jeune_amelie"], "companions_add": {"dantes": 2, "faria": 1, "jacopo": 1}},
                                                       "4": {"flags_add": ["m_treasure_taken", "m_spada_known"], "coins": {"gold": 8}},
                                                       "5": {"flags_add": ["m_albert_freed", "m_haydee_count"], "companions_add": {"haydee": 1, "ali": 1, "vampa": 1, "bertuccio": 1}}}}},
        "rogue_note": "第二章唐泰斯与法利亚还在牢里：名册里有他们，但只能在 if_corridors 上阵（第 9 回合起）；A 在 Battle2.lineup 里按 companions.json 的 available_from 判断（本稿提议的字段，见 CRISTO.md §5）。",
    }

    art = {"version": 1, "from": "C (标签 cristo)",
           "_doc": "伊夫堡分支需要的美术（data/hd/art_list.json 的条目形状）。B 合并进 art_list.json；variant_of 表示给现有条目加变体。ARCH §4.6 已列的地形、摆件、图标不在这里重复；map_if_fortress / map_paris 是 ARCH 已列的 id，这里补上画面说明（arch_listed）。",
           "assets": AR.build_art()}
    cast = {"version": 1, "_doc": "给 vn_cast.json 的演出表草稿（伊夫堡段）：chars 是新增人物的叫法和立绘 id；scenes / events 是背景与主讲人；variant 是同一立绘的年代变体（1815 / prisoner）。",
            "chars": AR.VN_CHARS, "scenes": {}, "events": {}}
    used_bg = {}
    for a in AR.ART:
        for u in a.get("used_in", []):
            used_bg.setdefault(u, a["id"])
    for s in SEGMENT["scenes"]:
        if s["id"] not in used_bg:
            err("scene %s has no background" % s["id"])
        cast["scenes"][s["id"]] = {"bg": used_bg.get(s["id"], "battle_backdrop"), "speaker": s["speaker"], "variant": AR.VARIANT_BY_SCENE.get(s["id"], {})}
        if s["id"] in ("c_faria_dies",):
            cast["scenes"][s["id"]]["bg_variant"] = "night"
    for e in SEGMENT["events"]:
        cast["events"][e["id"]] = {"bg": used_bg.get(e["id"], "camp_tent"), "speaker": e["speaker"]}
    speakers = {s["speaker"] for s in SEGMENT["scenes"] + SEGMENT["events"]}
    for sp in speakers:
        if sp not in AR.VN_CHARS:
            err("speaker %s not in vn chars" % sp)
    art_ids = {a["id"] for a in art["assets"] if a["kind"] == "chara" and "id" in a} | {"villefort", "dantes", "faria", "morel", "napoleon", "marie", "corso", "baptiste"}
    for cid, cc in AR.VN_CHARS.items():
        if cc["art"] != "placeholder_only" and cc["art"] not in art_ids:
            err("vn char %s art %s missing" % (cid, cc["art"]))

    paths = [dump("data/campaigns/napoleon/cristo.json", SEGMENT), dump("data/campaigns/napoleon/maps/med.json", MAPFILE),
             dump("data/campaigns/napoleon/companions_cristo.json", COMPANIONS), dump("data/campaigns/battle_templates_cristo.json", battles),
             dump("data/campaigns/napoleon/book_cristo_patch.json", book_patch), dump("data/hd/art_requests/C_cristo.json", art),
             dump("data/hd/vn_cast_cristo.json", cast)]
    pv = previews()
    summary = {"errors": ERR, "warnings": WARN, "maps": map_report, "boss_curve": curve,
               "counts": {"scenes": len(SEGMENT["scenes"]), "events": len(SEGMENT["events"]), "random_events": len([e for e in SEGMENT["events"] if e["pool"] not in ("fixed",) and not e["pool"].startswith("interlude")]),
                          "characters": len(SEGMENT["characters"]), "items": len(SEGMENT["items"]), "endings": len(SEGMENT["endings"]),
                          "companions_new": len(MO.COMPANIONS), "templates_built": len(TEMPLATES), "templates_planned": len(PL.PLANNED),
                          "enemies": len(ENEMIES), "art_assets": len(art["assets"]), "flags_set": len(flags)},
               "evidence": {tid: [{"L": r["L"], "idle": r["idle"], "hero_only": r["hero_only"], "plan": "%s m%d leaks%d fallen%s order%s" % (r["plan"]["outcome"], r["plan"]["morale"], r["plan"]["leaks"], r["plan"]["fallen"], r["plan"]["order_done"]), "power": r["counts"]["power"], "enemies": r["counts"]["enemies"], "hunters": r["counts"]["hunters"], "elites": r["counts"]["elites"]} for r in v["rows"]] for tid, v in ev.items()},
               "files": paths + pv}
    dump("tools/out/build_summary.json", summary)
    print(json.dumps({k: summary[k] for k in ("errors", "warnings", "counts", "boss_curve")}, ensure_ascii=False, indent=1))
    print(json.dumps(map_report, ensure_ascii=False))
    for tid, rows in summary["evidence"].items():
        for r in rows:
            print(tid, r)
    return 1 if ERR else 0


if __name__ == "__main__":
    sys.exit(main())
