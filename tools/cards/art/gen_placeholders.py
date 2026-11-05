#!/usr/bin/env python3
"""Deterministic placeholder art for the card game (K12).

    python3 tools/cards/art/gen_placeholders.py [--out=<root>] [--only=<id prefix>] [--check] [--sheet=<file>]

Same inputs produce byte-identical PNGs: each picture's RNG is random.Random(sha256(art_id)),
PNG is saved with a fixed compress level and no timestamp or color profile, and paths are sorted.
Every generated picture gets a top-left draft stamp (fixed bitmap, not a system font).
Colors are palette.dev.json keys. Does not read palette.json. Does not touch legacy files.

1.3 scene plates marked "K12 生成" are derived with Pillow from the old pictures
(read-only under art/bg, art/town, art/ui, art/tools). Sources are never written.
bg.stage.<year> is still drawn. bg.title and bg.street are legacy and are not drawn.
stage.<person> is not a manifest id.

Contract: docs/cards/CARDS_INTERFACES.md section 3.4 K12, section 11.2, section 12.4.
"""

import argparse
import hashlib
import json
import os
import random
import sys

import art_common as ac

CLEAR = (0, 0, 0, 0)


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def save_png(im, path):
    """8-bit RGBA, no ancillary chunks, fixed zlib level. Bytes depend only on pixels."""
    from PIL import Image

    clean = Image.frombytes("RGBA", im.size, im.convert("RGBA").tobytes())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    clean.save(path, format="PNG", optimize=False, compress_level=9)


def stamp(im, pal):
    side = ac.badge_side(im.size[0], im.size[1])
    pixels = ac.badge_pixels(pal, side)
    px = im.load()
    for y, row in enumerate(pixels):
        for x, col in enumerate(row):
            if x < im.size[0] and y < im.size[1]:
                px[x, y] = col


def _rect(d, box, fill):
    d.rectangle(box, fill=fill)


def _outline(d, box, col):
    d.rectangle(box, outline=col)


