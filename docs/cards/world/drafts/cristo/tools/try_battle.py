#!/usr/bin/env python3
# Quick iteration harness: python3 -I try_battle.py <template_id> [L ...]
import copy, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import battle_lib as B
import battle_sim as S
from cristo_enemies import E
from cristo_templates import T
from cristo_uses import PLANS, ROSTERS, levels_of


def prep(tid):
    t = copy.deepcopy(T[tid])
    t["_routes"] = {k: B.expand_route(v) if isinstance(v, str) else v for k, v in t["routes"].items()}
    return t


def run(tid, L, plan, roster_key, weather=None, hero=True, trace=False, boss_mod=None, cp_bonus=0, passive=False):
    t = prep(tid)
    comp, troops = ROSTERS[roster_key](L)
    roster = S.ref_roster(L, comp, troops)
    sim = S.Sim(t, E, L, roster, plan, weather=weather, hero_enabled=hero, trace=trace, boss_mod=boss_mod, cp_bonus=cp_bonus)
    if passive:  # ARCH A4: "only press fight" / "only the hero" -> no cards, no skills
        sim.use_cards = False
        sim.use_skills = False
    res = sim.run()
    return res, sim


def hero_best(tid, L):
    """hero alone on every standable cell x 4 facings: report the best outcome (a win here is a template bug)"""
    t = prep(tid)
    best = None
    for r in range(len(t["map"])):
        for c in range(len(t["map"][0])):
            st = B.TERRAIN[t["map"][r][c]][1]
            if st not in ("ground", "high"):
                continue
            for f in ("right", "left", "up", "down"):
                try:
                    res, _ = run(tid, L, [{"t": 1, "deploy": "hero", "at": B.label(c, r), "face": f}], PLANS[tid]["roster"], passive=True)
                except ValueError:
                    continue
                key = (res["outcome"] == "victory", res["morale"], res["turn"])
                if best is None or key > best[0]:
                    best = (key, res, B.label(c, r) + ":" + f)
    r = dict(best[1])
    r["kind"] = (r["kind"] or "") + "@" + best[2]
    return r


def main():
    tid = sys.argv[1]
    t = prep(tid)
    errs, warns = B.validate(tid, copy.deepcopy(T[tid]), E)
    print("validate:", errs or "ok")
    Ls = [int(x) for x in sys.argv[2:]] or levels_of(tid)
    for L in Ls:
        idle, _ = run(tid, L, [], PLANS[tid]["roster"], hero=False, passive=True)
        hero_only = hero_best(tid, L)
        res, sim = run(tid, L, PLANS[tid]["plan"], PLANS[tid]["roster"], trace="-v" in os.environ.get("TRACE", ""), cp_bonus=PLANS[tid].get("cp_bonus", 0))
        c = B.counts(t, E, L)
        print("L%d idle=%s/%s t%d m%d | hero_only=%s/%s t%d m%d | plan=%s" % (L, idle["outcome"], idle["kind"], idle["turn"], idle["morale"],
              hero_only["outcome"], hero_only["kind"], hero_only["turn"], hero_only["morale"], json.dumps(res, ensure_ascii=False)))
        print("    counts", c)
        if os.environ.get("TRACE"):
            print("\n".join(sim.log))


if __name__ == "__main__":
    main()
