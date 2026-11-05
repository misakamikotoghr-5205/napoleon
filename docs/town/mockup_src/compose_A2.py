"""MOCKUP A2: 德厚当 interior, Stardew-like 3/4 top-down + portrait dialogue box.

native 427x240, x3 NEAREST -> 1281x720, cropped to 1280x720. UI drawn at full res.
    python3 compose_A2.py   ->  A2_pawnshop_interior_topdown.png (+ _native.png)
New interior props are also exported to assets/props/A2_*.png for reuse.
"""
import math
import os
import random
from PIL import Image, ImageDraw

from pix import Cv, C, ASSETS, HERE, mix, alpha, font, font_mask, scale, ZEN, UNIFONT, CLEAR, REPO
import compose_A1 as A1

NW, NH, K = 427, 240, 3
VOID = (16, 11, 9, 255)

# room geometry (native px)
RX0, RX1 = 22, 405          # outer edges of the side-wall strips
FX0, FX1 = 29, 398          # floor x range (inclusive)
CAP_Y = 4                   # top of back-wall cap
BW_TOP, BW_BOT = 10, 54     # back wall face rows (inclusive)
FLOOR_Y0 = 55
BOT_Y = 150                 # bottom wall strip top row
BOT_H = 7
DX0, DX1 = 116, 147         # front door gap (inclusive)
# counter (高柜台)
CX0, CX1 = FX0, 318
CG_BACK, CG_FRONT = 100, 108        # footprint rows (ground)
CH = 22                             # counter height
CT0, CT1 = CG_BACK - CH, CG_FRONT - CH   # top surface rows 78..86
GATE_X0, GATE_X1 = 322, 352         # swing half-gate
CX2 = 356                           # short counter section to the right wall

PROPS = os.path.join(ASSETS, "props")


def A(*p):
    return os.path.join(ASSETS, *p)


def load(*p):
    return Image.open(A(*p)).convert("RGBA")


def save_prop(cv, name):
    cv.save(os.path.join(PROPS, "A2_" + name + ".png"))
    return cv


# ====================================================================== floor
def wood_floor(c, x0, y0, x1, y1, seed, tone=0.0, plank=4):
    """Horizontal floorboards: plank rows of `plank` px + 1px seam, staggered butt joints."""
    rnd = random.Random(seed)
    bases = [mix(C.wood2, C.wood3, t) for t in (0.30, 0.45, 0.55, 0.38, 0.65, 0.48)]
    if tone:
        bases = [mix(b, C.wood1 if tone < 0 else C.tan, abs(tone)) for b in bases]
    y = y0
    while y <= y1:
        x = x0 - rnd.randint(0, 30)
        while x <= x1:
            L = rnd.randint(22, 46)
            base = rnd.choice(bases)
            hi = mix(base, C.tan, 0.35)
            gr = mix(base, C.wood1, 0.32)
            for yy in range(y, min(y + plank, y1 + 1)):
                for xx in range(max(x, x0), min(x + L, x1 + 1)):
                    col = base
                    if yy == y:
                        col = mix(base, hi, 0.45)
                    if yy == y + plank - 1:
                        col = mix(base, gr, 0.5)
                    r = rnd.random()
                    if r < 0.05:
                        col = gr
                    elif r < 0.07:
                        col = hi
                    c.put(xx, yy, col)
            # grain streak
            if rnd.random() < 0.7:
                gy = y + rnd.randint(1, plank - 2)
                gx = x + rnd.randint(2, max(3, L - 12))
                for xx in range(gx, gx + rnd.randint(5, 11)):
                    if x0 <= xx <= x1:
                        c.put(xx, gy, gr)
            # knot
            if rnd.random() < 0.18:
                kx = x + rnd.randint(4, max(5, L - 5))
                ky = y + rnd.randint(1, plank - 2)
                if x0 <= kx <= x1:
                    c.put(kx, ky, C.wood1)
                    c.put(kx + 1, ky, mix(C.wood1, base, 0.5))
            # butt joint + nails
            jx = x + L
            if x0 <= jx <= x1:
                for yy in range(y, min(y + plank, y1 + 1)):
                    c.put(jx, yy, C.wood0)
                if jx + 1 <= x1:
                    c.put(jx + 1, y + 1, mix(base, C.tan, 0.4))
                for nx in (jx - 2, jx + 2):
                    if x0 <= nx <= x1 and y + 1 <= y1:
                        c.put(nx, y + 1, C.dkbrown)
            x += L + 1
        sy = y + plank
        if sy <= y1:
            for xx in range(x0, x1 + 1):
                c.put(xx, sy, C.wood0 if (xx * 7 + sy) % 11 else C.dkbrown)
        y += plank + 1


def worn_path(c, pts, width, amt=0.13):
    """Lighten floor along a polyline (foot traffic)."""
    for y in range(FLOOR_Y0, BOT_Y):
        for x in range(FX0, FX1 + 1):
            best = 1e9
            for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                vx, vy = bx - ax, by - ay
                t = max(0, min(1, ((x - ax) * vx + (y - ay) * vy) / float(vx * vx + vy * vy)))
                d = math.hypot(x - (ax + t * vx), (y - (ay + t * vy)) * 1.6)
                best = min(best, d)
            if best < width:
                f = (1 - best / width) * amt
                p = c.get(x, y)
                c.put(x, y, mix(p, C.tan, f))


