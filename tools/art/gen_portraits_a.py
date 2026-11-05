"""Generate 48x64 half-body portraits, group A (deterministic).

Run from project root:  python3 tools/art/gen_portraits_a.py
Outputs: art/portraits/{brother,chen,xiaoding,zhang,wangshan,li}.png
         art/_preview/portraits_a.png (contact sheet, x4, not shipped)

Lighting: warm lamp from upper right -> right side lit (hi), left side in shadow (lo).
Body shading is applied as a post-pass on the flat base colour, so every garment
keeps its own palette (indigo / brown / grey / tan / charcoal / blue-qipao).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview, CLEAR

W, H = 48, 64
OUT_DIR = "art/portraits"


# ------------------------------------------------------------------ helpers
def in_head(x, y, rx=9.5, ry=11.0, cx=24, cy=23):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def paint(c, fn, col):
    for y in range(c.h):
        for x in range(c.w):
            if fn(x, y):
                c.pixel(x, y, col)


def robe(c, pts, base, lo, hi, lo_x=14, hi_x=35):
    """Flat garment polygon with lamp shading: left of lo_x -> lo, right of hi_x -> hi."""
    c.poly(pts, base)
    for y in range(c.h):
        for x in range(c.w):
            if c.get(x, y) == base:
                if x <= lo_x:
                    c.pixel(x, y, lo)
                elif x >= hi_x:
                    c.pixel(x, y, hi)


def neck(c):
    c.rect(21, 31, 7, 8, P.skin)
    c.vline(21, 31, 36, P.skin_lo)
    c.hline(21, 27, 35, P.skin_lo)


def head(c):
    for y in range(11, 35):
        for x in range(14, 35):
            if in_head(x, y):
                nx = (x - 24) / 9.5
                ny = (y - 23) / 11.0
                s = 0.55 * nx - 0.45 * ny  # light from upper right
                if s < -0.5:
                    col = P.skin_lo
                elif s > 0.72:
                    col = P.skin_hi
                else:
                    col = P.skin
                c.pixel(x, y, col)
    # ears
    c.pixel(14, 23, P.skin_lo); c.pixel(14, 24, P.skin_lo)
    c.pixel(34, 23, P.skin); c.pixel(34, 24, P.skin)


def eyes_dark(c, rows=(22, 23)):
    for y in rows:
        for x in (19, 20, 27, 28):
            c.pixel(x, y, P.black)


def brows(c, col=P.hair, y=20):
    c.hline(18, 21, y, col)
    c.hline(26, 29, y, col)


def nose(c):
    c.pixel(23, 26, P.skin_lo)
    c.pixel(23, 27, P.skin_lo)
    c.pixel(24, 28, P.skin_lo)
    c.pixel(25, 27, P.skin_hi)


def sheen_body(c, x0, x1, y0, y1, col):
    """Small highlight stripe on a garment (lamp side)."""
    for y in range(y0, y1):
        c.pixel(x1 - (y - y0) // 4, y, col)


# ------------------------------------------------------------------ 沈如松
def brother():
    c = Canvas(W, H)
    robe(c, [(6, 63), (7, 48), (11, 41), (17, 37), (31, 37), (37, 41), (41, 48), (42, 63)],
         P.indigo1, P.indigo0, P.indigo2)
    neck(c)
    # 立领 (closed stand collar) + front placket with two buttons
    c.hline(19, 29, 37, P.indigo0)
    c.hline(19, 29, 38, P.indigo0)
    c.vline(24, 39, 63, P.indigo0)
    c.pixel(24, 44, P.gold)
    c.pixel(24, 52, P.gold)
    head(c)
    # short hair: flat cap with temples and a light crown sheen
    paint(c, lambda x, y: in_head(x, y) and y <= 16, P.hair)
    paint(c, lambda x, y: in_head(x, y) and y <= 18 and (x <= 16 or x >= 32), P.hair)
    paint(c, lambda x, y: in_head(x, y) and y <= 15 and x >= 27 and y >= 13, P.gray)
    # eyes calm and level, brows heavy
    eyes_dark(c)
    brows(c, P.hair, 20)
    # scar through the CHARACTER'S LEFT eyebrow (= viewer's right, x 26..30)
    c.pixel(26, 19, P.skin_hi)
    c.pixel(27, 20, P.skin_hi)
    c.pixel(28, 21, P.skin_hi)
    nose(c)
    # serious mouth
    c.hline(23, 25, 31, P.dkred)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ 陈文庭
def chen():
    c = Canvas(W, H)
    robe(c, [(5, 63), (6, 48), (10, 41), (17, 37), (31, 37), (38, 41), (42, 48), (43, 63)],
         P.wood2, P.wood1, P.wood3)
    neck(c)
    # closed 直领 in darker brown, with a cloth knot button
    c.hline(19, 29, 37, P.wood0)
    c.vline(24, 39, 63, P.wood1)
    c.pixel(24, 40, P.gold)
    c.pixel(24, 46, P.gold)
    head(c)
    # grey-white hair: receding top, grey temples
    paint(c, lambda x, y: in_head(x, y) and y <= 14, P.fog)
    paint(c, lambda x, y: in_head(x, y) and y <= 20 and (x <= 16 or x >= 32), P.fog)
    paint(c, lambda x, y: in_head(x, y) and y <= 14 and x >= 28, P.white)
    paint(c, lambda x, y: in_head(x, y) and y <= 20 and x <= 18 and (x <= 16 or y >= 16), P.silver)
    # round silver spectacles around both eyes
    c.ellipse(20, 23, 4, 4, P.silver, filled=False)
    c.ellipse(28, 23, 4, 4, P.silver, filled=False)
    c.pixel(24, 23, P.silver)
    c.pixel(15, 22, P.silver)
    c.pixel(33, 22, P.silver)
    eyes_dark(c)
    brows(c, P.silver, 19)
    nose(c)
    # gentle smile lines and a soft smile
    c.pixel(21, 27, P.skin_lo); c.pixel(21, 28, P.skin_lo)
    c.pixel(27, 27, P.skin_lo); c.pixel(27, 28, P.skin_lo)
    c.pixel(22, 30, P.dkbrown)
    c.hline(23, 25, 31, P.dkbrown)
    c.pixel(26, 30, P.dkbrown)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ 小丁
def xiaoding():
    c = Canvas(W, H)
    robe(c, [(10, 63), (11, 48), (15, 40), (19, 37), (29, 37), (33, 40), (37, 48), (38, 63)],
         P.mist, P.wall2, P.fog)
    neck(c)
    # grey cloth collar + apron with oil stains
    c.hline(19, 29, 37, P.wall2)
    c.poly([(16, 44), (32, 44), (34, 63), (14, 63)], P.paper_old)
    c.vline(15, 44, 63, P.wood3)  # apron edge in shadow
    for (x, y, w, h) in [(18, 50, 3, 2), (25, 56, 4, 2), (21, 60, 2, 2), (28, 47, 2, 1)]:
        c.rect(x, y, w, h, P.wood2)
    c.pixel(19, 51, P.wood1)
    head(c)
    # light grey towel draped at the neck, one end over the left shoulder
    c.hline(17, 31, 36, P.white)
    c.hline(17, 31, 37, P.fog)
    for i in range(0, 10):
        x0 = 16 - (i * 3) // 10
        c.hline(x0 - 2, x0, 37 + i, P.white)
        c.pixel(x0 - 3, 37 + i, P.fog)
    c.rect(28, 38, 3, 4, P.white)
    c.vline(30, 38, 41, P.fog)
    # messy short hair with uneven fringe
    paint(c, lambda x, y: in_head(x, y) and y <= 14, P.hair)
    paint(c, lambda x, y: in_head(x, y) and y == 15 and x % 4 != 0, P.hair)
    paint(c, lambda x, y: in_head(x, y) and y == 16 and (17 <= x <= 22 or 27 <= x <= 31), P.hair)
    # nervous eyes: whites showing, pupils sliding to the left
    for y in (22, 23):
        c.pixel(18, y, P.black); c.pixel(19, y, P.white); c.pixel(20, y, P.white)
        c.pixel(26, y, P.black); c.pixel(27, y, P.white); c.pixel(28, y, P.white)
    # worried brows: inner ends raised
    c.pixel(18, 20, P.hair); c.pixel(19, 19, P.hair); c.pixel(20, 18, P.hair); c.pixel(21, 18, P.hair)
    c.pixel(26, 18, P.hair); c.pixel(27, 18, P.hair); c.pixel(28, 19, P.hair); c.pixel(29, 20, P.hair)
    # sweat drop
    c.pixel(36, 25, P.fog); c.pixel(36, 26, P.fog); c.pixel(35, 27, P.mist); c.pixel(36, 27, P.fog)
    nose(c)
    # small uneasy mouth
    c.hline(23, 24, 31, P.dkred)
    c.pixel(23, 30, P.skin_lo); c.pixel(24, 30, P.skin_lo)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ 张慧娟
def zhang():
    c = Canvas(W, H)
    # blue qipao underneath
    robe(c, [(6, 63), (7, 48), (11, 41), (17, 37), (31, 37), (37, 41), (41, 48), (42, 63)],
         P.indigo1, P.indigo0, P.indigo2)
    # high collar in dark blue
    c.hline(18, 30, 35, P.indigo0)
    c.hline(18, 30, 36, P.indigo0)
    neck(c)
    c.hline(18, 30, 36, P.indigo0)
    # greyish-white over-smock (罩衣) with buttons
    robe(c, [(14, 39), (19, 38), (29, 38), (34, 39), (36, 63), (12, 63)],
         P.fog, P.wall2, P.white, lo_x=15, hi_x=32)
    c.vline(24, 40, 63, P.wall1)
    for y in (46, 53, 60):
        c.pixel(23, y, P.wall1)
    # qipao embroidery hint on the blue at both sides
    c.pixel(9, 56, P.gold); c.pixel(39, 52, P.gold); c.pixel(38, 58, P.gold)
    # basket handle crossing the bottom-left edge
    # woven basket (10x8) at the bottom-left, with a handle arc above it
    bx, by = 1, 55
    c.rect(bx, by, 10, 8, P.wood2)
    for yy in range(by + 1, by + 8):
        for xx in range(bx + 1, bx + 9):
            if (xx + yy) % 2 == 0:
                c.pixel(xx, yy, P.wood3)
            else:
                c.pixel(xx, yy, P.wood2)
    c.hline(bx, bx + 9, by, P.wood1)
    c.vline(bx, by, by + 7, P.wood1)
    c.vline(bx + 9, by, by + 7, P.wood1)
    c.hline(bx, bx + 9, by + 7, P.wood1)
    handle = [(bx + 1, by), (bx + 2, by - 3), (bx + 5, by - 5), (bx + 8, by - 3), (bx + 9, by)]
    for a, b in zip(handle, handle[1:]):
        c.line(a[0], a[1], b[0], b[1], P.wood1)
    head(c)
    # 1930s bob: cap of hair, sides ending at the jaw, short fringe
    paint(c, lambda x, y: in_head(x, y, 10.0, 12.0) and y <= 16, P.hair)
    paint(c, lambda x, y: abs(x - 24) >= 8 and abs(x - 24) <= 10 and 16 <= y <= 30, P.hair)
    paint(c, lambda x, y: y == 17 and 16 <= x <= 31 and (x % 5) != 0, P.hair)
    paint(c, lambda x, y: in_head(x, y) and y <= 14 and x >= 28, P.gray)
    # quick sharp eyes and thin brows
    eyes_dark(c, (22, 23))
    c.hline(18, 21, 20, P.hair)
    c.hline(26, 29, 20, P.hair)
    nose(c)
    # small red lips, one highlight
    c.hline(23, 25, 31, P.dkred)
    c.pixel(24, 31, P.seal_red)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ 王山
def wangshan():
    c = Canvas(W, H)
    # straw rain cape (蓑衣): wide shoulders, strands in tan / wood
    cape = [(2, 63), (4, 48), (9, 40), (16, 36), (32, 36), (39, 40), (44, 48), (46, 63)]
    c.poly(cape, P.tan)
    for y in range(H):
        for x in range(W):
            if c.get(x, y) == P.tan:
                if (x + 2 * y) % 9 == 0:
                    c.pixel(x, y, P.wood3)
                elif (x + 3 * y) % 13 == 5:
                    c.pixel(x, y, P.wood2)
    robe_fix = [(x, y) for y in range(H) for x in range(W) if c.get(x, y) == P.tan]
    for (x, y) in robe_fix:
        if x <= 12:
            c.pixel(x, y, P.wood3)
        elif x >= 36:
            c.pixel(x, y, P.lamp_pale)
    # ragged straw hem: cut the bottom edge at varying heights, then hang tips
    def hem(x):
        return 59 + ((x * 7) % 5)
    for x in range(W):
        for y in range(hem(x) + 1, H):
            c.pixel(x, y, CLEAR)
    for x in range(2, 46):
        if x % 2 == 0 and hem(x) + 1 <= 63:
            c.pixel(x, hem(x) + 1, P.wood2)
        if x % 5 == 1 and hem(x) + 2 <= 63:
            c.pixel(x, hem(x) + 2, P.wood3)
    # dark shirt collar under the cape
    c.rect(18, 36, 13, 4, P.wall0)
    neck(c)
    head(c)
    # cropped hair
    paint(c, lambda x, y: in_head(x, y) and y <= 15, P.hair)
    paint(c, lambda x, y: in_head(x, y) and y <= 18 and (x <= 15 or x >= 33), P.hair)
    # heavy angled brows
    c.hline(18, 21, 19, P.hair); c.hline(18, 21, 20, P.hair)
    c.hline(26, 29, 19, P.hair); c.hline(26, 29, 20, P.hair)
    # alert eyes: whites showing above the iris line
    c.hline(18, 20, 22, P.white); c.hline(18, 20, 23, P.black)
    c.hline(26, 28, 22, P.white); c.hline(26, 28, 23, P.black)
    # stubble
    paint(c, lambda x, y: in_head(x, y) and y >= 29 and (x + y) % 4 == 0 and (x + y) % 8 != 0, P.wall2)
    nose(c)
    c.hline(22, 26, 31, P.dkbrown)
    # left hand (viewer's right): white gauze wrap raised near the chest, one small seep spot
    c.rect(31, 41, 8, 9, P.white)
    c.hline(31, 38, 41, P.fog)
    c.vline(31, 41, 49, P.fog)
    c.hline(31, 38, 44, P.paper_old)
    c.hline(31, 38, 47, P.paper_old)
    c.hline(33, 38, 50, P.fog)
    c.pixel(35, 45, P.seal_red)
    c.pixel(36, 45, P.seal_red)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ 李敬之
def li():
    c = Canvas(W, H)
    robe(c, [(7, 63), (8, 48), (12, 40), (17, 37), (31, 37), (36, 40), (40, 48), (41, 63)],
         P.wall1, P.wall0, P.wall2)
    neck(c)
    # dark stand collar with white inner edge
    c.hline(18, 30, 37, P.wall0)
    c.hline(19, 29, 38, P.white)
    c.hline(18, 30, 39, P.wall0)
    # front placket and gold buttons
    c.vline(24, 40, 63, P.wall0)
    c.pixel(24, 44, P.gold)
    c.pixel(24, 52, P.gold)
    c.pixel(23, 44, P.skin_lo)
    head(c)
    # student cap pulled low: navy crown, black peak, gold badge
    # flat-topped soft crown (student cap, not a kepi): straight top, slightly rounded sides
    c.rect(15, 10, 19, 7, P.indigo0)
    c.hline(16, 32, 9, P.indigo0)
    c.hline(16, 32, 10, P.indigo0)
    c.hline(14, 34, 16, P.wall0)           # band
    c.hline(14, 34, 17, P.black)           # short brim, level with the band
    c.hline(15, 33, 18, P.wall0)
    c.pixel(14, 17, P.indigo0)
    c.pixel(34, 17, P.indigo0)
    c.hline(16, 32, 11, P.indigo1)         # faint crown sheen
    c.rect(23, 13, 2, 2, P.gray)           # small dull badge
    # hair edges under the cap
    paint(c, lambda x, y: in_head(x, y) and y <= 21 and (x <= 15 or x >= 33), P.hair)
    # peak shadow across the eyes, then the eyes
    c.hline(16, 32, 20, P.skin_lo)
    eyes_dark(c, (22, 23))
    nose(c)
    # firm, proud mouth
    c.hline(23, 25, 31, P.dkred)
    c.pixel(26, 32, P.skin_lo)
    c.outline(P.dkbrown)
    return c


# ------------------------------------------------------------------ main
GENERATORS = [
    ("brother", brother),
    ("chen", chen),
    ("xiaoding", xiaoding),
    ("zhang", zhang),
    ("wangshan", wangshan),
    ("li", li),
]


def main():
    paths = []
    for name, fn in GENERATORS:
        rel = "%s/%s.png" % (OUT_DIR, name)
        fn().save(rel)
        paths.append(rel)
    out = preview(paths, "art/_preview/portraits_a.png", scale=4)
    print("wrote", len(paths), "portraits; preview:", out)


if __name__ == "__main__":
    main()
