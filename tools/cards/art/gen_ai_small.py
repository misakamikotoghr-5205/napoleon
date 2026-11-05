#!/usr/bin/env python3
"""AI pixel art for the card game, batch "small": icons, items, portraits.

    python3 tools/cards/art/gen_ai_small.py [--out=<root>] [--only=<id prefix>] [--check]
                                            [--sheet=<png>] [--zoom=<dir>] [--force]

Every picture is drawn here in code, pixel by pixel (no image model, no fonts, no
source images). Writes art/ai/<category>/<rest>.png for art id <category>.<rest>.

* Deterministic: same script -> byte-identical PNGs. Each picture's RNG is
  random.Random(first 8 bytes of sha256(art_id)), the PNG has only IHDR/IDAT/IEND
  (8-bit RGBA, fixed zlib level, no time or color chunks), ids are processed sorted.
* Colors: only values of keys in data/cards/theme/palette.dev.json (copied below,
  so a later palette edit does not silently change shipped pixels).
* No letters, numbers or readable characters. Seals and "writing" are abstract strokes.
* Existing files under art/ai are never overwritten unless --force is given
  (re-running over this script's own output); --check compares without writing.

Batch owner: ai:claude:opus-5.5:2026-10-22:art-small. Spec: docs/cards/ART_SPEC.md.
"""

import argparse
import hashlib
import io
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PROVENANCE = "ai:claude:opus-5.5:2026-10-22:art-small"

# palette.dev.json keys used here (opaque ones). One letter each for the pixel maps.
PAL = {
    "k": ("ink", "#1f1712"),
    "K": ("scene_void", "#0d0a08"),
    "x": ("reply_bg", "#2b1c12"),
    "w": ("wood", "#3a2a1e"),
    "b": ("ink_soft", "#5a3f2a"),
    "o": ("reply_off", "#6b5a46"),
    "B": ("frame_person", "#8c6a44"),
    "P": ("paper_old", "#d9c49a"),
    "p": ("paper", "#f4e2b0"),
    "h": ("hud_ink", "#efe3c7"),
    "W": ("guide_bubble", "#fffdf8"),
    "S": ("seal_paper", "#f4efe0"),
    "N": ("night_tint", "#f2d9b8"),
    "c": ("candle_tint", "#ffdba8"),
    "y": ("lamp", "#ffd25a"),
    "e": ("dialog_name", "#e8c35a"),
    "Y": ("frame_gold", "#d9a520"),
    "g": ("gold", "#a07a2c"),
    "r": ("seal", "#b0262a"),
    "R": ("btn_day_confirm", "#c8452c"),
    "d": ("danger", "#a8322a"),
    "j": ("jade", "#2f6b5a"),
    "J": ("dialog_me", "#b9c4a0"),
    "G": ("good", "#4a6a3a"),
    "l": ("frame_life", "#6b7a4a"),
    "i": ("indigo", "#2f4670"),
    "I": ("btn_day_night", "#5c6aa8"),
    "n": ("frame_night", "#2d3a5a"),
    "m": ("mist", "#9aa4aa"),
    "s": ("frame_news", "#8c8378"),
    "t": ("frame_street", "#6a6058"),
    "E": ("frame_estate", "#5a524a"),
    "f": ("frame_fate", "#3a3532"),
    "q": ("frame_prison", "#2a2422"),
    "Q": ("frame_big_fate", "#1b1714"),
}


def _rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


COL = {ch: _rgba(v[1]) for ch, v in PAL.items()}
CLEAR = (0, 0, 0, 0)
ALLOWED = set(COL.values()) | {CLEAR}

# Light/dark neighbour of each color for edge shading (light from the upper left).
LIGHT = {
    "i": "I", "n": "i", "I": "m", "j": "J", "G": "l", "l": "J", "p": "W", "P": "p", "h": "W",
    "N": "W", "c": "W", "B": "P", "b": "B", "w": "b", "o": "B", "g": "Y", "Y": "e", "e": "y",
    "y": "W", "r": "R", "d": "R", "R": "c", "m": "h", "s": "m", "t": "s", "E": "t", "f": "E",
    "q": "f", "k": "w", "W": "W", "S": "W", "J": "W", "x": "w", "K": "k", "Q": "q",
}
DARK = {
    "i": "n", "n": "Q", "I": "i", "j": "f", "G": "f", "l": "G", "p": "P", "P": "B", "h": "P",
    "N": "P", "c": "N", "B": "b", "b": "w", "w": "k", "o": "w", "g": "b", "Y": "g", "e": "Y",
    "y": "Y", "r": "b", "d": "b", "R": "r", "m": "s", "s": "t", "t": "E", "E": "f", "f": "q",
    "q": "Q", "k": "Q", "W": "h", "S": "h", "J": "m", "x": "Q", "K": "K", "Q": "K",
}
CH = {v: k for k, v in COL.items()}


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


# --------------------------------------------------------------------------- canvas


