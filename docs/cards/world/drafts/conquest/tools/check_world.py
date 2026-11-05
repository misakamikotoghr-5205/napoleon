"""Segment, map, book-patch, companion and art checks for the conquest package.
Imported by check_conquest.py (which owns ERR / WARN and the template checks)."""
import json, math, os, collections, itertools

REPO = "/home/user/dehoudang"
METRICS = ["treasury", "morale", "heat", "vitality", "construction", "exploration"]
APPRAISAL_KINDS = ["spot", "weigh", "ring", "decode"]
COND_KEYS = {"flags", "any_flags", "not_flags", "metric", "stat", "coins", "alive", "items", "count_flags",
             "scene_done", "hero_ok", "any", "not", "mustered"}
CHOICE_KEYS = {"id", "label", "requires_clues", "requires_flags", "requires", "flags", "remove_flags", "items",
               "remove_items", "advance", "effects", "rogue", "branch", "days", "battle", "reveal", "boss_mod", "note"}
ROGUE_KEYS = {"coins", "props", "recruit", "troops", "heal", "trust"}
COINS = {"gold", "supply", "medal", "intel"}
PROPS = {"prop_loaded_dice", "prop_barricade", "prop_forced_march", "prop_spyglass", "prop_smoke_bomb",
         "prop_field_ration", "prop_bribe_pouch", "prop_imperial_decree"}
BOSS_MOD_KEYS = {"cp_bonus", "enemy_morale", "prep_turn", "remove_wave", "extra_deploy", "reveal_waves"}
NODE_TYPES = {"story", "battle", "elite", "boss", "event", "camp", "supply", "shop", "branch", "slot"}
BATTLEISH = {"battle", "elite", "boss"}
FLAG_PREFIX = {"trunk": ("t_",), "conquest": ("k_",)}
CROSS_OK = {"faria_half_letter", "o_followed", "m_letter_carried"}


def _load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


# ------------------------------------------------------------------ conditions
def cond_keys_ok(c, where, err):
    if not isinstance(c, dict):
        err("%s: condition is not an object" % where); return
    for k, v in c.items():
        if k not in COND_KEYS:
            err("%s: unknown condition key %s" % (where, k))
        if k in ("any",):
            for sub in v: cond_keys_ok(sub, where, err)
        if k == "not": cond_keys_ok(v, where, err)
        if k in ("metric", "stat", "coins"):
            for m, (op, n) in v.items():
                if op not in (">=", "<=", ">", "<", "=="): err("%s: bad operator %s" % (where, op))
                if not isinstance(n, int): err("%s: non-integer threshold" % where)


def cond_flags(c):
    """flags a condition reads (for cross-segment checks)."""
    out = set()
    if not isinstance(c, dict): return out
    for k, v in c.items():
        if k in ("flags", "any_flags", "not_flags"): out |= set(v)
        if k == "count_flags": out |= set(v["of"])
        if k == "any":
            for s in v: out |= cond_flags(s)
        if k == "not": out |= cond_flags(v)
    return out


