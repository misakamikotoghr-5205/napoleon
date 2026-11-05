"""Side-view shop interiors, 320x180, fully opaque.

Rice hall reuses compose_B2 (wall, counter, sacks, scale, price slips) without the keeper.
Other shops are drawn here. Light comes from the upper left. Portrait is overlaid later.
"""
import math
import os
import random
import sys
import json

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C, mix, font_mask  # noqa: E402

W, H = 320, 180
OUT = os.path.join(ROOT, "art", "town", "shops")
META_PATH = os.path.join(ROOT, "tools", "art", "town", "shop_meta.json")

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
WOOD = [C.black, C.dkbrown, C.wood0, C.wood1, C.wood2, C.wood3, C.tan, C.lamp_pale]
PLASTER = [C.ww3, C.ww2, C.ww1, C.ww0]
GREY = [C.wall0, C.wall1, C.wall2, C.mist, C.fog, C.white]
SKY = [C.wa2, C.wa3, C.wa4, C.wa5, C.st5, C.paper_hi]


def hz(x, y, s=0.0):
    v = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
    return v - math.floor(v)


def thr(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def ramp(x, y, cols, v):
    v = max(0.0, min(0.999, v))
    f = v * (len(cols) - 1)
    i = min(int(f), len(cols) - 2)
    return cols[i + 1] if thr(x, y) < (f - i) else cols[i]


def shadow(c, x, y, w, h=3, amt=0.5):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if thr(xx, yy) < 0.62 - 0.15 * (yy - y):
                p = c.get(xx, yy)
                if p[3]:
                    c.put(xx, yy, mix(p, C.black, amt))


def blit_ol(c, s, x, y, oc=None):
    s.outline(oc or C.dkbrown)
    c.blit(s, x, y)


def ceiling(c, y1=16):
    for y in range(0, y1 - 5):
        for x in range(W):
            r = x % 18
            v = 0.08 if r < 2 else (0.2 if r < 10 else 0.14)
            v += 0.04 * (y / max(1, y1))
            v -= 0.08 * x / W
            c.put(x, y, ramp(x, y, WOOD, v))
    for y in range(y1 - 5, y1 + 1):
        for x in range(W):
            v = {0: 0.62, 1: 0.48, 4: 0.12, 5: 0.08}.get(y - (y1 - 5), 0.34)
            v -= 0.1 * x / W
            c.put(x, y, ramp(x, y, WOOD, v))
    for y in range(y1 + 1, y1 + 5):
        for x in range(W):
            if thr(x, y) < 0.55 - (y - y1) * 0.12:
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.4))