# ====================================================================== props
def bundle(cloth, dark, hi, tag=True, w=9, h=7, dots=None, seed=0):
    """包袱: square-ish cloth bundle, folds converging on a top knot; optional pawn tag."""
    rnd = random.Random(seed)
    c = Cv(w + 2, h + 4)
    top, bot = 3, h + 2
    for y in range(top, bot + 1):
        inset = 1 if y in (top, bot) else 0
        for x in range(inset, w + 1 - inset):
            col = cloth
            if x <= 1 or y == top:
                col = hi
            if x >= w - 1 or y == bot:
                col = dark
            c.put(x, y, col)
    kx = w // 2
    # folds from the knot to the lower corners
    for i in range(1, h):
        y = top + i
        if y >= bot:
            break
        c.put(kx - 1 - (i * (kx - 1)) // h, y, dark)
        c.put(kx + 1 + (i * (w - kx - 2)) // h, y, dark)
    # knot + ears
    c.put(kx, top - 1, dark); c.put(kx, top, dark)
    c.put(kx - 1, top - 1, cloth); c.put(kx - 2, top - 2, hi); c.put(kx - 3, top - 3, hi)
    c.put(kx + 1, top - 1, cloth); c.put(kx + 2, top - 2, cloth); c.put(kx + 3, top - 3, dark)
    if dots:
        for _ in range(5):
            x, y = rnd.randint(1, w - 1), rnd.randint(top + 1, bot - 1)
            c.put(x, y, dots)
    c.outline(C.dkbrown)
    if tag:
        tx = min(w - 1, max(1, w // 2 + rnd.randint(-2, 2)))
        c.put(tx, bot + 1, C.paper_hi); c.put(tx + 1, bot + 1, C.paper_hi)
        c.put(tx, bot + 2, C.paper_hi); c.put(tx + 1, bot + 2, C.seal_red)
    return c


def vase(body=None, pat=None):
    body = body or C.ww0
    pat = pat or C.indigo2
    rows = ["..nn..", ".nnnn.", "..bb..", ".bbbb.", "bbbbbb", "bbbbbb", "bbbbbb", ".bbbb.", "..bb..", ".bbbb."]
    c = Cv(6, 10)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "n":
                c.put(x, y, body)
            elif ch == "b":
                c.put(x, y, body)
    for (x, y) in ((1, 4), (3, 5), (4, 4), (2, 6), (4, 6), (2, 1), (3, 1), (1, 9), (4, 9)):
        c.put(x, y, pat)
    c.put(1, 5, C.white)
    c.vline(5, 4, 6, C.ww2)
    c.outline(C.dkbrown)
    return c


def desk_clock():
    c = Cv(7, 9)
    c.rect(0, 1, 7, 8, C.wood1)
    c.hline(1, 5, 0, C.wood2)
    c.ellipse(3, 4, 2.2, 2.2, C.paper_hi)
    c.put(3, 4, C.dkbrown); c.put(3, 3, C.dkbrown); c.put(4, 4, C.dkbrown)
    c.hline(0, 6, 8, C.wood0)
    c.vline(0, 1, 7, C.wood2)
    c.outline(C.dkbrown)
    return c


def gramophone():
    c = Cv(13, 13)
    c.rect(1, 8, 9, 4, C.wood2)
    c.hline(1, 9, 8, C.wood3)
    c.hline(1, 9, 11, C.wood1)
    c.rect(4, 6, 2, 2, C.gold)
    c.line(5, 6, 8, 3, C.gold)
    # horn
    c.ellipse(9.5, 2.5, 3, 2.5, C.gold)
    c.ellipse(10, 2.5, 1.8, 1.4, C.wood1)
    c.put(8, 1, C.lamp)
    c.put(2, 9, C.wood0); c.put(3, 9, C.wood0)
    c.outline(C.dkbrown)
    return c


def birdcage():
    c = Cv(9, 12)
    c.ellipse(4, 5, 4, 5, C.tan, filled=False)
    for x in (1, 3, 5, 7):
        c.vline(x, 2, 10, C.tan)
    c.hline(0, 8, 10, C.wood2)
    c.hline(0, 8, 11, C.wood1)
    c.put(4, 0, C.wood2); c.put(4, 1, C.tan)
    c.put(4, 7, C.lamp); c.put(5, 7, C.lamp); c.put(4, 6, C.flame)
    c.outline(C.dkbrown)
    return c


def books(cols=None):
    cols = cols or [C.indigo1, C.indigo2, C.wood2]
    c = Cv(9, 6)
    for i, col in enumerate(cols):
        y = 4 - i * 2 if i < 3 else 0
        c.rect(i % 2, y, 8, 2, col)
        c.hline(i % 2, i % 2 + 7, y, mix(col, C.white, 0.25))
        c.put(i % 2 + 6, y + 1, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def lacquer_box():
    c = Cv(9, 6)
    c.rect(0, 1, 9, 5, C.seal_red)
    c.hline(0, 8, 0, C.lantern_hi)
    c.hline(0, 8, 2, C.gold)
    c.hline(0, 8, 5, C.dkred)
    c.put(4, 3, C.gold)
    c.outline(C.dkbrown)
    return c


def handwarmer():
    c = Cv(8, 7)
    c.ellipse(3.5, 4, 3.5, 2.6, C.gold)
    c.ellipse(3, 3.5, 2, 1.2, C.lamp)
    c.hline(1, 6, 1, C.gold)
    c.put(1, 0, C.gold); c.put(6, 0, C.gold); c.hline(2, 5, 0, C.wood2)
    c.hline(1, 6, 6, C.wood2)
    c.put(2, 3, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def teapot():
    c = Cv(9, 6)
    c.ellipse(4, 3.5, 3, 2.2, C.dkred)
    c.ellipse(3.4, 3, 1.6, 1, mix(C.dkred, C.flame, 0.35))
    c.put(4, 1, C.dkred); c.put(4, 0, C.wood1)
    c.put(8, 2, C.dkred); c.put(7, 3, C.dkred)
    c.put(0, 3, C.dkred); c.put(0, 2, C.dkred)
    c.outline(C.dkbrown)
    return c


def scrolls():
    c = Cv(12, 5)
    for i, (y, col) in enumerate(((0, C.paper), (2, C.paper_old))):
        c.hline(1, 10, y + 1, col)
        c.hline(1, 10, y + 2, mix(col, C.wood1, 0.25))
        c.put(0, y + 1, C.wood1); c.put(11, y + 1, C.wood1)
        c.put(0, y + 2, C.wood0); c.put(11, y + 2, C.wood0)
    c.outline(C.dkbrown)
    return c


def bronze_ding():
    c = Cv(9, 8)
    c.rect(1, 2, 7, 4, C.moss)
    c.hline(1, 7, 2, mix(C.moss, C.jade_hi, 0.5))
    c.put(1, 0, C.moss); c.put(1, 1, C.moss); c.put(7, 0, C.moss); c.put(7, 1, C.moss)
    c.put(2, 6, C.moss); c.put(6, 6, C.moss); c.put(4, 6, C.moss)
    c.put(2, 7, C.g0); c.put(6, 7, C.g0); c.put(4, 7, C.g0)
    c.hline(2, 6, 4, C.g1)
    c.outline(C.dkbrown)
    return c


def felt_hat():
    c = Cv(10, 5)
    c.rect(2, 0, 6, 3, C.hair)
    c.hline(3, 6, 0, C.gray)
    c.hline(2, 7, 2, C.wood1)
    c.hline(0, 9, 3, C.hair)
    c.hline(1, 8, 4, C.rf0)
    c.outline(C.dkbrown)
    return c


def jar(col=None):
    col = col or C.wood2
    c = Cv(7, 8)
    c.ellipse(3, 4.5, 3, 3, col)
    c.ellipse(2.4, 3.8, 1.2, 1.3, mix(col, C.paper_hi, 0.35))
    c.rect(2, 0, 3, 2, col)
    c.hline(1, 5, 0, C.seal_red)
    c.rect(2, 4, 3, 3, C.seal_red)  # red paper label
    c.put(3, 5, C.lamp)
    c.outline(C.dkbrown)
    return c


def clock_wall():
    """挂钟 pendulum wall clock."""
    c = Cv(11, 22)
    c.rect(1, 2, 9, 19, C.wood1)
    c.rect(0, 0, 11, 3, C.wood2)
    c.hline(0, 10, 0, C.wood3)
    c.rect(2, 3, 7, 7, C.wood0)
    c.ellipse(5, 6, 3, 3, C.paper_hi)
    c.put(5, 6, C.dkbrown); c.put(5, 5, C.dkbrown); c.put(5, 4, C.dkbrown); c.put(6, 6, C.dkbrown)
    c.rect(3, 11, 5, 8, C.wood0)
    c.rect(4, 12, 3, 6, mix(C.wood0, C.lamp_pale, 0.15))
    c.vline(5, 12, 15, C.gold)
    c.ellipse(5, 16.5, 1.2, 1.2, C.lamp)
    c.hline(1, 9, 20, C.wood0)
    c.vline(1, 2, 19, C.wood2)
    c.outline(C.dkbrown)
    return c


def calendar_poster():
    """月份牌: 1930s calendar poster (lady in qipao) with tear-off date pad."""
    c = Cv(19, 32)
    # string + nail
    c.line(9, 0, 3, 4, C.wood1); c.line(9, 0, 15, 4, C.wood1); c.put(9, 0, C.gold)
    # poster
    c.rect(1, 4, 17, 27, C.paper_hi)
    c.rect(2, 5, 15, 17, mix(C.lamp_pale, C.flower, 0.12))
    # painted backdrop: willow green bottom-left, sky
    c.rect(2, 5, 15, 7, mix(C.wa4, C.paper_hi, 0.45))
    for x in range(2, 7):
        c.vline(x, 9, 20 - (x % 3), mix(C.g3, C.paper_hi, 0.3))
    # lady: hair bun, face, red qipao
    c.rect(9, 7, 4, 2, C.hair); c.put(13, 7, C.hair); c.put(13, 8, C.hair)
    c.rect(9, 9, 4, 3, C.skin_hi); c.put(10, 10, C.dkbrown); c.put(12, 10, C.dkbrown); c.put(11, 11, C.seal_red)
    c.vline(8, 8, 12, C.hair)
    c.rect(8, 12, 6, 10, C.seal_red)
    c.vline(8, 12, 21, C.lantern_hi)
    c.vline(13, 13, 21, C.dkred)
    c.put(10, 12, C.gold); c.put(11, 13, C.gold)
    c.rect(7, 14, 2, 4, C.skin_hi)  # arm
    c.put(14, 15, C.skin_hi); c.put(15, 16, C.lamp)  # fan
    c.put(15, 15, C.lamp); c.put(16, 16, C.lamp)
    # title band
    c.rect(2, 22, 15, 2, C.dkred)
    for x in range(3, 16, 2):
        c.put(x, 22, C.gold)
    # tear-off date pad
    c.rect(5, 25, 9, 6, C.white)
    c.rect(5, 25, 9, 2, C.seal_red)
    c.put(8, 28, C.seal_red); c.put(9, 28, C.seal_red); c.put(9, 29, C.seal_red); c.put(10, 29, C.seal_red)
    c.put(8, 29, C.dkred)
    c.hline(5, 13, 30, C.fog)
    # roller rods
    c.hline(0, 18, 4, C.wood1); c.hline(0, 18, 31, C.wood1)
    c.outline(C.dkbrown)
    return c


def abacus():
    """算盘 lying on the counter (3/4 squashed)."""
    c = Cv(24, 8)
    c.rect(0, 0, 24, 8, C.wood1)
    c.rect(1, 1, 22, 6, C.dkbrown)
    c.hline(1, 22, 3, C.wood2)       # beam
    rnd = random.Random(3)
    for i, x in enumerate(range(2, 22, 2)):
        up = rnd.random() < 0.35
        c.put(x, 1 if not up else 2, C.wood3)
        for k in range(2):
            yy = 4 + k + (1 if rnd.random() < 0.5 else 0)
            c.put(x, min(6, yy), C.wood3)
        c.put(x + 1, 5, C.wood0)
    c.hline(0, 23, 0, C.wood3)
    c.vline(0, 0, 7, C.wood2)
    c.outline(C.dkbrown)
    return c


def ledger_open():
    c = Cv(16, 8)
    c.rect(0, 1, 16, 7, C.indigo1)
    c.rect(1, 0, 7, 7, C.paper_hi)
    c.rect(8, 0, 7, 7, C.paper)
    c.vline(8, 0, 6, C.paper_old)
    for y in (2, 4):
        c.hline(2, 6, y, C.gray)
        c.hline(10, 13, y, C.gray)
    c.put(3, 6, C.seal_red); c.put(4, 6, C.seal_red)
    c.outline(C.dkbrown)
    return c


def ledger_stack():
    c = Cv(12, 9)
    for i, col in enumerate((C.indigo1, C.indigo2, C.indigo1)):
        y = 6 - i * 3
        c.rect(0, y, 11, 3, col)
        c.hline(0, 10, y, mix(col, C.white, 0.3))
        c.vline(10, y, y + 2, C.paper)
        c.put(2, y + 1, C.paper_hi); c.put(3, y + 1, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def oil_lamp():
    c = Cv(9, 16)
    c.rect(2, 12, 5, 3, C.gold)
    c.hline(1, 7, 15, C.wood2)
    c.hline(2, 6, 12, C.lamp)
    c.ellipse(4, 10, 2.6, 2, C.gold)
    c.put(3, 9, C.lamp)
    # chimney glass
    c.rect(3, 2, 3, 6, mix(C.fog, C.lamp_pale, 0.6))
    c.vline(3, 2, 7, C.white)
    c.rect(2, 4, 5, 3, mix(C.fog, C.lamp_pale, 0.6))
    c.put(4, 5, C.lamp); c.put(4, 4, C.flame); c.put(4, 6, C.flame)
    c.hline(3, 5, 1, C.wood1)
    c.hline(2, 6, 8, C.gold)
    c.outline(C.dkbrown)
    return c


def magnifier():
    c = Cv(10, 6)
    c.ellipse(2.5, 2.5, 2.5, 2.2, C.gold)
    c.ellipse(2.5, 2.5, 1.5, 1.2, mix(C.fog, C.white, 0.5))
    c.put(2, 2, C.white)
    c.line(5, 3, 9, 5, C.wood2)
    c.put(9, 5, C.wood1)
    c.outline(C.dkbrown)
    return c


def inkstone_brush():
    c = Cv(12, 6)
    c.rect(0, 2, 6, 4, C.rf1)
    c.rect(1, 3, 3, 2, C.black)
    c.hline(0, 5, 2, C.rf3)
    c.line(7, 1, 11, 4, C.wood3)
    c.put(7, 1, C.hair); c.put(6, 0, C.hair)
    c.outline(C.dkbrown)
    return c


def seal_pad():
    c = Cv(10, 6)
    c.ellipse(2.5, 3.5, 2.5, 2, C.seal_red)
    c.put(2, 3, C.lantern_hi)
    c.rect(6, 0, 3, 5, C.jade)
    c.vline(6, 0, 4, C.jade_hi)
    c.hline(6, 8, 5, C.seal_red)
    c.outline(C.dkbrown)
    return c


def teacup():
    c = Cv(5, 4)
    c.rect(0, 1, 5, 3, C.ww0)
    c.hline(0, 4, 0, C.ww1)
    c.hline(1, 3, 1, C.dirt2)
    c.put(1, 2, C.indigo2); c.put(3, 3, C.indigo2)
    c.outline(C.dkbrown)
    return c


def ticket_spike():
    """当票 pawn tickets impaled on a spike."""
    c = Cv(6, 10)
    for i, y in enumerate((5, 3, 1)):
        c.rect(0 + (i % 2), y, 5, 3, C.paper if i % 2 else C.paper_hi)
        c.put(1 + (i % 2), y + 1, C.seal_red)
    c.vline(3, 0, 8, C.wall1)
    c.rect(1, 8, 5, 2, C.wood1)
    c.outline(C.dkbrown)
    return c


def open_bundle_bracelets():
    """周妈's 蓝印花布 bundle untied on the counter, two silver bracelets on it."""
    c = Cv(28, 11)
    c.poly([(2, 3), (25, 1), (27, 7), (22, 10), (4, 10), (0, 7)], C.indigo1)
    c.poly([(3, 4), (24, 2), (25, 6), (6, 8)], C.indigo2)
    rnd = random.Random(8)
    for _ in range(16):
        x, y = rnd.randint(1, 26), rnd.randint(1, 9)
        if c.get(x, y)[3]:
            c.put(x, y, C.ww1)
    for (x, y) in ((3, 7), (4, 6), (4, 8), (5, 7), (23, 4), (24, 3), (24, 5), (25, 4)):
        c.put(x, y, C.ww0)
    # bracelets: two bright silver rings (outer ring + inner hole)
    for bx in (8, 15):
        c.ellipse(bx + 2.5, 5.2, 3.4, 2.4, C.silver)
        c.ellipse(bx + 2.5, 5.2, 1.8, 1.0, C.indigo0)
        c.hline(bx + 1, bx + 3, 3, C.white)
        c.put(bx, 4, C.white)
        c.hline(bx + 2, bx + 4, 7, C.wall2)
        c.put(bx + 5, 6, C.wall2)
    c.outline(C.dkbrown)
    # sparkle
    c.put(13, 0, C.white)
    return c


def clothes_rack():
    """衣架 with pawned garments: a fur-collared coat and a red qipao."""
    c = Cv(34, 40)
    # frame
    c.rect(0, 1, 34, 2, C.wood1); c.hline(0, 33, 1, C.wood3)
    c.put(0, 0, C.wood2); c.put(33, 0, C.wood2)
    c.vline(2, 3, 39, C.wood1); c.vline(31, 3, 39, C.wood1)
    c.vline(3, 3, 39, C.wood0); c.vline(30, 3, 39, C.wood0)
    c.rect(0, 37, 6, 3, C.wood1); c.rect(28, 37, 6, 3, C.wood1)
    # coat (dark wool with fur collar)
    c.poly([(5, 4), (15, 4), (17, 30), (3, 30)], C.wall1)
    c.vline(10, 6, 29, C.wall0)
    c.vline(5, 5, 29, C.wall2)
    for (x, y) in ((6, 4), (7, 5), (9, 5), (11, 5), (13, 4), (14, 5), (8, 6), (12, 6)):
        c.put(x, y, C.tabby2)
    c.hline(5, 14, 4, C.tabby1)
    c.put(9, 12, C.gold); c.put(9, 17, C.gold); c.put(9, 22, C.gold)
    # qipao
    c.poly([(19, 4), (28, 4), (28, 9), (27, 33), (20, 33), (19, 9)], C.seal_red)
    c.vline(19, 5, 32, C.lantern_hi)
    c.vline(27, 9, 32, C.dkred)
    c.hline(21, 26, 4, C.gold)
    c.line(23, 5, 26, 9, C.gold)
    for (x, y) in ((22, 14), (24, 18), (21, 22), (25, 25)):
        c.put(x, y, C.lamp)
    # paper tags
    c.rect(15, 14, 2, 3, C.paper_hi); c.put(16, 16, C.seal_red)
    c.rect(26, 26, 2, 3, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def half_gate(w):
    """腰门: low swing gate in the counter line."""
    c = Cv(w, 16)
    c.rect(0, 2, w, 13, C.wood1)
    c.hline(0, w - 1, 2, C.wood3)
    c.hline(0, w - 1, 3, C.wood2)
    for x in range(2, w - 1, 3):
        c.vline(x, 5, 13, C.wood0)
        c.vline(x + 1, 5, 13, C.wood2)
    c.hline(0, w - 1, 9, C.wood1)
    c.hline(0, w - 1, 14, C.wood0)
    c.rect(0, 0, 2, 16, C.wood2); c.rect(w - 2, 0, 2, 16, C.wood1)
    c.put(0, 0, C.tan); c.put(w - 1, 0, C.wood3)
    c.put(w - 5, 8, C.gold); c.put(w - 5, 9, C.gold)
    c.outline(C.dkbrown)
    return c


def umbrella():
    c = Cv(5, 18)
    c.poly([(2, 1), (4, 4), (3, 14), (1, 14), (0, 4)], C.tan)
    c.vline(1, 3, 13, C.lamp_pale)
    c.vline(3, 4, 13, C.wood3)
    c.hline(1, 3, 6, C.seal_red); c.hline(1, 3, 11, C.seal_red)
    c.vline(2, 14, 17, C.wood1)
    c.put(2, 0, C.wood1)
    c.outline(C.dkbrown)
    return c


def broom():
    c = Cv(8, 22)
    c.vline(5, 0, 12, C.tan)
    c.vline(6, 0, 12, C.wood2)
    c.poly([(3, 12), (8, 12), (7, 21), (0, 21)], C.gold)
    for x in range(1, 7, 2):
        c.line(x + 3 - x // 2, 13, x, 21, mix(C.gold, C.wood2, 0.5))
    c.hline(3, 7, 13, C.wood1)
    c.outline(C.dkbrown)
    return c


def potted_bamboo():
    c = Cv(14, 26)
    rnd = random.Random(11)
    for sx in (5, 7, 9):
        c.vline(sx, 3 + (sx % 3), 18, C.g2)
        for y in range(6, 18, 4):
            c.put(sx, y, C.g1)
    for _ in range(26):
        x, y = rnd.randint(1, 12), rnd.randint(0, 14)
        c.put(x, y, rnd.choice([C.g3, C.g4, C.g2]))
        c.put(x + 1, y, C.g2)
    c.rect(3, 18, 8, 7, C.indigo2)
    c.hline(2, 11, 18, C.ww0)
    c.hline(2, 11, 19, C.ww1)
    c.vline(3, 20, 24, C.blue_hi)
    c.vline(10, 20, 24, C.indigo1)
    c.put(5, 21, C.ww0); c.put(7, 22, C.ww0); c.put(8, 21, C.ww0)
    c.outline(C.dkbrown)
    return c


def spittoon():
    c = Cv(8, 7)
    c.ellipse(3.5, 4, 3.4, 2.6, C.gold)
    c.ellipse(3.5, 1.5, 3.2, 1.2, C.lamp)
    c.ellipse(3.5, 1.5, 1.6, 0.6, C.wood1)
    c.put(1, 4, C.lamp)
    c.outline(C.dkbrown)
    return c


def strongbox():
    c = Cv(22, 16)
    c.rect(0, 3, 22, 13, C.wood1)
    c.rect(0, 0, 22, 4, C.wood2)
    c.hline(0, 21, 0, C.wood3)
    for x in (3, 18):
        c.vline(x, 0, 15, C.wall1)
    c.hline(0, 21, 4, C.wall1)
    c.rect(9, 7, 4, 4, C.gold)
    c.put(10, 8, C.dkbrown); c.put(10, 9, C.dkbrown)
    c.hline(0, 21, 15, C.wood0)
    c.outline(C.dkbrown)
    return c


def door_mat(w=26, h=8):
    c = Cv(w, h)
    for y in range(h):
        for x in range(w):
            col = C.dirt2 if (x // 2 + y) % 2 else C.dirt3
            col = mix(col, C.wood2, 0.25)
            c.put(x, y, col)
    c.frame(0, 0, w, h, C.wood2)
    for x in range(1, w - 1, 3):
        c.put(x, h - 1, C.dirt2)
    return c


def ladder(h=44):
    c = Cv(12, h)
    for i in range(h):
        lx = 1 + (i * 3) // h          # leaning: top further left
        c.put(lx, i, C.wood3); c.put(lx + 1, i, C.wood2)
        c.put(lx + 8, i, C.wood2); c.put(lx + 9, i, C.wood1)
        if i % 6 == 3:
            c.hline(lx + 2, lx + 7, i, C.wood3)
            c.hline(lx + 2, lx + 7, i + 1, C.wood1)
    c.outline(C.dkbrown)
    return c


def trunk(w=18, h=10, col=None):
    """樟木箱 camphor-wood trunk with brass corners."""
    col = col or C.wood3
    c = Cv(w, h)
    c.rect(0, 2, w, h - 2, col)
    c.rect(0, 0, w, 3, mix(col, C.tan, 0.35))
    c.hline(0, w - 1, 0, mix(col, C.paper_hi, 0.35))
    c.hline(0, w - 1, 3, C.wood1)
    c.hline(0, w - 1, h - 1, C.wood1)
    c.vline(w - 1, 2, h - 1, C.wood1)
    for (x, y) in ((0, 3), (w - 1, 3), (0, h - 1), (w - 1, h - 1)):
        c.put(x, y, C.gold)
    c.rect(w // 2 - 1, 4, 3, 3, C.gold)
    c.put(w // 2, 5, C.dkbrown)
    c.outline(C.dkbrown)
    return c


def quilts():
    """Pile of folded quilts (被褥) - the most common pledge in winter."""
    c = Cv(20, 12)
    for i, (col, hi) in enumerate(((C.indigo1, C.indigo2), (C.seal_red, C.lantern_hi), (C.ww1, C.ww0), (C.jade, C.jade_hi))):
        y = 9 - i * 3
        c.rect(i % 2, y, 19, 3, col)
        c.hline(i % 2, 18 + i % 2 - 1, y, hi)
        c.put(18 - i % 2, y + 1, mix(col, C.black, 0.3))
    c.rect(4, 0, 2, 3, C.paper_hi); c.put(5, 2, C.seal_red)
    c.outline(C.dkbrown)
    return c


def floor_vase():
    c = Cv(9, 16)
    rows = ["..nnnnn..", "...nnn...", "...nnn...", "..bbbbb..", ".bbbbbbb.", "bbbbbbbbb", "bbbbbbbbb", "bbbbbbbbb",
            "bbbbbbbbb", ".bbbbbbb.", ".bbbbbbb.", "..bbbbb..", "..bbbbb..", "...bbb...", "..bbbbb..", "..bbbbb.."]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in "nb":
                c.put(x, y, C.ww0)
    for (x, y) in ((2, 5), (3, 6), (5, 5), (6, 7), (4, 8), (2, 8), (6, 9), (3, 10), (5, 11), (3, 0), (5, 0), (3, 14), (5, 15)):
        c.put(x, y, C.indigo2)
    c.hline(1, 7, 6, C.indigo1)
    c.vline(1, 5, 9, C.white)
    c.vline(8, 5, 8, C.ww2); c.vline(7, 9, 11, C.ww2)
    c.outline(C.dkbrown)
    return c


def counter_rail(c):
    """Wooden railing (栅栏) along the back edge of the high counter, open at the service window."""
    top = CT0 - 13
    WIN0, WIN1 = 184, 238
    L0 = mix(C.dkbrown, C.wood0, 0.45)
    segs = [(CX0 + 1, WIN0), (WIN1, CX1 - 1)]
    for (a, b) in segs:
        for x in range(a, b + 1, 7):
            c.vline(x, top + 2, CT0, L0)
            c.vline(x + 1, top + 2, CT0, C.wood1)
        c.rect(a, top, b - a + 2, 3, L0)
        c.hline(a, b + 1, top, C.wood2)
        c.hline(a, b + 1, top + 2, C.black)
    # service window frame posts (taller) + little hanging sign
    for x in (WIN0, WIN1):
        c.rect(x, top - 4, 3, CT0 - top + 4, L0)
        c.vline(x, top - 4, CT0, C.wood2)
        c.put(x + 1, top - 5, C.gold)


# ====================================================================== room
def back_wall(c):
    rnd = random.Random(21)
    # plaster
    for y in range(BW_TOP, BW_BOT + 1):
        for x in range(FX0, FX1 + 1):
            col = C.ww1
            r = rnd.random()
            if r < 0.06:
                col = C.ww2
            elif r < 0.08:
                col = C.ww0
            # slight shade toward the floor
            if y > BW_BOT - 8:
                col = mix(col, C.ww3, (y - (BW_BOT - 8)) / 10.0)
            c.put(x, y, col)
    # damp stains near corners
    for (sx, sy, rr) in ((FX0 + 3, BW_TOP + 6, 6), (FX1 - 5, BW_TOP + 8, 7), (176, BW_TOP + 3, 4)):
        for y in range(sy - rr, sy + rr):
            for x in range(sx - rr, sx + rr):
                if math.hypot(x - sx, (y - sy) * 1.4) < rr and rnd.random() < 0.55:
                    if BW_TOP <= y <= BW_BOT and FX0 <= x <= FX1:
                        c.put(x, y, mix(c.get(x, y), C.paper_old, 0.35))
    # wainscot (lower wall boards)
    wy = BW_BOT - 9
    for y in range(wy, BW_BOT + 1):
        for x in range(FX0, FX1 + 1):
            col = C.wood1 if (x - FX0) % 6 else C.wood0
            if (x - FX0) % 6 == 1:
                col = C.wood2
            c.put(x, y, col)
    c.hline(FX0, FX1, wy - 1, C.wood3)
    c.hline(FX0, FX1, wy, C.wood2)
    c.hline(FX0, FX1, BW_BOT, C.wood0)
    # ceiling beam + wall cap
    c.rect(FX0, BW_TOP, FX1 - FX0 + 1, 3, C.wood1)
    c.hline(FX0, FX1, BW_TOP, C.wood2)
    c.hline(FX0, FX1, BW_TOP + 3, mix(C.ww1, C.ww3, 0.6))  # beam shadow on plaster
    c.hline(FX0, FX1, BW_TOP + 4, mix(C.ww1, C.ww3, 0.3))
    # posts (柱) dividing wall bays
    for px in (FX0, 172, 254, 340, FX1 - 2):
        c.rect(px, BW_TOP, 3, BW_BOT - BW_TOP + 1, C.wood1)
        c.vline(px, BW_TOP, BW_BOT, C.wood2)
        c.vline(px + 2, BW_TOP, BW_BOT, C.wood0)
        c.vline(px + 3, BW_TOP + 3, BW_BOT, mix(C.ww1, C.ww3, 0.5))


def shelf_unit(c, x, w, seed, fill):
    """Tall 货架 against the back wall. fill(c, x, w, shelf_y_list) places goods."""
    top = BW_TOP + 3
    bot = BW_BOT
    # back panel (dark so goods pop)
    c.rect(x, top, w, bot - top + 1, C.wood0)
    c.dither(x + 2, top + 2, w - 4, bot - top - 3, C.wood0, C.dkbrown, 0.3)
    boards = [top + 12, top + 23, top + 34]   # board rows (item baseline = board-1)
    # cornice
    c.rect(x - 1, top - 1, w + 2, 3, C.wood2)
    c.hline(x - 1, x + w, top - 1, C.wood3)
    c.hline(x - 1, x + w, top + 1, C.wood1)
    # side posts
    for px in (x, x + w - 2):
        c.rect(px, top, 2, bot - top + 1, C.wood1)
    c.vline(x, top, bot, C.wood2)
    c.vline(x + w - 1, top, bot, C.wood0)
    # middle divider
    mid = x + w // 2
    c.vline(mid, top + 2, bot, C.wood1)
    c.vline(mid + 1, top + 2, bot, C.wood0)
    # goods first (boards drawn over their feet)
    fill(c, x, w, [b - 1 for b in boards], top)
    for b in boards:
        c.hline(x, x + w - 1, b, C.wood3)
        c.hline(x, x + w - 1, b + 1, C.wood1)
        c.hline(x + 2, x + w - 3, b + 2, C.dkbrown)   # shadow under board
    # base drawer row
    c.rect(x, bot - 6, w, 7, C.wood1)
    c.hline(x, x + w - 1, bot - 6, C.wood3)
    for dx in range(x + 3, x + w - 6, 12):
        c.rect(dx, bot - 4, 9, 3, C.wood2)
        c.hline(dx, dx + 8, bot - 4, C.wood3)
        c.put(dx + 4, bot - 3, C.gold)
    c.hline(x, x + w - 1, bot, C.dkbrown)
    # cast shadow on wall to the right (light from top-left)
    for y in range(top + 1, bot + 1):
        p = c.get(x + w, y)
        c.put(x + w, y, mix(p, C.black, 0.35))
        p = c.get(x + w + 1, y)
        c.put(x + w + 1, y, mix(p, C.black, 0.15))


def place_on(c, item, x, base_y):
    im = item.img if isinstance(item, Cv) else item
    c.blit(im, x, base_y - im.height + 1)


def fill_left(c, x, w, shelves, top):
    s0, s1, s2 = shelves
    rnd = random.Random(1)
    # top shelf: bundles (most pawned goods are clothes wrapped in cloth)
    xx = x + 3
    for i, (cl, dk, hi, dots) in enumerate([
            (C.indigo2, C.indigo1, C.blue_hi, C.ww0), (C.wood3, C.wood2, C.tan, None), (C.indigo1, C.indigo0, C.indigo2, C.ww1),
            (C.seal_red, C.dkred, C.lantern_hi, None)]):
        b = bundle(cl, dk, hi, w=9, h=6, dots=dots, seed=i)
        place_on(c, b, xx, s0 + 2)
        xx += 11
    place_on(c, vase(), xx + 1, s0)
    place_on(c, desk_clock(), xx + 9, s0)
    place_on(c, bundle(C.indigo2, C.indigo1, C.blue_hi, w=8, h=6, dots=C.ww0, seed=7), xx + 18, s0 + 2)
    place_on(c, birdcage(), xx + 28, s0)
    place_on(c, bundle(C.wood3, C.wood2, C.tan, w=9, h=6, seed=12), xx + 38, s0 + 2)
    place_on(c, jar(C.wood2), xx + 49, s0)
    # middle shelf
    place_on(c, gramophone(), x + 3, s1)
    place_on(c, books(), x + 17, s1)
    place_on(c, lacquer_box(), x + 27, s1)
    place_on(c, handwarmer(), x + 38, s1)
    place_on(c, bundle(C.indigo1, C.indigo0, C.indigo2, w=9, h=6, dots=C.ww1, seed=3), x + 48, s1 + 2)
    place_on(c, bronze_ding(), x + 59, s1)
    place_on(c, teapot(), x + 69, s1)
    place_on(c, vase(C.ww0, C.seal_red), x + 79, s1)
    place_on(c, bundle(C.wood3, C.wood2, C.tan, w=8, h=6, seed=9), x + 87, s1 + 2)
    # bottom shelf
    place_on(c, scrolls(), x + 3, s2)
    for i, bx in enumerate(range(x + 17, x + w - 10, 11)):
        cl = [(C.indigo2, C.indigo1, C.blue_hi, C.ww0), (C.wood3, C.wood2, C.tan, None),
              (C.seal_red, C.dkred, C.lantern_hi, None), (C.indigo1, C.indigo0, C.indigo2, None)][i % 4]
        place_on(c, bundle(cl[0], cl[1], cl[2], w=9, h=6, dots=cl[3], seed=20 + i), bx, s2 + 2)


def fill_right(c, x, w, shelves, top):
    s0, s1, s2 = shelves
    place_on(c, felt_hat(), x + 3, s0)
    place_on(c, books([C.wood2, C.indigo1, C.indigo2]), x + 14, s0)
    place_on(c, bundle(C.indigo2, C.indigo1, C.blue_hi, w=9, h=6, dots=C.ww0, seed=31), x + 25, s0 + 2)
    place_on(c, vase(), x + 36, s0)
    place_on(c, desk_clock(), x + 47, s0)
    place_on(c, bundle(C.seal_red, C.dkred, C.lantern_hi, w=9, h=6, seed=32), x + 56, s0 + 2)
    place_on(c, jar(C.wood3), x + 68, s0)
    place_on(c, handwarmer(), x + 77, s0)
    for i, bx in enumerate(range(x + 3, x + w - 8, 11)):
        cl = [(C.wood3, C.wood2, C.tan, None), (C.indigo2, C.indigo1, C.blue_hi, C.ww0),
              (C.indigo1, C.indigo0, C.indigo2, None)][i % 3]
        place_on(c, bundle(cl[0], cl[1], cl[2], w=9, h=6, dots=cl[3], seed=40 + i), bx, s1 + 2)
    place_on(c, ledger_stack(), x + 3, s2)
    place_on(c, lacquer_box(), x + 17, s2)
    place_on(c, scrolls(), x + 28, s2)
    place_on(c, teapot(), x + 43, s2)
    place_on(c, bronze_ding(), x + 54, s2)
    place_on(c, bundle(C.wood3, C.wood2, C.tan, w=9, h=6, seed=51), x + 65, s2 + 2)
    place_on(c, vase(C.ww0, C.seal_red), x + 77, s2)


def shrine_and_plaque(c):
    cx = 213
    # plaque 德厚当 (black lacquer, gold)
    from gen_buildings import plaque
    plaque(c, cx, BW_TOP + 5, "德厚当", face=C.black, ink=C.gold, border=C.wood2, size=12, pad=2)
    # pawn-rules notice (left) and pendulum wall clock (right) flanking the shrine
    nx, ny = 181, BW_TOP + 20
    c.rect(nx, ny, 15, 20, C.paper)
    c.rect(nx, ny, 15, 3, C.seal_red)
    c.hline(nx, nx + 14, ny + 19, C.paper_old)
    for yy in range(ny + 5, ny + 18, 3):
        for xx in range(nx + 2, nx + 13):
            if (xx * 3 + yy) % 7 not in (0, 3):
                c.put(xx, yy, C.wall1)
    c.put(nx + 11, ny + 16, C.seal_red); c.put(nx + 12, ny + 16, C.seal_red); c.put(nx + 11, ny + 17, C.seal_red)
    c.frame(nx - 1, ny - 1, 17, 22, C.dkbrown)
    for y in range(ny, ny + 21):
        c.put(nx + 16, y, mix(c.get(nx + 16, y), C.black, 0.15))
    clk = clock_wall()
    c.blit(clk.img, 234, BW_TOP + 19)
    for y in range(BW_TOP + 21, BW_TOP + 41):
        c.put(245, y, mix(c.get(245, y), C.black, 0.18))
    # 财神 shrine niche
    sy = BW_TOP + 24
    c.rect(cx - 12, sy, 24, 15, C.dkred)
    c.rect(cx - 13, sy - 2, 26, 3, C.wood1)
    c.hline(cx - 13, cx + 12, sy - 2, C.wood3)
    c.rect(cx - 9, sy + 2, 18, 11, mix(C.dkred, C.black, 0.4))
    # figure
    c.rect(cx - 3, sy + 4, 6, 8, C.seal_red)
    c.rect(cx - 2, sy + 2, 4, 3, C.gold)
    c.put(cx - 1, sy + 3, C.skin_lo); c.put(cx, sy + 3, C.skin_lo)
    c.hline(cx - 3, cx + 2, sy + 7, C.gold)
    c.put(cx - 4, sy + 6, C.gold); c.put(cx + 3, sy + 6, C.gold)  # ingot
    # candles + incense
    for kx in (cx - 8, cx + 7):
        c.rect(kx, sy + 9, 2, 4, C.seal_red)
        c.put(kx, sy + 8, C.lamp); c.put(kx, sy + 7, C.flame)
    c.rect(cx - 13, sy + 13, 26, 2, C.wood2)
    c.hline(cx - 13, cx + 12, sy + 13, C.wood3)
    for (dx, dy) in ((1, -1), (2, -3), (1, -5), (2, -7)):
        c.pixel(cx + 6 + dx, sy + 7 + dy, alpha(C.ww0, 140))


def curtain_door(c):
    """门帘 to the inner rooms (right bay)."""
    x0, x1 = FX0 + 5, 52
    top = BW_TOP + 3
    c.rect(x0, top, x1 - x0 + 1, BW_BOT - top + 1, C.dkbrown)  # dark doorway
    c.rect(x0 - 2, top - 1, x1 - x0 + 5, 3, C.wood1)
    c.hline(x0 - 2, x1 + 2, top - 1, C.wood3)
    # curtain: indigo 蓝印花布, split in the middle
    mid = (x0 + x1) // 2
    for x in range(x0, x1 + 1):
        if abs(x - mid) <= 1:
            continue
        hang = BW_BOT - 2 - (2 if abs(x - mid) < 6 else 0)
        for y in range(top + 2, hang):
            col = C.indigo1 if (x - x0) % 4 else C.indigo0
            if (x - x0) % 4 == 1:
                col = C.indigo2
            c.put(x, y, col)
    rnd = random.Random(5)
    for _ in range(40):
        x = rnd.randint(x0 + 1, x1 - 1)
        y = rnd.randint(top + 4, BW_BOT - 6)
        if abs(x - mid) > 1:
            c.put(x, y, C.ww1)
    # valance
    c.rect(x0, top + 2, x1 - x0 + 1, 4, C.indigo0)
    for x in range(x0, x1 + 1, 2):
        c.put(x, top + 4, C.ww0)
    c.hline(x0, x1, top + 6, C.indigo0)
    # threshold
    c.hline(x0 - 1, x1 + 1, BW_BOT, C.wood2)


def drawer_cabinet(c, x0, x1):
    """首饰柜: wall of small drawers for jewellery / small valuables (right bay)."""
    top = BW_TOP + 3
    bot = BW_BOT
    c.rect(x0 - 1, top - 1, x1 - x0 + 3, 3, C.wood2)
    c.hline(x0 - 1, x1 + 1, top - 1, C.wood3)
    c.rect(x0, top + 2, x1 - x0 + 1, bot - top - 1, C.wood0)
    dw, dh = 9, 6
    for y in range(top + 3, bot - 8, dh + 1):
        for x in range(x0 + 1, x1 - dw + 1, dw + 1):
            c.rect(x, y, dw, dh, C.wood2)
            c.hline(x, x + dw - 1, y, C.wood3)
            c.vline(x, y, y + dh - 1, mix(C.wood2, C.wood3, 0.5))
            c.hline(x, x + dw - 1, y + dh - 1, C.wood1)
            c.rect(x + 3, y + 2, 3, 1, C.paper_hi)
            c.put(x + 4, y + 4, C.gold)
    # locked silver chest base
    by = bot - 8
    c.rect(x0, by, x1 - x0 + 1, 9, C.wood1)
    c.hline(x0, x1, by, C.wood3)
    c.rect((x0 + x1) // 2 - 2, by + 3, 5, 4, C.gold)
    c.put((x0 + x1) // 2, by + 5, C.dkbrown)
    for x in (x0 + 4, x1 - 4):
        c.vline(x, by + 1, bot - 1, C.wall1)
    c.hline(x0, x1, bot, C.dkbrown)
    for y in range(top + 1, bot + 1):
        c.put(x0 - 1, y, mix(c.get(x0 - 1, y), C.black, 0.2))


def side_and_front_walls(c):
    # side wall tops
    for (x0, x1, inner) in ((RX0, FX0 - 1, FX0 - 1), (FX1 + 1, RX1, FX1 + 1)):
        for y in range(CAP_Y, BOT_Y + BOT_H):
            for x in range(x0, x1 + 1):
                col = C.wood0
                if x == inner:
                    col = C.wood2 if inner == FX0 - 1 else C.wood1
                c.put(x, y, col)
        c.vline(x0, CAP_Y, BOT_Y + BOT_H - 1, C.dkbrown)
        c.vline(x1, CAP_Y, BOT_Y + BOT_H - 1, C.dkbrown)
        # plaster fill between timbers on the wall top
        for y in range(CAP_Y + 2, BOT_Y + BOT_H - 2):
            for x in range(x0 + 2, x1 - 1):
                c.put(x, y, mix(C.ww2, C.wood1, 0.55) if (y // 18) % 2 == 0 else mix(C.ww2, C.wood1, 0.45))
        for y in range(CAP_Y + 2, BOT_Y + BOT_H, 18):
            c.hline(x0 + 1, x1 - 1, y, C.wood1)
    # window in the left wall (front area) - lattice seen from above
    for y in range(112, 132):
        for x in range(RX0 + 2, FX0 - 1):
            c.put(x, y, C.lamp_pale if (y % 3) else C.wood2)
    c.hline(RX0 + 1, FX0 - 1, 111, C.wood1); c.hline(RX0 + 1, FX0 - 1, 132, C.wood1)
    # back wall cap
    for y in range(CAP_Y, BW_TOP):
        for x in range(RX0, RX1 + 1):
            col = C.wood0
            if y == CAP_Y:
                col = C.dkbrown
            elif y == CAP_Y + 1:
                col = C.wood1
            elif y == BW_TOP - 1:
                col = C.dkbrown
            c.put(x, y, col)
    for x in range(RX0, RX1 + 1, 24):
        c.vline(x, CAP_Y + 1, BW_TOP - 2, C.wood1)
    # front (bottom) wall strip with door gap
    for y in range(BOT_Y, BOT_Y + BOT_H):
        for x in range(RX0, RX1 + 1):
            if DX0 <= x <= DX1:
                continue
            col = mix(C.ww2, C.wood1, 0.5)
            if y == BOT_Y:
                col = C.wood2
            elif y == BOT_Y + 1:
                col = C.wood1
            elif y == BOT_Y + BOT_H - 1:
                col = C.dkbrown
            c.put(x, y, col)
    for x in list(range(RX0, DX0 - 4, 24)) + list(range(DX1 + 8, RX1, 24)):
        c.vline(x, BOT_Y + 1, BOT_Y + BOT_H - 2, C.wood1)
    # door posts
    for px in (DX0 - 4, DX1 + 1):
        c.rect(px, BOT_Y - 2, 4, BOT_H + 2, C.wood1)
        c.hline(px, px + 3, BOT_Y - 2, C.wood3)
        c.vline(px, BOT_Y - 2, BOT_Y + BOT_H - 1, C.wood2)
        c.vline(px + 3, BOT_Y - 1, BOT_Y + BOT_H - 1, C.dkbrown)
    # high threshold (门槛) + bright street beyond
    for y in range(BOT_Y + 1, BOT_Y + BOT_H):
        for x in range(DX0, DX1 + 1):
            c.put(x, y, mix(C.st4, C.lamp_pale, 0.55) if (x + y) % 5 else mix(C.st3, C.lamp_pale, 0.4))
    c.rect(DX0, BOT_Y - 1, DX1 - DX0 + 1, 3, C.wood2)
    c.hline(DX0, DX1, BOT_Y - 1, C.tan)
    c.hline(DX0, DX1, BOT_Y + 1, C.wood1)


# ====================================================================== counter
def counter_top(c, x0, x1):
    for y in range(CT0, CT1):
        for x in range(x0, x1 + 1):
            col = mix(C.wood2, C.wood3, 0.6) if (y - CT0) % 3 else mix(C.wood2, C.wood3, 0.4)
            if y == CT0:
                col = C.wood1
            c.put(x, y, col)
    rnd = random.Random(77 + x0)
    for _ in range((x1 - x0) // 2):
        c.put(rnd.randint(x0, x1), rnd.randint(CT0 + 1, CT1 - 1), mix(C.wood3, C.tan, 0.5))
    c.hline(x0, x1, CT1, C.tan)          # bullnose lip, lit
    c.hline(x0, x1, CT1 + 1, C.wood2)


def counter_face(c, x0, x1, pw=30):
    """Black-lacquer front of the high counter, raised panels, brass studs."""
    L0 = mix(C.dkbrown, C.wood0, 0.45)
    L1 = mix(C.wood0, C.wood1, 0.35)
    fy0, fy1 = CT1 + 2, CG_FRONT
    for y in range(fy0, fy1 + 1):
        for x in range(x0, x1 + 1):
            c.put(x, y, L0)
    c.hline(x0, x1, fy0, C.black)               # shadow under the lip
    c.hline(x0, x1, fy0 + 1, mix(C.gold, L0, 0.45))  # thin gilt moulding
    n = max(1, (x1 - x0 - 4) // (pw + 3))
    pw = (x1 - x0 - 4 - (n - 1) * 3) // n
    px = x0 + 3
    for i in range(n):
        py0, py1 = fy0 + 4, fy1 - 5
        c.rect(px, py0, pw, py1 - py0 + 1, L1)
        c.rect(px + 2, py0 + 2, pw - 4, py1 - py0 - 3, mix(L1, C.wood1, 0.5))
        c.hline(px, px + pw - 1, py0, C.wood2)       # bevel lit (top)
        c.vline(px, py0, py1, C.wood1)               # bevel lit (left)
        c.hline(px + 1, px + pw - 1, py1, C.black)   # shade (bottom)
        c.vline(px + pw - 1, py0 + 1, py1, C.black)
        c.hline(px + 3, px + pw - 5, py0 + 3, mix(C.wood1, C.wood2, 0.6))
        for sy in (py0, py1):
            c.put(px - 2, sy, C.gold)
        px += pw + 3
    c.hline(x0, x1, fy1 - 2, C.black)
    c.hline(x0, x1, fy1 - 1, C.wood1)
    c.hline(x0, x1, fy1, C.dkbrown)
    c.vline(x0, CT0, fy1, C.dkbrown)
    c.vline(x1, CT0, fy1, C.dkbrown)


def counter(c):
    counter_top(c, CX0, CX1)
    counter_face(c, CX0, CX1)
    c.vline(CX0, CT0, CG_FRONT, mix(C.dkbrown, C.wood0, 0.45))
    # red 斗方 paper with 当 on the leftmost panel
    fy0 = CT1 + 2
    m = font_mask("当", 12)
    dx, dy = 50, fy0 + 5
    c.rect(dx - 2, dy - 2, m.width + 5, m.height + 5, C.seal_red)
    c.hline(dx - 2, dx + m.width + 2, dy - 2, C.lantern_hi)
    c.vline(dx - 2, dy - 2, dy + m.height + 2, C.lantern_hi)
    c.text(dx + 1, dy + 1, "当", C.black, 12)
    # short section to the right wall
    counter_top(c, CX2, FX1)
    counter_face(c, CX2, FX1, pw=34)


def counter_items(c):
    on = lambda it, x, dy=0: place_on(c, it, x, CT1 - 1 + dy)
    on(ticket_spike(), 40, -1)
    on(bundle(C.wood3, C.wood2, C.tan, w=10, h=7, seed=60), 64, 1)
    on(bundle(C.indigo1, C.indigo0, C.indigo2, w=9, h=6, dots=C.ww1, seed=61), 76, 0)
    on(inkstone_brush(), 120, 0)
    on(ledger_open(), 138, 0)
    on(abacus(), 160, 0)
    on(open_bundle_bracelets(), 197, 1)
    on(oil_lamp(), 236, -2)
    on(magnifier(), 248, 0)
    on(teacup(), 262, -2)
    on(seal_pad(), 276, -1)
    on(ledger_stack(), 296, -1)
    on(teacup(), 364, -2)
    on(spittoon_small(), 380, -1)


def spittoon_small():
    c = Cv(7, 6)
    c.rect(1, 1, 5, 4, C.jade)
    c.hline(1, 5, 1, C.jade_hi)
    c.hline(0, 6, 0, C.jade_hi)
    c.put(2, 3, C.ww0)
    c.outline(C.dkbrown)
    return c


# ====================================================================== characters
def char_frame(name, d, f):
    return A1.char_frame(name, d, f)


def zhouma_reaching():
    """周妈 from behind, both hands up on the lip of the high counter."""
    im = char_frame("zhouma", "up", 0)
    c = Cv(16, 32)
    c.blit(im, 0, 0)
    # erase the hanging arms (sleeves + hands + their outline)
    for y in range(16, 26):
        for x in (0, 1, 2, 3, 12, 13, 14, 15):
            c.put(x, y, CLEAR)
    for y in range(16, 25):
        c.put(4, y, C.wood1)
        c.put(11, y, C.wood0)
    # raised arms: shoulder (y17) -> elbow (y11, flared out) -> hands (y4..5) beside the head
    L = [(3, 17), (3, 16), (2, 15), (2, 14), (2, 13), (2, 12), (2, 11), (2, 10), (3, 9), (3, 8), (3, 7), (3, 6)]
    for (x, y) in L:
        c.put(x, y, C.wood3); c.put(x + 1, y, C.wood2)
        c.put(15 - x, y, C.wood2); c.put(14 - x, y, C.wood1)
    for (x, y) in ((3, 5), (4, 5), (3, 4), (4, 4)):
        c.put(x, y, C.skinm); c.put(15 - x, y, C.skinm)
    c.put(4, 4, C.skin_hi); c.put(11, 4, C.skin)
    out = Cv(16, 32)
    out.blit(c, 0, 0)
    out.outline(C.dkbrown)
    return out


# ====================================================================== lighting
def light_poly(c, pts, col, amt, edge=3.0, pattern=None):
    """Additive-ish warm light inside a polygon with soft edges; optional lattice pattern(x,y)->0..1."""
    ys = [p[1] for p in pts]
    xs = [p[0] for p in pts]
    n = len(pts)

    def inside_dist(x, y):
        # signed distance approx: min distance to edges if inside, else -1
        ins = False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
                ins = not ins
            j = i
        if not ins:
            return -1
        best = 1e9
        for i in range(n):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % n]
            vx, vy = bx - ax, by - ay
            t = max(0, min(1, ((x - ax) * vx + (y - ay) * vy) / float(vx * vx + vy * vy)))
            best = min(best, math.hypot(x - (ax + t * vx), y - (ay + t * vy)))
        return best
    for y in range(int(min(ys)), int(max(ys)) + 1):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            d = inside_dist(x + 0.5, y + 0.5)
            if d < 0:
                continue
            a = amt * min(1.0, d / edge)
            if pattern:
                a *= pattern(x, y)
            # dither the soft edge for a pixel-art falloff
            if d < edge and ((x + y) % 2 == 0) and a < amt * 0.5:
                continue
            p = c.get(x, y)
            if p[3] == 0:
                continue
            q = tuple(min(255, int(p[i] + (col[i] - p[i] * 0.35) * a)) for i in range(3)) + (255,)
            c.put(x, y, q)


def glow(c, cx, cy, r, col, amt):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            d = math.hypot(x - cx, (y - cy) * 1.15) / r
            if d < 1:
                a = amt * (1 - d) ** 1.6
                p = c.get(x, y)
                if p[3]:
                    c.put(x, y, tuple(min(255, int(p[i] + col[i] * a)) for i in range(3)) + (255,))


def shade_rect(c, x0, y0, x1, y1, amt_fn):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            a = amt_fn(x, y)
            if a > 0:
                c.put(x, y, mix(c.get(x, y), C.black, a))


def ellipse_shadow(c, cx, cy, rx, ry, a=90):
    ov = Image.new("RGBA", (NW, NH), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(20, 12, 8, a))
    c.img.alpha_composite(ov)
    c.px = c.img.load()


# ====================================================================== scene
def build():
    c = Cv(NW, NH, VOID)
    # ---- floor: platform behind counter is darker, polished; customer side lighter
    wood_floor(c, FX0, FLOOR_Y0, FX1, CG_BACK + 2, seed=3, tone=-0.12)
    wood_floor(c, FX0, CG_BACK + 3, FX1, BOT_Y - 1, seed=8)
    worn_path(c, [(131, 149), (150, 126), (206, 112)], 12, 0.16)
    # ---- back wall + furniture on it
    back_wall(c)
    shelf_unit(c, 76, 94, 1, fill_left)
    cal = calendar_poster()
    c.blit(cal.img, 55, BW_TOP + 5)
    for y in range(BW_TOP + 10, BW_TOP + 37):
        c.put(74, y, mix(c.get(74, y), C.black, 0.2))
    shrine_and_plaque(c)
    shelf_unit(c, 258, 80, 2, fill_right)
    curtain_door(c)
    drawer_cabinet(c, 344, FX1 - 4)
    # AO where wall meets floor
    for i, a in enumerate((0.42, 0.25, 0.12, 0.05)):
        for x in range(FX0, FX1 + 1):
            y = FLOOR_Y0 + i
            c.put(x, y, mix(c.get(x, y), C.black, a))
    # ---- behind the counter (only the strip in front of the shelves is visible)
    lad = ladder(46)
    c.blit(lad.img, 150, 72 - lad.h + 1)
    ellipse_shadow(c, 112, 74, 12, 2, 70)
    t1, t2 = trunk(20, 10, C.wood3), trunk(16, 8, mix(C.wood3, C.dkred, 0.25))
    c.blit(t1.img, 100, 74 - t1.h + 1)
    c.blit(t2.img, 102, 74 - t1.h - t2.h + 3)
    ellipse_shadow(c, 266, 72, 11, 2, 70)
    q = quilts()
    c.blit(q.img, 256, 72 - q.h + 1)
    fv = floor_vase()
    ellipse_shadow(c, 74, 74, 5, 1.5, 80)
    c.blit(fv.img, 70, 74 - fv.h + 1)
    rack = clothes_rack()
    ellipse_shadow(c, 300, 93, 16, 2, 70)
    c.blit(rack.img, 284, 93 - rack.h + 1)
    sb = strongbox()
    c.blit(sb.img, 40, 92 - sb.h + 1)
    ruhua = char_frame("ruhua", "down", 0)
    c.blit(ruhua, 199, 90 - 30)
    # ---- counter + gate
    counter(c)
    counter_rail(c)
    gate = half_gate(GATE_X1 - GATE_X0 + 1)
    c.blit(gate.img, GATE_X0, CG_FRONT - gate.h + 1)
    for gx in (GATE_X0 - 3, GATE_X1 + 1):
        c.rect(gx, CT0 - 2, 3, CG_FRONT - CT0 + 3, C.wood1)
        c.vline(gx, CT0 - 2, CG_FRONT, C.wood2)
        c.vline(gx + 2, CT0 - 2, CG_FRONT, C.dkbrown)
        c.hline(gx, gx + 2, CT0 - 3, C.tan)
        c.put(gx + 1, CT0 - 4, C.gold)
    counter_items(c)
    # counter shadow on the customer floor (light from top-left -> falls down/right)
    def csh(x, y):
        d = y - (CG_FRONT + 1)
        if x > CX1 + 3 + d and not (GATE_X0 <= x <= FX1):
            return 0
        return max(0, 0.42 - d * 0.075)
    shade_rect(c, FX0, CG_FRONT + 1, FX1, CG_FRONT + 6, csh)
    # ---- customer side
    mat = door_mat(26, 8)
    c.blit(mat.img, DX0 + 3, BOT_Y - 10)
    sprites = []

    def add(img, x, ybase, sh=None):
        im = img.img if isinstance(img, Cv) else img
        sprites.append((ybase, x, ybase - im.height + 1, im, sh))
    add(Image.open(A("props", "cat_sit.png")).convert("RGBA"), 150, 131, (157, 130, 6, 2, 90))
    zm = zhouma_reaching()
    add(zm, 202, 115, (210, 114, 6.5, 2, 110))
    xd = char_frame("xiaoding", "right", 0)
    add(xd, 62, 130, (70.5, 129, 6, 2, 95))
    add(load("props", "bench.png"), 32, 125, (45, 123, 13, 2, 70))
    wsh = char_frame("wangshan", "left", 0)
    add(wsh, 300, 128, (308.5, 127, 6, 2, 95))
    add(load("props", "tea_table.png"), 322, 142, (335, 140, 13, 3, 70))
    add(load("props", "rice_sacks.png"), 375, 122, (385, 121, 10, 3, 80))
    add(load("props", "crates.png"), 381, 135, (389, 134, 8, 2, 80))
    add(potted_bamboo(), 32, 148, (39, 147, 7, 2, 80))
    add(broom(), 104, 148, (108, 147, 4, 1, 70))
    add(load("props", "water_vat.png"), 379, 148, (387, 146, 8, 3, 80))
    for (yb, x, y, im, sh) in sorted(sprites, key=lambda s: s[0]):
        if sh:
            ellipse_shadow(c, *sh)
        c.blit(im, x, y)
    # left-wall window: lattice patch of light on the floor (cast down-right)
    def lattice_pat(x, y):
        u = (x - (y - 112) * 0.6)
        return 0.25 if (int(u) % 5 == 0 or (y - 112) % 5 == 0) else 1.0
    light_poly(c, [(FX0, 112), (FX0 + 22, 112), (FX0 + 44, 134), (FX0 + 22, 134)], C.lamp_pale, 0.30, edge=1.0, pattern=lattice_pat)
    # ---- walls (front-most frame)
    side_and_front_walls(c)
    # ---- light: sunbeam through the front door, lamp glow, shrine candles
    def beam_pat(x, y):
        t = (BOT_Y - y) / float(BOT_Y - 110)
        return 1.0 if t < 0.45 else (0.7 if t < 0.75 else 0.42)
    light_poly(c, [(DX0, BOT_Y - 1), (DX1, BOT_Y - 1), (DX1 + 20, 110), (DX0 + 20, 110)], C.lamp_pale, 0.26, edge=1.0, pattern=beam_pat)
    rnd = random.Random(99)
    for _ in range(22):
        t = rnd.random()
        y = int(BOT_Y - 6 - t * 36)
        x = int(DX0 + 4 + t * 20 + rnd.random() * (DX1 - DX0 - 6))
        c.pixel(x, y, alpha(C.paper_hi, rnd.choice((110, 160, 210))))
    glow(c, 240, CT1 - 12, 26, (90, 60, 10), 0.55)
    glow(c, 213, BW_TOP + 30, 14, (80, 30, 5), 0.45)
    return c


def grade(img):
    im = img.convert("RGB")
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if (r, g, b) == VOID[:3]:
                continue
            l = (r + g + b) / 3
            s = 1.10
            r, g, b = (l + (r - l) * s, l + (g - l) * s, l + (b - l) * s)
            r = min(255, max(0, r * 1.03 + 4))
            g = min(255, max(0, g * 1.0 + 1))
            b = min(255, max(0, b * 0.92))
            # interior falloff: brighter around the counter / door, darker in far corners
            d = ((x / W - 0.45) ** 2 * 0.9 + (y / H - 0.42) ** 2 * 1.1)
            f = 1.0 - min(0.26, d * 0.62)
            px[x, y] = (int(r * f), int(g * f), int(b * f))
    return im


# ====================================================================== UI (full res)
def text_mask(text, size=16, spacing=1, path=ZEN, index=1):
    """Bitmap text without vertical cropping (fixed baseline)."""
    f = font(size, path, index)
    w = int(sum(f.getlength(ch) + spacing for ch in text) + 2)
    h = size + 4
    m = Image.new("L", (max(1, w), h), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    x = 0
    for ch in text:
        d.text((x, 0), ch, font=f, fill=255)
        x += f.getlength(ch) + spacing
    return m


def ptext(img, x, y, text, col, size=16, k=2, shadow=None, spacing=1):
    m = text_mask(text, size, spacing)
    m = m.resize((m.width * k, m.height * k), Image.NEAREST)
    if shadow:
        img.paste(Image.new("RGBA", m.size, shadow), (x + k, y + k), m)
    img.paste(Image.new("RGBA", m.size, col), (x, y), m)
    return m.width


def frame_native(w, h, inner=None, inner2=None):
    """Stardew-ish dialogue frame: orange-brown wood border, cream paper inside."""
    inner = inner or C.paper_hi
    inner2 = inner2 or mix(C.paper_hi, C.lamp_pale, 0.6)
    c = Cv(w, h)
    # outer dark outline with rounded corners
    c.rect(2, 0, w - 4, h, C.dkbrown)
    c.rect(0, 2, w, h - 4, C.dkbrown)
    c.rect(1, 1, w - 2, h - 2, C.dkbrown)
    # wood band
    c.rect(2, 1, w - 4, h - 2, C.wood3)
    c.rect(1, 2, w - 2, h - 4, C.wood3)
    c.hline(2, w - 3, 1, C.tan)
    c.vline(1, 2, h - 3, C.tan)
    c.hline(3, w - 4, 2, mix(C.tan, C.lamp_pale, 0.4))
    c.hline(2, w - 3, h - 2, C.wood1)
    c.vline(w - 2, 2, h - 3, C.wood1)
    c.hline(3, w - 3, h - 3, C.wood2)
    c.vline(w - 3, 3, h - 3, C.wood2)
    # wood grain on the band
    rnd = random.Random(2)
    for _ in range(int((w + h) * 0.6)):
        if rnd.random() < 0.5:
            x = rnd.randint(4, w - 6)
            yy = rnd.choice([3, h - 4])
            c.hline(x, x + rnd.randint(1, 3), yy, C.wood2)
    # inner bevel + paper
    c.rect(4, 4, w - 8, h - 8, C.wood1)
    c.rect(5, 5, w - 10, h - 10, inner)
    c.hline(5, w - 6, 5, C.wood2)
    c.vline(5, 5, h - 6, C.wood2)
    c.hline(6, w - 6, 6, mix(inner, C.paper, 0.6))
    # warm vignette on the paper (top lighter, bottom slightly deeper)
    for y in range(7, h - 5):
        t = (y - 7) / max(1, h - 12)
        if t > 0.55:
            c.dither(6, y, w - 11, 1, inner, inner2, (t - 0.55) * 1.6)
    # brass corner studs
    for (x, y) in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        c.put(x, y, C.lamp)
        c.put(x + 1, y + 1 if y < h // 2 else y - 1, C.gold)
    return c


def hand_cursor():
    rows = [
        "..........",
        ".oooo.....",
        "oWWWWo....",
        "oWWWWWoooo",
        ".oWWWWWWWo",
        "..oWWWoooo",
        "..oWWWWWo.",
        "..oWWWWo..",
        "...oooo...",
    ]
    c = Cv(10, 9)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "o":
                c.put(x, y, C.dkbrown)
            elif ch == "W":
                c.put(x, y, C.paper_hi)
    c.put(3, 3, C.skin_hi); c.put(2, 4, C.skin)
    for x in range(3, 9):
        c.put(x, 4, mix(C.paper_hi, C.skin, 0.25))
    return c


def icon_magnifier():
    c = Cv(9, 9)
    c.ellipse(3.5, 3.5, 3.2, 3.2, C.gold)
    c.ellipse(3.5, 3.5, 2.0, 2.0, mix(C.fog, C.white, 0.5))
    c.put(2, 2, C.white)
    c.line(6, 6, 8, 8, C.wood1)
    c.put(7, 7, C.wood2)
    c.outline(C.dkbrown)
    return c


def icon_question():
    c = Cv(9, 9)
    c.ellipse(4, 4, 4, 4, C.indigo2)
    c.ellipse(3.5, 3.5, 2.5, 2.5, C.blue_hi)
    c.put(3, 2, C.paper_hi); c.put(4, 2, C.paper_hi); c.put(5, 3, C.paper_hi); c.put(4, 4, C.paper_hi)
    c.put(4, 6, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def icon_refuse():
    c = Cv(9, 9)
    c.ellipse(4, 4, 4, 4, C.seal_red)
    c.ellipse(3.5, 3.5, 2.5, 2.5, C.lantern_hi)
    for i in range(-2, 3):
        c.put(4 + i, 4 + i, C.paper_hi)
        c.put(4 + i, 4 - i, C.paper_hi)
    c.outline(C.dkbrown)
    return c


def chip(img, x, y, text, fg, bg, k=2):
    m = text_mask(text, 12, 1)
    w = m.width * k
    d = ImageDraw.Draw(img)
    d.rectangle((x, y, x + w + 14, y + 30), fill=bg, outline=C.dkbrown, width=2)
    ptext(img, x + 8, y + 1, text, fg, 12, k)
    return w + 14


def dialogue(img):
    W, H = img.size
    bx, by, bw, bh = 8, 160, 411, 79     # native units -> full res via K
    fr = frame_native(bw, bh)
    img.alpha_composite(scale(fr.img, K), (bx * K, by * K))
    X0, Y0 = bx * K, by * K
    # ---- portrait panel (right)
    pw, ph = 56, 70
    px_n = bw - pw - 6
    pf = Cv(pw, ph)
    pf.rect(0, 0, pw, ph, C.dkbrown)
    pf.rect(1, 1, pw - 2, ph - 2, C.wood2)
    pf.hline(1, pw - 2, 1, C.wood3)
    pf.vline(1, 1, ph - 2, C.wood3)
    pf.rect(3, 3, pw - 6, 54, C.wood0)                      # portrait well
    pf.dither(4, 4, pw - 8, 52, mix(C.wood1, C.wood2, 0.5), C.wood1, 0.45)
    pf.hline(3, pw - 4, 3, C.dkbrown)
    por = Image.open(os.path.join(REPO, "art", "portraits", "zhouma.png")).convert("RGBA")
    por = por.crop((0, 0, 48, 52))
    pfi = pf.img
    pfi.alpha_composite(por, (4, 4))
    pf.px = pfi.load()
    pf.hline(3, pw - 4, 56, C.dkbrown)
    # name plate
    pf.rect(4, 58, pw - 8, 10, C.paper_hi)
    pf.hline(4, pw - 5, 58, C.white)
    pf.hline(4, pw - 5, 67, C.paper_old)
    pf.frame(3, 57, pw - 6, 12, C.wood1)
    pfs = scale(pf.img, K)
    PX, PY = X0 + px_n * K, Y0 + 4 * K + 1
    img.alpha_composite(pfs, (PX, PY))
    name = "周妈"
    nw = text_mask(name, 16, 2).width * 2
    ptext(img, PX + (pfs.width - nw) // 2, PY + 58 * K + 1, name, C.dkbrown, 16, 2, spacing=2)
    # ---- dialogue text
    tx, ty = X0 + 40, Y0 + 22
    ink = (59, 33, 18, 255)
    line1 = "如花啊，这对银镯子是我娘家陪嫁的，"
    line2 = "你给看看……能当多少？"
    ptext(img, tx, ty, line1, ink, 16, 2)
    w2 = ptext(img, tx, ty + 40, line2, ink, 16, 2)
    d = ImageDraw.Draw(img)
    # divider
    for xx in range(tx, PX - 30, 12):
        d.rectangle((xx, ty + 88, xx + 5, ty + 89), fill=C.paper_old)
    # ---- choices
    cy0 = ty + 100
    rows = [("拿放大镜看看", icon_magnifier(), "鉴定 · 耗时一刻", True),
            ("先问来路", icon_question(), "周妈怕是不高兴", False),
            ("不收", icon_refuse(), "口碑 -1", False)]
    for i, (txt, ic, hint, sel) in enumerate(rows):
        ry = cy0 + i * 33
        if sel:
            ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
            od = ImageDraw.Draw(ov)
            od.rectangle((tx - 8, ry - 3, PX - 24, ry + 29), fill=mix(C.lamp_pale, C.paper_hi, 0.3))
            od.rectangle((tx - 8, ry - 3, PX - 24, ry + 29), outline=C.tan, width=3)
            img.alpha_composite(ov)
            hc = scale(hand_cursor().img, 3)
            img.alpha_composite(hc, (tx - 8 - hc.width + 4, ry + 1))
        img.alpha_composite(scale(ic.img, 3), (tx + 4, ry))
        ptext(img, tx + 44, ry + 1, txt, ink if sel else (96, 64, 40, 255), 12, 2)
        hw = text_mask(hint, 12, 1).width * 2
        ptext(img, PX - 40 - hw, ry + 1, hint, (156, 122, 84, 255) if not sel else (128, 92, 56, 255), 12, 2)
    return img


def hud(img):
    """Same wooden clock panel as A1 (date / weather + time / money)."""
    W, H = img.size
    d = ImageDraw.Draw(img)
    ink = C.dkbrown
    pw, ph = 92, 42
    pnl = scale(A1.panel_native(pw, ph).img, K)
    px0, py0 = W - pnl.width - 10, 8
    img.alpha_composite(pnl, (px0, py0))
    t = "二月初五 · 星期六"
    tw = text_mask(t, 12, 1).width * 2
    ptext(img, px0 + (pnl.width - tw) // 2, py0 + 14, t, ink, 12, 2)
    d.rectangle((px0 + 18, py0 + 48, px0 + pnl.width - 18, py0 + 50), fill=C.wood3)
    sun = scale(load("ui", "sun_cloud.png"), K)
    img.alpha_composite(sun, (px0 + 20, py0 + 54))
    ptext(img, px0 + 92, py0 + 58, "上午 9:40", ink, 12, 2)
    mx0, my0, mx1 = px0 + 20, py0 + 90, px0 + pnl.width - 20
    d.rectangle((mx0, my0, mx1, my0 + 26), fill=C.wood1, outline=C.dkbrown, width=3)
    d.rectangle((mx0 + 3, my0 + 3, mx1 - 3, my0 + 5), fill=C.wood0)
    coin = scale(load("ui", "coin.png"), 2)
    img.alpha_composite(coin, (mx0 + 8, my0 + 3))
    money = "600 蚨"
    mw = text_mask(money, 12, 1).width * 2
    ptext(img, mx1 - 10 - mw, my0 + 1, money, C.lamp, 12, 2, shadow=C.dkbrown)
    return img


def label(img, text):
    lw = text_mask(text, 16, 0).width
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((8, 8, 8 + lw + 18, 8 + 30), fill=(15, 10, 8, 200))
    img.alpha_composite(ov)
    ptext(img, 17, 12, text, C.paper_hi, 16, 1, spacing=0)


def main():
    c = build()
    native = grade(c.img).convert("RGBA")
    native.save(os.path.join(HERE, "A2_native.png"))
    big = scale(native, K).crop((0, 0, 1280, 720))
    big = dialogue(big)
    big = hud(big)
    label(big, "示意图 A：店内俯视 + 头像对话框")
    big.convert("RGB").save(os.path.join(HERE, "A2_pawnshop_interior_topdown.png"))
    # export reusable props
    for nm, fn in (("abacus", abacus), ("oil_lamp", oil_lamp), ("ledger_open", ledger_open),
                   ("calendar_poster", calendar_poster), ("clock_wall", clock_wall),
                   ("clothes_rack", clothes_rack), ("gramophone", gramophone), ("birdcage", birdcage),
                   ("open_bundle_bracelets", open_bundle_bracelets), ("potted_bamboo", potted_bamboo),
                   ("broom", broom), ("magnifier", magnifier), ("ladder", ladder), ("trunk", trunk),
                   ("quilts", quilts), ("floor_vase", floor_vase), ("hand_cursor", hand_cursor)):
        save_prop(fn(), nm)
    save_prop(zhouma_reaching(), "zhouma_reaching")
    save_prop(bundle(C.indigo2, C.indigo1, C.blue_hi, w=9, h=6, dots=C.ww0, seed=1), "bundle_blue")
    save_prop(half_gate(31), "half_gate")


if __name__ == "__main__":
    main()
