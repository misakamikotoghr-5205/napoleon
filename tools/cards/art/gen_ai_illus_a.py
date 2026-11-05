#!/usr/bin/env python3
"""AI pixel art for the card game, batch "illus_a": 64x48 card illustrations.

    python3 tools/cards/art/gen_ai_illus_a.py [--out=<root>] [--only=<id prefix>] [--check]
                                              [--sheet=<png>] [--zoom=<dir>] [--force] [--list]

Covers the illus.* ids of events (ev.), news (nw.), night cards (nt.), estates (es.),
prison (pr.), tickets (tk.) and goals (gl.). Every picture is a small opaque scene drawn
here in code, pixel by pixel (no image model, no fonts, no source images). Writes
art/ai/illus/<rest>.png for art id illus.<rest>.

* Deterministic: same script -> byte-identical PNGs. Each picture's RNG is
  random.Random(first 8 bytes of sha256(art_id)), the PNG has only IHDR/IDAT/IEND
  (8-bit RGBA, fixed zlib level, no time or color chunks), ids are processed sorted.
* Colors: the same letter table as tools/cards/art/gen_ai_small.py (values of keys in
  data/cards/theme/palette.dev.json, copied below so a later palette edit does not
  silently change shipped pixels). Every pixel is opaque.
* No letters, numbers or readable characters: notices, ledgers and seals are abstract
  strokes. No faces, no gore; officials are uniformed silhouettes.
* Existing files under art/ai are never overwritten unless --force is given
  (re-running over this script's own output); --check compares without writing.

Batch owner: ai:claude:opus-5.5:2026-10-22:art-illus_a. Spec: docs/cards/ART_SPEC.md.
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
PROVENANCE = "ai:claude:opus-5.5:2026-10-22:art-illus_a"
W, H = 64, 48

# palette.dev.json keys (opaque ones). One letter each, same letters as gen_ai_small.py.
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
ALLOWED = set(COL.values())

# Light/dark neighbour of each color (same tables as gen_ai_small.py).
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
# One step toward lamplight (warm), used for glows around lamps and lit doorways.
WARM = {
    "K": "x", "Q": "x", "k": "x", "q": "w", "x": "w", "w": "b", "b": "B", "o": "B", "B": "g",
    "g": "Y", "Y": "e", "e": "y", "y": "y", "f": "o", "E": "o", "t": "B", "s": "P", "m": "P",
    "n": "f", "i": "t", "I": "s", "P": "N", "p": "c", "h": "c", "N": "c", "c": "y", "W": "c",
    "S": "c", "r": "R", "d": "R", "R": "c", "j": "l", "J": "P", "G": "l", "l": "g",
}
# One step toward night (cool and dark), used for moonlit or shadowed areas.
COOL = {
    "p": "m", "P": "s", "h": "m", "W": "m", "S": "m", "N": "s", "c": "s", "B": "t", "b": "f",
    "o": "f", "w": "q", "x": "Q", "k": "Q", "K": "K", "q": "Q", "Q": "K", "f": "q", "E": "f",
    "t": "E", "s": "t", "m": "s", "y": "e", "e": "g", "Y": "g", "g": "b", "r": "d", "R": "r",
    "d": "b", "j": "f", "J": "m", "G": "f", "l": "G", "i": "n", "I": "i", "n": "Q",
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def bay(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


# --------------------------------------------------------------------------- canvas


class Cv:
    """Small pixel canvas holding palette letters (None = transparent)."""

    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.a = [[fill] * w for _ in range(h)]

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if self.inside(x, y):
            self.a[y][x] = c

    def get(self, x, y):
        x, y = int(x), int(y)
        if self.inside(x, y):
            return self.a[y][x]
        return None

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def frame(self, x, y, w, h, c):
        self.hl(x, x + w - 1, y, c)
        self.hl(x, x + w - 1, y + h - 1, c)
        self.vl(x, y, y + h - 1, c)
        self.vl(x + w - 1, y, y + h - 1, c)

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

    def ascii(self, rows, x=0, y=0, cmap=None, skip="."):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in skip or ch == " ":
                    continue
                if cmap is not None and ch in cmap:
                    ch = cmap[ch]
                    if ch is None:
                        continue
                self.put(x + i, y + j, ch)

    def map(self, fn, box=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                v = fn(x, y, self.a[y][x])
                if v is not False:
                    self.a[y][x] = v

    def recolor(self, frm, to, box=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                if self.a[y][x] in frm:
                    self.a[y][x] = to

    def tone(self, table, box, level=1.0, only=None):
        """Shift colors one step through table (WARM/COOL/DARK/LIGHT), dithered by level."""
        x0, y0, x1, y1 = box
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                c = self.a[y][x]
                if c is None or (only is not None and c not in only):
                    continue
                if bay(x, y) < level:
                    self.a[y][x] = table.get(c, c)

    def outline(self, c="k", diag=False):
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

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                v = other.a[y][x]
                if v is not None:
                    self.put(ox + x, oy + y, v)

    def flip_x(self):
        self.a = [row[::-1] for row in self.a]

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        for y in range(self.h):
            for x in range(self.w):
                v = self.a[y][x]
                assert v is not None, ("transparent pixel", x, y)
                px[x, y] = COL[v]
        return im


# --------------------------------------------------------------------------- generic helpers


def bands(cv, x, y, w, spec, mix=1):
    """Horizontal color bands top->bottom; the first `mix` rows of each band checker
    with the band above (a light 2-tone dither, not a gradient)."""
    yy = y
    prev = None
    for col, n in spec:
        for k in range(n):
            for xx in range(x, x + w):
                c = col
                if prev is not None and k < mix and (xx + yy) % 2 == 0:
                    c = prev
                cv.put(xx, yy, c)
            yy += 1
        prev = col
    return yy


def glow(cv, cx, cy, r, strength=1.0, table=None, box=None, only=None):
    """Lamplight as flat pools: one tone step inside r, a second step inside an inner
    ring (radius r * 0.45 * strength); 1px checker seams between the rings."""
    table = table or WARM
    x0, y0, x1, y1 = box or (0, 0, cv.w, cv.h)
    inner = 0.45 * strength if strength >= 0.5 else 0.0
    seam = 1.0 / max(1.0, r)
    for y in range(max(y0, int(cy - r) - 1), min(y1, int(cy + r) + 2)):
        for x in range(max(x0, int(cx - r) - 1), min(x1, int(cx + r) + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
            if d >= 1.0:
                continue
            c = cv.a[y][x]
            if c is None or (only is not None and c not in only):
                continue
            n = 2 if d < inner else 1
            if abs(d - inner) < seam and inner > 0:
                n = 2 if (x + y) % 2 == 0 else 1
            elif d > 1.0 - seam:
                n = 1 if (x + y) % 2 == 0 else 0
            for _ in range(n):
                c = table.get(c, c)
            cv.a[y][x] = c


def light_poly(cv, pts, table=None, steps=1, seam=True):
    """Shift every pixel inside a polygon one tone step (window light, moonlight patches);
    the polygon border gets a 1px checker so the patch edge is soft but not noisy."""
    table = table or WARM
    m = Cv(cv.w, cv.h)
    m.poly(pts, "x")
    for y in range(cv.h):
        for x in range(cv.w):
            if m.a[y][x] is None:
                continue
            edge = seam and any(m.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and (x + y) % 2:
                continue
            c = cv.a[y][x]
            for _ in range(steps):
                c = table.get(c, c)
            cv.a[y][x] = c


def shaft(cv, x0, y0, x1, y1, width, level=0.5, table=None):
    """A slanted light shaft from a window: a flat parallelogram one tone lighter."""
    light_poly(cv, [(x0, y0), (x0 + width, y0), (x1 + width, y1), (x1, y1)], table or WARM)


def rain(cv, r, n, col="m", alt="s", length=3, box=None):
    x0, y0, x1, y1 = box or (0, 0, cv.w, cv.h)
    for _ in range(n):
        x = r.randrange(x0, x1)
        y = r.randrange(y0, y1)
        c = col if r.random() < 0.6 else alt
        for k in range(length):
            if y0 <= y + k < y1:
                cv.put(x - k // 2, y + k, c)


def snowfall(cv, r, n, box=None, cols=("W", "h", "S")):
    x0, y0, x1, y1 = box or (0, 0, cv.w, cv.h)
    for _ in range(n):
        cv.put(r.randrange(x0, x1), r.randrange(y0, y1), r.choice(cols))


def snowcap(cv, box, col="W", under=("h",), skip_cols=None):
    """Put snow on the top pixel of every solid run whose upper neighbour is sky-ish."""
    x0, y0, x1, y1 = box
    src = [row[:] for row in cv.a]
    for y in range(max(1, y0), y1):
        for x in range(x0, x1):
            c = src[y][x]
            up = src[y - 1][x]
            if skip_cols and c in skip_cols:
                continue
            if up in under and c not in under:
                cv.put(x, y, col)


def speckle(cv, r, box, cols, n, only=None):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = r.randrange(x0, x1), r.randrange(y0, y1)
        if only is None or cv.get(x, y) in only:
            cv.put(x, y, r.choice(cols))


# --------------------------------------------------------------------------- figures

SKIN = ("c", "N", "P", "B")
SKIN_TAN = ("N", "P", "B", "b")
SKIN_DIM = ("N", "P", "B", "b")       # skin in shadow or at night: one step darker, never brown
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
C_NIGHT = ("t", "f", "q", "Q")        # any cloth in deep shadow
C_RUHUA = ("m", "I", "i", "n")        # Shen Ruhua's blue jacket (walk sprite / portrait)
H_BLACK = "q"
H_GREY = "m"
H_BROWN = "w"

# Medium figure (about 17 px tall), facing right. Rows: hat/head 0..5, body 6..16, feet 17.
# Symbols: a hair, F skin, f skin shade, H hat, G hat dark, Y badge, r knob.
HEADS_M = {
    "bare": ["", ".....aaa", "....aaaaa", "....aaFFF", "....aFFFf", ".....FFf"],
    "old": ["", ".....aaa", "....aaaaa", "....aaFFF", "....aFFFf", ".....FFf"],
    "back": ["", ".....aaa", "....aaaaa", "....aaaaa", "....aaaaa", ".....fff"],
    "front": ["", ".....aaa", "....aaaaa", "....aFFFa", "....FFFFf", ".....fff"],
    "police": ["", "....HHHHH", "....HHHYH", "....GGGGGG", "....aFFFf", ".....FFf"],
    "police_back": ["", "....HHHHH", "....HHHHH", "...GGGGGG", "....aaaaa", ".....fff"],
    "mil": ["", ".....HHH", "....HHHHH", "....HHHHHG", "....aFFFf", ".....FFf"],
    "mil_back": ["", ".....HHH", "....HHHHH", "...GHHHHH", "....aaaaa", ".....fff"],
    "felt": [".....HHH", "....HHHHH", "...GGGGGGG", "....aaFFF", "....aFFFf", ".....FFf"],
    "felt_back": [".....HHH", "....HHHHH", "...GGGGGGG", "....aaaaa", "....aaaaa", ".....fff"],
    "skull": ["......r", ".....HHH", "....HHHHH", "....aaFFF", "....aFFFf", ".....FFf"],
    "skull_back": ["......r", ".....HHH", "....HHHHH", "....aaaaa", "....aaaaa", ".....fff"],
    "straw": ["......H", ".....HHH", "...HHHHHHH", "..GGGGGGGGG", "....aFFFf", ".....FFf"],
    "bun": ["", ".....aaa", "...aaaaaa", "...aaaFFF", "....aFFFf", ".....FFf"],
    "bun_back": ["", ".....aaa", "...aaaaaa", "...aaaaaa", "....aaaaa", ".....fff"],
    "scarf": ["", ".....HHH", "....HHHHH", "....HHFFF", "...HHFFFf", ".....FFf"],
    "scarf_back": ["", ".....HHH", "....HHHHH", "....HHHHH", "...HHHHHH", ".....fff"],
    "cap": ["", ".....HHH", "....HHHHH", "....GGGGGG", "....aFFFf", ".....FFf"],
    "braid": ["", ".....aaa", "....aaaaa", "....aaaaF", "....aFFFf", "....aFFf"],
    "braid_back": ["", ".....aaa", "....aaaaa", "....aaaaa", "....aaaaa", "....aafff"],
}

# bodies, rows 6..17 (12 rows); arms are drawn separately. L light, C base, D dark,
# T bottom base, U bottom dark, S shoe.
BODIES_M = {
    "gown": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCDD", "...LLCCCDD", "....SS.SS",
    ],
    "gown_walk": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....LCCCD", "....LCCCDD", "...LLCCCDD", "...LLCCCDDD", "..LLCC.CCDD", "..SS....SS",
    ],
    "jacket": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....LCCCD", "....TTTTU", "....TT.TU", "....TT.TU", "....TT.TU", "....SS.SS",
    ],
    "jacket_walk": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....LCCCD", "....TTTTU", "...TT..TU", "...TT..TU", "..TT....TU", "..SS....SS",
    ],
    "coat": [  # uniform tunic with belt and trousers
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....GGGGG",
        "....LCCCD", "....TTTTU", "....TT.TU", "....TT.TU", "....TT.TU", "....SS.SS",
    ],
    "coat_walk": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....GGGGG",
        "....LCCCD", "....TTTTU", "...TT..TU", "...TT..TU", "..TT....TU", "..SS....SS",
    ],
    "sit": [  # seated on a low stool, knees forward (stool drawn by the scene)
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....TTTTTUU", "....TTTTTUU", "........TU", "........TU", "........TU", "........SSS",
    ],
    "hug": [  # sitting on the floor, knees drawn up, arms round the knees
        "....LCCCD", "....LCCCDD", "....LCCCDDD", "....LCCTTUF", "....LCTTTU", "...LTTTTTU",
        "...TTTTTUU", "...UUUU.SS",
    ],
    "kneel": [
        "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD", "....LCCCD",
        "....LCCCD", "...LTTTTU", "...TTTTTUU", "...TTTTTUUU", "", "",
    ],
}

# front arm (facing right) as (pixels of sleeve, hand pixel); shoulder near (8, 7).
ARMS_FRONT = {
    "down": ([(8, 7), (9, 7), (8, 8), (9, 8), (9, 9), (9, 10)], (9, 11)),
    "fwd": ([(8, 7), (9, 7), (10, 7), (11, 7), (9, 8), (10, 8), (11, 8)], (12, 7)),
    "hold": ([(8, 7), (9, 7), (9, 8), (9, 9), (10, 9), (11, 9)], (12, 9)),
    "up": ([(8, 7), (9, 7), (9, 6), (10, 6), (10, 5), (10, 4), (11, 4)], (11, 3)),
    "point": ([(8, 7), (9, 7), (9, 6), (10, 6), (11, 5), (12, 5)], (13, 4)),
    "low": ([(8, 7), (9, 7), (9, 8), (10, 9), (10, 10)], (11, 11)),
    "chest": ([(8, 7), (9, 7), (9, 8), (8, 9)], (7, 9)),
    "shoulder": ([(8, 7), (9, 7), (9, 6), (9, 5)], (8, 5)),
    "none": ([], None),
}
ARMS_BACK = {
    "down": ([(4, 7), (3, 7), (3, 8), (3, 9), (3, 10)], (3, 11)),
    "fwd": ([(4, 7), (4, 8), (10, 8), (11, 8)], (12, 8)),
    "up": ([(4, 7), (3, 7), (3, 6), (2, 5), (2, 4)], (2, 3)),
    "hold": ([(4, 7), (3, 7), (3, 8), (3, 9)], (4, 10)),
    "none": ([], None),
}


FOOT_ROW = {"hug": 13, "kneel": 15}


class Fig:
    """A small person built from parts on its own canvas, outlined, then pasted."""

    def __init__(self, hat="bare", body="gown", top=C_INDIGO, bottom=None, skin=SKIN,
                 hair=H_BLACK, hatc=None, arm="down", barm="down", facing="r", armband=None):
        self.c = Cv(20, 22)
        self.ox, self.oy = 3, 2        # template origin on the canvas
        lt, base, dk, dp = top
        bt = bottom or top
        hatc = hatc or top
        cmap = {
            "a": hair, "F": skin[1], "f": skin[2], "H": hatc[1], "G": hatc[2], "Y": "Y",
            "r": "r", "L": lt, "C": base, "D": dk, "T": bt[1], "U": bt[2], "S": "k",
        }
        self.cmap = cmap
        self.top = top
        self.skin = skin
        body_rows = BODIES_M[body]
        # back arm first (behind body)
        pix, hand = ARMS_BACK[barm]
        for x, y in pix:
            self.c.put(self.ox + x, self.oy + y, dk if barm == "fwd" else lt)
        if hand:
            self.c.put(self.ox + hand[0], self.oy + hand[1], skin[2])
        self.c.ascii(body_rows, self.ox, self.oy + 6, cmap)
        self.c.ascii(HEADS_M[hat], self.ox, self.oy, cmap)
        self.head_rows = HEADS_M[hat]
        self.foot = FOOT_ROW.get(body, 17)
        if armband:
            self.c.pts([(self.ox + 4, self.oy + 8), (self.ox + 3, self.oy + 8)], armband)
        pix, hand = ARMS_FRONT[arm]
        for x, y in pix:
            self.c.put(self.ox + x, self.oy + y, dk)
        self.hand = None
        if hand:
            self.c.put(self.ox + hand[0], self.oy + hand[1], skin[1])
            self.hand = (self.ox + hand[0], self.oy + hand[1])
        bh = ARMS_BACK[barm][1]
        self.bhand = (self.ox + bh[0], self.oy + bh[1]) if bh else None
        self.facing = facing

    def at(self, x, y, c):
        """Draw on the figure canvas in template coordinates (facing right)."""
        self.c.put(self.ox + x, self.oy + y, c)

    def item(self, kind, col=None):
        hx, hy = self.hand if self.hand else (self.ox + 9, self.oy + 11)
        c = self.c
        if kind == "paper":
            c.rect(hx, hy - 3, 3, 4, col or "h")
            c.put(hx + 1, hy - 2, "s")
            c.put(hx + 1, hy - 1, "s")
            c.put(hx + 2, hy, "P")
        elif kind == "notice":  # held up, larger sheet with a red seal
            c.rect(hx, hy - 4, 4, 5, col or "h")
            c.vl(hx + 1, hy - 3, hy - 1, "s")
            c.put(hx + 3, hy - 3, "s")
            c.put(hx + 3, hy, "r")
        elif kind == "baton":
            c.vl(hx, hy - 4, hy - 1, col or "b")
        elif kind == "stick":
            c.line(hx, hy + 1, hx + 1, hy + 6, col or "b")
        elif kind == "lantern":
            c.put(hx, hy + 1, "k")
            c.rect(hx - 1, hy + 2, 3, 3, col or "R")
            c.put(hx, hy + 3, "y")
            c.hl(hx - 1, hx + 1, hy + 5, "k")
        elif kind == "ledger":
            c.rect(hx - 1, hy - 2, 3, 3, col or "i")
            c.put(hx, hy - 1, "h")
        elif kind == "bowl":
            c.hl(hx - 1, hx + 1, hy - 1, col or "h")
            c.put(hx, hy, "P")
        elif kind == "coins":
            c.pts([(hx, hy - 1), (hx + 1, hy - 1)], "Y")
        elif kind == "box":
            c.rect(hx - 1, hy - 3, 4, 3, col or "r")
            c.vl(hx + 1, hy - 3, hy - 1, "Y")
        elif kind == "sack":   # on the front shoulder, beside the head
            col = col or "P"
            c.ellipse(self.ox + 10.5, self.oy + 4.5, 3.0, 2.6, col)
            c.pts([(self.ox + 9, self.oy + 3), (self.ox + 10, self.oy + 2)], LIGHT[col])
            c.pts([(self.ox + 12, self.oy + 6), (self.ox + 13, self.oy + 5)], DARK[col])
            c.ascii(self.head_rows, self.ox, self.oy, self.cmap)
        elif kind == "bundle":  # on the back
            c.rect(self.ox + 1, self.oy + 6, 3, 5, col or "i")
            c.put(self.ox + 2, self.oy + 5, col or "i")
            c.put(self.ox + 1, self.oy + 7, "I" if (col or "i") == "i" else LIGHT.get(col, col))
        elif kind == "umbrella":
            c.vl(hx, hy - 7, hy, "w")
            for k in range(5):
                c.hl(hx - 1 - k, hx + 1 + k, hy - 9 + k if k < 3 else hy - 7, col or "B")
            c.hl(hx - 5, hx + 5, hy - 6, DARK.get(col or "B", "b"))
        elif kind == "broom":
            c.line(hx - 2, hy - 4, hx + 1, hy + 3, "B")
            c.pts([(hx + 1, hy + 4), (hx + 2, hy + 4), (hx + 2, hy + 3), (hx + 3, hy + 5)], "g")
        elif kind == "shovel":
            c.line(hx - 1, hy - 4, hx + 1, hy + 4, "b")
            c.rect(hx, hy + 5, 3, 2, "s")
        elif kind == "pole":  # carrying pole across the shoulder with two baskets
            y = self.oy + 6
            c.hl(self.ox - 2, self.ox + 14, y, "B")
            for bx in (self.ox - 2, self.ox + 12):
                c.vl(bx + 1, y + 1, y + 5, "b")
                c.rect(bx - 1, y + 6, 5, 3, col or "g")
                c.hl(bx - 1, bx + 3, y + 6, "Y")
        elif kind == "brush":
            c.vl(hx, hy - 3, hy, "B")
            c.put(hx, hy - 4, "k")
        elif kind == "rope":
            c.rect(hx, hy, 2, 2, "B")
            c.vl(hx + 1, hy + 2, hy + 4, "B")

    def place(self, cv, x, y, outline="k", flip=None):
        """Paste so the template's foot row (row 17, column 6) lands on (x, y)."""
        c = Cv(self.c.w, self.c.h)
        c.a = [row[:] for row in self.c.a]
        if outline:
            c.outline(outline)
        fx = self.ox + 6
        if (flip if flip is not None else self.facing == "l"):
            c.flip_x()
            fx = c.w - 1 - fx
        cv.paste(c, x - fx, y - (self.oy + self.foot))