def planks(c, x0, y0, x1, y1, seed=1):
    rnd = random.Random(seed)
    x = x0
    boards = []
    while x < x1:
        bw = rnd.choice((9, 10, 11, 12, 13))
        boards.append((x, min(x1, x + bw), rnd.random()))
        x += bw
    span = max(1, x1 - x0)
    for xa, xb, t in boards:
        bright = 0.9 - 0.75 * ((xa - x0) / span)
        r2 = random.Random(int(t * 1e6) + seed)
        for y in range(y0, y1):
            for xx in range(xa, xb):
                if xx == xa:
                    col = C.dkbrown
                elif xx == xa + 1:
                    col = C.wood3 if bright > 0.4 else C.wood2
                elif bright > 0.58:
                    col = C.wood2
                elif bright > 0.34:
                    col = C.wood1
                else:
                    col = C.wood0
                if y > y0 + int((y1 - y0) * 0.62) and thr(xx, y) < 0.4:
                    col = mix(col, C.dkbrown, 0.42)
                c.put(xx, y, col)
        if xb - xa > 6:
            for _ in range(3):
                gx = r2.randint(xa + 2, xb - 2)
                gy = r2.randint(y0 + 2, max(y0 + 3, y1 - 14))
                for k in range(r2.randint(6, 16)):
                    if gy + k < y1:
                        c.put(gx + (k // 8), gy + k, C.wood0 if bright > 0.45 else C.dkbrown)
            if t > 0.72:
                kx = (xa + xb) // 2
                ky = y0 + 10 + int(t * 30) % max(1, (y1 - y0 - 20))
                c.ellipse(kx, ky, 1.6, 2.2, C.dkbrown)


def plaster(c, x0, y0, x1, y1, lx, ly, cols, speckle=True):
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot((x - lx) / 120.0, (y - ly) / 100.0)
            v = 0.9 - 0.58 * d + (0.05 * (hz(x, y) - 0.5) if speckle else 0.0)
            if y > y0 + int((y1 - y0) * 0.75):
                v -= 0.14
            v = max(0.0, min(0.999, v))
            if speckle:
                c.put(x, y, ramp(x, y, cols, v))
            else:
                f = v * (len(cols) - 1)
                i = min(int(f), len(cols) - 2)
                frac = f - i
                if 0.3 < frac < 0.7 and thr(x, y) < frac:
                    col = cols[i + 1]
                else:
                    col = cols[i if frac < 0.5 else i + 1]
                c.put(x, y, col)


def wood_floor(c, y0, seed=2):
    for y in range(y0, H):
        for x in range(W):
            band = (x + (y // 14) * 5) // 18
            v = 0.32 + 0.1 * (hz(band, y // 14, seed) - 0.5) - 0.14 * x / W
            if (x + (y // 14) * 5) % 18 == 0:
                v = 0.1
            c.put(x, y, ramp(x, y, WOOD, v))
    for y in range(y0, y0 + 3):
        for x in range(W):
            if thr(x, y) < 0.7 - 0.2 * (y - y0):
                c.put(x, y, mix(c.get(x, y), C.black, 0.45))


def stone_floor(c, y0):
    for y in range(y0, H):
        for x in range(W):
            slab = (x // 22 + (y // 8) * 3)
            v = 0.45 + 0.14 * (hz(slab, y // 8, 2) - 0.5) - 0.2 * x / W
            if x % 22 == 0 or (y - y0) % 8 == 7:
                v = 0.16
            c.put(x, y, ramp(x, y, [C.st0, C.st1, C.st2, C.st3, C.st4], v))


def counter(c, x0, x1, top, bot, lip=C.tan):
    for y in range(top, bot):
        for x in range(x0, x1):
            if y < top + 4:
                v = (0.86, 0.68, 0.52, 0.28)[y - top]
                v -= 0.12 * x / W
            else:
                lx = (x - x0) % 52
                if lx < 3 or y >= bot - 6:
                    v = 0.22 if y < bot - 3 else 0.14
                elif lx in (3, 4):
                    v = 0.12
                else:
                    v = 0.34 + 0.04 * math.sin(y * 0.8 + lx * 0.1)
                v -= 0.1 * x / W
            c.put(x, y, ramp(x, y, WOOD, v))
    c.hline(x0, x1 - 1, top, lip)
    c.vline(x0, top, bot - 1, C.wood3)
    c.vline(x0 + 1, top, bot - 1, C.wood2)
    c.vline(x1 - 1, top, bot - 1, C.dkbrown)


def plaque(c, x, y, text, face, ink, rim=None, size=12):
    m = font_mask(text, size)
    w, h = m.width + 12, m.height + 8
    rim = rim or C.dkbrown
    c.rect(x + 1, y + 2, w, h, C.black)
    c.rect(x, y, w, h, rim)
    c.rect(x + 2, y + 2, w - 4, h - 4, face)
    c.hline(x + 2, x + w - 3, y + 2, mix(face, C.white, 0.35))
    c.text(x + 6, y + 4, text, ink, size=size, shadow=C.black)
    return w, h


def steam(c, x, y, n=8, seed=1):
    rnd = random.Random(seed)
    for i in range(n):
        xx = x + int(math.sin(i * 1.4 + seed) * 2)
        yy = y - i * 2
        if rnd.random() < 0.25:
            continue
        col = C.ww0 if i % 2 == 0 else C.fog
        c.put(xx, yy, col)
        if i % 3 == 0:
            c.put(xx + 1, yy, C.paper)


def lantern(c, x, y, beam=16):
    c.vline(x + 7, beam, y, C.dkbrown)
    s = Cv(16, 26)
    s.rect(5, 1, 6, 2, C.gold)
    s.ellipse(7, 9, 6, 6, C.lantern)
    for yy in range(3, 16):
        for xx in range(1, 15):
            p = s.get(xx, yy)
            if p[3] and p[:3] == C.lantern[:3]:
                if xx < 6:
                    s.put(xx, yy, C.lantern_hi)
                elif xx > 10:
                    s.put(xx, yy, C.seal_red)
    s.rect(5, 15, 6, 2, C.gold)
    for k in range(6):
        s.put(7, 17 + k, C.seal_red if k < 5 else C.dkred)
        if k > 1:
            s.put(6 + (k % 2), 17 + k, C.dkred)
    blit_ol(c, s, x, y)


def teacup(c, x, y, seed=1):
    s = Cv(12, 10)
    s.rect(1, 3, 7, 5, C.white)
    s.hline(1, 7, 3, C.paper_hi)
    s.vline(7, 3, 7, C.fog)
    s.put(3, 5, C.indigo2)
    s.put(4, 6, C.indigo1)
    s.put(9, 4, C.white)
    s.put(10, 5, C.fog)
    s.put(10, 6, C.fog)
    s.put(9, 7, C.white)
    blit_ol(c, s, x, y)
    steam(c, x + 4, y + 2, n=6, seed=seed)


def teapot(c, x, y, seed=2):
    s = Cv(18, 14)
    s.ellipse(8, 8, 6, 4, C.white)
    s.ellipse(6, 7, 3, 2, C.paper_hi)
    s.rect(6, 3, 5, 3, C.fog)
    s.put(8, 2, C.indigo1)
    s.line(13, 7, 16, 4, C.indigo2)
    s.line(13, 8, 16, 5, C.white)
    s.put(2, 7, C.white)
    s.put(1, 8, C.fog)
    s.put(2, 9, C.white)
    s.hline(5, 11, 10, C.indigo2)
    blit_ol(c, s, x, y)
    steam(c, x + 8, y + 1, n=7, seed=seed)


def kettle(c, x, y, seed=4):
    s = Cv(18, 16)
    s.ellipse(8, 10, 6, 4, C.wall1)
    s.ellipse(6, 9, 3, 2, C.mist)
    s.rect(6, 5, 5, 2, C.wall2)
    s.vline(8, 3, 5, C.wall0)
    s.line(13, 9, 16, 6, C.wall2)
    s.line(13, 10, 16, 7, C.mist)
    s.put(2, 9, C.wall0)
    s.put(1, 10, C.wall1)
    s.put(2, 11, C.wall2)
    blit_ol(c, s, x, y, C.black)
    steam(c, x + 8, y + 2, n=8, seed=seed)


def caddy(c, x, y):
    s = Cv(12, 14)
    s.rect(1, 3, 9, 9, C.dkred)
    s.rect(1, 3, 9, 2, C.seal_red)
    s.hline(1, 9, 3, C.lantern_hi)
    s.rect(3, 6, 5, 3, C.gold)
    blit_ol(c, s, x, y)


def table(c, x, y, w=46, leg=24):
    shadow(c, x + 4, y + 4 + leg, w - 4, 3)
    c.rect(x, y, w, 4, C.wood2)
    c.hline(x, x + w - 1, y, C.tan)
    c.hline(x, x + w - 1, y + 3, C.wood0)
    c.rect(x + 2, y + 4, w - 4, 3, C.wood1)
    c.rect(x + 3, y + 4, 3, leg, C.wood2)
    c.vline(x + 3, y + 4, y + 4 + leg, C.wood3)
    c.rect(x + w - 6, y + 4, 3, leg, C.wood1)
    c.vline(x + w - 4, y + 4, y + 4 + leg, C.dkbrown)


def stool(c, x, y):
    c.rect(x, y, 12, 3, C.wood2)
    c.hline(x, x + 11, y, C.tan)
    c.rect(x + 1, y + 3, 2, 10, C.wood1)
    c.rect(x + 9, y + 3, 2, 10, C.wood0)
    shadow(c, x + 2, y + 13, 12, 2)


def paper_board(c, x, y, w, h, lines=5, seed=1, seal=False, header=None):
    c.rect(x + 2, y + 2, w, h, C.black)
    c.rect(x, y, w, h, C.paper)
    c.frame(x, y, w, h, C.wood0)
    c.hline(x + 1, x + w - 2, y + 1, C.paper_hi)
    c.vline(x + w - 1, y + 1, y + h - 2, C.paper_old)
    rnd = random.Random(seed)
    top = 5
    if header:
        c.hline(x + 3, x + w - 4, y + 4, header)
        c.hline(x + 3, x + w - 4, y + 5, header)
        top = 9
    for i in range(lines):
        ln = rnd.randint(w // 3, w - 8)
        yy = y + top + i * max(3, (h - top - 8) // max(1, lines))
        if yy < y + h - 6:
            c.hline(x + 4, x + 4 + ln, yy, C.gray if i % 4 else C.wood1)
    if seal:
        c.rect(x + w - 12, y + h - 14, 8, 8, C.seal_red)
        c.frame(x + w - 12, y + h - 14, 8, 8, C.dkred)
        c.put(x + w - 9, y + h - 11, C.paper_hi)


def jar(c, x, y, w=10, h=14, body=C.white, band=C.indigo2, lid=C.wood2):
    s = Cv(w + 4, h + 4)
    s.rect(3, 1, w - 4, 3, lid)
    s.hline(3, w - 2, 1, C.tan if lid == C.wood2 else C.paper_hi)
    s.rect(1, 4, w, h - 3, body)
    s.vline(1, 4, h, mix(body, C.white, 0.45))
    s.vline(w, 4, h, mix(body, C.black, 0.35))
    s.hline(2, w - 1, 7, band)
    s.hline(2, w - 1, 8, mix(band, C.black, 0.3))
    blit_ol(c, s, x, y)


def herbs(c, x, y0, y1):
    c.vline(x, 16, y0, C.tan)
    cols = (C.g0, C.g1, C.moss, C.g2, C.g3, C.wood2)
    for i, col in enumerate(cols):
        c.line(x, y0, x - 7 + i * 3, y1, col)
    c.rect(x - 3, y0 - 1, 7, 3, C.paper)
    c.hline(x - 3, x + 3, y0 - 1, C.tan)


def gourd(c, x, y):
    c.vline(x, y, y + 4, C.wood1)
    s = Cv(14, 18)
    s.ellipse(6, 5, 3, 3, C.gold)
    s.ellipse(6, 11, 5, 4, C.gold)
    s.put(4, 4, C.lamp)
    s.put(3, 10, C.lamp)
    s.put(9, 13, C.wood3)
    blit_ol(c, s, x - 6, y + 3)


def mortar(c, x, y):
    s = Cv(18, 14)
    s.ellipse(7, 8, 6, 4, C.st3)
    s.ellipse(6, 7, 3, 2, C.st4)
    s.ellipse(7, 8, 3, 1, C.st1)
    s.line(11, 6, 16, 1, C.wood2)
    s.line(11, 7, 16, 2, C.wood3)
    blit_ol(c, s, x, y)


def balance(c, x, y):
    s = Cv(28, 22)
    s.rect(10, 8, 2, 10, C.wood1)
    s.hline(4, 20, 8, C.gold)
    s.hline(4, 20, 7, C.lamp)
    s.poly([(6, 18), (16, 18), (18, 20), (4, 20)], C.wood2)
    s.line(4, 8, 2, 12, C.wall2)
    s.line(20, 8, 23, 12, C.wall1)
    s.hline(0, 6, 12, C.mist)
    s.hline(18, 25, 12, C.wall2)
    s.ellipse(3, 14, 3, 1, C.wall1)
    s.ellipse(21, 14, 3, 1, C.wall0)
    blit_ol(c, s, x, y, C.black)


def abacus(c, x, y, w=40, h=20):
    s = Cv(w + 2, h + 2)
    s.rect(1, 1, w, h, C.wood1)
    s.rect(3, 3, w - 4, h - 4, C.dkbrown)
    s.hline(1, w, 1, C.wood3)
    mid = 3 + (h - 4) // 2
    s.hline(3, w - 2, mid, C.wood2)
    rods = 8
    step = max(3, (w - 10) // rods)
    for i in range(rods):
        bx = 5 + i * step
        s.vline(bx, 3, h - 2, C.wood0)
        s.rect(bx - 1, 5, 3, 2, C.wood3)
        for j in range(2 + (i % 3)):
            s.rect(bx - 1, h - 4 - j * 3, 3, 2, C.tan if j == 0 else C.wood3)
    blit_ol(c, s, x, y)


def lattice_window(c, x, y, w, h, glow, frame=C.wood1, bar=C.wood0):
    c.rect(x - 2, y - 2, w + 4, h + 4, frame)
    c.hline(x - 2, x + w + 1, y - 2, mix(frame, C.white, 0.3))
    c.vline(x - 2, y - 2, y + h + 1, mix(frame, C.white, 0.3))
    c.hline(x - 2, x + w + 1, y + h + 1, C.dkbrown)
    c.vline(x + w + 1, y - 2, y + h + 1, C.dkbrown)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            d = math.hypot((xx - x) / max(1, w), (yy - y) / max(1, h) * 0.6)
            c.put(xx, yy, ramp(xx, yy, glow, 0.85 - 0.4 * d))
    for xx in range(x, x + w, 8):
        c.vline(xx, y, y + h - 1, bar)
    for yy in range(y, y + h, 8):
        c.hline(x, x + w - 1, yy, bar)


def telegraph(c, x, y):
    s = Cv(26, 18)
    s.rect(1, 8, 22, 8, C.wood1)
    s.hline(1, 22, 8, C.wood3)
    s.rect(4, 4, 8, 3, C.gold)
    s.hline(4, 11, 4, C.lamp)
    s.put(6, 3, C.wood0)
    s.rect(14, 2, 3, 7, C.wall1)
    s.rect(18, 2, 3, 7, C.wall2)
    s.hline(14, 20, 2, C.mist)
    s.vline(16, 0, 2, C.dkbrown)
    s.put(8, 6, C.dkbrown)
    blit_ol(c, s, x, y, C.black)


def pigeonholes(c, x, y, cols, rows, cw=14, ch=12):
    wd, hd = cols * cw + 4, rows * ch + 6
    c.rect(x + 2, y + 2, wd, hd, C.black)
    c.rect(x, y, wd, hd, C.wood1)
    c.rect(x, y, wd, 3, C.postgreen)
    c.hline(x, x + wd - 1, y, C.postgreen_hi)
    c.hline(x, x + wd - 1, y + 1, C.wood3)
    for j in range(rows):
        for i in range(cols):
            xx = x + 2 + i * cw
            yy = y + 4 + j * ch
            c.rect(xx, yy, cw - 2, ch - 2, C.black)
            c.hline(xx, xx + cw - 3, yy, C.dkbrown)
            kind = (i * 5 + j * 3 + cols) % 5
            if kind != 0:
                col = C.paper_hi if kind % 2 == 0 else C.paper
                lh = ch - 6
                c.rect(xx + 2, yy + 2, cw - 6, lh, col)
                if cw > 8:
                    c.hline(xx + 3, xx + cw - 7, yy + 4, C.paper_old)
                if kind == 3:
                    c.put(xx + cw - 6, yy + 3, C.seal_red)


def garment(c, x, y, kind, main, hi, lo, length=26, patch=False):
    c.vline(x + 8, y - 14, y, C.dkbrown)
    c.hline(x + 3, x + 13, y, C.wood2)
    c.put(x + 8, y - 14, C.wood1)
    if kind == "pants":
        s = Cv(16, length)
        s.rect(3, 2, 10, 4, main)
        s.rect(3, 6, 4, length - 8, main)
        s.rect(8, 6, 4, length - 8, main)
        s.vline(3, 6, length - 3, hi)
        s.vline(11, 6, length - 3, lo)
        s.hline(3, 12, 2, hi)
        if patch:
            s.rect(4, 12, 3, 3, C.indigo1)
        blit_ol(c, s, x, y)
        return
    s = Cv(20, length)
    s.poly([(3, 3), (16, 3), (18, 9), (13, 11), (13, length - 2), (6, length - 2), (6, 11), (1, 9)], main)
    s.vline(4, 6, length - 4, hi)
    s.vline(14, 8, length - 4, lo)
    s.line(7, 3, 10, 8, lo)
    s.line(13, 3, 10, 8, hi)
    if patch:
        s.rect(8, 14, 4, 4, C.paper_old)
        s.hline(8, 11, 14, C.paper)
    blit_ol(c, s, x, y)


def basket(c, x, y, w=22, h=12, fill=C.paper, fill2=None):
    s = Cv(w + 6, h + 10)
    s.ellipse(w // 2 + 2, 6, max(3, w // 3), 4, fill)
    if fill2:
        s.ellipse(w // 2, 5, max(2, w // 5), 3, fill2)
    s.poly([(4, 8), (w, 8), (w + 3, 8 + h), (2, 8 + h)], C.wood3)
    s.hline(4, w, 8, C.tan)
    s.line(w, 8, w + 3, 8 + h, C.wood0)
    s.line(4, 8, 2, 8 + h, C.wood2)
    for yy in range(11, 8 + h, 3):
        s.hline(3, w + 1, yy, C.wood1)
    blit_ol(c, s, x, y)


def folded(c, x, y, w, h, cols):
    s = Cv(w + 2, h + 2)
    s.rect(1, 1, w, h, cols[0])
    for i, col in enumerate(cols):
        yy = 1 + i * max(1, h // len(cols))
        s.hline(1, w, yy, col)
        if yy + 1 < h:
            s.hline(1, w, yy + 1, col)
    s.vline(1, 1, h, mix(cols[0], C.white, 0.3))
    s.vline(w, 1, h, mix(cols[0], C.black, 0.35))
    blit_ol(c, s, x, y)


def awning(c, y0, y1):
    c.rect(0, y0, W, 3, C.wood1)
    c.hline(0, W - 1, y0, C.tan)
    c.hline(0, W - 1, y0 + 2, C.dkbrown)
    for x in range(W):
        stripe = (x // 10) % 2 == 0
        hem = y1 + int(4 * math.sin(x * 0.22))
        for y in range(y0 + 3, max(y0 + 4, hem)):
            if stripe:
                col = C.indigo0 if x % 10 == 0 else (C.indigo2 if x % 10 < 3 else C.indigo1)
            else:
                col = C.ww2 if x % 10 == 0 else (C.ww0 if x % 10 < 3 else C.ww1)
            if x > 220 and thr(x, y) < 0.35:
                col = mix(col, C.indigo0, 0.35)
            c.put(x, y, col)
        c.put(x, hem, C.dkbrown if stripe else C.wood1)
    for y in range(y1, y1 + 10):
        for x in range(W):
            if thr(x, y) < 0.5 - (y - y1) * 0.045:
                p = c.get(x, y)
                if p[3]:
                    c.put(x, y, mix(p, C.dkbrown, 0.28))


def shafts(c, x0, x1, y1, dx=0.42, power=0.16):
    px = c.img.load()
    for y in range(y1, H - 4):
        fall = max(0.0, 1.0 - (y - y1) / 120.0)
        for x in range(W):
            sx = x - (y - y1) * dx
            if x0 <= sx <= x1 and thr(x, y) < 0.62:
                r, g, b = px[x, y][:3]
                a = power * fall
                px[x, y] = (
                    min(255, int(r + (255 - r) * a)),
                    min(255, int(g + (232 - g) * a)),
                    min(255, int(b + (190 - b) * a * 0.75)),
                    255,
                )
    c.px = c.img.load()


def finish(im, warm=6, cool=0, dim=0.0, sat=1.06):
    if isinstance(im, Cv):
        im = im.img
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    bg = Image.new("RGB", im.size, (28, 22, 18))
    bg.paste(im, mask=im.split()[-1])
    px = bg.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            lum = (r + g + b) / 3.0
            r = lum + (r - lum) * sat
            g = lum + (g - lum) * sat
            b = lum + (b - lum) * sat
            d = (x / W - 0.14) ** 2 * 0.9 + (y / H - 0.18) ** 2
            f = (1.0 - min(0.32, d * 0.5)) * (1.0 - dim)
            r = r * f + warm
            g = g * f + warm * 0.3
            b = b * f - warm * 0.45 + cool
            px[x, y] = tuple(max(0, min(255, int(v))) for v in (r, g, b))
    return bg


def street_hole(c, x0, y0, x1, y1):
    # pale daylight sky (st5 / paper), not a dark dithered band
    for y in range(y0, y0 + 30):
        for x in range(x0, x1):
            t = (y - y0) / 30.0
            if t < 0.35:
                col = C.paper_hi if (x + y) % 6 else C.st5
            elif t < 0.7:
                col = C.st5 if (x + y * 2) % 5 else C.wa5
            else:
                col = C.wa4 if (x + y) % 4 else C.wa5
            if x < x0 + 14 and t < 0.55:
                col = C.paper_hi
            c.put(x, y, col)
    c.ellipse(x0 + 18, y0 + 8, 9, 3, C.white)
    c.ellipse(x0 + 26, y0 + 11, 6, 2, C.paper_hi)
    ey = y0 + 28
    for x in range(x0, x1):
        c.put(x, ey, C.rf3)
        c.put(x, ey + 1, C.rf1)
        c.put(x, ey + 2, C.rf0)
    for y in range(ey + 3, y1 - 16):
        for x in range(x0, x1):
            shade = 0 if x < x0 + (x1 - x0) // 2 else 1
            c.put(x, y, C.ww0 if shade == 0 and (x + y) % 9 else C.ww1)
    c.rect(x0 + 8, ey + 8, 14, 16, C.wood1)
    c.rect(x0 + 9, ey + 9, 12, 14, C.wa4)
    for i in range(0, 12, 4):
        c.vline(x0 + 9 + i, ey + 9, ey + 22, C.wood1)
        c.hline(x0 + 9, x0 + 20, ey + 9 + i, C.wood1)
    c.ellipse(x1 - 12, ey + 16, 3, 4, C.lantern)
    c.put(x1 - 14, ey + 14, C.lantern_hi)
    for y in range(y1 - 16, y1):
        for x in range(x0, x1):
            slab = ((x // 8) + (y // 5)) % 2
            col = C.st4 if slab else C.st3
            if x < x0 + 10:
                col = C.st5 if slab else C.st4
            if x % 8 == 0 or (y - (y1 - 16)) % 5 == 0:
                col = C.st1
            c.put(x, y, col)
    # three noren strips with wide gaps so the street stays visible
    for i, nx in enumerate((x0 + 1, x0 + 18, x0 + 34)):
        for y in range(y0, y0 + 20):
            col = C.indigo2 if i == 0 else C.indigo1
            if y > y0 + 16:
                col = C.indigo0
            c.put(nx, y, col)
            c.put(nx + 1, y, C.fog if i == 0 else C.indigo2)
            c.put(nx + 4, y, C.indigo0)
        c.put(nx + 2, y0 + 9, C.ww0)
    c.rect(x0 - 3, y0 - 3, 3, y1 - y0 + 6, C.wood2)
    c.vline(x0 - 3, y0 - 3, y1 + 2, C.tan)
    c.rect(x1, y0 - 3, 3, y1 - y0 + 6, C.wood0)
    c.rect(x0 - 3, y0 - 3, x1 - x0 + 6, 3, C.wood1)
    c.hline(x0 - 3, x1 + 2, y0 - 3, C.wood3)


# ---------------------------------------------------------------- shops
def teahouse():
    c = Cv(W, H, C.wood1)
    ceiling(c, 16)
    planks(c, 0, 16, W, 164, seed=11)
    street_hole(c, 12, 24, 64, 126)
    # cloth 茶 by the door
    s = Cv(18, 32)
    s.rect(2, 2, 13, 22, C.ww0)
    s.poly([(2, 20), (15, 20), (13, 28), (8, 24), (3, 28)], C.ww1)
    s.vline(2, 2, 24, C.indigo1)
    s.vline(14, 2, 24, C.indigo1)
    blit_ol(c, s, 68, 22)
    c.text(73, 28, "茶", C.black, size=12)
    c.vline(74, 16, 22, C.dkbrown)
    c.vline(80, 16, 22, C.dkbrown)
    plaque(c, 112, 20, "茶馆", C.rf0, C.lamp, C.wood3)
    paper_board(c, 168, 26, 28, 34, lines=4, seed=8)
    lantern(c, 96, 20)
    lantern(c, 270, 20)
    # pillar between hall and counter
    for y in range(16, 164):
        for x in range(150, 157):
            v = 0.55 if x == 150 else (0.18 if x == 156 else 0.36)
            c.put(x, y, ramp(x, y, WOOD, v - 0.05 * (y / H)))
    for y in range(16, 164):
        for x in range(157, 161):
            if thr(x, y) < 0.45:
                c.put(x, y, mix(c.get(x, y), C.dkbrown, 0.45))
    table(c, 78, 108, 44, 20)
    teapot(c, 90, 96, seed=2)
    teacup(c, 110, 100, seed=5)
    table(c, 84, 132, 52, 22)
    teacup(c, 96, 124, seed=6)
    teacup(c, 114, 124, seed=7)
    stool(c, 70, 146)
    stool(c, 136, 148)
    counter(c, 166, 318, 104, 164, lip=C.tan)
    # counter goods outside the keeper (x 200-248)
    teacup(c, 174, 96, seed=9)
    caddy(c, 258, 90)
    caddy(c, 272, 90)
    caddy(c, 286, 90)
    kettle(c, 292, 88, seed=4)
    # shelf of tins beside the keeper, not over the face
    c.rect(256, 70, 58, 3, C.wood2)
    c.hline(256, 313, 70, C.tan)
    wood_floor(c, 164, seed=3)
    shafts(c, 16, 60, 40, dx=0.5, power=0.2)
    return finish(c.img, warm=12, dim=0.0, sat=1.08)


def ricehall():
    """Full B2 interior at 320x180, keeper portrait left out."""
    import compose_B2 as b2

    c = Cv(b2.NW, b2.NH, C.wood1)
    b2.wall(c)
    b2.window(c)
    b2.pillar(c, *b2.PIL_L)
    b2.pillar(c, *b2.PIL_R)
    b2.banner(c)
    b2.curtain(c)
    b2.shelf_and_bins(c)
    b2.plaque(c)
    b2.lantern(c, 134, 18)
    b2.calendar(c)
    b2.steelyard(c)
    b2.counter(c)
    b2.counter_items(c)
    b2.floor(c)
    b2.sack_stack(c)
    b2.open_sack(c, 160, 56, "jing", 1, peak=17, stamp="square")
    b2.open_sack(c, 222, 56, "xian", 2, scoop=True, peak=19, stamp="round")
    b2.open_sack(c, 284, 56, "nuo", 3, peak=15, stamp="diamond", patch=True)
    b2.price_slip(c, 130, 92, "粳米", "73", 126, up=True)
    b2.price_slip(c, 218, 95, "籼米", "61", 126)
    b2.price_slip(c, 270, 93, "糯米", "80", 124)
    b2.sparrow(c, 107, 76)
    b2.light_shafts(c.img)
    return b2.grade(c.img)


def pharmacy():
    c = Cv(W, H, C.wood0)
    ceiling(c, 15)
    # dim plank surround then the drawer wall
    planks(c, 0, 16, W, 164, seed=21)
    lattice_window(c, 10, 20, 36, 26, [C.paper_old, C.tan, C.wood3], frame=C.wood0)
    plaque(c, 54, 18, "济生堂", C.rf0, C.gold, C.wood1)
    gourd(c, 292, 16)
    # 百子柜
    x0, y0, dw, dh = 8, 46, 16, 11
    cols, rows = 18, 5
    c.rect(x0 - 2, y0 - 2, cols * dw + 4, rows * dh + 4, C.wood0)
    for j in range(rows):
        for i in range(cols):
            xx, yy = x0 + i * dw, y0 + j * dh
            bright = 0.8 - 0.65 * (xx / W)
            face = C.wood2 if bright > 0.45 else C.wood1
            if (i + j) % 2 == 0 and bright > 0.35:
                face = C.wood3 if bright > 0.55 else C.wood2
            c.rect(xx + 1, yy + 1, dw - 2, dh - 2, face)
            c.hline(xx, xx + dw - 1, yy, C.dkbrown)
            c.vline(xx, yy, yy + dh - 1, C.dkbrown)
            c.hline(xx + 1, xx + dw - 2, yy + 1, mix(face, C.tan, 0.35 if xx < 140 else 0.05))
            c.put(xx + dw // 2, yy + dh // 2, C.gold if xx < 200 else C.wood3)
            c.put(xx + dw // 2 - 1, yy + dh // 2, C.lamp if xx < 120 else C.tan)
    for hx in (48, 96, 248):
        herbs(c, hx, 36, 78)
    # curtained recess, far right
    c.rect(296, 42, 22, 58, C.wood0)
    c.vline(296, 42, 99, C.wood2)
    c.vline(317, 42, 99, C.dkbrown)
    for y in range(46, 98):
        for x in range(300, 316):
            band = ((x - 300) // 4) % 2
            col = C.indigo2 if band == 0 else C.indigo1
            if x < 304:
                col = C.indigo2
            if x > 312:
                col = C.indigo0
            c.put(x, y, col)
    c.rect(304, 66, 8, 3, C.tan)
    counter(c, 6, 316, 100, 164, lip=C.wood3)
    jar(c, 14, 84, 12, 16, C.white, C.indigo2)
    jar(c, 30, 88, 10, 12, C.paper, C.moss, lid=C.wood1)
    jar(c, 46, 82, 11, 18, C.ww1, C.seal_red)
    jar(c, 64, 90, 9, 10, C.tan, C.g2, lid=C.wood0)
    jar(c, 100, 86, 12, 14, C.white, C.indigo1)
    jar(c, 128, 88, 10, 12, C.wood3, C.gold, lid=C.dkbrown)
    mortar(c, 78, 88)
    # right of keeper (ends x=228)
    jar(c, 236, 84, 12, 16, C.white, C.g1)
    jar(c, 254, 90, 9, 10, C.paper_old, C.dkred)
    balance(c, 270, 80)
    wood_floor(c, 164, seed=9)
    shafts(c, 12, 44, 46, dx=0.35, power=0.08)
    return finish(c.img, warm=4, cool=0, dim=0.08, sat=0.96)


def baogong():
    c = Cv(W, H, C.wall1)
    for y in range(0, 12):
        for x in range(W):
            v = 0.28 - 0.12 * x / W + 0.04 * y / 12
            c.put(x, y, ramp(x, y, [C.wall0, C.wall1, C.wall2, C.mist], v))
    c.rect(0, 12, W, 4, C.wall0)
    c.hline(0, W - 1, 12, C.mist)
    plaster(c, 0, 16, W, 164, 24, 20, GREY, speckle=False)
    # cool transom, top-left
    lattice_window(c, 12, 20, 52, 22, [C.wa1, C.wa2, C.wa3, C.fog], frame=C.wall1, bar=C.wall0)
    plaque(c, 78, 18, "保公所", C.wall0, C.paper_hi, C.wall2)
    paper_board(c, 14, 52, 46, 44, lines=5, seed=4, seal=True, header=C.seal_red)
    # empty white stretch behind 马 (x 190-238, y 36-100) — already plaster
    # grey cabinet on the right
    c.rect(252, 40, 58, 60, C.wall1)
    c.hline(252, 309, 40, C.mist)
    c.vline(252, 40, 99, C.fog)
    c.vline(309, 40, 99, C.wall0)
    for i, yy in enumerate((52, 70, 88)):
        c.hline(256, 305, yy, C.wall0)
        c.put(300, yy + 6, C.wall2)
    # round clock, left of the keeper
    c.ellipse(160, 30, 8, 8, C.wall0)
    c.ellipse(160, 30, 7, 7, C.white)
    c.line(160, 30, 164, 26, C.black)
    c.line(160, 30, 157, 34, C.black)
    c.put(160, 30, C.wall1)
    counter(c, 56, 308, 100, 160, lip=C.st4)
    abacus(c, 70, 78)
    # ink, brush, seal to the right of the keeper
    c.rect(250, 92, 10, 8, C.black)
    c.rect(251, 93, 8, 6, C.indigo0)
    c.line(264, 98, 276, 86, C.wood2)
    c.line(264, 99, 276, 87, C.wood1)
    c.put(276, 85, C.dkbrown)
    c.rect(286, 90, 8, 8, C.seal_red)
    c.frame(286, 90, 8, 8, C.dkred)
    # empty stool for visitors, left of the desk
    stool(c, 24, 140)
    stone_floor(c, 160)
    shafts(c, 14, 60, 42, dx=0.3, power=0.07)
    return finish(c.img, warm=0, cool=14, dim=0.04, sat=0.72)


def post():
    c = Cv(W, H, C.ww2)
    ceiling(c, 16)
    c.rect(0, 16, W, 4, C.postgreen)
    c.hline(0, W - 1, 16, C.postgreen_hi)
    c.hline(0, W - 1, 19, C.g0)
    plaster(c, 0, 20, W, 164, 30, 24, PLASTER)
    lattice_window(c, 10, 26, 40, 28, [C.wa3, C.wa4, C.wa5, C.paper_hi], frame=C.postgreen, bar=C.postgreen)
    plaque(c, 60, 24, "邮电", C.postgreen, C.paper_hi, C.g0)
    c.ellipse(112, 38, 8, 8, C.white)
    c.ellipse(112, 38, 8, 8, C.postgreen, filled=False)
    c.line(112, 38, 116, 33, C.dkbrown)
    c.line(112, 38, 109, 42, C.black)
    c.put(112, 38, C.gold)
    pigeonholes(c, 8, 62, 8, 1, cw=16, ch=18)
    pigeonholes(c, 228, 24, 5, 3, cw=16, ch=14)
    counter(c, 12, 316, 100, 164, lip=C.postgreen_hi)
    c.rect(12, 100, 304, 3, C.postgreen)
    c.hline(12, 315, 100, C.postgreen_hi)
    # grille along the counter; the bust covers only the middle bars
    for x in range(28, 296, 6):
        c.vline(x, 88, 100, C.wall0)
        c.vline(x + 1, 88, 100, C.mist)
    c.hline(18, 304, 88, C.gold)
    c.hline(18, 304, 89, C.wood3)
    # letters and telegraph outside the bust (170-218)
    c.rect(128, 90, 14, 10, C.paper_hi)
    c.rect(132, 86, 14, 10, C.paper)
    c.hline(134, 142, 90, C.gray)
    c.put(140, 88, C.seal_red)
    telegraph(c, 246, 84)
    c.rect(286, 92, 8, 6, C.dkred)
    c.rect(298, 90, 6, 8, C.wood2)
    c.hline(298, 303, 90, C.gold)
    wood_floor(c, 164, seed=6)
    shafts(c, 12, 48, 54, dx=0.4, power=0.12)
    return finish(c.img, warm=3, cool=4, dim=0.0, sat=1.0)


def market():
    c = Cv(W, H, C.wa4)
    for y in range(H):
        for x in range(W):
            v = 0.9 - 0.38 * (y / H) - 0.16 * (x / W)
            c.put(x, y, ramp(x, y, SKY, v))
    # soft sun, top-left
    for y in range(0, 36):
        for x in range(0, 90):
            if hz(x, y, 1) > 0.55:
                continue
            d = math.hypot(x / 90.0, y / 40.0)
            if d < 1 and thr(x, y) < (1 - d) * 0.7:
                c.put(x, y, C.paper_hi if d > 0.45 else C.lamp_pale)
    # distant houses under the sky band
    def house(x, w, wall, roof, door=C.wood0):
        top = 78
        c.poly([(x - 6, top + 12), (x + w // 2, top), (x + w + 6, top + 12)], roof)
        c.hline(x - 4, x + w + 4, top + 12, mix(roof, C.white, 0.2))
        for y in range(top + 12, 150):
            for xx in range(x, x + w):
                col = wall
                if xx < x + 2:
                    col = mix(wall, C.white, 0.2)
                elif xx > x + w - 3:
                    col = mix(wall, C.dkbrown, 0.25)
                c.put(xx, y, col)
        c.rect(x + 6, top + 22, 10, 12, C.wood1)
        c.rect(x + 7, top + 23, 8, 10, C.wa3)
        c.vline(x + 11, top + 23, top + 32, C.wood1)
        c.rect(x + w // 2, 128, 10, 22, door)

    house(4, 48, C.ww1, C.rf1)
    house(248, 56, C.ww2, C.rf2, door=C.wood1)
    # ground first so the stall stands on it
    for y in range(150, H):
        for x in range(W):
            n = hz(x, y, 5)
            if n > 0.86:
                col = C.st3
            elif n > 0.72:
                col = C.st1
            elif (x // 14 + y // 6) % 2 == 0:
                col = C.dirt1
            else:
                col = C.dirt2
            if x < 70 and thr(x, y) < 0.35:
                col = mix(col, C.st5, 0.22)
            elif x > 250 and thr(x, y) < 0.45:
                col = mix(col, C.dirt0, 0.4)
            c.put(x, y, col)
    # plain cloth behind the peddler so the portrait has a quiet spot
    for y in range(44, 114):
        for x in range(124, 236):
            fold = (x - 124) // 22
            edge = (x - 124) % 22
            cols = (C.paper, C.ww1, C.paper_old, C.ww2, C.paper)
            col = cols[fold % 5]
            if edge <= 1:
                col = C.ww3
            elif edge <= 3:
                col = C.paper_hi
            if y > 104:
                col = mix(col, C.ww3, 0.3)
            c.put(x, y, col)
    c.vline(124, 44, 113, C.wood1)
    c.vline(235, 44, 113, C.wood0)
    awning(c, 4, 34)
    # poles
    for px in (14, 302):
        c.rect(px, 8, 4, 150, C.wood1)
        c.vline(px, 8, 157, C.tan)
        c.vline(px + 3, 8, 157, C.dkbrown)
        shadow(c, px + 4, 150, 10, 4, amt=0.4)
    # clothes left of the keeper and right of him (bust is x 160-208, y 48-112)
    garment(c, 28, 46, "jacket", C.indigo1, C.indigo2, C.indigo0, 34)
    garment(c, 52, 48, "shirt", C.ww1, C.white, C.ww3, 28, patch=True)
    garment(c, 76, 44, "pants", C.wood1, C.wood2, C.wood0, 36)
    garment(c, 98, 50, "jacket", C.seal_red, C.lantern, C.dkred, 30)
    garment(c, 214, 46, "jacket", C.gray, C.fog, C.wall1, 32, patch=True)
    garment(c, 238, 44, "pants", C.indigo0, C.indigo1, C.rf0, 38)
    garment(c, 262, 50, "shirt", C.paper, C.paper_hi, C.paper_old, 26)
    garment(c, 286, 46, "jacket", C.moss, C.g3, C.g0, 34)
    # stall table, top meets the portrait feet
    counter(c, 36, 300, 112, 150, lip=C.tan)
    folded(c, 48, 100, 22, 12, (C.indigo1, C.indigo2, C.fog))
    folded(c, 74, 102, 18, 10, (C.seal_red, C.wood2, C.paper))
    basket(c, 96, 96, 20, 12, C.paper, C.wood3)
    # right of the bust
    basket(c, 220, 94, 24, 14, C.ww1, C.indigo2)
    folded(c, 252, 100, 20, 12, (C.wood2, C.tan, C.paper_old))
    # straw hat
    c.ellipse(286, 104, 8, 3, C.wood3)
    c.ellipse(286, 102, 4, 3, C.tan)
    basket(c, 18, 138, 26, 14, C.wood2, C.paper)
    basket(c, 168, 140, 22, 12, C.paper_old, C.gray)
    basket(c, 270, 136, 28, 16, C.indigo1, C.ww0)
    # shoes
    c.ellipse(150, 156, 5, 2, C.dkbrown)
    c.ellipse(160, 157, 5, 2, C.wood0)
    plaque(c, 56, 38, "估衣", C.paper_hi, C.dkbrown, C.wood1)
    return finish(c.img, warm=8, cool=2, dim=0.0, sat=1.05)


SHOPS = [
    ("teahouse", teahouse, "zhouma", [200, 40]),
    ("ricehall", ricehall, "wu", [150, 40]),
    ("pharmacy", pharmacy, "chen", [180, 36]),
    ("baogong", baogong, "ma", [190, 36]),
    ("post", post, "postman", [170, 36]),
    ("market", market, "stranger_peddler", [160, 48]),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for sid, fn, keeper, at in SHOPS:
        im = fn()
        if im.size != (W, H):
            raise SystemExit("%s size %s" % (sid, im.size))
        if im.mode != "RGB":
            im = im.convert("RGB")
        path = os.path.join(OUT, sid + "_bg.png")
        im.save(path)
        # no transparent channel possible on RGB; re-open to be sure
        check = Image.open(path)
        if check.size != (W, H) or check.mode != "RGB":
            raise SystemExit("bad write %s %s %s" % (sid, check.size, check.mode))
        x, y = at
        if not (0 <= x and x + 48 < W and 0 <= y and y + 64 < H):
            raise SystemExit("keeper offscreen %s" % sid)
        meta[sid] = {
            "bg": "art/town/shops/%s_bg.png" % sid,
            "keeper": keeper,
            "keeper_at": at,
        }
        print("%s %dx%d %s" % (sid, check.size[0], check.size[1], check.mode))
    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("SHOP_BG_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
