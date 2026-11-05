#!/usr/bin/env python3
"""Art-manifest coverage check (K12). Standard library only.

    python3 tools/cards/art/check_manifest.py [--refs=error|note]

Scans merged card data and scripts/cards for art ids, then checks
data/cards/art/manifest.json. 1.3 also scans a play block (`stage`):
props[].art, set → bg.<set> (counter → the three counter backdrops),
cast standing at customer/companion → portrait.<who>, extras at the
door or on the street → walk.<who>. Script literals add prop/walk/stage.

* ART MISSING <id> (referenced by <file>)  — unknown id
* ART NOFILE <id> <path>                    — placeholder path missing
* ART SIZE <id> <actual> != <base>          — PNG size != base
* ART CHECK OK <n> ids, <bytes> bytes
* ART CHECK FAILED ...

Missing references fail the process only when --refs=error (the default).
A missing file, a size mismatch, a bad stamp, or a placeholder total over 20 MB
always exits 1. --refs=note prints ART MISSING lines and still exits 0 when
nothing else is wrong (CI stays green while other lines add ids).

Contract: docs/cards/CARDS_INTERFACES.md section 4.8, section 11.2, section 12.4.
"""

import argparse
import os
import re
import sys
import zlib

import art_common as ac

ART_RE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$")
LIT_RE = re.compile(
    r"""["']((?:bg|icon|frame|wheel|portrait|illus|item|prop|walk|stage)\.[A-Za-z0-9_.]+)["']"""
)
# Quoted filenames are not art ids ("stage.json" lives next to real stage.<person> ids).
LIT_SKIP_SUFFIX = (".json", ".png", ".gd", ".tscn", ".import", ".txt", ".md", ".ogg", ".uid", ".csv")
SKIP_DIRS = {"_examples", "text"}
# Play-block spots (contract section 4.7.24 / V42). Door includes the pair.
_PLAY_KEYS = {"set", "cast", "props", "intro", "after", "fx", "walk"}
_STAND_AT = {"customer", "companion"}
_DOOR_AT = {"door", "door_l", "door_r", "street"}
_COUNTER_BG = ("bg.counter.day", "bg.counter.dusk", "bg.counter.night")


def add_ref(refs, art_id, source):
    if not art_id or art_id in ac.NOT_ART:
        return
    if not ART_RE.match(art_id):
        return
    refs.setdefault(art_id, set()).add(source)


def _is_play_block(val):
    return isinstance(val, dict) and any(k in val for k in _PLAY_KEYS)


def _scan_play(block, rel, refs):
    """Art ids a stage block needs. Does not treat the walk *field* as an id.

    set counter → the three counter backdrops; any other set → bg.<set>.
    props[].art as written. customer/companion → portrait.<who>.
    An extra (ex_*) at the door or on the street → walk.<who>.
    A named character with no walk sprite is not an error (the scene falls
    back to the portrait). stage.<person> is not required.
    """
    set_name = block.get("set")
    if isinstance(set_name, str) and set_name != "":
        if set_name == "counter":
            for bg_id in _COUNTER_BG:
                add_ref(refs, bg_id, rel)
        else:
            add_ref(refs, "bg." + set_name, rel)
    props = block.get("props")
    if isinstance(props, list):
        for prop in props:
            if isinstance(prop, dict) and isinstance(prop.get("art"), str):
                add_ref(refs, prop["art"], rel)
    cast = block.get("cast")
    if isinstance(cast, list):
        for member in cast:
            if not isinstance(member, dict):
                continue
            who = member.get("who")
            at = member.get("at")
            if not isinstance(who, str) or who == "":
                continue
            if at in _STAND_AT:
                add_ref(refs, "portrait." + who, rel)
            if who.startswith("ex_") and at in _DOOR_AT:
                add_ref(refs, "walk." + who, rel)


