#!/usr/bin/env python3
"""Tool / prop sprites for 德厚当 counter hotspots (owner: tools worker).

Run from project root:  python3 tools/art/gen_tools.py
Writes transparent PNGs into art/tools/. Hotspot sprites are exactly the
w x h of their rect in data/layout.json (customer and counter_item skipped).
Deterministic, palette-only (pixlib asserts this on save).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview, load_layout

OUT_DIR = "art/tools"
SKIP = {"customer", "counter_item"}


# ---------------------------------------------------------------- helpers
def _bead(c, x, y):
    c.rect(x, y, 3, 3, P.black)
    c.pixel(x, y, P.wood2)  # tiny glint, upper-left


def _text_lines(c, x, y, n, width, col):
    """Faint 'printed text' strokes on a label."""
    for i in range(n):
        c.hline(x, x + width - 1 - (i % 2) * 3, y + i * 2, col)


# ---------------------------------------------------------------- hotspots
def magnifier(w, h):
    c = Canvas(w, h)
    # handle: wooden, runs from lower-right up to the ring
    c.poly([(13, 11), (16, 12), (w - 1, h - 3), (w - 4, h - 1)], P.wood1)
    c.line(16, 12, w - 2, h - 4, P.wood3)
    # brass ring (outer radius 8, ring thickness 2)
    cx, cy = 9, 8
    c.ellipse(cx, cy, 8, 8, P.gold)
    c.ellipse(cx, cy, 6, 6, P.dkbrown)
    # glass lens with lit upper-left and shaded lower-right
    c.ellipse(cx, cy, 5, 5, P.fog)
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 5, cx + 6):
            if c.get(x, y) == P.fog and (x - cx) + (y - cy) > 4:
                c.pixel(x, y, P.mist)
    c.rect(cx - 3, cy - 3, 3, 1, P.white)      # glint on glass
    c.pixel(cx - 4, cy - 2, P.white)
    c.pixel(cx - 5, cy - 6, P.lamp_pale)        # brass highlight
    c.pixel(cx - 2, cy - 7, P.lamp_pale)
    c.outline(P.dkbrown)
    return c


def abacus(w, h):
    c = Canvas(w, h)
    c.rect(0, 0, w, h, P.wood2)                 # wooden frame
    c.rect(2, 2, w - 4, h - 4, P.wood3)         # inner board
    c.hline(2, w - 3, 2, P.tan)                 # top bevel light
    c.hline(2, w - 3, h - 3, P.wood1)           # bottom bevel shadow
    c.rect(2, 8, w - 4, 2, P.wood1)             # cross beam
    c.hline(2, w - 3, 8, P.wood2)
    cols = 9
    for i in range(cols):
        x = 5 + i * 5
        c.vline(x, 3, h - 4, P.wood0)           # rod
    for i in range(cols):
        x = 4 + i * 5
        upper_y = 4 if i % 3 != 1 else 5        # one upper bead per rod
        _bead(c, x, upper_y)
        # lower beads: count varies per rod (the number the player "set")
        lower = [11, 14, 17]
        n = 2 + (i % 2)
        for y in lower[:n]:
            _bead(c, x, y)
    c.frame(0, 0, w, h, P.dkbrown)
    return c


def scale(w, h):
    c = Canvas(w, h)
    # steelyard rod (戥子 杆)
    c.rect(2, 4, w - 4, 2, P.wood2)
    c.hline(2, w - 3, 4, P.wood3)
    c.hline(2, w - 3, 5, P.wood1)
    # brass tick marks
    for x in range(9, w - 4, 4):
        c.pixel(x, 2, P.gold)
    # hang ring at pivot
    c.ellipse(w // 2, 3, 2, 2, P.gold, filled=False)
    c.ellipse(w // 2, 3, 1, 1, P.gold)
    # sliding weight (秤砣) on the right
    c.rect(w - 9, 2, 5, 6, P.gray)
    c.hline(w - 9, w - 5, 2, P.silver)
    c.pixel(w - 8, 3, P.silver)
    # left hanging pan on two strings
    c.line(5, 6, 3, 12, P.dkbrown)
    c.line(5, 6, 8, 12, P.dkbrown)
    c.ellipse(5, 14, 4, 2, P.silver)
    c.hline(2, 8, 13, P.white)                  # pan rim glint
    c.ellipse(5, 14, 3, 1, P.gray)              # pan interior
    # base tray
    c.rect(0, h - 3, w, 3, P.wood3)
    c.hline(0, w - 1, h - 3, P.tan)
    c.outline(P.dkbrown)
    return c


def ledger(w, h):
    c = Canvas(w, h)
    cover_h = h - 3
    c.rect(0, 0, w, cover_h, P.indigo1)         # blue cloth binding
    c.rect(0, 0, 3, cover_h, P.indigo0)         # spine
    c.hline(4, w - 2, 1, P.indigo2)             # top light edge
    c.hline(4, w - 2, cover_h - 2, P.indigo0)
    # paper label
    lx, ly, lw, lh = 9, 5, 22, 11
    c.rect(lx, ly, lw, lh, P.paper_hi)
    c.frame(lx, ly, lw, lh, P.paper_old)
    _text_lines(c, lx + 3, ly + 3, 3, lw - 6, P.dkbrown)
    # page block visible at the bottom edge
    c.rect(3, cover_h, w - 3, 3, P.paper)
    c.hline(3, w - 1, cover_h + 1, P.paper_old)
    c.frame(0, 0, w, cover_h, P.dkbrown)
    return c


def notebook(w, h):
    c = Canvas(w, h)
    top = 5
    c.rect(0, top, w - 5, h - top - 3, P.wood2)  # thick brown cover
    c.rect(0, top, 4, h - top - 3, P.wood1)      # spine
    c.hline(5, w - 7, top + 1, P.wood3)
    # cover label
    c.rect(8, top + 5, 14, 7, P.paper_hi)
    c.frame(8, top + 5, 14, 7, P.paper_old)
    _text_lines(c, 10, top + 7, 2, 10, P.dkbrown)
    # paper slips sticking out of the top
    c.rect(11, 0, 5, top + 1, P.paper)
    c.hline(11, 15, 0, P.paper_hi)
    c.rect(21, 2, 4, top + 1 - 2, P.paper_old)
    c.hline(21, 24, 2, P.paper)
    # slip sticking out of the right edge
    c.rect(w - 6, top + 8, 6, 7, P.paper)
    c.vline(w - 1, top + 8, top + 14, P.paper_old)
    # page block at the bottom
    c.rect(2, h - 3, w - 6, 3, P.paper_old)
    c.hline(2, w - 7, h - 3, P.paper)
    c.frame(0, top, w - 5, h - top - 3, P.dkbrown)
    return c


def medbook(w, h):
    c = Canvas(w, h)
    cover_h = h - 2
    c.rect(0, 0, w, cover_h, P.indigo1)         # thin blue cloth book
    c.frame(1, 1, w - 2, cover_h - 2, P.indigo2)  # inner gilt-style border
    c.rect(0, 0, 2, cover_h, P.indigo0)
    lx, ly, lw, lh = 7, 3, w - 14, 7
    c.rect(lx, ly, lw, lh, P.paper_hi)
    _text_lines(c, lx + 2, ly + 2, 2, lw - 4, P.dkbrown)
    c.rect(2, cover_h, w - 2, 2, P.paper)       # page edge
    c.hline(2, w - 1, cover_h + 1, P.paper_old)
    c.frame(0, 0, w, cover_h, P.dkbrown)
    return c


def pawnbox(w, h):
    c = Canvas(w, h)
    rim_h = 10
    c.rect(0, 0, w, rim_h, P.wood2)              # open top rim
    c.rect(3, 2, w - 6, rim_h - 4, P.black)      # dark inside
    c.hline(3, w - 4, 2, P.dkbrown)
    c.rect(0, rim_h, w, h - rim_h, P.wood1)      # front face
    c.hline(0, w - 1, rim_h, P.wood3)
    for y in (rim_h + 6, rim_h + 12):           # plank seams
        c.hline(0, w - 1, y, P.wood0)
    for x in (w // 3, 2 * w // 3):
        c.vline(x, rim_h + 1, h - 1, P.wood0)
    # brass drawer pull
    c.rect(w // 2 - 4, rim_h + 4, 8, 2, P.gold)
    c.hline(w // 2 - 4, w // 2 + 3, rim_h + 4, P.lamp_pale)
    c.frame(0, 0, w, h, P.dkbrown)
    return c


def trash(w, h):
    c = Canvas(w, h)
    rim_y = 4
    body = [(1, rim_y), (w - 2, rim_y), (w - 6, h - 2), (5, h - 2)]
    c.poly(body, P.wood2)
    # weave: diagonal bamboo strands
    for y in range(rim_y + 2, h - 2):
        for x in range(1, w - 1):
            if c.get(x, y) != P.wood2:
                continue
            if (x + y) % 5 == 0:
                c.pixel(x, y, P.tan)
            elif (x - y) % 7 == 0:
                c.pixel(x, y, P.wood1)
    # horizontal bamboo hoops
    for y in (rim_y + 6, h - 6):
        c.hline(2, w - 3, y, P.wood3)
    # rim and opening
    c.ellipse(w // 2, rim_y, (w - 2) // 2, 3, P.wood3)
    c.ellipse(w // 2, rim_y, (w - 8) // 2, 1, P.wood0)
    c.outline(P.dkbrown)
    return c


def _cabinet_frame(c, w, h):
    c.rect(0, 0, w, h, P.wood1)
    c.frame(0, 0, w, h, P.dkbrown)
    c.hline(1, w - 2, 1, P.wood3)


def telegraph(w, h):
    """Closed cabinet door, small brass handle."""
    c = Canvas(w, h)
    _cabinet_frame(c, w, h)
    # door panels
    c.frame(3, 3, w - 6, h - 6, P.wood3)
    c.frame(5, 5, w - 10, h - 10, P.wood2)
    c.rect(w - 9, h // 2 - 3, 2, 6, P.gold)     # brass handle
    c.pixel(w - 9, h // 2 - 3, P.lamp_pale)
    c.rect(w - 11, h // 2 - 4, 1, 8, P.gold)    # escutcheon
    return c


def telegraph_open(w, h):
    """Cabinet door swung open: telegraph key + glowing indicator lamp."""
    c = Canvas(w, h)
    _cabinet_frame(c, w, h)
    # interior
    c.rect(5, 3, w - 9, h - 6, P.dkbrown)
    c.hline(5, w - 5, 3, P.wood0)
    c.rect(5, h - 9, w - 9, 2, P.wood0)          # shelf
    # swung door (narrow sliver on the left)
    c.rect(0, 0, 4, h, P.wood2)
    c.vline(1, 2, h - 3, P.wood3)
    c.frame(0, 0, 4, h, P.dkbrown)
    # telegraph key: base plate, lever, knob
    c.rect(9, h - 14, 14, 4, P.silver)
    c.hline(9, 22, h - 14, P.white)
    c.line(10, h - 14, 20, h - 17, P.gold)
    c.rect(19, h - 19, 3, 3, P.black)
    c.pixel(20, h - 19, P.gray)
    # indicator lamp (lit) with small glow ring
    lx, ly = w - 9, 8
    c.ellipse(lx, ly, 3, 3, P.flame)
    c.ellipse(lx, ly, 2, 2, P.lamp)
    c.pixel(lx - 1, ly - 1, P.lamp_pale)
    c.ellipse(lx, ly, 4, 4, P.lamp, filled=False)
    c.outline(P.dkbrown)
    return c


def _flag_pole(c, w, h):
    # pole at the left edge, bracket arm at the top
    c.vline(1, 0, h - 3, P.wood2)
    c.vline(2, 0, h - 3, P.wood1)
    c.hline(1, w - 1, 0, P.wood1)
    c.hline(1, w - 1, 1, P.wood0)
    c.rect(0, h - 3, 5, 2, P.wood1)              # foot


def _flag_cloth(c, x, y, cw, ch, base, light, dark):
    c.rect(x, y, cw, ch, base)
    c.vline(x, y, y + ch - 1, light)            # lit hanging edge
    c.vline(x + cw // 2, y + 1, y + ch - 3, dark)  # fold
    c.hline(x, x + cw - 1, y + ch - 1, dark)    # hem
    c.hline(x, x + cw - 1, y, light)


def door_flag(w, h):
    """Blue cloth banner (蓝布旗, 序章 default)."""
    c = Canvas(w, h)
    _flag_pole(c, w, h)
    _flag_cloth(c, 3, 3, w - 4, 22, P.indigo1, P.indigo2, P.indigo0)
    c.pixel(w - 3, 9, P.indigo2)
    c.outline(P.dkbrown)
    return c


def door_flag_white(w, h):
    c = Canvas(w, h)
    _flag_pole(c, w, h)
    _flag_cloth(c, 3, 3, w - 4, 22, P.white, P.paper_hi, P.gray)
    c.outline(P.dkbrown)
    return c


def door_flag_red(w, h):
    c = Canvas(w, h)
    _flag_pole(c, w, h)
    _flag_cloth(c, 3, 3, w - 4, 22, P.seal_red, P.dkred, P.dkred)
    c.pixel(w - 3, 9, P.gold)
    c.outline(P.dkbrown)
    return c


def door_flag_none(w, h):
    """Bare pole with hook (flag not hung)."""
    c = Canvas(w, h)
    _flag_pole(c, w, h)
    c.rect(3, 4, 2, 2, P.silver)                # hook
    c.pixel(4, 6, P.silver)
    c.outline(P.dkbrown)
    return c


def sign(w, h):
    """Plain hanging wooden board; text is overlaid by the engine."""
    c = Canvas(w, h)
    cord_x1, cord_x2 = 4, w - 5
    c.vline(cord_x1, 0, 4, P.dkbrown)
    c.vline(cord_x2, 0, 4, P.dkbrown)
    by = 4
    c.rect(0, by, w, h - by, P.wood2)           # board
    c.hline(1, w - 2, by + 1, P.wood3)          # light bevel top
    c.hline(1, w - 2, h - 2, P.wood1)           # shadow bottom
    for y in (by + 10, by + 19):                # faint grain
        c.hline(3, w - 4, y, P.wood1)
    for (x, y) in ((2, by + 2), (w - 3, by + 2), (2, h - 3), (w - 3, h - 3)):
        c.pixel(x, y, P.silver)                 # iron nails
    c.frame(0, by, w, h - by, P.dkbrown)
    return c


def _lamp_common(c, w, h):
    c.ellipse(10, 28, 5, 2, P.gold)             # foot
    c.hline(6, 13, 27, P.lamp_pale)
    c.ellipse(10, 21, 6, 5, P.gold)             # oil reservoir
    c.pixel(6, 20, P.lamp_pale)
    c.pixel(6, 21, P.lamp_pale)
    c.rect(8, 14, 4, 2, P.gold)                 # burner collar
    c.rect(6, 3, 8, 2, P.gold)                  # chimney cap
    c.frame(6, 5, 8, 10, P.silver)              # chimney frame


def lamp(w, h):
    c = Canvas(w, h)
    _lamp_common(c, w, h)
    c.rect(7, 6, 6, 8, P.fog)                   # glass
    c.vline(7, 6, 13, P.white)                  # glass glint
    c.ellipse(10, 11, 2, 3, P.lamp)             # flame
    c.ellipse(10, 12, 1, 2, P.flame)
    c.pixel(10, 9, P.lamp_pale)
    c.outline(P.dkbrown)
    return c


def lamp_off(w, h):
    c = Canvas(w, h)
    _lamp_common(c, w, h)
    c.rect(7, 6, 6, 8, P.mist)                  # dull glass, no flame
    c.vline(7, 6, 13, P.fog)
    c.rect(9, 12, 2, 2, P.dkbrown)              # cold wick
    c.outline(P.dkbrown)
    return c


def candle(w, h):
    c = Canvas(w, h)
    c.rect(1, 6, 6, 9, P.paper_hi)              # wax body
    c.vline(6, 6, 14, P.paper_old)              # shaded side
    c.hline(1, 6, 5, P.paper)                   # wax top rim
    c.rect(0, 14, 8, 2, P.paper_old)            # drip base
    c.pixel(2, 15, P.paper)
    c.pixel(3, 5, P.dkbrown)                    # wick
    c.ellipse(3, 2, 1, 2, P.flame)              # flame
    c.pixel(3, 2, P.lamp)
    c.pixel(3, 1, P.lamp_pale)
    c.frame(0, 5, 8, 11, P.dkbrown)
    return c


# ---------------------------------------------------------------- pieces
PIECES = {
    # name: (face, rim, inner ring)
    "black":  (P.black,    P.dkbrown, P.gray),
    "white":  (P.white,    P.tan,     P.paper_old),
    "cyan":   (P.indigo2,  P.indigo0, P.mist),
    "red":    (P.seal_red, P.dkred,   P.dkred),
    "yellow": (P.gold,     P.wood3,   P.lamp_pale),
    "gray":   (P.silver,   P.gray,    P.fog),
}


def piece(face, rim, inner):
    c = Canvas(14, 14)
    c.ellipse(7, 7, 6, 6, rim)                  # rim
    c.ellipse(7, 7, 5, 5, face)                 # face
    c.ellipse(7, 7, 3, 3, inner, filled=False)  # engraved ring
    c.pixel(5, 5, P.lamp_pale if face == P.white else P.white)  # glint
    return c


# ---------------------------------------------------------------- main
BUILDERS = [
    ("magnifier", magnifier), ("abacus", abacus), ("scale", scale),
    ("ledger", ledger), ("notebook", notebook), ("medbook", medbook),
    ("pawnbox", pawnbox), ("trash", trash), ("telegraph", telegraph),
    ("door_flag", door_flag), ("sign", sign), ("lamp", lamp),
]
VARIANTS = [
    # (out name, builder, layout id whose rect gives the size)
    ("telegraph_open", telegraph_open, "telegraph"),
    ("door_flag_none", door_flag_none, "door_flag"),
    ("door_flag_white", door_flag_white, "door_flag"),
    ("door_flag_red", door_flag_red, "door_flag"),
    ("lamp_off", lamp_off, "lamp"),
]


def main():
    layout = load_layout()
    hs = layout["hotspots"]
    written = []

    def rect_size(hid):
        _, _, w, h = hs[hid]["rect"]
        return w, h

    for hid, fn in BUILDERS:
        assert hid in hs and hid not in SKIP, hid
        w, h = rect_size(hid)
        written.append(_save(fn(w, h), hid, (w, h)))
    for name, fn, hid in VARIANTS:
        w, h = rect_size(hid)
        written.append(_save(fn(w, h), name, (w, h)))
    for n in ("black", "white", "cyan", "red", "yellow", "gray"):
        face, rim, inner = PIECES[n]
        written.append(_save(piece(face, rim, inner), "piece_" + n, (14, 14)))
    written.append(_save(candle(8, 16), "candle", (8, 16)))

    # sanity: every layout hotspot (except skipped) has a matching sprite
    for hid in hs:
        if hid in SKIP:
            continue
        assert os.path.exists(os.path.join(_root(), OUT_DIR, hid + ".png")), hid

    preview(written, "art/_preview/tools.png", scale=4)
    print("wrote %d sprites to %s" % (len(written), OUT_DIR))


def _root():
    from pixlib import ROOT
    return ROOT


def _save(canvas, name, expect):
    rel = os.path.join(OUT_DIR, name + ".png")
    canvas.save(rel)
    from PIL import Image
    im = Image.open(os.path.join(_root(), rel))
    assert im.size == tuple(expect), "%s size %s != %s" % (name, im.size, expect)
    return rel


if __name__ == "__main__":
    main()