# ------------------------------------------------------------------ segment definitions
def check_choice(ch, where, appraisal_ids, items, err, warn, in_event=False, segments=()):
    for k in ch:
        if k not in CHOICE_KEYS: err("%s: choice key %s not in the agreed shape" % (where, k))
    for k in ("requires_clues", "requires_flags", "flags", "remove_flags", "items", "remove_items"):
        v = ch.get(k, [])
        if not (isinstance(v, list) and all(isinstance(x, str) for x in v)): err("%s: %s must be string list" % (where, k))
    for clue in ch.get("requires_clues", []):
        if clue not in appraisal_ids: err("%s: requires clue %s not in this scene" % (where, clue))
    for it in ch.get("items", []) + ch.get("remove_items", []):
        if it not in items: err("%s: unknown item %s" % (where, it))
    for m, v in ch.get("effects", {}).items():
        if m not in METRICS or not isinstance(v, int): err("%s: bad effect %s" % (where, m))
    if not isinstance(ch.get("advance", True), bool): err("%s: advance must be bool" % where)
    if "requires" in ch: cond_keys_ok(ch["requires"], where, err)
    r = ch.get("rogue", {})
    for k, v in r.items():
        if k not in ROGUE_KEYS: err("%s: rogue key %s" % (where, k))
    for c, n in r.get("coins", {}).items():
        if c not in COINS or not isinstance(n, int): err("%s: bad coin %s" % (where, c))
    for p in r.get("props", []):
        if p not in PROPS: err("%s: unknown prop %s" % (where, p))
    for k in ch.get("boss_mod", {}):
        if k not in BOSS_MOD_KEYS: err("%s: boss_mod key %s" % (where, k))
    if in_event:
        for k in ("branch", "advance"):
            if k in ch: err("%s: events may not carry %s (ARCH §2.6)" % (where, k))
    if "branch" in ch and ch["branch"] not in segments:
        err("%s: branch to unknown segment %s" % (where, ch["branch"]))
    return r.get("recruit", [])