def draw_frame(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    kind = art_id.split(".", 1)[1]
    m = 6
    if kind == "guide_bubble":
        _rect(d, [0, 0, w - 1, h - 1], pal["guide_bubble"])
        _outline(d, [0, 0, w - 1, h - 1], pal["guide_ink"])
        _outline(d, [2, 2, w - 3, h - 3], pal["ink_soft"])
        _outline(d, [4, 4, w - 5, h - 5], pal["paper"])
        return
    if kind == "guide_note":
        # Opaque paper. Edges stay flat so the 6px nine-slice can stretch.
        _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
        _outline(d, [0, 0, w - 1, h - 1], pal["ink"])
        _outline(d, [2, 2, w - 3, h - 3], pal["ink_soft"])
        return
    if kind == "hero":
        _draw_hero_frame(d, w, h, pal, rng)
        return
    if kind == "gold":
        band = pal["gold_glow"]
        inner = pal["gold"]
    else:
        band = pal.get("frame_" + kind, pal["wood"])
        inner = band
    # Four margin strips. Center stays transparent so 9-slice can stretch it.
    _rect(d, [0, 0, w - 1, m - 1], band)
    _rect(d, [0, h - m, w - 1, h - 1], band)
    _rect(d, [0, 0, m - 1, h - 1], band)
    _rect(d, [w - m, 0, w - 1, h - 1], band)
    if kind == "gold":
        _rect(d, [2, 2, w - 3, m - 1], inner)
        _rect(d, [2, h - m, w - 3, h - 3], inner)
        _rect(d, [2, 2, m - 1, h - 3], inner)
        _rect(d, [w - m, 2, w - 3, h - 3], inner)
    _outline(d, [0, 0, w - 1, h - 1], pal["ink"])
    _outline(d, [m - 1, m - 1, w - m, h - m], pal["ink"])
    motif = rng.randrange(4)
    accent = pal["gold_glow"] if kind == "gold" else pal["lamp"]
    for cx, cy in ((1, 1), (w - 5, 1), (1, h - 5), (w - 5, h - 5)):
        _motif(d, cx, cy, motif, accent, pal["ink"])


def _motif(d, x, y, kind, accent, ink):
    if kind == 0:
        _rect(d, [x + 1, y + 1, x + 2, y + 2], accent)
    elif kind == 1:
        _rect(d, [x + 1, y, x + 2, y + 3], accent)
        _rect(d, [x, y + 1, x + 3, y + 2], accent)
    elif kind == 2:
        _outline(d, [x, y, x + 3, y + 3], accent)
        d.point((x + 1, y + 1), fill=ink)
    else:
        d.point((x + 1, y), fill=accent)
        d.point((x + 2, y), fill=accent)
        _rect(d, [x, y + 1, x + 3, y + 2], accent)
        d.point((x + 1, y + 3), fill=accent)
        d.point((x + 2, y + 3), fill=accent)


def _draw_hero_frame(d, w, h, pal, rng):
    """27×36 portrait frame. Center stays transparent. Margin 6 matches nine-slice."""
    m = 6
    band = pal["gold_glow"]
    inner = pal["gold"]
    _rect(d, [0, 0, w - 1, m - 1], band)
    _rect(d, [0, h - m, w - 1, h - 1], band)
    _rect(d, [0, 0, m - 1, h - 1], band)
    _rect(d, [w - m, 0, w - 1, h - 1], band)
    _rect(d, [2, 2, w - 3, m - 1], inner)
    _rect(d, [2, h - m, w - 3, h - 3], inner)
    _rect(d, [2, 2, m - 1, h - 3], inner)
    _rect(d, [w - m, 2, w - 3, h - 3], inner)
    _outline(d, [0, 0, w - 1, h - 1], pal["ink"])
    _outline(d, [m - 1, m - 1, w - m, h - m], pal["ink"])
    motif = rng.randrange(4)
    for cx, cy in ((1, 1), (w - 5, 1), (1, h - 5), (w - 5, h - 5)):
        _motif(d, cx, cy, motif, pal["lamp"], pal["ink"])


def draw_portrait(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
    for y in range(0, h, 4):
        if (y // 4 + rng.randrange(2)) % 2 == 0:
            _rect(d, [0, y, w - 1, y], pal["paper_old"])
    cloth = (pal["indigo"], pal["wood"], pal["jade"], pal["seal"], pal["wood_mid"])[rng.randrange(5)]
    d.polygon([(6, h - 1), (4, 40), (w - 5, 40), (w - 7, h - 1)], fill=cloth)
    collar = rng.randrange(4)
    if collar == 0:
        d.polygon([(18, 40), (24, 52), (30, 40)], fill=pal["ink"])
    elif collar == 1:
        _rect(d, [16, 36, 31, 44], pal["ink"])
    elif collar == 2:
        d.polygon([(10, 42), (24, 36), (38, 42), (34, 48), (14, 48)], fill=pal["seal"])
    else:
        _rect(d, [14, 38, 33, 46], pal["gold"])
        d.point((24, 42), fill=pal["lamp"])
    # Head and face. Face stays in paper/ink — no extra skin color.
    d.ellipse([12, 10, 35, 38], fill=pal["ink_soft"])
    d.ellipse([15, 14, 32, 36], fill=pal["paper_old"])
    hair = rng.randrange(6)
    _hair(d, hair, pal)
    d.point((19, 24), fill=pal["ink"])
    d.point((28, 24), fill=pal["ink"])
    _rect(d, [22, 28, 25, 29], pal["ink_soft"])
    # Shoulders outline so the bust reads at x2.
    d.line([(4, 40), (16, 36), (32, 36), (43, 40)], fill=pal["ink"])


def _hair(d, style, pal):
    ink = pal["ink"]
    if style == 0:
        d.pieslice([12, 8, 35, 28], 180, 360, fill=ink)
    elif style == 1:
        d.ellipse([18, 2, 30, 14], fill=ink)
        d.pieslice([12, 10, 35, 30], 180, 360, fill=ink)
    elif style == 2:
        d.polygon([(12, 18), (14, 8), (34, 8), (36, 20), (33, 40), (30, 18)], fill=ink)
    elif style == 3:
        _rect(d, [10, 12, 37, 18], pal["wood_dark"])
        d.polygon([(8, 18), (24, 8), (39, 18)], fill=pal["wood"])
    elif style == 4:
        d.pieslice([12, 8, 35, 28], 200, 360, fill=ink)
        _rect(d, [30, 20, 34, 46], ink)
    else:
        d.polygon([(10, 22), (24, 6), (38, 22), (34, 16), (24, 10), (14, 16)], fill=pal["mist"])
        d.pieslice([14, 12, 33, 26], 180, 360, fill=ink)


def draw_illus(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
    phase = rng.randrange(4)
    for y in range(phase, h, 3):
        _rect(d, [0, y, w - 1, y], pal["paper_old"])
    _rect(d, [0, 32, w - 1, h - 1], pal["mist"])
    _rect(d, [0, 36, w - 1, h - 1], pal["ink_soft"])
    prefix = art_id.split(".")[1] if "." in art_id else ""
    _illus_mark(d, w, h, prefix, pal, rng)
    _outline(d, [0, 0, w - 1, h - 1], pal["ink"])


def _illus_mark(d, w, h, prefix, pal, rng):
    ink = pal["ink"]
    accent = (pal["seal"], pal["gold"], pal["indigo"], pal["jade"])[rng.randrange(4)]
    cx, cy = w // 2, 20
    if prefix in ("ev", "fa", "bf"):
        d.polygon([(cx, 6), (cx + 10, 28), (cx - 10, 28)], fill=accent)
        d.polygon([(cx, 12), (cx + 5, 24), (cx - 5, 24)], fill=pal["paper"])
    elif prefix == "dm":
        _rect(d, [cx - 10, 8, cx + 10, 30], pal["paper"])
        _outline(d, [cx - 10, 8, cx + 10, 30], ink)
        _rect(d, [cx - 6, 14, cx + 6, 15], ink)
        _rect(d, [cx - 6, 19, cx + 4, 20], ink)
    elif prefix in ("nw", "kp", "tk"):
        _rect(d, [cx - 12, 10, cx + 8, 28], pal["paper_old"])
        d.polygon([(cx + 8, 10), (cx + 14, 16), (cx + 8, 16)], fill=accent)
        _outline(d, [cx - 12, 10, cx + 8, 28], ink)
    elif prefix in ("es", "st"):
        d.polygon([(cx, 8), (cx + 16, 20), (cx - 16, 20)], fill=accent)
        _rect(d, [cx - 10, 20, cx + 10, 32], pal["wood"])
    elif prefix == "nt":
        d.ellipse([cx - 8, 8, cx + 8, 24], fill=pal["lamp"])
        d.ellipse([cx - 2, 8, cx + 10, 22], fill=pal["paper"])
    elif prefix == "pr":
        for x in range(cx - 12, cx + 14, 4):
            _rect(d, [x, 8, x + 1, 30], ink)
    elif prefix == "lf":
        d.ellipse([cx - 10, 16, cx + 10, 30], fill=pal["wood"])
        d.arc([cx - 8, 8, cx + 8, 20], 200, 340, fill=ink)
    else:
        d.ellipse([cx - 8, 10, cx + 8, 26], fill=accent)


def draw_item(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
    parts = art_id.split(".")
    cat = parts[1] if len(parts) > 1 else ""
    variant = parts[2] if len(parts) > 2 else ""
    accent = (pal["indigo"], pal["seal"], pal["jade"], pal["gold"], pal["wood"])[rng.randrange(5)]
    if cat == "clothing":
        _clothing(d, variant, accent, pal)
    elif cat == "jewelry":
        _jewelry(d, variant, pal)
    elif cat == "utensils":
        _utensil(d, variant, pal)
    elif cat == "art":
        _art_object(d, variant, pal)
    elif cat == "goldbar":
        _rect(d, [14, 22, 50, 42], pal["gold"])
        _outline(d, [14, 22, 50, 42], pal["ink"])
        if variant == "bar_ten":
            _rect(d, [18, 18, 46, 46], pal["gold"])
            _outline(d, [18, 18, 46, 46], pal["ink"])
    elif cat == "papers":
        _rect(d, [12, 10, 52, 54], pal["paper_old"])
        _outline(d, [12, 10, 52, 54], pal["ink_soft"])
        for y in range(18, 50, 6):
            d.line([(16, y), (48, y)], fill=pal["ink_soft"])
    elif cat in ("silver", "silverware"):
        d.ellipse([14, 14, 50, 50], fill=pal["mist"], outline=pal["ink"])
        d.ellipse([22, 22, 42, 42], fill=pal["paper"], outline=pal["ink_soft"])
    else:
        d.ellipse([16, 16, 47, 47], fill=accent)
        _outline(d, [16, 16, 47, 47], pal["ink"])
    _outline(d, [0, 0, w - 1, h - 1], pal["ink_soft"])


def _clothing(d, variant, accent, pal):
    ink = pal["ink"]
    if variant == "scarf":
        d.polygon([(8, 20), (56, 16), (52, 28), (12, 32)], fill=accent)
        d.polygon([(40, 26), (56, 24), (48, 52), (36, 40)], fill=pal["seal"])
    elif variant == "qipao":
        d.polygon([(24, 10), (40, 10), (46, 58), (18, 58)], fill=accent)
        _rect(d, [30, 10, 34, 22], ink)
    elif variant == "robe":
        d.polygon([(16, 14), (48, 14), (54, 58), (10, 58)], fill=accent)
        d.line([(32, 14), (32, 58)], fill=ink)
    else:
        d.polygon([(14, 18), (50, 18), (56, 36), (46, 58), (18, 58), (8, 36)], fill=accent)
        _rect(d, [28, 18, 36, 28], pal["paper"])
    _outline_poly = None  # outline via ink line on the outer edge is enough
    d.line([(8, 8), (8, 8)], fill=ink)  # keep ink referenced if a branch skips it
    if variant == "scarf":
        d.line([(8, 20), (56, 16), (52, 28)], fill=ink)


def _jewelry(d, variant, pal):
    ink = pal["ink"]
    if variant == "bangle":
        d.ellipse([14, 18, 50, 50], outline=pal["gold"], width=4)
    else:
        d.ellipse([16, 16, 48, 48], fill=pal["jade"])
        d.ellipse([28, 28, 36, 36], fill=pal["paper"])
        d.ellipse([16, 16, 48, 48], outline=ink)


def _utensil(d, variant, pal):
    ink = pal["ink"]
    if variant == "bowl":
        d.chord([12, 20, 52, 52], 0, 180, fill=pal["wood"])
        d.arc([12, 20, 52, 44], 200, 340, fill=ink)
    elif variant == "clock":
        d.ellipse([12, 12, 52, 52], fill=pal["paper_old"], outline=ink)
        d.line([(32, 32), (32, 18)], fill=ink)
        d.line([(32, 32), (42, 36)], fill=pal["seal"])
    else:
        _rect(d, [18, 22, 46, 50], pal["mist"])
        d.polygon([(18, 22), (10, 30), (10, 40), (18, 36)], fill=pal["ink_soft"])
        _outline(d, [18, 22, 46, 50], ink)


def _art_object(d, variant, pal):
    ink = pal["ink"]
    if variant == "landscape":
        _rect(d, [8, 10, 55, 52], pal["wood"])
        _rect(d, [12, 14, 51, 48], pal["paper"])
        d.polygon([(14, 40), (28, 22), (40, 36), (50, 20), (50, 46), (14, 46)], fill=pal["ink_soft"])
    else:
        _rect(d, [26, 6, 38, 58], pal["paper_old"])
        _rect(d, [22, 6, 42, 12], pal["wood"])
        _rect(d, [22, 52, 42, 58], pal["wood"])
        d.line([(30, 16), (30, 48)], fill=ink)
        d.line([(34, 18), (34, 46)], fill=ink)


def draw_bg(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    name = art_id.split(".", 1)[1]
    # Only the year-open plates are drawn. prison/temple are derived; title/street are legacy.
    if name == "stage.1939":
        _bg_shop(d, w, h, pal, sky=pal["mist"], snow=True, rng=rng)
    elif name == "stage.1940":
        _bg_shop(d, w, h, pal, sky=pal["ink"], snow=False, rng=rng)
    elif name.startswith("stage."):
        _bg_shop(d, w, h, pal, sky=pal["paper_old"], snow=False, rng=rng)
    else:
        raise SystemExit("not a drawn backdrop (derive or legacy): %s" % art_id)


def _bg_shop(d, w, h, pal, sky, snow, rng):
    _rect(d, [0, 0, w - 1, 78], sky)
    _rect(d, [0, 78, w - 1, h - 1], pal["wood_dark"])
    _rect(d, [40, 48, 280, 150], pal["wood"])
    _rect(d, [70, 70, 140, 120], pal["lamp"] if rng.randrange(3) else pal["ink"])
    _rect(d, [160, 70, 250, 120], pal["ink"] if rng.randrange(2) else pal["lamp"])
    d.polygon([(30, 56), (160, 28), (290, 56)], fill=pal["seal"])
    _rect(d, [0, 140, w - 1, h - 1], pal["wood_mid"])
    if snow:
        for i in range(18):
            x = rng.randrange(4, w - 4)
            y = rng.randrange(4, 70)
            d.point((x, y), fill=pal["paper"])


def draw_wheel(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    kind = art_id.split(".", 1)[1]
    ring = {
        "month": pal["indigo"],
        "big": pal["gold_glow"],
        "fair": pal["jade"],
        "gamble": pal["seal"],
    }.get(kind, pal["wood"])
    _rect(d, [0, 0, w - 1, h - 1], pal["paper_old"])
    d.ellipse([4, 4, w - 5, h - 5], fill=pal["wood"])
    d.ellipse([14, 14, w - 15, h - 15], fill=ring)
    d.ellipse([28, 28, w - 29, h - 29], fill=pal["paper"])
    d.ellipse([52, 52, w - 53, h - 53], fill=pal["ink"])
    # Integer rim ticks (texture only; C06 draws the wedges). No float math.
    ticks = (
        (60, 14), (83, 20), (100, 37), (106, 60), (100, 83), (83, 100),
        (60, 106), (37, 100), (20, 83), (14, 60), (20, 37), (37, 20),
    )
    for i, (x, y) in enumerate(ticks):
        if rng.randrange(3) == 0:
            continue
        if 2 <= x < w - 2 and 2 <= y < h - 2:
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=pal["ink"] if i % 2 == 0 else pal["lamp"])


def _tab_glyph(d, name, w, h, pal, rng):
    """24×24 tab icon. The 16px draft stamp covers the top-left, so the glyph sits at (16, 16)."""
    x, y = 16, 16
    ink = pal["ink"]
    accent = (pal["seal"], pal["indigo"], pal["gold"], pal["jade"])[rng.randrange(4)]
    if name == "tab.contacts":
        d.point((x + 2, y + 1), fill=ink)
        d.point((x + 5, y + 1), fill=ink)
        _rect(d, [x + 1, y + 3, x + 3, y + 6], accent)
        _rect(d, [x + 4, y + 3, x + 6, y + 6], pal["wood"])
    elif name == "tab.demands":
        _rect(d, [x + 1, y + 1, x + 6, y + 6], pal["paper_old"])
        _outline(d, [x + 1, y + 1, x + 6, y + 6], ink)
        d.point((x + 5, y + 2), fill=accent)
    elif name == "tab.dossier":
        _rect(d, [x + 1, y + 1, x + 6, y + 6], pal["wood"])
        _rect(d, [x + 2, y + 2, x + 5, y + 5], pal["paper"])
        d.line([(x + 4, y + 2), (x + 4, y + 5)], fill=accent)
    elif name == "tab.rules":
        _rect(d, [x + 1, y + 2, x + 6, y + 6], pal["wood"])
        for yy in (y + 3, y + 4, y + 5):
            d.point((x + 2, yy), fill=accent)
            d.point((x + 5, yy), fill=pal["lamp"])
    elif name == "tab.shelf":
        _rect(d, [x + 1, y + 1, x + 3, y + 3], accent)
        _rect(d, [x + 4, y + 1, x + 6, y + 3], pal["wood_mid"])
        _rect(d, [x + 1, y + 4, x + 6, y + 6], pal["wood"])
    elif name == "tab.tickets":
        _rect(d, [x + 1, y + 1, x + 6, y + 6], pal["paper_old"])
        _outline(d, [x + 1, y + 1, x + 6, y + 6], ink)
        _rect(d, [x + 2, y + 3, x + 5, y + 3], accent)
    elif name == "tab.estates":
        d.polygon([(x + 3, y + 1), (x + 6, y + 3), (x + 1, y + 3)], fill=accent)
        _rect(d, [x + 2, y + 3, x + 6, y + 6], pal["wood"])
    elif name == "tab.settings":
        d.point((x + 3, y + 1), fill=ink)
        d.point((x + 3, y + 6), fill=ink)
        d.point((x + 1, y + 3), fill=ink)
        d.point((x + 6, y + 3), fill=ink)
        d.ellipse([x + 2, y + 2, x + 5, y + 5], outline=accent)
    else:
        _rect(d, [x + 1, y + 1, x + 6, y + 6], accent)


def draw_icon(art_id, im, pal, rng):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
    name = art_id.split(".", 1)[1]
    # Keep the glyph weighted to the lower right; the stamp owns the top left.
    ox = 6 if w <= 16 else 4
    oy = 6 if h <= 16 else 4
    _icon_mark(d, name, ox, oy, w, h, pal, rng)
    _outline(d, [0, 0, w - 1, h - 1], pal["ink_soft"])


def _icon_mark(d, name, ox, oy, w, h, pal, rng):
    ink = pal["ink"]
    if name.startswith("tab."):
        _tab_glyph(d, name, w, h, pal, rng)
        return
    # 24px guide icons keep their symbol in the lower-right; a 16px stamp owns the corner.
    if name == "obj.notice":
        _rect(d, [10, 8, w - 2, h - 2], pal["paper_old"])
        _outline(d, [10, 8, w - 2, h - 2], ink)
        _rect(d, [13, 14, w - 5, 16], ink)
        _rect(d, [13, 18, w - 6, 19], ink)
    elif name == "obj.almanac":
        _rect(d, [10, 6, w - 2, h - 2], pal["paper_old"])
        _rect(d, [10, 6, w - 2, 11], pal["seal"])
        for gx in range(14, w - 3, 3):
            for gy in range(14, h - 3, 3):
                d.point((gx, gy), fill=ink)
    elif name == "obj.brother_ledger":
        _rect(d, [10, 8, w - 2, h - 2], pal["wood"])
        _rect(d, [13, 10, w - 4, h - 4], pal["paper"])
        d.line([(16, 10), (16, h - 4)], fill=ink)
        _rect(d, [18, 13, w - 5, 14], ink)
        _rect(d, [18, 17, w - 6, 18], ink)
    elif name == "coin.head":
        d.ellipse([ox, oy, w - 3, h - 3], outline=pal["gold"], width=2)
        s = max(2, (w - ox) // 5)
        _rect(d, [w // 2, h // 2, w // 2 + s, h // 2 + s], pal["gold"])
    elif name == "coin.tail":
        d.ellipse([ox, oy, w - 3, h - 3], outline=pal["gold"], width=2)
        d.arc([ox + 2, oy + 2, w - 5, h - 5], 20, 200, fill=pal["ink"])
    elif name == "demand.money":
        d.ellipse([ox, oy, w - 3, h - 3], fill=pal["gold"])
        d.point((w // 2, h // 2), fill=pal["ink"])
    elif name == "demand.goods":
        _rect(d, [ox, oy + 2, w - 3, h - 3], pal["wood"])
        d.line([(ox, oy + 2), (w // 2, oy - 1), (w - 3, oy + 2)], fill=pal["wood_dark"])
    elif name == "demand.people":
        d.ellipse([ox, oy, ox + 5, oy + 5], fill=ink)
        d.ellipse([ox + 6, oy + 1, ox + 11, oy + 6], fill=pal["ink_soft"])
        _rect(d, [ox, oy + 6, ox + 6, h - 3], pal["indigo"])
    elif name == "demand.info":
        _rect(d, [ox, oy + 2, w - 5, h - 3], pal["paper_old"])
        d.polygon([(w - 5, oy + 2), (w - 2, oy + 6), (w - 5, oy + 6)], fill=pal["seal"])
    elif name == "seal":
        _rect(d, [ox, oy, w - 3, h - 3], pal["seal"])
        _rect(d, [ox + 2, oy + 2, w - 5, h - 5], pal["paper"])
    elif name == "ws.caixing":
        d.polygon([(w // 2, oy), (w // 2 + 2, h // 2), (w - 3, h // 2),
                   (w // 2 + 2, h // 2 + 2), (w - 4, h - 3), (w // 2, h // 2 + 3),
                   (ox, h - 3), (w // 2 - 2, h // 2 + 2), (ox, h // 2),
                   (w // 2 - 2, h // 2)], fill=pal["lamp"])
    elif name == "ws.fanshen":
        d.polygon([(w // 2, oy), (w - 3, h // 2), (w // 2 + 2, h // 2),
                   (w // 2 + 2, h - 3), (w // 2 - 2, h - 3), (w // 2 - 2, h // 2),
                   (ox, h // 2)], fill=pal["jade"])
    elif name == "ws.liunian":
        d.ellipse([ox, oy + 2, ox + 7, oy + 8], fill=pal["mist"])
        d.ellipse([ox + 4, oy, w - 3, oy + 7], fill=pal["ink_soft"])
    elif name == "ws.pingan":
        d.ellipse([ox, oy, w - 3, h - 3], outline=pal["jade"], width=2)
        d.point((w // 2, h // 2), fill=pal["jade"])
    elif name == "ws.zhuidi":
        d.polygon([(ox, oy), (w - 3, oy), (w // 2, h - 3)], fill=pal["seal"])
    else:
        d.ellipse([ox, oy, w - 3, h - 3], fill=pal["mist"])
    # Touch rng so two ids that share a shape still consume the seed the same way.
    if rng.randrange(7) == 0 and name.startswith("ws."):
        d.point((w - 2, h - 2), fill=pal["lamp"])


def draw_missing(im, pal):
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["ink"])
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            if ((x // 4) + (y // 4)) % 2 == 0:
                _rect(d, [x, y, min(x + 3, w - 1), min(y + 3, h - 1)], pal["danger"])
    d.line([(4, 4), (w - 5, h - 5)], fill=pal["paper"], width=1)
    d.line([(w - 5, 4), (4, h - 5)], fill=pal["paper"], width=1)


# Extras (CardIds.EXTRAS). Portraits are the down-facing first walk frame, ×2, at (8, 0)
# on a 48×64 canvas — the same construction as art/portraits/ruhua.png.
EXTRAS = (
    "ex_patrol",
    "ex_soldier",
    "ex_newsboy",
    "ex_girl",
    "ex_shopboy",
    "ex_oldman",
    "ex_porter",
    "ex_student",
    "ex_hu2_man",
)
# Walk sheets read from the repo. ex_soldier is recolored from patrol, not listed here.
EXTRA_WALK_SRC = {
    "ex_patrol": "art/town/chars/patrol.png",
    "ex_newsboy": "art/town/chars/passerby_0.png",
    "ex_girl": "art/town/chars/passerby_1.png",
    "ex_shopboy": "art/town/chars/passerby_2.png",
    "ex_oldman": "art/town/chars/passerby_3.png",
    "ex_porter": "art/town/chars/passerby_4.png",
    "ex_student": "art/town/chars/passerby_5.png",
    "ex_hu2_man": "art/town/chars/stranger_collector.png",
}
TAB_NAMES = (
    "contacts",
    "demands",
    "dossier",
    "rules",
    "shelf",
    "tickets",
    "estates",
    "settings",
)


def _open_rgba(rel):
    """Read a legacy picture. Never writes it."""
    from PIL import Image

    path = os.path.join(ac.ROOT, rel.replace("/", os.sep))
    src = Image.open(path)
    src.load()
    im = src.convert("RGBA")
    src.close()
    return im


def _fit(im, size):
    from PIL import Image

    if im.size == (size[0], size[1]):
        return im
    return im.resize((size[0], size[1]), Image.Resampling.NEAREST)


def _mix_toward(im, color, num, den):
    """Integer mix. out = (src * (den-num) + color * num) // den. Alpha stays."""
    px = im.load()
    tr, tg, tb = color[0], color[1], color[2]
    keep = den - num
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (
                (r * keep + tr * num) // den,
                (g * keep + tg * num) // den,
                (b * keep + tb * num) // den,
                a,
            )


def _paste_inside(dst, src, xy):
    x, y = xy
    if x < 0 or y < 0 or x + src.size[0] > dst.size[0] or y + src.size[1] > dst.size[1]:
        raise SystemExit("paste %s at %s does not fit %s" % (src.size, xy, dst.size))
    dst.paste(src, (x, y), src)


def _portrait_from_walk(walk):
    """Down row, first column (16×32) ×2, pasted at (8, 0) on 48×64."""
    from PIL import Image

    frame = walk.crop((0, 0, 16, 32)).resize((32, 64), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    canvas.paste(frame, (8, 0), frame)
    return canvas


def _soldier_walk(pal):
    """patrol.png shifted toward khaki. Seed is walk.ex_soldier so the portrait matches."""
    rng = rng_for("walk.ex_soldier")
    im = _open_rgba("art/town/chars/patrol.png")
    khaki = (
        (pal["gold"][0] + pal["wood"][0]) // 2,
        (pal["gold"][1] + pal["wood"][1]) // 2,
        (pal["gold"][2] + pal["wood"][2]) // 2,
        255,
    )
    _mix_toward(im, khaki, 2 + rng.randrange(2), 5)
    return im


def _crease(im, pal):
    px = im.load()
    w, h = im.size
    y = h // 2
    ink = pal["ink_soft"]
    paper = pal["paper"]
    for x in range(w):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        px[x, y] = (ink[0], ink[1], ink[2], a)
    if y + 1 < h:
        for x in range(w):
            r, g, b, a = px[x, y + 1]
            if a == 0:
                continue
            px[x, y + 1] = (
                (r + paper[0]) // 2,
                (g + paper[1]) // 2,
                (b + paper[2]) // 2,
                a,
            )


def _is_derived(art_id):
    if art_id in ("bg.prison", "bg.temple", "walk.ex_soldier", "prop.notice", "prop.ticket", "prop.letter"):
        return True
    return art_id.startswith("portrait.ex_")


def _derive(art_id, size, pal):
    """Pillow derivatives. Caller stamps the draft mark afterwards."""
    if art_id == "bg.prison":
        im = _fit(_open_rgba("art/bg/candle.png"), size)
        _mix_toward(im, pal["indigo"], 1, 2)
        return im
    if art_id == "bg.temple":
        rng = rng_for(art_id)
        im = _fit(_open_rgba("art/town/shops/market_bg.png"), size)
        _mix_toward(im, pal["lamp"], 1, 4)
        post = _open_rgba("art/town/props/lantern_post.png")
        jitter = rng.randrange(5) - 2
        _paste_inside(im, post, (28 + jitter, 62))
        _paste_inside(im, post, (276 + jitter, 62))
        return im
    if art_id == "walk.ex_soldier":
        return _fit(_soldier_walk(pal), size)
    if art_id.startswith("portrait.ex_"):
        who = art_id.split(".", 1)[1]
        if who == "ex_soldier":
            walk = _soldier_walk(pal)
        elif who in EXTRA_WALK_SRC:
            walk = _open_rgba(EXTRA_WALK_SRC[who])
        else:
            raise SystemExit("no walk source for %s" % art_id)
        im = _portrait_from_walk(walk)
        if im.size != (size[0], size[1]):
            raise SystemExit("%s portrait %s != %s" % (art_id, im.size, size))
        return im
    if art_id == "prop.notice":
        return _fit(_open_rgba("art/town/ui/notice_paper.png"), size)
    if art_id == "prop.ticket":
        return _fit(_open_rgba("art/ui/ticket_blank.png"), size)
    if art_id == "prop.letter":
        im = _fit(_open_rgba("art/town/ui/notice_paper.png"), size)
        _crease(im, pal)
        mark = _fit(_open_rgba("art/ui/stamp.png"), (8, 8))
        _paste_inside(im, mark, (size[0] - 8, 0))
        return im
    raise SystemExit("not a derived id: %s" % art_id)


def new_image(w, h):
    from PIL import Image

    return Image.new("RGBA", (w, h), CLEAR)


def draw_prop(art_id, im, pal, rng):
    """Generic prop placeholders (fortune stall + future scene props)."""
    from PIL import ImageDraw

    w, h = im.size
    d = ImageDraw.Draw(im)
    _rect(d, [0, 0, w - 1, h - 1], pal["paper"])
    name = art_id.split(".", 1)[1] if "." in art_id else art_id
    accent = (pal["indigo"], pal["seal"], pal["jade"], pal["gold"], pal["wood"])[rng.randrange(5)]
    if name == "fortune.tube":
        _rect(d, [max(2, w // 2 - 3), 4, min(w - 3, w // 2 + 3), h - 4], pal["wood"])
        _outline(d, [max(2, w // 2 - 3), 4, min(w - 3, w // 2 + 3), h - 4], pal["ink"])
        d.ellipse([max(1, w // 2 - 4), 2, min(w - 2, w // 2 + 4), 8], fill=pal["paper_old"], outline=pal["ink"])
    elif name == "fortune.slip":
        _rect(d, [4, 4, w - 5, h - 5], pal["paper_old"])
        _outline(d, [4, 4, w - 5, h - 5], pal["ink_soft"])
        for y in range(10, h - 8, 5):
            d.line([(6, y), (w - 7, y)], fill=pal["ink_soft"])
    elif name == "fortune.char":
        d.ellipse([4, 4, w - 5, h - 5], fill=accent, outline=pal["ink"])
        d.line([(w // 2, 8), (w // 2, h - 8)], fill=pal["ink"])
        d.line([(8, h // 2), (w - 8, h // 2)], fill=pal["ink"])
    else:
        d.rectangle([3, 3, w - 4, h - 4], fill=accent, outline=pal["ink"])
    _outline(d, [0, 0, w - 1, h - 1], pal["ink_soft"])


DRAW = {
    "frame": draw_frame,
    "portrait": draw_portrait,
    "illus": draw_illus,
    "item": draw_item,
    "prop": draw_prop,
    "bg": draw_bg,
    "wheel": draw_wheel,
    "icon": draw_icon,
}


def render(art_id, size, pal):
    if _is_derived(art_id):
        im = _derive(art_id, size, pal)
    else:
        im = new_image(size[0], size[1])
        if art_id == "missing":
            draw_missing(im, pal)
        else:
            kind = art_id.split(".", 1)[0]
            fn = DRAW.get(kind)
            if fn is None:
                raise SystemExit("unknown art category: %s" % art_id)
            fn(art_id, im, pal, rng_for(art_id))
    if im.size != (size[0], size[1]):
        raise SystemExit("%s is %s, base is %s" % (art_id, im.size, size))
    stamp(im, pal)
    return im


def targets(manifest):
    """(art_id or 'missing', relpath, (w, h)) for every file this generator owns."""
    out = []
    for art_id in sorted(manifest.get("art", {})):
        e = manifest["art"][art_id]
        if e.get("legacy"):
            continue
        rel = str(e.get("placeholder", "")).replace("\\", "/")
        if not ac.is_generated_placeholder(rel):
            continue
        base = e.get("base") or [0, 0]
        out.append((art_id, rel, (int(base[0]), int(base[1]))))
    missing = str(manifest.get("missing", "")).replace("\\", "/")
    if missing:
        out.append(("missing", missing, ac.MISSING_SIZE))
    out.sort(key=lambda row: row[1])
    return out


def save_png_import(rel, out_root):
    """Write .png.import in the exact form Godot 4.7.1 produces, preserving any valid committed UID."""
    rel = rel.replace("\\", "/")
    dest = os.path.join(out_root, (rel + ".import").replace("/", os.sep))
    repo_sidecar = os.path.join(ac.ROOT, (rel + ".import").replace("/", os.sep))
    uid = ac.read_import_uid(dest) or ac.read_import_uid(repo_sidecar) or ac.deterministic_godot_uid(rel)
    text = ac.render_png_import(rel, uid)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def generate(manifest, out_root, only, pal):
    written = []
    for art_id, rel, size in targets(manifest):
        if only and not art_id.startswith(only):
            continue
        if size[0] <= 0 or size[1] <= 0:
            raise SystemExit("bad base for %s" % art_id)
        im = render(art_id, size, pal)
        path = os.path.join(out_root, rel.replace("/", os.sep))
        save_png(im, path)
        save_png_import(rel, out_root)
        written.append(rel)
    write_placeholder_manifest(out_root, manifest)
    return written


def write_placeholder_manifest(out_root, manifest):
    files = {}
    for _art_id, rel, _size in targets(manifest):
        path = os.path.join(out_root, rel.replace("/", os.sep))
        if os.path.isfile(path):
            files[rel] = ac.sha256_file(path)
    doc = {
        "generator": ac.GENERATOR_NAME,
        "version": ac.GENERATOR_VERSION,
        "seed_rule": ac.SEED_RULE,
        "files": {k: files[k] for k in sorted(files)},
    }
    dest = os.path.join(out_root, ac.PLACEHOLDER_MANIFEST.replace("/", os.sep))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    text = json.dumps(doc, indent=2, ensure_ascii=True) + "\n"
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def check_output(out_root, manifest):
    """Stdlib verification: hashes, stamp, size, .import sidecar, byte total. Exit 1 on failure."""
    problems = 0
    total = 0
    pal = ac.load_palette()
    man_path = os.path.join(out_root, ac.PLACEHOLDER_MANIFEST.replace("/", os.sep))
    if not os.path.isfile(man_path):
        print("ART META missing %s" % ac.PLACEHOLDER_MANIFEST)
        problems += 1
        listed = {}
    else:
        listed_doc = ac.load_json(man_path)
        if listed_doc.get("generator") != ac.GENERATOR_NAME or listed_doc.get("seed_rule") != ac.SEED_RULE:
            print("ART META generator/seed_rule mismatch")
            problems += 1
        listed = listed_doc.get("files", {})
        total += os.path.getsize(man_path)
    seen = set()
    for art_id, rel, size in targets(manifest):
        path = os.path.join(out_root, rel.replace("/", os.sep))
        seen.add(rel)
        if not os.path.isfile(path):
            print("ART NOFILE %s %s" % (art_id, rel))
            problems += 1
            continue
        total += os.path.getsize(path)
        digest = ac.sha256_file(path)
        if listed.get(rel) != digest:
            print("ART HASH %s" % rel)
            problems += 1
        imp_path = path + ".import"
        if os.path.isfile(imp_path):
            imp_uid = ac.read_import_uid(imp_path)
            with open(imp_path, encoding="utf-8") as imp_f:
                imp_txt = imp_f.read()
            if not imp_uid or imp_txt != ac.render_png_import(rel, imp_uid):
                print("ART IMPORT %s %s.import" % (art_id, rel))
                problems += 1
        info = ac.png_ihdr(path)
        if info is None or info[2] != 8 or info[3] != 6:
            print("ART FORMAT %s %s not 8-bit RGBA" % (art_id, rel))
            problems += 1
            continue
        if (info[0], info[1]) != size:
            print("ART SIZE %s %dx%d != %dx%d" % (art_id, info[0], info[1], size[0], size[1]))
            problems += 1
        try:
            _w, _h, rows = ac.read_png_rgba(path)
        except ValueError:
            print("ART BADGE %s %s" % (art_id, rel))
            problems += 1
            continue
        if not _badge_ok(rows, ac.badge_pixels(pal, ac.badge_side(size[0], size[1]))):
            print("ART BADGE %s %s" % (art_id, rel))
            problems += 1
    for rel, _digest in sorted(listed.items()):
        if rel not in seen:
            print("ART EXTRA %s" % rel)
            problems += 1
    if total > ac.LIMIT_BYTES:
        print("ART OVERSIZE %d > %d" % (total, ac.LIMIT_BYTES))
        problems += 1
    n = len(targets(manifest))
    if problems:
        print("ART CHECK FAILED %d files, %d bytes" % (n, total))
        return 1
    print("ART CHECK OK %d files, %d bytes" % (n, total))
    return 0


def _badge_ok(rows, expect):
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


# 3x5 bitmap labels for the contact sheet (ASCII only, no system font).
_FONT = {
    " ": ["000", "000", "000", "000", "000"],
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "W": ["101", "101", "101", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "-": ["000", "000", "111", "000", "000"],
}


def _text(d, text, x, y, col, scale=2):
    for ch in text:
        glyph = _FONT.get(ch, _FONT[" "])
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    _rect(d, [x + gx * scale, y + gy * scale, x + gx * scale + scale - 1,
                              y + gy * scale + scale - 1], col)
        x += 4 * scale
    return x


def build_sheet(manifest, out_root, sheet_path, pal):
    from PIL import Image, ImageDraw

    def load_rel(rel, scale):
        path = os.path.join(out_root if _exists(out_root, rel) else ac.ROOT, rel.replace("/", os.sep))
        # Legacy guide portraits live in the repo, not under --out.
        if not os.path.isfile(path):
            path = os.path.join(ac.ROOT, rel.replace("/", os.sep))
        im = Image.open(path).convert("RGBA")
        if scale != 1:
            im = im.resize((im.size[0] * scale, im.size[1] * scale), Image.Resampling.NEAREST)
        return im

    def _exists(root, rel):
        return os.path.isfile(os.path.join(root, rel.replace("/", os.sep)))

    art = manifest["art"]
    guide = []
    for aid in ac.GUIDE_IDS:
        guide.append((aid, art[aid]["placeholder"], 4))
    groups = [
        ("FRAMES", "frame.", 3),
        ("PORTRAITS", "portrait.", 2),
        ("ICONS", "icon.", 3),
        ("ILLUS", "illus.", 2),
        ("ITEMS", "item.", 2),
        ("BG", "bg.", 1),
        ("WHEELS", "wheel.", 2),
    ]
    margin = 8
    max_w = 1600
    rows = []  # list of (label, list of images)

    def pack(label, cells):
        # cells: images already scaled
        if not cells:
            return
        lines = []
        cur = []
        width = margin
        for im in cells:
            if cur and width + im.size[0] + margin > max_w:
                lines.append(cur)
                cur = []
                width = margin
            cur.append(im)
            width += im.size[0] + margin
        if cur:
            lines.append(cur)
        rows.append((label, lines))

    guide_ims = [load_rel(rel, scale) for _aid, rel, scale in guide]
    pack("GUIDE X4", guide_ims)

    def scene_cell(aid, scale, crop):
        im = load_rel(art[aid]["placeholder"], 1)
        if crop:
            im = im.crop((0, 0, 16, 32))
        if scale != 1:
            im = im.resize((im.size[0] * scale, im.size[1] * scale), Image.Resampling.NEAREST)
        return im

    # 画面 row. ASCII label: the contact-sheet font has no CJK.
    # Counters, extra portraits, walk frame 0, every prop, dialog / hero / note, tab icons.
    scene = []
    for aid in ("bg.counter.day", "bg.counter.dusk", "bg.counter.night"):
        scene.append(scene_cell(aid, 1, False))
    for who in EXTRAS:
        scene.append(scene_cell("portrait." + who, 2, False))
    for who in EXTRAS:
        scene.append(scene_cell("walk." + who, 4, True))
    for aid in sorted(a for a in art if str(a).startswith("prop.")):
        scene.append(scene_cell(aid, 2, False))
    scene.append(scene_cell("frame.dialog", 2, False))
    scene.append(scene_cell("frame.hero", 4, False))
    scene.append(scene_cell("frame.guide_note", 4, False))
    for name in TAB_NAMES:
        scene.append(scene_cell("icon.tab." + name, 4, False))
    pack("SCENE", scene)

    for label, prefix, scale in groups:
        cells = []
        for aid in sorted(art):
            if not aid.startswith(prefix):
                continue
            if art[aid].get("legacy"):
                continue
            cells.append(load_rel(art[aid]["placeholder"], scale))
        pack(label, cells)
    miss = str(manifest.get("missing", ""))
    if miss:
        pack("MISSING", [load_rel(miss, 4)])

    label_h = 16
    height = margin
    width = margin
    prepared = []
    for label, lines in rows:
        block_h = label_h
        block_w = 0
        for line in lines:
            lw = margin + sum(im.size[0] + margin for im in line)
            lh = max(im.size[1] for im in line)
            block_h += lh + margin
            block_w = max(block_w, lw)
        prepared.append((label, lines, block_w, block_h))
        height += block_h
        width = max(width, block_w)
    sheet = Image.new("RGBA", (width, height), pal["paper"])
    d = ImageDraw.Draw(sheet)
    y = margin // 2
    for label, lines, _bw, _bh in prepared:
        _text(d, label, margin, y, pal["ink"], 2)
        y += label_h
        for line in lines:
            x = margin
            lh = max(im.size[1] for im in line)
            for im in line:
                sheet.paste(im, (x, y), im)
                x += im.size[0] + margin
            y += lh + margin
    os.makedirs(os.path.dirname(os.path.abspath(sheet_path)), exist_ok=True)
    save_png(sheet, sheet_path)
    print("SHEET %s" % sheet_path)


def parse_args(argv):
    p = argparse.ArgumentParser(description="K12 deterministic placeholder art")
    p.add_argument("--out", default="", help="output root (default: repo root)")
    p.add_argument("--only", default="", help="only art ids with this prefix")
    p.add_argument("--check", action="store_true", help="verify bytes, stamp, size, total; do not draw")
    p.add_argument("--sheet", default="", help="also write a contact sheet (outside the repo)")
    return p.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    out_root = os.path.abspath(args.out) if args.out else ac.ROOT
    manifest = ac.load_json(os.path.join(ac.ROOT, ac.DATA_MANIFEST))
    if args.check and not args.sheet:
        return check_output(out_root, manifest)
    try:
        import PIL  # noqa: F401
    except ImportError:
        print("Pillow not installed")
        return 1
    pal = ac.load_palette()
    if not args.check:
        generate(manifest, out_root, args.only, pal)
        # Report the repo-relative total when writing in place; always print a count.
        n = 0
        total = 0
        for _aid, rel, _size in targets(manifest):
            if args.only and not _aid.startswith(args.only):
                continue
            path = os.path.join(out_root, rel.replace("/", os.sep))
            if os.path.isfile(path):
                n += 1
                total += os.path.getsize(path)
        print("GEN OK %d files, %d bytes" % (n, total))
    if args.sheet:
        build_sheet(manifest, out_root, args.sheet, pal)
    if args.check:
        return check_output(out_root, manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
