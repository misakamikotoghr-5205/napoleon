"""MOCKUP B2: 米行 interior, static side-view close-up (native 320x180, x4 -> 1280x720).

Player (沈如花) is the visitor; 吴掌柜 stands behind the rice counter.
    python3 gen_B2_portraits.py   # portraits -> assets/portraits/B2_*.png
    python3 compose_B2.py         # -> B2_ricehall_sideview.png (+ _native.png, assets/B2_ricehall_bg.png)
Light: daylight through the lattice window at the upper LEFT; shadows fall right/down.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pix import Cv, C, ASSETS, HERE, mix, font_mask, scale, ZEN, UNIFONT, from_ascii  # noqa: E402
from compose_A1 import pixel_text, panel_native, load as a1_load  # noqa: E402

NW, NH, K = 320, 180, 4
BEAM_Y0, BEAM_Y1 = 9, 15
COUNTER_Y = 104          # counter top lip
FLOOR_Y = 166
PIL_L = (96, 103)
PIL_R = (236, 243)
MERCH_X = 166            # portrait left (48x64), bottom row on COUNTER_Y-1
WIN = (12, 28, 62, 74)   # x0, y0, x1, y1


def hz(x, y, s=0.0):
    v = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
    return v - math.floor(v)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def thr(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def ramp(x, y, cols, v):
    v = max(0.0, min(1.0, v))
    f = v * (len(cols) - 1)
    i = min(int(f), len(cols) - 2)
    return cols[i + 1] if thr(x, y) < (f - i) else cols[i]


WOOD = [C.black, C.dkbrown, C.wood0, C.wood1, C.wood2, C.wood3, C.tan, C.lamp_pale]
PLASTER = [C.ww3, C.ww2, C.ww1, C.ww0]
BURLAP = [C.wood1, C.wood2, C.wood3, C.tan, C.paper_old, C.paper]


# ================================================================== back wall
def wall(c):
    rnd = random.Random(7)
    # ---- plaster on the left section (lit by the window)
    for y in range(0, FLOOR_Y):
        for x in range(0, PIL_L[0]):
            d = math.hypot((x - 37) / 70.0, (y - 50) / 70.0)
            v = 0.82 - 0.55 * d + 0.06 * (hz(x, y) - 0.5)
            if y > 84:
                v -= 0.15
            c.put(x, y, ramp(x, y, PLASTER, v))
    # water stain + hairline crack
    for y in range(76, 92):
        for x in range(2, 20):
            if hz(x, y, 3) < 0.25 * (1 - abs(x - 10) / 10.0) * (1 - (y - 76) / 16.0) * 3:
                c.put(x, y, C.ww3)
    c.line(84, 40, 88, 52, C.ww3); c.line(88, 52, 87, 60, C.ww3)
    # ---- wainscot under the window
    for y in range(86, FLOOR_Y):
        for x in range(0, PIL_L[0]):
            v = 0.42 + 0.06 * math.sin(y * 1.7 + x * 0.05)
            if y in (86, 87):
                v = 0.62 if y == 86 else 0.2
            elif (x % 24) == 0:
                v = 0.15
            elif (x % 24) == 1:
                v = 0.55
            v += 0.08 * (1 - x / 95.0)
            c.put(x, y, ramp(x, y, WOOD, v))
    # ---- plank wall (centre + right): flat boards, sparse grain, lit from the left
    x = PIL_L[1] + 1
    boards = []
    while x < NW:
        w = rnd.choice((9, 10, 11, 12))
        boards.append((x, min(NW, x + w), rnd.random()))
        x += w
    for (x0, x1, t) in boards:
        bright = t < 0.95 - 0.75 * (x0 / NW)
        base, dark, lite = (C.wood2, C.wood1, C.wood3) if bright else (C.wood1, C.wood0, C.wood2)
        for y in range(BEAM_Y1, FLOOR_Y):
            for xx in range(x0, x1):
                col = base
                if xx == x0:
                    col = C.dkbrown
                elif xx == x0 + 1:
                    col = lite
                c.put(xx, y, col)
        # grain streaks
        r2 = random.Random(int(t * 1e6))
        for _ in range(4):
            gx = r2.randint(x0 + 3, x1 - 2)
            gy = r2.randint(BEAM_Y1 + 4, FLOOR_Y - 20)
            ln = r2.randint(6, 22)
            for k in range(ln):
                c.put(gx + (1 if (k // 7) % 2 else 0), gy + k, dark)
        # knot
        if t > 0.7:
            ky = int(30 + t * 70)
            kx = (x0 + x1) // 2
            c.ellipse(kx, ky, 1.5, 2.4, dark)
            c.put(kx, ky, C.dkbrown)
            c.put(kx - 1, ky - 3, lite)
        # nail heads
        for ny in (24, 96):
            c.put(x0 + 3, ny, C.dkbrown)
    # dim the plank wall toward the bottom (Bayer, keeps the boards crisp)
    for y in range(80, FLOOR_Y):
        for x in range(PIL_L[1] + 1, NW):
            if thr(x, y) < (y - 80) / 120.0:
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.5))
    # shadow band under the beam
    for y in range(BEAM_Y1, BEAM_Y1 + 5):
        for x in range(NW):
            if thr(x, y) < 0.7 - (y - BEAM_Y1) * 0.16:
                p = c.get(x, y)
                c.put(x, y, mix(p, C.dkbrown, 0.45))
    # ---- ceiling + rafters + main beam
    for y in range(0, BEAM_Y0):
        for x in range(NW):
            r = x % 14
            v = 0.12 if r in (0, 1) else (0.22 if r in (2, 3, 4, 5, 6, 7) else 0.16)
            v += 0.05 * (y / BEAM_Y0)
            c.put(x, y, ramp(x, y, WOOD, v))
    for y in range(BEAM_Y0, BEAM_Y1 + 1):
        for x in range(NW):
            v = {BEAM_Y0: 0.62, BEAM_Y0 + 1: 0.5, BEAM_Y1: 0.1, BEAM_Y1 - 1: 0.25}.get(y, 0.38)
            v += 0.05 * math.sin(x * 0.21 + y)
            v -= 0.1 * x / NW
            c.put(x, y, ramp(x, y, WOOD, v))


def pillar(c, x0, x1, y0=BEAM_Y1 + 1, y1=FLOOR_Y):
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            v = 0.26
            if x == x0:
                v = 0.5
            elif x == x0 + 1:
                v = 0.4
            elif x == x1:
                v = 0.08
            v += 0.03 * math.sin(y * 0.7)
            c.put(x, y, ramp(x, y, WOOD, v))
    # cast shadow of the pillar on the plank wall (to the right)
    for y in range(y0, y1):
        for x in range(x1 + 1, x1 + 4):
            if thr(x, y) < 0.55 - 0.15 * (x - x1):
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.5))


def window(c):
    x0, y0, x1, y1 = WIN
    # outer frame (shadow right/bottom)
    c.rect(x0 - 3, y0 - 3, x1 - x0 + 7, y1 - y0 + 7, C.wood1)
    c.hline(x0 - 3, x1 + 3, y0 - 3, C.wood2)
    c.vline(x0 - 3, y0 - 3, y1 + 3, C.wood2)
    c.hline(x0 - 3, x1 + 3, y1 + 3, C.wood0)
    c.vline(x1 + 3, y0 - 3, y1 + 3, C.wood0)
    # glowing paper panes with a willow-branch silhouette outside
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot((x - x0 - 8) / 50.0, (y - y0 - 6) / 50.0)
            col = ramp(x, y, [C.paper, C.paper_hi, C.lamp_pale, C.white], 0.95 - 0.5 * d)
            c.put(x, y, col)
    for i in range(40):
        t = i / 40.0
        bx = int(x0 + 4 + t * 46)
        by = int(y0 + 2 + 10 * t * t + 2 * math.sin(t * 6))
        c.put(bx, by, C.tan)
        if i % 4 == 0:
            for k in range(1, 10 + (i * 7) % 7):
                xx, yy = bx + (k // 4), by + k
                if y0 <= yy < y1 and thr(xx, yy) < 0.6:
                    c.put(xx, yy, C.paper_old if k < 7 else C.paper)
    # 方格 lattice
    for x in range(x0, x1):
        for y in range(y0, y1):
            lx, ly = x - x0, y - y0
            if lx % 8 == 7 or ly % 8 == 7:
                c.put(x, y, C.wood1)
                if lx % 8 == 7 and ly % 8 != 7:
                    c.put(x + 1 if x + 1 < x1 else x, y, c.get(x + 1, y))
    for x in range(x0, x1):
        for y in range(y0, y1):
            lx, ly = x - x0, y - y0
            if lx % 8 == 7 or ly % 8 == 7:
                c.put(x, y, C.wood1)
                if (lx % 8 == 7) and x + 1 < x1 and (ly % 8 != 7):
                    pass
    # little 回纹 corners in each pane intersection
    for gx in range(x0 + 7, x1, 8):
        for gy in range(y0 + 7, y1, 8):
            c.put(gx, gy, C.wood0)
    # sill + potted orchid
    c.rect(x0 - 5, y1 + 3, x1 - x0 + 11, 3, C.wood2)
    c.hline(x0 - 5, x1 + 5, y1 + 3, C.tan)
    c.hline(x0 - 5, x1 + 5, y1 + 6, C.wood0)
    px, py = x1 - 10, y1 + 2
    c.rect(px, py - 5, 7, 6, C.white)
    c.rect(px, py - 5, 7, 1, C.fog)
    c.put(px + 2, py - 3, C.indigo2); c.put(px + 4, py - 2, C.indigo2); c.put(px + 3, py - 3, C.indigo1)
    c.vline(px + 6, py - 4, py, C.mist)
    for (dx, dy) in [(1, -7), (2, -9), (3, -11), (4, -9), (5, -7), (6, -10), (0, -9), (7, -8), (3, -8)]:
        c.line(px + 3, py - 6, px + dx, py + dy, C.g2)
    c.put(px + 2, py - 11, C.g4); c.put(px + 6, py - 10, C.g4); c.put(px + 4, py - 12, C.flower)


def banner(c):
    """幌子: white cloth with a big 米, indigo border, hanging from the beam."""
    x0, x1, y0, y1 = 70, 90, 19, 66
    c.vline(73, BEAM_Y1, y0, C.dkbrown); c.vline(87, BEAM_Y1, y0, C.dkbrown)
    c.rect(x0 - 2, y0, x1 - x0 + 5, 3, C.wood1)
    c.hline(x0 - 2, x1 + 2, y0, C.wood3)
    cloth = Cv(NW, NH)
    pts = [(x0, y0 + 3), (x1, y0 + 3), (x1, y1), (x1 - 5, y1 - 5), (x0 + 10, y1 - 1), (x0 + 5, y1 - 5), (x0, y1)]
    cloth.poly(pts, C.ww0)
    for y in range(NH):
        for x in range(NW):
            p = cloth.get(x, y)
            if p[3]:
                v = 0.85 - 0.4 * (x - x0) / (x1 - x0) - 0.15 * (y - y0) / (y1 - y0)
                v += 0.08 * math.sin(x * 0.9)          # vertical folds
                col = ramp(x, y, [C.ww3, C.ww2, C.ww1, C.ww0], v)
                if x in (x0, x0 + 1, x1, x1 - 1) or y in (y0 + 3, y0 + 4):
                    col = C.indigo1 if x not in (x0,) else C.indigo2
                cloth.put(x, y, col)
    cloth.outline(C.dkbrown)
    c.blit(cloth, 0, 0)
    # big 米
    m = font_mask("米", 16)
    mp = m.load()
    for yy in range(m.height):
        for xx in range(m.width):
            if mp[xx, yy] > 127:
                c.put(80 - m.width // 2 + xx, 37 - m.height // 2 + yy, C.black)
    # red seal under it
    c.rect(78, 50, 5, 5, C.seal_red); c.put(80, 52, C.paper_hi); c.frame(78, 50, 5, 5, C.dkred)


def lantern(c, cx, top):
    """Red paper lantern hanging from the beam (close-up scale)."""
    c.vline(cx, BEAM_Y1 + 1, top, C.dkbrown)
    lt = Cv(NW, NH)
    lt.rect(cx - 3, top, 7, 2, C.gold)
    lt.ellipse(cx, top + 9, 7, 7, C.lantern)
    for y in range(top + 2, top + 17):
        for x in range(cx - 8, cx + 9):
            if lt.get(x, y)[3] and lt.get(x, y)[:3] == C.lantern[:3]:
                nx = (x - cx) / 7.0
                if nx < -0.45:
                    lt.put(x, y, C.lantern_hi)
                elif nx > 0.45:
                    lt.put(x, y, C.seal_red)
                if (x - cx) in (-3, 3) and abs(y - top - 9) < 6:
                    lt.put(x, y, C.dkred)
    lt.rect(cx - 3, top + 16, 7, 2, C.gold)
    lt.put(cx - 3, top, C.lamp); lt.put(cx - 3, top + 16, C.lamp)
    lt.outline(C.dkbrown)
    for k in range(6):
        lt.put(cx, top + 19 + k, C.seal_red if k < 5 else C.dkred)
        if k > 1:
            lt.put(cx - 1 + (k % 2) * 2, top + 19 + k, C.seal_red)
    c.blit(lt, 0, 0)


def plaque(c):
    x0, y0, w, h = 160, 18, 62, 15
    c.rect(x0 - 1, y0 - 1, w + 2, h + 2, C.dkbrown)
    c.rect(x0, y0, w, h, C.rf0)
    c.frame(x0 + 1, y0 + 1, w - 2, h - 2, C.wood3)
    c.hline(x0 + 1, x0 + w - 2, y0 + 1, C.gold)
    c.rect(x0 + 2, y0 + 2, w - 4, h - 4, C.rf1)
    c.dither(x0 + 2, y0 + 2, w - 4, 3, C.rf1, C.rf2, 0.3)
    text = "裕丰米行"
    adv = 14
    tx0 = x0 + (w - adv * len(text) + 2) // 2
    for i, ch in enumerate(text):
        m = font_mask(ch, 12)
        mp = m.load()
        tx = tx0 + i * adv + (12 - m.width) // 2
        ty = y0 + (h - 12) // 2 + (12 - m.height) // 2
        for yy in range(m.height):
            for xx in range(m.width):
                if mp[xx, yy] > 127:
                    c.put(tx + xx + 1, ty + yy + 1, C.wood0)
        for yy in range(m.height):
            for xx in range(m.width):
                if mp[xx, yy] > 127:
                    c.put(tx + xx, ty + yy, C.lamp)
    # 红绸 swag with a knot in the middle
    for x in range(x0 - 2, x0 + w + 2):
        sag = int(3 * math.sin(math.pi * ((x - x0 + 2) % 33) / 33.0))
        c.vline(x, y0 - 2 + sag, y0 + sag, C.seal_red)
        c.put(x, y0 + 1 + sag, C.dkred)
    c.ellipse(x0 + w // 2, y0, 3, 2.5, C.lantern)
    c.put(x0 + w // 2 - 1, y0 - 1, C.lantern_hi)
    for (sx, d) in ((x0 - 2, -1), (x0 + w + 1, 1)):
        for k in range(10):
            c.put(sx + (d if k > 6 else 0), y0 + k, C.seal_red if k % 3 else C.dkred)


def shelf_and_bins(c):
    # right: small drawer chest (receipts / weights) behind the counter
    bx0, bx1 = 214, 236
    for y in range(70, COUNTER_Y):
        for x in range(bx0, bx1):
            col = C.wood2
            if (x - bx0) % 11 == 0 or (y - 70) % 11 == 0:
                col = C.dkbrown
            elif (x - bx0) % 11 == 1 or (y - 70) % 11 == 1:
                col = C.wood3
            c.put(x, y, col)
    for x in range(bx0 + 5, bx1, 11):
        for y in range(76, COUNTER_Y, 11):
            c.rect(x, y, 3, 1, C.gold)
            c.put(x + 1, y + 1, C.wood0)
    # left: upright full sacks waiting behind the counter (tied necks)
    def upright(cx, top, w, seed):
        sk = Cv(NW, NH)
        for y in range(top, COUNTER_Y + 2):
            t = (y - top) / float(COUNTER_Y - top)
            tp = y - top
            if tp < 3:
                half = 2.5 + tp * 0.5
            elif tp < 6:
                half = 1.5
            elif tp < 15:
                half = 1.5 + (w / 2 - 1.5) * math.sin((tp - 6) / 9.0 * math.pi / 2)
            else:
                half = w / 2 + 1.2 * math.sin(t * 3)
            for x in range(int(cx - half), int(cx + half) + 1):
                nx = (x - cx) / max(1, half)
                v = 0.62 - 0.32 * nx - 0.08 * t + 0.04 * ((x + y) % 2)
                sk.put(x, y, ramp(x, y, BURLAP, v))
        sk.rect(int(cx - 2), top + 3, 5, 3, C.wood1)          # rope tie
        sk.hline(int(cx - 2), int(cx + 2), top + 3, C.tan)
        sk.hline(int(cx - w / 2 + 2), int(cx + w / 2 - 2), top + 22, C.indigo1)
        sk.rect(int(cx - 3), top + 13, 6, 5, C.seal_red)
        sk.put(int(cx - 1), top + 15, C.paper_hi)
        sk.outline(C.dkbrown)
        c.blit(sk, 0, 0)
    upright(118, 68, 22, 1)
    upright(140, 72, 22, 2)
    upright(160, 70, 18, 3)
    # shelf board
    sy = 62
    c.rect(104, sy, 132, 3, C.wood2)
    c.hline(104, 235, sy, C.tan)
    c.hline(104, 235, sy + 3, C.dkbrown)
    for x in range(104, 236):
        if thr(x, sy + 4) < 0.5:
            c.put(x, sy + 4, mix(c.get(x, sy + 4), C.dkbrown, 0.6))
    for bx in (112, 226):
        c.rect(bx, sy + 3, 2, 5, C.wood1)
    # stacked 斗 measures (left)
    def dou(x, ybot, w, h):
        c.poly([(x, ybot - h), (x + w, ybot - h), (x + w - 2, ybot), (x + 2, ybot)], C.wood3)
        c.hline(x, x + w, ybot - h, C.tan)
        c.line(x + w, ybot - h, x + w - 2, ybot, C.wood1)
        c.hline(x + 2, x + w - 2, ybot, C.wood1)
        c.hline(x + 1, x + w - 1, ybot - h + 2, C.wood1)
    dou(108, sy - 1, 14, 7); dou(110, sy - 8, 10, 6)
    # blue-white porcelain jar
    c.ellipse(134, sy - 6, 5, 6, C.white)
    c.rect(131, sy - 14, 7, 3, C.white)
    c.ellipse(133, sy - 7, 2, 2, C.indigo2, filled=False)
    c.hline(130, 138, sy - 3, C.indigo2)
    c.put(131, sy - 9, C.fog); c.put(137, sy - 6, C.fog); c.put(138, sy - 5, C.mist)
    # account books
    for i, col in enumerate((C.indigo1, C.paper, C.indigo0, C.paper_old)):
        c.rect(145 + i * 3, sy - 12 + (i % 2), 3, 12 - (i % 2), col)
    c.vline(157, sy - 9, sy - 1, C.wood1)
    # right side: tea caddy + oil lamp
    c.rect(218, sy - 9, 8, 9, C.dkred)
    c.rect(218, sy - 9, 8, 2, C.seal_red)
    c.rect(220, sy - 6, 4, 3, C.gold)
    c.ellipse(231, sy - 3, 3, 2, C.gold)
    c.vline(231, sy - 9, sy - 5, C.fog)
    c.rect(229, sy - 13, 5, 5, C.mist)
    c.put(231, sy - 11, C.flame)
    # shadow on the right of shelf objects
    for (x, y0, y1) in ((122, sy - 7, sy - 1), (139, sy - 10, sy - 1), (158, sy - 9, sy - 1), (226, sy - 8, sy - 1)):
        for y in range(y0, y1 + 1):
            c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.5))


def calendar(c):
    """1938 月份牌 hung on the right pillar: painted lady + tear-off pad showing 5."""
    x0, y0, w, h = 228, 34, 24, 34
    c.line(x0 + w // 2, y0 - 5, x0 + 2, y0, C.dkbrown)
    c.line(x0 + w // 2, y0 - 5, x0 + w - 3, y0, C.dkbrown)
    c.put(x0 + w // 2, y0 - 6, C.silver)
    # paper
    c.rect(x0, y0, w, h, C.paper)
    c.rect(x0 + 1, y0 + 1, w - 2, 19, C.blue_hi)          # painting: spring sky
    for y in range(y0 + 1, y0 + 20):
        for x in range(x0 + 1, x0 + w - 1):
            if y > y0 + 12:
                c.put(x, y, ramp(x, y, [C.wa4, C.g4, C.g3], (y - y0 - 12) / 8.0))
            elif thr(x, y) < 0.3:
                c.put(x, y, C.wa5)
    # little lady in a red qipao with a parasol
    lx = x0 + 9
    c.put(lx + 1, y0 + 6, C.hair); c.put(lx + 2, y0 + 6, C.hair); c.put(lx + 3, y0 + 6, C.hair); c.put(lx + 3, y0 + 5, C.hair)
    c.put(lx + 1, y0 + 7, C.skin_hi); c.put(lx + 2, y0 + 7, C.skin)
    c.rect(lx, y0 + 8, 4, 10, C.seal_red)
    c.vline(lx + 3, y0 + 8, y0 + 17, C.dkred)
    c.put(lx + 1, y0 + 18, C.skin)
    c.hline(lx - 4, lx + 1, y0 + 4, C.pink); c.hline(lx - 3, lx, y0 + 3, C.pink)
    c.vline(lx - 1, y0 + 5, y0 + 9, C.wood1)
    c.put(x0 + 18, y0 + 14, C.flower); c.put(x0 + 19, y0 + 13, C.flower); c.put(x0 + 3, y0 + 15, C.flower)
    # red header band + pad
    c.rect(x0, y0 + 20, w, 3, C.seal_red)
    c.hline(x0 + 2, x0 + w - 3, y0 + 21, C.gold)
    c.rect(x0 + 3, y0 + 23, w - 6, h - 25, C.paper_hi)
    c.hline(x0 + 3, x0 + w - 4, y0 + h - 2, C.paper_old)
    # big red 5
    five = ["xxxx", "x...", "xxx.", "...x", "...x", "x..x", ".xx."]
    for j, row in enumerate(five):
        for i, ch in enumerate(row):
            if ch == "x":
                c.put(x0 + 10 + i, y0 + 24 + j, C.seal_red)
    c.hline(x0 + 5, x0 + 7, y0 + 25, C.wood2); c.hline(x0 + 16, x0 + 18, y0 + 25, C.wood2)
    c.hline(x0 + 5, x0 + 7, y0 + 28, C.paper_old); c.hline(x0 + 16, x0 + 18, y0 + 28, C.paper_old)
    c.frame(x0 - 1, y0 - 1, w + 2, h + 2, C.dkbrown)
    # drop shadow on the pillar / wall (right + bottom)
    for y in range(y0, y0 + h + 2):
        x = x0 + w + 1
        c.put(x, y, mix(c.get(x, y), C.black, 0.5))
    for x in range(x0 + 1, x0 + w + 2):
        y = y0 + h + 1
        c.put(x, y, mix(c.get(x, y), C.black, 0.5))


def curtain(c):
    """Doorway to the back storeroom: 蓝印花布 curtain."""
    x0, x1, y0, y1 = 270, NW, 24, COUNTER_Y
    c.rect(x0 - 3, y0 - 4, x1 - x0 + 3, 4, C.wood0)
    c.hline(x0 - 3, x1, y0 - 4, C.wood2)
    for y in range(y0, y1):
        for x in range(x0, x1):
            fold = math.sin((x - x0) * 0.55)
            v = 0.45 + 0.25 * fold - 0.15 * (y - y0) / (y1 - y0)
            col = ramp(x, y, [C.indigo0, C.indigo1, C.indigo2], v)
            # 蓝印花布 dots / small flowers pattern
            px_, py_ = (x - x0) % 8, (y - y0 + ((x - x0) // 8 % 2) * 4) % 8
            if (px_, py_) in ((3, 3),) or (px_, py_) in ((2, 3), (4, 3), (3, 2), (3, 4)) and fold > -0.3:
                col = C.mist if fold < 0.2 else C.fog
            c.put(x, y, col)
    c.vline(x0, y0, y1, C.dkbrown)
    # tie-back fold near the right edge
    for y in range(y0 + 30, y0 + 34):
        c.hline(312, NW - 1, y, C.indigo0)
    c.hline(312, NW - 1, y0 + 30, C.tan)


def steelyard(c):
    """杆秤 hanging from the beam: rope, fulcrum ring, beam with brass stars, hook + sack, iron weight."""
    fx, ay = 278, 54                      # fulcrum x, arm y
    x_left, x_right = 260, 319
    # rope from the beam
    for y in range(BEAM_Y1 + 1, ay - 3):
        c.put(fx + (1 if (y // 2) % 2 else 0), y, C.paper if y % 2 else C.tan)
        c.put(fx + (0 if (y // 2) % 2 else 1), y, C.wood2)
    c.ellipse(fx + 0.5, ay - 3, 2.5, 2.5, C.wall2, filled=False)
    # arm: 4px pole, tapering toward the long end
    for x in range(x_left, x_right + 1):
        thick = 4 if x < fx + 26 else 3
        for k in range(thick):
            col = (C.paper_hi, C.tan, C.wood3, C.wood2)[k]
            c.put(x, ay + k, col)
        c.put(x, ay - 1, C.dkbrown)
        c.put(x, ay + thick, C.dkbrown)
    c.rect(x_left - 2, ay - 2, 4, 7, C.gold); c.vline(x_left - 2, ay - 2, ay + 4, C.lamp)
    c.frame(x_left - 3, ay - 3, 6, 9, C.dkbrown)
    for x in range(fx + 6, x_right - 2, 4):
        c.put(x, ay + 1, C.gold if x % 8 else C.lamp)          # 秤星
        c.put(x, ay + 2, C.wood1)
    c.rect(fx - 1, ay - 2, 4, 7, C.wall1); c.vline(fx - 1, ay - 2, ay + 4, C.wall2)
    c.frame(fx - 2, ay - 3, 6, 9, C.black)
    # hook (short arm) -> rope -> tied sack
    hx = 267
    c.vline(hx, ay + 4, ay + 9, C.wall1)
    c.vline(hx + 1, ay + 4, ay + 9, C.black)
    for (dx, dy) in ((1, 10), (2, 11), (2, 12), (1, 13), (0, 13), (-1, 12)):
        c.put(hx + dx, ay + dy, C.wall2)
    neck_y = ay + 18
    c.vline(hx, ay + 13, neck_y, C.tan)
    sack = Cv(NW, NH)
    bottom = 101
    for y in range(neck_y, bottom + 1):
        t = (y - neck_y) / float(bottom - neck_y)
        half = 2.5 + 9.5 * math.sin(min(1.0, t * 1.35) * math.pi / 2) - (max(0, t - 0.85) * 22)
        for x in range(int(hx - half), int(hx + half) + 1):
            nx = (x - hx) / max(1, half)
            v = 0.66 - 0.36 * nx - 0.1 * t + 0.05 * ((x + y) % 2)
            if abs(math.sin(x * 0.7 + y * 0.12)) < 0.08 and t > 0.25:
                v -= 0.15
            sack.put(x, y, ramp(x, y, BURLAP, v))
    sack.rect(hx - 2, neck_y + 1, 5, 2, C.wood1)
    sack.put(hx - 3, neck_y - 1, C.wood3); sack.put(hx + 3, neck_y - 2, C.wood3)
    sack.rect(hx - 4, neck_y + 13, 8, 6, C.seal_red)
    sack.frame(hx - 4, neck_y + 13, 8, 6, C.dkred)
    sack.put(hx - 2, neck_y + 15, C.paper_hi); sack.put(hx + 1, neck_y + 16, C.paper_hi)
    sack.outline(C.dkbrown)
    c.blit(sack, 0, 0)
    # iron weight (秤砣) on the long arm
    wx = 310
    c.vline(wx, ay + 4, ay + 9, C.dkbrown)
    wt = Cv(NW, NH)
    wt.rect(wx - 1, ay + 9, 3, 2, C.wall1)
    wt.poly([(wx - 3, ay + 11), (wx + 3, ay + 11), (wx + 6, ay + 20), (wx - 6, ay + 20)], C.wall0)
    wt.rect(wx - 6, ay + 20, 13, 2, C.wall0)
    wt.vline(wx - 3, ay + 12, ay + 19, C.wall2)
    wt.vline(wx - 2, ay + 12, ay + 19, C.wall1)
    wt.put(wx - 2, ay + 12, C.mist)
    wt.outline(C.black)
    c.blit(wt, 0, 0)


# ================================================================== counter
def counter(c):
    x0 = PIL_L[0]
    for y in range(COUNTER_Y, FLOOR_Y):
        for x in range(x0, NW):
            if y < COUNTER_Y + 5:
                v = {0: 0.86, 1: 0.7, 2: 0.6, 3: 0.48, 4: 0.18}[y - COUNTER_Y]
                v += 0.04 * math.sin(x * 0.11) - 0.1 * x / NW
            else:
                v = 0.36 + 0.04 * math.sin(y * 1.3 + math.sin(x * 0.07) * 2) - 0.08 * x / NW
                lx = (x - x0) % 56
                ly = y - (COUNTER_Y + 5)
                if lx < 4 or ly < 3 or y >= FLOOR_Y - 7:
                    v += 0.06                                        # stiles / rails
                    if y >= FLOOR_Y - 7:
                        v = 0.2 if y > FLOOR_Y - 3 else 0.3
                else:
                    # recessed panel: top/left inner edge in shadow, bottom/right lit
                    if lx == 4 or ly == 3:
                        v = 0.12
                    elif lx == 5 or ly == 4:
                        v = 0.24
                    elif lx == 55 or y == FLOOR_Y - 8:
                        v = 0.5
                    else:
                        v = 0.32 + 0.05 * math.sin(y * 0.9 + lx * 0.15)
            c.put(x, y, ramp(x, y, WOOD, v))
    # left end of the counter (side face in light)
    for y in range(COUNTER_Y, FLOOR_Y):
        c.put(x0, y, C.tan if y < COUNTER_Y + 5 else C.wood2)
        c.put(x0 + 1, y, C.wood2 if y < COUNTER_Y + 5 else C.wood1)
    # spilled rice on the counter top
    rnd = random.Random(11)
    for _ in range(26):
        x = rnd.randint(104, 300)
        y = COUNTER_Y + rnd.randint(0, 2)
        c.put(x, y, C.white)


def counter_items(c):
    y = COUNTER_Y + 1
    # big 斗 of rice (left of the merchant)
    x0 = 104
    it = Cv(NW, NH)
    it.poly([(x0, y - 15), (x0 + 26, y - 15), (x0 + 23, y), (x0 + 3, y)], C.wood3)
    for yy in range(y - 15, y + 1):
        for xx in range(x0, x0 + 27):
            if it.get(xx, yy)[3]:
                v = 0.6 - 0.35 * (xx - x0) / 26.0
                it.put(xx, yy, ramp(xx, yy, WOOD, v))
    it.hline(x0, x0 + 26, y - 15, C.tan)
    it.hline(x0 + 1, x0 + 25, y - 13, C.wood1)
    it.hline(x0 + 2, x0 + 24, y - 6, C.wood1)
    it.put(x0 + 13, y - 10, C.paper); it.put(x0 + 12, y - 10, C.paper); it.put(x0 + 13, y - 9, C.seal_red)
    # rice heap on top
    for xx in range(x0 + 1, x0 + 26):
        t = (xx - x0 - 13) / 13.0
        top = int(y - 16 - 5 * (1 - t * t))
        for yy in range(top, y - 15):
            it.put(xx, yy, C.white if thr(xx, yy) < 0.6 - 0.3 * t else C.fog)
    it.outline(C.dkbrown)
    c.blit(it, 0, 0)
    # cast shadow right
    for yy in range(y - 12, y + 1):
        for xx in range(x0 + 26, x0 + 30):
            if thr(xx, yy) < 0.5:
                c.put(xx, yy, mix(c.get(xx, yy), C.dkbrown, 0.6))
    # abacus leaning on the shelf behind (right of the merchant)
    ax0, ay0, aw, ah = 214, y - 15, 22, 15
    ab = Cv(NW, NH)
    ab.rect(ax0, ay0, aw, ah, C.wood1)
    ab.rect(ax0 + 2, ay0 + 2, aw - 4, ah - 4, C.dkbrown)
    ab.hline(ax0 + 2, ax0 + aw - 3, ay0 + 5, C.wood2)
    for i in range(6):
        bx = ax0 + 3 + i * 3
        ab.vline(bx, ay0 + 2, ay0 + ah - 3, C.wood0)
        ab.put(bx, ay0 + 3, C.wood3); ab.put(bx, ay0 + 4 - (i % 2), C.wood3)
        for j in range(3 - (i % 3)):
            ab.put(bx, ay0 + ah - 4 - j, C.wood3)
            ab.put(bx, ay0 + ah - 7 - (i % 2), C.wood3) if i in (1, 4) else None
    ab.hline(ax0, ax0 + aw - 1, ay0, C.wood3)
    ab.outline(C.dkbrown)
    c.blit(ab, 0, 0)
    # tea cup (青花)
    tx = 244
    c.rect(tx, y - 5, 6, 5, C.white)
    c.hline(tx, tx + 5, y - 5, C.fog)
    c.put(tx + 2, y - 3, C.indigo2); c.put(tx + 3, y - 2, C.indigo2)
    c.vline(tx + 5, y - 4, y - 1, C.mist)
    c.frame(tx - 1, y - 6, 8, 7, C.dkbrown)
    c.rect(tx, y - 5, 6, 1, C.fog)
    c.put(tx + 2, y - 8, C.ww3); c.put(tx + 3, y - 10, C.ww3); c.put(tx + 2, y - 12, C.ww3)   # steam


# ================================================================== floor + foreground
def floor(c):
    for y in range(FLOOR_Y, NH):
        for x in range(NW):
            band = (y - FLOOR_Y)
            slab = (x + (band // 7) * 13) // 26
            v = 0.42 + 0.12 * (hz(slab, band // 7, 2) - 0.5) - 0.12 * x / NW
            if (x + (band // 7) * 13) % 26 == 0 or band % 7 == 6:
                v = 0.15
            c.put(x, y, ramp(x, y, [C.st0, C.st1, C.st2, C.st3], v))
    for y in range(FLOOR_Y, FLOOR_Y + 3):     # contact shadow under the counter
        for x in range(PIL_L[0], NW):
            if thr(x, y) < 0.75 - 0.25 * (y - FLOOR_Y):
                c.put(x, y, C.st0)
    rnd = random.Random(5)
    for _ in range(40):
        c.put(rnd.randint(100, 318), rnd.randint(FLOOR_Y + 2, NH - 1), C.ww1)


def sack_stack(c):
    """Tied full sacks piled under the window, cat asleep on top."""
    rnd = random.Random(3)
    sk = Cv(NW, NH)

    def lying(cx, cy, w, h, seed):
        for y in range(int(cy - h / 2), int(cy + h / 2) + 1):
            for x in range(int(cx - w / 2), int(cx + w / 2) + 1):
                nx, ny = (x - cx) / (w / 2), (y - cy) / (h / 2)
                if nx ** 4 + ny ** 2 <= 1.0:
                    v = 0.68 - 0.3 * nx - 0.3 * ny + 0.05 * ((x + y) % 2) - 0.03 * hz(x, y, seed)
                    sk.put(x, y, ramp(x, y, BURLAP, v))
        sk.rect(int(cx - 4), int(cy - 2), 7, 5, C.seal_red)
        sk.put(int(cx - 2), int(cy), C.paper_hi); sk.put(int(cx), int(cy - 1), C.paper_hi); sk.put(int(cx + 1), int(cy + 1), C.paper_hi)
        sk.vline(int(cx + w / 2 - 5), int(cy - h / 2 + 2), int(cy + h / 2 - 2), C.indigo1)
        sk.vline(int(cx - w / 2 + 6), int(cy - h / 2 + 2), int(cy + h / 2 - 2), C.wood2)
        # tied ear
        ex = int(cx + w / 2)
        sk.rect(ex, int(cy - 2), 3, 4, C.wood3)
        sk.put(ex + 3, int(cy - 3), C.tan); sk.put(ex + 3, int(cy + 2), C.tan)

    for (cx, cy, w, h) in [(22, 158, 38, 18), (60, 158, 38, 18), (24, 140, 38, 18), (62, 141, 36, 18), (42, 123, 38, 18)]:
        lying(cx, cy, w, h, cx)
    sk.outline(C.dkbrown)
    # shadow to the right of the pile
    for y in range(110, FLOOR_Y + 12):
        for x in range(60, 96):
            if sk.get(x - 4, y - 2)[3] and not sk.get(x, y)[3] and thr(x, y) < 0.6:
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.5))
    c.blit(sk, 0, 0)
    # tabby sitting on the pile, watching the sparrow on the sack (close-up scale)
    cat = Cv(26, 30)
    cat.ellipse(10, 20, 7.5, 7.5, C.tabby1)                       # body
    cat.ellipse(7, 23, 5, 4.5, C.tabby1)                          # haunch
    cat.ellipse(14, 9, 6, 5, C.tabby1)                            # head
    cat.poly([(9, 7), (10, 1), (13, 5)], C.tabby1)                # ears
    cat.poly([(15, 5), (18, 1), (19, 7)], C.tabby1)
    cat.put(10, 3, C.pink); cat.put(17, 3, C.pink); cat.put(11, 4, C.pink)
    # light from the upper-left / shade on the right
    for y in range(30):
        for x in range(26):
            p_ = cat.get(x, y)
            if p_[3]:
                if (x - 3) + (y - 3) * 0.6 < 9 and x < 12:
                    cat.put(x, y, C.tabby2)
                elif x > 15 and y > 12:
                    cat.put(x, y, C.tabby0)
    # stripes
    for (x0, y0, ln) in ((4, 15, 4), (5, 19, 5), (6, 23, 4), (3, 21, 3), (12, 14, 3)):
        for k in range(ln):
            cat.put(x0 + k, y0 + (k // 2), C.tabby0)
    for (x, y) in ((13, 5), (14, 6), (15, 5), (12, 6), (16, 6)):
        cat.put(x, y, C.tabby0)                                   # M on the forehead
    # face: white muzzle, chest, paws
    cat.ellipse(16, 11, 3, 2, C.ww0)
    cat.ellipse(14, 17, 3, 4, C.ww0)
    cat.rect(12, 26, 3, 2, C.ww0); cat.rect(16, 26, 3, 2, C.ww0)
    cat.put(15, 27, C.tabby0)
    # eyes looking right (slit pupils)
    for ex in (13, 17):
        cat.put(ex, 8, C.jade_hi); cat.put(ex + 1, 8, C.dkbrown); cat.put(ex, 9, C.jade)
    cat.put(17, 10, C.pink)                                       # nose
    cat.put(19, 11, C.ww1); cat.put(20, 10, C.ww1)                # whiskers
    # tail hanging down over the sack
    for k in range(12):
        tx, ty = 3 - (k // 5), 22 + k // 1 if k < 8 else 29
        cat.put(tx, min(29, 21 + k), C.tabby1 if k % 3 else C.tabby0)
        cat.put(tx + 1, min(29, 21 + k), C.tabby1)
    cat.outline(C.dkbrown)
    cx, cy = 30, 86
    for x in range(cx + 6, cx + 30):
        for y in (cy + 28, cy + 29):
            if thr(x, y) < 0.55:
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.45))
    c.blit(cat, cx, cy)


RICE_HI = (252, 250, 243, 255)
RICE = {
    # (highlight, light, mid, dark, grain style)
    "jing": (RICE_HI, mix(C.ww0, C.fog, 0.3), mix(C.ww1, C.fog, 0.45),
             mix(C.ww2, C.mist, 0.45), "round"),                          # 粳: pearly, cool, short round
    "xian": (C.ww0, mix(C.ww0, C.paper_hi, 0.45), mix(C.ww1, C.paper, 0.45),
             mix(C.ww2, C.paper_old, 0.5), "long"),                         # 籼: slender, faintly yellow
    "nuo":  (RICE_HI, RICE_HI, C.ww0, C.ww1, "chalk"),                      # 糯: opaque chalk white
}


def open_sack(c, cx, w, kind, seed, scoop=False, peak=18, stamp="square", patch=False):
    rnd = random.Random(seed)
    rim_y = 140
    bot = 177
    sk = Cv(NW, NH)
    hw = w / 2
    # body: slightly narrower under the roll, settles wide at the bottom
    for y in range(rim_y, bot + 1):
        t = (y - rim_y) / (bot - rim_y)
        half = hw - 3 + 4 * t ** 0.7
        if y > bot - 3:
            half -= (y - (bot - 3)) * 2
        for x in range(int(cx - half), int(cx + half) + 1):
            nx = (x - cx) / half
            v = 0.68 - 0.38 * nx - 0.16 * t + 0.05 * ((x + 2 * y) % 3 == 0) - 0.04 * ((x * 3 + y) % 5 == 0)
            if abs(math.sin((x - cx) * 0.23 + y * 0.05 + seed)) < 0.07:
                v -= 0.2                                      # folds
            sk.put(x, y, ramp(x, y, BURLAP, v))
    sx, sy = int(cx - 6), rim_y + 14
    if stamp == "square":
        sk.frame(sx, sy, 13, 11, C.seal_red)
        sk.frame(sx + 1, sy + 1, 11, 9, C.dkred)
        for (dx, dy) in ((3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (5, 4), (5, 5), (6, 6), (7, 6), (4, 7), (8, 7), (3, 5), (8, 5)):
            sk.put(sx + dx, sy + dy, C.seal_red)
    elif stamp == "round":
        sk.ellipse(cx, sy + 5, 6, 5, C.seal_red, filled=False)
        sk.ellipse(cx, sy + 5, 3, 2.5, C.dkred)
        sk.put(int(cx), sy + 5, C.seal_red)
    else:
        sk.poly([(cx, sy - 1), (cx + 7, sy + 5), (cx, sy + 11), (cx - 7, sy + 5)], C.seal_red)
        sk.poly([(cx, sy + 2), (cx + 4, sy + 5), (cx, sy + 8), (cx - 4, sy + 5)], C.dkred)
    if patch:
        px0, py0 = int(cx - hw * 0.7), rim_y + 21
        sk.rect(px0, py0, 9, 7, C.indigo1)
        sk.hline(px0, px0 + 8, py0, C.indigo2)
        sk.vline(px0, py0, py0 + 6, C.indigo2)
        sk.put(px0 + 3, py0 + 3, C.mist); sk.put(px0 + 6, py0 + 2, C.mist); sk.put(px0 + 5, py0 + 5, C.mist)
        for k in range(0, 9, 2):
            sk.put(px0 + k, py0 - 1, C.paper); sk.put(px0 + k, py0 + 7, C.paper_old)
        for k in range(0, 7, 2):
            sk.put(px0 - 1, py0 + k, C.paper); sk.put(px0 + 9, py0 + k, C.paper_old)
    for y in (rim_y + 9, rim_y + 10):
        for x in range(int(cx - hw), int(cx + hw) + 2):
            if sk.get(x, y)[3]:
                sk.put(x, y, C.indigo1 if y == rim_y + 9 else C.indigo2)
    # rice heap (drawn before the front roll): 3 flat tones + dense grain texture
    hi, lt, md, dk, style = RICE[kind]

    def heap_top(x):
        nx = (x - cx) / (hw - 1)
        bump = 1.2 * math.sin(x * 0.8 + seed * 2) + 0.8 * math.sin(x * 0.37 + seed)
        return rim_y - 6 - peak * max(0, 1 - nx * nx) ** 0.9 + (bump if abs(nx) < 0.85 else 0)
    shade = {}
    for y in range(rim_y - peak - 6, rim_y + 2):
        for x in range(int(cx - hw + 1), int(cx + hw)):
            nx = (x - cx) / (hw - 1)
            top = heap_top(x)
            if y >= top:
                v = 0.95 - 0.6 * max(0, nx + 0.1) - 0.3 * (y - top) / 22.0 + (0.12 if nx < -0.35 else 0)
                v += 0.12 * (thr(x, y) - 0.5)
                tone = 2 if v > 0.72 else (1 if v > 0.45 else 0)
                shade[(x, y)] = tone
                sk.put(x, y, (dk, md, lt)[tone])
    for (x, y), tone in shade.items():
        r = hz(x, y, seed)
        if style == "long":
            if r < 0.22 and (x + 1, y) in shade:
                sk.put(x, y, (md, lt, hi)[tone]); sk.put(x + 1, y, (md, lt, hi)[tone])
                if (x + 2, y + 1) in shade:
                    sk.put(x + 2, y + 1, (dk, md, lt)[max(0, tone - 1)])
        elif style == "round":
            if r < 0.2:
                sk.put(x, y, (md, lt, hi)[tone])
                if (x, y + 1) in shade:
                    sk.put(x, y + 1, (dk, dk, md)[tone])
        else:
            if r < 0.1:
                sk.put(x, y, (md, hi, hi)[tone])
    # crest highlight
    for x in range(int(cx - hw * 0.6), int(cx + hw * 0.05)):
        nx = (x - cx) / (hw - 1)
        top = int(math.ceil(heap_top(x)))
        sk.put(x, top, hi)
    # back edge of the rolled rim peeking out at both sides of the heap
    for x in range(int(cx - hw - 2), int(cx + hw + 3)):
        nx = (x - cx) / (hw + 2)
        if abs(nx) > 0.74:
            yb = int(rim_y - 7)
            for k in range(4):
                if not sk.get(x, yb + k)[3]:
                    sk.put(x, yb + k, ramp(x, yb + k, BURLAP, 0.45 - 0.3 * nx - 0.08 * k))
    # front roll of the rim (thick burlap doughnut)
    for x in range(int(cx - hw - 2), int(cx + hw + 3)):
        nx = (x - cx) / (hw + 2)
        yy = int(rim_y + 2 * (1 - nx * nx) ** 0.5) + (1 if (x // 5) % 3 == 0 else 0)
        for k in range(6):
            v = 0.86 - 0.42 * nx - 0.09 * k
            if k == 5:
                v = 0.22
            sk.put(x, yy - 4 + k, ramp(x, yy - 4 + k, BURLAP, v))
    if scoop:
        # wooden 升 measure dug into the heap, tilted, with a handle
        sx0, sy0 = int(cx - hw + 7), rim_y - 20
        pts = [(sx0, sy0 + 4), (sx0 + 12, sy0), (sx0 + 15, sy0 + 9), (sx0 + 3, sy0 + 13)]
        sk.poly(pts, C.wood3)
        sk.line(sx0, sy0 + 4, sx0 + 12, sy0, C.tan)
        sk.line(sx0 + 12, sy0, sx0 + 15, sy0 + 9, C.wood1)
        sk.line(sx0 + 1, sy0 + 6, sx0 + 13, sy0 + 2, C.wood1)
        sk.line(sx0 + 3, sy0 + 13, sx0 + 15, sy0 + 9, C.wood0)
        for (dx, dy) in ((3, 4), (5, 3), (7, 3), (9, 2), (4, 5), (8, 3), (6, 4)):
            sk.put(sx0 + dx, sy0 + dy, C.white)
        sk.line(sx0 + 14, sy0 + 5, sx0 + 22, sy0 + 1, C.wood2)       # handle
        sk.line(sx0 + 14, sy0 + 6, sx0 + 22, sy0 + 2, C.wood1)
    sk.outline(C.dkbrown)
    # drop shadow to the lower right (on the floor + counter face)
    for y in range(rim_y - 22, bot + 4):
        for x in range(int(cx - hw), int(cx + hw + 9)):
            if sk.get(x - 5, y - 2)[3] and not sk.get(x, y)[3] and thr(x, y) < 0.62:
                c.put(x, y, mix(c.get(x, y), C.black, 0.45))
    c.blit(sk, 0, 0)
    return sk


def price_slip(c, x, y, name, price, stick_to, up=False):
    """Paper price tag clipped to a split-bamboo stick stuck into the rice."""
    m1 = font_mask(name, 12, spacing=1)
    m2 = font_mask(price, 12, spacing=1)
    w = max(m1.width, m2.width + (6 if up else 0)) + 6
    h = m1.height + m2.height + 9
    # bamboo stick
    sx = x + w // 2
    c.vline(sx, y + h, stick_to, C.wood3)
    c.vline(sx + 1, y + h, stick_to, C.wood1)
    c.put(sx + 1, y + h + 5, C.wood0)
    sl = Cv(NW, NH)
    sl.rect(x, y, w, h, C.paper_hi)
    sl.hline(x, x + w - 1, y, C.seal_red)
    sl.hline(x, x + w - 1, y + 1, C.dkred)
    sl.dither(x, y + h - 3, w, 3, C.paper_hi, C.paper, 0.5)
    sl.vline(x + w - 1, y + 2, y + h - 1, C.paper)
    sl.put(x + w - 1, y + h - 1, C.paper_old)
    for (m, ty, col) in ((m1, y + 3, C.dkbrown), (m2, y + 4 + m1.height + 1, C.seal_red)):
        mp = m.load()
        tx = x + (w - m.width - (6 if (up and m is m2) else 0)) // 2
        for yy in range(m.height):
            for xx in range(m.width):
                if mp[xx, yy] > 127:
                    sl.put(tx + xx, ty + yy, col)
    if up:
        ax = x + w - 7
        ay = y + 4 + m1.height + 1
        for (dx, dy) in ((2, 0), (1, 1), (2, 1), (3, 1), (0, 2), (2, 2), (4, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8)):
            sl.put(ax + dx, ay + dy, C.seal_red)
    sl.outline(C.dkbrown)
    # bamboo clip over the top
    sl.rect(sx - 1, y - 3, 3, 5, C.wood3)
    sl.put(sx - 1, y - 3, C.tan)
    sl.vline(sx + 1, y - 3, y + 1, C.wood1)
    # shadow of the slip on what's behind
    for yy in range(y + 2, y + h + 2):
        for xx in range(x + w + 1, x + w + 3):
            if thr(xx, yy) < 0.6:
                c.put(xx, yy, mix(c.get(xx, yy), C.black, 0.4))
    c.blit(sl, 0, 0)
    return (x, y, w, h)


def sparrow(c, x, y):
    """House sparrow facing left, head dipped to peck at the rice (18x12)."""
    sp = Cv(18, 12)
    sp.ellipse(10, 6, 5.5, 3.6, C.wood2)                  # body
    sp.ellipse(9, 8, 4.5, 2.2, C.ww2)                     # pale belly
    sp.poly([(14, 4), (17, 1), (17, 3), (15, 6)], C.wood1)  # cocked tail
    sp.ellipse(5, 6, 3.2, 3.0, C.wood2)                   # head
    sp.hline(3, 7, 3, C.dkred); sp.hline(4, 7, 4, C.wood1)   # chestnut crown
    sp.rect(3, 5, 3, 2, C.ww0)                            # white cheek
    sp.put(5, 6, C.wood0)                                 # cheek spot
    sp.put(4, 5, C.black)                                 # eye
    sp.rect(3, 7, 3, 2, C.black)                          # black bib
    sp.put(1, 7, C.wood3); sp.put(2, 7, C.wood1); sp.put(1, 8, C.wood1)   # beak, pecking down
    # back streaks + white wing bar
    for (px_, py_) in ((9, 3), (11, 3), (12, 4), (10, 4), (13, 5)):
        sp.put(px_, py_, C.wood0)
    sp.hline(9, 13, 6, C.paper_hi)
    sp.hline(10, 13, 7, C.wood1)
    # legs
    sp.put(8, 10, C.wood1); sp.put(11, 10, C.wood1); sp.put(7, 11, C.wood1); sp.put(10, 11, C.wood1)
    sp.outline(C.dkbrown)
    # tiny shadow on the rice
    for xx in range(x + 5, x + 16):
        if thr(xx, y + 12) < 0.6:
            c.put(xx, y + 12, mix(c.get(xx, y + 12), C.ww3, 0.7))
    c.blit(sp, x, y)


# ================================================================== light + grade
def light_shafts(img):
    """Dithered warm shafts from the window falling down-right, plus dust motes."""
    px = img.load()
    x0, y0, x1, y1 = WIN
    for y in range(y1 + 4, NH):
        for x in range(0, NW):
            # project back along the light direction (dx/dy = 0.55)
            sx = x - (y - y1) * 0.55
            if x0 <= sx <= x1:
                lx = (sx - x0) % 16
                if lx < 2 or 14 < lx:
                    continue
                fall = max(0.0, 1.0 - (y - y1) / 110.0)
                a = 0.24 * fall
                if thr(x, y) < 0.7:
                    r, g, b = px[x, y][:3]
                    px[x, y] = (int(r + (255 - r) * a), int(g + (236 - g) * a), int(b + (190 - b) * a * 0.8), 255)
    rnd = random.Random(21)
    for _ in range(22):
        y = rnd.randint(y1 + 4, 150)
        x = int(rnd.uniform(x0, x1) + (y - y1) * 0.55)
        r, g, b = px[x, y][:3]
        px[x, y] = (min(255, r + 70), min(255, g + 62), min(255, b + 40), 255)


def grade(img):
    im = img.convert("RGB")
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            l = (r + g + b) / 3
            s = 1.12
            r, g, b = (l + (r - l) * s, l + (g - l) * s, l + (b - l) * s)
            r = r * 1.05 + 6
            g = g * 1.01 + 2
            b = b * 0.92
            d = ((x / W - 0.18) ** 2 * 0.9 + (y / H - 0.25) ** 2)
            f = 1.0 - min(0.3, d * 0.5)
            px[x, y] = tuple(max(0, min(255, int(v * f))) for v in (r, g, b))
    return im


# ================================================================== build
def build():
    c = Cv(NW, NH, C.wood1)
    wall(c)
    window(c)
    pillar(c, *PIL_L)
    pillar(c, *PIL_R)
    banner(c)
    curtain(c)
    shelf_and_bins(c)
    plaque(c)
    lantern(c, 134, 18)
    calendar(c)
    steelyard(c)
    bg_only = c.img.copy()
    # merchant (behind the counter)
    merch = Image.open(os.path.join(ASSETS, "portraits", "B2_wu_merchant.png")).convert("RGBA")
    c.blit(merch, MERCH_X, COUNTER_Y - 64)
    counter(c)
    counter_items(c)
    floor(c)
    sack_stack(c)
    # foreground open sacks
    open_sack(c, 160, 56, "jing", 1, peak=17, stamp="square")
    open_sack(c, 222, 56, "xian", 2, scoop=True, peak=19, stamp="round")
    open_sack(c, 284, 56, "nuo", 3, peak=15, stamp="diamond", patch=True)
    price_slip(c, 130, 92, "粳米", "73", 126, up=True)
    price_slip(c, 218, 95, "籼米", "61", 126)
    price_slip(c, 270, 93, "糯米", "80", 124)
    sparrow(c, 107, 76)
    return c, bg_only


# ================================================================== UI (full resolution)
def bubble_native(w, h, fill=None, border=None):
    """Parchment speech bubble body (native UI px; scaled x3)."""
    fill = fill or C.paper_hi
    b = Cv(w, h)
    b.rect(2, 0, w - 4, h, C.dkbrown)
    b.rect(0, 2, w, h - 4, C.dkbrown)
    b.rect(1, 1, w - 2, h - 2, C.dkbrown)
    b.rect(2, 1, w - 4, h - 2, fill)
    b.rect(1, 2, w - 2, h - 4, fill)
    b.hline(3, w - 4, h - 2, C.paper)
    b.vline(w - 2, 3, h - 4, C.paper)
    b.dither(2, h - 5, w - 4, 3, fill, C.paper, 0.4)
    return b


def ui(img):
    W, H = img.size
    d = ImageDraw.Draw(img)
    U = 3
    ink = C.dkbrown
    # ---------------- top-right HUD (same panel as A1)
    pw, ph = 92, 42
    pnl = scale(panel_native(pw, ph).img, U)
    px0, py0 = W - pnl.width - 10, 8
    img.alpha_composite(pnl, (px0, py0))
    t = "二月初五 · 星期六"
    tw = font_mask(t, 12, spacing=1).width * 2
    pixel_text(img, px0 + (pnl.width - tw) // 2, py0 + 16, t, ink, 12, 2)
    d.rectangle((px0 + 18, py0 + 48, px0 + pnl.width - 18, py0 + 50), fill=C.wood3)
    sun = scale(a1_load("ui", "sun_cloud.png"), U)
    img.alpha_composite(sun, (px0 + 20, py0 + 54))
    pixel_text(img, px0 + 92, py0 + 60, "上午 9:40", ink, 12, 2)
    mx0, my0, mx1 = px0 + 20, py0 + 90, px0 + pnl.width - 20
    d.rectangle((mx0, my0, mx1, my0 + 26), fill=C.wood1, outline=C.dkbrown, width=3)
    d.rectangle((mx0 + 3, my0 + 3, mx1 - 3, my0 + 5), fill=C.wood0)
    coin = scale(a1_load("ui", "coin.png"), 2)
    img.alpha_composite(coin, (mx0 + 8, my0 + 3))
    money = "600 蚨"
    mw = font_mask(money, 12, spacing=1).width * 2
    pixel_text(img, mx1 - 10 - mw, my0 + 2, money, C.lamp, 12, 2, shadow=C.dkbrown)

    # ---------------- merchant speech bubble (left of him, tail to the mouth)
    lines = ["沈姑娘，今儿米船没到，", "粳米又涨了三蚨。"]
    mouth = ((MERCH_X + 24) * K, (COUNTER_Y - 64 + 32) * K)
    lh = 32
    tw = max(font_mask(s, 12, spacing=1).width for s in lines) * 2
    bw_n = (tw + 44) // U + 1
    bh_n = (len(lines) * lh + 34) // U + 1
    bx1 = mouth[0] - 56
    bx0 = bx1 - bw_n * U
    by0 = 178
    bub = scale(bubble_native(bw_n, bh_n).img, U)
    img.alpha_composite(bub, (bx0, by0))
    # tail (pixel steps) from the bubble's right edge toward the mouth
    tail = Cv(24, 14)
    for i in range(12):
        tail.hline(0, max(0, 14 - i * 1 - (i // 2)), i, C.paper_hi)
    tail.outline(C.dkbrown)
    for i in range(12):
        tail.put(0, i, C.paper_hi)
    ty_ = by0 + bub.height - 44
    img.alpha_composite(scale(tail.img, U), (bx1 - U * 2, ty_))
    # name plate
    name = "吴掌柜"
    nw = font_mask(name, 12, spacing=1).width * 2
    d = ImageDraw.Draw(img)
    d.rectangle((bx0 + 14, by0 - 22, bx0 + 14 + nw + 28, by0 + 12), fill=C.dkred, outline=C.dkbrown, width=3)
    d.rectangle((bx0 + 17, by0 - 19, bx0 + 11 + nw + 28, by0 - 17), fill=C.seal_red)
    pixel_text(img, bx0 + 28, by0 - 16, name, C.paper_hi, 12, 2)
    for i, s in enumerate(lines):
        pixel_text(img, bx0 + 22, by0 + 24 + i * lh, s, ink, 12, 2)
    # continue marker
    d.polygon([(bx1 - 34, by0 + bub.height - 26), (bx1 - 20, by0 + bub.height - 26), (bx1 - 27, by0 + bub.height - 18)], fill=C.seal_red)

    # ---------------- player portrait bubble + choices (bottom-left)
    rh = Image.open(os.path.join(ASSETS, "portraits", "B2_ruhua.png")).convert("RGBA")
    crop = rh.crop((9, 5, 41, 41))                      # 32x36 head + shoulders
    fr_n = Cv(38, 42)
    fr_n.rect(0, 0, 38, 42, C.dkbrown)
    fr_n.rect(1, 1, 36, 40, C.wood2)
    fr_n.hline(1, 36, 1, C.tan); fr_n.vline(1, 1, 40, C.tan)
    fr_n.hline(2, 36, 40, C.wood1); fr_n.vline(36, 2, 40, C.wood1)
    for y in range(3, 39):
        for x in range(3, 35):
            fr_n.put(x, y, ramp(x, y, [C.wa1, C.wa2, C.wa3], 0.75 - (y - 3) / 50.0 - (x - 3) / 90.0))
    fr_n.img.alpha_composite(crop, (3, 3))
    fr_n.px = fr_n.img.load()
    fr_n.frame(2, 2, 34, 38, C.dkbrown)
    for (x, y) in ((1, 1), (36, 1), (1, 40), (36, 40)):
        fr_n.put(x, y, C.gold)
    fr = scale(fr_n.img, U)
    fx0, fy0 = 18, H - fr.height - 30
    img.alpha_composite(fr, (fx0, fy0))
    d = ImageDraw.Draw(img)
    nm = "沈如花"
    nmw = font_mask(nm, 12, spacing=1).width * 2
    ny0 = fy0 + fr.height - 22
    d.rectangle((fx0 + (fr.width - nmw) // 2 - 12, ny0, fx0 + (fr.width + nmw) // 2 + 12, ny0 + 32), fill=C.indigo1, outline=C.dkbrown, width=3)
    d.rectangle((fx0 + (fr.width - nmw) // 2 - 9, ny0 + 3, fx0 + (fr.width + nmw) // 2 + 9, ny0 + 5), fill=C.indigo2)
    pixel_text(img, fx0 + (fr.width - nmw) // 2, ny0 + 5, nm, C.paper_hi, 12, 2)

    opts = [("1", "买一斗"), ("2", "问米船的事"), ("3", "回头再说")]
    row_h = 46
    ow = max(font_mask(s, 12, spacing=1).width for _, s in opts) * 2 + 136
    cw_n = (ow + 30) // U
    ch_n = (len(opts) * row_h + 36) // U
    cbx0 = fx0 + fr.width + 34
    cby0 = H - ch_n * U - 18
    cb = scale(bubble_native(cw_n, ch_n).img, U)
    img.alpha_composite(cb, (cbx0, cby0))
    # tail pointing left to the portrait
    tl = Cv(12, 14)
    for i in range(12):
        tl.hline(11 - i + (i // 3), 11, i, C.paper_hi)
    tl.outline(C.dkbrown)
    for i in range(12):
        tl.put(11, i, C.paper_hi)
    img.alpha_composite(scale(tl.img, U), (cbx0 - 11 * U + 3, cby0 + 46))
    d = ImageDraw.Draw(img)
    for i, (k, s) in enumerate(opts):
        ry = cby0 + 18 + i * row_h
        sel = i == 0
        if sel:
            d.rectangle((cbx0 + 12, ry - 4, cbx0 + cb.width - 14, ry + row_h - 10), fill=C.tan, outline=C.wood1, width=3)
            # pointer
            d.polygon([(cbx0 + 20, ry + 4), (cbx0 + 34, ry + 16), (cbx0 + 20, ry + 28)], fill=C.seal_red, outline=C.dkbrown)
        # key cap
        kx = cbx0 + 44
        d.rectangle((kx, ry + 2, kx + 26, ry + 30), fill=C.paper if not sel else C.paper_hi, outline=C.wood1, width=2)
        d.rectangle((kx + 2, ry + 26, kx + 24, ry + 28), fill=C.paper_old)
        pixel_text(img, kx + 6, ry + 3, k, C.dkbrown, 12, 2)
        pixel_text(img, kx + 44, ry + 4, s, C.dkbrown if sel else C.wood1, 12, 2)

    # ---------------- mockup label (top-left)
    label = "示意图 B：店内侧视特写（每家店一张背景）"
    lw = font_mask(label, 16, spacing=0).width
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((8, 8, 8 + lw + 18, 36), fill=(15, 10, 8, 185))
    img.alpha_composite(ov)
    pixel_text(img, 17, 13, label, C.paper_hi, 16, 1)
    # exit hint (bottom-right)
    hint = "Esc 出门"
    hw = font_mask(hint, 12, spacing=1).width * 2
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((W - hw - 34, H - 46, W - 10, H - 10), fill=(15, 10, 8, 170))
    img.alpha_composite(ov)
    pixel_text(img, W - hw - 22, H - 42, hint, C.paper_hi, 12, 2)
    return img


def main():
    c, bg_only = build()
    bg_only.save(os.path.join(ASSETS, "B2_ricehall_bg.png"))
    native = c.img.copy()
    light_shafts(native)
    graded = grade(native).convert("RGBA")
    graded.save(os.path.join(HERE, "B2_ricehall_sideview_native.png"))
    big = scale(graded, K)
    big = ui(big)
    big.convert("RGB").save(os.path.join(HERE, "B2_ricehall_sideview.png"))
    print("ok", big.size)


if __name__ == "__main__":
    main()
