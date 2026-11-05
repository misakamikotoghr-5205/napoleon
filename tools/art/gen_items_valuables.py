"""Generate closeup art for gold + deed items and UI ticket/stamp (deterministic).

Run from project root:  python3 tools/art/gen_items_valuables.py
Outputs: art/items/{hairpin,deed_zhao,deed_fake,deed_sun_real}.png (64x64),
         art/ui/ticket_blank.png (96x128), art/ui/stamp.png (24x24).
Rects for item parts live in data/items/gold.json and data/items/deed.json.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview
import random

CLEAR_PIX = (0, 0, 0, 0)


# ---------------------------------------------------------------- hairpin
def hairpin():
    c = Canvas(64, 64)
    # shaft: thick diagonal from lower-left (14,50) to upper-right (44,20)
    a, b = (14.0, 50.0), (44.0, 20.0)
    n = (1.2, 1.2)  # half-width vector (perpendicular to the shaft)
    poly = [(a[0] - n[0], a[1] - n[1]), (a[0] + n[0], a[1] + n[1]),
            (b[0] + n[0], b[1] + n[1]), (b[0] - n[0], b[1] - n[1])]
    c.poly([(round(x), round(y)) for x, y in poly], P.gold)
    # shadow edge (lower-right side) and highlight (upper-left side)
    c.line(15, 51, 45, 21, P.wood1)
    c.line(14, 49, 43, 20, P.lamp)
    c.line(16, 48, 42, 22, P.gold)
    c.line(15, 49, 42, 22, P.gold)
    c.line(13, 49, 13, 50, P.lamp)
    # stamp mark on shaft (near 22..30, 30..40): tiny engraved characters in a box
    for (x, y) in [(24, 36), (25, 36), (27, 36), (28, 36), (24, 38), (27, 38),
                   (25, 35), (27, 35)]:
        c.pixel(x, y, P.wood2)
    c.hline(23, 29, 33, P.dkbrown)
    c.hline(23, 29, 40, P.dkbrown)
    c.vline(23, 33, 40, P.dkbrown)
    c.vline(29, 33, 40, P.dkbrown)
    # pearl head: gold cap ring and pearl
    c.ellipse(48, 14, 6, 6, P.wood2)
    c.ellipse(48, 14, 5, 5, P.gold)
    c.ellipse(48, 14, 4, 4, P.paper_hi)
    c.ellipse(49, 15, 3, 3, P.paper)
    c.pixel(46, 12, P.white)
    c.pixel(47, 12, P.white)
    c.pixel(46, 13, P.white)
    # chip (小缺口) on the pearl's lower-right edge
    c.pixel(51, 17, CLEAR_PIX)
    c.pixel(52, 16, CLEAR_PIX)
    c.pixel(51, 16, P.wood2)
    c.outline(P.dkbrown)
    return c


# ---------------------------------------------------------------- deeds
# Shared layout (matches data/items/deed.json rects):
#   paper body x 6..49, y 4..59 ; owner block x 40..45, y 14..33
#   bounds columns x 27..37, y 14..42 ; seal x 33..42, y 42..51
#   witness marks x 6..27, y 44..57 ; 契尾 slip x 49..56, y 22..57

def _ink_column(c, x, y0, y1, rng, col, density=0.75, w=2):
    """Vertical column of short glyph-like strokes (text suggestion)."""
    y = y0
    while y < y1:
        h = rng.choice([2, 3, 3, 4])
        if rng.random() < density:
            c.rect(x, y, w, min(h, y1 - y), col)
        y += h + 1


def _ink_block(c, x, y, w, h, rng, col, density=0.7):
    for yy in range(y, y + h, 3):
        for xx in range(x, x + w, 3):
            if rng.random() < density:
                c.rect(xx, yy, 2, 2, col)


def _witness_mark(c, kind, x, y):
    """Small 画押: circle ring, cross, or square stamp mark (3x3 / 4x4)."""
    if kind == "circle":
        c.frame(x, y, 4, 4, P.wood2)
        c.pixel(x, y, CLEAR_PIX)
        c.pixel(x + 3, y + 3, CLEAR_PIX)
    elif kind == "cross":
        c.pixel(x, y, P.wood2)
        c.pixel(x + 2, y, P.wood2)
        c.pixel(x + 1, y + 1, P.wood2)
        c.pixel(x, y + 2, P.wood2)
        c.pixel(x + 2, y + 2, P.wood2)
    else:  # "square": hollow box with a centre dot
        c.frame(x, y, 4, 4, P.dkred)
        c.pixel(x + 1, y + 1, P.dkred)
        c.pixel(x + 2, y + 2, P.dkred)


def _deed_common(seed, paper, bounds_cols):
    """Paper sheet, title, owner block, bounds columns, decorative text columns."""
    rng = random.Random(seed)
    c = Canvas(64, 64)
    c.rect(6, 4, 44, 56, paper)
    c.frame(6, 4, 44, 56, P.dkbrown)
    # title bar
    c.rect(21, 7, 14, 2, P.wood2)
    # decorative text columns on the left (not hotspots)
    _ink_column(c, 12, 14, 42, rng, P.wood2, 0.8)
    _ink_column(c, 18, 14, 42, rng, P.wood2, 0.6)
    _ink_column(c, 44, 40, 44, rng, P.wood2, 0.6)
    # owner block (right column)
    _ink_block(c, 40, 14, 6, 20, rng, P.wood1, 0.9)
    # bounds columns: list of (x, width) pairs
    for bx, bw in bounds_cols:
        _ink_column(c, bx, 14, 42, rng, P.wood1, 0.85, w=bw)
    return c


def _tea_edge(c):
    """Fake 'tea stain' edge: uneven brown band along bottom and left."""
    c.dither(6, 56, 44, 4, P.paper_hi, P.paper_old, 0.55)
    c.dither(6, 4, 2, 56, P.paper_hi, P.paper_old, 0.45)
    c.dither(38, 4, 12, 3, P.paper_hi, P.paper_old, 0.35)


def _aged(c):
    """Real old paper: yellowed base already; add lighter worn patches."""
    c.dither(9, 46, 8, 6, P.paper_old, P.paper, 0.4)
    c.dither(36, 6, 9, 5, P.paper_old, P.paper, 0.35)


def _seal_dark(c):
    """Dark red 官印 (红契): dkred body, black frame, inner glyph suggestion."""
    c.rect(33, 42, 10, 10, P.dkred)
    c.frame(33, 42, 10, 10, P.black)
    c.hline(35, 40, 44, P.seal_red)
    c.hline(35, 40, 47, P.seal_red)
    c.vline(37, 44, 49, P.seal_red)
    c.vline(39, 44, 49, P.seal_red)


def _seal_bright(c):
    """Bright glossy 官印 (伪契): seal_red body with 1px white gloss highlight."""
    c.rect(33, 42, 10, 10, P.seal_red)
    c.frame(33, 42, 10, 10, P.dkred)
    # glossy highlight along the top-left inner edge
    c.hline(34, 38, 43, P.white)
    c.vline(34, 43, 46, P.white)
    c.hline(35, 40, 47, P.paper_hi)
    c.vline(38, 44, 49, P.paper_hi)


def _tail_slip(c):
    """红契 契尾 slip attached on the right edge, with its own small seal."""
    c.rect(49, 22, 8, 36, P.paper_old)
    c.frame(49, 22, 8, 36, P.dkbrown)
    for y in range(26, 40, 4):
        c.vline(52, y, y + 2, P.wood2)
    # small dkred seal on the slip
    c.rect(51, 46, 4, 4, P.dkred)
    c.pixel(52, 47, P.seal_red)
    c.pixel(53, 48, P.seal_red)
    # torn/attached seal edge over the slip joint
    c.rect(47, 40, 3, 6, P.dkred)


def deed_zhao():
    # 红契: yellowed old paper, dkred seal, 3 bounds-ish lines, 3 witness marks
    c = _deed_common(11, P.paper_old, bounds_cols=[(28, 2), (34, 2)])
    _aged(c)
    _tail_slip(c)
    _seal_dark(c)
    for i, kind in enumerate(["circle", "cross", "circle"]):
        _witness_mark(c, kind, 8 + i * 7, 48)
    c.outline(P.dkbrown)
    return c


def deed_sun_real():
    # genuine red deed pulled out later: same paper family, 3 narrow bounds columns,
    # different witness marks (squares) and text seed
    c = _deed_common(23, P.paper_old, bounds_cols=[(27, 1), (31, 2), (35, 1)])
    _aged(c)
    _tail_slip(c)
    _seal_dark(c)
    for i, kind in enumerate(["square", "cross", "square"]):
        _witness_mark(c, kind, 8 + i * 7, 48)
    c.outline(P.dkbrown)
    return c


def deed_fake():
    # 伪契: noticeably whiter/newer paper, tea-stain edge (fake ageing),
    # ONE bounds column (different count from the reals), bright glossy seal,
    # NO 契尾 slip (empty space at right), no witness marks
    c = _deed_common(37, P.paper_hi, bounds_cols=[(31, 3)])
    _tea_edge(c)
    _seal_bright(c)
    c.outline(P.dkbrown)
    return c


# ---------------------------------------------------------------- ui
def ticket_blank():
    c = Canvas(96, 128)
    # old paper body
    c.rect(0, 0, 96, 128, P.paper)
    c.dither(0, 0, 96, 128, P.paper, P.paper_old, 0.12)
    # red border frame (double line)
    c.frame(3, 3, 90, 122, P.seal_red)
    c.frame(5, 5, 86, 118, P.seal_red)
    # title band
    c.rect(20, 10, 56, 14, P.seal_red)
    for x in range(26, 70, 6):
        c.rect(x, 14, 3, 6, P.paper_hi)
    # vertical column cells
    top, bot = 30, 116
    cols = [5, 27, 49, 71, 90]
    c.hline(5, 90, top, P.dkred)
    c.hline(5, 90, bot, P.dkred)
    for x in cols:
        c.vline(x, top, bot, P.dkred)
    # horizontal row rules inside cells
    for y in range(top + 12, bot, 12):
        for x0, x1 in zip(cols[:-1], cols[1:]):
            c.hline(x0 + 1, x1 - 1, y, P.paper_old)
    # column labels as short ink blocks (blank form)
    for x0, x1 in zip(cols[:-1], cols[1:]):
        c.rect(x0 + 6, top + 4, (x1 - x0) - 12, 3, P.dkred)
    return c


def stamp():
    c = Canvas(24, 24)
    # square seal: 2px frame plus 2x2 glyph cells
    c.rect(0, 0, 24, 24, P.seal_red)
    c.rect(2, 2, 20, 20, P.dkred)
    cells = [(3, 3), (13, 3), (3, 13), (13, 13)]
    for i, (x, y) in enumerate(cells):
        c.rect(x, y, 8, 8, P.seal_red)
        # glyph-like negative strokes inside each cell (transparent holes)
        for k in range(8):
            if (k + i) % 2 == 0:
                c.pixel(x + k, y + 3, CLEAR_PIX)
            if k in (1, 2, 5, 6):
                c.pixel(x + 3, y + k, CLEAR_PIX)
        c.pixel(x + 1, y + 1, CLEAR_PIX)
        c.pixel(x + 6, y + 6, CLEAR_PIX)
    return c


def main():
    outs = {
        "art/items/hairpin.png": hairpin(),
        "art/items/deed_zhao.png": deed_zhao(),
        "art/items/deed_fake.png": deed_fake(),
        "art/items/deed_sun_real.png": deed_sun_real(),
        "art/ui/ticket_blank.png": ticket_blank(),
        "art/ui/stamp.png": stamp(),
    }
    for rel, cv in outs.items():
        cv.save(rel)
    preview(["art/items/hairpin.png", "art/items/deed_zhao.png",
             "art/items/deed_fake.png", "art/items/deed_sun_real.png"],
            "art/_preview/items_valuables.png")
    print("ok")


if __name__ == "__main__":
    main()