def ruhua(arm="down", barm="down", body="jacket", back=False, skin=SKIN, top=C_RUHUA, bottom=C_NAVY):
    """Shen Ruhua: bangs, a long braid down her back, blue right-fastening jacket."""
    f = Fig("braid_back" if back else "braid", body, top, bottom, skin, arm=arm, barm=barm)
    c, ox, oy = f.c, f.ox, f.oy
    if back:
        c.vl(ox + 6, oy + 6, oy + 11, "q")
        c.put(ox + 6, oy + 12, "r")
    else:
        c.vl(ox + 4, oy + 6, oy + 10, "q")
        c.put(ox + 4, oy + 11, "r")
        c.line(ox + 6, oy + 6, ox + 8, oy + 8, "h")   # light diagonal fastening
    return f


def tiny(cv, x, y, top="i", head="q", skin="N", facing="r", hat=None, legs=None, outline=None):
    """A distant figure, 3 wide x 8 tall, feet at (x, y)."""
    s = Cv(5, 9)
    s.rect(1, 3, 3, 4, top)
    s.put(3, 3, DARK.get(top, top))
    s.put(3, 4, DARK.get(top, top))
    s.put(3, 5, DARK.get(top, top))
    s.rect(1, 1, 3, 2, head)
    s.put(2, 2, skin)
    s.put(3, 2, skin)
    if hat:
        s.hl(0, 4, 1, hat)
        s.put(2, 0, hat)
    s.put(1, 7, legs or DARK.get(top, top))
    s.put(3, 7, legs or DARK.get(top, top))
    s.put(1, 8, "k")
    s.put(3, 8, "k")
    if facing == "l":
        s.flip_x()
    if outline:
        big = Cv(7, 11)
        big.paste(s, 1, 1)
        big.outline(outline)
        cv.paste(big, x - 3, y - 9)
    else:
        cv.paste(s, x - 2, y - 8)


def crowd(cv, r, x0, x1, y, n, tops=("i", "B", "t", "E", "b", "s"), heads=("q", "q", "f", "w"),
          outline=None, back=True):
    xs = sorted(r.randrange(x0, x1) for _ in range(n))
    for x in xs:
        tiny(cv, x, y + r.choice((0, 0, 1)), top=r.choice(tops), head=r.choice(heads),
             skin=r.choice(heads) if back else "N", outline=outline)


# --------------------------------------------------------------------------- environment


def sky(cv, kind, y1=48):
    if kind == "day":
        bands(cv, 0, 0, W, [("h", 6), ("p", y1 - 6)])
    elif kind == "warm":
        bands(cv, 0, 0, W, [("p", 8), ("N", y1 - 8)])
    elif kind == "grey":
        bands(cv, 0, 0, W, [("s", 5), ("m", 8), ("h", y1 - 13)])
    elif kind == "winter":
        bands(cv, 0, 0, W, [("m", 7), ("h", y1 - 7)])
    elif kind == "dusk":
        bands(cv, 0, 0, W, [("t", 4), ("s", 5), ("P", 6), ("N", y1 - 15)])
    elif kind == "night":
        bands(cv, 0, 0, W, [("Q", 6), ("n", y1 - 6)], mix=2)
    elif kind == "deep":
        bands(cv, 0, 0, W, [("K", 4), ("Q", 8), ("n", y1 - 12)], mix=2)


def moon(cv, x, y, r=3, col="h", dark="m"):
    cv.ellipse(x, y, r, r, col)
    cv.put(int(x + r * 0.3), int(y + r * 0.2), dark)
    cv.put(int(x - r * 0.4), int(y - r * 0.3), "W")


def stars(cv, r, n, box, cols=("m", "s")):
    x0, y0, x1, y1 = box
    for _ in range(n):
        cv.put(r.randrange(x0, x1), r.randrange(y0, y1), r.choice(cols))