def check_segment(seg, d, events_common, companions, segments, err, warn):
    """Kernel v1 _valid_definition rules + the v2 extras this package uses."""
    W = lambda m: "%s: %s" % (seg, m)
    if d.get("version") not in (1, 2): err(W("version"))
    ini = d.get("initial", {})
    if set(ini) != set(METRICS) or any(not isinstance(ini[m], int) for m in ini): err(W("initial metrics"))
    elif ini["treasury"] == 0 or ini["vitality"] == 0 or ini["heat"] == 100: err(W("initial metric at a failure value"))
    for key in ("chapters", "scenes", "items", "endings"):
        if not isinstance(d.get(key), list) or not d[key]: err(W("%s must be a non-empty list" % key))
    items = {i["id"] for i in d.get("items", [])}
    chars = {c["id"]: c for c in d.get("characters", [])}
    chap_ids, declared = [], []
    for c in d["chapters"]:
        if c["id"] in chap_ids: err(W("duplicate chapter %s" % c["id"]))
        chap_ids.append(c["id"])
        if not isinstance(c.get("currency"), str) or not c.get("scene_ids"): err(W("chapter %s shape" % c["id"]))
        if not isinstance(c.get("treasury_start"), int) or c["treasury_start"] <= 0: err(W("chapter %s treasury_start" % c["id"]))
        declared += c["scene_ids"]
        if "when" in c: cond_keys_ok(c["when"], W(c["id"]), err)
    sids = [s["id"] for s in d["scenes"]]
    if sids != declared: err(W("scenes order must equal concatenated chapter scene_ids"))
    if len(set(sids)) != len(sids): err(W("duplicate scene ids"))
    recruits = set()
    flags_set = set()
    for s in d["scenes"]:
        where = W(s["id"])
        if s.get("chapter") not in chap_ids: err(where + ": bad chapter")
        if s.get("speaker") and s["speaker"] not in chars: err(where + ": speaker %s not a character" % s["speaker"])
        if not (6 <= len(s.get("body", [])) <= 12) and not s.get("condensed"):
            warn(where + ": %d body lines (full scenes want 6–12)" % len(s.get("body", [])))
        if s.get("condensed") and not (3 <= len(s.get("body", [])) <= 8):
            warn(where + ": condensed scene has %d lines" % len(s.get("body", [])))
        for it in s.get("item_ids", []):
            if it not in items: err(where + ": item_ids %s" % it)
        if "when" in s: cond_keys_ok(s["when"], where, err)
        aids = []
        for a in s.get("appraisals", []):
            if a.get("kind") not in APPRAISAL_KINDS or not isinstance(a.get("observation"), str): err(where + ": appraisal %s" % a.get("id"))
            aids.append(a["id"])
        if len(set(aids)) != len(aids): err(where + ": duplicate appraisal")
        if not s.get("choices"): err(where + ": no choices")
        cids = [c["id"] for c in s["choices"]]
        if len(set(cids)) != len(cids): err(where + ": duplicate choice")
        open_choice = False
        for c in s["choices"]:
            recruits |= set(check_choice(c, "%s/%s" % (where, c["id"]), set(aids), items, err, warn, segments=segments))
            flags_set |= set(c.get("flags", []))
            if not c.get("requires_clues") and not c.get("requires_flags") and not c.get("requires"):
                open_choice = True
        if not open_choice: err(where + ": every choice is gated (needs at least one free choice)")
    ev_ids = set()
    for e in d.get("events", []):
        where = W("event " + e["id"])
        if e["id"] in ev_ids: err(where + ": duplicate")
        ev_ids.add(e["id"])
        if e.get("speaker") and e["speaker"] not in chars and e["speaker"] not in companions: err(where + ": speaker %s" % e["speaker"])
        if "requires" in e: cond_keys_ok(e["requires"], where, err)
        aids = [a["id"] for a in e.get("appraisals", [])]
        for a in e.get("appraisals", []):
            if a.get("kind") not in APPRAISAL_KINDS: err(where + ": appraisal kind")
        open_choice = False
        for c in e["choices"]:
            recruits |= set(check_choice(c, "%s/%s" % (where, c["id"]), set(aids), items, err, warn, in_event=True, segments=segments))
            flags_set |= set(c.get("flags", []))
            if not c.get("requires_clues") and not c.get("requires_flags") and not c.get("requires"):
                open_choice = True
        if not open_choice: err(where + ": every choice is gated")
        if e.get("pool") == "fixed" and e.get("council"):
            if len(e["choices"]) != 3 or any("boss_mod" not in c for c in e["choices"]):
                err(where + ": council events offer 3 choices, each with boss_mod (ARCH §2.8 R5)")
    for r in recruits:
        if r not in companions: err(W("recruits %s, not in companions" % r))
    end_ids = {e["id"] for e in d["endings"]}
    rules = d.get("rules", {})
    for f in rules.get("failures", []):
        if f["ending"] not in end_ids: err(W("failure ending %s missing" % f["ending"]))
        cond_keys_ok(f["when"], W("failure"), err)
    for e in rules.get("endings", []):
        if e["id"] not in end_ids: err(W("rules.endings %s missing" % e["id"]))
        cond_keys_ok(e["when"], W("ending " + e["id"]), err)
        for fl in cond_flags(e["when"]):
            if fl not in flags_set and not fl.startswith("t_") and fl not in CROSS_OK: err(W("ending %s reads flag %s nobody sets" % (e["id"], fl)))
    if rules.get("default_ending") and rules["default_ending"] not in end_ids: err(W("default_ending"))
    for b in d.get("big_fate_extra", []):
        if b.get("jump") and b["jump"] not in segments: err(W("big fate jump %s" % b["jump"]))
    # flag prefixes
    pref = FLAG_PREFIX.get(seg, ())
    for fl in flags_set:
        if not fl.startswith(pref) and fl not in CROSS_OK:
            if seg == "trunk" and fl.startswith(("k_", "o_", "m_")):
                continue
            warn(W("flag %s does not use the %s prefix" % (fl, "/".join(pref))))
    return {"events": ev_ids, "flags": flags_set, "chapters": chap_ids, "endings": end_ids, "scenes": sids}


def check_events_common(ec, companions, err, warn):
    ids = set()
    for e in ec.get("events", []):
        where = "events_common " + e["id"]
        if e["id"] in ids: err(where + ": duplicate")
        ids.add(e["id"])
        if not e.get("pool", "").startswith(("interlude:", "common")) and e.get("pool") != "fixed": warn(where + ": pool %s" % e.get("pool"))
        if "requires" in e: cond_keys_ok(e["requires"], where, err)
        aids = {a["id"] for a in e.get("appraisals", [])}
        open_choice = False
        for c in e["choices"]:
            check_choice(c, "%s/%s" % (where, c["id"]), aids, set(), err, warn, in_event=True)
            if not c.get("requires_clues") and not c.get("requires_flags") and not c.get("requires"): open_choice = True
        if not open_choice: err(where + ": every choice is gated")
        if e.get("speaker") and e["speaker"] not in companions and e["speaker"] not in ("villefort", "napoleon"): warn(where + ": speaker %s" % e["speaker"])
    return ids


