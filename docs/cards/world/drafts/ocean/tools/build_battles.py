#!/usr/bin/env python3
# Builds wm/ocean/ocean_battles.json from ocean_enemies.py + ocean_templates.py + ocean_uses.py.
# Every template is validated against the ARCH §4.2 terrain table (battle_lib.validate), simulated
# "nobody deployed" at each level it is used at, and checked against the ARCH §3.1–3.3 level rules.
# Usage: python3 -I build_battles.py [--report]      (exit code 1 when any error is found)
import json, os, sys, copy
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import battle_lib as B
from ocean_enemies import ENEMIES
from ocean_templates import TEMPLATES
from ocean_uses import SCENE_BATTLES, CHAPTER_BOSS, SCENE_CHAPTER, MAP_BATTLES, BATTLE_POOL, PLANS

OUT = os.path.join(os.path.dirname(HERE), "ocean_battles.json")
KIND_OF_SCALE = {"skirmish": "battle", "elite": "elite", "major": "boss", "grand": "boss", "epic": "boss"}


def band_of(L):
    return (13, 18) if L <= 18 else (19, 24)


def uses_of(tid):
    out = []
    for sid, sb in SCENE_BATTLES.items():
        for key, b in (("scene", sb), ("scene_fallback", sb.get("_fallback"))):
            if b and b.get("template") == tid:
                out.append({"use": key, "scene": sid, "chapter": SCENE_CHAPTER[sid], "level": b["level"]})
    if tid in MAP_BATTLES:
        m = MAP_BATTLES[tid]
        out.append({"use": "map_node", "chapter": m["sheet"], "node": m["node"], "level": m["level"]})
    for band, lst in BATTLE_POOL["ocean"].items():
        if tid in lst:
            lo, hi = [int(x) for x in band.split("-")]
            out.append({"use": "pool", "band": band, "level": lo, "level_max": hi})
    return out


def level_rule_errors(tid, t, uses):
    errs = []
    kind = KIND_OF_SCALE[t["scale"]]
    if kind != t["node"]:
        errs.append("scale %s is a %s, template says node %s" % (t["scale"], kind, t["node"]))
    b = int(t.get("base_level", t["level"]))
    for u in uses:
        L = u["level"]
        hi = u.get("level_max", L)
        if "base_level" in t:
            if not (b <= L and hi <= b + 11):
                errs.append("%s: levels %d..%d outside the pad range %d..%d" % (u["use"], L, hi, b, b + 11))
        elif L < b:
            errs.append("%s: used at L%d below its design level L%d" % (u["use"], L, b))
        if L < 13:
            errs.append("%s: ocean branch battles start at L13 (trunk ends at L12)" % u["use"])
        ch = u.get("chapter")
        if ch:
            boss = CHAPTER_BOSS[ch]
            if kind == "boss" and L != boss:
                errs.append("%s: boss of %s must be L%d, got L%d" % (u["use"], ch, boss, L))
            if kind == "elite" and L > boss - 1:
                errs.append("%s: elite L%d > boss-1 (%d) in %s" % (u["use"], L, boss - 1, ch))
            if kind == "battle" and L > boss - 2:
                errs.append("%s: battle L%d > boss-2 (%d) in %s" % (u["use"], L, boss - 2, ch))
        size = tuple(t["size"])
        for LL in sorted({L, hi}):
            if size not in B.SIZE_BAND[kind][band_of(LL)]:
                errs.append("%s: size %dx%d not in ARCH §3.3 band for %s at L%d %s" % (u["use"], size[0], size[1], kind, LL, B.SIZE_BAND[kind][band_of(LL)]))
    return errs