class Cv:
    """Small pixel canvas holding palette letters (None = transparent)."""

    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.a = [[fill] * w for _ in range(h)]

    def copy(self):
        c = Cv(self.w, self.h)
        c.a = [row[:] for row in self.a]
        return c

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if self.inside(x, y):
            self.a[y][x] = c

    def get(self, x, y):
        if self.inside(x, y):
            return self.a[y][x]
        return None

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def hl(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, c)

    def vl(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            for ox in range(w):
                for oy in range(w):
                    self.put(x0 + ox, y0 + oy, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def pts(self, lst, c):
        for x, y in lst:
            self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, test=None):
        """Filled ellipse through pixel centres; cx, cy may be half-integers."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1.0 and (test is None or test(x, y, d)):
                    self.put(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            yc = y + 0.5
            xs = []
            n = len(pts)
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.put(x, y, c)

    def ascii(self, rows, x=0, y=0, skip="."):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in skip or ch == " ":
                    continue
                if ch == "_":
                    self.put(x + i, y + j, None)
                else:
                    self.put(x + i, y + j, ch)

    def map(self, fn):
        for y in range(self.h):
            for x in range(self.w):
                v = fn(x, y, self.a[y][x])
                if v is not False:
                    self.a[y][x] = v

    def recolor(self, frm, to, box=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(y0, y1):
            for x in range(x0, x1):
                if self.inside(x, y) and self.a[y][x] in frm:
                    self.a[y][x] = to

    def dither(self, x, y, w, h, a, b, level, only=None):
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if not self.inside(xx, yy):
                    continue
                if only is not None and self.a[yy][xx] not in only:
                    continue
                t = (bayer[yy % 4][xx % 4] + 0.5) / 16.0
                self.a[yy][xx] = b if t < level else a

    def outline(self, c="k", diag=False, inner=None):
        """1px outline on transparent pixels next to opaque ones."""
        src = [row[:] for row in self.a]
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diag:
            nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is not None:
                    continue
                for dx, dy in nb:
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[yy][xx] is not None:
                        self.a[y][x] = c
                        break

    def edge_shade(self, light=True, dark=True, skip="k"):
        """Darken lower-right edges and lighten upper-left edges of each opaque area."""
        src = [row[:] for row in self.a]

        def clear(x, y):
            return not (0 <= x < self.w and 0 <= y < self.h) or src[y][x] is None or src[y][x] == "k"

        for y in range(self.h):
            for x in range(self.w):
                c = src[y][x]
                if c is None or c in skip:
                    continue
                if dark and (clear(x + 1, y) or clear(x, y + 1)):
                    self.a[y][x] = DARK.get(c, c)
                elif light and (clear(x - 1, y) or clear(x, y - 1)):
                    self.a[y][x] = LIGHT.get(c, c)

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                v = other.a[y][x]
                if v is not None:
                    self.put(ox + x, oy + y, v)

    def bbox(self):
        xs = [x for y in range(self.h) for x in range(self.w) if self.a[y][x] is not None]
        ys = [y for y in range(self.h) for x in range(self.w) if self.a[y][x] is not None]
        if not xs:
            return (0, 0, 0, 0)
        return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)

    def shift(self, dx, dy):
        src = [row[:] for row in self.a]
        self.a = [[None] * self.w for _ in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is not None:
                    self.put(x + dx, y + dy, src[y][x])

    def center(self, axis="xy"):
        x0, y0, x1, y1 = self.bbox()
        dx = (self.w - (x1 - x0)) // 2 - x0 if "x" in axis else 0
        dy = (self.h - (y1 - y0)) // 2 - y0 if "y" in axis else 0
        self.shift(dx, dy)

    def flip_x(self):
        self.a = [row[::-1] for row in self.a]

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), CLEAR)
        px = im.load()
        for y in range(self.h):
            for x in range(self.w):
                v = self.a[y][x]
                px[x, y] = CLEAR if v is None else COL[v]
        return im


def sprite(rows):
    h = len(rows)
    w = max(len(r) for r in rows)
    c = Cv(w, h)
    c.ascii(rows)
    return c


# --------------------------------------------------------------------------- icons 16x16


def _done(cv, outline=True, center=True, shade=False):
    if shade:
        cv.edge_shade()
    if center:
        cv.center()
    if outline:
        cv.outline("k")
    return cv


def _coin(cv, head):
    """Cast copper cash: raised rim, square hole, raised marks on a recessed field."""
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            d = math.hypot(dx, dy)
            if d > 8.0:
                continue
            lit = (-dx - dy) / (d * 1.414 + 1e-6)
            q = max(abs(dx), abs(dy))
            if d > 7.05:
                c = "k"
            elif d > 5.9:
                if head:
                    c = "y" if lit > 0.35 else ("g" if lit < -0.35 else "e")
                else:
                    c = "e" if lit > 0.35 else ("b" if lit < -0.35 else "Y")
            elif q <= 1:
                c = None
            elif q <= 2:
                c = "k"
            elif q <= 3:
                if head:
                    c = "y" if (dx < 0 and dy < 0) or (lit > 0.3) else ("g" if lit < -0.3 else "e")
                else:
                    c = "e" if lit > 0.3 else ("b" if lit < -0.3 else "Y")
            else:
                c = "Y" if head else "B"
            cv.put(x, y, c)
    if head:
        # four raised blobs round the hole (lit top-left, shadow bottom-right); not characters
        for (lx, ly), (sx, sy) in (((7, 3), (8, 4)), ((7, 11), (8, 12)), ((3, 7), (4, 8)), ((11, 7), (12, 8))):
            cv.pts([(lx, ly), (lx + 1, ly), (lx, ly + 1)], "g")
            cv.put(sx, sy, "b")
        cv.pts([(8, 3), (7, 12), (4, 7), (12, 7)], "b")
        cv.pts([(9, 4), (6, 12), (3, 9), (11, 6)], "y")
    else:
        # crescent above the hole and a dot below, on a darker field
        cv.pts([(5, 3), (6, 2), (7, 2), (8, 2), (9, 2), (10, 3)], "e")
        cv.pts([(6, 3), (7, 3), (8, 3), (9, 3)], "b")
        cv.pts([(7, 12), (8, 12)], "e")
        cv.pts([(7, 13), (8, 13)], "b")


def icon_coin_head(cv, r):
    _coin(cv, True)


def icon_coin_tail(cv, r):
    _coin(cv, False)


def icon_seal(cv, r):
    # Red stamp impression: square with a thin paper border and abstract seal strokes.
    cv.rect(1, 1, 14, 14, "r")
    for i in range(2, 14):
        cv.put(i, 2, "p")
        cv.put(i, 13, "p")
        cv.put(2, i, "p")
        cv.put(13, i, "p")
    # meandering strokes in the field (two abstract columns)
    cv.pts([(4, 4), (5, 4), (6, 4), (6, 5), (5, 6), (4, 6), (4, 7), (4, 8), (5, 8), (6, 8),
            (6, 9), (6, 10), (5, 11), (4, 11)], "p")
    cv.pts([(9, 4), (9, 5), (10, 5), (11, 5), (11, 6), (9, 7), (10, 7), (11, 8), (9, 9),
            (10, 9), (11, 10), (11, 11), (10, 11), (9, 11)], "p")
    # worn ink: a few gaps and dark spots so it reads as a stamp, not a tile
    for x, y in [(1, 1), (14, 1), (1, 14), (14, 14), (7, 1), (14, 9), (1, 6), (9, 14)]:
        cv.put(x, y, None)
    cv.pts([(3, 12), (12, 3), (8, 6), (7, 12)], "d")
    cv.pts([(2, 9), (13, 6)], "r")


def icon_demand_goods(cv, r):
    rows = [
        "......i..i......",
        ".....iIi.iIi....",
        "......iIiIi.....",
        ".......iIi......",
        ".....iiiIiii....",
        "...iIIiiiiiiin..",
        "..iIIiIiiiIiinn.",
        "..iImiiiiiiimin.",
        ".iIIiiiImiiiiinn",
        ".iIiiimiiiiimiin",
        ".iIiiiiiiiiiiinn",
        ".iiiImiiiiiImiin",
        "..iiiiiiiiiiinn.",
        "...nnnnnnnnnnn..",
    ]
    cv.ascii(rows, 0, 1)
    _done(cv)


def icon_demand_info(cv, r):
    rows = [
        "..PPPPPrRPPPP.",
        ".PpppWpRrppPPP",
        "PBpWWppRrpppPP",
        "PBppppprRpppPP",
        "PbBpppprRpppPP",
        ".PbBPPPrRPPPP.",
        "..PPPPrr.rr...",
        "......r...r...",
    ]
    cv.ascii(rows, 1, 4)
    _done(cv)


def icon_demand_money(cv, r):
    # stack of silver dollars
    for i, yy in enumerate((12, 10, 8, 6)):
        ox = (0, 1, 0, 1)[i]
        cv.ellipse(8 + ox, yy + 0.5, 5.5, 2.5, "s")
        cv.ellipse(8 + ox, yy - 0.5, 5.5, 2.5, "m")
    # top face detail
    cv.ellipse(9, 5.5, 5.5, 2.5, "h")
    cv.ellipse(9, 5.5, 3.5, 1.4, "m")
    cv.ellipse(9, 5.5, 2.5, 0.8, "h")
    for x in range(3, 15):
        for y in range(4, 15):
            if cv.get(x, y) == "s" and x >= 11:
                cv.put(x, y, "t")
    _done(cv)


def icon_demand_people(cv, r):
    rows = [
        ".....wwww.....",
        "....wwbwww....",
        "...wwppppww...",
        "...wpppppPw...",
        "...ppkpkpPP...",
        "...pppppppP...",
        "....ppBpPP....",
        ".....pPPP.....",
        "...iiPPPPii...",
        ".iIIiiiPiiiin.",
        "iIIiiiiPiiiinn",
        "iIiiiiiPiiiinn",
        "iiiiiiiPiiiinn",
    ]
    cv.ascii(rows, 1, 2)
    _done(cv)


def icon_ws_caixing(cv, r):
    rows = [
        "...........y....",
        "..........yWy...",
        "...........y....",
        "......eyye......",
        ".....eyWyyY.....",
        ".Ye..eyyyyg..eY.",
        ".YyeeYeyyYggeyg.",
        "..gyyyYYYYgyyg..",
        "..gYeeeeeeeeYg..",
        "...gYYYYYYYYg...",
        "....gggggggg....",
    ]
    cv.ascii(rows, 0, 2)
    _done(cv)


def icon_ws_wenxing(cv, r):
    # writing brush with a little star
    for i in range(8):
        cv.put(12 - i, 2 + i, "P")
        cv.put(13 - i, 2 + i, "B")
    cv.pts([(13, 1), (14, 1), (14, 2)], "b")
    cv.pts([(4, 10), (5, 10), (4, 9)], "g")
    cv.pts([(5, 9)], "Y")
    cv.pts([(3, 10), (3, 11), (4, 11), (2, 11), (2, 12), (3, 12), (1, 13), (2, 13), (1, 14)], "w")
    cv.pts([(3, 11), (2, 12)], "k")
    for x, y in [(4, 3), (3, 4), (4, 4), (5, 4), (4, 5), (4, 2), (2, 4), (6, 4), (4, 6)]:
        cv.put(x, y, "y")
    cv.put(4, 4, "W")
    cv.outline("k")


def icon_ws_liunian(cv, r):
    rows = [
        "......mms.......",
        ".....mssst.ss...",
        "...mmssttttsst..",
        "..msssttttttttt.",
        ".mssttttEtttttE.",
        ".sttttEEEEtEEEE.",
        "..tEEEEEEEEEEEf.",
        "...fff.ffff.ff..",
    ]
    cv.ascii(rows, 0, 2)
    cv.outline("k")
    for x, y in [(4, 12), (3, 13), (8, 12), (7, 13), (12, 12), (11, 13), (6, 14), (10, 14)]:
        cv.put(x, y, "I")


def icon_ws_guanmian(cv, r):
    # an official's peaked cap with a brass badge: inspections and paperwork
    rows = [
        "...iiiiiiiii....",
        ".iIIIiiiiiiiin..",
        "iIIiiiiiiiiiinn.",
        ".nnnnnnnnnnnnnn.",
        "..mmmmmYYmmmmm..",
        "..nnnnnyennnnn..",
        "..fqqqqqqqqqqf..",
        "...qqffffffqq...",
        ".....qqqqqq.....",
    ]
    cv.ascii(rows, 0, 3)
    cv.outline("k")


def icon_ws_pingan(cv, r):
    rows = [
        "....PPPPP....",
        ".....pPPP....",
        "......pP.....",
        "......pP.....",
        ".....ppPP....",
        "....pWpppP...",
        "...pWiiiiiP..",
        "..pWiIiiiiPP.",
        "..pWipppiiPP.",
        "..ppiiiiiiPP.",
        "...ppppppPP..",
        "....pppppP...",
        ".....iiiii...",
    ]
    cv.ascii(rows, 1, 2)
    _done(cv)


def icon_ws_koushe(cv, r):
    rows = [
        "pppppppp........",
        "pWWppppPP.......",
        "pWprprprP.......",
        "ppRpRpRpP.......",
        "pppppppPPPPPPP..",
        ".PpPPPPPhhhhhP..",
        ".P.P...PhkhkhP..",
        "P......PkhkhkP..",
        ".......PhhhhhPP.",
        "........PPPPPPPP",
        "............P.P.",
        ".............P..",
    ]
    cv.ascii(rows, 1, 2)
    _done(cv)


def icon_ws_shunshui(cv, r):
    rows = [
        ".....fffff......",
        "....fEtEEEf.....",
        "...fEEfEEEEf....",
        "B..ffffffffff..B",
        "BBBBBBBBBBBBBBBB",
        ".bPBBBBBBBBBBBb.",
        "..bbbbbbbbbbbb..",
    ]
    cv.ascii(rows, 0, 3)
    for x in (0, 15):
        for y in range(16):
            cv.put(x, y, None)
    cv.outline("k")
    cv.ascii(["..II...II...II..", ".I..I.I..I.I..I.", "I....I....I....I"], 0, 11)
    cv.ascii(["................"], 0, 14)
    for x in (0, 15):
        cv.put(x, 13, None)


def icon_ws_fanshen(cv, r):
    # leaping carp: head up-right, body arched, forked tail low left, splash below
    rows = [
        ".......RR.......",
        "......RRRr......",
        ".....RWkRrr.....",
        ".....RRRRrr.....",
        "....YRRRRRrY....",
        "...YYRyRRRrYY...",
        ".....RRRyRrr....",
        ".....RyRRRrr....",
        "......RRyRrr....",
        "......RRRrr.....",
        ".......RRr......",
        ".....YYRrYY.....",
        "....YYe...YY....",
        "....Y......Y....",
    ]
    cv.ascii(rows, 0, 0)
    cv.outline("k")
    cv.ascii(["..I.I..I..I..I..", ".I.I.II.II.II.I."], 0, 14)


def icon_ws_zhuidi(cv, r):
    # steelyard weight dropping: ring, pear-shaped iron body, speed lines above
    rows = [
        ".....tttt.....",
        ".....t..t.....",
        "......tt......",
        ".....tEEf.....",
        "....tsEEEf....",
        "...tsEEEEEf...",
        "...tsEEEEEf...",
        "..tsEEEEEEEf..",
        "..tEEEEEEEEf..",
        "..ffffffffff..",
    ]
    cv.ascii(rows, 1, 4)
    cv.outline("k")
    cv.pts([(7, 5), (8, 5)], "k")
    for y in (0, 1, 2):
        cv.put(3, y + 1, "m")
        cv.put(12, y + 1, "m")
    cv.pts([(5, 0), (5, 1), (10, 0), (10, 1)], "m")
    cv.ascii(["..s..........s.."], 0, 15)


def _lantern(cv, lit):
    body = ("R", "r", "d", "y") if lit else ("t", "E", "f", "s")
    cv.ellipse(8, 7.5, 6.5, 4.6, body[1])
    cv.ellipse(7, 6.5, 4.0, 2.8, body[0])
    if lit:
        cv.ellipse(6.5, 6.0, 1.8, 1.4, "y")
    for x in (4, 8, 12):
        for y in range(4, 12):
            if cv.get(x, y) is not None:
                cv.put(x, y, body[2])
    cv.hl(6, 9, 2, "Y" if lit else "t")
    cv.hl(6, 9, 12, "Y" if lit else "t")
    cv.pts([(7, 1), (8, 1)], "g" if lit else "E")
    cv.outline("k")
    cv.pts([(7, 0), (8, 0)], "k")
    if lit:
        cv.pts([(7, 13), (8, 13), (7, 14), (8, 14), (6, 15), (9, 15), (7, 15)], "Y")
    else:
        cv.pts([(7, 13), (8, 14), (7, 15)], "t")


def icon_ws_nianhuo(cv, r):
    _lantern(cv, True)


def icon_ws_nianwei(cv, r):
    _lantern(cv, False)
    for x, y in [(1, 2), (14, 4), (2, 13), (13, 12), (11, 15), (3, 8)]:
        cv.put(x, y, "W")


def icon_ws_micang(cv, r):
    cv.ellipse(8, 9.5, 7, 5.5, "b")
    cv.ellipse(6.5, 8.5, 4.5, 3.5, "B")
    cv.ellipse(5.5, 8, 2, 1.6, "P")
    for y in range(4, 16):
        for x in range(9, 16):
            if cv.get(x, y) == "b" and (x - 8) * 0.8 + (y - 9) * 0.6 > 3.2:
                cv.put(x, y, "w")
    cv.ellipse(8, 4.5, 5.5, 2.2, "B")
    cv.ellipse(8, 4.5, 4.5, 1.4, "k")
    cv.pts([(6, 5), (8, 5), (9, 5)], "P")
    cv.rect(5, 14, 6, 1, "w")
    _done(cv, center=False)


def icon_ws_chengmen(cv, r):
    rows = [
        "....bbbbbbbb....",
        "..bwwwwwwwwwwb..",
        "....PBBBBBBP....",
        "t.t.ssssssss.t.t",
        "tststsssssststst",
        "ssssssskksssssst",
        "sstssskkkkssttst",
        "ssssskkkkkksssst",
        "sttsskkkkkksstst",
        "rrWWrrWWrrWWrrWW",
        "sssskkkkkkkkssst",
        "tttttkkkkkkttttt",
    ]
    cv.ascii(rows, 0, 2)
    for y in range(16):
        cv.put(0, y, None)
        cv.put(15, y, None)
    _done(cv)


def icon_ws_jiashu(cv, r):
    # a wild goose, wings spread, carrying a letter on a cord
    rows = [
        "t............t",
        "ts..........st",
        "tms........smt",
        ".tmss....ssmt.",
        "..tmsswwssmt..",
        "...tssWwsst...",
        "....tssssst...",
        "......ss......",
    ]
    cv.ascii(rows, 1, 1)
    cv.outline("k")
    cv.put(8, 5, "Y")
    env = sprite(["pppp", "pPrP", "PPPP"])
    env.outline("k")
    cv.paste(env, 5, 11)
    cv.pts([(7, 10)], "B")


def icon_ws_qingzhang(cv, r):
    cv.rect(1, 3, 14, 11, "B")
    cv.rect(2, 4, 12, 9, None)
    cv.hl(1, 14, 6, "B")
    cv.hl(1, 14, 3, "P")
    cv.vl(1, 3, 13, "P")
    cv.hl(2, 14, 13, "b")
    cv.vl(14, 4, 13, "b")
    for x in (3, 6, 9, 12):
        cv.vl(x, 4, 12, "w")
    beads = {3: (4, (8, 10)), 6: (5, (9, 11)), 9: (4, (7, 11)), 12: (5, (10, 11))}
    for x, (top, lows) in beads.items():
        cv.pts([(x - 1, top), (x, top), (x + 1, top)], "j")
        for ly in lows:
            cv.pts([(x - 1, ly), (x, ly)], "J")
            cv.put(x + 1, ly, "j")
    cv.outline("k")


def icon_ws_diqi(cv, r):
    rows = [
        "..jJ......Jj....",
        ".jjjJ....Jjjj...",
        ".jjjjJ..Jjjjjj..",
        "..jjjjJJjjjjj...",
        "....GjjGjjG.....",
        ".......G........",
        ".......G........",
        "...BBBBGBBBB....",
        "..BbBbbbbbbbB...",
        ".bbbbbbbbbbbbb..",
    ]
    cv.ascii(rows, 0, 3)
    _done(cv)


def icon_ws_xinzheng(cv, r):
    # a big square seal with a knob, pressing down on a sheet
    rows = [
        "....BB....",
        "...BPPb...",
        "....Bb....",
        "BBBBBBBBBb",
        "BPPPPPPPBb",
        "BPBBBBBBBb",
        "BPBBBBBBBb",
        "BBBBBBBBBb",
        "bbbbbbbbbb",
        "rrrrrrrrrr",
    ]
    cv.ascii(rows, 3, 1)
    cv.outline("k")
    cv.ascii(["..pppppppppppp..", ".pprrprrrprrpPP.", ".PPPPPPPPPPPPPP."], 0, 13)
    cv.pts([(1, 8), (0, 9), (14, 8), (15, 9), (1, 11), (14, 11), (0, 11), (15, 11)], "m")
    cv.pts([(1, 11), (14, 11)], None)


def icon_ws_tanpai(cv, r):
    rows = [
        ".....b.b......",
        "....BBbBB.....",
        ".....bbb......",
        "....rrrrrr....",
        "...BBBBBBB....",
        "..BPBBBBBbb...",
        ".BPBBBBBBBbb..",
        ".BPBBBBBBBbb..",
        ".BBBBBBBBBbb..",
        ".BBBBBBBBbbb..",
        "..bbbbbbbbb...",
    ]
    cv.ascii(rows, 0, 3)
    cv.outline("k")
    tag = sprite(["pPP", "pbP", "pPP", "PPP"])
    tag.outline("k")
    cv.paste(tag, 11, 6)
    cv.pts([(10, 6), (11, 5)], "r")


def icon_ws_yuanyang(cv, r):
    cv.ascii([
        ".........m......",
        "........mmm.....",
        "...m...mmmmm....",
        "..mmm.mmmmmms...",
        ".mmmmmmmmmmsss..",
        "mmmmmmmmmmssssss",
    ], 0, 8)
    cv.outline("t")
    env = sprite([
        "hhhhhhhhh",
        "hPhhhhhPP",
        "hhPhhhPhP",
        "hhhPhPhhP",
        "hhhhPhhrP",
        "PPPPPPPPP",
    ])
    env.outline("k")
    cv.paste(env, 5, 2)
    for x in range(16):
        cv.put(x, 15, None)


def icon_ws_xiaocai(cv, r):
    # two copper cash on a red cord with a tassel
    def c1(ox, oy):
        s = Cv(11, 11)
        for y in range(11):
            for x in range(11):
                dx, dy = x + 0.5 - 5.5, y + 0.5 - 5.5
                d = math.hypot(dx, dy)
                if d > 5.2:
                    continue
                q = max(abs(dx), abs(dy))
                lit = (-dx - dy) / (d * 1.414 + 1e-6)
                if q <= 1:
                    c = "k"
                elif d > 4.0:
                    c = "y" if lit > 0.35 else ("g" if lit < -0.35 else "e")
                elif q <= 2:
                    c = "e" if lit > 0 else "g"
                else:
                    c = "Y"
                s.put(x, y, c)
        s.outline("k")
        cv.paste(s, ox, oy)

    c1(-1, 0)
    c1(5, 5)
    cv.pts([(4, 5), (5, 4), (10, 10), (11, 11)], "r")
    cv.pts([(13, 13), (12, 12), (14, 14), (13, 15), (15, 15), (14, 15)], "r")
    cv.pts([(15, 14)], "R")
    cv.pts([(1, 1), (0, 0)], "r")


def icon_ws_renyuan(cv, r):
    rows = [
        "..ww........ww..",
        ".wbbw......wbbw.",
        ".wppp......pppw.",
        ".pkpp......ppkp.",
        ".pppP......Pppp.",
        "..pP........Pp..",
        ".iiii......jjjj.",
        "iIiiii....jJjjjj",
        "iIiiiii..jJjjjjj",
        "iiiiiiii.jjjjjjj",
    ]
    cv.ascii(rows, 0, 4)
    cv.ascii(["..y..", ".yWy.", "..y.."], 5, 1)
    cv.outline("k")


def icon_ws_guashi(cv, r):
    # clay teapot (spout up-left, loop handle right), a small cup, steam: teahouse talk
    rows = [
        "......bb......",
        ".....BPBb.....",
        "...wwwwwwww...",
        "B.BPPBBBBBBb.bb",
        "BBBPBBBBBBBbbb.b",
        ".BBPBBBBBBBbb..b",
        "..BBBBBBBBBbbbb.",
        "...bBBBBBBbbb...",
        "....bbbbbbbb....",
    ]
    teapot = sprite(rows)
    teapot.outline("k")
    cv.paste(teapot, 0, 4)
    cup = sprite(["hhhP", "hhPP", ".PP."])
    cup.outline("k")
    cv.paste(cup, 10, 10)
    cv.pts([(1, 3), (2, 2), (1, 1), (4, 2), (5, 1), (4, 0)], "m")


def icon_ws_kanshi(cv, r):
    rows = [
        "...PPPPPPPP...",
        "..PppppppppP..",
        "..YPPPPPPPPY..",
        "..RRRRRRRRrr..",
        "..RYRRRRRrrd..",
        "..RRRRRRRrrd..",
        "..RRRRRRrrrd..",
        "..YrrrrrrrdY..",
        "...dddddddd...",
    ]
    d = sprite(rows)
    d.outline("k")
    cv.paste(d, 1, 6)
    cv.line(2, 0, 7, 6, "B")
    cv.line(13, 0, 8, 6, "B")
    cv.pts([(2, 0), (13, 0)], "P")


def icon_ws_xiaoshi(cv, r):
    rows = [
        ".....b.b...",
        "....BBbBB..",
        ".....bbb...",
        "...BBBBBB..",
        "..BPBBBBbb.",
        ".BPBBBBBBbb",
        ".BBBBBBBBbb",
        ".BBBBkkBBbb",
        "..bbbkkbbb.",
    ]
    cv.ascii(rows, 1, 1)
    cv.outline("k")
    for x, y in [(6, 11), (7, 13), (5, 14)]:
        cv.put(x, y, "Y")
        cv.put(x + 1, y, "g")
    cv.pts([(12, 9), (13, 11), (11, 12)], "m")


def icon_ws_koujue(cv, r):
    rows = [
        ".www........www.",
        "wwbbw......wbbww",
        "wppppp....pppppw",
        "wpkppp....pppkpw",
        ".ppppkk..kkpppp.",
        ".pppPp....pPppp.",
        "..ppP......Ppp..",
        ".iiii......jjjj.",
        "iIiiii....jJjjjj",
    ]
    cv.ascii(rows, 0, 4)
    cv.outline("k")
    cv.pts([(8, 2), (7, 3), (8, 4), (7, 5), (8, 6)], "R")
    cv.pts([(7, 2), (8, 3), (7, 4), (8, 5)], "y")
    for x in (0, 15):
        for y in range(16):
            if cv.get(x, y) == "k" and y < 6:
                pass


def icon_ws_yingqian(cv, r):
    # one big bright cash coin with sparkles: the stake came back with more
    s = Cv(13, 13)
    for y in range(13):
        for x in range(13):
            dx, dy = x + 0.5 - 6.5, y + 0.5 - 6.5
            d = math.hypot(dx, dy)
            if d > 6.2:
                continue
            q = max(abs(dx), abs(dy))
            lit = (-dx - dy) / (d * 1.414 + 1e-6)
            if q <= 1:
                c = None
            elif d > 5.0:
                c = "y" if lit > 0.3 else ("g" if lit < -0.35 else "e")
            elif q <= 2:
                c = "k"
            elif q <= 3:
                c = "y" if lit > 0.2 else ("g" if lit < -0.2 else "e")
            else:
                c = "Y"
            s.put(x, y, c)
    s.outline("k")
    cv.paste(s, 0, 2)
    cv.ascii(["..y..", ".yWy.", "..y.."], 11, 0)
    cv.ascii([".y.", "yWy", ".y."], 12, 11)
    cv.put(1, 1, "y")


def icon_ws_shunshou(cv, r):
    rows = [
        "....pP.pP.....",
        "....pP.pP.pP..",
        ".pP.pP.pP.pP..",
        ".pP.pP.pP.pP..",
        ".pPppPppPppP..",
        ".pppppppppPP..",
        ".ppppppppPPP..",
        "..pppppppPP...",
        "...ppppPPP....",
        "....iiiiii....",
        "....iIiiin....",
    ]
    cv.ascii(rows, 1, 4)
    cv.recolor(["."], None)
    cv.outline("k")
    cv.ascii(["...y...", "..yWy..", "...y..."], 9, 0)
    cv.pts([(2, 1), (14, 3)], "y")


def icon_ws_pingju(cv, r):
    rows = [
        ".......YY.......",
        ".......gg.......",
        ".eYYYYYYYYYYYYg.",
        ".g.....gg.....g.",
        "g.g....gg....g.g",
        "...g...gg...g...",
        "YeeY...gg...YeeY",
        "gYYg...gg...gYYg",
        "......gYYg......",
        ".....gYYYYg.....",
        ".....bbbbbb.....",
    ]
    cv.ascii(rows, 0, 2)
    cv.outline("k")


def icon_ws_heju(cv, r):
    def stack(ox, n):
        for i in range(n):
            y = 12 - i * 2
            cv.ascii([".eyyye.", "gYYYYYg", ".ggggg."], ox, y)

    stack(1, 4)
    stack(8, 4)
    cv.outline("k")


def icon_ws_shuqian(cv, r):
    left = sprite([
        "ppppp.",
        "pbbpPp",
        "ppppPP",
        "pbbpP.",
        "pppPPp",
        "prrpPP",
        "prpPP.",
        "pppPPp",
        "PPPPP.",
    ])
    right = sprite([
        ".pppP",
        "ppbPP",
        "PppPP",
        ".pbPP",
        "pppPP",
        "PrPPP",
        ".rPPP",
        "ppPPP",
        ".PPPP",
    ])
    left.outline("k")
    right.outline("k")
    cv.paste(left, 0, 3)
    cv.paste(right, 9, 4)
    cv.pts([(8, 2), (8, 5), (8, 9), (8, 13)], "s")


def icon_ws_zhekou(cv, r):
    rows = [
        "...WWWWWW...",
        "..WWhhhhhhP.",
        ".WhhhhhhhhPP",
        ".WhkkhhkkhhP",
        ".WhhhhhhhhPP",
        ".hhhhPhhhhPP",
        ".hhhhPhhhPP.",
        "..hhhrrrhhP.",
        "..hhrhhhrPP.",
        "...hhhhhPP..",
        "....PPPPP...",
    ]
    cv.ascii(rows, 2, 2)
    cv.outline("k")
    cv.pts([(9, 3), (8, 4), (8, 5), (9, 6), (10, 7), (9, 8), (9, 9), (10, 10), (11, 11)], "b")


# --------------------------------------------------------------------------- icons 24x24


def icon_obj_almanac(cv, r):
    cv.rect(4, 2, 16, 20, "e")
    cv.rect(4, 2, 16, 1, "y")
    cv.rect(18, 2, 2, 20, "Y")
    cv.rect(4, 21, 16, 1, "g")
    # thread binding on the right edge
    for y in (4, 8, 12, 16, 19):
        cv.pts([(17, y), (18, y), (19, y)], "b")
    cv.vl(17, 3, 20, "Y")
    for y in (4, 8, 12, 16, 19):
        cv.pts([(17, y), (18, y), (19, y)], "b")
    # red cover band and sun/cloud emblem (no writing)
    cv.rect(6, 4, 3, 15, "r")
    cv.vl(6, 4, 18, "R")
    cv.ellipse(13, 9, 2.6, 2.6, "R")
    cv.ellipse(12.6, 8.6, 1.3, 1.3, "y")
    cv.pts([(10, 14), (11, 13), (12, 13), (13, 14), (14, 13), (15, 13), (16, 14)], "g")
    cv.pts([(11, 16), (12, 16), (13, 16), (14, 16), (15, 16)], "g")
    # page block under the cover
    cv.rect(5, 22, 15, 1, "P")
    cv.outline("k")


def icon_obj_brother_ledger(cv, r):
    # thread-bound account book, indigo cloth cover, page block below, brush across
    cv.rect(3, 1, 16, 19, "i")
    cv.rect(3, 1, 16, 1, "I")
    cv.rect(3, 1, 1, 19, "I")
    cv.rect(17, 2, 2, 18, "n")
    cv.rect(4, 20, 15, 2, "p")
    cv.hl(4, 18, 21, "P")
    # binding on the right edge
    cv.vl(16, 2, 19, "n")
    for y in (3, 7, 11, 15, 18):
        cv.pts([(16, y), (17, y), (18, y)], "P")
    # paper label strip with a few abstract strokes
    cv.rect(5, 3, 4, 11, "p")
    cv.rect(8, 3, 1, 11, "P")
    cv.pts([(6, 5), (7, 5), (6, 6), (6, 8), (7, 9), (6, 11), (7, 11)], "b")
    cv.outline("k")
    # brush laid across the lower cover
    brush = Cv(24, 24)
    brush.line(4, 20, 17, 12, "B", 1)
    brush.line(5, 20, 18, 12, "P", 1)
    brush.pts([(18, 11), (19, 11), (19, 12)], "g")
    brush.pts([(20, 10), (20, 11), (21, 10), (22, 9)], "w")
    brush.put(22, 10, "k")
    brush.outline("k")
    cv.paste(brush, 0, 0)


def icon_obj_notice(cv, r):
    cv.rect(3, 2, 18, 20, "p")
    cv.rect(3, 2, 18, 1, "h")
    cv.vl(20, 2, 21, "P")
    cv.hl(3, 20, 21, "P")
    # curled lower-right corner
    cv.pts([(20, 21), (19, 21), (20, 20)], None)
    cv.pts([(18, 20), (19, 20), (19, 19)], "P")
    cv.pts([(18, 21)], "B")
    # columns of abstract strokes (right to left), not characters
    rng = random.Random(7)
    for col in range(5):
        x = 17 - col * 3
        y = 5
        while y < 17:
            ln = rng.choice((1, 2, 2, 3))
            if y + ln > 17:
                break
            cv.vl(x, y, y + ln - 1, "w")
            if rng.random() < 0.35:
                cv.put(x - 1 if rng.random() < 0.5 else x + 1, y + ln // 2, "b")
            y += ln + 1
    # red seal lower left, paste dabs at the top corners
    cv.rect(5, 16, 4, 4, "r")
    cv.pts([(6, 17), (7, 18)], "R")
    cv.pts([(4, 3), (19, 3)], "B")
    cv.outline("k")


def _bold_outline(cv, c="k"):
    cv.outline(c)


def icon_tab_contacts(cv, r):
    back = sprite([
        "...wwwww...",
        "..wwbbwww..",
        "..wNNNNNw..",
        "..NkNNkNP..",
        "..NNNNNNP..",
        "...NNNNP...",
        "....NPP....",
        ".iiiiiiiin.",
        "iIIiiiiiinn",
        "iIiiiiiiinn",
        "iiiiiiiiinn",
    ])
    back.outline("k")
    front = sprite([
        "...wwwww...",
        "..wwwbbww..",
        "..wppppPw..",
        "..pkppkpP..",
        "..ppppppP..",
        "...pBBpP...",
        "....pPP....",
        ".jjjjjjjjf.",
        "jJJjjjjjjff",
        "jJjjjjjjjff",
        "jjjjjjjjjff",
        "jjjjjjjjjff",
    ])
    front.outline("k")
    cv.paste(back, 10, 2)
    cv.paste(front, 2, 9)


def icon_tab_demands(cv, r):
    cv.poly([(7, 3), (17, 2), (19, 21), (9, 22)], "p")
    cv.poly([(7, 3), (17, 2), (17.3, 4), (7.3, 5)], "h")
    cv.poly([(17, 2), (19, 21), (17.5, 21.2), (16, 3)], "P")
    # abstract marks in two strokes columns (2px wide so a small scale keeps them)
    for x, y0, y1 in ((13, 7, 9), (13, 11, 12), (13, 14, 17), (10, 8, 10), (10, 13, 16)):
        for y in range(y0, y1 + 1):
            cv.put(x + (y // 7), y, "w")
            cv.put(x + 1 + (y // 7), y, "w")
    cv.outline("k")
    # red pin on top
    cv.rect(11, 0, 3, 3, "r")
    cv.pts([(11, 0)], "R")
    cv.pts([(12, 3), (12, 4)], "m")


def icon_tab_dossier(cv, r):
    cv.rect(4, 2, 16, 20, "B")
    cv.rect(4, 2, 16, 2, "P")
    cv.rect(4, 2, 2, 20, "P")
    cv.rect(18, 4, 2, 18, "b")
    cv.rect(6, 20, 14, 2, "b")
    # stitches on the left spine
    for y in (4, 8, 12, 16):
        cv.rect(6, y, 2, 2, "w")
    # label strip
    cv.rect(13, 4, 4, 13, "p")
    cv.rect(16, 4, 1, 13, "P")
    cv.rect(13, 16, 4, 1, "P")
    cv.rect(14, 6, 2, 2, "b")
    cv.rect(14, 10, 2, 3, "b")
    # cord
    cv.rect(9, 10, 2, 12, "r")
    cv.rect(9, 10, 1, 12, "R")
    cv.outline("k")


def icon_tab_estates(cv, r):
    rows = [
        "...........ff...........",
        "f.........ffff.........f",
        "ff......ffEEEEff......ff",
        ".ffffffEEEtEEEEEffffffff",
        "..fEEEEEtEEEEtEEEEEEEff.",
        "..ffffffffffffffffffff..",
        "...pPpppppppppppppppP...",
        "...pPpppppppppppppppP...",
        "...pPppbbbbbbppwwpppP...",
        "...pPppbBBBbbppwwpppP...",
        "...pPppbBbbbbpppppppP...",
        "...pPppbBbbbbppppppPP...",
        "...pPppbBbbYbppppppPP...",
        "...pPppbBbbbbppppppPP...",
        "...PPPPbbbbbbPPPPPPPP...",
        "..tttttttttttttttttttt..",
    ]
    cv.ascii(rows, 0, 4)
    for y in range(24):
        cv.put(0, y, None)
        cv.put(23, y, None)
    cv.outline("k")


def icon_tab_rules(cv, r):
    # carpenter's square (L) and a pair of compasses: 规 and 矩 as tools
    cv.rect(3, 3, 3, 18, "Y")
    cv.rect(3, 18, 18, 3, "Y")
    cv.rect(3, 3, 1, 18, "e")
    cv.rect(3, 20, 18, 1, "g")
    cv.rect(5, 3, 1, 15, "g")
    for y in (6, 9, 12, 15):
        cv.put(5, y, "b")
    for x in (8, 11, 14, 17):
        cv.put(x, 18, "b")
    cv.outline("k")
    comp = Cv(24, 24)
    comp.line(14, 4, 10, 15, "m", 2)
    comp.line(15, 4, 19, 15, "s", 2)
    comp.ellipse(15, 4.5, 2.5, 2.5, "e")
    comp.put(14, 4, "y")
    comp.pts([(10, 16), (20, 16)], "t")
    comp.outline("k")
    cv.paste(comp, 0, 0)


def icon_tab_settings(cv, r):
    cx = cy = 12.0
    for y in range(24):
        for x in range(24):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = math.cos(a * 8) > 0.25
            outer = 9.6 if tooth else 7.4
            if d <= outer and d > 3.0:
                lit = (-dx - dy) / (d * 1.414 + 1e-6)
                c = "h" if lit > 0.45 else ("t" if lit < -0.45 else "m")
                if 5.0 < d <= 6.0:
                    c = "s" if lit > 0 else "E"
                cv.put(x, y, c)
    cv.outline("k")
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if 2.0 < d <= 3.0:
                cv.put(x, y, "k")


def icon_tab_shelf(cv, r):
    cv.rect(2, 2, 20, 20, "b")
    cv.rect(4, 4, 16, 6, "x")
    cv.rect(4, 12, 16, 7, "x")
    cv.rect(2, 2, 20, 2, "B")
    cv.rect(2, 10, 20, 2, "B")
    cv.rect(2, 19, 20, 3, "B")
    cv.rect(2, 2, 2, 20, "B")
    cv.rect(20, 4, 2, 18, "b")
    # top shelf: jar and box
    cv.ascii([".jj.", "jJjj", "jjjf", "jjjf", "fjjf"], 5, 5)
    cv.ascii(["rrrrr", "rRrrd", "rrrrd", "ddddd"], 12, 6)
    # bottom shelf: bundle and vase
    cv.ascii(["..ii..", ".iIii.", "iIiiin", "iiiinn", "iiiinn", ".nnnn."], 5, 13)
    cv.ascii(["pp.", "pP.", "ppP", "pPP", "ppP", "PPP"], 15, 13)
    cv.outline("k")


def icon_tab_tickets(cv, r):
    cv.rect(4, 2, 16, 20, "p")
    cv.rect(4, 2, 16, 2, "h")
    cv.rect(18, 4, 2, 18, "P")
    cv.rect(4, 20, 16, 2, "P")
    # inner printed border
    cv.rect(6, 5, 11, 1, "B")
    cv.rect(6, 5, 1, 13, "B")
    cv.rect(16, 5, 1, 13, "B")
    cv.rect(6, 17, 11, 1, "B")
    # entry strokes in columns, 2px wide (right to left, uneven lengths)
    cv.rect(13, 7, 2, 7, "w")
    cv.rect(10, 7, 2, 3, "w")
    cv.rect(10, 11, 2, 4, "w")
    # red seal lower left
    cv.rect(7, 12, 3, 4, "r")
    cv.rect(7, 12, 3, 1, "R")
    # torn stub edge on the left
    for y in range(2, 22, 3):
        cv.put(4, y, None)
    cv.outline("k")


ICONS = {
    "icon.coin.head": icon_coin_head,
    "icon.coin.tail": icon_coin_tail,
    "icon.seal": icon_seal,
    "icon.demand.goods": icon_demand_goods,
    "icon.demand.info": icon_demand_info,
    "icon.demand.money": icon_demand_money,
    "icon.demand.people": icon_demand_people,
    "icon.ws.caixing": icon_ws_caixing,
    "icon.ws.wenxing": icon_ws_wenxing,
    "icon.ws.liunian": icon_ws_liunian,
    "icon.ws.guanmian": icon_ws_guanmian,
    "icon.ws.pingan": icon_ws_pingan,
    "icon.ws.koushe": icon_ws_koushe,
    "icon.ws.shunshui": icon_ws_shunshui,
    "icon.ws.fanshen": icon_ws_fanshen,
    "icon.ws.zhuidi": icon_ws_zhuidi,
    "icon.ws.nianhuo": icon_ws_nianhuo,
    "icon.ws.nianwei": icon_ws_nianwei,
    "icon.ws.micang": icon_ws_micang,
    "icon.ws.chengmen": icon_ws_chengmen,
    "icon.ws.jiashu": icon_ws_jiashu,
    "icon.ws.qingzhang": icon_ws_qingzhang,
    "icon.ws.diqi": icon_ws_diqi,
    "icon.ws.xinzheng": icon_ws_xinzheng,
    "icon.ws.tanpai": icon_ws_tanpai,
    "icon.ws.yuanyang": icon_ws_yuanyang,
    "icon.ws.xiaocai": icon_ws_xiaocai,
    "icon.ws.renyuan": icon_ws_renyuan,
    "icon.ws.guashi": icon_ws_guashi,
    "icon.ws.kanshi": icon_ws_kanshi,
    "icon.ws.xiaoshi": icon_ws_xiaoshi,
    "icon.ws.koujue": icon_ws_koujue,
    "icon.ws.yingqian": icon_ws_yingqian,
    "icon.ws.shunshou": icon_ws_shunshou,
    "icon.ws.pingju": icon_ws_pingju,
    "icon.ws.heju": icon_ws_heju,
    "icon.ws.shuqian": icon_ws_shuqian,
    "icon.ws.zhekou": icon_ws_zhekou,
    "icon.obj.almanac": icon_obj_almanac,
    "icon.obj.brother_ledger": icon_obj_brother_ledger,
    "icon.obj.notice": icon_obj_notice,
    "icon.tab.contacts": icon_tab_contacts,
    "icon.tab.demands": icon_tab_demands,
    "icon.tab.dossier": icon_tab_dossier,
    "icon.tab.estates": icon_tab_estates,
    "icon.tab.rules": icon_tab_rules,
    "icon.tab.settings": icon_tab_settings,
    "icon.tab.shelf": icon_tab_shelf,
    "icon.tab.tickets": icon_tab_tickets,
}

# --------------------------------------------------------------------------- items 64x64

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
SILVER = ["E", "t", "s", "m", "m", "S"]
GOLD = ["b", "g", "Y", "e", "y"]
INDIGO = ["Q", "n", "i", "I"]
BROWN = ["w", "b", "B", "P"]
WOOL = ["t", "s", "m", "h"]
PORCELAIN = ["P", "h", "S", "W"]


def _ramp_pick(ramp, v, x, y, dither):
    v = max(0.0, min(0.999, v))
    f = v * (len(ramp) - 1)
    i = int(f)
    if dither and i + 1 < len(ramp):
        if (BAYER[y % 4][x % 4] + 0.5) / 16.0 < (f - i) * 0.9:
            i += 1
    elif not dither:
        i = int(round(f))
    return ramp[min(i, len(ramp) - 1)]


def light_ellipse(cv, cx, cy, rx, ry, ramp, only=None, bias=0.0, dither=False, spec=None):
    """Shade pixels inside an ellipse as a lit dome (light from upper left)."""
    lx, ly, lz = -0.55, -0.6, 0.58
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not cv.inside(x, y):
                continue
            if only is not None and cv.a[y][x] not in only:
                continue
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            nz = math.sqrt(1.0 - d)
            v = nx * lx + ny * ly + nz * lz
            v = (v + 0.35) / 1.35 + bias
            c = _ramp_pick(ramp, v, x, y, dither)
            if spec is not None and v > spec:
                c = ramp[-1]
            cv.a[y][x] = c


def light_band(cv, x0, x1, ramp, only, bias=0.0, dither=False, y0=0, y1=None):
    """Vertical cylinder shading across x0..x1 (lighter left of centre)."""
    y1 = cv.h if y1 is None else y1
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            if not cv.inside(x, y) or cv.a[y][x] not in only:
                continue
            t = (x + 0.5 - x0) / max(1.0, (x1 + 1 - x0))
            v = math.cos((t - 0.32) * 2.4) * 0.85 + bias
            cv.a[y][x] = _ramp_pick(ramp, v, x, y, dither)


def item_art_calligraphy(cv, r):
    cx = 32
    # hanging cord
    cv.line(cx, 1, cx - 7, 5, "B")
    cv.line(cx, 1, cx + 7, 5, "B")
    cv.put(cx, 0, "b")
    # mounting silk, paper heart, two hanging ribbons
    cv.rect(cx - 12, 7, 24, 49, "P")
    cv.rect(cx - 12, 7, 1, 49, "p")
    cv.rect(cx + 11, 7, 1, 49, "B")
    cv.rect(cx - 9, 11, 18, 40, "p")
    cv.rect(cx - 9, 11, 18, 1, "P")
    cv.rect(cx + 8, 11, 1, 40, "P")
    cv.rect(cx - 9, 50, 18, 1, "P")
    for x in (cx - 4, cx + 3):
        cv.vl(x, 7, 10, "B")
    cv.hl(cx - 12, cx + 11, 10, "B")
    cv.hl(cx - 12, cx + 11, 51, "B")
    # rods and knobs
    cv.rect(cx - 14, 5, 28, 2, "b")
    cv.hl(cx - 14, cx + 13, 5, "B")
    cv.rect(cx - 15, 56, 30, 3, "b")
    cv.hl(cx - 15, cx + 14, 56, "B")
    cv.hl(cx - 15, cx + 14, 58, "w")
    for kx in (cx - 18, cx + 15):
        cv.rect(kx, 55, 3, 5, "w")
        cv.put(kx, 55, "b")
        cv.put(kx + 1, 56, "o")
    cv.outline("k")
    # running-script columns: one flowing brush line per column, lifted now and then.
    # Deliberately continuous so it never splits into readable characters.
    def column(x, y0, y1, heavy):
        y = y0
        while y < y1:
            seg = r.randint(7, 13)
            amp = r.choice((1, 2, 2, 3))
            ph = r.random() * 6.283
            prev = None
            for k in range(seg):
                yy = y + k
                if yy >= y1:
                    break
                xx = x + int(round(amp * math.sin(ph + k * 0.85)))
                if prev is not None and abs(xx - prev) > 1:
                    cv.hl(prev, xx, yy, "k")
                cv.put(xx, yy, "k")
                if heavy and (k < 2 or k % 5 == 2):
                    cv.put(xx + 1, yy, "k")
                elif r.random() < 0.2:
                    cv.put(xx + 1, yy, "w")
                prev = xx
            y += seg + r.choice((1, 2, 2))
    column(cx + 4, 14, 46, True)
    column(cx - 1, 15, 46, True)
    column(cx - 6, 18, 36, False)
    cv.rect(cx - 7, 40, 3, 3, "r")
    cv.put(cx - 6, 41, "R")


def item_art_landscape(cv, r):
    top, bot = 16, 46
    x0, x1 = 4, 49
    # painting paper
    cv.rect(x0, top, x1 - x0, bot - top, "p")
    cv.hl(x0, x1 - 1, top, "P")
    cv.hl(x0, x1 - 1, bot - 1, "P")
    cv.hl(x0, x1 - 1, top + 1, "B")
    cv.hl(x0, x1 - 1, bot - 2, "B")
    # far mountains (mist), near mountains (ink), water and a boat
    far = []
    h = 26
    for x in range(x0 + 2, x1 - 1):
        h += r.choice((-1, 0, 0, 1))
        if x in (14, 15, 16, 30, 31):
            h -= 2
        h = max(21, min(31, h))
        far.append((x, h))
    for x, hy in far:
        cv.vl(x, hy, 36, "m")
        cv.put(x, hy, "s")
    near_peaks = [(12, 24), (20, 29), (38, 26), (45, 31)]
    for px, py in near_peaks:
        for x in range(px - 9, px + 10):
            yy = py + abs(x - px) * 2 // 3 + (1 if (x * 7) % 5 == 0 else 0)
            if x0 + 2 <= x < x1 - 1 and yy < 40:
                for y in range(yy, 40):
                    cv.put(x, y, "t" if x > px else "s")
                cv.put(x, yy, "E")
    for px, py in near_peaks:
        cv.put(px, py, "k")
        cv.line(px, py + 2, px + 2, py + 7, "E")
    cv.rect(x0 + 2, 40, x1 - x0 - 4, 4, "h")
    for x in range(x0 + 4, x1 - 4, 5):
        cv.hl(x, x + 2, 41 + (x // 5) % 2, "m")
    cv.hl(30, 34, 39, "w")
    cv.hl(31, 33, 40, "w")
    cv.put(32, 37, "b")
    cv.put(32, 38, "b")
    # pine on the left bank
    cv.vl(9, 30, 39, "w")
    for y, w in ((29, 2), (31, 3), (33, 4), (35, 3)):
        cv.hl(9 - w, 9 + w, y, "G")
        cv.hl(9 - w + 1, 9 + w - 1, y + 1, "f")
    cv.rect(x1 - 6, top + 3, 3, 3, "r")
    # left rod, right roll wrapped in blue cloth with a tie
    cv.rect(x0 - 2, top - 1, 2, bot - top + 2, "b")
    cv.vl(x0 - 2, top - 1, bot, "B")
    cv.rect(x1, top - 3, 10, bot - top + 6, "i")
    cv.rect(x1, top - 3, 10, 1, "I")
    light_band(cv, x1, x1 + 9, ["n", "i", "I"], {"i", "I"})
    cv.rect(x1 + 2, top - 5, 6, 2, "b")
    cv.rect(x1 + 2, bot + 3, 6, 2, "b")
    cv.hl(x1 + 2, x1 + 7, top - 5, "B")
    cv.rect(x1, 29, 10, 3, "Y")
    cv.hl(x1, x1 + 9, 29, "e")
    cv.line(x1 + 9, 31, x1 + 12, 38, "Y")
    cv.line(x1 + 8, 31, x1 + 10, 40, "g")
    cv.outline("k")


def item_clothing_coat(cv, r):
    # padded jacket, centre opening with knot buttons, laid flat
    body = [(18, 14), (25, 10), (39, 10), (46, 14), (48, 58), (16, 58)]
    cv.poly(body, "i")
    cv.poly([(18, 14), (25, 11), (8, 30), (2, 42), (10, 47), (19, 33)], "i")
    cv.poly([(46, 14), (39, 11), (56, 30), (62, 42), (54, 47), (45, 33)], "i")
    # quilted look: soft horizontal ridges
    for y in range(18, 57, 7):
        for x in range(17, 48):
            if cv.get(x, y) == "i":
                cv.put(x, y, "n")
            if cv.get(x, y - 1) == "i" and x % 2 == 0:
                cv.put(x, y - 1, "I")
    # cuffs and hem bands
    cv.poly([(2, 42), (10, 47), (12, 44), (4, 39)], "n")
    cv.poly([(62, 42), (54, 47), (52, 44), (60, 39)], "n")
    cv.rect(16, 55, 33, 3, "n")
    # light from upper left: right side and right sleeve darker
    cv.map(lambda x, y, c: ("n" if c == "i" and x > 40 and y > 14 else False))
    cv.map(lambda x, y, c: ("I" if c == "i" and x < 22 and y < 30 else False))
    # stand collar
    cv.rect(26, 7, 12, 5, "i")
    cv.rect(26, 7, 12, 1, "I")
    cv.rect(27, 11, 10, 1, "n")
    cv.vl(32, 8, 11, "Q")
    # centre opening and knot buttons
    cv.vl(32, 12, 57, "Q")
    for y in (15, 22, 29, 36, 43):
        cv.pts([(29, y), (30, y), (31, y), (33, y), (34, y), (35, y)], "P")
        cv.pts([(31, y - 1), (33, y + 1)], "B")
        cv.put(32, y, "p")
    # pockets
    cv.hl(20, 27, 44, "n")
    cv.hl(37, 44, 44, "Q")
    cv.outline("k")


def item_clothing_robe(cv, r):
    # long navy gown, laid flat with sleeves out, side-fastening front
    cv.poly([(22, 12), (27, 8), (37, 8), (42, 12), (44, 62), (20, 62)], "n")
    cv.poly([(22, 12), (27, 9), (4, 13), (1, 24), (6, 26), (22, 22)], "n")
    cv.poly([(42, 12), (37, 9), (60, 13), (63, 24), (58, 26), (42, 22)], "n")
    cv.map(lambda x, y, c: ("i" if c == "n" and (x < 26 or y < 14) and x < 40 else False))
    cv.map(lambda x, y, c: ("I" if c == "i" and (x < 8 and y < 18) else False))
    cv.map(lambda x, y, c: ("Q" if c == "n" and x > 41 and y > 22 else False))
    # cuffs
    cv.poly([(1, 24), (6, 26), (7, 22), (2, 20)], "i")
    cv.poly([(63, 24), (58, 26), (57, 22), (62, 20)], "Q")
    # stand collar
    cv.rect(27, 5, 10, 5, "n")
    cv.hl(27, 36, 5, "i")
    cv.hl(28, 35, 9, "Q")
    # 大襟: diagonal from collar to right armpit, then down the side
    cv.line(32, 10, 41, 18, "Q")
    cv.line(33, 10, 42, 18, "K")
    cv.vl(41, 18, 54, "Q")
    for x, y in ((35, 13), (39, 17), (41, 24), (41, 32), (41, 40)):
        cv.pts([(x - 1, y), (x, y), (x + 1, y)], "m")
        cv.put(x, y, "h")
    # side slits near the hem and a centre fold
    cv.vl(21, 52, 61, "K")
    cv.vl(43, 52, 61, "K")
    cv.vl(31, 24, 60, "i")
    cv.outline("k")


def item_clothing_qipao(cv, r):
    # a folded bolt of light figured cloth with the loose end hanging over the front
    top = [(6, 27), (40, 19), (58, 25), (24, 33)]
    cv.poly(top, "S")
    cv.poly([(6, 27), (24, 33), (24, 51), (6, 45)], "N")
    cv.poly([(24, 33), (58, 25), (58, 43), (24, 51)], "c")
    for k in range(1, 6):
        y = 33 + k * 3
        cv.line(24, y, 58, y - 8, "P")
        cv.line(6, 27 + k * 3, 24, 33 + k * 3, "P")
    # loose end draped down the front
    cv.poly([(40, 27), (52, 24), (54, 50), (52, 55), (43, 57), (41, 53)], "S")
    cv.map(lambda x, y, c: ("h" if c == "S" and x > 49 and y > 28 else False))
    cv.line(42, 52, 53, 49, "P")
    cv.hl(43, 51, 56, "P")
    # woven pattern: small plum blossoms and leaves
    def blossom(x, y):
        cv.pts([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "R")
        cv.put(x, y, "y")
    pts = []
    for y in range(20, 58, 5):
        for x in range(6 + (y // 5) % 2 * 3, 58, 7):
            pts.append((x, y))
    for x, y in pts:
        if cv.get(x, y) in ("S", "N", "c", "h") and cv.get(x + 1, y + 1) in ("S", "N", "c", "h", "P"):
            blossom(x, y)
            if cv.get(x + 2, y + 1) in ("S", "N", "c", "h"):
                cv.put(x + 2, y + 1, "J")
    cv.line(40, 27, 52, 24, "P")
    cv.outline("k")


def item_clothing_scarf(cv, r):
    # grey wool scarf tied in a loop, two ends hanging and crossing, fringed
    cv.ellipse(32, 19, 16, 11, "m")
    cv.ellipse(32, 16, 9, 5, "t")
    cv.ellipse(32, 15, 8, 3.5, "E", test=lambda x, y, d: y < 15)
    # back tail (right) then front tail (left) over it
    cv.poly([(31, 26), (41, 25), (47, 52), (37, 54)], "s")
    cv.poly([(24, 26), (35, 28), (31, 55), (20, 53)], "m")
    # knot where the loop meets the tails
    cv.ellipse(31, 28, 5, 4, "m")
    # knit texture: ribs along each piece, light from the upper left
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.get(x, y)
            if c == "m":
                if (x + (y // 2)) % 4 == 0:
                    cv.put(x, y, "s")
                elif (x < 24 and y < 20) or (x < 25 and y > 30):
                    if (x + y) % 2 == 0:
                        cv.put(x, y, "h")
            elif c == "s" and (x + (y // 2)) % 4 == 0:
                cv.put(x, y, "t")
    cv.map(lambda x, y, c: ("s" if c == "m" and x > 42 and y < 28 else False))
    cv.line(35, 28, 31, 55, "t")
    cv.outline("k")
    for x in range(20, 32, 2):
        y0 = 53 + (x - 20) * 2 // 11 + 1
        cv.vl(x, y0, y0 + 3 + (x // 2) % 2, "s")
    for x in range(37, 48, 2):
        y0 = 54 - (x - 37) * 2 // 10 + 1
        cv.vl(x, y0, y0 + 3 + (x // 2) % 2, "t")


def _gold_bar(cv, x, y, w, h, depth, stamps):
    top = [(x + depth, y), (x + w + depth, y), (x + w, y + depth), (x, y + depth)]
    cv.poly([(x, y + depth), (x + w, y + depth), (x + w, y + depth + h), (x, y + depth + h)], "Y")
    cv.poly(top, "e")
    cv.poly([(x + w, y + depth), (x + w + depth, y), (x + w + depth, y + h), (x + w, y + depth + h)], "g")
    cv.hl(x + depth, x + w + depth - 1, y, "y")
    cv.line(x, y + depth, x + depth, y, "y")
    cv.hl(x, x + w - 1, y + depth, "y")
    cv.hl(x + 1, x + w - 1, y + depth + h - 1, "g")
    cv.vl(x + w, y + depth, y + depth + h - 1, "b")
    for sx, sy, sw, sh in stamps:
        cv.rect(sx, sy, sw, sh, "g")
        cv.hl(sx, sx + sw - 1, sy, "b")
        cv.vl(sx, sy, sy + sh - 1, "b")
        cv.hl(sx + 1, sx + sw - 1, sy + sh - 1, "e")
        for k in range(1, sw - 1, 2):
            cv.put(sx + k, sy + 1 + (k // 2) % max(1, sh - 2), "b")
    cv.outline("k")


def item_goldbar_bar_one(cv, r):
    _gold_bar(cv, 13, 26, 32, 9, 6, [(23, 27, 10, 4)])
    cv.pts([(16, 30), (17, 31)], "W")


def item_goldbar_bar_ten(cv, r):
    _gold_bar(cv, 4, 18, 48, 17, 10, [(18, 20, 12, 6), (34, 20, 8, 5)])
    cv.pts([(8, 27), (9, 28), (10, 29)], "W")
    for x in range(6, 50, 9):
        cv.put(x, 40, "e")


def item_jewelry_bangle(cv, r):
    cx, cy = 32, 33
    cv.ellipse(cx, cy, 27, 18, "m")
    cv.ellipse(cx, cy - 3, 21, 11, None)
    light_ellipse(cv, cx, cy, 27, 18, SILVER, only={"m"}, bias=0.05)
    # inner visible wall (back side of the ring)
    cv.ellipse(cx, cy - 3, 21, 11, "t", test=lambda x, y, d: d > 0.82 and y < cy - 3)
    # engraved flowers along the front band
    for k in range(-3, 4):
        x = cx + k * 7
        yy = cy + int(round(math.sqrt(max(0.0, 1 - (k * 7 / 27.0) ** 2)) * 14)) - 1
        if cv.get(x, yy) not in (None, "k"):
            cv.pts([(x - 1, yy), (x + 1, yy), (x, yy - 1), (x, yy + 1)], "s")
            cv.put(x, yy, "t")
            cv.pts([(x + 3, yy - 1), (x + 4, yy - 1)], "s")
    cv.outline("k")
    cv.pts([(14, 22), (15, 21), (16, 21), (17, 20)], "W")


def item_silverware_box(cv, r):
    cx = 32
    # base drum
    cv.rect(cx - 21, 34, 42, 14, "m")
    cv.ellipse(cx, 48, 21, 6, "m")
    light_band(cv, cx - 21, cx + 20, SILVER, {"m"}, bias=0.05)
    # lid rim band
    cv.rect(cx - 23, 26, 46, 9, "m")
    cv.ellipse(cx, 35, 23, 6, "m", test=lambda x, y, d: y >= 35)
    light_band(cv, cx - 23, cx + 22, SILVER, {"m"}, bias=0.12, y0=24, y1=42)
    # lid top
    cv.ellipse(cx, 26, 23, 9, "h")
    light_ellipse(cv, cx, 26, 23, 9, ["s", "m", "h", "W"], only={"h"}, bias=0.15)
    # chased flower and bird on the lid
    cv.line(cx - 15, 29, cx - 4, 24, "t")
    cv.line(cx - 4, 24, cx + 6, 25, "t")
    for x, y in ((cx - 12, 27), (cx - 7, 25), (cx + 3, 24)):
        cv.pts([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "s")
    cv.ascii([
        "..tt....",
        ".tsst...",
        "tssssttt",
        ".tsss...",
        "..t.t...",
    ], cx + 5, 20)
    cv.put(cx + 6, 21, "k")
    # rim line between lid and base, hinge
    cv.hl(cx - 22, cx + 21, 35, "t")
    cv.rect(cx + 17, 33, 3, 4, "s")
    cv.outline("k")
    cv.pts([(cx - 17, 22), (cx - 16, 21), (cx - 15, 21)], "W")


def item_silverware_cup(cv, r):
    cx = 32
    cv.poly([(cx - 17, 14), (cx + 17, 14), (cx + 11, 40), (cx - 11, 40)], "m")
    cv.ellipse(cx, 40, 11, 5, "m")
    cv.rect(cx - 3, 44, 7, 6, "m")
    cv.ellipse(cx, 52, 12, 4, "m")
    light_band(cv, cx - 17, cx + 17, SILVER, {"m"}, bias=0.05)
    # mouth
    cv.ellipse(cx, 14, 17, 5, "h")
    cv.ellipse(cx, 15, 15, 3.6, "s")
    cv.ellipse(cx, 16, 13, 2.6, "t", test=lambda x, y, d: y >= 16)
    # scrolling vine round the body
    for x in range(cx - 13, cx + 13):
        y = 27 + int(round(math.sin((x - cx) / 3.0) * 3))
        if cv.get(x, y) not in (None,):
            cv.put(x, y, "t")
        if (x - cx) % 6 == 0:
            cv.pts([(x, y - 2), (x + 1, y - 2), (x + 1, y - 3)], "s")
        if (x - cx) % 6 == 3:
            cv.pts([(x, y + 2), (x - 1, y + 2), (x - 1, y + 3)], "s")
    cv.hl(cx - 15, cx + 15, 19, "s")
    cv.hl(cx - 10, cx + 10, 38, "s")
    cv.outline("k")
    cv.pts([(cx - 13, 18), (cx - 13, 19), (cx - 12, 21), (cx - 12, 22), (cx - 11, 24)], "W")


def item_silverware_spoon(cv, r):
    # oval bowl lower left, long engraved handle to the upper right
    cv.ellipse(17, 46, 11, 8, "m")
    light_ellipse(cv, 17, 46, 11, 8, ["t", "s", "m", "h", "W"], only={"m"}, bias=-0.1)
    cv.ellipse(17.5, 46.5, 8, 5.5, "s", test=lambda x, y, d: d > 0.55)
    for k in range(0, 34):
        x = 25 + k
        y = 40 - int(k * 0.95)
        w = 2 if k < 26 else 3
        for j in range(w):
            cv.put(x, y + j, "m" if j == 0 else "s")
        cv.put(x, y - 1, "h")
    # flared end of the handle
    cv.ellipse(58, 8, 4, 3.5, "m")
    light_ellipse(cv, 58, 8, 4, 3.5, SILVER, only={"m"})
    # engraved line along the handle
    for k in range(4, 30, 3):
        cv.put(26 + k, 40 - int(k * 0.95) + 1, "t")
    cv.outline("k")
    cv.pts([(11, 42), (12, 41), (13, 41)], "W")


def _bowl(cv, cx, cy, rx, deep):
    rim_ry = max(3, rx // 3)
    cv.ellipse(cx, cy, rx, deep, "S", test=lambda x, y, d: y >= cy)
    cv.rect(cx - rx // 3, cy + deep - 1, 2 * (rx // 3) + 1, 3, "S")
    light_ellipse(cv, cx, cy, rx, deep, PORCELAIN, only={"S"}, bias=0.1)
    cv.rect(cx - rx // 3, cy + deep, 2 * (rx // 3) + 1, 2, "P")
    # inside of the bowl
    cv.ellipse(cx, cy, rx, rim_ry, "h")
    cv.ellipse(cx, cy + 0.5, rx - 2, rim_ry - 1, "S")
    cv.ellipse(cx + 1, cy + 1, rx - 5, rim_ry - 1.5, "W")
    # blue bands and a flower spray
    for x in range(cx - rx, cx + rx + 1):
        t = (x + 0.5 - cx) / rx
        if abs(t) >= 1:
            continue
        yb = cy + int(math.sqrt(1 - t * t) * deep * 0.25) + 1
        if cv.get(x, yb) in ("S", "h", "W", "P"):
            cv.put(x, yb, "i")
        yf = cy + int(math.sqrt(1 - t * t) * deep * 0.85)
        if cv.get(x, yf) in ("S", "h", "W", "P") and abs(t) < 0.75:
            cv.put(x, yf, "i")
    for dx in (-rx // 2, 0, rx // 2):
        x = cx + dx
        y = cy + deep // 2 + 1
        cv.pts([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], "I")
        cv.put(x, y, "i")
        cv.pts([(x + 2, y - 1), (x - 2, y + 1)], "n")
    cv.hl(cx - rx // 3 + 1, cx + rx // 3 - 1, cy + deep, "i")


def item_utensils_bowl(cv, r):
    back = Cv(64, 64)
    _bowl(back, 22, 22, 17, 13)
    back.outline("k")
    front = Cv(64, 64)
    _bowl(front, 39, 37, 20, 15)
    front.outline("k")
    cv.paste(back, 0, 0)
    cv.paste(front, 0, 0)


def item_utensils_tinpot(cv, r):
    cx, cy = 30, 38
    # body
    cv.ellipse(cx, cy, 18, 15, "m")
    cv.rect(cx - 12, cy + 10, 25, 6, "m")
    light_ellipse(cv, cx, cy, 18, 15, WOOL + ["W"], only={"m"}, bias=0.05)
    # shoulder rim, lid, knob
    cv.ellipse(cx, cy - 12, 11, 3.5, "s")
    cv.ellipse(cx, cy - 13, 9, 2.6, "h")
    cv.ellipse(cx, cy - 16, 2.5, 2.5, "m")
    cv.put(cx - 1, cy - 17, "W")
    # short spout to the left
    cv.poly([(cx - 16, cy - 2), (cx - 25, cy - 9), (cx - 27, cy - 7), (cx - 17, cy + 4)], "m")
    cv.line(cx - 25, cy - 9, cx - 17, cy - 3, "h")
    cv.line(cx - 26, cy - 6, cx - 17, cy + 3, "s")
    # base ring
    cv.hl(cx - 12, cx + 12, cy + 15, "t")
    cv.outline("k")
    # loop handle over the top (提梁), drawn after so it stays a thin rod
    for a in range(0, 181, 3):
        t = math.radians(a)
        x = cx + int(round(math.cos(t) * 13))
        y = cy - 12 - int(round(math.sin(t) * 16))
        cv.put(x, y, "s")
        cv.put(x, y - 1, "k")
        cv.put(x + (1 if x > cx else -1), y, "k")
    for a in range(30, 101, 3):
        t = math.radians(a)
        cv.put(cx + int(round(math.cos(t) * 13)), cy - 12 - int(round(math.sin(t) * 16)), "h")
    cv.pts([(cx - 13, cy - 11), (cx + 13, cy - 11), (cx - 13, cy - 12), (cx + 13, cy - 12)], "t")


ITEMS = {
    "item.art.calligraphy": item_art_calligraphy,
    "item.art.landscape": item_art_landscape,
    "item.clothing.coat": item_clothing_coat,
    "item.clothing.qipao": item_clothing_qipao,
    "item.clothing.robe": item_clothing_robe,
    "item.clothing.scarf": item_clothing_scarf,
    "item.goldbar.bar_one": item_goldbar_bar_one,
    "item.goldbar.bar_ten": item_goldbar_bar_ten,
    "item.jewelry.bangle": item_jewelry_bangle,
    "item.silverware.box": item_silverware_box,
    "item.silverware.cup": item_silverware_cup,
    "item.silverware.spoon": item_silverware_spoon,
    "item.utensils.bowl": item_utensils_bowl,
    "item.utensils.tinpot": item_utensils_tinpot,
}

# --------------------------------------------------------------------------- portraits 48x64

# skin: (highlight, base, shade, deep)
SKIN_FAIR = ("c", "N", "P", "B")
SKIN_TAN = ("N", "P", "B", "b")
SKIN_PALE = ("W", "p", "P", "B")
# cloth ramps: (light, base, dark, deep)
C_INDIGO = ("I", "i", "n", "Q")
C_NAVY = ("i", "n", "Q", "K")
C_JADE = ("J", "j", "f", "Q")
C_RED = ("R", "r", "b", "w")
C_BROWN = ("P", "B", "b", "w")
C_DKBROWN = ("B", "b", "w", "k")
C_TAN = ("p", "P", "B", "b")
C_GREY = ("m", "s", "t", "E")
C_DKGREY = ("s", "t", "E", "f")
C_OLIVE = ("J", "l", "G", "f")
C_BLACK = ("t", "E", "f", "q")
C_WHITE = ("W", "h", "P", "B")
H_BLACK = ("E", "q", "Q", "K")
H_BROWN = ("b", "w", "x", "K")
H_GREY = ("h", "m", "s", "t")

CX = 24
EY = 23  # eye row


def _face_profile(kind):
    if kind == "female":
        main, tail = 7.0, [6.6, 6.2, 5.8, 5.2, 4.6, 3.8, 2.8]
    elif kind == "young":
        main, tail = 7.4, [7.2, 6.8, 6.3, 5.7, 5.0, 4.0, 2.8]
    elif kind == "broad":
        main, tail = 8.4, [8.3, 8.0, 7.6, 7.0, 6.2, 5.2, 3.8]
    elif kind == "thin":
        main, tail = 7.2, [6.8, 6.2, 5.6, 5.0, 4.4, 3.7, 2.8]
    else:
        main, tail = 8.0, [7.8, 7.4, 6.9, 6.3, 5.6, 4.6, 3.2]
    prof = {12: main - 3.0, 13: main - 1.4, 14: main - 0.5}
    for y in range(15, 28):
        prof[y] = main
    for k, v in enumerate(tail):
        prof[28 + k] = v
    return prof


class Bust:
    """A head-and-shoulders portrait built in layers on a flat paper background."""

    def __init__(self, cv, r, bg="P", skin=SKIN_FAIR, face="male"):
        self.cv, self.r, self.bg, self.skin = cv, r, bg, skin
        self.f = Cv(48, 64)       # figure
        self.back = Cv(48, 64)    # things behind the figure (outlined with it)
        self.prof = _face_profile(face)
        self.chin = max(self.prof)
        self.face_kind = face

    # ---- helpers
    def xr(self, y):
        hw = self.prof.get(y, 0)
        return int(math.floor(CX + hw - 0.5))

    def xl(self, y):
        hw = self.prof.get(y, 0)
        return int(math.ceil(CX - hw - 0.5))

    def is_face(self, x, y):
        return y in self.prof and self.xl(y) <= x <= self.xr(y)

    # ---- body
    def body(self, ramp, style="diag", build=0, collar=True, open_col=None):
        lt, base, dk, dp = ramp
        b = build
        f = self.f
        pts = [(17 - b // 2, 38), (31 + b // 2, 38), (38 + b, 41), (43 + b, 45), (46 + b // 2, 51),
               (48, 64), (0, 64), (2 - b // 2, 51), (5 - b, 45), (10 - b, 41)]
        f.poly(pts, base)
        # light upper left, shade right; arm creases
        f.map(lambda x, y, c: (dk if c == base and (x >= 37 + b or (x >= 33 and y >= 57)) else False))
        f.map(lambda x, y, c: (lt if c == base and ((x <= 10 and y <= 52 and x + y < 56) or (y <= 43 and x < 20)) else False))
        f.line(10 - b, 50, 12 - b, 63, dk)
        f.line(37 + b, 50, 35 + b, 63, dp)
        f.line(38 + b, 50, 36 + b, 63, dk)
        self.cloth = ramp
        if collar:
            f.rect(18, 36, 12, 4, base)
            f.hl(18, 29, 36, lt)
            f.vl(29, 36, 39, dk)
            f.hl(18, 29, 39, dk)
        if style == "diag":
            # right-fastening front (大襟): neck to right armpit, knot buttons
            f.line(CX, 40, 33, 46, dp)
            f.line(33, 46, 35, 50, dp)
            for x, y in ((28, 43), (33, 47)):
                f.pts([(x - 1, y), (x, y), (x + 1, y)], open_col or lt)
        elif style == "centre":
            f.vl(CX - 1, 40, 63, dp)
            for y in range(43, 64, 6):
                f.pts([(CX - 3, y), (CX - 2, y), (CX, y), (CX + 1, y)], open_col or lt)
        elif style == "uniform":
            f.vl(CX - 1, 40, 63, dp)
            for y in range(43, 64, 5):
                f.put(CX - 1, y, "Y")
                f.put(CX - 1, y + 1, "g")
            for px in (12, 28):
                f.rect(px, 47, 8, 1, dp)
                f.rect(px, 48, 8, 1, dk)
                f.vl(px + 3, 48, 49, dp)
                f.put(px + 3, 50, "Y")
        elif style == "tunic":
            f.vl(CX - 1, 40, 63, dp)
            for y in range(43, 64, 5):
                f.put(CX - 1, y, "Y")
        elif style == "open":
            # open jacket over a light undershirt
            f.poly([(CX - 6, 38), (CX + 6, 38), (CX + 4, 64), (CX - 5, 64)], open_col or "h")
            f.line(CX - 6, 38, CX - 5, 63, dp)
            f.line(CX + 6, 38, CX + 4, 63, dp)
            f.line(CX - 7, 39, CX - 6, 63, lt)

    # ---- head
    def neck(self):
        hi, s, sh, dp = self.skin
        f = self.f
        f.rect(CX - 4, self.chin - 2, 8, 41 - self.chin + 2, s)
        f.rect(CX + 1, self.chin - 2, 3, 41 - self.chin + 2, sh)
        f.hl(CX - 4, CX + 3, self.chin + 1, sh)
        f.hl(CX - 3, CX + 2, self.chin + 2, sh)

    def head(self, ears=True):
        hi, s, sh, dp = self.skin
        f = self.f
        for y in self.prof:
            for x in range(self.xl(y), self.xr(y) + 1):
                f.put(x, y, s)
        for y in self.prof:
            xr, xl = self.xr(y), self.xl(y)
            f.put(xr, y, sh)
            if y >= 18:
                f.put(xr - 1, y, sh)
            if 15 <= y <= 27:
                f.put(xl + 1, y, hi)
        # cheekbone and jaw shading on the right, chin line
        for y in range(27, self.chin + 1):
            f.put(self.xr(y) - 2, y, sh)
        f.hl(self.xl(self.chin), self.xr(self.chin), self.chin, sh)
        if ears:
            for y in range(21, 28):
                f.put(self.xl(y) - 1, y, s)
                f.put(self.xr(y) + 1, y, sh)
            for y in range(22, 27):
                f.put(self.xl(y) - 2, y, s)
                f.put(self.xr(y) + 2, y, sh)
            f.pts([(self.xl(23) - 1, 24), (self.xl(23) - 1, 25)], sh)
            f.pts([(self.xr(23) + 1, 24), (self.xr(23) + 1, 25)], dp)

    def eyes(self, kind="open", col="k"):
        f = self.f
        hi, s, sh, dp = self.skin
        L, R = (18, 19, 20), (27, 28, 29)
        if kind == "closed":
            f.pts([(18, EY), (19, EY + 1), (20, EY + 1), (27, EY + 1), (28, EY + 1), (29, EY)], col)
            return
        for xs in (L, R):
            for x in xs:
                f.put(x, EY, col)
        if kind in ("open", "wide"):
            f.pts([(19, EY + 1), (28, EY + 1)], col)
            f.pts([(18, EY + 1), (27, EY + 1)], "W" if kind == "wide" else sh)
        if kind == "down":
            f.pts([(17, EY + 1), (30, EY + 1)], col)
            f.pts([(19, EY + 1), (28, EY + 1)], "w")
        if kind == "narrow":
            f.pts([(18, EY - 1), (29, EY - 1)], sh)
        # lower lid shadow
        f.pts([(18, EY + 2), (19, EY + 2), (28, EY + 2), (29, EY + 2)], sh)

    def brows(self, kind="flat", col="w"):
        f = self.f
        y = EY - 3
        if kind == "flat":
            f.hl(17, 20, y, col)
            f.hl(27, 30, y, col)
        elif kind == "thick":
            f.hl(17, 21, y, col)
            f.hl(26, 30, y, col)
            f.hl(17, 20, y - 1, col)
            f.hl(27, 30, y - 1, col)
        elif kind == "thin":
            f.pts([(17, y + 1), (18, y), (19, y), (20, y)], col)
            f.pts([(27, y), (28, y), (29, y), (30, y + 1)], col)
        elif kind == "knit":
            f.pts([(17, y - 1), (18, y - 1), (19, y), (20, y), (21, y + 1)], col)
            f.pts([(26, y + 1), (27, y), (28, y), (29, y - 1), (30, y - 1)], col)
        elif kind == "worried":
            f.pts([(17, y + 1), (18, y), (19, y), (20, y - 1)], col)
            f.pts([(27, y - 1), (28, y), (29, y), (30, y + 1)], col)
        elif kind == "raised":
            f.pts([(17, y), (18, y - 1), (19, y - 1), (20, y - 1)], col)
            f.pts([(27, y - 1), (28, y - 1), (29, y - 1), (30, y)], col)

    def nose(self, big=False):
        f = self.f
        hi, s, sh, dp = self.skin
        for y in range(EY + 1, EY + 5):
            f.put(CX, y, sh)
        f.put(CX - 1, EY + 3, hi)
        f.pts([(CX - 2, EY + 5), (CX + 1, EY + 5)], dp)
        f.put(CX, EY + 5, sh)
        if big:
            f.pts([(CX - 3, EY + 5), (CX + 2, EY + 4)], sh)

    def mouth(self, kind="flat", lips=None):
        f = self.f
        hi, s, sh, dp = self.skin
        y = EY + 8
        lc = lips or dp
        if kind == "flat":
            f.hl(CX - 2, CX + 1, y, lc)
            f.put(CX - 1, y, "b" if lips is None else lc)
        elif kind == "smile":
            f.hl(CX - 2, CX + 1, y, lc)
            f.pts([(CX - 3, y - 1), (CX + 2, y - 1)], lc)
        elif kind == "frown":
            f.hl(CX - 2, CX + 1, y, lc)
            f.pts([(CX - 3, y + 1), (CX + 2, y + 1)], lc)
        elif kind == "open":
            f.hl(CX - 2, CX + 1, y, "b")
            f.hl(CX - 1, CX, y + 1, "w")
        elif kind == "thin":
            f.hl(CX - 2, CX + 1, y, sh)
        if lips:
            f.hl(CX - 1, CX, y + 1, sh)
        f.hl(CX - 1, CX, y + 2, sh)

    def cheeks(self, col="R"):
        self.f.pts([(18, EY + 4), (29, EY + 4)], col)

    def lines(self, forehead=True, folds=True, eyes=False):
        f = self.f
        hi, s, sh, dp = self.skin
        if forehead:
            f.hl(20, 23, 16, sh)
            f.hl(24, 27, 17, sh)
        if folds:
            f.pts([(CX - 4, EY + 5), (CX - 4, EY + 6), (CX - 4, EY + 7)], sh)
            f.pts([(CX + 3, EY + 5), (CX + 3, EY + 6), (CX + 4, EY + 7)], dp)
        if eyes:
            f.pts([(16, EY), (31, EY)], sh)

    def stubble(self, col=None):
        f = self.f
        hi, s, sh, dp = self.skin
        col = col or sh
        for y in range(EY + 5, self.chin + 1):
            for x in range(self.xl(y), self.xr(y) + 1):
                if (x + y) % 2 == 0 and f.get(x, y) in (s, hi) and not (CX - 2 <= x <= CX + 1 and y == EY + 8):
                    f.put(x, y, col)

    def moustache(self, col="w", wide=False):
        y = EY + 6
        self.f.hl(CX - 3, CX + 2, y, col)
        if wide:
            self.f.pts([(CX - 4, y + 1), (CX + 3, y + 1)], col)

    def goatee(self, col="m", long=4):
        f = self.f
        for k in range(long):
            f.hl(CX - 2 + k // 3, CX + 1 - k // 3, self.chin - 1 + k, col)
        f.hl(CX - 1, CX, EY + 6, col)

    def glasses(self, col="k", lens=None):
        f = self.f
        for ex in (19, 28):
            for x, y in ((ex - 2, EY - 1), (ex - 2, EY), (ex - 2, EY + 1), (ex + 2, EY - 1), (ex + 2, EY), (ex + 2, EY + 1),
                         (ex - 1, EY - 2), (ex, EY - 2), (ex + 1, EY - 2), (ex - 1, EY + 2), (ex, EY + 2), (ex + 1, EY + 2)):
                f.put(x, y, col)
            if lens:
                f.put(ex - 1, EY - 1, lens)
        f.hl(22, 25, EY - 1, col)
        f.pts([(16, EY - 1), (31, EY - 1)], col)

    # ---- hair
    def hair(self, ramp, style="crop", line=13):
        hi, base, dk, dp = ramp
        f = self.f
        top = 5 if style not in ("shaved",) else 6
        for y in range(top, 24):
            for x in range(14, 34):
                dx = abs(x + 0.5 - CX)
                inside = ((x + 0.5 - CX) / 9.6) ** 2 + ((y + 0.5 - 15) / 10.0) ** 2 <= 1.0
                if not inside:
                    continue
                hl = line if dx < 5 else line + int((dx - 4) * 1.6)
                if style in ("bob", "bun", "braids", "long"):
                    hl = line if dx < 6 else line + int((dx - 5) * 3)
                if y < min(hl, 22):
                    f.put(x, y, base)
        # shading
        f.map(lambda x, y, c: (hi if c == base and y < 11 and x < 22 and (x + y) % 2 == 0 else False))
        f.map(lambda x, y, c: (dk if c == base and x > 28 else False))
        f.map(lambda x, y, c: (dk if c == base and y >= line - 1 and abs(x + 0.5 - CX) < 6 else False))
        if style == "shaved":
            f.map(lambda x, y, c: ((dk if (x + y) % 2 else base) if c in (base, hi) else False))
        if style == "part":
            for y in range(6, line):
                f.put(CX - 4 + (y - 6) // 4, y, hi)
        if style == "slick":
            for y in range(6, line):
                f.put(CX - 5, y, dp)
            f.pts([(19, 8), (20, 7), (21, 7), (22, 7)], hi)
        if style == "bowl":
            f.rect(16, line, 16, 3, base)
            f.hl(16, 31, line + 2, dk)
            for x in range(16, 32, 3):
                f.put(x, line + 2, base)
        if style in ("bob", "long"):
            for y in range(line, 33 if style == "bob" else 40):
                for side in (-1, 1):
                    x0 = self.xl(y) - 1 if side < 0 else self.xr(y) + 1
                    w = 3 if y < 30 else 2
                    for k in range(w):
                        f.put(x0 + side * k, y, base if side < 0 else dk)
        if style in ("bob", "braids"):
            # fringe
            for x in range(17, 31):
                for y in range(line, line + 3 + (x % 3 == 0)):
                    f.put(x, y, base)
            f.hl(17, 30, line + 3, dk)
            for x in range(17, 31, 3):
                f.put(x, line + 3 + (x % 3 == 0), base)

    def bun(self, ramp, x=CX + 6, y=9, pin=None):
        hi, base, dk, dp = ramp
        self.back.ellipse(x, y, 4, 3.5, base)
        self.back.pts([(x - 2, y - 2), (x - 1, y - 2)], hi)
        self.back.hl(x - 2, x + 2, y + 2, dk)
        if pin:
            self.back.line(x - 6, y + 1, x + 6, y - 3, pin)

    def braids(self, ramp):
        hi, base, dk, dp = ramp
        for side in (-1, 1):
            x0 = 14 if side < 0 else 33
            for k, y in enumerate(range(22, 50)):
                x = x0 + side * (k // 9)
                c = base if (y // 2) % 2 else dk
                self.f.put(x, y, c)
                self.f.put(x + 1, y, c if side < 0 else dp)
            self.f.pts([(x0 + side * 3, 50), (x0 + side * 3 + 1, 50)], "r")

    # ---- headwear
    def cap_peaked(self, crown, band, badge="Y", visor="K", tall=6, flat_top=True):
        f = self.f
        lt, base, dk, dp = crown
        top = 12 - tall
        f.poly([(13, top + 2), (35, top + 2), (33, 12), (15, 12)], base)
        f.hl(14, 34, top + 1, base)
        f.hl(16, 32, top, base)
        f.hl(15, 30, top + 1, lt)
        f.map(lambda x, y, c: (dk if c == base and x > 29 and y < 13 else False))
        f.rect(15, 11, 18, 3, band)
        f.hl(15, 32, 11, "m" if band != "m" else "h")
        f.rect(CX - 1, top + 3, 2, 2, badge)
        f.put(CX - 1, top + 3, "y" if badge == "Y" else badge)
        f.poly([(15, 14), (33, 14), (31, 17), (17, 17)], visor)
        f.hl(18, 30, 14, "E")
        # shadow of the visor across the brow
        for x in range(16, 32):
            if self.is_face(x, 17):
                f.put(x, 17, self.skin[2])
            if self.is_face(x, 18) and (x + 1) % 2:
                f.put(x, 18, self.skin[2])

    def cap_flat(self, ramp, tilt=1):
        """Newsboy / flat cap: soft crown overhanging, short visor."""
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX + tilt, 10, 12, 5.5, base)
        f.rect(14, 10, 21, 4, base)
        f.map(lambda x, y, c: (lt if c == base and y < 9 and x < 24 else False))
        f.map(lambda x, y, c: (dk if c == base and x > 30 else False))
        f.hl(14, 34, 13, dk)
        f.poly([(14, 14), (31, 14), (29, 16), (15, 16)], dp)
        f.put(CX + tilt, 5, dp)
        for x in range(16, 32):
            if self.is_face(x, 16):
                f.put(x, 16, self.skin[2])

    def fedora(self, ramp, band="f", brim=7):
        f = self.f
        lt, base, dk, dp = ramp
        f.poly([(16, 4), (CX - 1, 2), (CX + 1, 3), (32, 4), (33, 13), (15, 13)], base)
        f.pts([(CX, 3), (CX, 4), (CX - 1, 4)], dk)
        f.rect(15, 10, 19, 3, band)
        f.poly([(15 - brim, 15), (33 + brim, 15), (35, 12), (13, 12)], base)
        f.hl(15 - brim, 33 + brim, 15, dk)
        f.map(lambda x, y, c: (lt if c == base and x < 21 and y < 10 else False))
        f.map(lambda x, y, c: (dk if c == base and x > 29 and y < 12 else False))
        for x in range(16, 32):
            if self.is_face(x, 16):
                f.put(x, 16, self.skin[2])
            if self.is_face(x, 17) and x % 2:
                f.put(x, 17, self.skin[2])

    def felt_hat(self, ramp):
        """Rounded felt hat with a narrow turned-up brim."""
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX, 10, 10, 7, base)
        f.rect(14, 10, 20, 4, base)
        f.rect(12, 12, 24, 3, dk)
        f.hl(12, 35, 12, base)
        f.map(lambda x, y, c: (lt if c == base and y < 9 and x < 22 else False))
        f.map(lambda x, y, c: (dk if c == base and x > 29 and y < 12 else False))

    def skullcap(self, ramp, knot="r"):
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX, 13, 9.5, 8, base, test=lambda x, y, d: y < 13)
        f.rect(15, 12, 18, 2, dk)
        for x in (19, CX, 28):
            f.vl(x, 6 if x == CX else 7, 11, dk)
        f.pts([(18, 8), (19, 7)], lt)
        f.rect(CX - 1, 3, 2, 2, knot)
        f.put(CX - 1, 3, "R")

    def conical(self, ramp):
        f = self.f
        lt, base, dk, dp = ramp
        f.poly([(CX, 1), (CX + 23, 15), (CX + 20, 17), (CX - 20, 17), (CX - 24, 15)], base)
        for k in range(-20, 21, 5):
            f.line(CX, 2, CX + k, 16, dk)
        f.hl(CX - 21, CX + 21, 16, dp)
        f.map(lambda x, y, c: (lt if c == base and x < CX - 3 and y < 12 else False))
        for x in range(16, 32):
            if self.is_face(x, 18):
                f.put(x, 18, self.skin[2])

    def earflap(self, ramp, trim="h"):
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX, 13, 10.5, 8.5, base, test=lambda x, y, d: y < 15)
        f.rect(13, 13, 22, 3, trim)
        f.hl(13, 34, 15, "P")
        for side in (13, 32):
            f.rect(side, 15, 3, 13, base)
            f.rect(side, 26, 3, 2, trim)
        f.map(lambda x, y, c: (lt if c == base and y < 10 and x < 22 else False))
        f.map(lambda x, y, c: (dk if c == base and x > 30 else False))

    def headband(self, col="h", knot=True):
        f = self.f
        for x in range(15, 34):
            for y in (14, 15, 16):
                if f.get(x, y) is not None:
                    f.put(x, y, col)
        f.hl(15, 33, 16, "P")
        if knot:
            f.pts([(33, 13), (34, 13), (35, 14), (34, 15), (35, 16), (36, 17)], col)

    def head_towel(self, ramp):
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX, 13, 10, 8, base, test=lambda x, y, d: y < 17)
        f.hl(14, 33, 16, dk)
        f.hl(15, 32, 15, base)
        f.pts([(30, 6), (31, 5), (32, 6), (33, 7), (31, 7)], lt)
        f.pts([(32, 8), (33, 9)], dk)
        f.map(lambda x, y, c: (lt if c == base and y < 10 and x < 21 else False))

    def headscarf(self, ramp, dots="h"):
        f = self.f
        lt, base, dk, dp = ramp
        f.ellipse(CX, 15, 11, 10, base, test=lambda x, y, d: y < 16)
        for y in range(15, 35):
            for side in (-1, 1):
                x0 = self.xl(y) - 1 if side < 0 else self.xr(y) + 1
                for k in range(3):
                    f.put(x0 + side * k, y, base if side < 0 else dk)
        f.hl(16, 31, 15, dk)
        f.poly([(CX - 6, 34), (CX + 6, 34), (CX + 2, 39), (CX - 2, 39)], base)
        f.pts([(CX + 2, 38), (CX + 4, 41), (CX + 5, 42), (CX + 3, 40)], dk)
        for y in range(6, 40, 3):
            for x in range(12, 37, 4):
                xx = x + (y // 3) % 2 * 2
                if f.get(xx, y) == base:
                    f.put(xx, y, dots)

    # ---- extras on the body
    def scarf(self, ramp, hang=True):
        lt, base, dk, dp = ramp
        f = self.f
        f.poly([(CX - 8, 35), (CX + 8, 35), (CX + 9, 41), (CX - 9, 41)], base)
        f.hl(CX - 8, CX + 8, 35, lt)
        f.hl(CX - 9, CX + 9, 41, dk)
        if hang:
            f.poly([(CX + 2, 41), (CX + 8, 41), (CX + 9, 56), (CX + 3, 57)], base)
            f.line(CX + 3, 42, CX + 4, 56, dk)
            for x in range(CX + 3, CX + 10, 2):
                f.put(x, 58, dk)

    def towel(self, col=("W", "h", "P", "B")):
        lt, base, dk, dp = col
        f = self.f
        f.poly([(CX - 10, 37), (CX - 4, 37), (CX - 6, 56), (CX - 11, 55)], base)
        f.poly([(CX + 4, 37), (CX + 10, 37), (CX + 10, 54), (CX + 5, 55)], base)
        f.hl(CX - 9, CX + 9, 36, base)
        f.line(CX - 5, 38, CX - 6, 55, dk)
        f.line(CX + 9, 38, CX + 9, 53, dk)
        f.vl(CX - 10, 38, 54, lt)

    def strap(self, col="b", lt="B"):
        f = self.f
        f.line(10, 40, 36, 63, col, 2)
        f.line(10, 39, 36, 62, lt)

    def apron(self, ramp):
        lt, base, dk, dp = ramp
        f = self.f
        f.poly([(CX - 8, 48), (CX + 7, 48), (CX + 9, 64), (CX - 10, 64)], base)
        f.line(CX - 8, 48, CX - 5, 40, dk)
        f.line(CX + 7, 48, CX + 4, 40, dk)
        f.hl(CX - 8, CX + 7, 48, lt)
        f.line(CX + 6, 49, CX + 8, 63, dk)

    def hand(self, x, y, w=4):
        hi, s, sh, dp = self.skin
        self.f.rect(x, y, w, 3, s)
        self.f.hl(x, x + w - 1, y, hi)
        self.f.hl(x, x + w - 1, y + 2, sh)
        for k in range(1, w, 2):
            self.f.put(x + k, y + 1, sh)

    # ---- finish
    def finish(self, outline="w"):
        fig = Cv(48, 64)
        fig.paste(self.back, 0, 0)
        fig.paste(self.f, 0, 0)
        fig.outline(outline)
        self.cv.rect(0, 0, 48, 64, self.bg)
        self.cv.paste(fig, 0, 0)


def _std_face(b, eyes="open", brows="flat", mouth="flat", lips=None):
    b.neck()
    b.head()
    b.eyes(eyes)
    b.brows(brows)
    b.nose()
    b.mouth(mouth, lips)


def portrait_ex_girl(cv, r):
    b = Bust(cv, r, bg="p", skin=SKIN_FAIR, face="female")
    b.body(C_RED, "diag", build=-3, open_col="p")
    _std_face(b, "open", "thin", "smile", lips="d")
    b.cheeks("c")
    b.hair(H_BLACK, "braids", line=13)
    b.braids(H_BLACK)
    b.finish()


def portrait_ex_hu2_man(cv, r):
    # silhouette only: a man in a brimmed hat against the lamp, no face shown
    b = Bust(cv, r, bg="P", skin=("f", "q", "Q", "K"), face="broad")
    sil = ("f", "q", "Q", "K")
    b.body(sil, "none", build=2, collar=True)
    b.neck()
    b.head(ears=True)
    b.fedora(("E", "q", "Q", "K"), band="K", brim=8)
    # rim light from the lamp on the left edge
    f = b.f
    for y in range(64):
        for x in range(48):
            if f.get(x, y) is not None and (f.get(x - 1, y) is None):
                if y > 14:
                    f.put(x, y, "o")
                    break
    # cigarette ember
    f.pts([(CX - 3, EY + 8), (CX - 4, EY + 8), (CX - 5, EY + 8)], "h")
    f.put(CX - 6, EY + 8, "R")
    b.finish("k")
    cv.pts([(CX - 7, EY + 6), (CX - 8, EY + 4), (CX - 7, EY + 2)], "s")


def portrait_ex_newsboy(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="young")
    b.body(C_TAN, "centre", build=-4, open_col="b")
    b.strap("w", "b")
    _std_face(b, "wide", "raised", "open")
    b.hair(H_BROWN, "crop", line=15)
    b.cap_flat(C_BROWN, tilt=2)
    # bundle of papers under the arm, lower left
    f = b.f
    f.rect(1, 50, 16, 11, "h")
    f.rect(1, 50, 16, 1, "W")
    for y in range(52, 60, 2):
        f.hl(3, 14, y, "m")
    f.rect(1, 58, 16, 3, "P")
    f.vl(9, 50, 60, "B")
    b.hand(13, 55, 5)
    b.finish()


def portrait_ex_oldman(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="thin")
    b.body(C_BROWN, "diag", build=-1)
    _std_face(b, "narrow", "flat", "thin")
    b.lines(forehead=True, folds=True, eyes=True)
    b.hair(H_GREY, "crop", line=11)
    # receding: bald crown with shine, grey at the sides
    f = b.f
    hi, s, sh, dp = b.skin
    for y in range(6, 15):
        for x in range(18, 30):
            if f.get(x, y) in H_GREY:
                f.put(x, y, s)
    f.pts([(20, 8), (21, 8), (21, 7)], hi)
    f.hl(18, 29, 15, sh)
    b.brows("flat", "m")
    b.goatee("h", long=5)
    b.moustache("m")
    b.glasses("w")
    b.finish()


def portrait_ex_patrol(cv, r):
    # police in a peaked cap; eyes stay in the cap's shadow
    b = Bust(cv, r, bg="m", skin=SKIN_FAIR, face="male")
    b.body(C_NAVY, "uniform", build=1)
    _std_face(b, "narrow", "flat", "flat")
    b.hair(H_BLACK, "crop", line=15)
    b.cap_peaked(C_NAVY, band="h", tall=6)
    f = b.f
    for y in range(EY - 4, EY + 2):
        for x in range(17, 31):
            if f.get(x, y) == b.skin[1] or f.get(x, y) == b.skin[0]:
                f.put(x, y, b.skin[2])
    # whistle cord
    f.line(14, 41, CX - 2, 46, "h")
    b.finish()


def portrait_ex_porter(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="broad")
    # sack on the shoulder, behind the head
    b.back.ellipse(12, 22, 12, 9, "B")
    b.back.ellipse(10, 19, 8, 5, "P")
    for x in range(2, 22, 3):
        b.back.put(x, 26, "b")
    b.body(C_GREY, "open", build=3, open_col="P")
    _std_face(b, "narrow", "thick", "flat")
    b.stubble()
    b.hair(H_BLACK, "crop", line=14)
    b.headband("h")
    b.finish()


def portrait_ex_shopboy(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="young")
    b.body(C_JADE, "centre", build=-2)
    b.apron(C_WHITE)
    _std_face(b, "open", "raised", "smile")
    b.hair(H_BLACK, "crop", line=14)
    b.finish()


def portrait_ex_soldier(cv, r):
    # puppet-army soldier: olive uniform and field cap, rifle strap across the chest
    b = Bust(cv, r, bg="m", skin=SKIN_TAN, face="male")
    b.body(C_OLIVE, "uniform", build=2)
    _std_face(b, "narrow", "flat", "flat")
    b.hair(H_BLACK, "crop", line=15)
    b.cap_peaked(C_OLIVE, band="l", badge="Y", visor="f", tall=5)
    f = b.f
    f.line(8, 40, 36, 63, "G", 2)
    f.line(8, 39, 36, 62, "l")
    b.finish("k")


def portrait_ex_student(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="young")
    b.body(C_TAN, "tunic", build=-2)
    _std_face(b, "open", "flat", "flat")
    b.hair(H_BLACK, "part", line=13)
    # a cloth-bound book held to the chest
    f = b.f
    f.rect(26, 48, 13, 16, "i")
    f.rect(26, 48, 13, 1, "I")
    f.rect(37, 49, 2, 15, "n")
    f.rect(28, 50, 3, 8, "p")
    b.hand(23, 52, 4)
    b.finish()


def portrait_nf1938a(cv, r):
    # 钱阿根, rice-shop porter: shaved head, towel round the neck, rice sack on the shoulder
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="broad")
    b.back.ellipse(38, 24, 11, 9, "P")
    b.back.ellipse(40, 21, 7, 5, "p")
    b.back.pts([(33, 26), (36, 27), (40, 27), (44, 26)], "B")
    b.body(C_DKBROWN, "open", build=3, open_col="P")
    _std_face(b, "open", "thick", "flat")
    b.hair(H_BLACK, "shaved", line=13)
    b.towel()
    b.finish()


def portrait_nf1938b(cv, r):
    # 周阿绣, young needlewoman: hair in a bun with a pin, thread and needle
    b = Bust(cv, r, bg="p", skin=SKIN_FAIR, face="female")
    b.bun(H_BLACK, x=CX + 5, y=8, pin="Y")
    b.body(C_JADE, "diag", build=-3, open_col="P")
    _std_face(b, "down", "thin", "flat", lips="d")
    b.hair(H_BLACK, "long", line=13)
    f = b.f
    for y in range(28, 40):
        for x in (14, 15, 16, 31, 32, 33):
            if f.get(x, y) in H_BLACK:
                f.put(x, y, None)
    # hands holding a needle and a length of thread
    b.hand(12, 54, 5)
    b.hand(26, 55, 5)
    f.line(17, 55, 26, 56, "h")
    f.line(27, 52, 30, 57, "m")
    f.put(27, 52, "W")
    b.finish()


def portrait_nf1938c(cv, r):
    # 方小安, apprentice at the herb shop: bowl cut, light jacket, a paper herb packet
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="young")
    b.body(C_WHITE, "centre", build=-4, open_col="B")
    b.apron(C_INDIGO)
    _std_face(b, "wide", "flat", "flat")
    b.hair(H_BLACK, "bowl", line=14)
    f = b.f
    f.poly([(28, 50), (38, 49), (39, 58), (29, 59)], "p")
    f.line(28, 50, 38, 49, "W")
    f.line(33, 49, 34, 59, "r")
    f.line(28, 54, 39, 53, "r")
    f.vl(39, 50, 58, "P")
    b.hand(36, 56, 4)
    b.finish()


def portrait_nf1938d(cv, r):
    # 崔老奎, night watchman: earflap cap, padded jacket, a small lit lantern
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="thin")
    b.body(C_DKBROWN, "centre", build=0)
    _std_face(b, "narrow", "worried", "thin")
    b.lines(True, True, True)
    b.stubble("m")
    b.earflap(C_GREY, trim="P")
    f = b.f
    # lantern lower left with its glow on the coat
    f.vl(8, 44, 47, "w")
    f.ellipse(8, 53, 5, 5.5, "y")
    f.ellipse(7, 52, 2.5, 3, "W")
    f.hl(5, 11, 47, "b")
    f.hl(5, 11, 58, "b")
    for y in range(48, 58):
        f.put(4, y, "Y")
        f.put(12, y, "Y")
    for x in range(13, 18):
        for y in range(47, 60):
            if f.get(x, y) in C_DKBROWN and (x + y) % 2 == 0:
                f.put(x, y, "g")
    b.hand(10, 42, 4)
    b.finish()


def portrait_nf1939a(cv, r):
    # 柴佬, firewood seller from outside the gate: head cloth, bundle of sticks on the back
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="broad")
    for k, (x0, y0) in enumerate(((2, 30), (4, 32), (6, 31), (3, 35), (8, 34))):
        b.back.line(x0, y0, x0 + 9, y0 - 26, "B" if k % 2 else "b", 2)
    b.back.line(1, 24, 13, 20, "w", 1)
    b.body(C_DKBROWN, "diag", build=2)
    _std_face(b, "narrow", "thick", "frown")
    b.stubble()
    b.lines(True, False, True)
    b.head_towel(C_GREY)
    f = b.f
    f.line(10, 40, 18, 63, "w", 2)
    b.finish()


def portrait_nf1939b(cv, r):
    # 茧账, clerk at the cocoon firm: slick part, grey gown, black sleeve guards, ledger
    b = Bust(cv, r, bg="p", skin=SKIN_PALE, face="thin")
    b.body(C_GREY, "diag", build=-1)
    _std_face(b, "narrow", "flat", "thin")
    b.hair(H_BLACK, "slick", line=13)
    f = b.f
    # ledger held in front, sleeve guards on the forearms
    f.rect(14, 51, 20, 13, "i")
    f.rect(14, 51, 20, 1, "I")
    f.rect(16, 53, 4, 9, "p")
    f.rect(6, 54, 9, 10, "q")
    f.rect(33, 54, 9, 10, "q")
    f.hl(6, 14, 54, "E")
    b.hand(11, 52, 4)
    b.hand(33, 52, 4)
    # a pen tucked behind the ear
    f.line(32, 15, 35, 25, "B")
    f.put(35, 26, "k")
    b.finish()


def portrait_nf1939c(cv, r):
    # 乡嫂, country woman in town for New Year: printed headscarf, padded jacket, red cheeks
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="female")
    b.body(C_BROWN, "diag", build=-1, open_col="p")
    _std_face(b, "open", "thin", "smile", lips="d")
    b.cheeks("R")
    b.hair(H_BLACK, "crop", line=13)
    b.headscarf(C_INDIGO, dots="h")
    # a basket handle over the arm at the lower right
    f = b.f
    f.rect(30, 55, 16, 9, "g")
    for x in range(30, 46, 2):
        f.vl(x, 55, 63, "B")
    f.hl(30, 45, 55, "Y")
    for a in range(0, 181, 6):
        t = math.radians(a)
        f.put(38 + int(round(math.cos(t) * 7)), 55 - int(round(math.sin(t) * 6)), "b")
    b.finish()


def portrait_nf1939d(cv, r):
    # 区抄, new scribe at the district office: side part, round glasses, grey tunic, pen in pocket
    b = Bust(cv, r, bg="m", skin=SKIN_PALE, face="thin")
    b.body(C_DKGREY, "tunic", build=-1)
    _std_face(b, "narrow", "knit", "thin")
    b.hair(H_BLACK, "part", line=13)
    b.glasses("k", lens="W")
    f = b.f
    f.rect(28, 47, 8, 1, "f")
    f.rect(28, 48, 8, 1, "E")
    f.vl(30, 44, 48, "Y")
    f.put(30, 44, "y")
    b.finish()


def portrait_nf1940a(cv, r):
    # 顾承年, young clerk sent with the new officials: grey fedora, dark gown, document folder
    b = Bust(cv, r, bg="P", skin=SKIN_PALE, face="young")
    b.body(C_NAVY, "diag", build=0, open_col="m")
    _std_face(b, "narrow", "flat", "thin")
    b.hair(H_BLACK, "slick", line=14)
    b.fedora(C_GREY, band="f", brim=5)
    f = b.f
    f.rect(25, 49, 16, 15, "B")
    f.rect(25, 49, 16, 1, "P")
    f.rect(27, 51, 12, 2, "p")
    f.vl(33, 53, 63, "b")
    b.hand(22, 54, 4)
    b.finish()


def portrait_nf1940b(cv, r):
    # 齐路生, news hawker walking in from the Nanjing road: dark cap, scarf, papers in a bag
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="male")
    b.body(C_BROWN, "centre", build=1)
    b.strap("w", "b")
    _std_face(b, "narrow", "flat", "flat")
    b.moustache("w")
    b.stubble("B")
    b.lines(True, True, False)
    b.hair(H_BLACK, "crop", line=15)
    b.cap_flat(C_BLACK, tilt=-1)
    b.scarf(C_GREY)
    f = b.f
    f.rect(30, 52, 15, 12, "o")
    f.hl(30, 44, 52, "B")
    f.rect(32, 47, 4, 6, "h")
    f.rect(37, 46, 4, 7, "p")
    f.hl(32, 35, 49, "m")
    f.hl(37, 40, 48, "m")
    b.finish()


def portrait_nf1940c(cv, r):
    # 蔡布成, cloth dealer: skullcap, short jacket over a gown, a roll of blue cloth
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="broad")
    b.body(C_BLACK, "centre", build=2, open_col="Y")
    _std_face(b, "open", "flat", "smile")
    b.moustache("w")
    b.hair(H_BLACK, "crop", line=14)
    b.skullcap(C_BLACK, knot="r")
    f = b.f
    # cloth roll under the left arm
    f.rect(0, 50, 22, 9, "i")
    f.hl(0, 21, 50, "I")
    f.hl(0, 21, 58, "n")
    f.ellipse(21, 54.5, 2.5, 4.5, "I")
    f.ellipse(21, 54.5, 1, 2, "n")
    b.hand(17, 57, 4)
    b.finish()


def portrait_nf1940d(cv, r):
    # 方晚晴, a woman looking for someone: bobbed hair with a clip, holds half an old ticket
    b = Bust(cv, r, bg="p", skin=SKIN_FAIR, face="female")
    b.body(C_GREY, "diag", build=-3, open_col="h")
    _std_face(b, "open", "worried", "thin")
    b.hair(H_BLACK, "bob", line=13)
    f = b.f
    f.pts([(29, 14), (30, 14), (31, 15)], "Y")
    # half a pawn ticket, torn edge on the right, half a seal
    f.rect(16, 50, 11, 14, "p")
    f.hl(16, 26, 50, "W")
    for y in range(50, 64, 2):
        f.put(27, y, "p")
        f.put(26, y + 1, None)
    f.vl(19, 53, 60, "b")
    f.rect(22, 57, 4, 3, "r")
    b.hand(12, 55, 4)
    b.finish()


def portrait_stranger_boatman(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="broad")
    b.body(C_INDIGO, "open", build=2, open_col="P")
    _std_face(b, "narrow", "thick", "flat")
    b.lines(False, True, True)
    b.hair(H_BLACK, "crop", line=15)
    b.conical(C_TAN)
    # coil of rope over the shoulder
    f = b.f
    f.ellipse(37, 50, 8, 7, "B")
    f.ellipse(37, 50, 5, 4, "i")
    f.ellipse(37, 50, 8, 7, "B", test=lambda x, y, d: d > 0.55)
    for a in range(0, 360, 30):
        t = math.radians(a)
        f.put(37 + int(round(math.cos(t) * 6.5)), 50 + int(round(math.sin(t) * 5.5)), "b")
    f.line(30, 42, 45, 58, "b")
    b.finish()


def portrait_stranger_student(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_FAIR, face="young")
    b.body(C_NAVY, "tunic", build=-2)
    b.strap("b", "B")
    _std_face(b, "open", "flat", "thin")
    b.hair(H_BLACK, "crop", line=15)
    b.cap_peaked(C_NAVY, band="Q", badge="Y", visor="K", tall=5)
    b.scarf(C_WHITE, hang=True)
    b.finish()


def portrait_stranger_waixiang(cv, r):
    b = Bust(cv, r, bg="P", skin=SKIN_TAN, face="thin")
    b.body(C_DKGREY, "diag", build=0)
    _std_face(b, "down", "worried", "thin")
    b.stubble()
    b.lines(True, True, False)
    b.hair(H_BLACK, "crop", line=14)
    b.felt_hat(C_DKBROWN)
    # bundle tied across the chest (包袱)
    f = b.f
    b.back.ellipse(41, 40, 7, 8, "i")
    b.back.pts([(38, 36), (40, 35), (43, 37)], "I")
    f.line(7, 41, 33, 63, "i", 2)
    f.line(7, 40, 33, 62, "I")
    f.ellipse(31, 59, 2.5, 2, "i")
    b.finish()


def portrait_stranger_widow(cv, r):
    b = Bust(cv, r, bg="p", skin=SKIN_PALE, face="female")
    b.bun(H_BLACK, x=CX + 4, y=8)
    b.body(C_BLACK, "diag", build=-3, open_col="t")
    _std_face(b, "down", "worried", "thin")
    b.hair(H_BLACK, "long", line=12)
    f = b.f
    for y in range(26, 40):
        for x in (14, 15, 16, 31, 32, 33):
            if f.get(x, y) in H_BLACK:
                f.put(x, y, None)
    # a small white flower in the hair
    f.pts([(30, 9), (31, 8), (32, 9), (31, 10), (31, 9)], "W")
    f.put(31, 9, "h")
    b.finish()


PORTRAITS = {
    "portrait.ex_girl": portrait_ex_girl,
    "portrait.ex_hu2_man": portrait_ex_hu2_man,
    "portrait.ex_newsboy": portrait_ex_newsboy,
    "portrait.ex_oldman": portrait_ex_oldman,
    "portrait.ex_patrol": portrait_ex_patrol,
    "portrait.ex_porter": portrait_ex_porter,
    "portrait.ex_shopboy": portrait_ex_shopboy,
    "portrait.ex_soldier": portrait_ex_soldier,
    "portrait.ex_student": portrait_ex_student,
    "portrait.nf1938a": portrait_nf1938a,
    "portrait.nf1938b": portrait_nf1938b,
    "portrait.nf1938c": portrait_nf1938c,
    "portrait.nf1938d": portrait_nf1938d,
    "portrait.nf1939a": portrait_nf1939a,
    "portrait.nf1939b": portrait_nf1939b,
    "portrait.nf1939c": portrait_nf1939c,
    "portrait.nf1939d": portrait_nf1939d,
    "portrait.nf1940a": portrait_nf1940a,
    "portrait.nf1940b": portrait_nf1940b,
    "portrait.nf1940c": portrait_nf1940c,
    "portrait.nf1940d": portrait_nf1940d,
    "portrait.stranger_boatman": portrait_stranger_boatman,
    "portrait.stranger_student": portrait_stranger_student,
    "portrait.stranger_waixiang": portrait_stranger_waixiang,
    "portrait.stranger_widow": portrait_stranger_widow,
}

# --------------------------------------------------------------------------- driver

SIZES = {"icon": None, "item": (64, 64), "portrait": (48, 64)}
ICON24 = ("icon.obj.", "icon.tab.")


def base_size(art_id):
    if art_id.startswith("icon."):
        return (24, 24) if art_id.startswith(ICON24) else (16, 16)
    return SIZES[art_id.split(".", 1)[0]]


def all_drawers():
    out = {}
    out.update(ICONS)
    out.update(globals().get("ITEMS", {}))
    out.update(globals().get("PORTRAITS", {}))
    return out


def out_rel(art_id):
    cat, rest = art_id.split(".", 1)
    return "art/ai/%s/%s.png" % (cat, rest)


def render(art_id):
    w, h = base_size(art_id)
    cv = Cv(w, h)
    all_drawers()[art_id](cv, rng_for(art_id))
    im = cv.image()
    assert im.size == (w, h), (art_id, im.size)
    raw = im.tobytes()
    for k in range(0, len(raw), 4):
        assert tuple(raw[k:k + 4]) in ALLOWED, (art_id, tuple(raw[k:k + 4]))
    return im


def png_bytes(im):
    clean = Image.frombytes("RGBA", im.size, im.convert("RGBA").tobytes())
    buf = io.BytesIO()
    clean.save(buf, format="PNG", optimize=False, compress_level=9)
    return buf.getvalue()


def build_sheet(ids, images, path, scale=3):
    from PIL import ImageDraw, ImageFont

    font = ImageFont.load_default()
    groups = [("icon", 10), ("item", 7), ("portrait", 9)]
    rows = []
    for cat, cols in groups:
        sel = [i for i in ids if i.startswith(cat + ".")]
        for k in range(0, len(sel), cols):
            rows.append(sel[k:k + cols])
    cell_w = 64 * scale + 16
    label_h = 14
    heights = [max(images[i].size[1] for i in row) * scale + label_h + 10 for row in rows]
    W = max(len(r) for r in rows) * cell_w + 8
    H = sum(heights) + 8
    sheet = Image.new("RGBA", (W, H), (0x80, 0x78, 0x6c, 255))
    d = ImageDraw.Draw(sheet)
    y = 4
    for row, rh in zip(rows, heights):
        for n, aid in enumerate(row):
            im = images[aid]
            big = im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST)
            x = 4 + n * cell_w + (cell_w - big.size[0]) // 2
            sheet.alpha_composite(big, (x, y))
            label = aid.split(".", 1)[1]
            tw = d.textlength(label, font=font)
            d.text((4 + n * cell_w + (cell_w - tw) / 2, y + rh - label_h - 6), label,
                   fill=(255, 255, 255, 255), font=font)
        y += rh
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sheet.save(path)


def main(argv):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--out", default=ROOT)
    p.add_argument("--only", default="")
    p.add_argument("--check", action="store_true")
    p.add_argument("--force", action="store_true")
    p.add_argument("--sheet", default="")
    p.add_argument("--zoom", default="")
    p.add_argument("--list", action="store_true")
    a = p.parse_args(argv)
    ids = sorted(i for i in all_drawers() if i.startswith(a.only))
    if a.list:
        for i in ids:
            print(i, out_rel(i))
        return 0
    images = {}
    bad = 0
    for aid in ids:
        im = render(aid)
        images[aid] = im
        data = png_bytes(im)
        path = os.path.join(a.out, out_rel(aid))
        if a.check:
            if not os.path.isfile(path) or open(path, "rb").read() != data:
                print("DIFF %s" % out_rel(aid))
                bad += 1
            continue
        if os.path.exists(path) and not a.force:
            if open(path, "rb").read() == data:
                continue
            print("SKIP (exists, use --force) %s" % out_rel(aid))
            bad += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
    if a.zoom:
        os.makedirs(a.zoom, exist_ok=True)
        for aid, im in images.items():
            k = 12 if im.size[0] <= 24 else 6
            im.resize((im.size[0] * k, im.size[1] * k), Image.NEAREST).save(os.path.join(a.zoom, aid + ".png"))
    if a.sheet:
        build_sheet(ids, images, a.sheet)
    print("%s %d images%s" % ("CHECK" if a.check else "WROTE", len(ids), (", %d problems" % bad) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