# ------------------------------------------------------------------ maps
EUROPE = {"lon_min": -12.0, "scale": 2022.203982815, "y_top": 1.42678824664}
def merc(lon, lat):
    s = EUROPE["scale"]
    return s * (math.radians(lon) - math.radians(EUROPE["lon_min"])), s * (EUROPE["y_top"] - math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)))

def frame_positions(sheet, frame, nodes):
    pts = {}
    if "lon" in frame:
        x0, y1 = merc(frame["lon"][0] / 100, frame["lat"][0] / 100)
        x1, y0 = merc(frame["lon"][1] / 100, frame["lat"][1] / 100)
        s = min(1920 / (x1 - x0), 1080 / (y1 - y0))
        for n in nodes:
            x, y = merc(n["geo"][0] / 100, n["geo"][1] / 100)
            ox, oy = n.get("offset", [0, 0])
            pts[n["id"]] = ((x - x0) * s + (1920 - (x1 - x0) * s) / 2 + ox, (y - y0) * s + (1080 - (y1 - y0) * s) / 2 + oy)
    else:
        for n in nodes:
            xy = n.get("xy_frames", {}).get(frame["id"], n.get("xy"))
            pts[n["id"]] = tuple(xy)
    return pts

def in_frame(sheet, n):
    fr = n.get("frame")
    if fr: return fr
    return [sheet["frames"][-1]["id"]] if sheet.get("frames") else []


def variants(sheet):
    sets = set()
    for n in sheet["nodes"]:
        r = n.get("requires", {})
        if "flags" in r and len(r) == 1: sets.add(tuple(r["flags"]))
    return [set(s) for s in sorted(sets)] or [set()]

def active(n, V):
    r = n.get("requires", {})
    if "flags" in r and not set(r["flags"]) <= V: return False
    return True

def graph(sheet, V, nodes, skip=()):
    adj = collections.defaultdict(list)
    for l in sheet["links"]:
        if l["a"] not in nodes or l["b"] not in nodes or l["a"] in skip or l["b"] in skip: continue
        r = l.get("requires", {})
        if "flags" in r and not set(r["flags"]) <= V: continue
        w = l.get("legs", 0)
        adj[l["a"]].append((l["b"], w, l))
        if not l.get("oneway"): adj[l["b"]].append((l["a"], w, l))
    return adj

def reach(adj, s):
    seen, st = {s}, [s]
    while st:
        u = st.pop()
        for v, _, _ in adj[u]:
            if v not in seen: seen.add(v); st.append(v)
    return seen

def dist(adj, s):
    import heapq
    d, h = {s: 0}, [(0, s)]
    while h:
        k, u = heapq.heappop(h)
        if k > d[u]: continue
        for v, w, l in adj[u]:
            nk = k + w + l.get("voyage_days", 0) * 3
            if nk < d.get(v, 1e9): d[v] = nk; heapq.heappush(h, (nk, v))
    return d

def pick(x, nodes):
    if isinstance(x, list):
        for i in x:
            if i in nodes: return i
        return None
    return x if x in nodes else None


