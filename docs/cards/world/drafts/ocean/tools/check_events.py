#!/usr/bin/env python3
# Checks wm/ocean/ocean_events.json: ARCH §2.6 shape, forbidden keys (branch / ending / advance), metric / coin / prop ids,
# condition syntax, clue and flag references, and the VN speaker parse with aliases from vn_cast.json + new_characters.
# Usage: python3 -I check_events.py [--vn]      (exit 1 on any error)
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from apply_rewrite import parse_paragraph, declared
ROOT = os.path.dirname(HERE)
REPO = "/home/user/dehoudang"
METRICS = {"treasury", "morale", "heat", "vitality", "construction", "exploration"}
COINS = {"gold", "supply", "medal", "intel"}
PROPS = {"prop_loaded_dice", "prop_barricade", "prop_forced_march", "prop_spyglass", "prop_smoke_bomb", "prop_field_ration", "prop_bribe_pouch", "prop_imperial_decree"}
TROOPS = {"line", "grenadier", "jager", "hussar", "artillery"}
CHOICE_KEYS = {"id", "label", "requires_clues", "requires_flags", "requires", "effects", "rogue", "flags", "remove_flags", "items", "days", "battle", "reveal", "boss_mod"}
EVENT_KEYS = {"id", "pool", "weight", "once", "requires", "title", "location", "speaker", "date", "body", "appraisals", "choices", "_note",
              "questions", "offer", "pick_companions", "weight_by_trust"}
FORBIDDEN = {"branch", "ending", "advance"}
POOLS = {"fixed", "biscay_1815", "st_helena", "new_elba", "nautilus", "ocean", "interlude:audience", "interlude:camp_night", "interlude:bond", "interlude:minigame:ring"}
BOSS = {"st_helena": 16, "new_elba": 20, "nautilus": 24}


def main():
    doc = json.load(open(os.path.join(ROOT, "ocean_events.json"), encoding="utf-8"))
    cast = json.load(open(os.path.join(REPO, "data/hd/vn_cast.json"), encoding="utf-8"))
    al = [(a, cid) for cid, row in cast["chars"].items() for a in row.get("aliases", [])]
    al += [(a, cid) for cid, row in doc["new_characters"].items() if isinstance(row, dict) for a in row.get("aliases", [])]
    al.sort(key=lambda x: (-len(x[0]), x[0]))
    verbs = list(cast.get("say_verbs", []))
    known_people = set(cast["chars"]) | {k for k in doc["new_characters"] if not k.startswith("_")}
    errs, vn = [], {}
    ids, set_flags, need_flags = set(), set(), []
    for e in doc["events"]:
        eid = e["id"]
        if eid in ids:
            errs.append("duplicate %s" % eid)
        ids.add(eid)
        if not eid.startswith("ev_o_"):
            errs.append("%s: ocean event ids start with ev_o_" % eid)
        for k in e:
            if k not in EVENT_KEYS:
                errs.append("%s: unknown key %s" % (eid, k))
        if e["pool"] not in POOLS:
            errs.append("%s: unknown pool %s" % (eid, e["pool"]))
        if e["speaker"] not in known_people:
            errs.append("%s: speaker %s is not a VN character" % (eid, e["speaker"]))
        clues = {a["id"] for a in e.get("appraisals", [])}
        for a in e.get("appraisals", []):
            if a["kind"] not in ("spot", "weigh", "ring", "decode"):
                errs.append("%s: appraisal kind %s" % (eid, a["kind"]))
        if not e.get("choices") and not e.get("questions"):
            errs.append("%s: no choices" % eid)
        if e["pool"] not in ("fixed",) and not e["pool"].startswith("interlude:") and not (2 <= len(e["choices"]) <= 3):
            errs.append("%s: random events have 2-3 choices" % eid)
        free = 0
        for c in e.get("choices", []):
            for k in c:
                if k in FORBIDDEN:
                    errs.append("%s/%s: %s is forbidden in events (ARCH §2.6)" % (eid, c["id"], k))
                elif k not in CHOICE_KEYS:
                    errs.append("%s/%s: unknown choice key %s" % (eid, c["id"], k))
            for k in c.get("effects", {}):
                if k not in METRICS:
                    errs.append("%s/%s: unknown metric %s" % (eid, c["id"], k))
            r = c.get("rogue", {})
            for k in r:
                if k not in ("coins", "props", "recruit", "troops", "heal"):
                    errs.append("%s/%s: unknown rogue key %s" % (eid, c["id"], k))
            for k in r.get("coins", {}):
                if k not in COINS:
                    errs.append("%s/%s: unknown coin %s" % (eid, c["id"], k))
            for p in r.get("props", []):
                if p not in PROPS:
                    errs.append("%s/%s: unknown prop %s" % (eid, c["id"], p))
            for t in r.get("troops", []):
                if t not in TROOPS:
                    errs.append("%s/%s: unknown troop %s" % (eid, c["id"], t))
            for cl in c.get("requires_clues", []):
                if cl not in clues:
                    errs.append("%s/%s: clue %s not in this event" % (eid, c["id"], cl))
            for f in c.get("flags", []):
                if not f.startswith("o_"):
                    errs.append("%s/%s: new ocean flags start with o_ (%s)" % (eid, c["id"], f))
                set_flags.add(f)
            need_flags += [(eid, f) for f in c.get("requires_flags", [])]
            if "days" in c and not (isinstance(c["days"], int) and c["days"] >= 1):
                errs.append("%s/%s: days must be a positive int" % (eid, c["id"]))
            if not c.get("requires_clues") and not c.get("requires_flags") and not c.get("requires"):
                free += 1
            bm = c.get("boss_mod")
            if bm and e["pool"] != "fixed":
                errs.append("%s: boss_mod only in fixed council events" % eid)
        if e.get("choices") and free == 0:
            errs.append("%s: every choice is gated; one must always be open" % eid)
        for q in e.get("questions", []):
            for side in ("a", "b"):
                for k in q[side].get("effects", {}):
                    if k not in METRICS:
                        errs.append("%s/%s: unknown metric %s" % (eid, q["id"], k))
                for f in q[side].get("flags", []):
                    set_flags.add(f)
        for k, v in e.get("requires", {}).items():
            if k not in ("flags", "any_flags", "not_flags", "metric", "stat", "coins", "alive", "items", "count_flags", "scene_done", "hero_ok", "any", "not"):
                errs.append("%s: unknown condition %s" % (eid, k))
        vn[eid] = [declared(parse_paragraph(p, al, verbs)) for p in e["body"]]
        if e["speaker"] not in [x.lstrip("@") for x in vn[eid]] and e["speaker"] != "villefort":
            errs.append("%s: declared speaker %s never speaks or gets the focus (%s)" % (eid, e["speaker"], vn[eid]))
    for eid, f in need_flags:
        if f not in set_flags:
            errs.append("%s: requires flag %s that no ocean event sets" % (eid, f))
    rnd = [e for e in doc["events"] if e["pool"] not in ("fixed",) and not e["pool"].startswith("interlude:")]
    print("events: %d (random %d, fixed %d, interludes %d); flags set: %d" % (len(doc["events"]), len(rnd),
          sum(e["pool"] == "fixed" for e in doc["events"]), sum(e["pool"].startswith("interlude:") for e in doc["events"]), len(set_flags)))
    if "--vn" in sys.argv:
        for k, v in vn.items():
            print(" ", k, v)
    for e in errs:
        print("ERR", e)
    print("ok" if not errs else "errors")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