def _walk_json(node, rel, refs, filename):
    if isinstance(node, dict):
        for key in sorted(node.keys(), key=str):
            if str(key).startswith("_"):
                continue
            val = node[key]
            if key == "art" and isinstance(val, str):
                add_ref(refs, val, rel)
            elif key == "portrait" and isinstance(val, str):
                add_ref(refs, val if val.startswith("portrait.") else "portrait." + val, rel)
            elif key == "bg" and filename == "stage.json" and isinstance(val, str):
                add_ref(refs, val, rel)
            elif key == "teacher" and rel.endswith("guide/steps.json") and isinstance(val, str):
                if val == "":
                    continue
                if val.startswith("obj."):
                    add_ref(refs, "icon." + val, rel)
                else:
                    add_ref(refs, "portrait." + val, rel)
            elif key == "stage" and _is_play_block(val):
                _scan_play(val, rel, refs)
                _walk_json(val, rel, refs, filename)
            else:
                _walk_json(val, rel, refs, filename)
    elif isinstance(node, list):
        for item in node:
            _walk_json(item, rel, refs, filename)


def _templates_extra(node, rel, refs):
    cats = node.get("categories", {})
    if not isinstance(cats, dict):
        return
    for cat in sorted(cats.keys(), key=str):
        block = cats[cat]
        if not isinstance(block, dict):
            continue
        for variant in block.get("variants", []):
            if isinstance(variant, dict) and variant.get("id"):
                add_ref(refs, "item.%s.%s" % (cat, variant["id"]), rel)


def scan_data(refs):
    root = os.path.join(ac.ROOT, "data", "cards")
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            if not name.endswith(".json"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, ac.ROOT).replace("\\", "/")
            if rel == ac.DATA_MANIFEST:
                continue
            try:
                data = ac.load_json(full)
            except ValueError:
                continue
            _walk_json(data, rel, refs, name)
            if name == "templates_extra.json":
                _templates_extra(data, rel, refs)


def scan_scripts(refs):
    root = os.path.join(ac.ROOT, "scripts", "cards")
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            if not name.endswith(".gd"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, ac.ROOT).replace("\\", "/")
            text = open(full, encoding="utf-8").read()
            for match in LIT_RE.finditer(text):
                lit = match.group(1)
                if "%" in lit or lit.endswith(LIT_SKIP_SUFFIX):
                    continue
                add_ref(refs, lit, rel)


def required_ids(refs):
    for kind in ac.FRAME_TYPES:
        add_ref(refs, "frame." + kind, "card-types")
    add_ref(refs, "frame.gold", "card-types")
    for art_id in ac.GUIDE_IDS:
        add_ref(refs, art_id, "guide-required")


def _badge_ok(path, expect):
    try:
        _w, _h, rows = ac.read_png_rgba(path)
    except (ValueError, OSError, zlib.error):
        return False
    side = len(expect)
    if len(rows) < side or len(rows[0]) < side * 4:
        return False
    for y in range(side):
        row = rows[y]
        for x in range(side):
            i = x * 4
            if tuple(row[i:i + 4]) != expect[y][x]:
                return False
    return True


