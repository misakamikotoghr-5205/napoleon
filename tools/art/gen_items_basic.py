#!/usr/bin/env python3
"""Item closeups (64x64 RGBA) for practice / rice / scrap groups.

Run from project root:  python3 tools/art/gen_items_basic.py
Writes art/items/<def_id>.png and a contact sheet art/_preview/items_basic.png.
Deterministic: all randomness uses fixed seeds. Palette colours only (pixlib enforces).
"""
import sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, CLEAR, preview

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# ---------------------------------------------------------------- helpers
def faint(c, x, y, col, level):
    """Paint one pixel with an ordered-dither coverage `level` (0..1)."""
    if BAYER[y % 4][x % 4] / 16.0 + 1 / 32.0 < level:
        c.pixel(x, y, col)


def shade(c, x0, y0, x1, y1, col, level):
    """Dither `col` over already-opaque pixels inside a box (never paints transparency)."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            if c.get(x, y)[3] != 0:
                faint(c, x, y, col, level)


def arc(c, cx, cy, r, a0, a1, col, thick=1):
    """Arc in degrees (0 = right, 90 = down in screen space)."""
    import math
    steps = int(abs(a1 - a0) * r / 2) + 8
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        x = cx + r * math.cos(a)
        y = cy + r * math.sin(a)
        for t in range(thick):
            c.pixel(int(round(x)), int(round(y)) + t, col)


def grains(c, rng, kind, cx, cy, rx, ry, count, base):
    """Dense mound of rice grains inside an ellipse. kind: round|long|opaque|mold."""
    c.ellipse(cx, cy, rx, ry, base)
    placed = 0
    tries = 0
    while placed < count and tries < count * 20:
        tries += 1
        u = rng.uniform(-1, 1)
        v = rng.uniform(-1, 1)
        if u * u + v * v > 0.92:
            continue
        gx = int(cx + u * rx)
        gy = int(cy + v * ry)
        placed += 1
        if kind == "round":  # short, translucent warm grains
            col = rng.choice([P.paper_hi, P.paper_hi, P.paper, P.lamp_pale])
            c.rect(gx, gy, 2, 2, col)
            c.pixel(gx + 1, gy + 1, P.paper_old)
            if rng.random() < 0.35:
                c.pixel(gx, gy, P.paper_hi)
        elif kind == "long":  # slender, chalky-white grains
            col = rng.choice([P.white, P.white, P.fog])
            dx = rng.choice([3, 4])
            c.line(gx, gy, gx + dx, gy + 1, col)
            c.pixel(gx + 1, gy + 2 if rng.random() < 0.5 else gy + 1, P.fog)
        elif kind == "opaque":  # glutinous, milky and opaque
            c.rect(gx, gy, 2, 2, P.white)
            c.pixel(gx + 1, gy + 1, P.fog)
        elif kind == "mold":  # damp, grey-green spotted
            c.rect(gx, gy, 2, 2, P.paper_old)
            r = rng.random()
            if r < 0.45:
                c.pixel(gx, gy, P.moss)
            elif r < 0.7:
                c.pixel(gx + 1, gy, P.gray)
    return placed


def broken_bits(c, rng, cx, cy, rx, ry, n):
    """Broken grain fragments and husk specks (碎米 / 稻壳)."""
    for _ in range(n):
        u = rng.uniform(-1, 1)
        v = rng.uniform(-1, 1)
        if u * u + v * v > 0.85:
            continue
        x = int(cx + u * rx)
        y = int(cy + v * ry)
        if rng.random() < 0.6:
            c.pixel(x, y, P.tan)  # broken fragment
        else:
            c.line(x, y, x + 2, y, P.wood3)  # husk
            c.pixel(x + 2, y, P.dkbrown)


def sack(c, base, shade_col, stamp=False, mold=False, seed=0):
    """Gathered burlap sack with a tied neck, outside-in seam ridge, optional 孙记 stamp."""
    body = [(20, 10), (44, 10), (53, 24), (55, 40), (49, 51), (15, 51), (9, 40), (11, 24)]
    neck = [(23, 3), (41, 3), (44, 10), (20, 10)]
    c.poly(body, base)
    c.poly(neck, shade_col)
    # right-side shading and upper-left highlight
    shade(c, 42, 10, 56, 52, shade_col, 0.55)
    shade(c, 12, 12, 22, 34, P.paper_hi if base == P.paper_old else P.lamp_pale, 0.25)
    # rope tie around the neck
    c.rect(19, 11, 26, 2, P.wood3)
    c.pixel(31, 13, P.wood2)
    c.pixel(32, 13, P.wood2)
    c.line(31, 13, 27, 17, P.wood3)
    c.line(32, 13, 36, 17, P.wood3)
    # seam: inside-out, so the seam allowance ridge and stitches show on the outside
    c.vline(12, 22, 44, shade_col)
    for y in range(22, 45, 2):
        c.pixel(13, y, P.dkbrown)
    c.hline(16, 47, 48, shade_col)
    for x in range(16, 48, 2):
        c.pixel(x, 49, P.dkbrown)
    # cloth weave dots
    rng = random.Random(seed + 7)
    for _ in range(26):
        x = rng.randint(16, 50)
        y = rng.randint(16, 46)
        if c.get(x, y)[3] != 0 and rng.random() < 0.5:
            c.pixel(x, y, shade_col)
    if mold:
        # damp mould stains
        for (x, y, w, h) in [(18, 22, 5, 3), (40, 30, 4, 4), (26, 38, 6, 3), (46, 18, 3, 3)]:
            c.rect(x, y, w, h, P.gray)
            c.pixel(x + 1, y + 1, P.moss)
            c.pixel(x + w - 1, y, P.moss)
    if stamp:
        # faint, half-rubbed red 孙记 stamp, printed on the inside and showing through
        sx, sy = 30, 22
        for (dx, dy) in [(0, 0), (7, 0), (0, 7), (7, 7)]:
            x0, y0 = sx + dx, sy + dy
            for t in range(6):
                faint(c, x0 + t, y0, P.seal_red, 0.55)
                faint(c, x0 + t, y0 + 5, P.seal_red, 0.55)
                faint(c, x0, y0 + t, P.seal_red, 0.55)
                faint(c, x0 + 5, y0 + t, P.seal_red, 0.55)
        # cross strokes inside the two upper cells
        c.line(sx + 2, sy + 1, sx + 2, sy + 4, P.seal_red)
        c.line(sx + 9, sy + 1, sx + 9, sy + 4, P.seal_red)
        for x in range(sx, sx + 15):
            faint(c, x, sy + 13, P.seal_red, 0.3)


def tray_bowl(c):
    """Shallow wooden bowl under a grain mound."""
    c.ellipse(32, 44, 29, 14, P.wood2)
    c.ellipse(32, 42, 26, 11, P.wood1)
    arc(c, 32, 40, 28, 200, 330, P.tan)


def finish(c):
    c.outline(P.dkbrown)
    return c


def paper_tag(c, x, y, w, h, text_col):
    c.rect(x, y, w, h, P.paper_hi)
    c.frame(x, y, w, h, P.dkbrown)
    c.hline(x + 2, x + w - 3, y + 3, text_col)
    c.hline(x + 2, x + w - 5, y + 5, text_col)


# ---------------------------------------------------------------- sprites
def gen_coin():
    c = Canvas(64, 64)
    cx, cy, r = 32, 32, 23
    c.ellipse(cx, cy, r, r, P.wood3)          # rim, darker copper
    c.ellipse(cx, cy, r - 2, r - 2, P.tan)    # field
    c.ellipse(cx, cy, r - 6, r - 6, P.tan)
    # worn edge: lamp-lit upper-right rim polished bright
    for a in range(-60, 40, 3):
        import math
        x = cx + int((r - 2) * math.cos(math.radians(a)))
        y = cy + int((r - 2) * math.sin(math.radians(a)))
        c.pixel(x, y, P.lamp_pale)
    # subtle dither shading on lower-left
    for y in range(cy, cy + r):
        for x in range(cx - r, cx):
            if c.get(x, y)[3] != 0:
                faint(c, x, y, P.wood3, 0.35)
    # inscription hints: short dark strokes ring the field
    for a in range(0, 360, 30):
        import math
        x = cx + int(15 * math.cos(math.radians(a)))
        y = cy + int(15 * math.sin(math.radians(a)))
        if abs(x - cx) > 3 or abs(y - cy) > 3:
            c.pixel(x, y, P.wood2)
    # square hole: frame it, then clear the interior so the hole is see-through
    c.frame(27, 27, 10, 10, P.dkbrown)
    c.rect(28, 28, 8, 8, CLEAR)
    c.frame(27, 27, 10, 10, P.dkbrown)
    c.outline(P.dkbrown)
    # keep the hole see-through (outline() only touches transparent pixels next to opaque ones)
    c.rect(28, 28, 8, 8, CLEAR)
    return c


def gen_handwarmer():
    c = Canvas(64, 64)
    # bail (提梁): iron-ish arc above the lid, drawn in gold-brass with dark edge
    arc(c, 32, 28, 12, 180, 360, P.wood3, thick=2)
    arc(c, 32, 28, 12, 180, 360, P.gold, thick=1)
    # body: brass sphere-ish drum
    c.ellipse(32, 40, 21, 14, P.gold)
    shade(c, 36, 28, 54, 54, P.wood3, 0.6)
    shade(c, 42, 36, 53, 52, P.dkbrown, 0.35)
    c.ellipse(24, 34, 5, 3, P.lamp)           # specular on the drum
    c.pixel(22, 33, P.lamp_pale)
    # lid: flat dome with pierced flower holes
    c.ellipse(32, 28, 19, 6, P.gold)
    shade(c, 40, 24, 52, 34, P.wood3, 0.5)
    for y in range(24, 33, 3):
        for x in range(16, 49, 4):
            if ((x - 32) / 19.0) ** 2 + ((y - 28) / 6.0) ** 2 < 0.7:
                c.pixel(x, y, P.dkbrown)
                c.pixel(x + 1, y, P.dkbrown)
    # embossed bands
    arc(c, 32, 40, 19, 20, 160, P.wood3)
    arc(c, 32, 47, 18, 25, 155, P.wood3)
    # charcoal soot on the bottom
    c.ellipse(32, 52, 14, 4, P.dkbrown, filled=True)
    c.ellipse(32, 52, 12, 3, P.wood1)
    # foot ring
    c.ellipse(32, 56, 16, 4, P.wood2)
    c.hline(18, 46, 58, P.dkbrown)
    finish(c)
    return c


def gen_silver_keepsake():
    c = Canvas(64, 64)
    cx, cy, r = 32, 32, 25
    c.ellipse(cx, cy, r, r, P.gray)            # dark milled edge
    c.ellipse(cx, cy, r - 2, r - 2, P.silver)
    c.ellipse(cx, cy, r - 4, r - 4, P.fog)     # face
    shade(c, 34, 30, 60, 60, P.silver, 0.5)
    # milled edge dots
    import math
    for a in range(0, 360, 6):
        x = cx + int((r - 1) * math.cos(math.radians(a)))
        y = cy + int((r - 1) * math.sin(math.radians(a)))
        c.pixel(x, y, P.gray if a % 12 == 0 else P.mist)
    # inner ring (raised rim of the coin face)
    for a in range(0, 360, 2):
        x = cx + int(16 * math.cos(math.radians(a)))
        y = cy + int(16 * math.sin(math.radians(a)))
        c.pixel(x, y, P.silver)
    # worn highlight, upper-left
    for a in range(200, 300, 4):
        x = cx + int((r - 5) * math.cos(math.radians(a)))
        y = cy + int((r - 5) * math.sin(math.radians(a)))
        c.pixel(x, y, P.white)
    # small central emblem: a plain bar and a worn dot
    c.rect(29, 27, 6, 2, P.silver)
    c.rect(29, 33, 6, 2, P.silver)
    c.pixel(31, 30, P.mist)
    c.pixel(32, 30, P.mist)
    finish(c)
    return c


def gen_rice_sunji():
    c = Canvas(64, 64)
    rng = random.Random(1001)
    sack(c, P.paper_old, P.tan, stamp=True, seed=1)
    # grain spilling out in front of the bag
    c.ellipse(32, 50, 27, 9, P.wood1)
    grains(c, rng, "round", 32, 48, 25, 9, 170, P.wood1)
    broken_bits(c, rng, 32, 48, 25, 9, 22)
    finish(c)
    return c


def _generic_rice(seed, base, shade_col, kind, tag_col, mold=False, count=170):
    c = Canvas(64, 64)
    rng = random.Random(seed)
    sack(c, base, shade_col, mold=mold, seed=seed)
    c.ellipse(32, 50, 27, 9, P.wood1)
    grains(c, rng, kind, 32, 48, 25, 9, count, P.wood1)
    broken_bits(c, rng, 32, 48, 25, 9, 14)
    paper_tag(c, 40, 30, 14, 9, tag_col)
    finish(c)
    return c


def gen_rice_jing_a():
    return _generic_rice(2002, P.paper_old, P.tan, "round", P.dkred, count=180)


def gen_rice_xian_b():
    return _generic_rice(2003, P.paper, P.paper_old, "long", P.dkred, count=190)


def gen_rice_nuo_c():
    return _generic_rice(2004, P.paper_hi, P.paper_old, "opaque", P.dkred, count=170)


def gen_rice_mold_d():
    return _generic_rice(2005, P.paper_old, P.tan, "mold", P.moss, mold=True, count=170)


def _news_sheet(c, x, y, w, h, col, seed):
    """One sheet of printed newsprint: headline bar and grey text lines."""
    rng = random.Random(seed)
    c.rect(x, y, w, h, col)
    c.frame(x, y, w, h, P.paper_old)
    c.rect(x + 3, y + 3, w - 6, 3, P.dkbrown)           # headline
    for ly in range(y + 9, y + h - 3, 3):
        n = rng.randint(w // 2, w - 8)
        c.hline(x + 3, x + 3 + n, ly, P.gray)


def gen_newspapers():
    c = Canvas(64, 64)
    # stacked bundle, edges of the lower sheets visible
    for i, (dx, dy) in enumerate([(3, 3), (1, 2), (0, 0)]):
        _news_sheet(c, 8 + dx, 14 + dy, 46, 42, P.paper if i % 2 == 0 else P.paper_hi, 40 + i)
    # bottom edge shadow
    c.hline(10, 52, 56, P.paper_old)
    c.hline(10, 52, 55, P.dkbrown)
    # tied string: two bands crossing the bundle, with a bow on top
    c.rect(18, 14, 3, 42, P.wood3)
    c.rect(40, 14, 3, 42, P.wood3)
    c.vline(18, 14, 55, P.tan)
    c.vline(40, 14, 55, P.tan)
    c.rect(18, 35, 25, 2, P.wood3)
    # knot and bow loops
    c.ellipse(30, 35, 3, 3, P.wood2)
    c.ellipse(24, 30, 5, 3, P.wood3, filled=False)
    c.ellipse(36, 30, 5, 3, P.wood3, filled=False)
    c.pixel(30, 32, P.wood3)
    c.line(30, 33, 26, 39, P.wood3)
    c.line(31, 33, 35, 39, P.wood3)
    finish(c)
    return c


def gen_ciyuan():
    c = Canvas(64, 64)
    # loose manuscript sheets peeking out from the top edge (扇页里的稿纸)
    c.rect(36, 2, 12, 9, P.paper_hi)
    for y in range(4, 11, 2):
        c.hline(37, 46, y, P.indigo2)
    c.frame(36, 2, 12, 9, P.dkbrown)
    # page block on the right and bottom
    c.rect(44, 6, 8, 50, P.paper_old)
    for y in range(7, 56, 2):
        c.hline(44, 51, y, P.paper)
    c.rect(10, 53, 42, 6, P.paper_old)
    for x in range(12, 52, 2):
        c.vline(x, 53, 58, P.paper)
    # blue cloth cover
    c.rect(10, 6, 36, 48, P.indigo1)
    c.rect(10, 6, 5, 48, P.indigo0)               # spine
    c.hline(15, 44, 7, P.indigo2)                 # top light edge
    shade(c, 20, 20, 46, 54, P.indigo0, 0.25)
    # gold title label with 辞源 hinted as two boxed glyphs
    c.rect(19, 15, 20, 24, P.paper_hi)
    c.frame(19, 15, 20, 24, P.gold)
    c.frame(21, 18, 7, 8, P.dkbrown)
    c.frame(29, 18, 7, 8, P.dkbrown)
    c.hline(22, 26, 22, P.dkbrown)
    c.vline(24, 19, 25, P.dkbrown)
    c.hline(30, 34, 22, P.dkbrown)
    c.vline(32, 19, 25, P.dkbrown)
    c.rect(21, 29, 15, 2, P.dkbrown)
    c.rect(21, 33, 15, 2, P.indigo1)
    # bent top-right corner
    c.poly([(40, 6), (46, 6), (46, 12)], P.paper_hi)
    c.line(40, 6, 46, 12, P.dkbrown)
    # gilt bands on spine
    c.hline(10, 14, 44, P.gold)
    c.hline(10, 14, 45, P.gold)
    finish(c)
    return c


def gen_tabloid():
    c = Canvas(64, 64)
    # three mimeographed sheets, the front one on top
    offsets = [(10, 6), (6, 9), (2, 12)]
    for i, (x, y) in enumerate(offsets):
        w, h = 46, 50
        c.rect(x, y, w, h, P.paper_hi if i == 0 else P.paper)
        c.frame(x, y, w, h, P.paper_old if i else P.dkbrown)
        # black masthead
        c.rect(x + 4, y + 4, w - 8, 6, P.black)
        c.rect(x + 5, y + 5, 6, 4, P.paper_hi)
        c.rect(x + 13, y + 5, 6, 4, P.paper_hi)
        # mimeograph ink lines (indigo, slightly smudged)
        for ly in range(y + 13, y + h - 4, 4):
            ln = w - 10 - ((ly + i) % 3) * 4
            c.hline(x + 4, x + 4 + ln, ly, P.indigo1)
            if (ly + i) % 8 == 0:
                c.hline(x + 4, x + 4 + ln // 2, ly + 1, P.indigo2)
    # ink smudge on the front sheet
    faint(c, 40, 46, P.indigo1, 0.5)
    faint(c, 41, 46, P.indigo1, 0.5)
    faint(c, 38, 47, P.indigo1, 0.4)
    finish(c)
    return c


ITEMS = [
    ("coin", gen_coin),
    ("handwarmer", gen_handwarmer),
    ("silver_keepsake", gen_silver_keepsake),
    ("rice_sunji", gen_rice_sunji),
    ("rice_jing_a", gen_rice_jing_a),
    ("rice_xian_b", gen_rice_xian_b),
    ("rice_nuo_c", gen_rice_nuo_c),
    ("rice_mold_d", gen_rice_mold_d),
    ("newspapers", gen_newspapers),
    ("ciyuan", gen_ciyuan),
    ("tabloid", gen_tabloid),
]


def main():
    paths = []
    for did, fn in ITEMS:
        c = fn()
        rel = "art/items/%s.png" % did
        c.save(rel)
        paths.append(rel)
        print("wrote", rel)
    out = preview(paths, "art/_preview/items_basic.png", scale=3)
    print("preview", out)


if __name__ == "__main__":
    main()