def roof(cv, x0, x1, y, h, tile="f", dark="q", eave="Q", ridge="Q", curl=True):
    """Front view of a black-tiled roof: ridge, tile columns, eave line, upturned ends."""
    for yy in range(y, y + h):
        inset = max(0, (y + h - 1 - yy) // 2) if h > 3 else 0
        inset = min(inset, 2)
        for xx in range(x0 + inset, x1 - inset + 1):
            cv.put(xx, yy, dark if (xx % 2 == 0 and yy > y) else tile)
    cv.hl(x0 + 2, x1 - 2, y, ridge)
    cv.hl(x0 - 1, x1 + 1, y + h - 1, eave)
    if curl:
        cv.pts([(x0 - 1, y + h - 2), (x0 - 2, y + h - 3), (x1 + 1, y + h - 2), (x1 + 2, y + h - 3)], eave)
        cv.pts([(x0 + 1, y - 1), (x1 - 1, y - 1)], ridge)


def gable(cv, x, w, ytop, ybot, wall="h", shade="P", cap="Q"):
    """Horse-head wall: whitewashed gable section with a heavy black cap whose outer end
    lifts like a horse's head (front view). Several sections side by side make the steps."""
    cv.rect(x, ytop, w, ybot - ytop, wall)
    cv.vl(x + w - 1, ytop, ybot - 1, shade)
    cv.hl(x - 1, x + w, ytop - 1, "f")
    cv.hl(x - 1, x + w, ytop - 2, cap)
    cv.hl(x, x + w - 1, ytop - 3, cap)
    cv.hl(x, x + w - 1, ytop, shade)
    cv.pts([(x - 2, ytop - 3), (x - 2, ytop - 4), (x + w + 1, ytop - 3), (x + w + 1, ytop - 4)], cap)


def wall(cv, x, y, w, h, base="h", shade="P", stain="P", r=None):
    cv.rect(x, y, w, h, base)
    cv.vl(x + w - 1, y, y + h - 1, shade)
    if r is not None:
        for _ in range(w * h // 40):
            sx, sy = r.randrange(x, x + w), r.randrange(y + h // 2, y + h)
            cv.put(sx, sy, stain)
    # damp line along the bottom
    for xx in range(x, x + w):
        if (xx * 7) % 3 == 0:
            cv.put(xx, y + h - 1, stain)


def planks(cv, x, y, w, h, base="w", seam="x", lit="b", step=3):
    cv.rect(x, y, w, h, base)
    for xx in range(x + step - 1, x + w, step):
        cv.vl(xx, y, y + h - 1, seam)
    cv.vl(x, y, y + h - 1, lit)


def lattice(cv, x, y, w, h, frame="w", fill="P", bar="b", step=2):
    cv.rect(x, y, w, h, fill)
    for xx in range(x, x + w, step):
        cv.vl(xx, y, y + h - 1, bar)
    for yy in range(y, y + h, step):
        cv.hl(x, x + w - 1, yy, bar)
    cv.frame(x - 1, y - 1, w + 2, h + 2, frame)


def ground(cv, y, kind="stone", r=None, y1=48):
    if kind == "stone":
        cv.rect(0, y, W, y1 - y, "t")
        row = 0
        yy = y
        while yy < y1:
            hgt = 2 + row // 2
            cv.hl(0, W - 1, yy, "E")
            off = (row * 5) % 7
            for xx in range(off, W, 7 + row):
                cv.vl(xx, yy, yy + hgt - 1, "E")
            for xx in range(0, W):
                if (xx + row) % 9 == 0:
                    cv.put(xx, yy + 1, "s")
            yy += hgt
            row += 1
    elif kind == "earth":
        cv.rect(0, y, W, y1 - y, "B")
        if r is not None:
            speckle(cv, r, (0, y, W, y1), ("b", "P", "g"), (y1 - y) * 6)
    elif kind == "boards":
        cv.rect(0, y, W, y1 - y, "b")
        yy = y
        k = 0
        while yy < y1:
            cv.hl(0, W - 1, yy, "w")
            for xx in range((k * 11) % 17, W, 17):
                cv.vl(xx, yy, yy + 2, "w")
            yy += 3 + k // 2
            k += 1


def water(cv, y, y1=48, base="i", dark="n", lite="I", r=None, night=False):
    """Calm canal water: flat colour, a dark band under the far bank, short ripple dashes
    that get longer toward the viewer."""
    cv.rect(0, y, W, y1 - y, base)
    cv.hl(0, W - 1, y, dark)
    lite = "i" if night and lite == "I" else lite
    if night:
        lite = "i" if base == "n" else lite
    for yy in range(y + 2, y1, 2):
        k = yy - y
        period = 10 + (yy * 7) % 6
        off = (yy * 13) % period
        ln = 2 + k // 7
        for xx in range(off, W, period):
            cv.hl(xx, xx + ln - 1, yy, lite)
            if k > 6 and (xx // period) % 2:
                cv.hl(xx + 2, xx + ln, yy + 1, dark)


def wupeng(cv, x, y, length=24, facing="r", awning="Q", hull="w", lamp=False):
    """Black-awning canal boat, waterline at y. x is the stern end."""
    s = Cv(length + 4, 10)
    L = length
    # hull: long low shape with raised bow
    s.poly([(0, 6), (L, 6), (L + 2, 4), (L + 3, 4), (L + 1, 8), (2, 8), (0, 7)], hull)
    s.hl(1, L, 6, LIGHT.get(hull, hull))
    s.hl(2, L, 8, DARK.get(hull, hull))
    # awning: arched mat roof in the middle
    ax0, ax1 = L // 4, L * 3 // 4
    for xx in range(ax0, ax1 + 1):
        top = 2 if ax0 + 1 < xx < ax1 - 1 else 3
        s.vl(xx, top, 5, awning)
    s.hl(ax0 + 2, ax1 - 2, 2, LIGHT.get(awning, awning))
    for xx in range(ax0 + 1, ax1, 3):
        s.put(xx, 4, "f")
    if lamp:
        s.vl(L + 1, 0, 3, "k")
        s.put(L + 2, 1, "y")
        s.put(L + 2, 2, "R")
    if facing == "l":
        s.flip_x()
    big = Cv(s.w + 2, s.h + 2)
    big.paste(s, 1, 1)
    big.outline("K" if awning == "Q" else "k")
    cv.paste(big, x - 1, y - 8)


def lantern_red(cv, cx, cy, lit=True, small=False):
    if small:
        cv.put(cx, cy - 2, "k")
        cv.rect(cx - 1, cy - 1, 3, 3, "r")
        cv.put(cx, cy, "y" if lit else "R")
        cv.put(cx - 1, cy - 1, "R")
        cv.hl(cx - 1, cx + 1, cy + 2, "k")
        return
    cv.vl(cx, cy - 4, cy - 3, "k")
    cv.hl(cx - 1, cx + 1, cy - 3, "Y")
    cv.ellipse(cx + 0.5, cy + 0.5, 2.6, 2.6, "r")
    cv.vl(cx, cy - 2, cy + 2, "R" if not lit else "y")
    cv.put(cx - 1, cy - 1, "R")
    cv.put(cx + 2, cy + 1, "d")
    cv.hl(cx - 1, cx + 1, cy + 3, "Y")
    cv.vl(cx, cy + 4, cy + 5, "r")


def notice(cv, x, y, w, h, paper="h", seal=True, lines="s", r=None, edge="P"):
    """A pasted paper notice: blank sheet, abstract stroke columns, a red seal square."""
    cv.rect(x, y, w, h, paper)
    cv.vl(x + w - 1, y, y + h - 1, edge)
    cv.hl(x, x + w - 1, y + h - 1, edge)
    for xx in range(x + w - 3, x + 1, -2):
        ys = y + 2
        ye = y + h - 3
        for yy in range(ys, ye):
            if (yy * 5 + xx * 3) % 7 != 0:
                cv.put(xx, yy, lines)
    if seal:
        cv.rect(x + 1, y + h - 4, 2, 2, "r")
    cv.put(x, y, edge)


def counter(cv, x, y, w, h, top="B", face="w", panel="b", lit="P"):
    """Front of a tall wooden shop counter."""
    cv.rect(x, y, w, h, face)
    cv.hl(x, x + w - 1, y, lit)
    cv.hl(x, x + w - 1, y + 1, top)
    cv.hl(x, x + w - 1, y + 2, "x")
    pw = 9
    for px in range(x + 2, x + w - pw + 1, pw + 2):
        cv.frame(px, y + 4, pw, h - 6, panel)
        cv.hl(px + 1, px + pw - 2, y + 5, "x")


def abacus(cv, x, y, w=11, h=6):
    cv.frame(x, y, w, h, "w")
    cv.rect(x + 1, y + 1, w - 2, h - 2, "x")
    cv.hl(x + 1, x + w - 2, y + 2, "b")
    for xx in range(x + 1, x + w - 1, 2):
        cv.put(xx, y + 1, "B")
        cv.put(xx, y + h - 2, "B")
        cv.put(xx, y + h - 3, "B" if (xx // 2) % 3 else "x")
    cv.hl(x, x + w - 1, y, "b")


def ledger(cv, x, y, w=8, h=5, cover="i", page="h", open_=True):
    if open_:
        cv.rect(x, y, w, h, page)
        cv.vl(x + w // 2, y, y + h - 1, "P")
        for yy in range(y + 1, y + h - 1):
            for xx in range(x + 1, x + w - 1, 2):
                if xx != x + w // 2 and (xx + yy) % 3:
                    cv.put(xx, yy, "s")
        cv.hl(x, x + w - 1, y + h, cover)
    else:
        cv.rect(x, y, w, h, cover)
        cv.hl(x, x + w - 1, y, LIGHT.get(cover, cover))
        cv.vl(x + 1, y + 1, y + h - 1, "h")


def sack(cv, x, y, w=7, h=7, col="P", tie="B", outline="k"):
    s = Cv(w + 2, h + 2)
    s.ellipse(w / 2 + 1, h / 2 + 1.5, w / 2, h / 2, col)
    s.rect(2, h // 2 + 2, w - 2, h // 2, col)
    s.hl(w // 2, w // 2 + 2, 1, tie)
    s.put(w // 2 + 1, 2, tie)
    s.vl(w, 3, h, DARK.get(col, col))
    s.put(2, 3, LIGHT.get(col, col))
    s.put(3, 3, LIGHT.get(col, col))
    if outline:
        s.outline(outline)
    cv.paste(s, x - 1, y - 1)


def stool(cv, x, y, col="b"):
    """Low stool, seat top at y, legs to y+3."""
    cv.hl(x, x + 4, y, col)
    cv.hl(x, x + 4, y + 1, DARK.get(col, col))
    cv.vl(x, y + 2, y + 3, DARK.get(col, col))
    cv.vl(x + 4, y + 2, y + 3, DARK.get(col, col))


def table(cv, x, y, w, col="b", legs=6, cloth=None):
    cv.hl(x, x + w - 1, y, LIGHT.get(col, col))
    cv.hl(x, x + w - 1, y + 1, col)
    cv.hl(x, x + w - 1, y + 2, DARK.get(col, col))
    if cloth:
        cv.rect(x, y + 1, w, legs, cloth)
        cv.vl(x + w - 1, y + 1, y + legs, DARK.get(cloth, cloth))
    else:
        cv.vl(x + 1, y + 3, y + 2 + legs, DARK.get(col, col))
        cv.vl(x + w - 2, y + 3, y + 2 + legs, DARK.get(col, col))


def coins(cv, x, y, n=3):
    for k in range(n):
        cv.hl(x, x + 2, y - k, "Y" if k % 2 == 0 else "g")
        cv.put(x + 2, y - k, "g")
    cv.put(x, y - n + 1, "e")


# --------------------------------------------------------------------------- scenes

SCENES = {}


def scene(art_id):
    def deco(fn):
        SCENES[art_id] = fn
        return fn
    return deco


# --------------------------------------------------------------------------- scene helpers


def house(cv, x0, x1, y_roof, y_ground, kind="shop", night=False, lit=False, roof_h=4,
          window=True, r=None):
    """One street house seen from the front (x0..x1 inclusive)."""
    wallc, wshade = ("t", "E") if night else ("h", "P")
    if night:
        roof(cv, x0, x1, y_roof, roof_h, "q", "Q", "K", "K")
    else:
        roof(cv, x0, x1, y_roof, roof_h)
    top = y_roof + roof_h
    w = x1 - x0 + 1
    if kind == "wall":
        wall(cv, x0, top, w, y_ground - top, wallc, wshade, stain=wshade, r=r)
        cv.hl(x0, x1, top, wshade)
        return top
    mid = top + max(4, (y_ground - top) * 2 // 5)
    wall(cv, x0, top, w, mid - top, wallc, wshade)
    cv.hl(x0, x1, top, wshade)
    if window and w >= 10:
        wx = x0 + w // 2 - 3
        if lit:
            lattice(cv, wx, top + 2, 6, max(2, mid - top - 4), frame="w", fill="e", bar="g")
        else:
            lattice(cv, wx, top + 2, 6, max(2, mid - top - 4), frame="w",
                    fill="E" if night else "P", bar="q" if night else "b")
    cv.hl(x0, x1, mid, "x")
    cv.hl(x0, x1, mid + 1, "b" if not night else "w")
    planks(cv, x0, mid + 2, w, y_ground - mid - 2, base="q" if night else "w",
           seam="K" if night else "x", lit="w" if night else "b")
    return mid


def city_gate(cv, x0, x1, y_wall, y_ground, arch=(24, 40), tower=True, light="m", night=False):
    """Town wall with a gate tower and an arched gateway (front view)."""
    stone, joint, lite = ("E", "f", "t") if night else ("t", "E", "s")
    ax0, ax1 = arch
    cx = (ax0 + ax1) // 2
    cv.rect(x0, y_wall, x1 - x0 + 1, y_ground - y_wall, stone)
    for y in range(y_wall + 2, y_ground, 3):
        cv.hl(x0, x1, y, joint)
        off = 0 if (y // 3) % 2 else 3
        for x in range(x0 + off, x1 + 1, 6):
            cv.vl(x, y - 2, y - 1, joint)
    for x in range(x0, x1 + 1, 4):
        cv.rect(x, y_wall - 2, 2, 2, stone)
        cv.put(x, y_wall - 2, lite)
    cv.hl(x0, x1, y_wall, lite)
    if tower:
        cv.rect(cx - 13, y_wall - 6, 27, 6, "b" if not night else "w")
        for x in range(cx - 12, cx + 13, 4):
            cv.vl(x, y_wall - 6, y_wall - 1, "r" if not night else "b")
        roof(cv, cx - 16, cx + 16, y_wall - 11, 5, *(("q", "Q", "K", "K") if night else ("f", "q", "Q", "Q")))
        cv.hl(cx - 15, cx + 15, y_wall - 1, "Q")
    # the gateway
    aw = ax1 - ax0
    top = y_wall + 6
    cv.ellipse(cx + 0.5, top + aw / 2.0, aw / 2.0, aw / 2.0, "Q")
    cv.rect(ax0, int(top + aw / 2.0), aw + 1, y_ground - int(top + aw / 2.0), "Q")
    cv.rect(cx - 2, y_ground - 7, 5, 7, light)        # daylight at the far end
    cv.rect(cx - 1, y_ground - 8, 3, 1, light)
    for y in range(int(top + aw / 2.0), y_ground):
        cv.put(ax0 - 1, y, lite)
        cv.put(ax1 + 1, y, joint)


def mulberry(cv, x, y, snow=False):
    """A pollarded mulberry stump with bare winter twigs."""
    cv.rect(x, y - 5, 2, 5, "b")
    cv.put(x + 1, y - 5, "w")
    cv.rect(x - 1, y - 7, 4, 2, "b")
    for dx, dy in ((-2, -9), (-1, -10), (1, -10), (3, -9), (4, -8)):
        cv.line(x + 1, y - 7, x + dx, y + dy, "w")
    if snow:
        cv.hl(x - 1, x + 2, y - 8, "W")


def sandbags(cv, x0, x1, y_top, rows):
    """Rows of grey sandbags, running bond."""
    for k in range(rows):
        y = y_top + k * 3
        off = 0 if k % 2 else 3
        for x in range(x0 - off, x1, 6):
            cv.rect(max(x0, x), y, min(5, x1 - max(x0, x)), 3, "m")
            cv.hl(max(x0, x), min(x1 - 1, x + 4), y, "h")
            cv.hl(max(x0, x), min(x1 - 1, x + 4), y + 2, "s")
            cv.put(x + 5, y + 1, "t")


def plaque(cv, x, y, w, h, board="Q", rim="Y"):
    """A blank horizontal name board with a gold rim (nothing written on it)."""
    cv.rect(x, y, w, h, board)
    cv.frame(x, y, w, h, rim)
    cv.frame(x + 1, y + 1, w - 2, h - 2, "g")
    cv.hl(x + 2, x + w - 3, y + 2, "q")


def prize_wheel(cv, cx, cy, rad, cols=("r", "S", "i", "Y", "j", "h"), rim="w", hub="Y", turn=0.0):
    """A painted prize wheel: coloured sectors, dark rim with studs, a hub, pointer on top."""
    n = len(cols)
    for y in range(int(cy - rad) - 1, int(cy + rad) + 2):
        for x in range(int(cx - rad) - 1, int(cx + rad) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > rad:
                continue
            if d > rad - 1.2:
                cv.put(x, y, rim)
                continue
            a = (math.atan2(dy, dx) / (2 * math.pi) + 1.0 + turn) % 1.0
            cv.put(x, y, cols[int(a * n) % n])
    for k in range(8):
        a = 2 * math.pi * k / 8
        cv.put(int(cx + math.cos(a) * (rad - 0.6)), int(cy + math.sin(a) * (rad - 0.6)), "Y")
    cv.ellipse(cx, cy, 1.6, 1.6, hub)
    cv.put(int(cx), int(cy), "k")
    cv.pts([(int(cx) - 1, int(cy - rad) - 2), (int(cx), int(cy - rad) - 2), (int(cx) + 1, int(cy - rad) - 2),
            (int(cx), int(cy - rad) - 1)], "k")


def ticket_piece(cv, pts, x0, y0):
    """One torn piece of an old pawn ticket: cream paper, red ruled border, ink strokes."""
    m = Cv(cv.w, cv.h)
    m.poly(pts, "p")
    for y in range(cv.h):
        for x in range(cv.w):
            if m.a[y][x] is None:
                continue
            lx, ly = x - x0, y - y0
            c = "p"
            if lx in (1, 22) or ly in (1, 30):
                c = "r"
            elif ly == 6 or (ly > 6 and lx in (8, 15)):
                c = "R"
            elif ly < 6 and 6 <= lx <= 16 and ly in (3, 4) and lx % 2 == 0:
                c = "k"
            elif ly > 7 and (lx in (4, 5, 11, 12, 18, 19)) and (ly * 7 + lx * 3) % 5 < 3:
                c = "k" if lx % 7 < 5 else "b"
            elif 23 <= ly <= 27 and 14 <= lx <= 18:
                c = "r"
            cv.put(x, y, c)
    # the torn edge: paper fibre light, shadow under the lower right
    src = [row[:] for row in m.a]
    for y in range(cv.h):
        for x in range(cv.w):
            if src[y][x] is None:
                continue
            if (y + 1 < cv.h and src[y + 1][x] is None) or (x + 1 < cv.w and src[y][x + 1] is None):
                cv.put(x + 1, y + 1, "x")
            if any(src[y + dy][x + dx] is None for dx, dy in ((0, -1), (-1, 0))
                   if 0 <= y + dy < cv.h and 0 <= x + dx < cv.w):
                cv.put(x, y, "W")


def oil_lamp(cv, x, y):
    """Small table oil lamp: glass chimney, flame, brass base (top-left at x, y)."""
    cv.rect(x + 1, y, 3, 1, "g")
    cv.rect(x + 1, y + 1, 3, 4, "c")
    cv.put(x + 2, y + 2, "y")
    cv.put(x + 2, y + 3, "W")
    cv.rect(x, y + 5, 5, 2, "g")
    cv.hl(x, x + 4, y + 7, "Y")


def bridge(cv, x0, x1, y_deck, y_water, col="m", dark="s"):
    """A humped stone bridge with one round arch over the water."""
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    for x in range(x0, x1 + 1):
        t = (x - cx) / half
        top = int(round(y_deck - 4 * (1 - t * t)))
        cv.vl(x, top, y_water, col)
        cv.put(x, top, "h")
    rad = (y_water - y_deck) + 2
    cv.ellipse(cx, y_water + 0.5, rad * 0.8, rad, "Q", test=lambda x, y, d: y <= y_water)
    for x in range(x0, x1 + 1, 3):
        cv.put(x, y_deck - 1 + (x % 2), dark)


def willow(cv, x, y, h, leaf="l", dark="G", bare=False, lean=0.0):
    """Willow: trunk and hanging strands; lean > 0 blows the strands to the right."""
    cv.vl(x, y - h, y, "b")
    cv.vl(x + 1, y - h + 2, y, "w")
    for k, dx in enumerate((-6, -4, -2, 0, 2, 4, 6)):
        top = y - h + abs(dx) // 2
        for yy in range(top, top + h // 2 + (k % 3) * 2):
            xx = x + dx + (yy - top) // 5 + int((yy - top) * lean)
            if bare:
                if yy % 2 == 0:
                    cv.put(xx, yy, "b")
            else:
                cv.put(xx, yy, leaf if (yy + k) % 3 else dark)


def plum_vase(cv, x, y):
    """A small vase with a sprig of winter plum blossom."""
    cv.rect(x, y, 4, 5, "i")
    cv.hl(x + 1, x + 2, y - 1, "i")
    cv.vl(x + 3, y, y + 4, "n")
    cv.put(x, y + 1, "I")
    cv.line(x + 2, y - 1, x - 2, y - 7, "w")
    cv.line(x + 1, y - 3, x + 5, y - 8, "w")
    for px, py in ((x - 2, y - 7), (x - 1, y - 5), (x + 4, y - 7), (x + 5, y - 8), (x + 3, y - 5), (x, y - 8)):
        cv.put(px, py, "R")
    cv.put(x - 2, y - 8, "c")
    cv.put(x + 5, y - 9, "c")


def cash_box(cv, x, y, w=16, h=7):
    cv.rect(x, y, w, h, "b")
    cv.frame(x, y, w, h, "w")
    cv.rect(x + 1, y + 1, w - 2, 3, "x")
    for k in range(x + 2, x + w - 2, 3):
        cv.hl(k, k + 1, y + 2, "Y")
        cv.put(k, y + 1, "e")
    cv.rect(x - 1, y - 5, w + 2, 5, "B")    # lid standing open
    cv.hl(x - 1, x + w, y - 5, "P")
    cv.rect(x + w // 2 - 1, y + 4, 2, 2, "Y")


# --------------------------------------------------------------------------- estates


@scene("illus.es.counter")
def es_counter(cv, r):
    # back wall of dark boards with a shelf of wrapped pledges
    cv.rect(0, 0, W, 25, "w")
    for x in range(3, W, 7):
        cv.vl(x, 2, 24, "x")
    cv.rect(0, 0, W, 2, "x")
    for sy in (10, 20):
        x = 1 + (sy % 4)
        while x < W - 3:
            w = r.choice((4, 5, 6, 7))
            h = r.choice((4, 5, 6))
            col = r.choice(("i", "B", "P", "b", "j", "s", "i", "B"))
            cv.rect(x, sy - h, w, h, col)
            cv.hl(x, x + w - 1, sy - h, LIGHT[col])
            cv.vl(x + w - 1, sy - h + 1, sy - 1, DARK[col])
            if r.random() < 0.6:
                cv.vl(x + w // 2, sy - h, sy - 1, DARK[col])
                cv.put(x + w // 2, sy - h + 1, "h")
            x += w + r.choice((0, 1, 1, 2))
        cv.hl(0, W - 1, sy, "B")
        cv.hl(0, W - 1, sy + 1, "x")
    # counter top seen from the customer's side
    cv.rect(0, 25, W, 6, "B")
    cv.hl(0, W - 1, 25, "b")
    cv.hl(0, W - 1, 30, "P")
    for x in range(5, W, 13):
        cv.hl(x, x + 4, 27, "g")
    cv.rect(0, 31, W, 17, "w")
    cv.hl(0, W - 1, 31, "x")
    for px in range(2, W - 8, 12):
        cv.frame(px, 33, 10, 13, "b")
        cv.hl(px + 1, px + 8, 34, "x")
        cv.vl(px + 1, 34, 44, "x")
    # abacus, open ledger, brush, red seal box, coins
    cv.rect(14, 22, 18, 7, "w")
    cv.frame(14, 22, 18, 7, "k")
    cv.rect(15, 23, 16, 5, "x")
    cv.hl(15, 30, 24, "b")
    for x in range(16, 30, 2):
        cv.put(x, 23, "P")
        cv.put(x, 26, "P" if (x // 2) % 3 else "x")
        cv.put(x, 27, "B")
    cv.hl(14, 31, 22, "b")
    ledger(cv, 36, 25, 12, 4)
    cv.line(46, 22, 50, 26, "k")
    cv.put(50, 26, "B")
    cv.rect(53, 25, 4, 3, "r")
    cv.hl(53, 56, 25, "R")
    coins(cv, 7, 28, 3)
    coins(cv, 10, 28, 2)
    # hanging oil lamp, upper left
    cv.vl(8, 0, 2, "k")
    cv.rect(6, 3, 5, 1, "g")
    cv.rect(7, 4, 3, 3, "c")
    cv.put(8, 5, "y")
    cv.rect(6, 7, 5, 1, "g")
    cv.put(8, 5, "W")


@scene("illus.es.jewel_cabinet")
def es_jewel_cabinet(cv, r):
    # plaster wall over a wooden wainscot, dark floor
    cv.rect(0, 0, W, 30, "P")
    for _ in range(14):
        cv.put(r.randrange(0, W), r.randrange(0, 30), "B")
    cv.rect(0, 30, W, 12, "b")
    cv.hl(0, W - 1, 30, "w")
    for x in range(4, W, 9):
        cv.frame(x, 32, 7, 8, "w")
    cv.rect(0, 42, W, 6, "w")
    cv.hl(0, W - 1, 42, "x")
    # the cabinet
    x0, x1 = 17, 46
    cv.rect(x0 - 2, 3, x1 - x0 + 5, 3, "x")
    cv.hl(x0 - 2, x1 + 2, 3, "b")
    cv.rect(x0, 6, x1 - x0 + 1, 38, "w")
    cv.vl(x0, 6, 43, "b")
    cv.vl(x1, 6, 43, "x")
    # glass doors
    gx0, gx1, gy0, gy1 = x0 + 2, x1 - 2, 8, 27
    cv.rect(gx0, gy0, gx1 - gx0 + 1, gy1 - gy0 + 1, "n")
    cv.vl((gx0 + gx1) // 2, gy0, gy1, "w")
    cv.vl((gx0 + gx1) // 2 + 1, gy0, gy1, "x")
    for sy in (14, 20, 27):
        cv.hl(gx0, gx1, sy, "b")
    # treasures on the shelves
    def bangle(x, y, c, d):
        cv.pts([(x + 1, y), (x + 2, y), (x, y + 1), (x + 3, y + 1), (x + 1, y + 2), (x + 2, y + 2)], c)
        cv.put(x + 3, y + 1, d)
    bangle(gx0 + 1, 11, "Y", "g")
    bangle(gx0 + 6, 11, "J", "j")
    cv.rect(gx1 - 5, 11, 4, 3, "Y")          # gold ingot
    cv.hl(gx1 - 6, gx1 - 1, 12, "e")
    cv.hl(gx1 - 5, gx1 - 2, 11, "y")
    cv.pts([(gx0 + 2, 17), (gx0 + 3, 18), (gx0 + 4, 18), (gx0 + 5, 18), (gx0 + 6, 17)], "h")  # pearls
    cv.pts([(gx0 + 2, 17), (gx0 + 4, 18), (gx0 + 6, 17)], "W")
    cv.rect(gx0 + 8, 17, 2, 3, "j")          # jade pendant
    cv.put(gx0 + 8, 16, "Y")
    cv.rect(gx1 - 6, 16, 2, 4, "m")          # silver hairpins
    cv.vl(gx1 - 3, 15, 19, "h")
    cv.put(gx1 - 3, 15, "r")
    cv.vl(gx1 - 1, 16, 19, "Y")
    bangle(gx0 + 2, 23, "m", "s")
    cv.rect(gx1 - 7, 23, 4, 4, "r")          # small lacquer box
    cv.hl(gx1 - 7, gx1 - 4, 23, "R")
    cv.put(gx1 - 6, 25, "Y")
    cv.pts([(gx0 + 9, 24), (gx0 + 10, 25), (gx0 + 9, 26)], "e")
    # glass glints
    for k in range(5):
        cv.put(gx0 + 1 + k, gy0 + 6 - k, "m")
        cv.put(gx1 - 4 + k // 2, gy0 + 12 - k, "i")
    # brass lock between the doors
    cv.rect((gx0 + gx1) // 2 - 1, 17, 3, 3, "Y")
    cv.put((gx0 + gx1) // 2, 19, "k")
    # drawers below
    for k, dy in enumerate((29, 34, 39)):
        cv.frame(x0 + 2, dy, x1 - x0 - 3, 5, "x")
        cv.hl(x0 + 3, x1 - 2, dy + 1, "b")
        cv.pts([((x0 + x1) // 2, dy + 2), ((x0 + x1) // 2 + 1, dy + 2)], "Y")
    cv.rect(x0, 44, 2, 2, "x")
    cv.rect(x1 - 1, 44, 2, 2, "x")
    # cast shadow right of the cabinet
    cv.tone(DARK, (x1 + 1, 6, x1 + 4, 42), 1.0)


@scene("illus.es.old_house")
def es_old_house(cv, r):
    sky(cv, "warm")
    for x in range(0, W, 6):
        cv.ellipse(x + 3, 26, 4, 3, "J")
    # stepped horse-head gables either side, roof between
    gable(cv, 2, 6, 16, 43)
    gable(cv, 8, 6, 8, 43)
    gable(cv, 50, 6, 8, 43)
    gable(cv, 56, 6, 16, 43)
    roof(cv, 15, 48, 12, 5)
    wall(cv, 14, 17, 36, 26, "h", "P", r=r)
    cv.hl(14, 49, 17, "P")
    lattice(cv, 18, 20, 6, 4, frame="w", fill="P", bar="b")
    lattice(cv, 40, 20, 6, 4, frame="w", fill="P", bar="b")
    # stone gate frame, little roof, wooden doors
    cv.rect(25, 26, 14, 17, "m")
    cv.hl(25, 38, 26, "s")
    roof(cv, 23, 40, 22, 3)
    cv.rect(27, 28, 10, 15, "w")
    cv.vl(31, 28, 42, "x")
    cv.vl(32, 28, 42, "k")
    cv.vl(27, 28, 42, "b")
    for x in (29, 34):
        for y in range(30, 42, 3):
            cv.put(x, y, "g")
    cv.pts([(30, 35), (33, 35)], "Y")
    cv.pts([(30, 36), (33, 36)], "g")
    cv.rect(25, 28, 1, 12, "d")              # faded couplet strips, blank
    cv.rect(38, 28, 1, 12, "d")
    lantern_red(cv, 21, 25, lit=False, small=True)
    lantern_red(cv, 43, 25, lit=False, small=True)
    cv.rect(22, 43, 20, 1, "s")
    ground(cv, 44, "stone")
    cv.tone(DARK, (49, 17, 50, 43), 1.0)


@scene("illus.es.storeroom")
def es_storeroom(cv, r):
    planks(cv, 0, 0, W, 40, base="w", seam="x", lit="w", step=5)
    cv.rect(0, 0, W, 2, "x")
    # small high window with daylight
    lattice(cv, 28, 4, 8, 5, frame="x", fill="p", bar="P")
    shaft(cv, 28, 9, 38, 40, 9, 0.55)
    # racks left and right
    for rx0, rx1 in ((1, 21), (43, 62)):
        cv.vl(rx0, 4, 41, "b")
        cv.vl(rx1, 4, 41, "x")
        for sy in (13, 23, 33):
            cv.hl(rx0, rx1, sy, "B")
            cv.hl(rx0, rx1, sy + 1, "x")
            x = rx0 + 1
            while x < rx1 - 2:
                kind = r.random()
                if kind < 0.5:   # cloth bundle tied with string, paper tag
                    w = r.choice((5, 6))
                    h = r.choice((5, 6, 7))
                    col = r.choice(("i", "B", "j", "s", "b"))
                    cv.rect(x, sy - h, min(w, rx1 - x), h, col)
                    cv.hl(x, x + w - 1, sy - h, LIGHT[col])
                    cv.vl(x + w // 2, sy - h, sy - 1, "P")
                    cv.put(x + w // 2 + 1, sy - h + 2, "h")
                elif kind < 0.75:  # porcelain jar
                    w = 4
                    cv.rect(x, sy - 6, 4, 6, "h")
                    cv.hl(x + 1, x + 2, sy - 7, "h")
                    cv.vl(x + 3, sy - 6, sy - 1, "m")
                    cv.hl(x, x + 3, sy - 4, "i")
                else:            # wooden box
                    w = 6
                    cv.rect(x, sy - 4, 6, 4, "B")
                    cv.hl(x, x + 5, sy - 4, "P")
                    cv.vl(x + 5, sy - 3, sy - 1, "b")
                    cv.put(x + 2, sy - 2, "Y")
                x += w + 1
    # floor and a chest in the middle
    ground(cv, 41, "boards")
    cv.rect(24, 32, 16, 10, "b")
    cv.rect(24, 32, 16, 2, "B")
    cv.hl(24, 39, 32, "P")
    cv.vl(39, 33, 41, "w")
    cv.frame(24, 32, 16, 10, "k")
    cv.rect(30, 35, 3, 3, "Y")
    cv.put(31, 36, "k")
    cv.vl(27, 34, 40, "g")
    cv.vl(36, 34, 40, "g")
    # dust in the light
    for _ in range(10):
        x, y = r.randrange(30, 44), r.randrange(12, 34)
        cv.put(x, y, "P")


# --------------------------------------------------------------------------- events 1938 (third month)


@scene("illus.ev.1938.dock_night")
def ev_dock_night(cv, r):
    sky(cv, "deep", 22)
    stars(cv, r, 9, (0, 0, 64, 12))
    moon(cv, 52, 6, 3)
    for x0, x1, y in ((0, 14, 15), (15, 30, 13), (31, 40, 16), (41, 63, 14)):
        cv.rect(x0, y, x1 - x0 + 1, 22 - y, "Q")
        cv.hl(x0 - 1, x1 + 1, y, "K")
    cv.pts([(8, 18), (9, 18), (35, 19), (52, 18), (53, 18)], "g")
    water(cv, 22, base="n", dark="Q", lite="i")
    for y in range(24, 36, 2):
        cv.hl(51 + (y % 3), 52 + (y % 3), y, "s")
    # wooden pier on the right
    cv.rect(38, 36, 26, 3, "b")
    cv.hl(38, 63, 36, "B")
    cv.rect(38, 39, 26, 9, "w")
    for x in range(40, 64, 6):
        cv.vl(x, 39, 47, "x")
    for x in (39, 51, 62):
        cv.rect(x, 31, 2, 6, "x")
        cv.put(x, 31, "b")
    # the boat with a bow lamp and its reflection
    wupeng(cv, 1, 37, 24, lamp=True)
    for y in range(38, 46, 2):
        cv.hl(25, 27, y, "g" if y < 42 else "b")
    # gangplank from boat to pier, a porter on it, another on the pier
    cv.line(22, 32, 38, 36, "B")
    cv.line(22, 33, 38, 37, "b")
    p2 = Fig("bare", "jacket_walk", C_DKGREY, C_NIGHT, SKIN_DIM, arm="shoulder", barm="down")
    p2.item("sack", "P")
    p2.place(cv, 31, 35, outline="K")
    p1 = Fig("straw", "jacket", C_GREY, C_NIGHT, SKIN_DIM, hatc=C_BROWN, arm="shoulder", barm="down")
    p1.item("sack", "B")
    p1.place(cv, 52, 37, outline="K")
    cv.vl(62, 26, 30, "x")
    lantern_red(cv, 62, 29, lit=True, small=True)
    sack(cv, 43, 31, 6, 5, "P", outline="K")


@scene("illus.ev.1938.levy_call")
def ev_levy_call(cv, r):
    sky(cv, "day", 8)
    # white wall on the left, shop door planks on the right
    roof(cv, -2, 22, 2, 4)
    wall(cv, 0, 6, 22, 36, "h", "P", r=r)
    roof(cv, 22, 66, 0, 4)
    cv.rect(22, 4, 42, 3, "x")
    planks(cv, 22, 7, 42, 35, base="w", seam="x", lit="b", step=4)
    cv.vl(22, 4, 41, "k")
    # the posted levy sheet, big and pale, with a red seal
    notice(cv, 33, 11, 16, 20, paper="S", lines="t")
    cv.rect(44, 25, 3, 3, "r")
    cv.put(45, 26, "R")
    # paste marks
    cv.pts([(33, 11), (48, 11), (33, 30), (48, 30)], "P")
    ground(cv, 42, "stone")
    # Ruhua reading it, the committee man who pasted it leaving with his brush
    keeper = ruhua(arm="down", barm="down", back=True)
    keeper.place(cv, 27, 45)
    man = Fig("felt", "gown_walk", C_BLACK, hatc=C_BLACK, arm="hold", barm="down", armband="r")
    man.item("brush")
    man.place(cv, 8, 44, flip=True)


@scene("illus.ev.1938.night_patrol")
def ev_night_patrol(cv, r):
    sky(cv, "night", 16)
    stars(cv, r, 6, (0, 0, 64, 8))
    moon(cv, 9, 5, 2)
    house(cv, -3, 22, 8, 40, kind="shop", night=True)
    house(cv, 23, 66, 6, 40, kind="wall", night=True, r=r)
    # a lit lattice window the patrol is knocking at
    lattice(cv, 40, 17, 10, 8, frame="x", fill="e", bar="g")
    cv.rect(40, 20, 10, 1, "g")
    light_poly(cv, [(39, 26), (51, 26), (55, 40), (37, 40)], WARM)
    cv.rect(0, 40, W, 8, "f")
    for x in range(0, W, 6):
        cv.vl(x, 41, 47, "q")
    cv.hl(0, W - 1, 40, "E")
    # patrolman raises his baton at the shutter, the other holds the lantern
    p = Fig("police", "coat", C_NAVY, C_NAVY, SKIN_DIM, hatc=C_NAVY, arm="up", barm="down")
    p.item("baton", "B")
    p.place(cv, 36, 44, outline="K")
    q = Fig("felt", "gown", C_NIGHT, skin=SKIN_DIM, hatc=C_NIGHT, arm="hold", barm="down", armband="r")
    q.item("lantern")
    q.place(cv, 20, 45, outline="K")
    glow(cv, 27.5, 39.5, 7, 0.4)


@scene("illus.ev.1938.police_check")
def ev_police_check(cv, r):
    sky(cv, "day", 8)
    house(cv, -2, 26, 3, 36, kind="shop")
    house(cv, 27, 66, 1, 36, kind="shop")
    ground(cv, 36, "stone")
    # Ruhua with her papers out, policeman inspecting, committee man with the roll behind
    civ = ruhua(arm="fwd", barm="down")
    civ.item("paper", "S")
    civ.place(cv, 24, 45)
    pol = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="fwd", barm="down")
    pol.place(cv, 40, 45, flip=True)
    com = Fig("felt", "gown", C_BLACK, hatc=C_BLACK, arm="hold", barm="down", armband="r")
    com.item("ledger", "b")
    com.place(cv, 53, 42, flip=True)


@scene("illus.ev.1938.police_open")
def ev_police_open(cv, r):
    sky(cv, "grey", 20)
    # the station: grey brick front, dark gateway, blank board on the post
    cv.rect(6, 8, 52, 30, "t")
    for y in range(9, 38, 3):
        off = 0 if (y // 3) % 2 else 2
        for x in range(6 + off, 58, 5):
            cv.put(x, y, "E")
        cv.hl(6, 57, y + 2, "E")
    cv.rect(4, 5, 56, 3, "f")
    cv.hl(4, 59, 5, "E")
    cv.hl(3, 60, 7, "q")
    cv.rect(24, 16, 16, 22, "Q")
    cv.rect(22, 14, 20, 2, "E")
    cv.vl(24, 16, 37, "f")
    cv.rect(17, 15, 4, 16, "S")          # blank name board, nothing written
    cv.frame(17, 15, 4, 16, "k")
    cv.rect(10, 18, 5, 7, "n")
    cv.frame(10, 18, 5, 7, "q")
    cv.rect(49, 18, 5, 7, "n")
    cv.frame(49, 18, 5, 7, "q")
    # opening day: red silk swag with a knot over the gate
    for x in range(22, 42):
        cv.put(x, 15 + (1 if 26 <= x <= 37 else 0) + (1 if 29 <= x <= 34 else 0), "r")
    cv.ellipse(32, 17.5, 2.2, 2, "R")
    cv.put(31, 17, "c")
    cv.pts([(30, 20), (30, 21), (34, 20), (34, 21)], "r")
    cv.rect(0, 38, W, 10, "s")
    cv.hl(0, W - 1, 38, "m")
    cv.rect(20, 37, 24, 2, "m")
    guard = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="down", barm="down")
    guard.place(cv, 38, 37)
    # shopkeepers called to come and look, seen from behind
    for x, top, hat in ((6, C_INDIGO, "skull_back"), (16, C_BROWN, "back"), (46, C_DKGREY, "felt_back"),
                        (57, C_JADE, "back")):
        f = Fig(hat, "gown", top, hatc=C_BLACK, arm="down", barm="down")
        f.place(cv, x, 52)


@scene("illus.ev.1938.puppet_roll")
def ev_puppet_roll(cv, r):
    cv.rect(0, 0, W, 34, "P")
    cv.rect(0, 0, W, 2, "w")
    for x in (0, 62):
        cv.rect(x, 0, 2, 34, "b")
    # long blank banner across the back wall
    cv.rect(8, 4, 48, 6, "h")
    cv.frame(8, 4, 48, 6, "r")
    cv.hl(9, 54, 9, "d")
    # table with a cloth, the man reading out the roll behind it
    reader = Fig("front", "gown", C_BLACK, arm="fwd", barm="fwd")
    reader.place(cv, 32, 34)
    cv.rect(35, 15, 9, 9, "S")           # the unrolled list he holds
    for yy in range(16, 23):
        cv.hl(36, 42, yy, "s" if yy % 2 else "S")
    cv.hl(35, 43, 15, "P")
    cv.rect(18, 26, 30, 3, "B")
    cv.hl(18, 47, 26, "P")
    cv.rect(18, 28, 30, 6, "i")
    cv.vl(47, 28, 33, "n")
    cv.rect(0, 34, W, 14, "b")
    cv.hl(0, W - 1, 34, "w")
    # rows of shopkeepers, seen from behind
    for x, top, hat in ((4, C_INDIGO, "skull_back"), (14, C_BROWN, "back"), (24, C_DKGREY, "felt_back"),
                        (36, C_INDIGO, "back"), (46, C_JADE, "skull_back"), (57, C_BROWN, "felt_back")):
        f = Fig(hat, "gown", top, hatc=C_BLACK, arm="down", barm="down")
        f.place(cv, x, 55)


@scene("illus.ev.1938.refugee_door")
def ev_refugee_door(cv, r):
    sky(cv, "dusk", 10)
    wall(cv, 0, 6, 64, 36, "s", "t", stain="t", r=r)
    cv.hl(0, 63, 6, "t")
    roof(cv, -3, 66, 2, 4, "f", "q", "Q", "Q")
    cv.rect(0, 42, W, 6, "E")
    cv.hl(0, W - 1, 42, "t")
    # the back door, ajar, warm light inside
    cv.rect(41, 13, 14, 29, "x")
    cv.rect(43, 15, 10, 27, "c")
    cv.rect(43, 15, 10, 4, "N")
    cv.rect(47, 15, 6, 27, "w")          # door leaf swung partly open
    cv.vl(47, 15, 41, "b")
    for y in range(18, 40, 5):
        cv.hl(48, 52, y, "x")
    cv.rect(41, 41, 14, 1, "f")
    # light spilling on the ground
    cv.poly([(43, 42), (47, 42), (40, 48), (30, 48)], "P")
    # the refugee with bowl and bundle, a child at her side
    ref = Fig("scarf", "jacket", C_GREY, C_DKGREY, hatc=C_BROWN, arm="fwd", barm="down")
    ref.item("bundle", "B")
    ref.item("bowl")
    ref.at(5, 9, "t")
    ref.at(6, 12, "B")
    ref.place(cv, 31, 45)
    tiny(cv, 20, 45, top="B", head="q", skin="N", outline="k")


@scene("illus.ev.1938.rice_line")
def ev_rice_line(cv, r):
    sky(cv, "day", 10)
    house(cv, -3, 30, 4, 38, kind="wall", r=r)
    # the rice shop, open front, sacks inside
    roof(cv, 31, 66, 1, 5)
    cv.rect(31, 6, 33, 32, "x")
    cv.rect(31, 6, 33, 2, "b")
    cv.rect(46, 8, 5, 11, "S")           # hanging shop board, blank
    cv.frame(46, 8, 5, 11, "k")
    for sx, sy in ((34, 22), (41, 23), (52, 22), (58, 23), (37, 17), (55, 17)):
        sack(cv, sx, sy, 6, 6, "P")
    counter(cv, 31, 30, 33, 8, top="B", face="b", panel="w")
    clerk = Fig("front", "gown", C_TAN, arm="down", barm="down")
    clerk.place(cv, 47, 40)
    counter(cv, 31, 30, 33, 8, top="B", face="b", panel="w")
    ground(cv, 38, "stone")
    # the queue, each with a bag or basket
    tops = [C_INDIGO, C_BROWN, C_GREY, C_JADE, C_DKBROWN]
    hats = ["bun_back", "skull", "bare", "scarf", "felt"]
    for k, x in enumerate((5, 12, 19, 26)):
        f = Fig(hats[k], "gown" if k % 2 else "jacket", tops[k], hatc=C_BLACK if k != 3 else C_BROWN,
                arm="hold" if k else "down", barm="down")
        if k:
            f.item("bowl" if k == 2 else "box", "B" if k != 2 else None)
        f.place(cv, x, 46 - (k % 2))
    first = Fig("bare", "jacket", C_DKGREY, C_INDIGO, arm="fwd", barm="down")
    first.item("coins")
    first.place(cv, 34, 46)


@scene("illus.ev.1938.road_pass")
def ev_road_pass(cv, r):
    sky(cv, "day", 20)
    # distant town wall and trees
    cv.rect(0, 15, 64, 5, "s")
    cv.hl(0, 63, 15, "t")
    for x in range(1, 64, 4):
        cv.put(x, 14, "t")
    for x in (4, 12, 50, 58):
        cv.ellipse(x, 15, 4, 3, "G")
        cv.ellipse(x - 1, 14, 2, 2, "l")
    # fields
    cv.rect(0, 20, 64, 28, "l")
    for y in range(21, 48, 3):
        cv.hl(0, 63, y, "G")
    # the road narrowing to the horizon
    cv.poly([(28, 20), (36, 20), (60, 48), (4, 48)], "P")
    for y in range(22, 48, 4):
        cv.put(32 + (y % 5) - 2, y, "B")
    # sentry hut
    cv.rect(46, 20, 11, 14, "B")
    cv.vl(56, 20, 33, "b")
    cv.rect(45, 17, 13, 3, "f")
    cv.hl(44, 58, 19, "Q")
    cv.rect(49, 24, 4, 4, "x")
    # barrier pole across the road on a trestle
    cv.line(10, 27, 12, 33, "b")
    cv.line(14, 27, 12, 33, "b")
    cv.hl(8, 46, 28, "h")
    cv.hl(8, 46, 29, "P")
    for x in range(10, 46, 6):
        cv.hl(x, x + 2, 28, "r")
        cv.hl(x, x + 2, 29, "d")
    # soldier stops a traveller
    sol = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="fwd", barm="down")
    sol.place(cv, 42, 43, flip=True)
    tr = Fig("bare", "jacket", C_BROWN, C_DKGREY, arm="fwd", barm="down")
    tr.item("bundle", "i")
    tr.item("paper", "S")
    tr.place(cv, 25, 45)


@scene("illus.ev.1938.wharf_due")
def ev_wharf_due(cv, r):
    sky(cv, "day", 8)
    for x0, x1, y in ((0, 20, 4), (21, 40, 3), (41, 63, 5)):
        roof(cv, x0, x1, y, 3)
        wall(cv, x0, y + 3, x1 - x0 + 1, 9 - y, "h", "P")
    water(cv, 10, 30)
    wupeng(cv, 2, 24, 22)
    wupeng(cv, 38, 21, 18, facing="l")
    # stone wharf steps
    for k, y in enumerate(range(28, 48, 4)):
        cv.rect(0, y, W, 4, "m" if k % 2 == 0 else "s")
        cv.hl(0, W - 1, y, "h" if k % 2 == 0 else "m")
        for x in range((k * 7) % 11, W, 11):
            cv.vl(x, y + 1, y + 3, "t")
    # the collector at his little table, a boatman paying
    col = Fig("felt", "gown", C_BLACK, hatc=C_BLACK, arm="hold", barm="down", armband="r")
    col.place(cv, 50, 43, flip=True)
    table(cv, 36, 35, 12, "b", legs=8)
    ledger(cv, 37, 32, 6, 3)
    cv.rect(44, 31, 4, 4, "w")
    cv.hl(44, 47, 31, "b")
    coins(cv, 45, 30, 2)
    bt = Fig("straw", "jacket", C_INDIGO, C_DKGREY, hatc=C_TAN, arm="fwd", barm="down")
    bt.item("coins")
    bt.place(cv, 26, 46)


# --------------------------------------------------------------------------- events 1939 (twelfth month, winter)


@scene("illus.ev.1939.charcoal_spike")
def ev_charcoal_spike(cv, r):
    # a cold kitchen in the twelfth month
    cv.rect(0, 0, W, 36, "t")
    speckle(cv, r, (0, 0, W, 36), ("E", "s"), 30)
    cv.rect(0, 36, W, 12, "E")
    cv.hl(0, W - 1, 36, "f")
    lattice(cv, 44, 5, 13, 9, frame="w", fill="m", bar="E", step=3)
    for _ in range(9):
        cv.put(r.randrange(44, 57), r.randrange(5, 14), "W")
    # clay stove with an iron pot, chimney, nearly dead fire
    cv.rect(3, 24, 26, 15, "P")
    cv.rect(3, 22, 26, 2, "s")
    cv.hl(3, 28, 22, "m")
    cv.vl(28, 24, 38, "B")
    cv.rect(4, 2, 4, 20, "P")
    cv.vl(7, 2, 21, "B")
    cv.ellipse(17, 22, 6, 2.2, "q")
    cv.hl(13, 21, 21, "E")
    cv.rect(12, 30, 8, 7, "K")
    cv.frame(11, 29, 10, 8, "B")
    cv.pts([(14, 36), (15, 35), (16, 36), (17, 36)], "R")
    cv.pts([(15, 36), (16, 35)], "d")
    glow(cv, 16, 35, 5, 0.4)
    # empty firewood corner: two sticks left
    cv.rect(46, 31, 14, 8, "f")
    cv.frame(46, 31, 14, 8, "q")
    cv.line(48, 37, 56, 36, "B")
    cv.line(49, 38, 55, 38, "b")
    # Ruhua on a stool, holding her hands to the embers
    f = ruhua(arm="fwd", barm="fwd", body="sit", top=("s", "i", "n", "Q"))
    f.place(cv, 33, 45, flip=True)
    stool(cv, 32, 42, "b")


@scene("illus.ev.1939.cocoon_desk")
def ev_cocoon_desk(cv, r):
    cv.rect(0, 0, W, 30, "P")
    cv.rect(0, 30, W, 18, "b")
    cv.hl(0, W - 1, 30, "w")
    # racks of cocoon trays on the left
    cv.vl(2, 2, 40, "w")
    cv.vl(27, 2, 40, "w")
    for ty in (10, 19, 28):
        cv.hl(2, 27, ty + 1, "w")
        cv.ellipse(14.5, ty, 11, 1.6, "B")
        cv.hl(5, 24, ty - 1, "P")
        for k in range(18):
            x = 5 + (k * 7) % 20
            y = ty - 2 - (k % 2)
            cv.pts([(x, y), (x + 1, y)], "W")
            cv.put(x + 1, y + 1, "h")
    # baskets of cocoons on the floor
    for bx in (34, 43):
        cv.rect(bx, 41, 7, 5, "B")
        cv.hl(bx, bx + 6, 41, "P")
        cv.ellipse(bx + 3.5, 41, 3.5, 2, "W")
        cv.pts([(bx + 2, 40), (bx + 4, 41)], "h")
    # the desk with the ledger, clerk in a western suit behind it
    clerk = Fig("felt", "jacket", C_DKGREY, C_DKGREY, hatc=C_BLACK, arm="point", barm="down")
    clerk.place(cv, 50, 34, flip=True)
    cv.rect(30, 30, 33, 3, "B")
    cv.hl(30, 62, 30, "P")
    cv.rect(30, 33, 33, 6, "w")
    cv.vl(62, 30, 38, "x")
    ledger(cv, 38, 27, 12, 3)
    abacus(cv, 52, 26, 9, 4)
    # a townsman bent over to register
    man = Fig("skull_back", "gown", C_BROWN, hatc=C_BLACK, arm="fwd", barm="down")
    man.item("brush")
    man.place(cv, 25, 46)


@scene("illus.ev.1939.countryside_word")
def ev_countryside_word(cv, r):
    sky(cv, "winter", 18)
    cv.poly([(0, 18), (14, 12), (26, 16), (40, 11), (64, 17), (64, 19), (0, 19)], "m")
    cv.poly([(0, 19), (20, 15), (38, 18), (64, 16), (64, 20), (0, 20)], "s")
    cv.rect(0, 20, W, 28, "P")
    for y in range(22, 48, 3):
        cv.hl(0, 63, y, "B")
    for x, y in ((6, 27), (16, 25), (27, 27), (9, 34), (21, 33)):
        mulberry(cv, x, y)
    # path to the shop on the right
    cv.poly([(16, 48), (30, 30), (38, 30), (46, 48)], "p")
    cv.rect(47, 6, 17, 37, "h")
    roof(cv, 46, 66, 3, 4)
    cv.rect(51, 14, 12, 29, "w")
    cv.vl(51, 14, 42, "b")
    cv.rect(52, 15, 10, 28, "x")
    cv.rect(46, 43, 18, 5, "t")
    # the man from the country, baskets set down, telling what he heard
    for bx in (19, 33):
        cv.rect(bx, 41, 6, 4, "g")
        cv.hl(bx, bx + 5, 41, "Y")
        cv.vl(bx + 2, 36, 40, "b")
        cv.pts([(bx + 1, 40), (bx + 2, 40), (bx + 3, 40)], "P")
    cv.line(21, 36, 35, 36, "B")
    man = Fig("straw", "jacket", C_BROWN, C_DKGREY, SKIN_TAN, hatc=C_TAN, arm="point", barm="down")
    man.place(cv, 29, 45)
    f = ruhua(arm="chest", barm="down")
    f.place(cv, 55, 44, flip=True)


@scene("illus.ev.1939.district_levy")
def ev_district_levy(cv, r):
    planks(cv, 0, 0, W, 38, base="w", seam="x", lit="w", step=6)
    # bright doorway on the right
    cv.rect(44, 6, 16, 32, "p")
    cv.rect(44, 6, 16, 3, "h")
    cv.rect(44, 30, 16, 8, "P")
    cv.frame(43, 5, 18, 34, "x")
    # shelf of rice sacks on the left
    cv.hl(0, 30, 18, "B")
    cv.hl(0, 30, 19, "x")
    for x in (1, 8, 15, 22):
        sack(cv, x, 11, 6, 7, "P")
    cv.rect(0, 38, W, 10, "b")
    cv.hl(0, W - 1, 38, "w")
    for x in (3, 11):
        sack(cv, x, 31, 7, 7, "P")
    # the district man points at the rice, his militiaman carries a sack out
    off = Fig("felt", "gown", C_BLACK, hatc=C_BLACK, arm="point", barm="down", armband="r")
    off.place(cv, 31, 45, flip=True)
    mil = Fig("mil", "coat_walk", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="shoulder", barm="down")
    mil.item("sack", "P")
    mil.place(cv, 47, 45)


@scene("illus.ev.1939.gate_check")
def ev_gate_check(cv, r):
    sky(cv, "winter", 16)
    city_gate(cv, -1, 64, 14, 40, arch=(25, 39))
    snowcap(cv, (0, 0, W, 20), "W", under=("m", "h"))
    cv.rect(0, 40, W, 8, "h")
    cv.hl(0, W - 1, 40, "m")
    for x in range(4, 60, 7):
        cv.pts([(x, 43), (x + 2, 45)], "m")
    # the traveller with raised arms, a sentry patting him down, another at the side
    tr = Fig("bare", "gown", C_BROWN, arm="up", barm="up")
    tr.place(cv, 31, 45)
    s1 = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="fwd", barm="fwd")
    s1.place(cv, 41, 45, flip=True)
    s2 = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="down", barm="down")
    s2.place(cv, 14, 44)
    snowfall(cv, r, 26, (0, 0, W, 48))


@scene("illus.ev.1939.night_market")
def ev_night_market(cv, r):
    sky(cv, "night", 14)
    stars(cv, r, 5, (0, 0, 64, 5))
    house(cv, -3, 20, 7, 30, kind="wall", night=True, r=r)
    house(cv, 21, 44, 5, 30, kind="wall", night=True, r=r)
    house(cv, 45, 66, 7, 30, kind="wall", night=True, r=r)
    # one string of red lanterns across the street
    for x in range(0, W):
        cv.put(x, 4 + int(4 * math.sin(math.pi * x / 63.0)), "k")
    for x in range(4, 62, 8):
        lantern_red(cv, x, 8 + int(4 * math.sin(math.pi * x / 63.0)), lit=True, small=True)
    # stalls under striped awnings
    for sx, a, b in ((1, "r", "S"), (23, "i", "h"), (45, "r", "S")):
        for k, x in enumerate(range(sx - 1, sx + 18)):
            cv.vl(x, 24, 27, a if (k // 3) % 2 == 0 else b)
        cv.hl(sx - 1, sx + 17, 28, DARK[a])
        cv.rect(sx, 32, 16, 6, "b")
        cv.hl(sx, sx + 15, 32, "B")
        for x in range(sx + 1, sx + 15, 2):
            cv.put(x, 31, r.choice(("r", "Y", "h", "R", "e")))
            cv.put(x + 1, 31, r.choice(("Y", "h")))
        cv.vl(sx, 28, 37, "w")
        cv.vl(sx + 15, 28, 37, "w")
        cv.put(sx + 8, 29, "y")
    cv.rect(0, 38, W, 10, "f")
    cv.hl(0, W - 1, 38, "E")
    crowd(cv, r, 2, 62, 46, 11, tops=("i", "B", "r", "t", "E", "b", "j"), outline="K")
    pair = Fig("bun", "jacket", C_RED, C_NAVY, SKIN_DIM, arm="hold", barm="down")
    pair.item("lantern")
    pair.place(cv, 30, 48, outline="K")


@scene("illus.ev.1939.patrol")
def ev_patrol(cv, r):
    sky(cv, "grey", 10)
    house(cv, -3, 30, 3, 34, kind="shop")
    house(cv, 31, 66, 5, 34, kind="wall", r=r)
    snowcap(cv, (0, 0, W, 12), "W", under=("s", "m", "h"))
    ground(cv, 34, "stone")
    # a wooden barricade across the street corner
    for x in (36, 54):
        cv.line(x - 3, 40, x + 3, 33, "b")
        cv.line(x + 3, 40, x - 3, 33, "b")
    cv.rect(32, 35, 26, 2, "P")
    cv.hl(32, 57, 35, "h")
    # the patrolman reads a woman's papers, a second waits with a baton
    w_ = Fig("bun", "jacket", C_JADE, C_NAVY, arm="fwd", barm="hold")
    w_.item("paper", "S")
    w_.place(cv, 17, 45)
    cv.rect(10, 37, 4, 3, "g")     # her basket
    cv.hl(10, 13, 37, "Y")
    p1 = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="fwd", barm="down")
    p1.place(cv, 30, 45, flip=True)
    p2 = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="hold", barm="down")
    p2.item("baton", "b")
    p2.place(cv, 47, 38, flip=True)


@scene("illus.ev.1939.refugee_cold")
def ev_refugee_cold(cv, r):
    sky(cv, "winter", 12)
    city_gate(cv, -1, 64, 10, 40, arch=(46, 60), tower=False)
    cv.rect(0, 40, W, 8, "h")
    cv.hl(0, W - 1, 40, "m")
    snowcap(cv, (0, 0, W, 14), "W", under=("m", "h"))
    # people huddled against the wall
    a = Fig("scarf_back", "hug", C_GREY, C_DKGREY, hatc=C_BROWN, arm="none", barm="down")
    a.place(cv, 8, 41)
    b = Fig("scarf", "hug", C_BROWN, C_DKGREY, hatc=C_GREY, arm="none", barm="down")
    b.place(cv, 19, 41)
    c = Fig("scarf", "jacket", C_DKGREY, C_GREY, hatc=C_BROWN, arm="chest", barm="down")
    c.item("bundle", "B")
    c.place(cv, 31, 44)
    tiny(cv, 37, 44, top="B", head="q", skin="N", outline="k")
    # wind-driven snow
    for _ in range(30):
        x, y = r.randrange(0, 70), r.randrange(0, 46)
        cv.line(x, y, x - 2, y + 1, r.choice(("W", "h")))


@scene("illus.ev.1939.snow_road")
def ev_snow_road(cv, r):
    sky(cv, "winter", 18)
    cv.rect(0, 13, W, 4, "m")
    for x in range(0, W, 4):
        cv.put(x, 12, "m")
    cv.rect(0, 17, W, 31, "W")
    for y in range(19, 48, 4):
        cv.hl((y * 3) % 7, 63, y, "h")
    # the buried road
    cv.poly([(28, 17), (35, 17), (52, 48), (12, 48)], "h")
    for y in range(18, 48, 3):
        w = (y - 17) // 3
        cv.hl(31 - w // 2, 32 + w // 2, y, "m")
    # bare trees with snow on the branches
    for x, y, h in ((7, 30, 12), (55, 32, 13), (16, 22, 7), (47, 22, 7)):
        cv.vl(x, y - h, y, "w")
        for k in range(3):
            yy = y - h + 2 + k * 3
            cv.line(x, yy, x - 3 + k, yy - 3, "w")
            cv.line(x, yy + 1, x + 3 - k, yy - 2, "w")
            cv.put(x - 3 + k, yy - 4, "W")
    # Ruhua digging the road clear, a heap of snow beside her
    cv.ellipse(42, 42, 6, 3, "h")
    cv.hl(37, 47, 40, "W")
    f = ruhua(arm="low", barm="fwd", body="jacket_walk")
    f.item("shovel")
    f.place(cv, 30, 45)
    snowfall(cv, r, 50, (0, 0, W, 48), cols=("W", "W", "h"))


@scene("illus.ev.1939.wu_price")
def ev_wu_price(cv, r):
    cv.rect(0, 0, W, 32, "b")
    for x in range(0, W, 8):
        cv.vl(x, 0, 31, "w")
    for x, y in ((2, 9), (9, 9), (2, 17), (9, 17), (50, 11), (56, 18), (49, 19)):
        sack(cv, x, y, 6, 7, "P")
    # the rice merchant behind his counter, hand raised: the price goes up
    wu = Fig("skull", "gown", C_JADE, hatc=C_BLACK, arm="up", barm="down")
    wu.place(cv, 30, 33)
    cv.rect(0, 30, W, 18, "w")
    cv.hl(0, W - 1, 30, "P")
    cv.hl(0, W - 1, 31, "B")
    for px in range(3, W - 8, 13):
        cv.frame(px, 34, 10, 12, "b")
    for k, x in enumerate((38, 43, 48)):
        coins(cv, x, 29, 3 + k * 3)
    cv.rect(13, 25, 10, 5, "B")
    cv.hl(13, 22, 25, "P")
    cv.ellipse(18, 25, 5, 2, "W")
    cv.pts([(16, 24), (19, 24)], "h")
    b = Fig("bun_back", "jacket", C_INDIGO, C_DKGREY, arm="down", barm="down")
    b.place(cv, 57, 50, flip=True)


@scene("illus.ev.1939.year_debt")
def ev_year_debt(cv, r):
    sky(cv, "night", 10)
    roof(cv, -3, 66, 3, 5, "q", "Q", "K", "K")
    planks(cv, 0, 8, W, 32, base="w", seam="x", lit="b", step=4)
    cv.rect(0, 8, W, 2, "x")
    # red couplet strips (blank) and a lit lantern
    cv.rect(26, 12, 3, 24, "r")
    cv.rect(52, 12, 3, 24, "r")
    cv.vl(28, 12, 35, "d")
    cv.vl(54, 12, 35, "d")
    cv.rect(31, 10, 19, 3, "r")
    lantern_red(cv, 40, 17, lit=True)
    glow(cv, 40.5, 17.5, 9, 0.5)
    # door ajar, Ruhua looking out
    cv.rect(36, 20, 9, 20, "x")
    cv.rect(37, 21, 7, 19, "N")
    f = ruhua(arm="chest", barm="down", skin=SKIN_DIM)
    f.place(cv, 41, 43, flip=True)
    cv.rect(44, 20, 6, 20, "w")
    cv.vl(44, 20, 39, "b")
    cv.rect(0, 40, W, 8, "f")
    cv.hl(0, W - 1, 40, "E")
    # the creditor with his account book open, abacus under his arm
    c = Fig("felt", "gown", C_BLACK, skin=SKIN_DIM, hatc=C_BLACK, arm="fwd", barm="down")
    c.item("ledger", "i")
    c.place(cv, 21, 45)
    cv.rect(13, 34, 4, 3, "x")
    cv.hl(13, 16, 35, "B")
    snowfall(cv, r, 30, (0, 0, W, 48), cols=("W", "h", "m"))


# --------------------------------------------------------------------------- events 1940 (spring)


@scene("illus.ev.1940.curfew")
def ev_1940_curfew(cv, r):
    sky(cv, "dusk", 12)
    house(cv, -3, 30, 4, 38, kind="shop")
    house(cv, 31, 66, 2, 38, kind="shop")
    cv.recolor({"P"}, "B", (0, 0, W, 38))
    cv.recolor({"h"}, "P", (0, 0, W, 38))
    ground(cv, 38, "stone")
    # a street lamp just lit
    cv.vl(4, 16, 38, "x")
    cv.rect(2, 12, 5, 5, "w")
    cv.rect(3, 13, 3, 3, "y")
    glow(cv, 4.5, 14.5, 7, 0.4)
    # Ruhua putting up the door planks, a patrolman waving everyone off the street
    f = ruhua(arm="hold", barm="hold")
    f.c.rect(f.ox + 10, f.oy + 1, 3, 15, "B")
    f.c.vl(f.ox + 12, f.oy + 1, f.oy + 15, "b")
    f.c.hl(f.ox + 10, f.ox + 12, f.oy + 1, "P")
    f.c.put(f.ox + 11, f.oy + 9, "N")
    f.place(cv, 22, 45)
    p = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="up", barm="down")
    p.item("baton", "b")
    p.place(cv, 50, 45, flip=True)


@scene("illus.ev.1940.gate_tight")
def ev_gate_tight(cv, r):
    sky(cv, "day", 14)
    city_gate(cv, -1, 64, 14, 36, arch=(26, 38))
    cv.rect(0, 36, W, 12, "P")
    cv.hl(0, W - 1, 36, "B")
    # sandbag post on the left, a barrier pole across the road
    sandbags(cv, 0, 20, 30, 3)
    cv.hl(16, 50, 33, "h")
    cv.hl(16, 50, 34, "P")
    for x in range(18, 50, 6):
        cv.hl(x, x + 2, 33, "r")
        cv.hl(x, x + 2, 34, "d")
    cv.rect(49, 33, 2, 7, "b")
    # one sentry behind the bags, one stepping out to stop the next in line
    s1 = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="down", barm="down")
    s1.place(cv, 8, 35)
    sandbags(cv, 0, 20, 33, 2)
    s2 = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="fwd", barm="down")
    s2.place(cv, 30, 45)
    first = Fig("bare", "gown", C_BROWN, arm="fwd", barm="down")
    first.item("paper", "S")
    first.place(cv, 44, 46, flip=True)
    for k, x in enumerate((52, 58, 63)):
        tiny(cv, x, 45 - (k % 2), top=("i", "t", "j")[k], head="q", skin="N", facing="l", outline="k")


@scene("illus.ev.1940.household_count")
def ev_household_count(cv, r):
    sky(cv, "day", 8)
    house(cv, -3, 66, 2, 38, kind="shop")
    cv.rect(26, 22, 12, 16, "x")     # the open shop door
    cv.rect(27, 23, 10, 15, "w")
    ground(cv, 38, "stone")
    # the household lined up: grandmother, Ruhua, a child
    gran = Fig("bun", "jacket", C_BROWN, C_DKGREY, hair="m", arm="chest", barm="down")
    gran.place(cv, 8, 45)
    f = ruhua(arm="down", barm="down")
    f.place(cv, 19, 45)
    tiny(cv, 27, 45, top="R", head="q", skin="N", outline="k")
    # the census clerk ticking them off in his register
    c = Fig("cap", "gown", C_DKGREY, hatc=C_BLACK, arm="hold", barm="fwd")
    c.item("ledger", "i")
    c.place(cv, 47, 45, flip=True)
    cv.vl(39, 34, 38, "k")


@scene("illus.ev.1940.levy_rename")
def ev_levy_rename(cv, r):
    sky(cv, "day", 48)
    wall(cv, 0, 8, W, 32, "h", "P", r=r)
    roof(cv, -3, 66, 4, 4)
    ground(cv, 40, "stone")
    # the street notice board, a little roof over it
    roof(cv, 10, 54, 9, 3)
    cv.rect(10, 12, 45, 24, "b")
    cv.frame(10, 12, 45, 24, "w")
    cv.vl(12, 36, 41, "w")
    cv.vl(52, 36, 41, "w")
    # the old levy sheet, yellowed, with its seal
    notice(cv, 14, 14, 18, 19, paper="P", lines="B", edge="B")
    # the new sheet pasted half over it, one corner still curling
    notice(cv, 24, 15, 20, 19, paper="S", lines="t")
    cv.rect(39, 29, 3, 3, "r")
    cv.pts([(43, 15), (42, 15), (43, 16)], "b")
    cv.pts([(42, 16)], "m")
    # the paster on a stool with his brush and bucket
    m = Fig("cap", "jacket", C_DKGREY, C_BLACK, hatc=C_BLACK, arm="up", barm="down", armband="r")
    m.item("brush")
    m.place(cv, 50, 42, flip=True)
    cv.rect(56, 41, 5, 4, "B")
    cv.hl(56, 60, 41, "P")
    cv.vl(60, 41, 44, "b")


@scene("illus.ev.1940.new_official")
def ev_new_official(cv, r):
    sky(cv, "day", 12)
    # the yamen gate: red pillars, a blank plaque, steps
    roof(cv, 2, 61, 3, 6)
    cv.rect(4, 9, 56, 24, "Q")
    for x in (6, 20, 43, 57):
        cv.rect(x, 9, 3, 24, "r")
        cv.vl(x, 9, 32, "R")
        cv.vl(x + 2, 9, 32, "d")
    cv.rect(24, 13, 17, 20, "w")     # open doors
    cv.rect(25, 14, 15, 19, "x")
    plaque(cv, 22, 10, 21, 4)
    for k in range(4):
        cv.rect(2 + k * 2, 33 + k * 2, 60 - k * 4, 2, "m" if k % 2 == 0 else "s")
        cv.hl(2 + k * 2, 61 - k * 2, 33 + k * 2, "h")
    cv.rect(0, 41, W, 7, "t")
    # the new man arriving in a western suit, guards either side
    o = Fig("felt", "jacket", C_DKGREY, C_DKGREY, hatc=C_BLACK, arm="down", barm="down")
    o.place(cv, 32, 35)
    for x, fl in ((17, False), (47, True)):
        g = Fig("mil", "coat", C_OLIVE, C_OLIVE, hatc=C_OLIVE, arm="down", barm="down")
        g.place(cv, x, 33, flip=fl)
    # shopkeepers below with gift boxes, seen from behind
    for x, top, hat in ((8, C_BROWN, "skull_back"), (52, C_INDIGO, "felt_back")):
        f = Fig(hat, "gown", top, hatc=C_BLACK, arm="hold", barm="hold")
        f.place(cv, x, 52)
        cv.rect(x + 2, 40, 5, 4, "r")
        cv.vl(x + 4, 40, 43, "Y")
        cv.hl(x + 2, x + 6, 40, "R")


@scene("illus.ev.1940.papers_swap")
def ev_papers_swap(cv, r):
    cv.rect(0, 0, W, 48, "P")
    for _ in range(20):
        cv.put(r.randrange(0, W), r.randrange(0, 36), "B")
    # the office window with a grille, a clerk behind it
    cv.rect(10, 4, 38, 30, "x")
    cv.frame(9, 3, 40, 32, "w")
    cv.rect(11, 5, 36, 26, "f")
    clerk = Fig("cap", "gown", C_DKGREY, hatc=C_BLACK, arm="fwd", barm="down")
    clerk.place(cv, 26, 42, flip=True)
    for x in range(13, 46, 4):
        cv.vl(x, 5, 20, "w")
    cv.hl(11, 46, 5, "w")
    cv.hl(11, 46, 20, "w")
    cv.rect(8, 31, 42, 3, "B")      # the window ledge
    cv.hl(8, 49, 31, "P")
    cv.rect(0, 34, W, 14, "b")
    cv.hl(0, W - 1, 34, "w")
    # new paper with its red seal slid out; the old one, yellow and creased, handed in
    cv.rect(16, 26, 8, 5, "S")
    cv.hl(17, 22, 27, "t")
    cv.hl(17, 21, 29, "t")
    cv.rect(21, 28, 2, 2, "r")
    cv.rect(30, 27, 7, 4, "P")
    cv.pts([(31, 28), (33, 29), (35, 28)], "B")
    cv.put(36, 27, "g")
    f = ruhua(arm="fwd", barm="down", back=True)
    f.place(cv, 46, 52, flip=True)


@scene("illus.ev.1940.rice_notice")
def ev_rice_notice(cv, r):
    sky(cv, "day", 10)
    roof(cv, -3, 66, 2, 5)
    cv.rect(0, 7, W, 33, "h")
    cv.rect(30, 7, 34, 33, "x")      # the open rice shop
    cv.rect(30, 7, 34, 2, "b")
    for x, y in ((33, 26), (40, 27), (47, 26), (54, 27), (36, 20), (51, 20)):
        sack(cv, x, y, 6, 6, "P")
    cv.vl(30, 7, 39, "w")
    cv.vl(29, 7, 39, "k")
    # the price notice going up on the wall, a clerk smoothing it with his brush
    notice(cv, 8, 11, 14, 18, paper="S", lines="t")
    cv.rect(17, 25, 3, 3, "r")
    clerk = Fig("bare", "jacket", C_TAN, C_DKGREY, arm="up", barm="down")
    clerk.item("brush")
    clerk.place(cv, 26, 38, flip=True)
    cv.rect(23, 38, 6, 2, "b")
    ground(cv, 40, "stone")
    # buyers stopping to read it
    for x, top, hat in ((6, C_INDIGO, "bun_back"), (16, C_BROWN, "skull_back")):
        f = Fig(hat, "gown", top, hatc=C_BLACK, arm="down", barm="down")
        f.place(cv, x, 51)


@scene("illus.ev.1940.shop_search")
def ev_shop_search(cv, r):
    planks(cv, 0, 0, W, 38, base="w", seam="x", lit="w", step=7)
    for sy in (12, 24):
        cv.hl(0, W - 1, sy, "B")
        cv.hl(0, W - 1, sy + 1, "x")
        x = 2
        while x < W - 4:
            if r.random() < 0.3:
                x += 5
                continue
            col = r.choice(("i", "B", "j", "s"))
            cv.rect(x, sy - 5, 5, 5, col)
            cv.hl(x, x + 4, sy - 5, LIGHT[col])
            x += 6
    cv.rect(0, 38, W, 10, "b")
    cv.hl(0, W - 1, 38, "w")
    # bundles pulled down and thrown open on the floor
    for x, y, col in ((24, 41, "i"), (33, 43, "B"), (41, 40, "j")):
        cv.rect(x, y, 6, 3, col)
        cv.hl(x, x + 5, y, LIGHT[col])
        cv.pts([(x + 6, y + 1), (x + 7, y + 2), (x - 1, y + 2)], LIGHT[col])
    cv.rect(46, 44, 4, 2, "h")
    # one policeman pulls a bundle off the shelf, the other stands over Ruhua
    p1 = Fig("police_back", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="up", barm="down")
    p1.place(cv, 52, 44)
    cv.rect(54, 3, 5, 5, "i")
    cv.hl(54, 58, 3, "I")
    p2 = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="hold", barm="down")
    p2.item("baton", "b")
    p2.place(cv, 25, 45, flip=True)
    f = ruhua(arm="chest", barm="down")
    f.place(cv, 10, 45)


@scene("illus.ev.1940.signboard")
def ev_signboard(cv, r):
    sky(cv, "day", 48)
    roof(cv, -3, 66, 2, 5)
    cv.rect(0, 7, W, 33, "h")
    cv.hl(0, W - 1, 7, "P")
    planks(cv, 0, 27, W, 13, base="w", seam="x", lit="b", step=4)
    cv.hl(0, W - 1, 26, "x")
    # sun-faded patch where the board hung for years
    cv.rect(17, 10, 30, 9, "N")
    cv.frame(17, 10, 30, 9, "P")
    ground(cv, 40, "stone")
    # the ladder, a man on it lowering one end, a man below taking the other
    for y in range(12, 46, 3):
        cv.hl(49, 53, y, "B")
    cv.vl(48, 9, 46, "b")
    cv.vl(54, 9, 46, "b")
    up = Fig("cap", "jacket", C_DKGREY, C_BLACK, hatc=C_BLACK, arm="fwd", barm="fwd")
    up.place(cv, 53, 30, flip=True)
    low = Fig("bare", "jacket", C_TAN, C_DKGREY, arm="up", barm="up")
    low.place(cv, 16, 47)
    # the blank board itself, tilted, black with a gold rim
    pts = [(12, 27), (45, 21), (45, 27), (12, 33)]
    cv.poly(pts, "Q")
    for x in range(12, 46):
        t = (x - 12) / 33.0
        yt = int(round(27 - 6 * t))
        cv.put(x, yt, "Y")
        cv.put(x, yt + 6, "g")
        cv.put(x, yt + 2, "q")
    cv.vl(12, 27, 33, "Y")
    cv.vl(45, 21, 27, "g")


@scene("illus.ev.1940.wang_regime")
def ev_wang_regime(cv, r):
    sky(cv, "grey", 48)
    # grey brick wall with a great proclamation and its big seal
    cv.rect(0, 8, W, 32, "t")
    for y in range(9, 40, 3):
        cv.hl(0, W - 1, y, "E")
        off = 0 if (y // 3) % 2 else 3
        for x in range(off, W, 6):
            cv.vl(x, y - 2, y - 1, "E")
    cv.rect(0, 6, W, 2, "f")
    notice(cv, 12, 10, 40, 24, paper="S", seal=False, lines="t")
    cv.frame(12, 10, 40, 24, "r")
    cv.rect(41, 23, 7, 7, "r")
    cv.frame(42, 24, 5, 5, "R")
    cv.put(44, 26, "d")
    ground(cv, 40, "stone")
    # townspeople reading, a policeman standing by
    for x, top, hat in ((6, C_BROWN, "felt_back"), (17, C_INDIGO, "skull_back"), (29, C_GREY, "bun_back"),
                        (41, C_DKBROWN, "back")):
        f = Fig(hat, "gown", top, hatc=C_BLACK, arm="down", barm="down")
        f.place(cv, x, 51 - (x % 2))
    p = Fig("police", "coat", C_NAVY, C_NAVY, hatc=C_NAVY, arm="down", barm="down")
    p.place(cv, 57, 46, flip=True)


# --------------------------------------------------------------------------- events, any year


@scene("illus.ev.any.alley_row")
def ev_alley_row(cv, r):
    sky(cv, "day", 6)
    wall(cv, 0, 4, 64, 38, "h", "P", r=r)
    roof(cv, -3, 66, 0, 4)
    lattice(cv, 46, 10, 7, 6, frame="w", fill="x", bar="b")
    cv.rect(48, 12, 3, 3, "N")                # a neighbour peering out
    cv.rect(48, 11, 3, 1, "q")
    # laundry pole across the alley
    cv.line(0, 8, 40, 6, "B")
    for x, c in ((6, "i"), (13, "S"), (21, "r"), (29, "J")):
        y = 8 - x // 20
        cv.rect(x, y, 5, 6, c)
        cv.vl(x + 4, y, y + 5, DARK[c])
    ground(cv, 42, "stone")
    # two neighbours shouting, Ruhua between them
    a = Fig("skull", "gown", C_BROWN, hatc=C_BLACK, arm="point", barm="down")
    a.place(cv, 14, 45)
    b = Fig("bare", "jacket", C_DKGREY, C_INDIGO, arm="up", barm="up")
    b.place(cv, 50, 45, flip=True)
    f = ruhua(arm="fwd", barm="down", back=True)
    f.place(cv, 32, 46)


@scene("illus.ev.any.cezi_stall")
def ev_cezi_stall(cv, r):
    sky(cv, "day", 48)
    wall(cv, 0, 6, 64, 32, "h", "P", r=r)
    roof(cv, -3, 66, 2, 4)
    ground(cv, 38, "stone")
    # a tree's shade over the stall
    cv.vl(58, 6, 38, "b")
    cv.ellipse(56, 6, 9, 6, "G")
    cv.ellipse(52, 4, 5, 4, "l")
    # tall pole with a blank cloth banner
    cv.vl(6, 4, 42, "b")
    cv.rect(7, 5, 6, 20, "S")
    cv.frame(7, 5, 6, 20, "r")
    cv.hl(7, 12, 25, "r")
    cv.pts([(8, 26), (10, 27), (12, 26)], "r")
    # the table: white cloth front, paper with one big ink blot, ink stone, brush pot
    cv.rect(18, 30, 24, 3, "B")
    cv.hl(18, 41, 30, "P")
    cv.rect(18, 33, 24, 9, "S")
    cv.vl(41, 33, 41, "h")
    cv.frame(18, 33, 24, 9, "P")
    cv.rect(26, 27, 8, 4, "W")
    cv.pts([(28, 28), (29, 28), (30, 29), (29, 30), (31, 28), (32, 29)], "k")
    cv.rect(36, 28, 3, 2, "q")
    cv.rect(20, 26, 2, 4, "j")
    cv.vl(20, 23, 25, "B")
    cv.vl(21, 24, 25, "B")
    # the old character reader behind it, the customer before it
    old = Fig("skull", "gown", C_DKGREY, hair="m", hatc=C_BLACK, arm="point", barm="down")
    old.place(cv, 25, 36)
    cust = Fig("bun_back", "jacket", C_JADE, C_NAVY, arm="fwd", barm="down")
    cust.place(cv, 48, 46, flip=True)


@scene("illus.ev.any.curfew")
def ev_any_curfew(cv, r):
    sky(cv, "night", 14)
    stars(cv, r, 6, (0, 0, 64, 6))
    moon(cv, 54, 5, 2)
    house(cv, -3, 30, 6, 38, kind="shop", night=True)
    house(cv, 31, 66, 4, 38, kind="wall", night=True, r=r)
    cv.vl(40, 10, 38, "x")
    cv.rect(38, 7, 5, 4, "w")
    cv.rect(39, 8, 3, 2, "y")
    notice(cv, 45, 16, 9, 12, paper="P", lines="E", edge="B")
    cv.rect(0, 38, W, 10, "f")
    cv.hl(0, W - 1, 38, "E")
    # the lamp's pool of light on the street
    cv.ellipse(38, 43, 18, 4, "E")
    cv.ellipse(38, 43, 11, 2.5, "t")
    p = Fig("police", "coat", C_NAVY, C_NAVY, SKIN_DIM, hatc=C_NAVY, arm="fwd", barm="hold")
    p.place(cv, 36, 45, flip=True)
    p2 = Fig("police", "coat", C_NAVY, C_NAVY, SKIN_DIM, hatc=C_NAVY, arm="hold", barm="down")
    p2.item("lantern")
    p2.place(cv, 51, 44, flip=True)
    f = ruhua(arm="fwd", barm="down", skin=SKIN_DIM)
    f.item("paper", "P")
    f.place(cv, 22, 45)


@scene("illus.ev.any.demand_return")
def ev_demand_return(cv, r):
    sky(cv, "dusk", 22)
    # the far town gate at the end of the road
    cv.rect(18, 12, 28, 10, "t")
    cv.rect(16, 10, 32, 2, "E")
    cv.ellipse(32, 17, 3, 3, "q")
    cv.rect(29, 17, 7, 5, "q")
    cv.rect(0, 20, W, 28, "B")
    for y in range(22, 48, 3):
        cv.hl(0, 63, y, "b")
    cv.poly([(29, 21), (35, 21), (48, 48), (12, 48)], "P")
    for x, y in ((6, 26), (55, 27), (12, 32)):
        mulberry(cv, x, y)
    # the one who was sent out, walking home with his bundle
    m = Fig("front", "gown", C_GREY, arm="down", barm="down")
    m.item("bundle", "i")
    m.place(cv, 30, 36)
    # Ruhua at the shop door with a lantern, waiting
    cv.rect(50, 6, 14, 42, "w")
    cv.rect(52, 8, 12, 40, "N")
    cv.vl(50, 6, 47, "x")
    f = ruhua(arm="hold", barm="down", back=True)
    f.item("lantern")
    f.place(cv, 48, 48)
    glow(cv, 49.5, 37.5, 6, 0.4)


@scene("illus.ev.any.fair")
def ev_fair(cv, r):
    sky(cv, "day", 12)
    # the city god temple: red walls, grey roof, a red banner
    roof(cv, 6, 57, 3, 6)
    cv.rect(8, 9, 48, 18, "r")
    cv.vl(8, 9, 26, "R")
    for x in (12, 26, 37, 51):
        cv.rect(x, 9, 2, 18, "d")
    cv.rect(27, 12, 10, 15, "Q")
    plaque(cv, 26, 9, 12, 3)
    for x in range(10, 56, 4):
        cv.put(x, 9, "Y")
    cv.rect(0, 27, W, 21, "P")
    cv.hl(0, W - 1, 27, "B")
    # a snack seller with candied haws, a pinwheel seller
    cv.vl(6, 18, 34, "b")
    for k in range(4):
        cv.pts([(5, 19 + k * 3), (7, 20 + k * 3)], "r")
        cv.put(6, 19 + k * 3, "R")
    cv.vl(59, 20, 34, "b")
    for k, (dx, dy, c) in enumerate(((-2, -1, "R"), (1, -2, "Y"), (2, 1, "i"), (-1, 2, "h"))):
        cv.put(59 + dx, 20 + dy, c)
        cv.put(59 + dx * 2 // 2, 20 + dy // 2, c)
    # the fair's prize wheel on a stall
    cv.rect(38, 36, 16, 6, "b")
    cv.hl(38, 53, 36, "B")
    cv.vl(46, 30, 35, "w")
    prize_wheel(cv, 46.5, 29.5, 6.5, turn=0.1)
    # the crowd
    crowd(cv, r, 0, 64, 44, 10, tops=("i", "B", "r", "t", "j", "b", "s"), outline="k")
    crowd(cv, r, 2, 36, 48, 5, tops=("i", "B", "r", "j"), outline="k")


@scene("illus.ev.any.gamble_stall")
def ev_gamble_stall(cv, r):
    sky(cv, "day", 48)
    wall(cv, 0, 4, 64, 30, "h", "P", r=r)
    roof(cv, -3, 66, 0, 4)
    cv.rect(0, 34, W, 14, "t")
    ground(cv, 34, "stone")
    # the banker behind a low table with the wheel laid flat-ish on a stand
    banker = Fig("felt", "gown", C_BLACK, hatc=C_BLACK, arm="hold", barm="down")
    banker.place(cv, 32, 38)
    cv.rect(16, 33, 32, 3, "b")
    cv.hl(16, 47, 33, "B")
    cv.rect(18, 36, 2, 6, "w")
    cv.rect(44, 36, 2, 6, "w")
    prize_wheel(cv, 24.5, 24.5, 8, cols=("r", "Q", "Y", "Q", "r", "S", "Q", "Y"), rim="x", turn=0.04)
    cv.vl(24, 32, 33, "w")
    # stakes on the table: coins and a little bundle, a gambler leaning in
    coins(cv, 36, 32, 3)
    cv.rect(40, 30, 5, 3, "j")
    cv.hl(40, 44, 30, "J")
    g = Fig("cap", "jacket", C_BROWN, C_DKGREY, hatc=C_DKGREY, arm="point", barm="down")
    g.place(cv, 8, 46)
    g2 = Fig("bare", "jacket", C_INDIGO, C_DKGREY, arm="hold", barm="down")
    g2.item("coins")
    g2.place(cv, 55, 46, flip=True)


@scene("illus.ev.any.market_haggle")
def ev_market_haggle(cv, r):
    sky(cv, "day", 10)
    # awnings of the market behind
    for k, x in enumerate(range(-4, 64, 17)):
        c = ("B", "i", "P", "B")[k % 4]
        cv.poly([(x, 10), (x + 15, 10), (x + 17, 15), (x - 2, 15)], c)
        cv.hl(x - 2, x + 17, 15, DARK[c])
        cv.vl(x, 15, 30, "w")
        cv.rect(x + 1, 22, 13, 8, "b")
        for xx in range(x + 2, x + 13, 2):
            cv.put(xx, 21, r.choice(("l", "Y", "h", "R")))
    crowd(cv, r, 0, 64, 32, 9, tops=("i", "B", "t", "j", "b", "s"))
    cv.rect(0, 32, W, 16, "P")
    cv.hl(0, W - 1, 32, "B")
    speckle(cv, r, (0, 33, W, 48), ("B", "p"), 30)
    # the farmer squatting by his baskets of greens and eggs
    for bx, fill in ((22, "l"), (31, "h")):
        cv.rect(bx, 39, 8, 5, "g")
        cv.hl(bx, bx + 7, 39, "Y")
        cv.vl(bx + 7, 40, 43, "b")
        cv.ellipse(bx + 4, 39, 4, 2, fill)
        if fill == "l":
            cv.pts([(bx + 2, 37), (bx + 5, 37), (bx + 3, 38)], "G")
        else:
            cv.pts([(bx + 2, 38), (bx + 5, 38)], "W")
    man = Fig("straw", "sit", C_BROWN, C_DKGREY, SKIN_TAN, hatc=C_TAN, arm="fwd", barm="down")
    man.place(cv, 13, 45)
    stool(cv, 9, 42, "b")
    # Ruhua pointing at the greens, coins ready
    f = ruhua(arm="point", barm="hold")
    f.place(cv, 50, 46, flip=True)
    coins(cv, 44, 37, 2)


@scene("illus.ev.any.rain_leak")
def ev_rain_leak(cv, r):
    planks(cv, 0, 0, W, 40, base="w", seam="x", lit="w", step=7)
    # roof beams and a gap where the rain comes in
    cv.rect(0, 0, W, 4, "x")
    for x in range(0, W, 10):
        cv.rect(x, 0, 3, 5, "k")
    cv.rect(30, 0, 5, 2, "n")
    cv.put(32, 1, "m")
    # a window onto the rain
    cv.rect(4, 10, 14, 14, "n")
    cv.frame(3, 9, 16, 16, "x")
    rain(cv, r, 26, "m", "I", 3, (4, 10, 18, 24))
    # drips falling into a basin, a wet patch
    for y in (6, 11, 17, 24, 30):
        cv.put(32, y, "m")
        cv.put(32, y + 1, "I")
    cv.rect(0, 40, W, 8, "b")
    cv.hl(0, W - 1, 40, "w")
    cv.ellipse(32, 44, 10, 2.5, "E")
    cv.rect(27, 37, 11, 5, "B")
    cv.hl(27, 37, 37, "P")
    cv.hl(28, 36, 38, "i")
    cv.pts([(30, 38), (34, 38)], "I")
    cv.vl(37, 38, 41, "b")
    # Ruhua up the ladder pressing a board over the leak
    for y in range(6, 46, 3):
        cv.hl(44, 48, y, "B")
    cv.vl(43, 4, 46, "b")
    cv.vl(49, 4, 46, "b")
    f = ruhua(arm="up", barm="down")
    f.c.rect(f.ox + 7, f.oy + 0, 8, 2, "P")
    f.c.hl(f.ox + 7, f.ox + 14, f.oy + 1, "B")
    f.place(cv, 46, 25, flip=True)
    cv.rect(26, 2, 10, 2, "P")


@scene("illus.ev.any.temple_lot")
def ev_temple_lot(cv, r):
    cv.rect(0, 0, W, 48, "x")
    for x in (2, 58):
        cv.rect(x, 0, 4, 40, "r")
        cv.vl(x, 0, 39, "R")
        cv.vl(x + 3, 0, 39, "d")
    # the dim shrine: a seated god in red robes, only a shape in the dark
    cv.rect(18, 3, 28, 17, "q")
    cv.rect(16, 0, 32, 3, "r")
    for x in range(17, 47, 3):
        cv.put(x, 3, "Y")
    cv.rect(29, 5, 6, 3, "Q")              # tall hat
    cv.hl(27, 36, 8, "Q")
    cv.rect(30, 9, 4, 4, "g")              # face, gilded, no features
    cv.poly([(24, 20), (26, 13), (38, 13), (40, 20)], "d")
    cv.vl(32, 14, 19, "r")
    # altar with candles and an incense burner, smoke
    cv.rect(12, 20, 40, 3, "B")
    cv.hl(12, 51, 20, "P")
    cv.rect(12, 23, 40, 9, "r")
    cv.frame(14, 24, 36, 7, "Y")
    for x in (16, 47):
        cv.rect(x, 15, 2, 5, "R")
        cv.put(x, 14, "y")
        cv.put(x + 1, 14, "e")
        cv.put(x, 13, "e")
    cv.rect(28, 16, 8, 4, "g")
    cv.hl(27, 36, 16, "Y")
    for k, x in enumerate((30, 32, 34)):
        cv.vl(x, 12, 15, "B")
        cv.put(x, 11, "R")
    for y in range(1, 11):
        if y % 3:
            cv.put(32 + int(2 * math.sin(y * 0.7)), y, "m" if y > 5 else "s")
    cv.rect(0, 32, W, 16, "f")
    cv.hl(0, W - 1, 32, "E")
    cv.rect(23, 42, 14, 3, "r")
    cv.hl(23, 36, 42, "R")
    f = ruhua(arm="up", barm="up", body="kneel", back=True)
    f.c.rect(f.ox + 6, f.oy + 0, 3, 4, "B")
    f.c.vl(f.ox + 8, f.oy + 0, f.oy + 3, "b")
    f.c.pts([(f.ox + 6, f.oy - 1), (f.ox + 7, f.oy - 2), (f.ox + 8, f.oy - 1)], "P")
    f.place(cv, 30, 44)


@scene("illus.ev.any.wheel_go")
def ev_wheel_go(cv, r):
    planks(cv, 0, 0, W, 48, base="b", seam="w", lit="b", step=8)
    cv.rect(0, 40, W, 8, "w")
    cv.hl(0, W - 1, 40, "B")
    # a big spinning wheel on a post, motion arcs around it
    cv.rect(31, 38, 3, 4, "x")
    prize_wheel(cv, 32.5, 21.5, 15, cols=("r", "S", "Q", "Y", "r", "S", "Q", "j"), rim="x", turn=0.07)
    for a in range(0, 360, 6):
        if 200 < a < 280:
            x = 32.5 + 17.5 * math.cos(math.radians(a))
            y = 21.5 + 17.5 * math.sin(math.radians(a))
            cv.put(int(x), int(y), "P")
    for a in range(20, 80, 6):
        x = 32.5 + 17.5 * math.cos(math.radians(a))
        y = 21.5 + 17.5 * math.sin(math.radians(a))
        cv.put(int(x), int(y), "P")
    # Ruhua's hand has just set it going
    f = ruhua(arm="point", barm="down")
    f.place(cv, 10, 46)


# --------------------------------------------------------------------------- goals


@scene("illus.gl.1938.keep_shop")
def gl_keep_shop(cv, r):
    sky(cv, "day", 12)
    cv.ellipse(56, 4, 4, 4, "W")
    cv.ellipse(56, 4, 3, 3, "y")
    roof(cv, -3, 66, 4, 5)
    cv.rect(0, 9, W, 8, "h")
    cv.hl(0, W - 1, 9, "P")
    lattice(cv, 8, 11, 8, 4)
    lattice(cv, 48, 11, 8, 4)
    cv.rect(0, 17, W, 2, "x")
    cv.rect(0, 19, W, 1, "b")
    planks(cv, 0, 20, 22, 20, base="w", seam="x", lit="b", step=4)
    planks(cv, 42, 20, 22, 20, base="w", seam="x", lit="b", step=4)
    cv.rect(22, 20, 20, 20, "x")             # the open door, counter inside
    cv.rect(23, 28, 18, 12, "b")
    cv.hl(23, 40, 28, "B")
    cv.rect(26, 10, 12, 7, "Q")              # blank shop board
    cv.frame(26, 10, 12, 7, "Y")
    ground(cv, 40, "stone")
    cv.rect(18, 40, 28, 2, "m")
    # Ruhua sweeping the step in the morning
    f = ruhua(arm="low", barm="fwd")
    f.item("broom")
    f.place(cv, 30, 45)


@scene("illus.gl.1938.levy_clear")
def gl_levy_clear(cv, r):
    planks(cv, 0, 0, W, 30, base="b", seam="w", lit="b", step=9)
    cv.rect(0, 30, W, 18, "B")
    cv.hl(0, W - 1, 30, "P")
    cv.hl(0, W - 1, 31, "p")
    # a receipt spike full of settled slips, each with its red seal
    cv.rect(10, 38, 10, 3, "x")
    cv.hl(10, 19, 38, "b")
    cv.vl(15, 14, 37, "m")
    cv.put(15, 13, "h")
    for k, y in enumerate((18, 23, 28, 33)):
        x = 10 + (k % 2)
        cv.rect(x, y, 10, 4, "S" if k % 2 else "h")
        cv.hl(x + 1, x + 6, y + 1, "s")
        cv.rect(x + 7, y + 1, 2, 2, "r")
        cv.put(15, y + 1, "m")
    # closed ledger tied with string, abacus, an empty tray
    cv.rect(26, 33, 14, 7, "i")
    cv.hl(26, 39, 33, "I")
    cv.vl(27, 34, 39, "h")
    cv.vl(33, 33, 39, "B")
    abacus(cv, 44, 32, 14, 6)
    cv.rect(24, 42, 14, 3, "g")
    cv.hl(24, 37, 42, "Y")
    cv.hl(25, 36, 43, "b")


@scene("illus.gl.1938.low_heat")
def gl_low_heat(cv, r):
    sky(cv, "warm", 22)
    # far roofs, a chimney whose smoke goes straight up: no wind tonight
    for x0, x1, y in ((0, 18, 12), (19, 40, 10), (41, 63, 13)):
        roof(cv, x0, x1, y, 3)
        cv.rect(x0, y + 3, x1 - x0 + 1, 22 - y - 3, "h")
        cv.vl(x1, y + 3, 21, "P")
    cv.rect(30, 5, 2, 5, "t")
    for y in range(0, 5):
        cv.put(30 + (y % 2), y, "s")
    bridge(cv, 14, 50, 22, 31)
    water(cv, 31, base="i", dark="n", lite="I")
    # still reflection of the bridge arch
    for y in range(32, 40):
        for x in range(24, 41):
            if cv.get(x, y) == "i" and (x + y) % 3 == 0:
                cv.put(x, y, "n")
    willow(cv, 6, 30, 22)
    wupeng(cv, 40, 40, 18, facing="l")


@scene("illus.gl.1938.redeem_cabinet")
def gl_redeem_cabinet(cv, r):
    cv.rect(0, 0, W, 48, "b")
    # close on the cabinet doors: glass with treasures, brass lock, key turning
    cv.rect(6, 0, 52, 48, "w")
    cv.vl(6, 0, 47, "b")
    cv.rect(9, 3, 21, 26, "n")
    cv.rect(34, 3, 21, 26, "n")
    cv.vl(31, 0, 47, "x")
    cv.vl(32, 0, 47, "k")
    for gx in (9, 34):
        cv.hl(gx, gx + 20, 15, "b")
        cv.hl(gx, gx + 20, 28, "b")
    cv.pts([(12, 11), (13, 10), (14, 10), (15, 11), (14, 12), (13, 12)], "Y")
    cv.rect(19, 10, 6, 4, "Y")
    cv.hl(19, 24, 10, "y")
    cv.rect(38, 10, 3, 5, "j")
    cv.pts([(45, 11), (46, 12), (47, 12), (48, 11), (49, 12), (50, 12)], "h")
    cv.pts([(13, 24), (14, 23), (15, 23), (16, 24), (15, 25), (14, 25)], "m")
    cv.rect(44, 22, 6, 5, "r")
    cv.hl(44, 49, 22, "R")
    for k in range(4):
        cv.put(11 + k, 8 - k, "m")
        cv.put(36 + k, 26 - k, "i")
    # the lock plate and the key, a red cord tied on: redeemed
    cv.rect(29, 18, 6, 8, "Y")
    cv.frame(29, 18, 6, 8, "g")
    # keyhole: a round head over a slot, symmetric so it never reads as a digit
    cv.rect(30, 20, 3, 2, "k")
    cv.vl(31, 22, 24, "k")
    cv.rect(35, 21, 6, 2, "g")
    cv.hl(35, 40, 21, "Y")
    cv.ellipse(43, 22, 2.5, 2.5, "g")
    cv.put(43, 22, "w")
    cv.line(43, 25, 41, 32, "r")
    cv.line(44, 25, 46, 31, "R")
    # drawers below
    for dy in (31, 39):
        cv.frame(9, dy, 46, 7, "x")
        cv.hl(10, 54, dy + 1, "b")
        cv.pts([(31, dy + 3), (32, dy + 3)], "Y")


@scene("illus.gl.1938.storeroom")
def gl_storeroom(cv, r):
    cv.rect(0, 0, W, 48, "P")
    cv.rect(0, 40, W, 8, "b")
    cv.hl(0, W - 1, 40, "w")
    # the storeroom's double doors, shut fast with a big padlock
    cv.rect(14, 4, 36, 36, "x")
    planks(cv, 16, 6, 16, 34, base="w", seam="x", lit="b", step=4)
    planks(cv, 32, 6, 16, 34, base="w", seam="x", lit="b", step=4)
    cv.vl(31, 6, 39, "k")
    for y in (10, 33):
        cv.rect(16, y, 32, 2, "g")
        cv.hl(16, 47, y, "Y")
    cv.rect(27, 19, 10, 2, "m")
    cv.hl(27, 36, 19, "h")
    cv.rect(28, 21, 8, 7, "Y")
    cv.frame(28, 21, 8, 7, "g")
    cv.put(31, 23, "k")
    cv.vl(31, 24, 25, "k")
    cv.pts([(29, 22), (30, 22)], "y")
    # key ring hanging on a nail beside the door, a tag on it
    cv.put(55, 12, "k")
    cv.ellipse(55, 16, 2.5, 2.5, "g", test=lambda x, y, d: d > 0.35)
    cv.vl(54, 18, 22, "Y")
    cv.pts([(53, 22), (55, 21)], "Y")
    cv.rect(57, 17, 3, 4, "h")
    cv.put(58, 18, "s")


@scene("illus.gl.1938.zhouma_page")
def gl_zhouma_page(cv, r):
    cv.rect(0, 0, W, 48, "b")
    for y in range(2, 48, 6):
        cv.hl(0, W - 1, y, "w")
    # the open dossier folder
    cv.rect(4, 4, 56, 40, "B")
    cv.rect(6, 5, 25, 37, "h")
    cv.rect(33, 5, 25, 37, "p")
    cv.vl(32, 4, 43, "b")
    # left page: a little sketched likeness of an old woman, hair in a bun
    cv.rect(10, 9, 16, 16, "S")
    cv.frame(10, 9, 16, 16, "P")
    cv.poly([(11, 25), (13, 21), (23, 21), (25, 25)], "B")
    cv.vl(18, 21, 24, "b")
    cv.ellipse(18.5, 16.5, 3.6, 4.2, "P")
    cv.ellipse(18.5, 13.5, 3.8, 2.2, "f")
    cv.ellipse(22.5, 13, 2, 2, "f")
    cv.put(22, 12, "t")
    cv.pts([(15, 14), (15, 15)], "f")
    cv.vl(21, 16, 19, "B")
    for y in (29, 32, 35, 38):
        cv.hl(10, 26 - (y % 4), y, "s")
    # right page: torn fragments laid together, the last one being fitted
    for x, y, w, h in ((36, 9, 9, 8), (46, 9, 9, 9), (36, 18, 10, 9)):
        cv.rect(x, y, w, h, "S")
        cv.frame(x, y, w, h, "P")
        for yy in range(y + 2, y + h - 1, 2):
            cv.hl(x + 2, x + w - 3, yy, "s")
    cv.rect(48, 22, 9, 9, "S")
    cv.frame(48, 22, 9, 9, "P")
    for yy in (24, 26, 28):
        cv.hl(50, 54, yy, "s")
    cv.rect(52, 28, 2, 2, "r")
    cv.pts([(47, 31), (48, 32), (49, 32)], "x")
    cv.put(57, 21, "B")
    cv.line(52, 33, 58, 40, "B")
    cv.put(52, 33, "k")


@scene("illus.gl.1939.cabinet_free")
def gl_cabinet_free(cv, r):
    cv.rect(0, 0, W, 34, "P")
    cv.rect(0, 34, W, 14, "b")
    cv.hl(0, W - 1, 34, "w")
    # a winter window with snow, light falling across the floor
    cv.rect(4, 6, 14, 16, "m")
    cv.frame(3, 5, 16, 18, "w")
    cv.vl(10, 6, 21, "w")
    cv.hl(4, 17, 13, "w")
    snowfall(cv, r, 14, (4, 6, 18, 22), cols=("W", "h"))
    cv.hl(4, 17, 21, "W")
    light_poly(cv, [(4, 34), (18, 34), (30, 48), (10, 48)], LIGHT)
    # the jewellery cabinet, shut and locked, plum blossom on top
    x0, x1, t = 28, 54, 16
    cv.rect(x0 - 1, t, x1 - x0 + 3, 2, "x")
    cv.rect(x0, t + 2, x1 - x0 + 1, 44 - t - 2, "w")
    cv.vl(x0, t + 2, 43, "b")
    cv.rect(x0 + 2, t + 4, 11, 11, "n")
    cv.rect(x0 + 14, t + 4, 11, 11, "n")
    cv.hl(x0 + 2, x1 - 2, t + 9, "b")
    cv.pts([(x0 + 4, t + 7), (x0 + 5, t + 6), (x0 + 6, t + 6), (x0 + 7, t + 7)], "Y")
    cv.rect(x0 + 17, t + 6, 4, 3, "Y")
    cv.rect(x0 + 5, t + 11, 2, 3, "j")
    cv.pts([(x0 + 17, t + 12), (x0 + 19, t + 12), (x0 + 21, t + 12)], "h")
    for k in range(3):
        cv.put(x0 + 3 + k, t + 8 - k, "m")
    cv.rect(x0 + 12, t + 8, 3, 4, "Y")
    cv.put(x0 + 13, t + 10, "k")
    for dy in (t + 16, t + 22):
        cv.frame(x0 + 2, dy, x1 - x0 - 3, 5, "x")
        cv.pts([(41, dy + 2), (42, dy + 2)], "Y")
    plum_vase(cv, 46, t - 5)


@scene("illus.gl.1939.clear_books")
def gl_clear_books(cv, r):
    planks(cv, 0, 0, W, 30, base="b", seam="w", lit="b", step=9)
    # a red diamond of new-year paper on the wall, blank
    cv.poly([(32, 3), (40, 11), (32, 19), (24, 11)], "r")
    cv.poly([(32, 5), (38, 11), (32, 17), (26, 11)], "R")
    cv.poly([(32, 7), (36, 11), (32, 15), (28, 11)], "r")
    lantern_red(cv, 8, 9, lit=True)
    lantern_red(cv, 56, 9, lit=True)
    cv.rect(0, 30, W, 18, "B")
    cv.hl(0, W - 1, 30, "P")
    # the year's ledger closed and tied, abacus cleared, coins counted into stacks
    cv.rect(8, 33, 18, 9, "i")
    cv.hl(8, 25, 33, "I")
    cv.vl(9, 34, 41, "h")
    cv.vl(10, 34, 41, "S")
    cv.hl(8, 25, 37, "B")
    cv.rect(16, 36, 3, 3, "r")
    abacus(cv, 30, 34, 16, 7)
    for x in range(31, 45, 2):
        cv.put(x, 35, "B")
        cv.put(x, 37, "x")
        cv.put(x, 38, "x")
        cv.put(x, 39, "B")
    for k, x in enumerate((49, 53, 57)):
        coins(cv, x, 41, 4)


@scene("illus.gl.1939.debt_paid")
def gl_debt_paid(cv, r):
    sky(cv, "winter", 10)
    roof(cv, -3, 66, 2, 5)
    planks(cv, 0, 7, W, 33, base="w", seam="x", lit="b", step=4)
    cv.rect(0, 7, W, 2, "x")
    cv.rect(20, 10, 3, 22, "r")
    cv.rect(42, 10, 3, 22, "r")
    cv.rect(24, 9, 17, 3, "r")
    cv.rect(0, 40, W, 8, "h")
    cv.hl(0, W - 1, 40, "m")
    snowcap(cv, (0, 0, W, 10), "W", under=("m", "h"))
    # Ruhua hands over the money pouch; the creditor takes it, book under his arm
    f = ruhua(arm="fwd", barm="down")
    f.c.rect(f.ox + 12, f.oy + 6, 3, 3, "i")
    f.c.put(f.ox + 13, f.oy + 5, "I")
    f.c.put(f.ox + 12, f.oy + 7, "I")
    f.place(cv, 22, 45)
    c = Fig("felt", "gown", C_BLACK, hatc=C_BLACK, arm="fwd", barm="hold")
    c.place(cv, 39, 45, flip=True)
    cv.rect(43, 33, 4, 4, "i")
    cv.hl(43, 46, 33, "I")
    snowfall(cv, r, 16, (0, 0, W, 40), cols=("W", "h"))


@scene("illus.gl.1939.gate_passed")
def gl_gate_passed(cv, r):
    # looking out through the gate tunnel: dark stone, bright snowy country beyond
    cv.rect(0, 0, W, 48, "q")
    for y in range(0, 48, 4):
        cv.hl(0, W - 1, y, "Q")
        off = 0 if (y // 4) % 2 else 4
        for x in range(off, W, 8):
            cv.vl(x, y, y + 3, "Q")
    cv.ellipse(32, 20, 17, 17, "h")
    cv.rect(15, 20, 35, 28, "h")
    cv.rect(15, 0, 35, 4, "q")
    cv.poly([(15, 20), (49, 20), (49, 24), (15, 24)], "m")
    cv.rect(15, 24, 35, 24, "W")
    cv.poly([(28, 24), (36, 24), (44, 48), (20, 48)], "h")
    for x, y, h in ((20, 26, 7), (44, 25, 8)):
        cv.vl(x, y - h, y, "b")
        cv.line(x, y - h + 2, x - 2, y - h, "b")
        cv.line(x, y - h + 3, x + 2, y - h + 1, "b")
    cv.rect(0, 40, W, 8, "f")
    cv.poly([(15, 40), (49, 40), (56, 48), (8, 48)], "m")
    # the arch's lit edge
    for y in range(4, 40):
        if cv.get(14, y) == "q":
            cv.put(14, y, "t")
    # sentries left behind in the dark, Ruhua walking out into the light
    for x, fl in ((8, False), (56, True)):
        s = Fig("mil", "coat", C_NIGHT, C_NIGHT, SKIN_DIM, hatc=C_NIGHT, arm="down", barm="down")
        s.place(cv, x, 45, flip=fl, outline="K")
    f = ruhua(arm="down", barm="down", back=True, body="jacket_walk")
    f.item("bundle", "B")
    f.place(cv, 32, 41)
    snowfall(cv, r, 12, (15, 4, 50, 24), cols=("W",))


@scene("illus.gl.1939.quiet_year")
def gl_quiet_year(cv, r):
    sky(cv, "deep", 48)
    stars(cv, r, 12, (0, 0, 64, 12))
    moon(cv, 12, 6, 3)
    # snowy rooftops of the lane, one shop with its lanterns lit
    for x0, x1, y in ((-3, 20, 18), (44, 66, 16)):
        roof(cv, x0, x1, y, 4, "q", "Q", "K", "K")
        cv.rect(max(0, x0), y + 4, min(63, x1) - max(0, x0) + 1, 40 - y - 4, "E")
    roof(cv, 18, 46, 13, 5, "q", "Q", "K", "K")
    cv.rect(18, 18, 29, 22, "t")
    cv.rect(18, 26, 29, 14, "w")
    for x in range(20, 46, 4):
        cv.vl(x, 26, 39, "x")
    lattice(cv, 26, 19, 12, 5, frame="x", fill="e", bar="g")
    snowcap(cv, (0, 0, W, 30), "W", under=("K", "Q", "n", "m", "s"), skip_cols=("y", "e", "h", "W", "m", "s"))
    cv.rect(0, 40, W, 8, "m")
    cv.hl(0, W - 1, 40, "h")
    for x in (21, 43):
        lantern_red(cv, x, 28, lit=True)
    cv.rect(26, 34, 3, 5, "r")
    cv.rect(36, 34, 3, 5, "r")
    light_poly(cv, [(18, 40), (46, 40), (52, 47), (12, 47)], WARM)
    snowfall(cv, r, 18, (0, 0, W, 40), cols=("W", "h"))


@scene("illus.gl.1939.rice_ready")
def gl_rice_ready(cv, r):
    cv.rect(0, 0, W, 34, "P")
    for _ in range(16):
        cv.put(r.randrange(0, W), r.randrange(0, 34), "B")
    cv.rect(0, 34, W, 14, "b")
    cv.hl(0, W - 1, 34, "w")
    # a full rice crock with a red paper diamond, two sacks, the measure on top
    cv.ellipse(20, 30, 11, 12, "B")
    cv.ellipse(20, 30, 11, 12, "b", test=lambda x, y, d: x > 22 and d > 0.5)
    cv.rect(11, 17, 18, 3, "B")
    cv.hl(11, 28, 17, "P")
    cv.ellipse(20, 17, 8, 2, "W")
    cv.pts([(16, 16), (19, 15), (23, 16)], "h")
    cv.poly([(20, 23), (25, 28), (20, 33), (15, 28)], "r")
    cv.poly([(20, 25), (23, 28), (20, 31), (17, 28)], "R")
    cv.rect(17, 13, 6, 4, "w")
    cv.hl(17, 22, 13, "b")
    for x, y in ((36, 26), (46, 27), (40, 19)):
        sack(cv, x, y, 9, 10, "P")
    cv.pts([(54, 37), (55, 38), (56, 37)], "W")


@scene("illus.gl.1940.cash_left")
def gl_cash_left(cv, r):
    planks(cv, 0, 0, W, 30, base="b", seam="w", lit="b", step=9)
    cv.rect(0, 30, W, 18, "B")
    cv.hl(0, W - 1, 30, "P")
    # an open cash box, a little left in it, an abacus and a string of cash
    cash_box(cv, 18, 31, 22, 9)
    cv.rect(21, 34, 6, 2, "s")
    cv.hl(21, 26, 34, "h")
    abacus(cv, 44, 34, 15, 6)
    for k in range(9):
        cv.put(4 + k, 39 + (k % 2), "g")
        cv.put(4 + k, 40 - (k % 2), "Y")
    cv.hl(3, 13, 41, "b")
    oil_lamp(cv, 6, 21)
    glow(cv, 8.5, 24, 7, 0.4)
    cv.put(8, 23, "y")
    cv.put(8, 24, "W")


@scene("illus.gl.1940.census_clear")
def gl_census_clear(cv, r):
    cv.rect(0, 0, W, 48, "B")
    for y in range(3, 48, 7):
        cv.hl(0, W - 1, y, "b")
    # the household register, stamped with a large red seal; ink pad and brush
    cv.rect(12, 8, 30, 34, "i")
    cv.rect(14, 9, 27, 32, "h")
    cv.vl(14, 9, 40, "P")
    for y in range(13, 30, 3):
        cv.hl(17, 37, y, "s")
        cv.vl(17 + (y % 7), y, y + 1, "s")
    cv.rect(27, 28, 10, 10, "r")
    cv.frame(28, 29, 8, 8, "R")
    cv.pts([(30, 31), (33, 31), (31, 33), (32, 34), (30, 35), (33, 35)], "R")
    cv.rect(46, 30, 10, 7, "r")
    cv.frame(46, 30, 10, 7, "g")
    cv.rect(47, 31, 8, 5, "d")
    cv.line(46, 12, 58, 24, "B")
    cv.line(47, 12, 59, 24, "b")
    cv.pts([(58, 25), (59, 25), (59, 26)], "k")
    cv.rect(48, 40, 9, 5, "g")       # the seal itself
    cv.hl(48, 56, 40, "Y")
    cv.rect(50, 37, 5, 3, "e")


@scene("illus.gl.1940.heat_quiet")
def gl_heat_quiet(cv, r):
    sky(cv, "day", 22)
    cv.pts([(40, 6), (41, 5), (42, 6), (48, 9), (49, 8), (50, 9)], "q")
    for x0, x1, y in ((0, 22, 13), (23, 44, 11), (45, 63, 14)):
        roof(cv, x0, x1, y, 3)
        cv.rect(x0, y + 3, x1 - x0 + 1, 22 - y - 3, "h")
        cv.vl(x1, y + 3, 21, "P")
        cv.rect(x0 + 4, y + 5, 3, 3, "b")
    cv.rect(0, 22, W, 2, "m")
    water(cv, 24, base="j", dark="f", lite="J")
    willow(cv, 8, 26, 24, leaf="l", dark="J")
    willow(cv, 58, 26, 20, leaf="l", dark="J")
    wupeng(cv, 26, 40, 20)
    bm = Fig("straw", "jacket", C_INDIGO, C_DKGREY, hatc=C_TAN, arm="hold", barm="hold")
    bm.place(cv, 27, 37)
    cv.line(31, 22, 22, 44, "b")


@scene("illus.gl.1940.levy_done")
def gl_levy_done(cv, r):
    planks(cv, 0, 0, W, 30, base="b", seam="w", lit="b", step=9)
    # the stamped receipt pinned to the post, the paid string of cash on the counter
    cv.rect(20, 3, 22, 26, "S")
    cv.frame(20, 3, 22, 26, "P")
    for x in range(24, 40, 3):
        for y in range(7, 21):
            if (x * 5 + y * 3) % 7 < 5:
                cv.put(x, y, "t")
    cv.rect(31, 20, 8, 7, "r")
    cv.frame(32, 21, 6, 5, "R")
    cv.put(30, 4, "k")
    cv.put(31, 3, "s")
    cv.rect(0, 30, W, 18, "B")
    cv.hl(0, W - 1, 30, "P")
    for k in range(16):
        cv.put(12 + k * 2, 37 + (k % 2), "Y")
        cv.put(13 + k * 2, 37 + (k % 2), "g")
    cv.hl(10, 46, 39, "r")
    cv.rect(48, 34, 8, 6, "w")
    cv.hl(48, 55, 34, "b")
    cv.rect(50, 32, 4, 2, "g")


@scene("illus.gl.1940.ruhua_well")
def gl_ruhua_well(cv, r):
    cv.rect(0, 0, W, 48, "P")
    for _ in range(16):
        cv.put(r.randrange(0, W), r.randrange(0, 36), "B")
    cv.rect(0, 36, W, 12, "b")
    cv.hl(0, W - 1, 36, "w")
    # spring window, a blooming pot plant, sunlight on her
    cv.rect(34, 5, 22, 18, "h")
    cv.frame(33, 4, 24, 20, "w")
    cv.vl(45, 5, 22, "w")
    cv.ellipse(40, 21, 7, 4, "l")
    cv.ellipse(52, 20, 6, 4, "J")
    for x in range(36, 55, 4):
        cv.put(x, 9 + (x % 3), "l")
    light_poly(cv, [(34, 23), (56, 23), (42, 48), (12, 48)], WARM)
    cv.rect(52, 26, 6, 6, "B")
    cv.hl(52, 57, 26, "P")
    for px, py in ((52, 22), (55, 21), (57, 23), (54, 24)):
        cv.line(55, 26, px, py, "G")
    cv.pts([(52, 21), (55, 20), (57, 22)], "R")
    # Ruhua at the little table with a bowl of tea, sitting upright and well
    cv.rect(20, 32, 12, 2, "B")
    cv.hl(20, 31, 32, "P")
    cv.vl(21, 34, 41, "b")
    cv.vl(30, 34, 41, "b")
    cv.rect(25, 30, 3, 2, "h")
    cv.put(26, 29, "m")
    f = ruhua(arm="hold", barm="down", body="sit")
    f.place(cv, 12, 43)
    stool(cv, 8, 40, "b")


@scene("illus.gl.1940.stand_rules")
def gl_stand_rules(cv, r):
    sky(cv, "day", 12)
    roof(cv, -3, 66, 3, 5)
    cv.rect(0, 8, W, 32, "h")
    cv.hl(0, W - 1, 8, "P")
    cv.rect(18, 9, 28, 7, "Q")       # the shop's own board, blank, kept up
    cv.frame(18, 9, 28, 7, "Y")
    planks(cv, 0, 18, 18, 22, base="w", seam="x", lit="b", step=4)
    planks(cv, 46, 18, 18, 22, base="w", seam="x", lit="b", step=4)
    cv.rect(18, 18, 28, 22, "x")
    cv.rect(19, 28, 26, 12, "b")
    cv.hl(19, 44, 28, "B")
    notice(cv, 50, 20, 10, 14, paper="S", lines="t")
    cv.rect(56, 30, 2, 2, "r")
    ground(cv, 40, "stone")
    for x in (1, 57):
        willow(cv, x, 22, 18, leaf="l", dark="J", lean=0.3)
    # a spring wind down the street; Ruhua standing square in her doorway all the same
    cv.pts([(10, 33), (47, 31), (30, 37), (52, 36)], "l")
    f = ruhua(arm="down", barm="down")
    f.place(cv, 32, 44)


# --------------------------------------------------------------------------- night cards


@scene("illus.nt.accounts")
def nt_accounts(cv, r):
    planks(cv, 0, 0, W, 34, base="q", seam="Q", lit="q", step=8)
    cv.rect(0, 34, W, 14, "Q")
    cv.rect(46, 5, 12, 10, "n")
    cv.frame(45, 4, 14, 12, "x")
    cv.vl(51, 5, 14, "x")
    cv.hl(46, 57, 9, "x")
    moon(cv, 55, 7, 1.5)
    # Ruhua at the desk late at night, brush in hand, the month's ledger open
    f = ruhua(arm="fwd", barm="fwd", body="sit", skin=SKIN)
    f.item("brush")
    f.place(cv, 16, 37)
    cv.rect(8, 31, 48, 3, "B")
    cv.hl(8, 55, 31, "P")
    cv.rect(10, 34, 3, 12, "b")
    cv.rect(51, 34, 3, 12, "b")
    cv.rect(8, 34, 48, 2, "w")
    ledger(cv, 23, 27, 12, 4)
    abacus(cv, 37, 26, 10, 5)
    oil_lamp(cv, 48, 23)
    glow(cv, 50.5, 26, 8, 0.45)
    cv.put(50, 25, "y")
    cv.put(50, 26, "W")


@scene("illus.nt.backdoor")
def nt_backdoor(cv, r):
    sky(cv, "deep", 10)
    moon(cv, 10, 4, 2)
    house(cv, -3, 66, 3, 42, kind="wall", night=True, r=r)
    cv.rect(0, 42, W, 6, "q")
    cv.hl(0, W - 1, 42, "f")
    cv.rect(10, 16, 14, 26, "Q")
    cv.rect(12, 18, 10, 24, "w")
    cv.rect(12, 18, 5, 24, "g")
    cv.vl(17, 18, 41, "x")
    cv.poly([(12, 42), (22, 42), (30, 48), (8, 48)], "E")
    f = ruhua(arm="hold", barm="down", skin=SKIN_DIM, top=("I", "i", "n", "Q"))
    f.c.rect(f.ox + 11, f.oy + 7, 1, 2, "h")
    f.c.put(f.ox + 11, f.oy + 6, "y")
    f.place(cv, 15, 44)
    # a man with no name holding out a wrapped bundle, his handcart behind
    cv.rect(44, 33, 16, 5, "w")
    cv.hl(44, 59, 33, "b")
    cv.ellipse(48, 40, 3, 3, "x")
    cv.ellipse(56, 40, 3, 3, "x")
    cv.put(48, 40, "b")
    cv.put(56, 40, "b")
    cv.rect(46, 29, 5, 4, "i")
    cv.rect(52, 30, 6, 3, "B")
    m = Fig("felt", "gown", C_NIGHT, skin=SKIN_DIM, hatc=C_NIGHT, arm="fwd", barm="fwd")
    m.c.rect(m.ox + 10, m.oy + 5, 5, 4, "j")
    m.c.hl(m.ox + 10, m.ox + 14, m.oy + 5, "J")
    m.c.put(m.ox + 12, m.oy + 4, "j")
    m.place(cv, 33, 45, flip=True, outline="K")


@scene("illus.nt.early_sleep")
def nt_early_sleep(cv, r):
    sky(cv, "deep", 48)
    stars(cv, r, 14, (0, 0, 64, 14))
    moon(cv, 50, 6, 3)
    # the shopfront closed up for the night: every door plank in place
    roof(cv, -3, 66, 12, 5, "q", "Q", "K", "K")
    cv.rect(0, 17, W, 6, "t")
    cv.hl(0, W - 1, 17, "E")
    lattice(cv, 8, 18, 8, 4, frame="q", fill="Q", bar="f")
    lattice(cv, 46, 18, 8, 4, frame="q", fill="Q", bar="f")
    cv.rect(0, 23, W, 2, "Q")
    for k, x in enumerate(range(2, 62, 5)):
        cv.rect(x, 25, 5, 18, "w" if k % 2 else "b")
        cv.vl(x + 4, 25, 42, "x")
        cv.hl(x, x + 4, 25, "B" if k % 2 == 0 else "b")
        cv.put(x + 2, 33, "x")
    cv.rect(0, 25, 2, 18, "x")
    cv.rect(62, 25, 2, 18, "x")
    cv.hl(0, W - 1, 42, "Q")
    cv.rect(0, 43, W, 5, "f")
    lantern_red(cv, 32, 20, lit=False, small=True)
    # a cat asleep on the step
    cv.rect(40, 41, 5, 2, "E")
    cv.pts([(45, 41), (44, 40), (45, 40)], "E")
    cv.put(39, 42, "E")
    # moonlight on the planks
    light_poly(cv, [(30, 25), (64, 25), (64, 43), (44, 43)], LIGHT)


@scene("illus.nt.telegraph")
def nt_telegraph(cv, r):
    # inside the post and telegraph agency at night
    cv.rect(0, 0, W, 30, "B")
    cv.rect(0, 0, W, 2, "w")
    for _ in range(14):
        cv.put(r.randrange(0, W), r.randrange(2, 30), "b")
    # window: night outside, a pole with wires
    cv.rect(4, 4, 18, 14, "n")
    for x in range(4, 22):
        cv.put(x, 8 + int(1.5 * math.sin(math.pi * (x - 4) / 18.0)), "t")
        cv.put(x, 11 + int(1.5 * math.sin(math.pi * (x - 4) / 18.0)), "t")
    cv.vl(17, 5, 17, "Q")
    cv.hl(14, 20, 7, "Q")
    cv.put(8, 6, "m")
    cv.frame(3, 3, 20, 16, "w")
    cv.vl(13, 4, 17, "w")
    # pigeonholes for letters
    cv.rect(40, 4, 20, 14, "w")
    for x in range(41, 59, 4):
        for y in range(5, 17, 4):
            cv.rect(x, y, 3, 3, "x")
            if (x + y) % 3 == 0:
                cv.rect(x, y + 1, 3, 2, "h")
    # the clerk at the key behind the counter, Ruhua with her message
    clerk = Fig("cap", "gown", C_DKGREY, hatc=C_BLACK, arm="fwd", barm="down")
    clerk.place(cv, 28, 36)
    cv.rect(0, 30, W, 3, "B")
    cv.hl(0, W - 1, 30, "P")
    cv.rect(0, 33, W, 15, "w")
    for px in range(2, W, 12):
        cv.frame(px, 35, 10, 11, "b")
    cv.rect(32, 27, 7, 3, "g")
    cv.hl(33, 38, 26, "Y")
    cv.put(38, 25, "k")
    cv.put(37, 25, "k")
    cv.vl(31, 27, 29, "k")
    oil_lamp(cv, 12, 22)
    glow(cv, 14.5, 25, 7, 0.45)
    f = ruhua(arm="fwd", barm="down", back=True)
    f.item("paper", "S")
    f.place(cv, 50, 52, flip=True)


@scene("illus.nt.tidy")
def nt_tidy(cv, r):
    planks(cv, 0, 0, W, 40, base="w", seam="x", lit="w", step=8)
    for sy in (12, 25):
        cv.hl(0, W - 1, sy, "B")
        cv.hl(0, W - 1, sy + 1, "x")
    for k, x in enumerate(range(3, 62, 7)):
        kind = k % 3
        if kind == 0:
            cv.rect(x, 6, 4, 6, "h")
            cv.hl(x + 1, x + 2, 5, "h")
            cv.vl(x + 3, 6, 11, "m")
            cv.hl(x, x + 3, 8, "i")
        elif kind == 1:
            cv.rect(x, 8, 5, 4, "B")
            cv.hl(x, x + 4, 8, "P")
            cv.put(x + 2, 10, "Y")
        else:
            cv.rect(x, 9, 5, 3, "i")
            cv.hl(x, x + 4, 9, "I")
        cv.rect(x, 20, 5, 5, ("j", "B", "s")[k % 3])
        cv.hl(x, x + 4, 20, LIGHT[("j", "B", "s")[k % 3]])
    cv.rect(0, 40, W, 8, "b")
    cv.hl(0, W - 1, 40, "w")
    f = ruhua(arm="up", barm="down")
    f.c.line(f.ox + 11, f.oy + 3, f.ox + 13, f.oy - 1, "B")
    f.c.pts([(f.ox + 13, f.oy - 2), (f.ox + 14, f.oy - 2), (f.ox + 14, f.oy - 1), (f.ox + 12, f.oy - 2)], "P")
    f.place(cv, 28, 45)
    stool(cv, 42, 40, "B")
    cv.rect(42, 37, 5, 3, "s")
    cv.hl(42, 46, 37, "m")
    cv.put(44, 36, "h")
    oil_lamp(cv, 51, 32)
    glow(cv, 53.5, 35, 7, 0.45)
    cv.put(53, 34, "y")
    cv.put(53, 35, "W")


# --------------------------------------------------------------------------- news


@scene("illus.nw.lead")
def nw_lead(cv, r):
    sky(cv, "day", 6)
    wall(cv, 0, 4, 64, 38, "h", "P", r=r)
    roof(cv, -3, 66, 0, 4)
    # a doorway in shade, two people close together: one passes a word to the other
    cv.rect(26, 10, 22, 32, "x")
    cv.rect(28, 12, 18, 30, "w")
    cv.vl(26, 10, 41, "b")
    ground(cv, 42, "stone")
    m = Fig("felt", "gown", C_DKGREY, hatc=C_BLACK, arm="chest", barm="down")
    m.at(9, 4, "N")
    m.place(cv, 33, 45)
    f = ruhua(arm="down", barm="down")
    f.place(cv, 42, 45, flip=True)
    # a thin thread of attention: the street beyond, someone watching
    tiny(cv, 10, 44, top="E", head="q", skin="N", outline="k")
    cv.pts([(36, 27), (37, 26)], "N")


@scene("illus.nw.letter")
def nw_letter(cv, r):
    cv.rect(0, 0, W, 48, "b")
    for y in range(2, 48, 5):
        cv.hl(0, W - 1, y, "w")
    # an envelope with a red centre strip, the letter unfolded beside it
    cv.rect(8, 10, 20, 30, "S")
    cv.frame(8, 10, 20, 30, "P")
    cv.rect(14, 13, 8, 22, "r")
    cv.frame(15, 14, 6, 20, "R")
    cv.rect(24, 12, 3, 4, "i")
    cv.put(25, 13, "I")
    cv.rect(32, 6, 26, 34, "p")
    cv.frame(32, 6, 26, 34, "P")
    cv.vl(45, 6, 39, "P")
    for x in range(54, 34, -3):
        for y in range(9, 37):
            if (x * 7 + y * 3) % 6 < 4:
                cv.put(x, y, "t")
    cv.rect(35, 33, 3, 3, "r")
    cv.line(4, 44, 20, 42, "k")
    cv.pts([(3, 44), (4, 45)], "B")


@scene("illus.nw.paper")
def nw_paper(cv, r):
    cv.rect(0, 0, W, 48, "B")
    for y in range(3, 48, 6):
        cv.hl(0, W - 1, y, "b")
    # a folded newspaper: columns of grey type, a dark photograph block
    cv.poly([(4, 6), (44, 3), (48, 40), (8, 44)], "h")
    for k in range(5):
        x = 8 + k * 7
        for y in range(10 + (k == 0) * 0, 38):
            if (y % 2 == 0) and not (20 <= x <= 32 and 12 <= y <= 24):
                cv.hl(x + y // 12, x + 4 + y // 12, y, "s" if (y // 2 + k) % 5 else "E")
    cv.rect(20, 11, 13, 12, "E")
    cv.rect(22, 13, 9, 8, "m")
    cv.poly([(22, 18), (25, 15), (28, 17), (30, 15), (30, 20), (22, 20)], "t")
    cv.hl(22, 30, 19, "f")
    cv.hl(6, 44, 8, "k")
    # the cut-out clipping lying on top, scissors beside
    cv.rect(38, 22, 16, 14, "S")
    cv.frame(38, 22, 16, 14, "P")
    for y in range(25, 34, 2):
        cv.hl(40, 51, y, "s")
    cv.hl(40, 51, 24, "k")
    cv.rect(49, 31, 3, 3, "r")
    cv.line(52, 38, 60, 44, "m")
    cv.line(52, 44, 60, 38, "m")
    cv.ellipse(51, 37, 1.6, 1.6, "k")
    cv.ellipse(51, 45, 1.6, 1.6, "k")


@scene("illus.nw.price")
def nw_price(cv, r):
    cv.rect(0, 0, W, 48, "b")
    for x in range(0, W, 8):
        cv.vl(x, 0, 47, "w")
    # a steelyard weighing a sack of rice: hook, beam, sliding weight
    cv.vl(28, 0, 6, "k")
    cv.line(10, 9, 56, 5, "B")
    cv.line(10, 10, 56, 6, "g")
    for k in range(14, 56, 4):
        cv.put(k, 9 - (k - 10) * 4 // 46, "Y")
    cv.vl(22, 9, 16, "k")
    cv.vl(48, 7, 12, "k")
    cv.rect(46, 12, 5, 6, "q")
    cv.hl(46, 50, 12, "E")
    sack(cv, 16, 16, 12, 12, "P")
    # rice bins and coins on the counter below
    cv.rect(0, 34, W, 14, "w")
    cv.hl(0, W - 1, 34, "B")
    for bx in (34, 46):
        cv.rect(bx, 26, 10, 8, "B")
        cv.hl(bx, bx + 9, 26, "P")
        cv.ellipse(bx + 5, 26, 5, 2, "W")
    coins(cv, 8, 33, 4)
    coins(cv, 12, 33, 6)
    coins(cv, 58, 33, 3)


@scene("illus.nw.rumor")
def nw_rumor(cv, r):
    cv.rect(0, 0, W, 36, "t")
    for _ in range(20):
        cv.put(r.randrange(0, W), r.randrange(0, 36), "E")
    cv.rect(0, 36, W, 12, "E")
    cv.hl(0, W - 1, 36, "f")
    # the kitchen stove, a pot steaming
    cv.rect(34, 24, 28, 14, "P")
    cv.rect(34, 22, 28, 2, "s")
    cv.hl(34, 61, 22, "m")
    cv.vl(61, 24, 37, "B")
    cv.ellipse(46, 21, 6, 2.2, "q")
    cv.rect(42, 30, 7, 6, "K")
    cv.pts([(44, 35), (45, 34), (46, 35)], "R")
    for k, x in enumerate((44, 47, 50)):
        for y in range(4, 19):
            if (y + k) % 4:
                cv.put(x + int(1.5 * math.sin(y * 0.6 + k)), y, "m" if y > 9 else "s")
    cv.rect(56, 2, 4, 20, "P")
    # Zhou Ma with her ladle, leaning in to tell Ruhua what she heard
    zm = Fig("bun", "jacket", C_BROWN, C_DKGREY, hair="m", arm="point", barm="down")
    zm.c.rect(zm.ox + 4, zm.oy + 9, 5, 4, "S")
    zm.place(cv, 26, 45, flip=True)
    f = ruhua(arm="chest", barm="down")
    f.place(cv, 13, 45)


@scene("illus.nw.telegram")
def nw_telegram(cv, r):
    cv.rect(0, 0, W, 48, "b")
    for y in range(4, 48, 6):
        cv.hl(0, W - 1, y, "w")
    # a telegram form ruled into boxes, each holding a group of four marks
    cv.rect(6, 6, 34, 36, "p")
    cv.frame(6, 6, 34, 36, "P")
    cv.rect(6, 6, 34, 4, "d")
    cv.hl(8, 37, 8, "R")
    for row in range(5):
        for col in range(4):
            x = 9 + col * 7
            y = 13 + row * 5
            cv.frame(x, y, 6, 4, "B")
            for k in range(4):
                cv.put(x + 1 + k % 2 * 3 - (k // 2), y + 1 + k // 2 * 1, "k")
    # the code book open beside it, pencil, a telegraph key
    cv.rect(44, 10, 16, 20, "i")
    cv.rect(45, 11, 14, 18, "h")
    cv.vl(52, 11, 28, "P")
    for y in range(13, 28, 2):
        cv.hl(46, 50, y, "s")
        cv.hl(54, 57, y, "s")
    cv.line(42, 32, 50, 40, "Y")
    cv.put(50, 40, "k")
    cv.rect(44, 40, 14, 4, "g")
    cv.hl(45, 56, 39, "Y")
    cv.put(56, 38, "k")
    cv.put(55, 38, "k")


# --------------------------------------------------------------------------- prison


@scene("illus.pr.cell")
def pr_cell(cv, r):
    # stone block wall
    cv.rect(0, 0, W, 36, "f")
    for y in range(0, 36, 5):
        cv.hl(0, W - 1, y, "q")
        off = 0 if (y // 5) % 2 else 4
        for x in range(off, W, 8):
            cv.vl(x, y, y + 4, "q")
            cv.put(x + 1, y + 1, "E")
    cv.rect(0, 36, W, 12, "q")
    cv.hl(0, W - 1, 36, "E")
    # high barred window and the moonlight it throws onto wall and floor
    cv.rect(6, 4, 9, 7, "n")
    cv.put(12, 6, "h")
    cv.put(13, 6, "m")
    for x in (8, 11, 14):
        cv.vl(x, 4, 10, "K")
    cv.frame(5, 3, 11, 9, "K")
    light_poly(cv, [(6, 11), (15, 11), (34, 36), (40, 44), (24, 44), (14, 36)], LIGHT)
    # straw on the floor
    for _ in range(40):
        x, y = r.randrange(12, 40), r.randrange(38, 46)
        cv.line(x, y, x + r.choice((-1, 1, 2)), y, r.choice(("g", "B", "b")))
    # the prisoner sitting against the wall, knees up, head bowed
    pr = Fig("back", "hug", C_GREY, C_DKGREY, SKIN_DIM, arm="none", barm="down")
    pr.place(cv, 24, 41)
    # bars in the foreground on the right
    for x in range(42, 64, 5):
        cv.rect(x, 0, 2, 48, "q")
        cv.vl(x, 0, 47, "E")
    for y in (6, 40):
        cv.rect(40, y, 24, 2, "Q")
        cv.hl(40, 63, y, "E")
    cv.rect(47, 21, 4, 5, "Q")
    cv.put(48, 23, "s")


# --------------------------------------------------------------------------- pawn tickets


@scene("illus.tk.de196")
def tk_de196(cv, r):
    # dark counter wood, grain running across
    cv.rect(0, 0, W, 48, "w")
    for y in range(1, 48, 4):
        for x in range(0, W):
            if (x * 3 + y * 5) % 17 < 6:
                cv.put(x, y + ((x // 9) % 2), "x")
    X, Y = 20, 8
    pieces = [
        [(X, Y), (X + 13, Y), (X + 11, Y + 9), (X + 14, Y + 15), (X, Y + 17)],
        [(X + 13, Y), (X + 24, Y), (X + 24, Y + 13), (X + 14, Y + 15), (X + 11, Y + 9)],
        [(X, Y + 17), (X + 14, Y + 15), (X + 12, Y + 24), (X + 15, Y + 32), (X, Y + 32)],
        [(X + 14, Y + 15), (X + 24, Y + 13), (X + 24, Y + 32), (X + 15, Y + 32), (X + 12, Y + 24)],
    ]
    shifts = [(-3, -2), (3, -3), (-4, 3), (4, 2)]
    for pts, (dx, dy) in zip(pieces, shifts):
        ticket_piece(cv, [(x + dx, y + dy) for x, y in pts], X + dx, Y + dy)


# --------------------------------------------------------------------------- driver


def out_rel(art_id):
    cat, rest = art_id.split(".", 1)
    return "art/ai/%s/%s.png" % (cat, rest)


def render(art_id):
    cv = Cv(W, H, "p")
    SCENES[art_id](cv, rng_for(art_id))
    im = cv.image()
    assert im.size == (W, H), (art_id, im.size)
    raw = im.tobytes()
    for k in range(0, len(raw), 4):
        assert tuple(raw[k:k + 4]) in ALLOWED, (art_id, tuple(raw[k:k + 4]))
    return im


def png_bytes(im):
    clean = Image.frombytes("RGBA", im.size, im.convert("RGBA").tobytes())
    buf = io.BytesIO()
    clean.save(buf, format="PNG", optimize=False, compress_level=9)
    return buf.getvalue()


def build_sheet(ids, images, path, scale=3, cols=8):
    from PIL import ImageDraw, ImageFont

    font = ImageFont.load_default()
    cell_w = W * scale + 12
    label_h = 14
    row_h = H * scale + label_h + 8
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w + 8, rows * row_h + 8), (0x80, 0x78, 0x6c, 255))
    d = ImageDraw.Draw(sheet)
    for n, aid in enumerate(ids):
        im = images[aid]
        big = im.resize((W * scale, H * scale), Image.NEAREST)
        cx = 4 + (n % cols) * cell_w
        y = 4 + (n // cols) * row_h
        sheet.alpha_composite(big, (cx + 6, y))
        label = aid.split(".", 1)[1]
        tw = d.textlength(label, font=font)
        d.text((cx + (cell_w - tw) / 2, y + H * scale + 2), label, fill=(255, 255, 255, 255), font=font)
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
    ids = sorted(i for i in SCENES if i.startswith(a.only))
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
            im.resize((W * 6, H * 6), Image.NEAREST).save(os.path.join(a.zoom, aid + ".png"))
    if a.sheet:
        build_sheet(ids, images, a.sheet)
    print("%s %d images%s" % ("CHECK" if a.check else "WROTE", len(ids), (", %d problems" % bad) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