def check(refs_mode):
    manifest = ac.load_json(os.path.join(ac.ROOT, ac.DATA_MANIFEST))
    art = manifest.get("art", {})
    refs = {}
    scan_data(refs)
    scan_scripts(refs)
    required_ids(refs)

    problems = 0
    for art_id in sorted(refs):
        if art_id in art:
            continue
        for src in sorted(refs[art_id]):
            print("ART MISSING %s (referenced by %s)" % (art_id, src))
        if refs_mode == "error":
            problems += 1

    pal = ac.load_palette()
    seen_paths = {}
    total = 0

    def take(path):
        nonlocal total
        path = path.replace("\\", "/")
        if path in seen_paths:
            return seen_paths[path]
        full = os.path.join(ac.ROOT, path.replace("/", os.sep))
        if os.path.isfile(full):
            size = os.path.getsize(full)
            seen_paths[path] = size
            total += size
            return size
        seen_paths[path] = None
        return None

    for art_id in sorted(art):
        entry = art[art_id]
        rel = str(entry.get("placeholder", "")).replace("\\", "/")
        base = entry.get("base") or [0, 0]
        if not rel or take(rel) is None:
            print("ART NOFILE %s %s" % (art_id, rel))
            problems += 1
            continue
        full = os.path.join(ac.ROOT, rel.replace("/", os.sep))
        info = ac.png_ihdr(full)
        if info is None:
            print("ART SIZE %s ? != %sx%s" % (art_id, base[0], base[1]))
            problems += 1
            continue
        if info[2] != 8 or info[3] != 6:
            print("ART FORMAT %s %s not 8-bit RGBA" % (art_id, rel))
            problems += 1
        actual = "%dx%d" % (info[0], info[1])
        want = "%dx%d" % (int(base[0]), int(base[1]))
        if actual != want:
            print("ART SIZE %s %s != %s" % (art_id, actual, want))
            problems += 1
        if art_id.startswith("frame."):
            want_nine = ac.expected_nine(art_id)
            if entry.get("nine") != want_nine:
                print("ART NINE %s %s != %s" % (art_id, entry.get("nine"), want_nine))
                problems += 1
        if ac.is_generated_placeholder(rel):
            side = ac.badge_side(info[0], info[1])
            if not _badge_ok(full, ac.badge_pixels(pal, side)):
                print("ART BADGE %s %s" % (art_id, rel))
                problems += 1
            imp_full = full + ".import"
            imp_uid = ac.read_import_uid(imp_full)
            if not imp_uid or open(imp_full, encoding="utf-8").read() != ac.render_png_import(rel, imp_uid):
                print("ART IMPORT %s %s.import" % (art_id, rel))
                problems += 1

    missing_rel = str(manifest.get("missing", "")).replace("\\", "/")
    if not missing_rel or take(missing_rel) is None:
        print("ART NOFILE missing %s" % missing_rel)
        problems += 1
    else:
        full = os.path.join(ac.ROOT, missing_rel.replace("/", os.sep))
        info = ac.png_ihdr(full)
        if info is None or (info[0], info[1]) != ac.MISSING_SIZE or info[2] != 8 or info[3] != 6:
            print("ART SIZE missing %s != %dx%d" % (
                ("%dx%d" % (info[0], info[1])) if info else "?",
                ac.MISSING_SIZE[0], ac.MISSING_SIZE[1]))
            problems += 1
        if info is not None and not _badge_ok(full, ac.badge_pixels(pal, ac.badge_side(info[0], info[1]))):
            print("ART BADGE missing %s" % missing_rel)
            problems += 1
        imp_full = full + ".import"
        imp_uid = ac.read_import_uid(imp_full)
        if not imp_uid or open(imp_full, encoding="utf-8").read() != ac.render_png_import(missing_rel, imp_uid):
            print("ART IMPORT missing %s.import" % missing_rel)
            problems += 1

    man_rel = ac.PLACEHOLDER_MANIFEST
    man_full = os.path.join(ac.ROOT, man_rel.replace("/", os.sep))
    if not os.path.isfile(man_full):
        print("ART META missing %s" % man_rel)
        problems += 1
        listed = {}
    else:
        take(man_rel)
        doc = ac.load_json(man_full)
        if doc.get("generator") != ac.GENERATOR_NAME or doc.get("seed_rule") != ac.SEED_RULE:
            print("ART META generator/seed_rule mismatch")
            problems += 1
        if "version" not in doc:
            print("ART META version missing")
            problems += 1
        listed = doc.get("files", {})
        for art_id in sorted(art):
            entry = art[art_id]
            if entry.get("legacy"):
                continue
            rel = str(entry.get("placeholder", "")).replace("\\", "/")
            if not ac.is_generated_placeholder(rel):
                continue
            full = os.path.join(ac.ROOT, rel.replace("/", os.sep))
            if os.path.isfile(full) and listed.get(rel) != ac.sha256_file(full):
                print("ART HASH %s" % rel)
                problems += 1
        if missing_rel and os.path.isfile(os.path.join(ac.ROOT, missing_rel.replace("/", os.sep))):
            if listed.get(missing_rel) != ac.sha256_file(os.path.join(ac.ROOT, missing_rel.replace("/", os.sep))):
                print("ART HASH %s" % missing_rel)
                problems += 1

    if total > ac.LIMIT_BYTES:
        print("ART OVERSIZE %d > %d" % (total, ac.LIMIT_BYTES))
        problems += 1

    n = len(art)
    if problems:
        print("ART CHECK FAILED %d ids, %d bytes" % (n, total))
        return 1
    print("ART CHECK OK %d ids, %d bytes" % (n, total))
    return 0


def main(argv):
    p = argparse.ArgumentParser(description="K12 art manifest coverage check")
    p.add_argument("--refs", default="error", choices=("error", "note"))
    args = p.parse_args(argv)
    return check(args.refs)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
