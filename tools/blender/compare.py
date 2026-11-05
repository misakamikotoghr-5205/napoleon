#!/usr/bin/env python3
# Side-by-side sheet for the owner's final check: the image the game uses now for a manifest id
# (human layer, else AI layer, else placeholder) next to a new one, enlarged, plus both at 1x below.
#   python3 tools/blender/compare.py <art id> <new.png> <sheet.png> [--scale N]
# Do not use this while composing a scene with an AI operator (BLENDER_PIPELINE.md red line 2).
import argparse
import json
import os

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MANIFEST = os.path.join(REPO, "data", "cards", "art", "manifest.json")


def current(art_id, fallback_size):
    """(path or None, base size) for an id; warns and falls back when the repo data is not there."""
    if not os.path.isfile(MANIFEST):
        print("WARNING: %s not found (not a full repo checkout); left panel stays empty" % MANIFEST)
        return None, list(fallback_size)
    entry = json.load(open(MANIFEST, encoding="utf-8"))["art"].get(art_id)
    if entry is None:
        print("WARNING: %s is not in the manifest; left panel stays empty" % art_id)
        return None, list(fallback_size)
    for key in ("human", "ai", "placeholder"):
        p = entry.get(key)
        if p and os.path.isfile(os.path.join(REPO, p)):
            return os.path.join(REPO, p), entry["base"]
    return None, entry["base"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("art_id")
    ap.add_argument("new")
    ap.add_argument("sheet")
    ap.add_argument("--scale", type=int, default=0, help="zoom, default 2 for images >=160 px wide, else 5")
    a = ap.parse_args()
    new = Image.open(a.new).convert("RGB")
    cur, base = current(a.art_id, new.size)
    if list(new.size) != list(base):
        print("WARNING: new image is %dx%d, manifest base is %dx%d" % (new.size + tuple(base)))
    s = a.scale or (2 if base[0] >= 160 else 5)
    old = Image.open(cur).convert("RGB") if cur else Image.new("RGB", tuple(base), (255, 0, 255))
    w, h = base[0] * s, base[1] * s
    sheet = Image.new("RGB", (2 * w + 24, h + base[1] + 32), (246, 240, 228))
    sheet.paste(old.resize((w, h), Image.NEAREST), (8, 8))
    sheet.paste(new.resize((w, h), Image.NEAREST), (w + 16, 8))
    sheet.paste(old, (8, h + 24))
    sheet.paste(new, (w + 16, h + 24))
    sheet.save(a.sheet)
    print("WROTE", a.sheet, "left:", os.path.relpath(cur, REPO) if cur else "(none)", "right:", a.new)


main()