def analyse(tid, t, uses):
    errs, warns = B.validate(tid, t, ENEMIES)
    if errs:
        return {"errors": errs}
    errs = level_rule_errors(tid, t, uses)
    kind = t["node"]
    t["_reserved"] = set(w["at"] for w in t["waves"] if "at" in w)
    levels = sorted({u["level"] for u in uses} | ({int(t["base_level"]) + d for d in (0, 3, 6, 9)} if "base_level" in t else set()))
    levels = [L for L in levels if 13 <= L <= 24] or [int(t["level"])]
    res = {"levels": {}, "routes": B.coverage(t), "warnings": [], "errors": errs}
    for L in levels:
        row = B.LEVELS[L]
        want_h = {"boss": row[4], "elite": row[6], "battle": row[7]}[kind]
        want_turns = {"boss": row[8], "elite": row[9], "battle": row[10]}[kind]
        c = B.counts(t, ENEMIES, L)
        outcome, turn, loss, tl = B.simulate_idle(t, ENEMIES, L, t.get("weather", "clear"))
        mor = max(1, t["enemy_morale"] * row[1] // 100)
        entry = dict(c)
        entry.update({"stars": row[11], "enemy_morale": mor, "kill_value_pct_of_morale": c["kill_value"] * 100 // mor,
                      "idle": "%s on turn %d (eagle loss %d)" % (outcome, turn, loss),
                      "idle_first_leak_turn": tl[0][0] if tl else None})
        if c["hunters"] < want_h:
            res["warnings"].append("L%d hunters %d < target %d" % (L, c["hunters"], want_h))
        if kind == "boss" and c["elites"] < row[5]:
            res["warnings"].append("L%d boss elites %d < target %d" % (L, c["elites"], row[5]))
        if t["turn_limit"] != want_turns:
            res["warnings"].append("turn_limit %d != target %d at L%d" % (t["turn_limit"], want_turns, L))
        if outcome != "defeat":
            res["errors"].append("L%d: doing nothing does NOT lose (%s)" % (L, entry["idle"]))
        elif tl and tl[0][0] <= 2:
            res["warnings"].append("L%d: first leak on turn %d (too early to deploy)" % (L, tl[0][0]))
        res["levels"]["L%d" % L] = entry
    for rid, cv in res["routes"].items():
        if cv["blockable"] == 0:
            res["errors"].append("route %s has no cell we can block" % rid)
    if tid not in PLANS:
        res["warnings"].append("no reference plan")
    return res


def boss_curve(report):
    """ARCH §3.6 A5: along the play order each chapter boss has >= 112% of the previous boss' enemy power."""
    order = ["prologue", "scene05", "scene09", "finale"]
    out, prev = [], None
    for sid in order:
        sb = SCENE_BATTLES[sid]
        a = report[sb["template"]]
        p = a["levels"]["L%d" % sb["level"]]["power"]
        ok = prev is None or p * 100 >= prev * 112
        out.append({"scene": sid, "template": sb["template"], "level": sb["level"], "enemy_power": p, "ok": ok})
        prev = p
    return out


def main():
    out_t, report = {}, {}
    bad = False
    for tid, t in TEMPLATES.items():
        t = copy.deepcopy(t)
        uses = uses_of(tid)
        a = analyse(tid, t, uses)
        report[tid] = a
        bad = bad or bool(a.get("errors"))
        clean = {k: v for k, v in t.items() if not k.startswith("_") and k != "node"}
        clean["routes"] = {k: B.expand_route(v) for k, v in t["routes"].items()}
        clean["plan"] = PLANS.get(tid, "")
        meta = {"node": t["node"], "uses": uses, "analysis": a}
        out_t[tid] = {"template": clean, "meta": meta}
    curve = boss_curve(report) if not bad else []
    if any(not c["ok"] for c in curve):
        bad = True
    doc = {
        "_doc": "远洋分支（海底两万里）的战斗草稿。enemies 是 battle_rules.gd ENEMIES 形状（L1 基线，运行时按 ARCH §3.2 等级表缩放；src=arch 表示 ARCH §5 原表，trunk/cristo 表示沿用那两段的同名敌人，new 是本稿新增）。"
                "templates[id].template 是 battle_templates.json 形状加 ARCH §3/§4 的扩展键（size、level、base_level、pad、weather、新地形字符、on-cell 事件、lv_min）；"
                "plan 是参考解法（证明打得过）；meta.uses 是在拿破仑书里的用处和等级，meta.analysis 是 tools/build_battles.py 的校验结果（什么都不做必输、猎官数、回合数、敌战力）。"
                "scene_battles 直接进 book.json 的 segments.ocean.scene_battles；template 为空表示这一场在拿破仑书里不打仗（需要 A 支持，否则用 _fallback）。",
        "enemies": {k: {kk: vv for kk, vv in v.items() if kk not in ("src", "note")} for k, v in ENEMIES.items()},
        "enemy_notes": {k: {"src": v.get("src", ""), "note": v.get("note", "")} for k, v in ENEMIES.items()},
        "new_tags_used": sorted({tg for v in ENEMIES.values() for tg in v["tags"]} - {"hunter", "heavy", "officer", "execute"}),
        "templates": out_t,
        "scene_battles": SCENE_BATTLES,
        "map_battles": MAP_BATTLES,
        "battle_pool": BATTLE_POOL,
        "chapter_boss_levels": CHAPTER_BOSS,
        "boss_curve": curve,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    if "--report" in sys.argv or bad:
        for tid, a in report.items():
            print("==", tid, [u["use"] + ":" + str(u["level"]) for u in uses_of(tid)])
            for e in a.get("errors", []):
                print("  ERR", e)
            if "levels" not in a:
                continue
            for L, e in a["levels"].items():
                print("  ", L, {k: e[k] for k in ("enemies", "enemy_hp_total", "hunters", "elites", "power", "enemy_morale", "kill_value_pct_of_morale", "idle", "idle_first_leak_turn")})
            for w in a["warnings"]:
                print("  WARN", w)
        print("boss curve", curve)
    print("wrote", OUT, "errors" if bad else "ok")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
