#!/usr/bin/env python3
# Applies wm/ocean/ocean_scenes_rewrite.json to a COPY of the repo's data/campaigns/ocean_pawn.json
# (written to wm/ocean/out/ocean_pawn.json; the repo is never touched) and proves the rewrite is text-only:
#   1. every non-text key is byte-identical to the baseline (ids, numbers, flags, effects, advance, requires_*)
#   2. paragraph counts per scene are unchanged (vn_cast.json indexes paragraphs)
#   3. the VN speaker parse (vn_script.gd rules, aliases from vn_cast.json) matches the declared `speakers`
#   4. the anti-regression word list (ARCH §6.11 + a few more) has zero hits in all player-visible text,
#      including other_text, ocean_events.json and ocean_art_requests.json when present
#   5. the prologue chapter title and scene title stay "the same sentence" (test_vn.gd 370/374, HubData.same_title)
# Usage: python3 -I apply_rewrite.py           (exit 1 on any failure)
import json, os, sys, copy, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = "/home/user/dehoudang"
SRC = os.path.join(REPO, "data/campaigns/ocean_pawn.json")
CAST = os.path.join(REPO, "data/hd/vn_cast.json")
REWRITE = os.path.join(ROOT, "ocean_scenes_rewrite.json")
OUTDIR = os.path.join(ROOT, "out")
EXTRA = [os.path.join(ROOT, "ocean_events.json"), os.path.join(ROOT, "ocean_art_requests.json"), os.path.join(ROOT, "book_ocean.json")]

# ARCH §6.11 word list, plus words that are pawnshop-only in this setting
BANNED = ["当铺", "典当", "当票", "流当", "估值铺", "掌柜", "挂牌", "柜台", "活当", "收当", "盘库", "鉴定", "营业", "经营须知",
          "当物", "赎当", "账房", "押当", "典押", "估值"]
TEXT_KEYS = {"title", "location", "body", "label", "observation", "name", "description", "role", "currency_name"}
SAY_VERBS = None
QUOTES = {"“": "”", "「": "」"}


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def aliases(cast):
    out = []
    for cid, row in cast["chars"].items():
        for a in row.get("aliases", []):
            out.append((a, cid))
    out.sort(key=lambda x: (-len(x[0]), x[0]))
    return out


def speaker(s, al, verbs):
    for alias, who in al:
        if not s.startswith(alias):
            continue
        after = s[len(alias):]
        for v in [""] + verbs:
            if not after.startswith(v):
                continue
            r = after[len(v):]
            if len(r) < 3 or r[0] != "：" or r[1] not in QUOTES:
                continue
            close = QUOTES[r[1]]
            end = r.find(close, 2)
            if end < 0:
                continue
            said = r[2:end].strip()
            if not said:
                continue
            return {"who": who, "text": said, "rest": r[end + 1:]}
    return None


def parse_paragraph(text, al, verbs):
    lines = []
    rest = text.strip()
    guard = 0
    while rest and guard < 12:
        guard += 1
        m = speaker(rest, al, verbs)
        if not m:
            break
        lines.append(("say", m["who"]))
        rest = m["rest"].strip()
    if rest:
        lead = next((who for a, who in al if rest.startswith(a)), "")
        lines.append(("narr", lead if lead and any(q in rest for q in QUOTES) else ""))
    return lines


def declared(lines):
    """first line -> speakers notation"""
    if not lines:
        return ""
    kind, who = lines[0]
    if kind == "say":
        return who
    return ("@" + who) if who else ""