def check_map(mp, seg, segdef, scene_battles, tpl_ok, events_ok, err, warn, boss_trail):
    """boss_trail: list of (chapter, [boss levels per variant]) in play order, appended to."""
    W = lambda m: "map %s: %s" % (mp["id"], m)
    ids_seen = set()
    chapters = {c["id"]: c for c in segdef["chapters"]}
    scenes = {s["id"]: s for s in segdef["scenes"]}
    sheet_chapters = [s["chapter"] for s in mp["sheets"]]
    if sheet_chapters != [c["id"] for c in segdef["chapters"]]:
        err(W("sheets %s do not match chapters" % sheet_chapters))
    for sh in mp["sheets"]:
        ch = sh["chapter"]
        S = lambda m: W("%s: %s" % (ch, m))
        allnodes = {n["id"]: n for n in sh["nodes"]}
        for n in sh["nodes"]:
            if n["id"] in ids_seen: err(S("node id %s repeats inside the segment" % n["id"]))
            ids_seen.add(n["id"])
            if n["type"] not in NODE_TYPES: err(S("%s type %s" % (n["id"], n["type"])))
            if not (isinstance(n.get("geo"), list) and all(isinstance(v, int) for v in n["geo"])): err(S("%s geo" % n["id"]))
            if n["type"] in ("story", "boss", "branch") and n.get("scene") not in chapters[ch]["scene_ids"]:
                err(S("%s scene %s not in chapter" % (n["id"], n.get("scene"))))
            if n["type"] == "event" and n.get("event") not in events_ok: err(S("%s event %s missing" % (n["id"], n.get("event"))))
            if n["type"] in ("battle", "elite"):
                if not tpl_ok(n["template"], n): pass
            if n["type"] == "slot":
                k = n["slot"]["kinds"]
                if not k or any(t not in NODE_TYPES for t in k): err(S("%s slot kinds" % n["id"]))
                if ("battle" in k or "elite" in k) and "level" not in n["slot"]: err(S("%s slot without level" % n["id"]))
            if "requires" in n: cond_keys_ok(n["requires"], S(n["id"]), err)
        for l in sh["links"]:
            if l["a"] not in allnodes or l["b"] not in allnodes: err(S("link %s-%s dangling" % (l["a"], l["b"])))
            if "legs" in l and not (1 <= l["legs"] <= 4): err(S("link legs"))
            if "legs" not in l and not l.get("voyage_days"): err(S("link %s-%s has neither legs nor voyage_days" % (l["a"], l["b"])))
        # anchors: every scene of the chapter appears exactly once
        anchor_of = {}
        for n in sh["nodes"]:
            if n.get("scene"): anchor_of.setdefault(n["scene"], []).append(n["id"])
        for sid in chapters[ch]["scene_ids"]:
            if len(anchor_of.get(sid, [])) != 1: err(S("scene %s has %d anchor nodes" % (sid, len(anchor_of.get(sid, [])))))
        lv_boss = []
        vs = variants(sh)
        if set() not in vs and pick(sh["boss"], {k: n for k, n in allnodes.items() if active(n, set())}):
            vs = [set()] + vs
        for V in vs:
            nodes = {k: n for k, n in allnodes.items() if active(n, V)}
            tag = S("[%s]" % ",".join(sorted(V)) if V else "")
            adj = graph(sh, V, nodes)
            start = sh["start"]
            boss = pick(sh["boss"], nodes); muster = pick(sh["muster"], nodes)
            if not boss or not muster: err(tag + " no boss/muster"); continue
            R = reach(adj, start)
            for k in nodes:
                if k not in R: err(tag + " %s unreachable" % k)
            # scene order: anchors of scenes whose `when` holds under V
            seq = []
            for sid in chapters[ch]["scene_ids"]:
                w = scenes[sid].get("when", {})
                if "flags" in w and not set(w["flags"]) <= V: continue
                if anchor_of.get(sid): seq.append(anchor_of[sid][0])
            for a in seq:
                if a not in nodes: err(tag + " anchor %s inactive in this variant" % a)
            for a, b in zip(seq, seq[1:]):
                if b not in reach(adj, a): err(tag + " anchor %s cannot reach next anchor %s" % (a, b))
            camp_nodes = {k for k, n in nodes.items() if n.get("phase") == "campaign"}
            # campaign nodes behind the muster
            adj_nm = graph(sh, V, nodes, skip=(muster,))
            leak = reach(adj_nm, start) & camp_nodes
            if leak: err(tag + " campaign nodes reachable without the muster: %s" % sorted(leak))
            if nodes[muster].get("phase") == "campaign": err(tag + " muster must be an accumulation node")
            # R1
            for kinds, name in (({"camp"}, "camp"), ({"supply", "shop"}, "supply/shop")):
                skip = {k for k, n in nodes.items() if n["type"] in kinds}
                if boss in reach(graph(sh, V, nodes, skip=skip), start): err(tag + " R1: a path to the boss avoids every %s" % name)
            # R2
            def battle_class(n):
                if n["type"] in BATTLEISH: return True
                if n["type"] == "story" and n.get("scene") in scene_battles: return True
                if n["type"] == "slot" and ({"battle", "elite"} & set(n["slot"]["kinds"])): return True
                return False
            for l in sh["links"]:
                if l["a"] in nodes and l["b"] in nodes and not l.get("rush") and battle_class(nodes[l["a"]]) and battle_class(nodes[l["b"]]):
                    err(tag + " R2: %s and %s are adjacent battles" % (l["a"], l["b"]))
            # R3
            slots = [n for n in nodes.values() if n["type"] == "slot"]
            if len(slots) * 10 < 3 * len(nodes): err(tag + " R3: %d slots of %d nodes (< 30%%)" % (len(slots), len(nodes)))
            exp = sum(n["slot"]["kinds"].get("event", 0) / sum(n["slot"]["kinds"].values()) for n in slots)
            exp += sum(1 for n in nodes.values() if n["type"] == "event" and n.get("role") != "council")
            if exp < 3: err(tag + " R3: expected events %.1f < 3" % exp)
            # R4
            for k, n in nodes.items():
                if n["type"] == "elite":
                    if boss not in reach(graph(sh, V, nodes, skip=(k,)), start): err(tag + " R4: elite %s is on every path" % k)
                    for a in seq:
                        if a != k and a not in reach(graph(sh, V, nodes, skip=(k,)), start): err(tag + " R4: elite %s blocks anchor %s" % (k, a))
            # R5
            councils = {k for k in camp_nodes if nodes[k].get("role") == "council"}
            if not councils: err(tag + " R5: no council in the campaign phase")
            elif boss in reach(graph(sh, V, nodes, skip=councils), muster): err(tag + " R5: the boss is reachable without the council")
            ccamps = {k for k in camp_nodes if nodes[k]["type"] == "camp"}
            if boss in reach(graph(sh, V, nodes, skip=ccamps), muster): err(tag + " R5: the boss is reachable without a camp night")
            pre = [v for v, _, _ in adj[boss] if v in camp_nodes and v in reach(graph(sh, V, nodes, skip=(boss,)), muster)]
            for v in pre:
                if nodes[v]["type"] != "camp": err(tag + " R5: %s leads straight into the boss (want the camp night)" % v)
            # R7: start -> accumulation anchors -> enough posts -> muster
            acc_seq = [a for a in seq if nodes[a].get("phase") != "campaign"]
            posts = [k for k, n in nodes.items() if n.get("role") == "post"]
            need = sh.get("stamps_need", 0)
            if len(posts) < need: err(tag + " only %d posts for stamps_need %d" % (len(posts), need))
            D = {k: dist(adj, k) for k in [start] + acc_seq + posts + [muster]}
            best = 1e9
            for combo in itertools.permutations(posts, need):
                stops = [start] + acc_seq
                # insert posts greedily after the last anchor (cheap upper bound) and as detours
                cost = sum(D[a].get(b, 1e9) for a, b in zip(stops, stops[1:]))
                cur = stops[-1]
                for p in combo:
                    cost += D[cur].get(p, 1e9); cur = p
                cost += D[cur].get(muster, 1e9)
                best = min(best, cost)
            if need == 0:
                stops = [start] + acc_seq + [muster]
                best = sum(D[a].get(b, 1e9) for a, b in zip(stops, stops[1:]))
            days = math.ceil(best / 3) + sum(1 for k in acc_seq if nodes[k].get("scene") in scene_battles)
            if sh["days_max"] < days + 3: err(tag + " R7: days_max %d < route days %d + 3" % (sh["days_max"], days))
            elif sh["days_max"] > days + 9: warn(tag + " days_max %d is loose (route ~%d days)" % (sh["days_max"], days))
            sh.setdefault("_route_days", {})[",".join(sorted(V))] = days
            # levels
            bl = scene_battles.get(nodes[boss].get("scene"), {}).get("level")
            if bl is None: err(tag + " boss has no scene battle"); continue
            lv_boss.append(bl)
            for k, n in nodes.items():
                if n["type"] == "elite" and n["level"] > bl - 1: err(tag + " elite %s L%d > boss L%d − 1" % (k, n["level"], bl))
                if n["type"] == "battle" and n["level"] > bl - 2: err(tag + " battle %s L%d > boss − 2" % (k, n["level"]))
                if n["type"] == "slot" and "level" in n["slot"] and n["slot"]["level"] > bl - 2: err(tag + " slot %s L%d > boss − 2" % (k, n["slot"]["level"]))
                if n["type"] == "story" and n.get("scene") in scene_battles and scene_battles[n["scene"]]["level"] > bl - 1:
                    err(tag + " anchor battle %s above boss − 1" % k)
            for rv in sh.get("rivals", []):
                if "requires" in rv and not set(rv["requires"].get("flags", [])) <= V: continue
                for p in rv["path"]:
                    if p not in nodes: err(tag + " rival %s path %s" % (rv["id"], p))
                for a, b in zip(rv["path"], rv["path"][1:]):
                    if b not in [v for v, _, _ in adj[a]]: err(tag + " rival %s step %s→%s not a link" % (rv["id"], a, b))
                bt = rv.get("meet", {}).get("battle")
                if bt and bt["level"] > bl - 2: err(tag + " rival %s battle level" % rv["id"])
                if bt: tpl_ok(bt["template"], bt)
        boss_trail.append((mp["segment"], ch, sorted(set(lv_boss)), sh))
        # frames / spacing
        fr_ids = [f["id"] for f in sh.get("frames", [])]
        if not fr_ids: err(S("no frames"))
        for f in sh.get("frames", []):
            members = [n for n in sh["nodes"] if f["id"] in in_frame(sh, n)]
            pts = frame_positions(sh, f, members)
            for (a, pa), (b, pb) in itertools.combinations(pts.items(), 2):
                d = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
                if d < 40: err(S("frame %s: %s and %s only %.0f px apart" % (f["id"], a, b, d)))
                elif d < 52: warn(S("frame %s: %s and %s %.0f px apart" % (f["id"], a, b, d)))
            for k, p in pts.items():
                if not (20 <= p[0] <= 1900 and 20 <= p[1] <= 1060): err(S("frame %s: %s off screen at %s" % (f["id"], k, tuple(int(v) for v in p))))
        for n in sh["nodes"]:
            for fid in in_frame(sh, n):
                if fid not in fr_ids: err(S("%s in unknown frame %s" % (n["id"], fid)))
    return ids_seen


def check_level_trail(trail, err, warn):
    by_seg = collections.defaultdict(list)
    for seg, ch, lv, sh in trail:
        by_seg[seg].append((ch, lv))
    for seg, rows in by_seg.items():
        prev = 0
        for ch, lv in rows:
            if not lv: continue
            if min(lv) <= prev: err("levels %s/%s: boss L%s not above previous chapter's L%d" % (seg, ch, lv, prev))
            prev = max(lv)
    if by_seg.get("trunk") and by_seg.get("conquest"):
        t_last = max(by_seg["trunk"][-1][1])
        c_first = min(by_seg["conquest"][0][1])
        if c_first < t_last + 2: err("levels: conquest first boss L%d < trunk last boss L%d + 2" % (c_first, t_last))
