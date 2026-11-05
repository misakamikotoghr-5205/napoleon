#!/usr/bin/env python3
"""Item closeups (64x64) for the medicine group: art/items/<def_id>.png.

Run from project root:  python3 tools/art/gen_items_medicine.py
Deterministic. Palette colours only. Hotspot rects live in data/items/medicine.json
and must match the features drawn here (see the RECT_* constants below, which are
the same numbers used in the JSON).
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, P

# ---- hotspot rects (x, y, w, h) on the 64x64 sprite; mirrored in medicine.json ----
RECT_QUININE = {
    "label": (14, 33, 23, 18),   # blue label band
    "batch": (17, 44, 17, 4),    # paper batch band on the label
    "seal": (20, 8, 11, 8),      # tin-foil seal over the neck
    "pill": (44, 44, 13, 12),    # single tablet
}
RECT_MERCURO = {
    "label": (11, 40, 43, 8),    # both paper labels
    "batch": (11, 40, 11, 8),    # batch on the left label
    "liquid": (9, 26, 47, 31),   # both bottles (shake)
}
RECT_SULFA_FAKE = {
    "label": (6, 29, 52, 28),    # whole tin front + lid
    "batch": (28, 40, 20, 7),    # paper sticker with batch
    "powder": (12, 24, 39, 11),  # open lid, powder heap
}
RECT_SULFA = {
    "label": (6, 29, 52, 28),
    "batch": (28, 40, 20, 7),
    "powder": (12, 24, 39, 11),
}
RECT_ASPIRIN = {
    "label": (16, 36, 27, 17),   # red/white striped label
    "batch": (18, 44, 23, 4),    # batch band
    "seal": (16, 21, 27, 8),     # wax-dipped cap
    "pill": (46, 44, 13, 13),    # tablet with cross
}
RECT_IODINE = {
    "label": (24, 33, 15, 13),   # paper label
    "batch": (25, 41, 13, 4),    # batch band
    "wax": (25, 5, 13, 8),       # cork + wax
    "smell": (27, 13, 9, 8),     # neck
}
RECT_MORPHINE = {
    "label": (11, 28, 39, 27),   # box face
    "ampoules": (14, 12, 32, 14),  # ampoules peeking out of the box
}


def glyphs(c, x, y, n, col, step=4):
    """Row of tiny solid blocks standing in for printed characters."""
    for i in range(n):
        c.rect(x + i * step, y, 3, 3, col)


def bottle_body(c, x0, x1, y0, y_bottom, fill, hi, shade):
    """Glass-like body: rectangle + elliptical base, lit from upper right."""
    w = x1 - x0 + 1
    cx = x0 + (w - 1) // 2
    rx = (w - 1) // 2
    ry = 5
    c.rect(x0, y0, w, (y_bottom - ry) - y0 + 1, fill)
    c.ellipse(cx, y_bottom - ry, rx, ry, fill)
    c.rect(x0, y0, 2, (y_bottom - ry) - y0 + 1, shade)
    c.rect(x1 - 2, y0 + 2, 1, (y_bottom - ry) - y0 - 3, hi)


def quinine():
    c = Canvas(64, 64)
    x0, x1 = 13, 37
    # neck, lip, shoulder
    c.rect(22, 14, 7, 9, P.fog)
    c.rect(21, 13, 9, 2, P.mist)
    c.rect(15, 22, 21, 4, P.fog)
    bottle_body(c, x0, x1, 26, 56, P.fog, P.white, P.mist)
    # blue label with white stripe and white printed name
    lx, ly, lw, lh = RECT_QUININE["label"]
    c.rect(lx, ly, lw, lh, P.indigo1)
    c.rect(lx, ly + lh - 2, lw, 2, P.indigo0)
    c.rect(lx, ly, 2, lh, P.indigo0)
    c.rect(lx, 39, lw, 2, P.white)
    glyphs(c, 18, 35, 6, P.white)
    # batch band (paper strip with dark marks)
    bx, by, bw, bh = RECT_QUININE["batch"]
    c.rect(bx, by, bw, bh, P.paper_hi)
    c.rect(bx, by + bh - 1, bw, 1, P.paper_old)
    c.rect(bx + 1, by + 1, bw - 3, 1, P.dkbrown)
    # tin-foil seal over the neck
    sx, sy, sw, sh = RECT_QUININE["seal"]
    c.rect(sx, sy, sw, sh, P.silver)
    c.rect(sx, sy, sw, 1, P.white)
    c.rect(sx, sy + sh - 1, sw, 1, P.mist)
    for fx in (sx + 2, sx + 5, sx + 8):
        c.vline(fx, sy + 2, sy + sh - 3, P.mist)
    # one tablet, marked Q
    px, py, pw, ph = RECT_QUININE["pill"]
    c.ellipse(px + 6, py + 5, 6, 5, P.white)
    c.ellipse(px + 5, py + 4, 2, 2, P.dkbrown, filled=False)
    c.line(px + 7, py + 7, px + 9, py + 9, P.dkbrown)
    c.outline(P.black)
    return c


def mercuro():
    c = Canvas(64, 64)
    for x0 in (9, 41):
        cx = x0 + 7
        # cork cap, neck, lip
        c.rect(cx - 3, 12, 7, 5, P.tan)
        c.rect(cx - 4, 16, 9, 2, P.mist)
        c.rect(cx - 2, 18, 5, 8, P.moss)
        bottle_body(c, x0, x0 + 14, 26, 56, P.moss, P.fog, P.black)
        # deep red liquid window
        c.rect(x0 + 3, 30, 9, 22, P.dkred)
        c.rect(x0 + 4, 31, 1, 18, P.seal_red)
        # paper label
        c.rect(x0 + 2, 40, 11, 8, P.paper_hi)
        c.rect(x0 + 2, 47, 11, 1, P.paper_old)
        glyphs(c, x0 + 3, 42, 2, P.dkred)
        c.rect(x0 + 3, 44, 7, 1, P.dkred)
    c.outline(P.black)
    return c


def _tin(c, genuine):
    # lid (lit top face) and open interior
    c.rect(6, 29, 52, 6, P.fog)
    c.rect(6, 29, 52, 1, P.mist)
    c.rect(12, 30, 40, 4, P.wall0)
    # front face
    c.rect(6, 35, 52, 22, P.mist)
    c.rect(6, 34, 52, 1, P.wall1)
    c.rect(6, 35, 1, 22, P.fog)
    c.rect(57, 35, 1, 22, P.wall1)
    c.rect(6, 54, 52, 3, P.wall2)
    if genuine:
        # embossed plaque with raised logo
        c.rect(9, 39, 15, 14, P.mist)
        c.hline(9, 23, 39, P.white)
        c.vline(9, 39, 52, P.white)
        c.hline(9, 23, 52, P.wall1)
        c.vline(23, 39, 52, P.wall1)
        c.ellipse(16, 46, 4, 4, P.wall1, filled=False)
        c.pixel(16, 46, P.wall1)
    else:
        # plain printed name, no embossing
        glyphs(c, 10, 42, 4, P.dkbrown)
    # paper batch sticker
    bx, by, bw, bh = RECT_SULFA["batch"]
    c.rect(bx, by, bw, bh, P.paper_hi)
    c.rect(bx, by + bh - 1, bw, 1, P.paper_old)
    c.rect(bx + 2, by + 2, 14, 1, P.dkbrown)
    c.rect(bx + 2, by + 4, 9, 1, P.dkbrown)


def sulfa_fake():
    c = Canvas(64, 64)
    _tin(c, genuine=False)
    # pure white powder heaped in the open lid
    c.ellipse(31, 29, 19, 5, P.white)
    c.rect(14, 32, 36, 1, P.fog)
    c.outline(P.black)
    return c


def sulfa():
    c = Canvas(64, 64)
    _tin(c, genuine=True)
    # faint yellow powder
    c.ellipse(31, 29, 19, 5, P.paper_hi)
    c.rect(14, 32, 36, 1, P.paper_old)
    c.outline(P.black)
    return c


def aspirin():
    c = Canvas(64, 64)
    x0, x1 = 14, 44
    # wax-dipped cap
    cx0, cy0, cw, ch = RECT_ASPIRIN["seal"]
    c.rect(cx0, cy0, cw, ch, P.dkred)
    c.rect(cx0, cy0, cw, 2, P.seal_red)
    c.rect(cx0, cy0 + ch - 2, cw, 2, P.dkred)
    # squat glass jar
    bottle_body(c, x0, x1, 28, 57, P.fog, P.white, P.mist)
    # red/white striped label
    lx, ly, lw, lh = RECT_ASPIRIN["label"]
    for yy in range(ly, ly + lh):
        col = P.seal_red if ((yy - ly) // 2) % 2 == 0 else P.white
        c.rect(lx, yy, lw, 1, col)
    c.rect(lx, ly + lh - 1, lw, 1, P.dkred)
    # batch band
    bx, by, bw, bh = RECT_ASPIRIN["batch"]
    c.rect(bx, by, bw, bh, P.paper_hi)
    c.rect(bx, by + bh - 1, bw, 1, P.paper_old)
    c.rect(bx + 2, by + 1, bw - 5, 1, P.dkbrown)
    # tablet with cross lines
    px, py, pw, ph = RECT_ASPIRIN["pill"]
    c.ellipse(px + 6, py + 6, 5, 5, P.paper_hi)
    c.hline(px + 2, px + 10, py + 6, P.dkbrown)
    c.vline(px + 6, py + 2, py + 10, P.dkbrown)
    c.outline(P.black)
    return c


def iodine():
    c = Canvas(64, 64)
    # cork under a wax cap, with wax drips
    c.rect(26, 8, 11, 6, P.tan)
    c.pixel(28, 10, P.wood2)
    c.pixel(33, 11, P.wood2)
    wx, wy, ww, wh = RECT_IODINE["wax"]
    c.rect(wx, wy, ww, 4, P.seal_red)
    c.rect(wx, wy + 3, ww, 1, P.dkred)
    c.rect(wx + 1, wy + 4, 2, 3, P.seal_red)
    c.rect(wx + 8, wy + 4, 2, 2, P.seal_red)
    # neck and brown glass body
    c.rect(27, 13, 9, 7, P.wood1)
    c.rect(21, 19, 21, 4, P.wood1)
    bottle_body(c, 20, 42, 22, 55, P.wood1, P.tan, P.wood0)
    # paper label with batch band
    lx, ly, lw, lh = RECT_IODINE["label"]
    c.rect(lx, ly, lw, lh, P.paper_hi)
    c.rect(lx, ly + lh - 1, lw, 1, P.paper_old)
    glyphs(c, lx + 2, ly + 3, 3, P.dkbrown)
    glyphs(c, lx + 2, ly + 7, 2, P.dkbrown)
    bx, by, bw, bh = RECT_IODINE["batch"]
    c.rect(bx, by, bw, bh, P.white)
    c.rect(bx + 1, by + 1, bw - 3, 1, P.dkbrown)
    c.outline(P.black)
    return c


def morphine():
    c = Canvas(64, 64)
    # ampoules standing up out of the open box
    for ax in (14, 21, 28, 35, 42):
        c.rect(ax + 1, 12, 2, 1, P.mist)
        c.rect(ax + 1, 13, 2, 3, P.fog)
        c.rect(ax, 16, 4, 11, P.fog)
        c.rect(ax + 1, 17, 1, 9, P.white)
    # carton
    c.rect(10, 25, 41, 2, P.paper_hi)
    c.rect(10, 27, 41, 29, P.paper)
    c.rect(10, 54, 41, 2, P.paper_old)
    c.rect(49, 27, 2, 27, P.paper_old)
    # printed name band
    lx, ly, lw, lh = RECT_MORPHINE["label"]
    glyphs(c, 16, 31, 6, P.dkred)
    c.rect(lx + 2, ly + 6, lw - 4, 1, P.paper_old)
    # red cross
    c.rect(28, 34, 4, 14, P.seal_red)
    c.rect(24, 39, 12, 4, P.seal_red)
    c.rect(28, 47, 4, 1, P.dkred)
    c.rect(35, 39, 1, 4, P.dkred)
    c.outline(P.black)
    return c


SPRITES = [
    ("quinine", quinine),
    ("mercuro", mercuro),
    ("sulfa_fake", sulfa_fake),
    ("sulfa", sulfa),
    ("aspirin", aspirin),
    ("iodine", iodine),
    ("morphine", morphine),
]


def main():
    from pixlib import preview
    paths = []
    for def_id, fn in SPRITES:
        canvas = fn()
        assert canvas.w == 64 and canvas.h == 64
        rel = "art/items/%s.png" % def_id
        canvas.save(rel)
        paths.append(rel)
        print("wrote", rel)
    out = preview(paths, "art/_preview/items_medicine.png")
    print("preview", out)


if __name__ == "__main__":
    main()