def walk_text(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k.startswith("_"):
                continue
            yield from walk_text(v, path + "." + k)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_text(v, "%s[%d]" % (path, i))
    elif isinstance(obj, str):
        yield path, obj


def strip_text(obj):
    """copy without the text-bearing keys, for the mechanics comparison"""
    if isinstance(obj, dict):
        return {k: strip_text(v) for k, v in obj.items() if k not in TEXT_KEYS and k != "design_notes"}
    if isinstance(obj, list):
        return [strip_text(v) for v in obj]
    return obj


def same_title(a, b):
    p = re.compile(r"[\s·：:，,。.！!？?、—\-（）()《》“”\"']")
    return p.sub("", a) == p.sub("", b)


def main():
    base = load(SRC)
    rw = load(REWRITE)
    cast = load(CAST)
    al = aliases(cast)
    verbs = list(cast.get("say_verbs", []))
    errs, notes = [], []
    out = copy.deepcopy(base)
    out["title"] = rw["title"]
    for ch in out["chapters"]:
        for k, v in rw["chapters"].get(ch["id"], {}).items():
            ch[k] = v
    for c in out["characters"]:
        for k, v in rw["characters"].get(c["id"], {}).items():
            c[k] = v
    for it in out["items"]:
        r = rw["items"].get(it["id"])
        if not r:
            errs.append("item %s not rewritten" % it["id"])
            continue
        it.update(r)
    vn_report = {}
    for s in out["scenes"]:
        sid = s["id"]
        r = rw["scenes"].get(sid)
        if not r:
            errs.append("scene %s not rewritten" % sid)
            continue
        if len(r["body"]) != len(s["body"]):
            errs.append("%s: %d paragraphs, baseline has %d (vn_cast indexes paragraphs)" % (sid, len(r["body"]), len(s["body"])))
        s["title"], s["location"], s["body"] = r["title"], r["location"], list(r["body"])
        ids = {a["id"] for a in s["appraisals"]}
        if set(r["appraisals"]) != ids:
            errs.append("%s: appraisal ids differ %s vs %s" % (sid, sorted(r["appraisals"]), sorted(ids)))
        for a in s["appraisals"]:
            a.update(r["appraisals"].get(a["id"], {}))
        cids = {c["id"] for c in s["choices"]}
        if set(r["choices"]) != cids:
            errs.append("%s: choice ids differ" % sid)
        for c in s["choices"]:
            c.update(r["choices"].get(c["id"], {}))
        parsed = [parse_paragraph(p, al, verbs) for p in s["body"]]
        got = [declared(x) for x in parsed]
        if got != r.get("speakers"):
            errs.append("%s: speakers %s, declared %s" % (sid, got, r.get("speakers")))
        vn_report[sid] = [[list(l) for l in x] for x in parsed]
        spec = cast["scenes"].get(sid, {})
        for key in ("enter", "exit", "expr"):
            for para in spec.get(key, {}):
                if int(para) >= len(s["body"]):
                    errs.append("%s: vn_cast %s at paragraph %s is past the end" % (sid, key, para))
        for b in spec.get("bg", []):
            if isinstance(b.get("at"), int) and b["at"] >= len(s["body"]):
                errs.append("%s: vn_cast bg at %s is past the end" % (sid, b["at"]))
    for e in out["endings"]:
        r = rw["endings"].get(e["id"])
        if not r:
            errs.append("ending %s not rewritten" % e["id"])
            continue
        e.update(r)
        if "同盟" not in "".join(e["body"]):
            notes.append("ending %s does not mention 同盟 (test_ui.gd:177)" % e["id"])
    if len(rw["design_notes"]) != len(base["design_notes"]):
        errs.append("design_notes count changed")
    out["design_notes"] = list(rw["design_notes"])
    # 1. mechanics identical
    if json.dumps(strip_text(out), sort_keys=True, ensure_ascii=False) != json.dumps(strip_text(base), sort_keys=True, ensure_ascii=False):
        errs.append("non-text content differs from the baseline")
    # 5. prologue title rule
    pro_ch = next(c for c in out["chapters"] if c["id"] == "prologue")["title"]
    pro_sc = next(s for s in out["scenes"] if s["id"] == "prologue")["title"]
    if not same_title(pro_ch, pro_sc):
        errs.append("prologue chapter title and scene title are no longer the same sentence")
    if parse_paragraph(next(s for s in out["scenes"] if s["id"] == "prologue")["body"][0], al, verbs)[0] != ("narr", ""):
        errs.append("prologue paragraph 0 must be plain narration (test_vn.gd)")
    if "贝勒罗丰号底舱" not in pro_sc + next(s for s in out["scenes"] if s["id"] == "prologue")["location"]:
        errs.append("prologue location must keep 贝勒罗丰号底舱 (test_vn.gd 372)")
    # 4. banned words
    sources = [("ocean_pawn.json", out), ("rewrite.other_text", rw["other_text"])]
    for p in EXTRA:
        if os.path.exists(p):
            sources.append((os.path.basename(p), load(p)))
        else:
            notes.append("not scanned (missing): %s" % os.path.basename(p))
    hits = []
    for name, doc in sources:
        for path, text in walk_text(doc):
            for w in BANNED:
                if w in text:
                    hits.append("%s%s: %s" % (name, path, w))
    if hits:
        errs.extend("banned word " + h for h in hits)
    os.makedirs(OUTDIR, exist_ok=True)
    with open(os.path.join(OUTDIR, "ocean_pawn.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(os.path.join(OUTDIR, "vn_lines.json"), "w", encoding="utf-8") as f:
        json.dump({"_doc": "VN 规则解析出的每段句子：[kind, who]；say = 有名字牌的台词，narr 带 who = 镜头给这个人的旁白",
                   "scenes": vn_report}, f, ensure_ascii=False, indent=1)
    for n in notes:
        print("NOTE", n)
    for e in errs:
        print("ERR", e)
    print("wrote", os.path.join(OUTDIR, "ocean_pawn.json"), "errors" if errs else "ok (text-only, %d banned words, 0 hits)" % len(BANNED))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
