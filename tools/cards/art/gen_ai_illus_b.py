#!/usr/bin/env python3
"""AI pixel art for the card game, batch "illus_b": 64x48 card illustrations.

    python3 tools/cards/art/gen_ai_illus_b.py [--out=<root>] [--only=<id prefix>] [--check]
                                              [--sheet=<png>] [--zoom=<dir>] [--force]
                                              [--frag=<json>] [--list]

Covers the illus.* ids of fate (fa), life (lf), demand (dm), kept (kp), big fate (bf)
and street (st) cards. Every picture is drawn here in code, pixel by pixel (no image
model, no fonts, no source images). Writes art/ai/illus/<rest>.png for art id illus.<rest>.

* Deterministic: same script -> byte-identical PNGs. Each picture's RNG is
  random.Random(first 8 bytes of sha256(art_id)), the PNG has only IHDR/IDAT/IEND
  (8-bit RGBA, fixed zlib level, no time or color chunks), ids are processed sorted.
* Colors: the same palette letters as gen_ai_small.py (values of keys in
  data/cards/theme/palette.dev.json, copied below so a later palette edit does not
  silently change shipped pixels). Every scene is opaque: no transparent pixel.
* No letters, numbers or readable characters. Notices, tickets and letters carry
  abstract strokes and a red seal only. No gore; uniforms are olive (puppet troops)
  or navy (police) silhouettes.
* Existing files under art/ai are never overwritten unless --force is given
  (re-running over this script's own output); --check compares without writing.
* --frag writes the manifest fragment {"<art id>": {"ai": ..., "_provenance": ...}}.
* A drawer that leaves a pixel unpainted fails the run; while drafting, ILLUS_DEV=1 paints
  such holes red and only prints a warning (never ship output made that way).

Batch owner: ai:claude:opus-5.5:2026-10-22:art-illus_b. Spec: docs/cards/ART_SPEC.md.
"""

import argparse
import hashlib
import io
import json
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PROVENANCE = "ai:claude:opus-5.5:2026-10-22:art-illus_b"
W, H = 64, 48

# palette.dev.json keys (opaque ones), one letter each -- same table as gen_ai_small.py.
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

# Light/dark neighbour of each color (light from the upper left) -- as gen_ai_small.py.
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
# Warm lamp-light step (what a pixel turns into inside a lamp pool).
WARM = {
    "K": "k", "Q": "x", "k": "x", "x": "w", "q": "w", "w": "b", "f": "b", "b": "B", "E": "o",
    "o": "B", "t": "B", "B": "P", "s": "P", "P": "c", "m": "P", "p": "c", "h": "c", "N": "c",
    "n": "E", "i": "o", "I": "s", "j": "l", "G": "l", "l": "B", "J": "P", "g": "Y", "Y": "e",
    "e": "y", "r": "R", "d": "R", "R": "R", "c": "c", "y": "y", "W": "W", "S": "c",
}
# Cold night step (what a pixel turns into in moonlight / night shade).
NIGHT = {
    "W": "m", "S": "m", "h": "m", "p": "m", "N": "s", "c": "s", "P": "s", "y": "e", "e": "g",
    "Y": "g", "B": "E", "s": "E", "m": "t", "o": "E", "t": "f", "b": "f", "E": "f", "g": "b",
    "R": "d", "r": "b", "d": "b", "I": "i", "i": "n", "J": "s", "l": "G", "G": "f", "j": "n",
    "w": "q", "f": "q", "x": "Q", "q": "Q", "n": "Q", "k": "Q", "Q": "K", "K": "K",
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bay(x, y, level):
    """True where a 4x4 ordered dither of strength level (0..1) picks the second colour."""
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0 < level


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


# --------------------------------------------------------------------------- canvas


class Cv:
    """Pixel canvas holding palette letters (None = transparent, only inside sprites)."""

    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        self.a = [[fill] * w for _ in range(h)]

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if c is not None and self.inside(x, y):
            self.a[y][x] = c

    def get(self, x, y):
        x, y = int(x), int(y)
        if self.inside(x, y):
            return self.a[y][x]
        return None

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
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

    def ellipse(self, cx, cy, rx, ry, c):
        """Filled ellipse through pixel centres; cx, cy may be half-integers."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1.0:
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

    def ascii(self, rows, x=0, y=0, cmap=None):
        """Stamp rows of letters; '.' and ' ' are skipped; cmap maps template roles."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                if cmap is not None:
                    ch = cmap.get(ch, ch)
                    if ch is None:
                        continue
                self.put(x + i, y + j, ch)

    def recolor(self, frm, to, box=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                if self.a[y][x] in frm:
                    self.a[y][x] = to

    def remap(self, table, box=None, level=1.0, test=None):
        """Replace each pixel by table[pixel] (dithered at the given strength)."""
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                v = self.a[y][x]
                if v is None or v not in table:
                    continue
                if test is not None and not test(x, y):
                    continue
                if level >= 1.0 or bay(x, y, level):
                    self.a[y][x] = table[v]

    def glow(self, cx, cy, rx, ry, strength=1.0, table=None, steps=2):
        """Banded light pool: pixels step toward warm light, stronger near the centre.
        Each band edge is hard, with a one-pixel checker seam."""
        table = table or WARM

        def val(x, y):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            return max(0.0, 1.0 - d) * strength * steps

        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if not self.inside(x, y):
                    continue
                v = val(x, y)
                if v <= 0.0:
                    continue
                g = abs(val(x + 1, y) - v) + abs(val(x, y + 1) - v)
                n = int(v)
                f = v - n
                if abs(f - 0.5) < max(0.03, g * 0.5):
                    if (x + y) % 2 == 0:
                        n += 1
                elif f > 0.5:
                    n += 1
                c = self.a[y][x]
                for _ in range(n):
                    c = table.get(c, c)
                self.a[y][x] = c

    def dither(self, x, y, w, h, a, b, level, only=None):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if not self.inside(xx, yy):
                    continue
                if only is not None and self.a[yy][xx] not in only:
                    continue
                self.a[yy][xx] = b if bay(xx, yy, level) else a

    def vgrad(self, x, y, w, h, cols):
        """Flat vertical bands through cols; a short checker strip joins two bands."""
        n = len(cols)
        for yy in range(h):
            f = yy * n / max(1, h)
            i = min(int(f), n - 1)
            lv = f - i
            for xx in range(x, x + w):
                c = cols[i]
                if i + 1 < n and (lv > 0.86 or (lv > 0.72 and (xx + yy) % 2 == 0)):
                    c = cols[i + 1]
                self.put(xx, y + yy, c)

    def outline(self, c="k", diag=False):
        """1px outline on transparent pixels next to opaque ones (sprites only)."""
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


def sprite(rows, cmap=None):
    h = len(rows)
    w = max(len(r) for r in rows)
    c = Cv(w, h)
    c.ascii(rows, 0, 0, cmap)
    return c


# --------------------------------------------------------------------------- figures
# A figure is assembled on an 18x28 sprite, facing right, feet on row 26, body centre
# column 7, then outlined in ink, flipped for facing left and pasted into the scene.
# Template roles: h hair, s skin, S skin shade, c coat, C coat shade, d hem/belt,
# p trousers, P trouser shade, f shoes.

FW, FH = 18, 28
HEADS = {
    "short": ["..hhh..", ".hhhhh.", ".hhsss.", ".hssss.", "..ssS.."],
    "bob": ["..hhh..", ".hhhhh.", ".hhhss.", ".hhsss.", ".hhsS.."],
    "bun": ["..hhh..", "hhhhhh.", "hhhsss.", ".hssss.", "..ssS.."],
}
TORSO = {
    "jacket": [
        ".....ccc........",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....dddddd......",
    ],
    "gown": [
        ".....ccc........",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
    ],
}
LEGS = {
    "stand": [
        "....pppppp......",
        "....pp..pp......",
        "....pp..pp......",
        "....pp..pp......",
        "....pp..pp......",
        "....PP..PP......",
        "....ff..fff.....",
    ],
    "walk": [
        "....pppppp......",
        "....pp..ppp.....",
        "...pp....pp.....",
        "...pp....pp.....",
        "..pp.....pp.....",
        "..PP......PP....",
        ".ff.......fff...",
    ],
    "run": [
        "....pppppp......",
        "...ppp..ppp.....",
        "..pp.....pp.....",
        ".pp.......pp....",
        "pp........pp....",
        "ff.........PP...",
        "...........fff..",
    ],
    "gown": [
        "....cccccC......",
        "....cccccC......",
        "...ccccccC......",
        "...ccccccCC.....",
        "...cccccccC.....",
        "....pp..pp......",
        "....ff..fff.....",
    ],
    "gown_walk": [
        "....cccccC......",
        "...ccccccC......",
        "...ccccccCC.....",
        "..cccccccCC.....",
        "..ccccccccCC....",
        "..pp......pp....",
        ".ff.......fff...",
    ],
    "sit": [
        "....pppppppp....",
        "....ppppppPP....",
        "..........pp....",
        "..........pp....",
        "..........pp....",
        "..........PP....",
        "..........fff...",
    ],
    "gown_sit": [
        "....cccccccc....",
        "....ccccccCC....",
        "........cccc....",
        "........cccC....",
        "........cccC....",
        "..........pp....",
        "..........fff...",
    ],
    "squat": [
        "....pppppppp....",
        "....pp....PP....",
        "...fff....fff...",
    ],
    "kneel": [
        "....pppppppp....",
        "....pppppp.pp...",
        "...PPPPPP..pp...",
        "...ff......fff..",
    ],
}
SHORT_LEGS = ("squat", "kneel")

# Hand offsets from the shoulder for arm poses (facing right).
ARMS = {
    "down": (1, 5),
    "fwd": (4, 0),
    "give": (4, 2),
    "low": (3, 4),
    "up": (1, -6),
    "upfwd": (3, -5),
    "hold": (3, 2),
    "back": (-1, 5),
    "swing": (-3, 3),
    "chest": (2, 2),
    "head": (1, -2),
}


class Look:
    """Colours and kit of one figure."""

    def __init__(self, coat="i", coat2=None, legs="f", hair="Q", skin="N", hat=None,
                 hatc="f", body="jacket", head="short", shoes="k", hem=None, accent=None,
                 legs2=None):
        self.coat = coat
        self.coat2 = coat2 or DARK.get(coat, coat)
        self.legs = legs
        self.legs2 = legs2 or DARK.get(legs, legs)
        self.hair = hair
        self.skin = skin
        self.hat = hat
        self.hatc = hatc
        self.body = body
        self.head = head
        self.shoes = shoes
        self.hem = hem or self.coat2
        self.accent = accent

    def but(self, **kw):
        n = Look()
        n.__dict__.update(self.__dict__)
        n.__dict__.update(kw)
        if "coat" in kw and "coat2" not in kw:
            n.coat2 = DARK.get(n.coat, n.coat)
        if "legs" in kw and "legs2" not in kw:
            n.legs2 = DARK.get(n.legs, n.legs)
        return n

    def cmap(self):
        return {"h": self.hair, "s": self.skin, "S": DARK.get(self.skin, self.skin),
                "c": self.coat, "C": self.coat2, "d": self.hem, "p": self.legs,
                "P": self.legs2, "f": self.shoes}


# Stock looks (the walk sprites' and portraits' families).
RUHUA = Look(coat="I", coat2="i", legs="n", hair="Q", head="bob", shoes="k")
SOLDIER = Look(coat="l", coat2="G", legs="G", legs2="f", hat="peak", hatc="l", hem="f")
POLICE = Look(coat="n", coat2="Q", legs="n", legs2="Q", hat="peak", hatc="n", hem="k",
              accent="Y")
CLERK = Look(coat="s", coat2="t", legs="f", body="gown", hat="skull", hatc="q")
GENTRY = Look(coat="i", coat2="n", legs="q", hair="m", body="gown", hat="skull", hatc="Q")
FEDORA = Look(coat="f", coat2="q", legs="q", body="gown", hat="fedora", hatc="q")
PORTER = Look(coat="B", coat2="b", legs="b", legs2="w", skin="P", shoes="w")
WORKER = Look(coat="t", coat2="E", legs="f", skin="P", hat="cap", hatc="E", shoes="w")
WOMAN = Look(coat="j", coat2="f", legs="f", head="bun")
OLDWOMAN = Look(coat="B", coat2="b", legs="w", hair="m", head="bun")
STRANGER = Look(coat="q", coat2="Q", legs="Q", body="gown", hat="fedora", hatc="Q", shoes="K")
POSTMAN = Look(coat="j", coat2="f", legs="j", legs2="f", hat="peak", hatc="j")
DOCTOR = Look(coat="E", coat2="f", legs="q", body="gown", hat="skull", hatc="Q")
BEGGAR = Look(coat="E", coat2="f", legs="t", hair="q", skin="P", shoes="w")
RUHUA_ST = Look(coat="i", coat2="n", legs="f", hair="Q", head="bob", shoes="k")  # on the street


def _hat(sp, kind, c, x0, y0):
    """Hats over a head whose 7-wide box starts at x0, top row y0 (facing right)."""
    d = DARK.get(c, c)
    if kind == "cap":  # flat worker cap, peak to the front
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.hl(x0 + 1, x0 + 5, y0 + 1, c)
        sp.hl(x0 + 5, x0 + 6, y0 + 1, d)
    elif kind == "peak":  # uniform cap: crown, dark band, black visor
        sp.hl(x0 + 1, x0 + 5, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.hl(x0 + 1, x0 + 5, y0 + 1, d)
        sp.hl(x0 + 5, x0 + 6, y0 + 2, "k")
    elif kind == "fedora":
        sp.hl(x0 + 2, x0 + 4, y0 - 2, c)
        sp.hl(x0 + 1, x0 + 5, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, d)
        sp.hl(x0, x0 + 6, y0 + 1, c)
    elif kind == "skull":  # melon-skin cap with a red knot
        sp.hl(x0 + 2, x0 + 4, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.put(x0 + 3, y0 - 2, "r")
    elif kind == "straw":  # wide bamboo hat
        sp.hl(x0 + 3, x0 + 3, y0 - 2, c)
        sp.hl(x0 + 2, x0 + 4, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.hl(x0 - 1, x0 + 7, y0 + 1, d)
    elif kind == "scarf":
        sp.hl(x0 + 2, x0 + 4, y0, c)
        sp.hl(x0 + 1, x0 + 5, y0 + 1, c)
        sp.vl(x0 + 1, y0 + 1, y0 + 4, c)
        sp.put(x0, y0 + 3, d)
        sp.put(x0, y0 + 4, d)


def person(cv, fx, fy, look, legs="stand", arm="down", arm2=None, face=1, drop=0,
           outline="k", lean=0, band=None):
    """Draw one figure with feet bottom at (fx, fy). Returns scene anchors.

    arm / arm2: near / far arm pose (a name in ARMS or an (dx, dy) hand offset; None hides it).
    drop: lower the upper body. lean: shift head and shoulders forward.
    band: colour of an armband on the near arm (puppet-committee men).
    """
    sp = Cv(FW, FH)
    cm = look.cmap()
    if look.body == "gown" and legs in ("stand", "walk", "sit"):
        legs = {"stand": "gown", "walk": "gown_walk", "sit": "gown_sit"}[legs]
    lrows = LEGS[legs]
    ly = 26 - len(lrows) + 1
    top = ly - 12 + drop
    ty = top + 5
    sh_n = (8 + lean, ty + 1)
    sh_f = (5 + lean, ty + 1)

    def arm_line(sh, pose, col):
        # sleeve in shade colour over the body, in coat colour where it sticks out
        off = ARMS[pose] if isinstance(pose, str) else pose
        hx, hy2 = sh[0] + off[0], sh[1] + off[1]
        tmp = Cv(FW, FH)
        tmp.line(sh[0], sh[1], hx, hy2, "1")
        if abs(off[0]) + abs(off[1]) > 3 and off[1] > -3:
            mx, my = (sh[0] + hx) // 2, (sh[1] + hy2) // 2
            tmp.line(sh[0], sh[1], mx, my, "1", 2)
        for yy in range(FH):
            for xx in range(FW):
                if tmp.a[yy][xx]:
                    sp.put(xx, yy, col if sp.a[yy][xx] is not None else look.coat)
        sp.put(hx, hy2, look.skin)
        if band and col == look.coat2 and pose == arm:
            bx = sh[0] + (off[0] * 2) // 5
            by = sh[1] + (off[1] * 2) // 5
            sp.put(bx, by, band)
            sp.put(bx + (1 if abs(off[1]) >= abs(off[0]) else 0),
                   by + (0 if abs(off[1]) >= abs(off[0]) else 1), band)
        return (hx, hy2)

    hand_f = None
    if arm2 is not None:
        hand_f = arm_line(sh_f, arm2, look.coat2)
    sp.ascii(lrows, 0, ly, cm)
    trows = TORSO["gown" if look.body == "gown" else "jacket"]
    sp.ascii(trows, lean, ty, cm)
    sp.ascii(HEADS[look.head], 4 + lean, top, cm)
    if look.accent and look.body != "gown":
        sp.put(7 + lean, ty + 2, look.accent)
        sp.put(7 + lean, ty + 4, look.accent)
    if look.hat:
        _hat(sp, look.hat, look.hatc, 4 + lean, top)
    hand_n = arm_line(sh_n, arm, look.coat2) if arm else None
    if outline:
        sp.outline(outline)
    ox = fx - 7
    oy = fy - 26
    if face < 0:
        sp.flip_x()
        ox = fx - (FW - 1 - 7)

    def tr(p):
        if p is None:
            return None
        x, y = p
        if face < 0:
            x = FW - 1 - x
        return (ox + x, oy + y)

    cv.paste(sp, ox, oy)
    return {"hand": tr(hand_n), "hand2": tr(hand_f), "head": tr((7 + lean, top + 2)),
            "top": oy + top, "chest": tr((7 + lean, ty + 2))}


# Small background figures (about 12 px): rows of roles, facing right.
SMALL = {
    "stand": [
        "..hh..",
        ".hhss.",
        "..ss..",
        ".cccc.",
        ".cccC.",
        ".cccC.",
        ".cccs.",
        ".dddd.",
        ".pppp.",
        ".p..p.",
        ".p..p.",
        ".f..ff",
    ],
    "walk": [
        "..hh..",
        ".hhss.",
        "..ss..",
        ".cccc.",
        "ccccC.",
        "s.ccC.",
        "..cCs.",
        ".dddd.",
        ".pppp.",
        "p...p.",
        "p....p",
        "f....f",
    ],
    "gown": [
        "..hh..",
        ".hhss.",
        "..ss..",
        ".cccc.",
        ".cccC.",
        ".cccC.",
        ".cccs.",
        ".cccC.",
        ".cccC.",
        ".cccC.",
        "ccccCC",
        ".f..f.",
    ],
    "carry": [
        "BBBB..",
        "BBBBh.",
        "PBhss.",
        "..ss..",
        ".cccc.",
        ".ccCC.",
        ".cccC.",
        ".dddd.",
        ".pppp.",
        ".p..p.",
        ".p..p.",
        ".f..ff",
    ],
}


def small_person(cv, fx, fy, look, pose="stand", face=1, outline="k"):
    """A ~12 px figure with feet bottom at (fx, fy)."""
    rows = SMALL[pose]
    cm = look.cmap()
    cm["B"] = "B"
    cm["P"] = "P"
    sp = Cv(len(rows[0]) + 2, len(rows) + 2)
    sp.ascii(rows, 1, 1, cm)
    if look.hat == "peak":
        sp.hl(2, 4, 1, look.hatc)
        sp.put(5, 2, "k")
    elif look.hat == "fedora":
        sp.hl(2, 4, 0, look.hatc)
        sp.hl(1, 5, 1, look.hatc)
    elif look.hat == "skull":
        sp.hl(2, 3, 1, look.hatc)
    elif look.hat == "straw":
        sp.hl(2, 3, 0, look.hatc)
        sp.hl(1, 5, 1, look.hatc)
    elif look.hat == "cap":
        sp.hl(2, 4, 1, look.hatc)
        sp.put(5, 2, look.hatc)
    if outline:
        sp.outline(outline)
    if face < 0:
        sp.flip_x()
    cv.paste(sp, fx - sp.w // 2, fy - sp.h + 2)


# --------------------------------------------------------------------------- scenery

SKIES = {
    "day": ["h", "N", "N", "p"],
    "warm": ["N", "c", "p"],
    "grey": ["s", "m", "m", "h"],
    "rain": ["t", "s", "m"],
    "dusk": ["n", "I", "s", "c"],
    "night": ["Q", "n", "n", "i"],
    "snow": ["m", "m", "h", "h"],
}


def sky(cv, kind, y1=48, y0=0):
    cv.vgrad(0, y0, cv.w, y1 - y0, SKIES[kind])


def stars(cv, r, n, y1, cols=("m", "h")):
    for _ in range(n):
        x, y = r.randrange(cv.w), r.randrange(max(1, y1))
        if cv.get(x, y) in ("Q", "n", "i", "K", "q"):
            cv.put(x, y, r.choice(cols))


def moon(cv, x, y, rad=3, full=True):
    cv.ellipse(x + 0.5, y + 0.5, rad + 0.6, rad + 0.6, "s")
    cv.ellipse(x + 0.5, y + 0.5, rad, rad, "p")
    cv.put(x - 1, y - 1, "W")
    if not full:
        cv.ellipse(x + 2.0, y - 0.5, rad, rad, cv.get(x + rad + 2, y) or "n")


def ground(cv, y0, kind="slab", y1=48):
    """Stone slabs (Jiangnan street), earth, or wooden floor from y0 down."""
    if kind == "slab":
        cv.rect(0, y0, cv.w, y1 - y0, "s")
        row = 0
        y = y0
        while y < y1:
            hgt = 2 + row
            cv.hl(0, cv.w - 1, y, "t")
            off = (row * 5) % 9
            for x in range(off, cv.w, 9 + row * 2):
                cv.vl(x, y, min(y1 - 1, y + hgt), "t")
            y += hgt + 1
            row += 1
        cv.dither(0, y0 + 1, cv.w, 1, "s", "m", 0.25, only=("s",))
    elif kind == "earth":
        cv.vgrad(0, y0, cv.w, y1 - y0, ["o", "B", "B"])
    elif kind == "floor":
        cv.rect(0, y0, cv.w, y1 - y0, "b")
        for y in range(y0, y1, 3):
            cv.hl(0, cv.w - 1, y, "w")
        cv.hl(0, cv.w - 1, y0, "x")
    elif kind == "brick":
        cv.rect(0, y0, cv.w, y1 - y0, "t")
        for y in range(y0, y1, 3):
            cv.hl(0, cv.w - 1, y, "E")
            for x in range((y // 3 % 2) * 4, cv.w, 8):
                cv.vl(x, y, y + 2, "E")


def tile_roof(cv, x0, x1, y, depth=4, c="E", eave=1):
    """Black-tile roof seen from the front: ridge, tile rows, a lighter eave line."""
    cv.rect(x0, y, x1 - x0 + 1, depth, c)
    cv.hl(x0 - 1, x1 + 1, y, "f")
    for x in range(x0, x1 + 1, 2):
        cv.vl(x, y + 1, y + depth - 1, "f")
    cv.hl(x0 - eave, x1 + eave, y + depth, "q")
    cv.put(x0 - eave - 1, y - 1, "f")
    cv.put(x1 + eave + 1, y - 1, "f")


def gable(cv, x0, x1, ytop, ybase, wall="h", cap="f"):
    """Stepped horse-head wall: whitewash with dark tile caps."""
    steps = 3
    sw = (x1 - x0 + 1) // (steps * 2)
    for i in range(steps):
        y = ytop + i * ((ybase - ytop) // steps)
        a = x0 + i * sw
        b = x1 - i * sw
        cv.rect(a, y, b - a + 1, ybase - y, wall)
        cv.hl(a - 1, b + 1, y, cap)
        cv.hl(a, b, y + 1, "E")


def lattice(cv, x, y, w, h, frame="w", pane="p", step=2):
    cv.rect(x, y, w, h, pane)
    cv.frame(x, y, w, h, frame)
    for xx in range(x + step, x + w - 1, step):
        cv.vl(xx, y, y + h - 1, frame)
    for yy in range(y + step, y + h - 1, step):
        cv.hl(x, x + w - 1, yy, frame)


def plank_door(cv, x, y, w, h, c="b", seam="w", ring=True):
    cv.rect(x, y, w, h, c)
    for xx in range(x + 2, x + w, 3):
        cv.vl(xx, y, y + h - 1, seam)
    cv.frame(x - 1, y - 1, w + 2, h + 1, "x")
    if ring:
        m = x + w // 2
        cv.pts([(m - 2, y + h // 2), (m + 1, y + h // 2)], "Y")
        cv.pts([(m - 2, y + h // 2 + 1), (m + 1, y + h // 2 + 1)], "g")


def shopfront(cv, x, y, w, h, r, wall="h", wood="b", open_=True, banner=None):
    """A two-storey Jiangnan shop: white upper wall, tile eave, wooden boards below."""
    cv.rect(x, y, w, h, wall)
    cv.vl(x + w - 1, y, y + h - 1, DARK.get(wall, wall))
    win_y = y + 2
    for wx in range(x + 2, x + w - 5, 7):
        lattice(cv, wx, win_y, 5, 4, "w", "P")
    tile_roof(cv, x, x + w - 1, y + 7, 2)
    by = y + 10
    cv.rect(x, by, w, h - 10, wood)
    for xx in range(x + 1, x + w, 3):
        cv.vl(xx, by, y + h - 1, DARK.get(wood, wood))
    if open_:
        cv.rect(x + 2, by + 2, w - 4, h - 12, "x")
    if banner:
        bx = x + w - 4
        cv.rect(bx, by - 1, 3, 8, banner)
        cv.vl(bx + 2, by - 1, by + 6, DARK.get(banner, banner))
        cv.put(bx, by + 7, banner)
        cv.put(bx + 2, by + 7, banner)


def lantern(cv, x, y, c="r", lit=True, string=True):
    """Red paper lantern centred on x, top at y (5x6)."""
    if string:
        cv.vl(x, y - 2, y - 1, "k")
    cv.hl(x - 1, x + 1, y, "k")
    cv.rect(x - 2, y + 1, 5, 4, c)
    cv.hl(x - 1, x + 1, y + 5, c)
    cv.vl(x - 2, y + 1, y + 4, DARK.get(c, c))
    cv.put(x + 2, y + 2, DARK.get(c, c))
    if lit:
        cv.put(x, y + 2, "y")
        cv.put(x - 1, y + 2, "R")
        cv.put(x, y + 3, "e")
    cv.hl(x - 1, x + 1, y + 6, "k")
    cv.put(x, y + 7, "Y")


def oil_lamp(cv, x, y, flame=True, big=False):
    """Small oil lamp: dish on a stand, flame above (base at y)."""
    cv.hl(x - 1, x + 1, y, "w")
    cv.vl(x, y - 2, y - 1, "b")
    cv.hl(x - 2, x + 2, y - 3, "g")
    cv.hl(x - 1, x + 1, y - 4, "Y")
    if flame:
        cv.put(x, y - 5, "y")
        cv.put(x, y - 6, "W" if big else "e")
        if big:
            cv.put(x, y - 7, "e")


def candle(cv, x, y, h=3):
    cv.vl(x, y - h + 1, y, "R")
    cv.put(x, y - h, "y")
    cv.put(x, y - h - 1, "e")


def rice_sack(cv, x, y, w=9, h=7, c="P", tie=True):
    """Hemp sack lying with its mouth tied, top-left at (x, y)."""
    d = DARK.get(c, c)
    cv.rect(x + 1, y, w - 2, h, c)
    cv.vl(x, y + 1, y + h - 2, c)
    cv.vl(x + w - 1, y + 1, y + h - 2, d)
    cv.hl(x + 1, x + w - 2, y + h - 1, d)
    cv.hl(x + 2, x + w - 3, y, LIGHT.get(c, c))
    # a woven stripe across the sack and a seam down its right side
    cv.hl(x + 1, x + w - 2, y + h - 3, "B" if c in ("P", "p", "h") else d)
    cv.vl(x + w - 3, y + 1, y + h - 4, d)
    if tie:
        m = x + w // 2
        cv.pts([(m, y - 1), (m - 1, y - 2), (m + 1, y - 2), (m, y - 2)], d)


def crate(cv, x, y, w, h, c="B", band="w"):
    d = DARK.get(c, c)
    cv.rect(x, y, w, h, c)
    cv.frame(x, y, w, h, d)
    cv.line(x + 1, y + 1, x + w - 2, y + h - 2, d)
    cv.hl(x, x + w - 1, y, LIGHT.get(c, c))
    cv.frame(x - 1, y - 1, w + 2, h + 2, band)


def paper(cv, x, y, w, h, c="p", strokes="b", seal="r", r=None, cols=None, edge="P"):
    """A sheet with abstract brush marks (no characters) and an optional red seal."""
    cv.rect(x, y, w, h, c)
    cv.vl(x + w - 1, y, y + h - 1, edge)
    cv.hl(x, x + w - 1, y + h - 1, edge)
    if strokes:
        ncol = cols or max(1, (w - 2) // 3)
        for i in range(ncol):
            xx = x + w - 3 - i * 3
            if xx <= x:
                break
            yy = y + 2
            while yy < y + h - 2:
                ln = 1 + ((xx * 7 + yy * 3) % 3)
                if r is not None:
                    ln = 1 + r.randrange(3)
                cv.vl(xx, yy, min(y + h - 3, yy + ln - 1), strokes)
                yy += ln + 1
    if seal:
        cv.rect(x + 1, y + h - 4, 2, 2, seal)


def envelope(cv, x, y, w, h, c="h", band="r"):
    """Chinese envelope: long sheet with a red centre panel."""
    cv.rect(x, y, w, h, c)
    cv.vl(x + w - 1, y, y + h - 1, DARK.get(c, c))
    cv.hl(x, x + w - 1, y + h - 1, DARK.get(c, c))
    cx = x + w // 2 - 1
    cv.rect(cx, y + 1, 2, h - 2, band)
    cv.put(cx, y + 2, "p")


def silver(cv, x, y, n=3, top="h"):
    """A short stack of silver dollars, bottom at y."""
    for i in range(n):
        yy = y - i * 2
        cv.hl(x, x + 4, yy, "t")
        cv.hl(x, x + 4, yy - 1, "m")
        cv.put(x + 4, yy - 1, "s")
    cv.hl(x + 1, x + 3, y - n * 2, top)


def coin_row(cv, x, y, n, c="Y"):
    for i in range(n):
        cv.put(x + i * 2, y, c)
        cv.put(x + i * 2 + 1, y, DARK.get(c, c))


def stool(cv, x, y, c="b"):
    """Small stool, seat top at y, 5 wide."""
    cv.hl(x, x + 4, y, LIGHT.get(c, c))
    cv.hl(x, x + 4, y + 1, c)
    cv.vl(x, y + 2, y + 5, DARK.get(c, c))
    cv.vl(x + 4, y + 2, y + 5, DARK.get(c, c))


def table(cv, x, y, w, h, c="w", top=None, legs=True):
    """Square table, top surface at y."""
    top = top or LIGHT.get(c, c)
    cv.hl(x, x + w - 1, y, top)
    cv.rect(x, y + 1, w, 2, c)
    cv.hl(x, x + w - 1, y + 3, DARK.get(c, c))
    if legs:
        cv.rect(x + 1, y + 4, 2, h - 4, DARK.get(c, c))
        cv.rect(x + w - 3, y + 4, 2, h - 4, DARK.get(c, c))


def counter(cv, y, c="w", top="b", x0=0, x1=None):
    """The pawnshop's tall counter across the picture from y down."""
    x1 = cv.w - 1 if x1 is None else x1
    cv.rect(x0, y, x1 - x0 + 1, cv.h - y, c)
    cv.hl(x0, x1, y, "B")
    cv.hl(x0, x1, y + 1, top)
    cv.hl(x0, x1, y + 2, "x")
    for xx in range(x0 + 5, x1, 12):
        cv.rect(xx, y + 5, 8, cv.h - y - 7, "x")
        cv.rect(xx + 1, y + 6, 6, cv.h - y - 9, c)


def shelves(cv, r, x, y, w, h, goods=True):
    """Dark wooden shelving full of wrapped goods, boxes and jars."""
    cv.rect(x, y, w, h, "x")
    rows = list(range(y + 5, y + h, 6))
    for yy in rows:
        cv.hl(x, x + w - 1, yy, "b")
        cv.hl(x, x + w - 1, yy + 1, "w")
        if not goods:
            continue
        xx = x + 1
        while xx < x + w - 3:
            k = r.randrange(5)
            if k == 0:  # cloth bundle
                cv.rect(xx, yy - 3, 4, 3, r.choice(["i", "B", "l", "d"]))
                cv.put(xx + 1, yy - 4, "p")
                xx += 5
            elif k == 1:  # jar
                cv.rect(xx, yy - 3, 3, 3, r.choice(["j", "m", "B"]))
                cv.put(xx + 1, yy - 4, "f")
                xx += 4
            elif k == 2:  # box
                cv.rect(xx, yy - 2, 4, 2, r.choice(["g", "b", "r"]))
                cv.hl(xx, xx + 3, yy - 2, "B")
                xx += 5
            elif k == 3:  # ticket bundle
                cv.rect(xx, yy - 4, 2, 4, "P")
                cv.put(xx, yy - 4, "r")
                xx += 3
            else:
                xx += 2
    for xx in range(x, x + w, 16):
        cv.vl(xx, y, y + h - 1, "w")


def rain(cv, r, n=60, c="m", slant=1, length=3, box=None):
    x0, y0, x1, y1 = box or (0, 0, cv.w, cv.h)
    for _ in range(n):
        x = r.randrange(x0, x1)
        y = r.randrange(y0, y1)
        for i in range(length):
            cv.put(x + (i * slant) // 2, y + i, c)


def snow(cv, r, n=50, box=None, cols=("W", "h")):
    x0, y0, x1, y1 = box or (0, 0, cv.w, cv.h)
    for _ in range(n):
        cv.put(r.randrange(x0, x1), r.randrange(y0, y1), r.choice(cols))


def smoke(cv, r, x, y0, y1, c="s", drift=1):
    """Thin rising curl from (x, y0) up to y1."""
    xx = x
    for y in range(y0, y1, -1):
        cv.put(xx, y, c)
        if (y0 - y) % 3 == 2:
            xx += r.choice((-1, 0, drift))


def steam(cv, x, y, n=3, c="h"):
    for i in range(n):
        cv.put(x + (1 if i % 2 else 0), y - i, c)
        cv.put(x + 2 + (0 if i % 2 else 1), y - i - 1, c)


def bowl(cv, x, y, c="h", inside="b"):
    """Small bowl, rim at y, 5 wide."""
    cv.hl(x, x + 4, y, c)
    cv.hl(x + 1, x + 3, y, inside)
    cv.hl(x, x + 4, y + 1, c)
    cv.hl(x + 1, x + 3, y + 2, DARK.get(c, c))


def boat(cv, x, y, w=20, hull="w", awning="q", lamp=False):
    """Wupeng boat: low hull with a black arched awning; y is the waterline."""
    cv.poly([(x, y - 3), (x + w, y - 3), (x + w - 3, y), (x + 3, y)], hull)
    cv.hl(x, x + w, y - 3, LIGHT.get(hull, hull))
    aw0, aw1 = x + w // 4, x + w * 3 // 4
    cv.rect(aw0, y - 7, aw1 - aw0, 4, awning)
    cv.hl(aw0 + 1, aw1 - 2, y - 8, awning)
    for xx in range(aw0 + 2, aw1, 3):
        cv.vl(xx, y - 7, y - 4, DARK.get(awning, awning))
    if lamp:
        cv.vl(x + w - 3, y - 9, y - 4, "w")
        cv.put(x + w - 3, y - 10, "y")
        cv.put(x + w - 2, y - 9, "y")


def water(cv, r, y0, y1=48, base="i", hi="I", glint="m", n=30, x0=0, x1=None):
    x1 = cv.w if x1 is None else x1
    cv.rect(x0, y0, x1 - x0, y1 - y0, base)
    cv.dither(x0, y0, x1 - x0, 1, base, hi, 0.5)
    for _ in range(n):
        x = r.randrange(x0, x1)
        y = r.randrange(y0 + 1, y1)
        ln = r.randrange(2, 5)
        cv.hl(x, min(x1 - 1, x + ln), y, hi if r.random() < 0.7 else glint)


def wall_plaster(cv, x, y, w, h, c="P", stain="B", r=None):
    cv.rect(x, y, w, h, c)
    if r is not None:
        for _ in range(max(1, w * h // 160)):
            xx, yy = r.randrange(x, x + w), r.randrange(y, y + h)
            cv.hl(xx, xx + r.randrange(1, 4), yy, stain)


def bars(cv, x, y, w, h, c="t", bg="Q"):
    cv.rect(x, y, w, h, bg)
    for xx in range(x + 1, x + w, 2):
        cv.vl(xx, y, y + h - 1, c)
    cv.frame(x, y, w, h, "w")


def hand(cv, x, y, skin="N", sleeve="I", face=1):
    """A forearm coming up from the bottom edge, the hand's top-left knuckle at (x, y)."""
    d = DARK.get(skin, skin)
    for i, yy in enumerate(range(y + 4, cv.h)):
        sx = x - 1 + (i // 3) * face
        cv.hl(sx, sx + 4, yy, sleeve)
        cv.put(sx + (4 if face > 0 else 0), yy, DARK.get(sleeve, sleeve))
    cv.hl(x - 1, x + 3, y + 4, LIGHT.get(sleeve, sleeve))
    cv.rect(x, y, 4, 4, skin)
    cv.hl(x, x + 3, y + 3, d)
    cv.vl(x + (3 if face > 0 else 0), y, y + 3, d)
    cv.put(x - face if face > 0 else x + 4, y + 1, skin)
    cv.put(x - face if face > 0 else x + 4, y + 2, d)


def vignette(cv, strength=0.5, table=None):
    """Darken the four edges a little (ordered dither) to pull the eye inward."""
    table = table or DARK
    for y in range(cv.h):
        for x in range(cv.w):
            d = max(abs(x + 0.5 - cv.w / 2) / (cv.w / 2), abs(y + 0.5 - cv.h / 2) / (cv.h / 2))
            if d > 0.86 and bay(x, y, (d - 0.86) / 0.14 * strength):
                c = cv.a[y][x]
                cv.a[y][x] = table.get(c, c)


def layer():
    return Cv(W, H)


def basket(cv, x, y, w=10, rice=True):
    """Round bamboo basket seen from the front, rim at y; heaped rice on top."""
    cv.rect(x, y, w, 6, "B")
    cv.hl(x, x + w - 1, y, "P")
    for xx in range(x + 1, x + w, 2):
        cv.vl(xx, y + 1, y + 5, "b")
    cv.hl(x + 1, x + w - 2, y + 6, "b")
    if rice:
        cv.ellipse(x + w / 2, y + 0.5, w / 2 - 0.5, 3, "h")
        cv.ellipse(x + w / 2 - 1, y - 0.5, w / 2 - 2.5, 1.5, "W")
        cv.hl(x, x + w - 1, y + 1, "P")


def broom(cv, x, y, h=18):
    """Bamboo broom leaning to the right, top at (x, y)."""
    cv.line(x, y, x + 3, y + h - 5, "B")
    cv.poly([(x + 1, y + h - 5), (x + 6, y + h - 5), (x + 8, y + h), (x, y + h)], "g")
    for i in range(0, 8, 2):
        cv.line(x + 2 + i // 2, y + h - 4, x + i, y + h, "b")


def flames(cv, r, x0, x1, ybase, height):
    """Flame tongues rising from ybase between x0 and x1."""
    for x in range(x0, x1 + 1):
        hgt = int(height * (0.45 + 0.55 * abs(math.sin(x * 0.7 + r.random()))))
        for y in range(ybase - hgt, ybase + 1):
            t = (ybase - y) / max(1, hgt)
            c = "y" if t < 0.3 else ("e" if t < 0.55 else ("R" if t < 0.8 else "d"))
            cv.put(x, y, c)


def umbrella(cv, x, y, c="R", w=13):
    """Oil-paper umbrella canopy centred on x, top at y, with its shaft down to y + 9."""
    hw = w // 2
    cv.hl(x - 1, x + 1, y, c)
    cv.hl(x - hw + 3, x + hw - 3, y + 1, c)
    cv.hl(x - hw + 1, x + hw - 1, y + 2, c)
    cv.hl(x - hw, x + hw, y + 3, DARK.get(c, c))
    for xx in range(x - hw + 1, x + hw, 3):
        cv.put(xx, y + 2, LIGHT.get(c, c))
    cv.vl(x, y + 4, y + 9, "b")


def sawhorse(cv, x, y, w=16):
    """Wooden road barrier: a rail on two X frames, rail at y."""
    cv.hl(x, x + w - 1, y, "B")
    cv.hl(x, x + w - 1, y + 1, "b")
    for fx in (x + 2, x + w - 3):
        cv.line(fx - 3, y + 7, fx + 3, y - 1, "b")
        cv.line(fx + 3, y + 7, fx - 3, y - 1, "B")
    for xx in range(x + 1, x + w - 1, 4):
        cv.put(xx, y, "h")


def bed(cv, x, y, w, quilt="I", head_left=True):
    """Wooden bed with a quilt, mattress top at y."""
    cv.rect(x, y, w, 4, "b")
    cv.hl(x, x + w - 1, y + 4, "w")
    cv.rect(x, y - 3, w, 4, quilt)
    cv.hl(x, x + w - 1, y - 3, LIGHT.get(quilt, quilt))
    for xx in range(x + 2, x + w - 2, 4):
        cv.put(xx, y - 1, DARK.get(quilt, quilt))
    cv.vl(x, y - 8, y + 6, "w")
    cv.vl(x + w - 1, y - 6, y + 6, "w")
    cv.vl(x + 1, y + 5, y + 6, "w")
    cv.vl(x + w - 2, y + 5, y + 6, "w")


def purse(cv, x, y, c="i", big=False):
    """Embroidered drawstring purse, 6x6 (or 10x9 when big), top-left at (x, y)."""
    if big:
        d = DARK.get(c, c)
        cv.ellipse(x + 5, y + 5.5, 4.6, 3.6, c)
        cv.rect(x + 3, y + 1, 5, 2, c)
        cv.hl(x + 2, x + 8, y + 3, d)
        cv.pts([(x + 3, y), (x + 7, y), (x + 4, y + 1), (x + 6, y + 1)], "r")
        cv.pts([(x + 2, y - 1), (x + 8, y - 1)], "R")
        cv.pts([(x + 4, y + 5), (x + 6, y + 5), (x + 5, y + 4), (x + 5, y + 6)], "Y")
        cv.put(x + 5, y + 5, "R")
        cv.hl(x + 3, x + 7, y + 9, d)
        cv.vl(x + 9, y + 4, y + 7, d)
        cv.put(x + 2, y + 4, LIGHT.get(c, c))
        return
    cv.rect(x + 1, y + 2, 5, 4, c)
    cv.hl(x + 2, x + 4, y + 6, DARK.get(c, c))
    cv.hl(x + 2, x + 4, y + 1, c)
    cv.pts([(x + 2, y), (x + 4, y)], "r")
    cv.put(x + 3, y + 1, "r")
    cv.put(x + 3, y + 4, "Y")
    cv.put(x + 2, y + 3, "R")
    cv.vl(x + 6, y + 2, y + 5, DARK.get(c, c))


def vase(cv, x, y, h=10):
    """Blue-and-white porcelain vase, base centre at (x, y)."""
    cv.rect(x - 1, y - h, 3, 2, "h")
    cv.ellipse(x + 0.5, y - h / 2 + 1, 3.2, h / 2 - 1, "h")
    cv.hl(x - 2, x + 2, y, "P")
    cv.hl(x - 2, x + 2, y - h // 2, "i")
    cv.pts([(x - 1, y - h // 2 + 2), (x + 1, y - h // 2 - 2), (x, y - 2)], "i")
    cv.vl(x + 3, y - h // 2 - 1, y - 2, "P")


def firewood(cv, x, y, w=6, h=8):
    for i in range(w):
        cv.vl(x + i, y, y + h - 1, "B" if i % 2 else "b")
        cv.put(x + i, y, "P")
    cv.hl(x, x + w - 1, y + 2, "w")
    cv.hl(x, x + w - 1, y + h - 3, "w")


def pawnshop_front(cv, r, x0, x1, y0, y1, door=(None, None)):
    """Our own shop seen from the street: dark boards, blank black signboard, an opening."""
    cv.rect(x0, y0, x1 - x0 + 1, y1 - y0, "w")
    for xx in range(x0 + 1, x1 + 1, 3):
        cv.vl(xx, y0 + 7, y1 - 1, "x")
    cv.rect(x0 + 2, y0 + 1, x1 - x0 - 3, 5, "Q")
    cv.frame(x0 + 2, y0 + 1, x1 - x0 - 3, 5, "g")
    dx0, dx1 = door
    if dx0 is not None:
        cv.rect(dx0, y0 + 8, dx1 - dx0 + 1, y1 - y0 - 8, "K")
        cv.rect(dx0 + 1, y0 + 9, dx1 - dx0 - 1, y1 - y0 - 9, "x")


def clip(lay, x0, y0, x1, y1):
    """Clear a layer outside the box (x1, y1 exclusive)."""
    for y in range(lay.h):
        for x in range(lay.w):
            if not (x0 <= x < x1 and y0 <= y < y1):
                lay.a[y][x] = None


def at_night(cv, lay, level=1.0):
    """Darken a layer into night colours, then paste it over the canvas."""
    lay.remap(NIGHT, level=level)
    cv.paste(lay, 0, 0)


ILLUS = {}


def art(*ids):
    def reg(fn):
        for i in ids:
            ILLUS[i] = fn
        return fn
    return reg


# =========================================================================== big fate (bf)


@art("illus.bf.wheel")
def bf_wheel(cv, r):
    # temple hall: dark wall, red pillars, a big wheel over the incense table
    cv.vgrad(0, 0, W, 40, ["K", "x", "w"])
    cv.rect(0, 0, W, 3, "w")
    cv.hl(0, W - 1, 3, "g")
    cv.hl(0, W - 1, 4, "x")
    for px in (3, 57):
        cv.rect(px, 3, 5, 37, "r")
        cv.vl(px, 3, 39, "R")
        cv.vl(px + 4, 3, 39, "d")
        cv.hl(px, px + 4, 5, "g")
    lantern(cv, 13, 6, "r")
    lantern(cv, 51, 6, "r")
    # smoke behind the wheel
    for sx in (24, 31, 38):
        smoke(cv, r, sx, 36, 2, "o")
    cx, cy, rad = 32, 19, 14
    cols = ["Y", "j", "q", "R", "j", "q"]
    for y in range(cy - rad - 1, cy + rad + 2):
        for x in range(cx - rad - 1, cx + rad + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > rad + 0.5:
                continue
            if d > rad - 2:
                c = "d" if dx + dy > 4 else "r"
                if d > rad - 0.6:
                    c = "k"
            elif d < 3:
                c = "e" if dx + dy < 0 else "g"
                if d < 1.2:
                    c = "y"
            else:
                a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
                k = int(a * 6) % 6
                c = cols[k]
                if abs(a * 6 - round(a * 6)) * d < 0.55:
                    c = "k"
                elif dx + dy > 6:
                    c = DARK.get(c, c)
            cv.put(x, y, c)
    for i in range(12):
        a = i * math.pi / 6
        cv.put(int(cx + math.cos(a) * (rad - 1)), int(cy + math.sin(a) * (rad - 1)), "Y")
    # pointer at the top
    cv.pts([(cx - 1, 3), (cx, 3), (cx + 1, 3), (cx, 4), (cx, 5)], "y")
    cv.pts([(cx - 2, 2), (cx + 2, 2)], "k")
    # altar
    cv.rect(0, 40, W, 8, "E")
    cv.hl(0, W - 1, 40, "t")
    cv.rect(8, 35, 48, 11, "r")
    cv.hl(8, 55, 35, "Y")
    cv.hl(8, 55, 36, "g")
    cv.hl(8, 55, 45, "d")
    cv.rect(10, 38, 44, 6, "d")
    cv.rect(11, 39, 42, 4, "r")
    cv.ellipse(32, 41, 3, 1.5, "Y")
    cv.pts([(31, 41), (32, 41)], "g")
    # incense burner and candles on the table
    cv.rect(27, 31, 11, 4, "g")
    cv.hl(27, 37, 31, "Y")
    cv.hl(26, 38, 30, "g")
    cv.pts([(27, 35), (37, 35)], "b")
    for ix in (30, 32, 34):
        cv.vl(ix, 26, 29, "B")
        cv.put(ix, 25, "R")
    candle(cv, 14, 34, 4)
    candle(cv, 50, 34, 4)
    cv.glow(14, 30, 7, 6, 0.8)
    cv.glow(50, 30, 7, 6, 0.8)
    cv.glow(32, 19, 18, 17, 0.35)


@art("illus.bf.1938.bail_shop")
def bf_bail_shop(cv, r):
    # police post: grey wall, barred window, a desk; she sets silver down on the desk
    wall_plaster(cv, 0, 0, W, 26, "m", "s", r)
    cv.rect(0, 26, W, 8, "s")
    cv.hl(0, W - 1, 26, "t")
    ground(cv, 34, "floor")
    bars(cv, 5, 5, 11, 10, "t", "N")
    cv.poly([(5, 15), (16, 15), (22, 26), (11, 26)], "h")
    cv.vl(5, 5, 14, "w")
    paper(cv, 47, 6, 9, 12, "p", "b", "r", r)
    cv.rect(47, 4, 9, 1, "t")
    person(cv, 46, 39, POLICE, legs="sit", arm="fwd", face=-1)
    cv.rect(16, 33, 48, 15, "w")
    cv.hl(16, 63, 33, "B")
    cv.hl(16, 63, 34, "b")
    cv.rect(20, 37, 14, 8, "x")
    cv.rect(21, 38, 12, 6, "w")
    cv.pts([(27, 41), (28, 41)], "g")
    paper(cv, 34, 30, 7, 4, "S", None, "r")
    cv.rect(52, 31, 6, 3, "i")
    cv.hl(52, 57, 31, "I")
    silver(cv, 17, 32, 3)
    silver(cv, 23, 32, 2)
    person(cv, 10, 48, RUHUA, arm=(5, -1), arm2="down")


@art("illus.bf.1938.night_cargo")
def bf_night_cargo(cv, r):
    sky(cv, "night", 22)
    stars(cv, r, 10, 14)
    moon(cv, 52, 6, 3)
    lay = layer()
    # far bank roofs
    for x0, w0, h0 in ((0, 14, 5), (13, 10, 7), (24, 12, 4), (38, 9, 6), (48, 16, 5)):
        lay.rect(x0, 20 - h0, w0, h0, "E")
        lay.hl(x0 - 1, x0 + w0, 20 - h0, "f")
    water(lay, r, 20, 48, "i", "I", "m", 40)
    # stone quay with steps on the left
    lay.poly([(0, 25), (26, 25), (34, 48), (0, 48)], "s")
    for i, yy in enumerate(range(25, 48, 4)):
        lay.hl(0, 26 + i * 1, yy, "t")
    lay.vl(26, 25, 30, "t")
    boat(lay, 33, 40, 26, "b", "f")
    # crates waiting on the quay
    crate(lay, 3, 18, 8, 6, "B")
    crate(lay, 11, 19, 7, 5, "B")
    crate(lay, 6, 13, 7, 5, "o")
    at_night(cv, lay)
    # porter with a crate on his shoulder walking to the boat
    a = person(cv, 26, 37, PORTER.but(coat="E", legs="f", skin="s"), legs="walk", arm="head", face=1)
    hx, hy = a["hand"]
    crate(cv, hx - 5, hy - 4, 7, 4, "o", "q")
    # the boat lantern
    cv.vl(56, 29, 36, "w")
    lantern(cv, 56, 30, "r")
    cv.glow(56, 33, 10, 8, 1.0)
    cv.glow(56, 42, 6, 4, 0.7)


@art("illus.bf.1939.gate_passage")
def bf_gate_passage(cv, r):
    sky(cv, "dusk", 20)
    # far fields seen through the arch
    cv.rect(0, 20, W, 28, "f")
    lay = layer()
    lay.rect(0, 4, W, 36, "t")
    for y in range(4, 40, 3):
        lay.hl(0, W - 1, y, "E")
        for x in range((y // 3 % 2) * 3, W, 6):
            lay.vl(x, y, y + 2, "E")
    for x in range(0, W, 6):
        lay.rect(x, 1, 4, 3, "t")
        lay.hl(x, x + 3, 1, "s")
    lay.hl(0, W - 1, 4, "s")
    # arch opening
    cx, top, bot = 32, 14, 40
    for y in range(top, bot):
        hw = 9 if y > top + 6 else int(math.sqrt(max(0, 81 - (top + 7 - y) ** 2 * 81 / 49)))
        for x in range(cx - hw, cx + hw):
            lay.a[y][x] = None
    for y in range(top, bot):
        for x in range(cx - 11, cx + 11):
            if lay.get(x, y) is not None and (lay.get(x + 1, y) is None or lay.get(x - 1, y) is None
                                              or lay.get(x, y + 1) is None):
                lay.put(x, y, "s")
    lay.rect(0, 40, W, 8, "o")
    lay.poly([(23, 40), (41, 40), (52, 48), (12, 48)], "B")
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    # the road out, under the evening sky
    cv.poly([(29, 20), (35, 20), (41, 40), (23, 40)], "o")
    cv.rect(23, 14, 18, 6, "I")
    cv.dither(23, 17, 18, 3, "I", "s", 0.5)
    cv.hl(23, 40, 20, "q")
    small_person(cv, 32, 33, RUHUA, "walk", face=1)
    cv.put(30, 25, "P")
    cv.put(29, 25, "P")
    # guard with a rifle, turned away
    a = person(cv, 51, 46, SOLDIER, arm="hold", face=1)
    hx, hy = a["hand"]
    cv.line(hx, hy + 2, hx + 2, hy - 9, "w")
    lantern(cv, 32, 9, "r")
    cv.glow(32, 12, 9, 6, 0.9)


@art("illus.bf.1939.rice_hoard")
def bf_rice_hoard(cv, r):
    # storeroom: plank wall, a pile of hemp rice sacks by lantern light
    cv.rect(0, 0, W, 40, "w")
    for x in range(0, W, 4):
        cv.vl(x, 0, 39, "x")
    cv.rect(0, 40, W, 8, "b")
    cv.hl(0, W - 1, 40, "x")
    for y in (43, 46):
        cv.hl(0, W - 1, y, "w")
    rows = [(4, 36, 10), (3, 29, 10), (2, 22, 10)]
    for n, y, sw in rows:
        x0 = 30 - n * sw // 2
        for i in range(n):
            rice_sack(cv, x0 + i * sw, y, sw, 7, "P", tie=(n == 2))
    # one split sack spilling rice
    cv.pts([(46, 42), (47, 42), (48, 43), (49, 43), (46, 43), (50, 44), (45, 44), (47, 44),
            (48, 44), (51, 45), (44, 45), (46, 45), (49, 45), (50, 45)], "h")
    cv.pts([(47, 43), (48, 45), (45, 45)], "W")
    lantern(cv, 10, 4, "r")
    cv.glow(10, 9, 15, 13, 0.9)
    a = person(cv, 56, 46, STRANGER, arm="fwd", face=-1)
    cv.glow(30, 31, 18, 10, 0.4)


@art("illus.bf.1940.night_road")
def bf_night_road(cv, r):
    sky(cv, "night", 26)
    stars(cv, r, 14, 18)
    moon(cv, 50, 7, 3)
    cv.rect(0, 22, W, 26, "q")
    # distant hills
    for x in range(W):
        hgt = int(3 + 2 * math.sin(x * 0.17) + 1.5 * math.sin(x * 0.41))
        cv.vl(x, 24 - hgt, 24, "f")
    # town wall and gate on the left
    cv.rect(0, 12, 18, 14, "f")
    for x in range(0, 18, 4):
        cv.rect(x, 10, 3, 2, "f")
    cv.rect(6, 17, 6, 9, "Q")
    cv.put(9, 15, "e")
    cv.glow(9, 16, 4, 3, 0.8)
    # road winding away
    cv.poly([(10, 26), (13, 26), (30, 36), (36, 48), (16, 48), (18, 36)], "E")
    cv.dither(16, 40, 22, 8, "E", "t", 0.2, only=("E",))
    # the pass in her hand
    paper(cv, 36, 18, 15, 22, "p", "b", None, r)
    cv.rect(38, 33, 4, 4, "r")
    cv.put(39, 34, "R")
    cv.hl(36, 50, 18, "W")
    hand(cv, 42, 37, "s", "i")
    cv.glow(43, 28, 12, 14, 0.4)


@art("illus.bf.1940.yamen_crate")
def bf_yamen_crate(cv, r):
    # yamen hall being emptied: dark plaque, red pillars, a crate of documents
    cv.rect(0, 0, W, 36, "P")
    wall_plaster(cv, 0, 6, W, 30, "P", "B", r)
    cv.rect(0, 0, W, 5, "w")
    cv.hl(0, W - 1, 5, "x")
    cv.rect(20, 7, 24, 7, "Q")
    cv.frame(20, 7, 24, 7, "g")
    for px in (4, 55):
        cv.rect(px, 5, 5, 31, "d")
        cv.vl(px, 5, 35, "R")
        cv.vl(px + 4, 5, 35, "b")
    ground(cv, 36, "brick")
    # lid leaning behind
    cv.poly([(17, 24), (40, 20), (41, 23), (18, 28)], "b")
    cv.line(17, 24, 40, 20, "B")
    # crate
    crate(cv, 15, 29, 28, 14, "B", "w")
    # papers sticking out
    for i, (x, y, w0, c) in enumerate(((17, 24, 6, "p"), (23, 22, 7, "h"), (30, 23, 6, "P"),
                                        (36, 25, 5, "p"), (20, 26, 8, "S"), (32, 26, 7, "h"))):
        cv.rect(x, y, w0, 5, c)
        cv.hl(x, x + w0 - 1, y + 4, "P")
        cv.vl(x + w0 - 1, y, y + 4, "P")
        if i % 2 == 0:
            cv.put(x + 1, y + 1, "r")
        cv.hl(x + 1, x + w0 - 2, y + 2, "b" if i % 3 else "o")
    cv.hl(15, 42, 29, "g")
    # loose sheets on the floor
    cv.rect(8, 44, 5, 3, "p")
    cv.put(9, 45, "r")
    cv.rect(44, 45, 6, 2, "h")
    # clerk bringing another armful
    a = person(cv, 53, 47, CLERK, legs="walk", arm="hold", arm2="hold", face=-1)
    hx, hy = a["hand"]
    for i in range(3):
        cv.rect(hx - 4, hy - 1 - i * 2, 6, 2, ("p", "h", "S")[i])
        cv.hl(hx - 4, hx + 1, hy - i * 2, "P")
    vignette(cv, 0.6)


@art("illus.bf.any.house_offer")
def bf_house_offer(cv, r):
    sky(cv, "day", 42)
    # old house: horse-head gable, white wall, black door with rings
    gable(cv, 2, 40, 4, 16, "h", "f")
    cv.rect(2, 16, 39, 26, "h")
    cv.vl(40, 4, 41, "P")
    tile_roof(cv, 10, 32, 18, 3)
    plank_door(cv, 15, 24, 12, 18, "x", "Q")
    cv.rect(13, 22, 16, 2, "f")
    lattice(cv, 33, 22, 6, 6, "w", "P")
    lattice(cv, 4, 22, 6, 6, "w", "P")
    cv.dither(2, 38, 39, 4, "h", "P", 0.4, only=("h",))
    # willow at the right
    cv.vl(58, 6, 40, "b")
    for i in range(10):
        x = 52 + i
        cv.vl(x, 6 + (i % 3), 20 + (i * 7) % 9, "l")
    ground(cv, 42, "slab")
    person(cv, 21, 45, RUHUA, arm="down", arm2=None, face=1)
    a = person(cv, 47, 46, FEDORA.but(coat="B", coat2="b"), arm="give", face=-1)
    hx, hy = a["hand"]
    silver(cv, hx - 5, hy, 4)


@art("illus.bf.any.mystery_box")
def bf_mystery_box(cv, r):
    # night shop: a stranger pushes a locked, roped box up onto the high counter
    lay = layer()
    shelves(lay, r, 0, 0, W, 34)
    lay.remap(NIGHT)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    counter(cv, 34)
    bx, by, bw, bh = 22, 20, 22, 14
    cv.rect(bx, by, bw, bh, "b")
    cv.rect(bx, by, bw, 3, "B")
    cv.hl(bx, bx + bw - 1, by + 3, "w")
    cv.frame(bx, by, bw, bh, "k")
    for cx0, cy0 in ((bx + 1, by + 1), (bx + bw - 2, by + 1), (bx + 1, by + bh - 2),
                     (bx + bw - 2, by + bh - 2)):
        cv.put(cx0, cy0, "Y")
    cv.vl(bx + 5, by, by + bh - 1, "P")
    cv.vl(bx + bw - 6, by, by + bh - 1, "P")
    cv.rect(bx + bw // 2 - 1, by + 3, 3, 4, "Y")
    cv.put(bx + bw // 2, by + 5, "k")
    oil_lamp(cv, 9, 33)
    person(cv, 55, 48, STRANGER.but(coat="f", coat2="q"), arm="upfwd", arm2=(-1, -5), face=-1)
    cv.glow(10, 27, 19, 13, 1.0)


@art("illus.bf.any.quiet_fee")
def bf_quiet_fee(cv, r):
    # back alley: a red packet slipped into a hand held behind the back
    sky(cv, "dusk", 10)
    cv.rect(0, 8, W, 32, "h")
    wall_plaster(cv, 0, 10, W, 30, "h", "P", r)
    cv.hl(0, W - 1, 8, "f")
    cv.hl(0, W - 1, 9, "E")
    cv.rect(54, 10, 10, 30, "P")
    cv.vl(54, 10, 39, "s")
    cv.rect(0, 30, W, 10, "P")
    cv.hl(0, W - 1, 30, "s")
    ground(cv, 40, "slab")
    person(cv, 40, 45, SOLDIER, arm="down", arm2=(-3, 4), face=1)
    a = person(cv, 21, 46, RUHUA, arm=(6, 2), arm2="down", face=1, lean=1)
    hx, hy = a["hand"]
    cv.rect(hx, hy - 1, 2, 3, "r")
    cv.put(hx, hy - 1, "R")


@art("illus.bf.any.ship_ticket")
def bf_ship_ticket(cv, r):
    sky(cv, "warm", 24)
    cv.ellipse(12, 20, 4, 4, "c")
    cv.hl(0, W - 1, 23, "s")
    water(cv, r, 24, 48, "I", "m", "c", 30)
    # steamer
    cv.poly([(6, 28), (40, 28), (37, 33), (9, 33)], "q")
    cv.hl(6, 40, 28, "t")
    cv.rect(11, 23, 22, 5, "h")
    cv.hl(11, 32, 23, "W")
    for x in range(13, 31, 3):
        cv.rect(x, 25, 2, 1, "f")
    cv.rect(20, 15, 4, 8, "Q")
    cv.hl(20, 23, 17, "r")
    for i in range(7):
        cv.ellipse(25 + i * 3, 12 - i, 2 + i * 0.4, 1.6, "m" if i % 2 else "s")
    cv.dither(6, 33, 34, 1, "i", "I", 0.5)
    # the ticket, held up close
    cv.rect(41, 22, 18, 18, "p")
    cv.frame(41, 22, 18, 18, "r")
    cv.vl(53, 22, 39, "P")
    for y in range(23, 39, 2):
        cv.put(53, y, "p")
    cv.rect(43, 25, 8, 1, "b")
    cv.rect(43, 28, 6, 1, "b")
    cv.rect(43, 31, 8, 1, "b")
    cv.rect(55, 26, 2, 2, "r")
    cv.vl(58, 23, 39, "B")
    cv.hl(41, 58, 39, "B")
    hand(cv, 46, 37, "N", "i")


@art("illus.bf.any.street_bed")
def bf_street_bed(cv, r):
    # rainy night street; a lit doorway, someone waves her in
    lay = layer()
    lay.rect(0, 0, W, 40, "h")
    wall_plaster(lay, 0, 0, W, 40, "h", "P", r)
    tile_roof(lay, 0, W - 1, 0, 3)
    lay.rect(36, 10, 20, 30, "x")
    ground(lay, 40, "slab")
    lay.remap(NIGHT)
    lay.remap(NIGHT, box=(0, 0, W, 40))
    cv.paste(lay, 0, 0)
    cv.rect(38, 12, 16, 28, "c")
    cv.rect(38, 34, 16, 6, "N")
    table(cv, 46, 30, 8, 10, "B")
    oil_lamp(cv, 49, 29)
    person(cv, 41, 41, OLDWOMAN, arm="fwd", face=-1)
    cv.poly([(38, 40), (54, 40), (62, 48), (24, 48)], "t")
    a = person(cv, 16, 46, BEGGAR.but(head="bob", coat="E", legs="t"), arm="hold", face=1)
    hx, hy = a["hand"]
    cv.rect(hx - 2, hy - 1, 4, 3, "B")
    rain(cv, r, 22, "t", 1, 4, (0, 2, 36, 46))
    cv.glow(46, 26, 14, 18, 0.5)



def ink_peaks(cv, x0, y0, w, h):
    # a landscape painting as filled ink-wash peaks (solid shapes, never a bare line that reads as a chart)
    base = y0 + h - 1
    for cx, top, slope, c in ((x0 + w * 2 // 5, y0, 1.3, "t"), (x0 + w * 3 // 4, y0 + h // 3, 1.0, "s")):
        for x in range(x0, x0 + w):
            y = int(top + abs(x - cx) * slope)
            if y <= base:
                cv.vl(x, y, base, c)
    cv.hl(x0, x0 + w - 1, base, "m")


@art("illus.bf.any.sun_guarantee")
def bf_sun_guarantee(cv, r):
    # Sun's study: a guarantee paper, the seal box and silver on the rosewood table
    cv.rect(0, 0, W, 34, "P")
    wall_plaster(cv, 0, 0, W, 34, "P", "B", r)
    cv.rect(0, 28, W, 6, "b")
    cv.hl(0, W - 1, 28, "w")
    ground(cv, 34, "floor")
    lattice(cv, 3, 6, 10, 14, "w", "p")
    # hanging landscape scroll
    cv.rect(26, 2, 14, 20, "p")
    cv.hl(25, 40, 2, "w")
    cv.hl(25, 40, 21, "w")
    ink_peaks(cv, 27, 5, 12, 12)
    cv.rect(36, 18, 2, 2, "r")
    a = person(cv, 48, 38, GENTRY.but(coat="j", coat2="f"), legs="sit", arm="fwd", face=-1)
    hx, hy = a["head"]
    cv.pts([(hx - 1, hy + 3), (hx - 2, hy + 3), (hx - 2, hy + 4)], "m")
    table(cv, 14, 33, 44, 15, "x", "w")
    paper(cv, 24, 29, 12, 5, "S", "b", None, r, 3)
    cv.rect(33, 30, 2, 2, "r")
    cv.rect(38, 30, 4, 3, "r")
    cv.hl(38, 41, 30, "R")
    silver(cv, 44, 32, 3)
    silver(cv, 49, 32, 2)
    person(cv, 9, 48, RUHUA, arm="down", face=1)


# =========================================================================== demands (dm)


@art("illus.dm.goods")
def dm_goods(cv, r):
    # goods levy: a handcart in front of the shop, loaded with rice, cloth and copper
    sky(cv, "day", 10)
    shopfront(cv, 0, 2, 30, 38, r, banner="r")
    shopfront(cv, 30, 4, 34, 36, r, "P", "w")
    ground(cv, 40, "slab")
    # cart
    cv.rect(16, 30, 26, 4, "B")
    cv.hl(16, 41, 30, "P")
    cv.hl(16, 41, 33, "b")
    cv.line(41, 31, 50, 28, "b")
    for wx in (21, 36):
        cv.ellipse(wx, 37, 3.5, 3.5, "w")
        cv.ellipse(wx, 37, 2, 2, "b")
        cv.put(wx, 37, "x")
    rice_sack(cv, 17, 23, 10, 7, "P")
    cv.rect(28, 25, 8, 2, "i")
    cv.rect(28, 27, 8, 2, "B")
    cv.rect(29, 23, 6, 2, "l")
    cv.ellipse(39, 27, 3, 2.5, "Y")
    cv.ellipse(38, 26, 1.5, 1, "e")
    cv.hl(36, 42, 25, "g")
    a = person(cv, 54, 46, SOLDIER, arm="fwd", face=-1)
    person(cv, 8, 46, RUHUA, arm="hold", arm2="hold", face=1)
    rice_sack(cv, 9, 33, 7, 5, "P", tie=False)


@art("illus.dm.info")
def dm_info(cv, r):
    # asked who comes to the shop: an officer leans over the counter at the visitors' book
    lay = layer()
    shelves(lay, r, 0, 0, 30, 33)
    lay.rect(30, 0, 34, 33, "w")
    lattice(lay, 34, 3, 27, 22, "w", "P", 4)
    lay.remap(DARK, box=(0, 0, 30, 33))
    cv.paste(lay, 0, 0)
    person(cv, 10, 40, RUHUA, arm=None, face=1)
    person(cv, 47, 41, POLICE, arm=(5, 3), arm2=None, face=-1, lean=2)
    counter(cv, 33)
    # the open register lying on the counter
    cv.poly([(19, 27), (41, 27), (43, 33), (17, 33)], "p")
    cv.hl(19, 41, 27, "h")
    cv.vl(30, 27, 33, "P")
    cv.hl(17, 43, 33, "B")
    for x in range(21, 29, 2):
        cv.vl(x, 29, 31, "o")
    for x in range(32, 41, 2):
        cv.vl(x, 29, 30 + (x // 2) % 2, "o")
    cv.frame(35, 28, 4, 5, "r")
    cv.line(12, 33, 16, 30, "b")
    oil_lamp(cv, 4, 32)
    cv.glow(5, 27, 15, 10, 0.9)


@art("illus.dm.money")
def dm_money(cv, r):
    # levy office: coins pushed in under the barred window to the clerk
    wall_plaster(cv, 0, 0, W, 40, "s", "t", r)
    ground(cv, 40, "brick")
    cv.rect(16, 4, 32, 26, "w")
    cv.frame(16, 4, 32, 26, "x")
    inner = layer()
    inner.rect(18, 6, 28, 22, "o")
    inner.rect(18, 6, 28, 3, "b")
    person(inner, 34, 36, CLERK, arm="give", face=-1)
    clip(inner, 18, 6, 46, 28)
    cv.paste(inner, 0, 0)
    for x in range(20, 46, 4):
        cv.vl(x, 6, 24, "x")
    cv.rect(18, 25, 28, 3, "w")
    # ledge with silver and strings of copper cash
    cv.rect(14, 28, 36, 3, "b")
    cv.hl(14, 49, 28, "B")
    silver(cv, 26, 27, 3)
    silver(cv, 31, 27, 2)
    for i in range(3):
        cv.hl(36 + i, 44 - i, 27 - i, "Y" if i % 2 else "g")
    cv.put(35, 27, "r")
    paper(cv, 51, 7, 10, 16, "p", "b", "r", r)
    cv.hl(51, 60, 6, "t")
    person(cv, 9, 47, RUHUA, arm=(6, -4), arm2="down", face=1)


@art("illus.dm.people")
def dm_people(cv, r):
    # labour levy: men with shovels marched off along the road under guard
    sky(cv, "grey", 26)
    for x in range(W):
        hgt = int(4 + 2 * math.sin(x * 0.12) + math.sin(x * 0.5))
        cv.vl(x, 26 - hgt, 26, "s")
    # town wall far left
    cv.rect(0, 14, 14, 12, "t")
    for x in range(0, 14, 4):
        cv.rect(x, 12, 3, 2, "t")
    cv.rect(0, 26, W, 22, "B")
    cv.poly([(0, 30), (W, 27), (W, 36), (0, 44)], "o")
    cv.dither(0, 30, W, 14, "o", "B", 0.15, only=("o",))
    # trees
    for tx in (50, 58):
        cv.vl(tx, 16, 27, "b")
        cv.ellipse(tx, 15, 4, 4, "l")
        cv.ellipse(tx - 1, 14, 2, 2, "J")
    looks = [WORKER, PORTER, WORKER.but(coat="B", hat=None), PORTER.but(coat="t")]
    for i, lk in enumerate(looks):
        fx = 22 + i * 10
        fy = 43 - i * 2
        a = person(cv, fx, fy, lk, legs="walk", arm="head", face=1)
        hx, hy = a["hand"]
        cv.line(hx - 4, hy + 3, hx + 3, hy - 3, "B")
        cv.rect(hx + 3, hy - 4, 2, 2, "s")
    a = person(cv, 8, 46, SOLDIER, legs="walk", arm="hold", face=1)
    hx, hy = a["hand"]
    cv.line(hx - 1, hy + 2, hx + 2, hy - 9, "w")


@art("illus.fa.1938.door_fine")
def fa_door_fine(cv, r):
    # a fine pasted on the shop door; the committee man walks off
    sky(cv, "day", 6)
    wall_plaster(cv, 0, 4, W, 38, "h", "P", r)
    tile_roof(cv, 0, W - 1, 1, 3)
    cv.rect(13, 8, 32, 34, "x")
    plank_door(cv, 15, 10, 28, 32, "b", "w", ring=False)
    cv.pts([(27, 30), (30, 30)], "Y")
    cv.pts([(27, 31), (30, 31)], "g")
    paper(cv, 23, 13, 12, 14, "S", "b", None, r)
    cv.rect(30, 22, 3, 3, "r")
    cv.put(31, 23, "R")
    cv.pts([(23, 13), (34, 13), (23, 26), (34, 26)], "P")
    broom(cv, 6, 24, 18)
    ground(cv, 42, "slab")
    person(cv, 55, 46, CLERK.but(hat=None, coat="t", coat2="E"), legs="walk", arm="down",
           face=1, band="h")


@art("illus.fa.1938.kin_money")
def fa_kin_money_1938(cv, r):
    # the postman hands a remittance envelope across the shop door
    sky(cv, "day", 8)
    pawnshop_front(cv, r, 0, 63, 4, 42, (10, 34))
    cv.rect(11, 13, 23, 3, "w")
    ground(cv, 42, "slab")
    person(cv, 20, 44, RUHUA, arm="give", face=1)
    a = person(cv, 41, 46, POSTMAN, arm="give", face=-1)
    hx, hy = a["hand"]
    envelope(cv, hx - 4, hy - 4, 4, 7)
    cv.rect(44, 36, 5, 5, "B")
    cv.hl(44, 48, 36, "P")
    cv.line(44, 36, 39, 27, "b")


@art("illus.fa.1938.requisition")
def fa_requisition_1938(cv, r):
    # word of requisition: a posted order by the canal, boats and grain under guard
    sky(cv, "grey", 14)
    cv.rect(0, 6, 38, 30, "h")
    wall_plaster(cv, 0, 8, 38, 28, "h", "P", r)
    tile_roof(cv, 0, 37, 5, 2)
    paper(cv, 11, 12, 14, 16, "p", "b", None, r)
    cv.rect(21, 23, 3, 3, "r")
    ground(cv, 36, "slab")
    for x, y in ((40, 6), (50, 9), (58, 5)):
        cv.rect(x, y, 7, 8, "s")
        cv.hl(x - 1, x + 7, y, "t")
    cv.rect(38, 14, 26, 16, "m")
    water(cv, r, 30, 48, "i", "I", "m", 12, x0=38)
    cv.hl(38, 63, 29, "t")
    cv.rect(36, 30, 3, 18, "t")
    cv.vl(38, 30, 47, "E")
    boat(cv, 41, 42, 22, "b", "q")
    rice_sack(cv, 45, 32, 7, 4, "P", tie=False)
    rice_sack(cv, 51, 32, 7, 4, "P", tie=False)
    small_person(cv, 5, 46, WORKER, "stand", face=1)
    small_person(cv, 14, 46, WOMAN.but(coat="B"), "stand", face=-1)
    a = person(cv, 31, 46, SOLDIER, arm="fwd", face=1)
    cv.line(25, 39, 29, 26, "w")


@art("illus.fa.1938.rice_ease")
def fa_rice_ease(cv, r):
    # new rice in: heaped baskets in front of the rice shop
    sky(cv, "warm", 8)
    cv.rect(0, 6, W, 36, "w")
    cv.rect(2, 12, 60, 22, "x")
    cv.poly([(0, 6), (63, 6), (60, 12), (3, 12)], "P")
    for x in range(2, 62, 4):
        cv.vl(x, 7, 11, "B")
    cv.hl(0, 63, 12, "b")
    cv.rect(6, 18, 16, 12, "b")
    cv.hl(6, 21, 18, "B")
    cv.ellipse(14, 18, 7, 2, "h")
    cv.vl(32, 12, 22, "B")
    cv.hl(28, 40, 16, "B")
    cv.rect(39, 17, 2, 3, "f")
    cv.line(29, 16, 27, 22, "o")
    cv.line(29, 16, 31, 22, "o")
    cv.hl(26, 32, 23, "B")
    ground(cv, 42, "slab")
    cv.rect(2, 34, 44, 4, "b")
    cv.hl(2, 45, 34, "B")
    for bx in (4, 18, 32):
        basket(cv, bx, 30, 12)
    cv.vl(14, 24, 30, "B")
    cv.rect(12, 21, 5, 4, "P")
    a = person(cv, 52, 46, PORTER.but(coat="B", hair="m"), arm="give", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 3, hy - 1, 3, 2, "B")
    cv.put(hx - 3, hy - 2, "h")


@art("illus.fa.1939.charcoal_wind")
def fa_charcoal_wind(cv, r):
    # winter wind; the firewood seller with two bundles on his pole
    sky(cv, "grey", 34)
    for x0, w0, h0 in ((0, 12, 14), (11, 9, 18), (22, 14, 12), (40, 10, 16)):
        cv.rect(x0, 30 - h0, w0, h0, "m")
        cv.hl(x0 - 1, x0 + w0, 30 - h0, "s")
    # bare tree
    cv.vl(56, 8, 34, "b")
    cv.line(56, 16, 49, 9, "b")
    cv.line(56, 13, 62, 6, "b")
    cv.line(52, 12, 52, 7, "b")
    cv.line(59, 10, 63, 11, "b")
    ground(cv, 34, "slab")
    a = person(cv, 30, 45, PORTER.but(coat="t", legs="E"), legs="walk", arm="head", face=-1)
    hx, hy = a["hand"]
    cv.line(hx - 12, hy + 1, hx + 12, hy - 1, "B")
    firewood(cv, hx - 15, hy + 3, 6, 9)
    firewood(cv, hx + 9, hy + 1, 6, 9)
    cv.vl(hx - 12, hy + 1, hy + 3, "P")
    cv.vl(hx + 12, hy - 1, hy + 1, "P")
    for x, y, n in ((4, 10, 7), (14, 20, 5), (40, 14, 8), (6, 30, 4), (46, 26, 6)):
        cv.hl(x, x + n, y, "h")
    cv.pts([(10, 24), (21, 15), (46, 21), (62, 30), (36, 9)], "B")


@art("illus.fa.1939.district_fine")
def fa_district_fine(cv, r):
    # district office: the clerk brings his seal down on a fine
    wall_plaster(cv, 0, 0, W, 28, "P", "B", r)
    cv.rect(0, 22, W, 6, "b")
    cv.hl(0, W - 1, 22, "w")
    ground(cv, 28, "floor")
    cv.rect(22, 3, 20, 6, "Q")
    cv.frame(22, 3, 20, 6, "g")
    person(cv, 55, 41, SOLDIER, arm="down", face=-1)
    a = person(cv, 34, 37, CLERK.but(coat="E", coat2="f"), legs="sit", arm=(3, -3), face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 1, hy - 3, 2, 3, "w")
    cv.rect(hx - 2, hy, 4, 2, "r")
    table(cv, 14, 31, 36, 17, "w", "b")
    paper(cv, 22, 28, 10, 4, "S", "b", None, r, 2)
    cv.pts([(22, 31), (25, 30)], "r")
    cv.rect(37, 28, 4, 3, "r")
    person(cv, 8, 47, RUHUA, arm="down", face=1)


@art("illus.fa.1939.gate_wink")
def fa_gate_wink(cv, r):
    # at the gate post: a few coins dropped into the sentry's open palm
    sky(cv, "day", 36)
    cv.rect(0, 2, 30, 34, "t")
    for y in range(2, 36, 3):
        cv.hl(0, 29, y, "E")
    for x in range(0, 30, 6):
        cv.rect(x, 0, 4, 2, "t")
    cv.rect(6, 14, 14, 22, "Q")
    cv.ellipse(13, 15, 7, 4, "Q")
    # sentry box
    cv.rect(47, 14, 14, 26, "B")
    cv.rect(49, 18, 10, 8, "x")
    cv.poly([(45, 14), (62, 14), (59, 10), (48, 10)], "b")
    cv.vl(60, 14, 39, "b")
    ground(cv, 36, "earth")
    cv.rect(0, 36, W, 12, "o")
    cv.rect(0, 42, W, 6, "B")
    cv.hl(0, W - 1, 41, "B")
    sawhorse(cv, 2, 33, 18)
    a = person(cv, 44, 46, SOLDIER, arm="low", face=-1)
    hx, hy = a["hand"]
    b = person(cv, 26, 46, RUHUA, arm="give", face=1)
    cv.pts([(hx, hy - 3), (hx - 1, hy - 5), (hx + 1, hy - 1)], "Y")
    cv.put(hx, hy - 1, "e")
    cv.line(48, 37, 50, 22, "w")


@art("illus.fa.1939.year_remittance")
def fa_year_remittance(cv, r):
    # New Year remittance: envelope and silver on the table; snow at the window
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    lattice(cv, 4, 4, 22, 20, "w", "m", 4)
    snow(cv, r, 30, (5, 5, 25, 23), ("W", "h"))
    cv.ellipse(15, 14, 3, 3, "r")
    cv.pts([(15, 10), (15, 18), (11, 14), (19, 14)], "r")
    cv.put(15, 14, "R")
    for x in (56, 61):
        cv.rect(x, 2, 3, 26, "r")
        for y in range(5, 26, 5):
            cv.put(x + 1, y, "Y")
    lantern(cv, 44, 3, "r", lit=False)
    table(cv, 0, 30, W, 18, "w", "b", legs=False)
    cv.rect(0, 34, W, 14, "w")
    cv.hl(0, W - 1, 33, "x")
    envelope(cv, 14, 23, 14, 8, "h", "r")
    silver(cv, 32, 31, 3)
    silver(cv, 38, 31, 4)
    silver(cv, 44, 31, 2)


@art("illus.fa.1940.old_buyer")
def fa_old_buyer(cv, r):
    # spring: an old customer comes back and admires a vase on the counter
    lay = layer()
    shelves(lay, r, 0, 0, 42, 33)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    cv.rect(42, 0, 22, 33, "w")
    cv.rect(45, 3, 16, 30, "c")
    cv.rect(45, 26, 16, 7, "P")
    for i in range(6):
        x = 47 + i * 2
        cv.line(x, 3, x - 1, 10 + (i * 5) % 9, "l")
    cv.hl(45, 60, 3, "b")
    person(cv, 13, 45, RUHUA, arm=None, face=1)
    counter(cv, 33)
    vase(cv, 26, 32, 11)
    a = person(cv, 46, 49, GENTRY.but(coat="B", coat2="b"), arm="fwd", arm2="down", face=-1)
    hx, hy = a["hand2"]
    cv.line(hx, hy, hx + 1, 47, "x")


@art("illus.fa.1940.rice_spike")
def fa_rice_spike(cv, r):
    # rice shot up: a crowd presses at the rice shop window
    sky(cv, "grey", 10)
    cv.rect(0, 6, W, 34, "w")
    cv.poly([(0, 6), (63, 6), (60, 10), (3, 10)], "t")
    cv.rect(16, 13, 32, 15, "x")
    cv.frame(15, 12, 34, 17, "b")
    person(cv, 38, 36, PORTER.but(coat="B", hair="m"), arm="fwd", face=-1)
    basket(cv, 18, 22, 9)
    cv.rect(15, 28, 34, 3, "b")
    cv.hl(15, 48, 28, "B")
    ground(cv, 40, "slab")
    looks = [WORKER, WOMAN, PORTER, OLDWOMAN, WORKER.but(coat="i"), WOMAN.but(coat="B"),
             PORTER.but(coat="E")]
    for i, lk in enumerate(looks):
        fx = 8 + i * 8
        fy = 46 + (i % 2) * 2
        small_person(cv, fx, fy, lk, "stand", face=1 if i < 4 else -1)
        if i % 2 == 0:
            cv.vl(fx + (1 if i < 4 else -1), fy - 16, fy - 11, lk.coat)
            cv.rect(fx + (0 if i < 4 else -2), fy - 18, 3, 2, "P" if i % 4 else "B")
    for x, y in ((6, 26), (58, 24), (30, 31)):
        cv.pts([(x, y), (x + 1, y - 1), (x + 2, y)], "h")


@art("illus.fa.1940.spring_rain")
def fa_spring_rain(cv, r):
    # days of spring rain: she hurries goods in from the wet back yard
    lay = layer()
    lay.rect(0, 0, 30, 40, "w")
    for x in range(0, 30, 4):
        lay.vl(x, 0, 39, "x")
    shelves(lay, r, 2, 4, 20, 26)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    cv.rect(30, 0, 34, 40, "s")
    cv.rect(30, 0, 34, 8, "t")
    for x in range(34, 64, 8):
        cv.rect(x, 9, 6, 26, "m")
    cv.rect(30, 32, 34, 8, "t")
    rain(cv, r, 70, "h", 1, 4, (30, 0, 64, 40))
    cv.vl(30, 0, 39, "x")
    cv.vl(31, 0, 39, "b")
    ground(cv, 40, "floor")
    for y in range(4, 20, 4):
        cv.put(14, y, "m")
    bowl(cv, 11, 41, "t", "m")
    cv.hl(8, 19, 44, "m")
    a = person(cv, 36, 46, RUHUA.but(coat="i"), legs="walk", arm="hold", arm2="hold", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 4, hy - 3, 6, 5, "B")
    cv.hl(hx - 4, hx + 1, hy - 3, "P")


@art("illus.fa.1940.whisper")
def fa_whisper(cv, r):
    # night office: someone leans in to the new official's ear
    cv.rect(0, 0, W, 34, "x")
    cv.rect(0, 0, W, 34, "w")
    for x in range(0, W, 5):
        cv.vl(x, 0, 33, "x")
    lattice(cv, 40, 4, 16, 14, "x", "n", 4)
    moon(cv, 50, 8, 2)
    ground(cv, 34, "floor")
    new_off = Look(coat="q", coat2="Q", legs="Q", hair="Q", accent="h")
    person(cv, 40, 39, new_off, legs="sit", arm="fwd", face=-1)
    person(cv, 26, 44, WORKER.but(coat="t", hat="cap"), arm="head", face=1, lean=2)
    table(cv, 20, 34, 40, 14, "w", "b")
    oil_lamp(cv, 50, 33)
    cv.rect(28, 31, 7, 3, "p")
    cv.glow(50, 27, 18, 14, 1.0)
    cv.glow(34, 26, 12, 10, 0.5)


@art("illus.fa.any.clear_road")
def fa_clear_road(cv, r):
    # the sky clears: a dry bright street fills with people
    sky(cv, "day", 16)
    cv.ellipse(8, 5, 3.5, 3.5, "y")
    cv.ellipse(8, 5, 2, 2, "W")
    for x0, y0 in ((22, 4), (44, 7)):
        cv.hl(x0, x0 + 8, y0, "W")
        cv.hl(x0 + 2, x0 + 6, y0 - 1, "W")
    shopfront(cv, 0, 10, 22, 30, r, banner="r")
    shopfront(cv, 22, 12, 20, 28, r, "P", "w", banner="j")
    shopfront(cv, 42, 9, 22, 31, r, banner="i")
    ground(cv, 40, "slab")
    cv.hl(30, 36, 44, "h")
    cv.hl(31, 35, 45, "m")
    small_person(cv, 8, 47, WORKER, "walk", face=1)
    small_person(cv, 50, 46, WOMAN.but(coat="R"), "walk", face=-1)
    small_person(cv, 58, 47, CLERK, "gown", face=-1)
    a = person(cv, 27, 47, PORTER, legs="walk", arm="head", face=1)
    hx, hy = a["hand"]
    cv.line(hx - 9, hy + 1, hx + 9, hy - 1, "B")
    basket(cv, hx - 12, hy + 3, 6)
    basket(cv, hx + 7, hy + 1, 6)


@art("illus.fa.any.damp_loss")
def fa_damp_loss(cv, r):
    # damp has got into the chest: she lifts out a spotted cloth
    wall_plaster(cv, 0, 0, W, 34, "P", "B", r)
    cv.dither(0, 24, W, 10, "P", "B", 0.3)
    lattice(cv, 40, 4, 16, 14, "w", "s", 4)
    rain(cv, r, 14, "h", 1, 3, (41, 5, 55, 17))
    ground(cv, 34, "floor")
    cv.vl(30, 0, 6, "m")
    cv.put(30, 10, "m")
    cv.put(30, 15, "m")
    cv.hl(27, 33, 44, "m")
    # open chest
    cv.poly([(18, 22), (44, 22), (46, 30), (16, 30)], "b")
    cv.rect(16, 30, 30, 12, "B")
    cv.frame(16, 30, 30, 12, "w")
    cv.rect(18, 28, 26, 3, "i")
    cv.rect(20, 27, 10, 2, "R")
    cv.rect(31, 27, 11, 2, "l")
    for x, y in ((21, 29), (26, 28), (35, 28), (40, 29), (33, 27)):
        cv.put(x, y, "G")
    cv.pts([(29, 34), (30, 34)], "Y")
    a = person(cv, 54, 46, RUHUA, legs="kneel", arm="fwd", arm2="fwd", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 6, hy - 1, 6, 7, "i")
    cv.pts([(hx - 5, hy + 1), (hx - 3, hy + 3), (hx - 2, hy), (hx - 5, hy + 4)], "G")


@art("illus.fa.any.false_charge")
def fa_false_charge(cv, r):
    # a man waves a written complaint at the shop; an officer has come with him
    sky(cv, "grey", 6)
    pawnshop_front(cv, r, 0, 30, 2, 40, (8, 24))
    wall_plaster(cv, 31, 4, 33, 36, "h", "P", r)
    tile_roof(cv, 31, 63, 2, 2)
    ground(cv, 40, "slab")
    person(cv, 15, 41, RUHUA, arm="chest", face=1)
    person(cv, 56, 45, POLICE, arm="down", face=-1)
    a = person(cv, 40, 47, Look(coat="q", coat2="Q", legs="f", hat="cap", hatc="Q"),
               arm="fwd", arm2="up", face=-1)
    hx, hy = a["hand2"]
    paper(cv, hx - 2, hy - 7, 5, 8, "S", "b", "r", r, 1)


@art("illus.fa.any.fire_next_door")
def fa_fire_next_door(cv, r):
    # night: the shop next door burns; she carries goods out, a neighbour throws water
    sky(cv, "night", 20)
    lay = layer()
    pawnshop_front(lay, r, 0, 28, 10, 40, (7, 21))
    shopfront(lay, 29, 12, 35, 28, r, "h", "b")
    ground(lay, 40, "slab")
    at_night(cv, lay)
    for i in range(6):
        cv.ellipse(36 + i * 4 + r.randrange(3), 8 - i + r.randrange(3), 5, 3, "f" if i % 2 else "E")
    flames(cv, r, 31, 62, 20, 12)
    flames(cv, r, 40, 56, 30, 6)
    cv.rect(31, 22, 33, 8, "x")
    flames(cv, r, 33, 60, 29, 5)
    cv.glow(46, 22, 30, 26, 1.0)
    a = person(cv, 14, 46, RUHUA, legs="walk", arm="hold", arm2="hold", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 5, hy - 3, 7, 5, "B")
    cv.hl(hx - 5, hx + 1, hy - 3, "P")
    b = person(cv, 38, 47, PORTER, legs="walk", arm="upfwd", arm2="fwd", face=1)
    hx, hy = b["hand"]
    cv.rect(hx - 1, hy - 1, 3, 3, "b")
    cv.pts([(hx + 2, hy - 2), (hx + 3, hy - 3), (hx + 4, hy - 3), (hx + 5, hy - 4), (hx + 4, hy - 2)], "m")
    cv.glow(46, 40, 24, 8, 0.6)


@art("illus.fa.any.found_claim")
def fa_found_claim(cv, r):
    # the owner comes back for the purse: it lies on the counter between them
    lay = layer()
    shelves(lay, r, 0, 0, W, 33)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    person(cv, 11, 42, RUHUA, arm="give", face=1)
    counter(cv, 33)
    purse(cv, 25, 24, "i", big=True)
    person(cv, 46, 48, WOMAN.but(coat="R", coat2="r"), arm="upfwd", face=-1)


@art("illus.fa.any.found_purse")
def fa_found_purse(cv, r):
    # a purse in the street, coins spilling from its mouth; she stoops to it
    wall_plaster(cv, 0, 0, W, 16, "h", "P", r)
    cv.hl(0, W - 1, 0, "E")
    cv.rect(0, 14, W, 2, "s")
    cv.rect(0, 16, W, 32, "s")
    for i, y in enumerate((16, 21, 28, 37)):
        cv.hl(0, W - 1, y, "t")
        hgt = (5, 7, 9, 11)[i]
        for x in range((i * 7) % 13, W, 13 + i * 3):
            cv.vl(x, y, min(47, y + hgt - 1), "t")
    cv.dither(0, 17, W, 2, "s", "m", 0.3, only=("s",))
    cv.ellipse(36, 42, 8, 2, "t")
    purse(cv, 29, 32, "i", big=True)
    for x, y in ((40, 40), (42, 41), (38, 42), (44, 39), (46, 41)):
        cv.put(x, y, "Y")
        cv.put(x + 1, y, "g")
    a = person(cv, 18, 44, RUHUA, legs="squat", arm=(5, 3), face=1)


@art("illus.fa.any.illness")
def fa_illness(cv, r):
    # laid up in the curtained bed, a damp cloth on the brow, medicine steaming by the bed
    wall_plaster(cv, 0, 0, W, 34, "B", "b", r)
    lattice(cv, 50, 4, 11, 12, "w", "s", 4)
    ground(cv, 34, "floor")
    # canopy bed frame and gathered netting
    cv.vl(3, 6, 42, "w")
    cv.vl(44, 6, 42, "w")
    cv.hl(2, 45, 6, "x")
    cv.hl(3, 44, 7, "b")
    cv.poly([(4, 8), (12, 8), (7, 24), (4, 26)], "h")
    cv.vl(10, 9, 15, "P")
    cv.poly([(43, 8), (36, 8), (40, 22), (43, 24)], "h")
    cv.vl(39, 9, 14, "P")
    cv.rect(3, 33, 42, 6, "b")
    cv.hl(3, 44, 33, "B")
    cv.hl(3, 44, 38, "w")
    # pillow and head
    cv.rect(5, 26, 9, 5, "h")
    cv.hl(5, 13, 30, "P")
    cv.ellipse(9, 27.5, 3.2, 2.6, "Q")
    cv.ellipse(11.5, 28, 2.2, 2.0, "N")
    cv.hl(9, 12, 25, "W")
    cv.hl(9, 12, 26, "S")
    # quilt
    cv.poly([(13, 26), (22, 24), (36, 25), (43, 28), (43, 33), (12, 33)], "I")
    cv.hl(14, 35, 25, "m")
    for x, y in ((18, 28), (24, 27), (30, 29), (36, 28), (21, 31), (33, 31), (40, 31)):
        cv.put(x, y, "i")
    cv.rect(14, 29, 3, 2, "N")
    # stool with the medicine bowl
    stool(cv, 48, 37)
    bowl(cv, 48, 35, "h", "x")
    steam(cv, 49, 33, 4, "h")
    cv.remap(DARK, box=(0, 0, 47, H))
    cv.glow(56, 10, 8, 8, 0.5)


@art("illus.fa.any.kin_money")
def fa_kin_money(cv, r):
    # a letter from far-off kin, the notes it carried fanned out under the lamp
    cv.rect(0, 0, W, 26, "w")
    for x in range(0, W, 5):
        cv.vl(x, 0, 25, "x")
    cv.rect(0, 26, W, 22, "b")
    cv.hl(0, W - 1, 26, "B")
    cv.hl(0, W - 1, 27, "w")
    oil_lamp(cv, 9, 31, big=True)
    envelope(cv, 15, 30, 16, 7, "h", "r")
    paper(cv, 24, 22, 16, 13, "p", "b", None, r)
    for i, (x, y, c) in enumerate(((40, 30, "l"), (43, 32, "B"), (46, 34, "J"))):
        cv.rect(x, y, 13, 6, c)
        cv.frame(x, y, 13, 6, DARK.get(c, c))
        cv.rect(x + 2, y + 2, 3, 2, DARK.get(c, c))
        cv.put(x + 9, y + 2, "r")
    cv.glow(10, 26, 18, 12, 1.0)


@art("illus.fa.any.neighbor_row")
def fa_neighbor_row(cv, r):
    # two neighbours quarrel in the street right outside the shop
    sky(cv, "day", 8)
    shopfront(cv, 0, 4, 20, 36, r, "h", "b")
    pawnshop_front(cv, r, 20, 44, 4, 40, (27, 38))
    shopfront(cv, 45, 4, 19, 36, r, "P", "w", banner="j")
    ground(cv, 40, "slab")
    small_person(cv, 32, 39, RUHUA, "stand", face=1)
    person(cv, 16, 47, WOMAN.but(coat="R", coat2="r"), arm="upfwd", arm2="down", face=1)
    person(cv, 45, 47, PORTER.but(coat="i", legs="f"), arm="upfwd", arm2="swing", face=-1)
    for x0, y0 in ((25, 22), (34, 20)):
        cv.pts([(x0, y0), (x0 + 1, y0 - 1), (x0 + 2, y0), (x0 + 3, y0 - 1)], "r")
        cv.pts([(x0 + 1, y0 + 2), (x0 + 2, y0 + 1)], "k")


@art("illus.fa.any.night_knock")
def fa_night_knock(cv, r):
    # night: someone in rags knocks at the closed shop door
    sky(cv, "night", 12)
    stars(cv, r, 8, 8)
    moon(cv, 8, 5, 2)
    lay = layer()
    wall_plaster(lay, 0, 8, W, 34, "h", "P", r)
    tile_roof(lay, 0, W - 1, 8, 3)
    lay.rect(18, 14, 30, 28, "x")
    plank_door(lay, 20, 16, 26, 26, "b", "w")
    ground(lay, 42, "slab")
    at_night(cv, lay)
    cv.hl(20, 45, 41, "e")
    cv.glow(33, 43, 14, 3, 0.8)
    lantern(cv, 52, 13, "r", lit=False)
    person(cv, 15, 46, BEGGAR, arm="upfwd", arm2="down", face=1)
    for x0, y0 in ((21, 22), (22, 26), (21, 30)):
        cv.hl(x0, x0 + 1, y0, "m")


@art("illus.fa.any.regular_intro")
def fa_regular_intro(cv, r):
    # in the teahouse an old customer tells her about a friend who will come by tomorrow
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    lattice(cv, 4, 3, 18, 14, "w", "h", 3)
    lattice(cv, 42, 3, 18, 14, "w", "h", 3)
    cv.rect(0, 26, W, 4, "b")
    cv.hl(0, W - 1, 26, "w")
    ground(cv, 30, "floor")
    a = person(cv, 16, 44, GENTRY.but(coat="B", coat2="b"), legs="sit", arm="give", face=1)
    stool(cv, 9, 39)
    person(cv, 50, 47, RUHUA, arm="down", face=-1)
    table(cv, 22, 34, 20, 14, "w", "b")
    # teapot and cups
    cv.ellipse(31, 31, 3, 2.5, "h")
    cv.rect(30, 28, 2, 1, "h")
    cv.pts([(34, 30), (35, 29)], "h")
    cv.put(27, 30, "h")
    cv.vl(31, 31, 32, "i")
    bowl(cv, 36, 32, "h", "B")
    steam(cv, 37, 30, 3, "W")


@art("illus.fa.any.requisition")
def fa_requisition(cv, r):
    # a soldier walks off with a copper pot from the shelf; she reaches after it
    shelves(cv, r, 0, 0, W, 34)
    cv.rect(20, 6, 9, 4, "x")
    ground(cv, 34, "floor")
    a = person(cv, 44, 46, SOLDIER, legs="walk", arm="hold", arm2="hold", face=1)
    hx, hy = a["hand"]
    cv.ellipse(hx + 1, hy - 1, 4, 3.5, "Y")
    cv.ellipse(hx, hy - 2, 2, 1.5, "e")
    cv.hl(hx - 3, hx + 5, hy - 4, "g")
    person(cv, 20, 46, RUHUA, legs="walk", arm="fwd", face=1)


@art("illus.fa.any.rice_dip")
def fa_rice_dip(cv, r):
    # cheap new rice: a loaded boat at the canal steps, a porter carrying a sack up
    sky(cv, "day", 14)
    for x0, w0, h0 in ((0, 14, 7), (13, 12, 9), (40, 12, 8), (51, 13, 6)):
        cv.rect(x0, 14 - h0, w0, h0, "h")
        cv.hl(x0 - 1, x0 + w0, 14 - h0, "E")
    cv.rect(0, 14, W, 6, "s")
    cv.hl(0, W - 1, 14, "t")
    water(cv, r, 20, 48, "I", "m", "h", 24)
    cv.poly([(0, 20), (22, 20), (32, 48), (0, 48)], "s")
    for i, y in enumerate(range(20, 48, 4)):
        cv.hl(0, 22 + i * 2, y, "t")
    boat(cv, 30, 40, 30, "b", "q")
    for i in range(3):
        rice_sack(cv, 36 + i * 7, 31, 7, 5, "P", tie=False)
    a = person(cv, 18, 41, PORTER, legs="walk", arm="head", face=-1)
    hx, hy = a["hand"]
    rice_sack(cv, hx - 5, hy - 4, 9, 5, "P", tie=False)


@art("illus.fa.any.shop_sealed")
def fa_shop_sealed(cv, r):
    # seal strips crossed over the shutters; the officer still holds the paste brush
    sky(cv, "grey", 6)
    pawnshop_front(cv, r, 0, 63, 2, 42, (None, None))
    for x in range(4, 46, 6):
        cv.rect(x, 12, 5, 30, "b")
        cv.vl(x + 4, 12, 41, "w")
    for i in range(30):
        for k in range(3):
            cv.put(5 + i + k, 13 + i, "S")
            cv.put(43 - i - k, 13 + i, "S")
    cv.rect(21, 25, 4, 4, "r")
    cv.rect(10, 16, 3, 3, "r")
    cv.rect(37, 16, 3, 3, "r")
    ground(cv, 42, "slab")
    a = person(cv, 54, 46, POLICE, arm="give", face=-1)
    hx, hy = a["hand"]
    cv.line(hx, hy, hx - 3, hy - 3, "B")
    cv.put(hx - 4, hy - 4, "S")
    cv.rect(57, 40, 4, 3, "t")
    cv.hl(57, 60, 40, "m")


@art("illus.fa.any.snow_day")
def fa_snow_day(cv, r):
    # snow: an empty white street, one red umbrella
    sky(cv, "snow", 14)
    shopfront(cv, 0, 6, 22, 32, r, "h", "b")
    shopfront(cv, 22, 8, 20, 30, r, "P", "w")
    shopfront(cv, 42, 5, 22, 33, r, "h", "b", banner="r")
    for x0, x1, y in ((0, 21, 13), (22, 41, 15), (42, 63, 12)):
        cv.hl(x0, x1, y, "W")
        cv.hl(x0 + 1, x1 - 1, y - 1, "W")
    cv.rect(0, 38, W, 10, "h")
    cv.hl(0, W - 1, 38, "W")
    for x in range(8, 40, 5):
        cv.put(x, 43 + (x // 5) % 2, "m")
    lantern(cv, 48, 18, "r")
    person(cv, 30, 45, Look(coat="t", coat2="E", legs="f", head="bun"), legs="walk",
           arm="up", face=1)
    umbrella(cv, 31, 22, "R", 15)
    snow(cv, r, 70)


@art("illus.fa.any.stranger_deal")
def fa_stranger_deal(cv, r):
    # dusk at the side door: a stranger opens his coat on a wrapped bundle
    sky(cv, "dusk", 10)
    lay = layer()
    wall_plaster(lay, 0, 6, W, 36, "h", "P", r)
    tile_roof(lay, 0, W - 1, 5, 2)
    lay.rect(8, 14, 16, 28, "x")
    plank_door(lay, 10, 16, 12, 26, "b", "w")
    lay.rect(10, 16, 6, 26, "K")
    ground(lay, 42, "slab")
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    lantern(cv, 28, 12, "r")
    cv.glow(28, 17, 10, 8, 1.0)
    person(cv, 15, 44, RUHUA, arm="chest", face=1)
    a = person(cv, 42, 46, STRANGER.but(coat="f", coat2="q"), arm="give", arm2="fwd", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 3, hy - 2, 5, 4, "B")
    cv.hl(hx - 3, hx + 1, hy - 2, "P")
    cv.put(hx - 2, hy - 1, "y")


@art("illus.fa.any.street_fine")
def fa_street_fine(cv, r):
    # an officer points his notebook at the doorstep; she stands there with the broom
    sky(cv, "day", 6)
    pawnshop_front(cv, r, 0, 40, 2, 40, (6, 28))
    wall_plaster(cv, 41, 2, 23, 38, "h", "P", r)
    lattice(cv, 46, 10, 12, 10, "w", "P")
    ground(cv, 40, "slab")
    cv.rect(4, 40, 28, 2, "t")
    for x, y in ((26, 41), (28, 42), (31, 41), (24, 43)):
        cv.pts([(x, y), (x + 1, y)], "B")
        cv.put(x, y + 1, "g")
    a = person(cv, 16, 44, RUHUA, arm="hold", face=1)
    hx, hy = a["hand"]
    cv.line(hx, hy - 6, hx + 2, hy + 7, "B")
    cv.rect(hx, hy + 6, 4, 3, "g")
    b = person(cv, 46, 46, POLICE, arm="give", face=-1)
    hx, hy = b["hand"]
    cv.rect(hx - 2, hy - 2, 3, 4, "p")
    cv.vl(hx - 2, hy - 2, hy + 1, "P")


@art("illus.fa.any.theft")
def fa_theft(cv, r):
    # night: an empty gap on the shelf, a figure bolting out the door with a bundle
    lay = layer()
    shelves(lay, r, 0, 0, 40, 34)
    lay.rect(16, 7, 10, 4, "x")
    lay.frame(16, 7, 10, 4, "B")
    lay.rect(40, 0, 24, 34, "w")
    ground(lay, 34, "floor")
    at_night(cv, lay)
    cv.rect(44, 4, 16, 30, "n")
    cv.rect(44, 26, 16, 8, "i")
    moon(cv, 54, 10, 2)
    cv.poly([(44, 34), (60, 34), (54, 48), (26, 48)], "E")
    a = person(cv, 48, 41, Look(coat="Q", coat2="K", legs="K", hair="K", skin="E",
                                 hat="cap", hatc="K", shoes="K"),
               legs="run", arm="hold", arm2="swing", face=1, outline="q")
    hx, hy = a["hand"]
    cv.rect(hx - 2, hy - 4, 5, 5, "o")
    cv.hl(hx - 2, hx + 2, hy - 4, "B")


@art("illus.lf.1938.qingming_prep")
def lf_qingming_prep(cv, r):
    # getting ready for Qingming: paper ingots, green rice balls, willow sprigs
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    lattice(cv, 40, 3, 18, 16, "w", "h", 6)
    for i in range(5):
        cv.line(44 + i * 3, 4, 43 + i * 3, 9 + (i * 3) % 7, "l")
    ground(cv, 30, "floor")
    a = person(cv, 12, 46, RUHUA, legs="sit", arm="fwd", face=1)
    stool(cv, 4, 41)
    table(cv, 18, 31, 42, 17, "w", "b")
    # paper ingots, gold and silver
    for i, (x, y, c) in enumerate(((22, 28, "Y"), (27, 28, "m"), (24, 26, "Y"), (31, 28, "Y"),
                                    (29, 26, "h"))):
        cv.hl(x, x + 4, y + 1, DARK.get(c, c))
        cv.hl(x, x + 4, y, c)
        cv.pts([(x, y - 1), (x + 4, y - 1), (x + 2, y - 1)], c)
    # dish of green qingtuan
    cv.ellipse(42, 30.5, 6, 1.5, "h")
    for x in (38, 41, 44, 40, 43):
        cv.ellipse(x + 0.5, 28.5 if x in (40, 43) else 29.5, 1.6, 1.4, "G")
        cv.put(x, 28 if x in (40, 43) else 29, "l")
    # willow sprigs in a jar, incense bundle
    cv.rect(52, 25, 4, 6, "j")
    cv.hl(52, 55, 25, "J")
    for i in range(4):
        cv.line(53 + i // 2, 25, 50 + i * 3, 15 + i, "l")
    cv.rect(35, 27, 1, 4, "R")
    cv.rect(36, 27, 1, 4, "d")
    cv.put(35, 26, "B")


@art("illus.lf.1938.spring_chill")
def lf_spring_chill(cv, r):
    # cold spring night: wrapped in a quilt by the charcoal brazier, coughing
    cv.rect(0, 0, W, 32, "b")
    wall_plaster(cv, 0, 0, W, 32, "b", "w", r)
    lattice(cv, 6, 5, 14, 12, "w", "n", 4)
    rain(cv, r, 10, "m", 1, 2, (7, 6, 19, 16))
    ground(cv, 32, "floor")
    # brazier
    cv.ellipse(40, 39, 8, 2.5, "w")
    cv.rect(33, 39, 15, 4, "w")
    cv.vl(34, 43, 45, "x")
    cv.vl(46, 43, 45, "x")
    cv.ellipse(40, 38.5, 6, 1.5, "q")
    for x in range(36, 45, 2):
        cv.put(x, 38, "R")
    cv.put(39, 37, "e")
    cv.put(41, 38, "y")
    # figure huddled under a quilt on a stool
    stool(cv, 18, 40)
    cv.poly([(14, 24), (25, 24), (28, 40), (12, 40)], "I")
    cv.poly([(15, 24), (24, 24), (25, 28), (14, 28)], "m")
    cv.hl(14, 26, 24, "m")
    for x, y in ((16, 31), (21, 34), (25, 36), (18, 38), (23, 29)):
        cv.put(x, y, "i")
    cv.ellipse(19.5, 21, 3.2, 3, "Q")
    cv.rect(20, 20, 3, 4, "N")
    cv.put(23, 22, "N")
    for x0, y0 in ((26, 17), (28, 19), (27, 14)):
        cv.hl(x0, x0 + 1, y0, "h")
    cv.remap(DARK)
    cv.glow(40, 37, 10, 7, 1.0)


@art("illus.lf.1938.spring_roof")
def lf_spring_roof(cv, r):
    # rain gets through the old tiles: drips down onto the shelf, a basin set under them
    cv.rect(0, 0, W, 10, "f")
    for x in range(0, W, 3):
        cv.vl(x, 0, 9, "q")
    cv.rect(26, 0, 6, 10, "m")
    rain(cv, r, 8, "h", 0, 3, (26, 0, 32, 10))
    cv.rect(0, 10, W, 3, "w")
    cv.hl(0, W - 1, 10, "b")
    for x in (4, 22, 40, 58):
        cv.rect(x, 10, 3, 3, "x")
    wall_plaster(cv, 0, 13, W, 23, "P", "B", r)
    cv.dither(20, 13, 16, 8, "P", "B", 0.35, only=("P",))
    shelves(cv, r, 38, 14, 24, 22)
    ground(cv, 36, "floor")
    for y in (15, 20, 25, 30):
        cv.put(29, y, "I")
        cv.put(29, y + 1, "m")
    cv.ellipse(29, 41, 6, 2, "B")
    cv.rect(23, 39, 13, 3, "b")
    cv.hl(23, 35, 39, "B")
    cv.ellipse(29, 39.5, 5, 1, "i")
    cv.put(29, 38, "m")
    cv.pts([(27, 37), (31, 37)], "m")
    person(cv, 12, 46, RUHUA, arm="low", face=1)


@art("illus.lf.1939.fuel_stock")
def lf_fuel_stock(cv, r):
    # laying in firewood: a stack of split logs against the back-yard wall
    sky(cv, "grey", 12)
    cv.rect(0, 8, W, 30, "h")
    wall_plaster(cv, 0, 10, W, 28, "h", "P", r)
    cv.hl(0, W - 1, 8, "f")
    cv.hl(0, W - 1, 9, "E")
    ground(cv, 38, "brick")
    cv.rect(2, 22, 36, 18, "w")
    for row in range(5):
        y = 23 + row * 3
        for col in range(9):
            x = 3 + col * 4 + (row % 2) * 2
            if x > 35:
                continue
            cv.ellipse(x + 1.5, y + 1.5, 1.6, 1.4, "B")
            cv.put(x + 1, y + 1, "P")
    cv.rect(2, 20, 36, 2, "o")
    cv.hl(2, 37, 20, "t")
    a = person(cv, 50, 46, RUHUA.but(coat="i"), legs="walk", arm="hold", arm2="hold", face=-1)
    hx, hy = a["hand"]
    firewood(cv, hx - 6, hy - 4, 8, 5)


@art("illus.lf.1939.new_year_goods")
def lf_new_year_goods(cv, r):
    # year-end market: cured meat and fish hang over the stall, red lanterns overhead
    sky(cv, "grey", 8)
    cv.rect(0, 6, W, 34, "w")
    cv.poly([(0, 6), (63, 6), (60, 11), (3, 11)], "r")
    for x in range(3, 61, 6):
        cv.vl(x, 7, 10, "d")
    cv.hl(0, 63, 11, "x")
    cv.rect(2, 12, 60, 18, "x")
    cv.hl(2, 61, 13, "B")
    for i, x in enumerate(range(6, 58, 6)):
        if i % 3 == 2:
            cv.vl(x + 1, 13, 15, "B")
            cv.poly([(x, 16), (x + 3, 16), (x + 2, 25), (x + 1, 25)], "m")
            cv.pts([(x, 24), (x + 3, 24), (x + 1, 26), (x + 2, 26)], "s")
        else:
            cv.vl(x + 1, 13, 15, "B")
            cv.rect(x, 16, 3, 7, "d" if i % 2 else "b")
            cv.vl(x, 16, 22, "R" if i % 2 else "B")
            cv.hl(x, x + 2, 16, "h")
    lantern(cv, 14, 1, "r")
    lantern(cv, 50, 1, "r")
    cv.rect(2, 30, 60, 4, "B")
    cv.hl(2, 61, 30, "P")
    basket(cv, 8, 27, 9, rice=False)
    cv.rect(9, 24, 7, 3, "r")
    ground(cv, 38, "slab")
    cv.rect(2, 34, 60, 4, "b")
    a = person(cv, 40, 47, RUHUA, arm="give", face=1)
    hx, hy = a["hand"]
    cv.ellipse(hx - 2, hy + 3, 3, 2, "B")
    cv.hl(hx - 5, hx + 1, hy + 1, "P")
    cv.vl(hx, hy, hy + 1, "B")
    small_person(cv, 56, 46, OLDWOMAN, "stand", face=-1)


@art("illus.lf.1939.pawn_coat")
def lf_pawn_coat(cv, r):
    # she lifts her own padded coat up to another shop's high counter
    lay = layer()
    shelves(lay, r, 0, 0, W, 22)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    person(cv, 34, 30, CLERK.but(hat=None, coat="t"), arm="fwd", face=-1)
    counter(cv, 22)
    cv.rect(0, 22, 8, 26, "h")
    cv.rect(0, 22, 8, 26, "m")
    snow(cv, r, 12, (0, 22, 8, 48))
    a = person(cv, 22, 48, RUHUA.but(coat="h", coat2="P"), arm="upfwd", arm2="up", face=1)
    hx, hy = a["hand"]
    cv.rect(hx - 4, hy - 6, 12, 7, "I")
    cv.hl(hx - 4, hx + 7, hy - 6, "m")
    for y in range(hy - 5, hy):
        cv.put(hx + 1, y, "i")
    cv.pts([(hx - 2, hy - 3), (hx + 4, hy - 3), (hx + 1, hy - 4)], "Y")


@art("illus.lf.1939.year_tab")
def lf_year_tab(cv, r):
    # year-end accounts: the abacus, the ledger, coins counted out under a red lantern
    cv.rect(0, 0, W, 28, "w")
    for x in range(0, W, 5):
        cv.vl(x, 0, 27, "x")
    lantern(cv, 52, 2, "r")
    cv.rect(4, 4, 10, 18, "r")
    cv.frame(4, 4, 10, 18, "d")
    cv.rect(8, 8, 2, 2, "Y")
    cv.rect(8, 15, 2, 2, "Y")
    table(cv, 0, 28, W, 20, "b", "B", legs=False)
    cv.rect(0, 32, W, 16, "b")
    cv.hl(0, W - 1, 31, "w")
    # abacus
    cv.rect(18, 22, 26, 11, "x")
    cv.rect(19, 23, 24, 9, "w")
    cv.hl(19, 42, 26, "x")
    for i, x in enumerate(range(20, 42, 3)):
        cv.vl(x + 1, 23, 31, "o")
        cv.rect(x, 24 if i % 2 else 23, 3, 1, "B")
        for k in range(3 if i % 3 else 2):
            cv.rect(x, 28 + k if i % 2 else 27 + k, 3, 1, "B")
        cv.put(x, 28 if i % 2 else 27, "P")
    paper(cv, 46, 26, 12, 6, "p", "b", None, r, 3)
    coin_row(cv, 6, 31, 4, "Y")
    silver(cv, 8, 30, 3)
    cv.line(48, 23, 56, 29, "b")
    cv.glow(52, 10, 12, 10, 0.6)


@art("illus.lf.1940.census_chit")
def lf_census_chit(cv, r):
    # the household count: a clerk at a street table writes up the family
    sky(cv, "grey", 8)
    pawnshop_front(cv, r, 0, 36, 4, 40, (6, 22))
    wall_plaster(cv, 37, 4, 27, 36, "h", "P", r)
    cv.rect(48, 12, 6, 9, "B")
    cv.frame(48, 12, 6, 9, "b")
    ground(cv, 40, "slab")
    person(cv, 44, 41, CLERK, legs="sit", arm="fwd", face=-1)
    table(cv, 30, 34, 14, 12, "B")
    cv.rect(32, 31, 9, 3, "p")
    cv.vl(36, 31, 33, "P")
    cv.line(39, 28, 41, 31, "k")
    person(cv, 56, 46, POLICE, arm="back", face=-1)
    person(cv, 14, 46, OLDWOMAN, arm="down", face=1)
    a = person(cv, 23, 46, RUHUA, arm="give", face=1)
    hx, hy = a["hand"]
    cv.rect(hx, hy - 2, 3, 4, "S")


@art("illus.lf.1940.door_paper")
def lf_door_paper(cv, r):
    # new rule: she pastes the required sheet on the shop door herself
    sky(cv, "day", 6)
    wall_plaster(cv, 0, 4, W, 38, "h", "P", r)
    tile_roof(cv, 0, W - 1, 1, 3)
    cv.rect(24, 8, 32, 34, "x")
    plank_door(cv, 26, 10, 28, 32, "b", "w", ring=False)
    paper(cv, 32, 13, 11, 13, "h", "b", "r", r)
    cv.pts([(31, 13), (31, 18)], "P")
    a = person(cv, 22, 46, RUHUA, arm="upfwd", arm2="down", face=1)
    hx, hy = a["hand"]
    cv.line(hx, hy, hx + 3, hy - 3, "B")
    cv.rect(hx + 3, hy - 5, 3, 2, "P")
    ground(cv, 42, "slab")
    cv.rect(10, 41, 6, 4, "j")
    cv.hl(10, 15, 41, "J")
    cv.hl(11, 14, 42, "S")


@art("illus.lf.1940.school_rename")
def lf_school_rename(cv, r):
    # the school gate gets a new signboard; the old one leans against the wall
    sky(cv, "day", 10)
    wall_plaster(cv, 0, 8, W, 32, "h", "P", r)
    tile_roof(cv, 0, W - 1, 6, 3)
    cv.rect(18, 18, 22, 22, "x")
    plank_door(cv, 20, 20, 9, 20, "w", "x", ring=False)
    plank_door(cv, 30, 20, 9, 20, "w", "x", ring=False)
    cv.rect(20, 11, 18, 5, "j")
    cv.frame(20, 11, 18, 5, "Y")
    cv.rect(45, 27, 4, 13, "b")
    cv.frame(45, 27, 4, 13, "g")
    cv.line(46, 30, 47, 37, "w")
    ground(cv, 40, "slab")
    # ladder and workman
    cv.line(10, 41, 16, 10, "B")
    cv.line(14, 41, 20, 12, "B")
    for k in range(6):
        cv.line(11 + k, 37 - k * 5, 15 + k, 37 - k * 5, "b")
    a = person(cv, 15, 28, WORKER, arm="upfwd", face=1)
    small_person(cv, 56, 46, RUHUA.but(coat="I", head="short"), "stand", face=-1)
    cv.rect(53, 39, 3, 3, "B")


@art("illus.lf.any.coal_out")
def lf_coal_out(cv, r):
    # the stove has gone cold; the coal basket is empty
    wall_plaster(cv, 0, 0, W, 30, "s", "t", r)
    cv.rect(0, 0, W, 3, "w")
    ground(cv, 30, "brick")
    # plastered brick stove: cold wok on top, arched fire mouth, chimney
    cv.rect(26, 18, 34, 22, "h")
    cv.hl(26, 59, 18, "W")
    cv.rect(26, 21, 34, 2, "i")
    cv.vl(59, 18, 39, "P")
    cv.rect(26, 34, 34, 6, "s")
    cv.hl(26, 59, 34, "m")
    cv.ellipse(43, 18.5, 9, 2, "E")
    cv.ellipse(43, 18.5, 7, 1.2, "f")
    cv.rect(30, 27, 9, 7, "q")
    cv.hl(31, 37, 26, "q")
    cv.hl(32, 36, 25, "q")
    cv.hl(31, 37, 33, "t")
    cv.pts([(33, 32), (35, 32), (34, 31)], "s")
    cv.rect(52, 3, 5, 15, "s")
    cv.vl(56, 3, 17, "t")
    cv.hl(52, 56, 3, "m")
    # empty basket on its side
    cv.ellipse(14, 40, 7, 4, "B")
    cv.ellipse(12, 40, 5, 3, "w")
    for x in range(9, 20, 2):
        cv.vl(x, 37, 43, "b")
    cv.ellipse(12, 40, 5, 3, "w")
    cv.pts([(20, 43), (22, 44), (18, 44)], "Q")
    a = person(cv, 26, 46, RUHUA, legs="squat", arm=(4, 1), face=1)
    hx, hy = a["head"]
    cv.pts([(hx + 4, hy), (hx + 5, hy - 1), (hx + 6, hy)], "h")


@art("illus.lf.any.debt_due")
def lf_debt_due(cv, r):
    # the lender sits down at the family table and holds up the note that has come due
    wall_plaster(cv, 0, 0, W, 32, "P", "B", r)
    cv.rect(24, 3, 22, 16, "p")
    cv.frame(23, 2, 24, 18, "w")
    ink_peaks(cv, 25, 5, 20, 12)
    cv.rect(0, 26, W, 6, "b")
    cv.hl(0, W - 1, 26, "w")
    ground(cv, 32, "floor")
    stool(cv, 8, 40)
    a = person(cv, 15, 45, FEDORA.but(coat="B", coat2="b"), legs="sit", arm=(1, -6),
               arm2="fwd", face=1)
    hx, hy = a["hand"]
    paper(cv, hx - 2, hy - 9, 6, 9, "S", "b", "r", r, 1)
    table(cv, 22, 35, 26, 13, "x", "w")
    cv.rect(25, 31, 12, 4, "x")
    cv.rect(26, 32, 10, 2, "w")
    for x in range(27, 36, 2):
        cv.put(x, 32, "B")
    bowl(cv, 40, 33, "h", "B")
    person(cv, 56, 47, RUHUA, arm="chest", face=-1)


@art("illus.lf.any.funeral")
def lf_funeral(cv, r):
    # a neighbour's funeral: white banners and lanterns at the door, mourners in hemp
    sky(cv, "grey", 8)
    shopfront(cv, 0, 4, 26, 36, r, "h", "b")
    cv.rect(26, 4, 38, 36, "w")
    cv.rect(30, 12, 30, 28, "x")
    cv.rect(26, 4, 38, 6, "f")
    for x in (29, 57):
        cv.rect(x, 12, 3, 26, "h")
        cv.vl(x + 2, 12, 37, "P")
        for y in range(15, 35, 3):
            cv.put(x + 1, y, "f")
    cv.rect(32, 10, 26, 3, "h")
    for x in range(33, 57, 4):
        cv.put(x, 13, "h")
        cv.put(x + 1, 14, "h")
    lantern(cv, 37, 16, "h", lit=False)
    lantern(cv, 51, 16, "h", lit=False)
    cv.rect(40, 30, 8, 5, "b")
    cv.hl(40, 47, 30, "B")
    candle(cv, 41, 29, 2)
    candle(cv, 46, 29, 2)
    ground(cv, 40, "slab")
    mourn = Look(coat="P", coat2="B", legs="P", legs2="B", shoes="w")
    for fx, fy, lk in ((10, 46, mourn), (20, 47, mourn.but(head="bun"))):
        a = person(cv, fx, fy, lk, legs="walk", arm="down", face=1)
        hx, hy = a["head"]
        cv.hl(hx - 2, hx + 2, hy - 1, "W")
    small_person(cv, 60, 46, RUHUA, "stand", face=-1)


@art("illus.lf.any.lamp_oil")
def lf_lamp_oil(cv, r):
    # the lamp has nearly burned dry; she squints at the ledger beside its small flame
    cv.rect(0, 0, W, 32, "q")
    ground(cv, 32, "floor")
    table(cv, 8, 32, 50, 16, "w", "b")
    a = person(cv, 44, 41, RUHUA, legs="sit", arm="fwd", face=-1, lean=-1)
    table(cv, 8, 32, 50, 16, "w", "b")
    paper(cv, 28, 29, 12, 4, "p", "b", None, r, 3)
    oil_lamp(cv, 20, 31)
    cv.put(20, 26, "e")
    cv.put(20, 25, "q")
    cv.rect(11, 28, 3, 4, "m")
    cv.put(12, 27, "m")
    cv.hl(11, 13, 28, "s")
    cv.remap(DARK)
    cv.glow(20, 26, 13, 9, 0.8)


@art("illus.lf.any.mother_cough")
def lf_mother_cough(cv, r):
    # mother sits up in bed coughing; she brings the bowl of medicine
    cv.rect(0, 0, W, 32, "B")
    wall_plaster(cv, 0, 0, W, 32, "B", "b", r)
    lattice(cv, 46, 4, 12, 12, "w", "n", 4)
    ground(cv, 32, "floor")
    cv.vl(2, 4, 42, "w")
    cv.hl(2, 34, 4, "x")
    cv.poly([(3, 5), (10, 5), (6, 20), (3, 22)], "h")
    person(cv, 16, 37, OLDWOMAN.but(coat="h", coat2="P"), legs="sit", arm="head", face=1)
    bed(cv, 2, 36, 32, "j")
    cv.poly([(14, 31), (33, 31), (33, 36), (12, 36)], "j")
    cv.hl(14, 33, 31, "J")
    for x0, y0 in ((22, 17), (24, 15), (23, 20)):
        cv.hl(x0, x0 + 1, y0, "h")
    a = person(cv, 44, 46, RUHUA, arm="give", arm2="give", face=-1)
    hx, hy = a["hand"]
    bowl(cv, hx - 4, hy - 1, "h", "x")
    steam(cv, hx - 3, hy - 3, 3, "h")
    cv.remap(DARK, box=(0, 0, W, 30))


@art("illus.lf.any.new_year")
def lf_new_year(cv, r):
    # New Year's eve: red couplets and lanterns, firecrackers popping at the door
    sky(cv, "night", 8)
    pawnshop_front(cv, r, 0, 63, 3, 42, (20, 42))
    for x in (14, 45):
        cv.rect(x, 11, 4, 28, "r")
        for y in range(14, 37, 5):
            cv.put(x + 1, y, "Y")
            cv.put(x + 2, y + 1, "g")
    cv.rect(22, 11, 20, 4, "r")
    cv.rect(21, 15, 22, 27, "c")
    cv.rect(21, 34, 22, 8, "N")
    table(cv, 26, 30, 12, 12, "B")
    cv.ellipse(32, 29, 4, 1.5, "h")
    cv.ellipse(32, 28.5, 2.5, 1, "R")
    lantern(cv, 8, 9, "r")
    lantern(cv, 56, 9, "r")
    ground(cv, 42, "slab")
    # string of firecrackers hanging from the eave, bursting at the bottom
    cv.vl(4, 10, 12, "k")
    for y in range(12, 33, 2):
        cv.put(4, y, "r")
        cv.put(5, y + 1, "R")
    for x, y in ((2, 35), (6, 36), (4, 38), (8, 34), (1, 38), (7, 39)):
        cv.put(x, y, "y")
    cv.pts([(3, 36), (5, 37)], "W")
    cv.glow(32, 30, 16, 12, 0.6)
    cv.glow(8, 13, 6, 5, 0.8)
    cv.glow(56, 13, 6, 5, 0.8)


@art("illus.lf.any.rent")
def lf_rent(cv, r):
    # the landlord at the gate with his pipe, palm out; she counts coins into it
    sky(cv, "day", 8)
    wall_plaster(cv, 0, 6, W, 34, "h", "P", r)
    tile_roof(cv, 0, W - 1, 4, 3)
    cv.rect(34, 12, 24, 28, "x")
    plank_door(cv, 36, 14, 10, 26, "b", "w")
    cv.rect(47, 14, 9, 26, "K")
    ground(cv, 40, "slab")
    a = person(cv, 16, 46, GENTRY.but(coat="E", coat2="f", hair="m"), arm="give", arm2="chest",
               face=1)
    hx, hy = a["hand2"]
    cv.line(hx, hy, hx + 5, hy - 4, "w")
    cv.rect(hx + 5, hy - 5, 2, 2, "x")
    ph = a["hand"]
    b = person(cv, 34, 46, RUHUA, arm="give", face=-1)
    cv.pts([(ph[0] + 1, ph[1] - 1), (ph[0] + 2, ph[1] - 2)], "Y")
    cv.put(ph[0] + 3, ph[1] - 4, "e")


@art("illus.lf.any.repair_house")
def lf_repair_house(cv, r):
    # the carpenter up a ladder relays the tiles; new tiles stacked below
    sky(cv, "day", 20)
    cv.rect(0, 16, W, 26, "h")
    wall_plaster(cv, 0, 16, W, 26, "h", "P", r)
    tile_roof(cv, 0, W - 1, 10, 6)
    cv.rect(24, 10, 9, 3, "Q")
    cv.rect(36, 24, 14, 18, "x")
    plank_door(cv, 38, 26, 10, 16, "b", "w")
    ground(cv, 42, "slab")
    cv.line(14, 43, 22, 11, "B")
    cv.line(18, 43, 26, 12, "B")
    for k in range(7):
        cv.line(15 + k, 39 - k * 4, 19 + k, 39 - k * 4, "b")
    a = person(cv, 22, 34, WORKER.but(coat="B", coat2="b"), arm="upfwd", face=1)
    hx, hy = a["hand"]
    cv.rect(hx, hy - 1, 3, 2, "f")
    for i in range(4):
        cv.rect(52, 43 - i * 2, 8, 2, "E")
        cv.hl(52, 59, 43 - i * 2, "t")
    person(cv, 6, 47, RUHUA, arm="hold", face=1)


@art("illus.lf.any.rice_low")
def lf_rice_low(cv, r):
    # the big glazed rice crock, scraped down to its last grains
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    ground(cv, 30, "brick")
    cv.ellipse(30, 35, 20, 12, "b")
    cv.ellipse(23, 33, 8, 8, "B")
    for y in range(24, 48):
        for x in range(10, 51):
            if cv.get(x, y) == "b" and x > 41:
                cv.put(x, y, "w")
    cv.ellipse(30, 23, 18, 5, "B")
    cv.ellipse(30, 23, 17, 4.2, "b")
    cv.ellipse(30, 23.5, 16, 3.6, "Q")
    cv.ellipse(30, 25, 9, 1.4, "q")
    cv.hl(27, 33, 26, "P")
    cv.hl(28, 31, 25, "h")
    cv.put(29, 24, "W")
    cv.hl(14, 46, 19, "P")
    cv.line(46, 4, 36, 24, "B")
    cv.line(47, 4, 37, 24, "P")
    cv.ellipse(35, 25, 2.5, 1.2, "B")
    person(cv, 56, 48, RUHUA, arm=None, face=-1)


@art("illus.lf.any.school_fee")
def lf_school_fee(cv, r):
    # the schoolmaster at his desk holds out his hand for the term's fee
    wall_plaster(cv, 0, 0, W, 32, "P", "B", r)
    cv.rect(8, 4, 26, 15, "f")
    cv.frame(8, 4, 26, 15, "b")
    cv.line(12, 9, 18, 9, "m")
    cv.line(12, 12, 24, 12, "m")
    cv.line(20, 15, 28, 15, "s")
    lattice(cv, 46, 4, 12, 12, "w", "h", 4)
    ground(cv, 32, "floor")
    a = person(cv, 44, 38, DOCTOR.but(coat="i", coat2="n", hair="m"), legs="sit", arm="give",
               face=-1)
    hx, hy = a["head"]
    cv.pts([(hx - 1, hy), (hx - 2, hy)], "m")
    table(cv, 26, 33, 26, 15, "w", "b")
    paper(cv, 34, 30, 9, 4, "p", "b", None, r, 2)
    person(cv, 10, 46, RUHUA, arm="down", face=1)
    small_person(cv, 19, 46, Look(coat="I", legs="n", hair="Q"), "stand", face=1)
    cv.rect(15, 38, 3, 4, "B")
    cv.hl(15, 17, 38, "P")


@art("illus.lf.any.see_doctor")
def lf_see_doctor(cv, r):
    # the old doctor feels the pulse at the bedside, his medicine box open on the floor
    cv.rect(0, 0, W, 32, "P")
    wall_plaster(cv, 0, 0, W, 32, "P", "B", r)
    lattice(cv, 4, 4, 12, 12, "w", "h", 4)
    ground(cv, 32, "floor")
    cv.vl(30, 6, 42, "w")
    cv.vl(62, 6, 42, "w")
    cv.hl(29, 63, 6, "x")
    cv.poly([(31, 7), (37, 7), (34, 20), (31, 22)], "h")
    cv.rect(33, 31, 29, 6, "b")
    cv.hl(33, 61, 31, "B")
    cv.rect(53, 26, 8, 5, "h")
    cv.ellipse(56, 26.5, 3, 2.4, "Q")
    cv.ellipse(54, 27, 2, 1.8, "N")
    cv.poly([(36, 27), (52, 26), (52, 31), (34, 31)], "I")
    cv.hl(36, 52, 26, "m")
    cv.rect(34, 28, 3, 2, "N")
    a = person(cv, 22, 46, DOCTOR.but(coat="t", coat2="E", hair="m"), legs="sit", arm=(5, 0),
               face=1)
    stool(cv, 15, 41)
    hx, hy = a["head"]
    cv.pts([(hx + 1, hy + 3), (hx + 2, hy + 3), (hx + 1, hy + 4)], "m")
    cv.rect(4, 39, 9, 7, "r")
    cv.rect(4, 39, 9, 2, "d")
    cv.hl(4, 12, 39, "R")
    cv.rect(7, 42, 3, 2, "Y")
    cv.pts([(5, 37), (7, 36), (9, 37)], "l")
    person(cv, 47, 45, RUHUA, arm="chest", face=-1)


@art("illus.lf.any.wedding_gift")
def lf_wedding_gift(cv, r):
    # a red wedding invitation brought to the door; the bride's house across is hung with red
    sky(cv, "day", 8)
    pawnshop_front(cv, r, 0, 30, 4, 40, (6, 22))
    cv.rect(31, 4, 33, 36, "h")
    wall_plaster(cv, 31, 6, 33, 34, "h", "P", r)
    tile_roof(cv, 31, 63, 4, 2)
    cv.rect(40, 16, 18, 24, "x")
    cv.hl(38, 59, 14, "r")
    cv.ellipse(48.5, 15.5, 3, 2.2, "R")
    cv.put(48, 15, "y")
    for x in (40, 44, 53, 57):
        cv.put(x, 15 + (1 if x in (44, 53) else 0), "r")
    lantern(cv, 37, 18, "r")
    lantern(cv, 61, 18, "r")
    ground(cv, 40, "slab")
    person(cv, 13, 43, RUHUA, arm="give", face=1)
    a = person(cv, 30, 46, WOMAN.but(coat="R", coat2="r", legs="i"), arm="give", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 6, hy - 4, 6, 8, "r")
    cv.frame(hx - 6, hy - 4, 6, 8, "Y")
    cv.rect(hx - 4, hy - 2, 2, 3, "e")


@art("illus.kp.blank_ticket")
def kp_blank_ticket(cv, r):
    # a blank pawn ticket on the counter: printed border, the shop's seal, nothing filled in
    lay = layer()
    shelves(lay, r, 0, 0, W, 16)
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    cv.rect(0, 16, W, 32, "b")
    cv.hl(0, W - 1, 16, "B")
    for y in range(20, 48, 5):
        cv.hl(0, W - 1, y, "w")
    # the ticket
    cv.rect(17, 19, 26, 27, "p")
    cv.hl(17, 42, 45, "P")
    cv.vl(42, 19, 45, "P")
    cv.frame(19, 21, 22, 22, "r")
    cv.frame(20, 22, 20, 20, "R")
    for x in range(23, 39, 4):
        for y in range(25, 40, 2):
            cv.put(x, y, "P")
    cv.rect(34, 23, 5, 5, "r")
    cv.frame(34, 23, 5, 5, "d")
    cv.pts([(35, 25), (36, 24), (37, 26), (36, 26)], "R")
    cv.vl(22, 24, 40, "c")
    # brush and inkstone
    cv.rect(48, 34, 10, 7, "f")
    cv.rect(49, 35, 8, 4, "Q")
    cv.hl(48, 57, 34, "E")
    cv.line(46, 22, 53, 31, "B")
    cv.pts([(53, 31), (54, 32)], "k")
    cv.rect(5, 30, 6, 6, "B")
    cv.rect(6, 36, 4, 2, "r")
    cv.hl(5, 10, 30, "P")


@art("illus.kp.brother_note")
def kp_brother_note(cv, r):
    # the brother at the door with his bundle, turning back; his rules left on the counter
    cv.rect(0, 0, W, 34, "w")
    for x in range(0, W, 5):
        cv.vl(x, 0, 33, "x")
    cv.rect(38, 4, 18, 30, "c")
    cv.rect(38, 26, 18, 8, "N")
    cv.frame(37, 3, 20, 31, "x")
    a = person(cv, 47, 34, RUHUA.but(coat="n", coat2="Q", head="short", legs="q"), arm="hold",
               arm2="back", face=-1)
    hx, hy = a["hand"]
    cv.rect(hx - 1, hy - 1, 4, 4, "B")
    cv.hl(hx - 1, hx + 2, hy - 1, "P")
    cv.rect(0, 34, W, 14, "b")
    cv.hl(0, W - 1, 34, "B")
    cv.hl(0, W - 1, 35, "w")
    paper(cv, 10, 30, 22, 12, "p", "b", None, r, 6)
    cv.pts([(10, 30), (31, 30)], "P")
    cv.rect(27, 38, 3, 3, "r")
    cv.rect(6, 36, 6, 4, "i")
    cv.hl(6, 11, 36, "I")
    cv.glow(47, 18, 12, 14, 0.4)


@art("illus.kp.gate_pass")
def kp_gate_pass(cv, r):
    # at the gate she holds out the pass; the sentry bends over its seal
    sky(cv, "day", 36)
    cv.rect(34, 2, 30, 34, "t")
    for y in range(2, 36, 3):
        cv.hl(34, 63, y, "E")
        for x in range(34 + (y // 3 % 2) * 3, 64, 6):
            cv.vl(x, y, y + 2, "E")
    cv.rect(44, 12, 14, 24, "Q")
    cv.ellipse(51, 13, 7, 4, "Q")
    for x in range(34, 64, 6):
        cv.rect(x, 0, 4, 2, "t")
    cv.rect(0, 36, W, 12, "o")
    cv.rect(0, 42, W, 6, "B")
    sawhorse(cv, 46, 34, 16)
    person(cv, 38, 46, SOLDIER, arm="give", face=-1, lean=1)
    a = person(cv, 18, 46, RUHUA, arm=(5, -2), face=1)
    hx, hy = a["hand"]
    cv.rect(hx, hy - 9, 7, 11, "p")
    cv.vl(hx + 6, hy - 9, hy + 1, "P")
    cv.rect(hx + 2, hy - 3, 3, 3, "r")
    cv.vl(hx + 1, hy - 8, hy - 5, "b")
    cv.vl(hx + 3, hy - 8, hy - 6, "b")


@art("illus.kp.gold_bar")
def kp_gold_bar(cv, r):
    # one small gold bar bedded in red cloth in its box
    cv.rect(0, 0, W, H, "x")
    cv.vgrad(0, 0, W, 30, ["K", "x"])
    cv.rect(0, 30, W, 18, "w")
    cv.hl(0, W - 1, 30, "b")
    # open box
    cv.poly([(12, 14), (52, 14), (54, 22), (10, 22)], "b")
    cv.poly([(12, 14), (52, 14), (51, 16), (13, 16)], "B")
    cv.rect(10, 22, 44, 16, "b")
    cv.frame(10, 22, 44, 16, "x")
    cv.rect(12, 24, 40, 12, "r")
    cv.dither(12, 24, 40, 12, "r", "d", 0.2)
    cv.hl(12, 51, 24, "R")
    # the bar
    cv.poly([(20, 28), (44, 28), (47, 32), (17, 32)], "Y")
    cv.rect(17, 32, 31, 3, "g")
    cv.hl(17, 47, 32, "Y")
    cv.hl(21, 43, 28, "y")
    cv.rect(26, 29, 4, 2, "e")
    cv.rect(34, 29, 4, 2, "e")
    cv.pts([(22, 29), (23, 29)], "W")
    cv.put(53, 23, "Y")
    cv.put(10, 23, "Y")
    cv.glow(32, 30, 22, 12, 0.7)


def _favor_scene(cv, r, who, backdrop):
    """A man who owes you one, fists cupped in a bow (shared by the three favour cards)."""
    if backdrop == "office":
        wall_plaster(cv, 0, 0, W, 36, "s", "t", r)
        cv.rect(0, 30, W, 6, "E")
        paper(cv, 6, 6, 10, 14, "p", "b", "r", r)
        paper(cv, 18, 8, 8, 11, "h", "b", "r", r)
        ground(cv, 36, "brick")
    elif backdrop == "study":
        wall_plaster(cv, 0, 0, W, 34, "P", "B", r)
        cv.rect(0, 28, W, 6, "b")
        cv.rect(4, 4, 14, 18, "p")
        cv.frame(3, 3, 16, 20, "w")
        ink_peaks(cv, 5, 7, 12, 11)
        ground(cv, 34, "floor")
        table(cv, 4, 34, 22, 14, "x", "w")
        cv.rect(8, 31, 4, 3, "r")
        cv.rect(14, 31, 8, 3, "p")
    else:
        sky(cv, "grey", 22)
        water(cv, r, 22, 34, "s", "m", "h", 10)
        boat(cv, 4, 31, 24, "b", "q")
        ground(cv, 34, "slab")
        cv.line(10, 46, 22, 30, "B")
        cv.rect(8, 42, 5, 5, "B")
    a = person(cv, 36, 46, who, arm="chest", arm2="chest", face=1, lean=1)
    hx, hy = a["hand"]
    cv.rect(hx - 1, hy - 1, 3, 3, who.skin)
    cv.put(hx, hy - 1, DARK.get(who.skin, who.skin))
    person(cv, 54, 46, RUHUA, arm="down", face=-1)


@art("illus.kp.hu_owes")
def kp_hu_owes(cv, r):
    # Hu Er, the headman's runner, cups his fists: he owes you one
    _favor_scene(cv, r, Look(coat="q", coat2="Q", legs="E", legs2="f", accent="m"), "office")


@art("illus.kp.ma_owes")
def kp_ma_owes(cv, r):
    # Headman Ma in his black hat and suit, by his desk and seal: he owes you one
    _favor_scene(cv, r, Look(coat="f", coat2="q", legs="q", hat="fedora", hatc="Q",
                             accent="r"), "study")


@art("illus.kp.zhao_favor")
def kp_zhao_favor(cv, r):
    # Zhao Laosan, the boatman in patched blue-grey, cups his fists: he owes you one
    _favor_scene(cv, r, Look(coat="s", coat2="t", legs="i", skin="P", hat="straw", hatc="P",
                             accent="B"), "river")


@art("illus.kp.leverage.li")
def kp_leverage_li(cv, r):
    # Li's secret manuscript pages half hidden under a book, by lamplight
    cv.rect(0, 0, W, 28, "x")
    lattice(cv, 44, 3, 14, 12, "x", "n", 4)
    cv.rect(0, 28, W, 20, "w")
    cv.hl(0, W - 1, 28, "b")
    oil_lamp(cv, 10, 30, big=True)
    for i, (x, y) in enumerate(((18, 25), (21, 27), (16, 29))):
        paper(cv, x, y, 18, 12, "p" if i != 1 else "h", "b", None, r, 5)
    cv.rect(30, 22, 18, 12, "i")
    cv.frame(30, 22, 18, 12, "n")
    cv.hl(31, 46, 22, "I")
    cv.rect(32, 33, 15, 1, "h")
    cv.vl(46, 23, 32, "h")
    cv.line(48, 34, 56, 40, "B")
    cv.pts([(56, 40), (57, 41)], "k")
    cv.glow(12, 26, 22, 14, 1.0)


@art("illus.kp.leverage.wu")
def kp_leverage_wu(cv, r):
    # Wu's rice-boat dates marked on a slip; his loaded boat slipping off at dusk
    sky(cv, "dusk", 22)
    for x0, w0, h0 in ((0, 16, 5), (14, 10, 7), (40, 14, 4), (52, 12, 6)):
        cv.rect(x0, 22 - h0, w0, h0, "f")
    water(cv, r, 22, 48, "n", "i", "I", 20)
    boat(cv, 4, 34, 28, "w", "q")
    for i in range(3):
        rice_sack(cv, 10 + i * 6, 25, 6, 4, "B", tie=False)
    cv.rect(40, 12, 20, 32, "p")
    cv.vl(59, 12, 43, "P")
    cv.hl(40, 59, 43, "P")
    for col, x in enumerate(range(42, 58, 3)):
        for y in range(15, 41, 4):
            cv.hl(x, x + 1, y, "o")
    for x, y in ((44, 22), (50, 30), (53, 18)):
        cv.frame(x - 1, y - 1, 4, 3, "r")
    hand(cv, 47, 40, "N", "I")


@art("illus.kp.leverage.xiaoding")
def kp_leverage_xiaoding(cv, r):
    # the Sun storeroom: neat rows of rice sacks with a gap where some went missing
    cv.rect(0, 0, W, 40, "w")
    for x in range(0, W, 4):
        cv.vl(x, 0, 39, "x")
    ground(cv, 40, "floor")
    for row, y in enumerate((32, 25, 18)):
        for i in range(6):
            x = 3 + i * 10
            if row == 1 and i in (2, 3):
                cv.frame(x, y, 10, 7, "B")
                continue
            if row == 2 and i == 3:
                continue
            rice_sack(cv, x, y, 10, 7, "P", tie=False)
    paper(cv, 42, 40, 16, 7, "p", "b", None, r, 4)
    cv.frame(46, 41, 5, 4, "r")
    lantern(cv, 6, 4, "r")
    cv.glow(6, 10, 18, 14, 1.0)
    cv.remap(DARK, box=(30, 0, W, 40))


@art("illus.kp.leverage.zhang")
def kp_leverage_zhang(cv, r):
    # medicine hidden in a market basket: the cloth lifted on bottles and paper packets
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    ground(cv, 30, "floor")
    cv.ellipse(32, 38, 22, 8, "B")
    cv.rect(10, 26, 44, 12, "B")
    for x in range(11, 54, 3):
        cv.vl(x, 27, 44, "b")
    for y in (30, 34, 38):
        cv.hl(10, 53, y, "o")
    cv.ellipse(32, 26, 22, 4, "b")
    cv.ellipse(32, 26, 20, 3, "w")
    for i, (x, h) in enumerate(((17, 8), (22, 10), (27, 7), (33, 9))):
        c = "g" if i % 2 == 0 else "b"
        cv.rect(x, 26 - h, 4, h, c)
        cv.rect(x + 1, 24 - h, 2, 2, "W" if i % 2 else "h")
        cv.vl(x, 26 - h, 25, "Y" if i % 2 == 0 else "B")
        cv.rect(x, 22 - h // 2, 4, 2, "S")
    cv.rect(38, 20, 8, 5, "S")
    cv.rect(40, 18, 7, 5, "h")
    cv.hl(38, 45, 22, "P")
    cv.poly([(44, 14), (56, 18), (52, 28), (42, 24)], "j")
    cv.line(44, 14, 56, 18, "J")
    for i in range(41):
        a = math.pi * i / 40
        cv.put(32 - math.cos(a) * 20, 24 - math.sin(a) * 17, "b")
        cv.put(32 - math.cos(a) * 20, 23 - math.sin(a) * 17, "B")


@art("illus.kp.liangmin")
def kp_liangmin(cv, r):
    # the "good citizen" card held up at the checkpoint: photo square, red seal
    sky(cv, "grey", 26)
    cv.rect(0, 20, W, 10, "s")
    for x in range(0, W, 7):
        cv.rect(x, 22, 6, 4, "t")
        cv.rect(x + 2, 18, 6, 4, "t")
    cv.rect(0, 26, W, 22, "o")
    cv.rect(0, 36, W, 12, "B")
    sawhorse(cv, 4, 28, 16)
    small_person(cv, 34, 33, SOLDIER, "stand", face=-1)
    cv.line(31, 24, 32, 18, "w")
    cv.remap(DARK, box=(0, 16, W, 40))
    # the card
    cv.rect(20, 20, 28, 20, "S")
    cv.frame(20, 20, 28, 20, "P")
    cv.rect(23, 23, 8, 10, "m")
    cv.ellipse(27, 26.5, 2, 2, "t")
    cv.rect(25, 29, 5, 4, "t")
    for y in (24, 27, 30):
        cv.hl(34, 44, y, "o")
    cv.ellipse(42, 35, 3, 3, "r")
    cv.ellipse(42, 35, 2, 2, "R")
    cv.put(42, 35, "r")
    cv.hl(21, 46, 20, "W")
    hand(cv, 17, 33, "N", "I")


@art("illus.kp.mystery_box")
def kp_mystery_box(cv, r):
    # under a lifted floorboard: the stranger's box, kept out of sight
    ground(cv, 0, "floor")
    cv.rect(0, 0, W, 48, "b")
    for y in range(0, 48, 6):
        cv.hl(0, W - 1, y, "w")
        for x in range((y // 6 % 2) * 11, W, 22):
            cv.vl(x, y, y + 5, "w")
    cv.rect(14, 16, 34, 18, "K")
    cv.poly([(14, 16), (48, 16), (52, 8), (18, 8)], "B")
    cv.hl(18, 51, 8, "P")
    cv.line(14, 16, 18, 8, "w")
    cv.rect(17, 20, 28, 12, "w")
    cv.rect(17, 20, 28, 3, "b")
    cv.frame(17, 20, 28, 12, "k")
    cv.vl(22, 20, 31, "P")
    cv.vl(40, 20, 31, "P")
    cv.rect(30, 23, 3, 4, "Y")
    cv.put(31, 25, "k")
    for x, y in ((18, 21), (43, 21), (18, 30), (43, 30)):
        cv.put(x, y, "Y")
    oil_lamp(cv, 56, 44)
    cv.remap(DARK)
    cv.glow(52, 36, 18, 14, 1.0)


@art("illus.kp.silver_keepsake")
def kp_silver_keepsake(cv, r):
    # the family's silver longevity lock on its chain, laid out on red cloth
    cv.rect(0, 0, W, H, "d")
    cv.ellipse(32, 25, 27, 19, "r")
    for y in range(2, 46, 4):
        for x in range((y // 4 % 2) * 4, W, 8):
            cv.put(x, y, "R" if cv.get(x, y) == "r" else "r")
    # chain looping up from the two horns
    for i in range(31):
        a = math.pi * i / 30
        x = 32 - math.cos(a) * 13
        y = 18 - math.sin(a) * 13
        cv.put(x, y, "h" if i % 2 else "s")
    # lock body: horned top edge, round belly
    for x in range(17, 48):
        t = (x - 32) / 15.0
        top = int(round(20 - 4 * t * t))
        bot = int(round(27 + 7 * math.sqrt(max(0.0, 1 - t * t))))
        for y in range(top, bot + 1):
            c = "m"
            if y <= top + 1 or x <= 19:
                c = "h"
            if y >= bot - 1 or x >= 45:
                c = "s"
            cv.put(x, y, c)
        cv.put(x, top - 1, "t")
        cv.put(x, bot + 1, "t")
    cv.vl(16, 15, 21, "t")
    cv.vl(48, 15, 21, "t")
    # raised flower in the middle
    cv.ellipse(32, 26.5, 4.5, 3.5, "h")
    cv.ellipse(32, 26.5, 2.5, 2, "S")
    cv.put(32, 26, "W")
    for x, y in ((26, 25), (38, 25), (32, 31)):
        cv.put(x, y, "t")
    # little bells
    for x in (25, 32, 39):
        cv.vl(x, 35, 37, "s")
        cv.ellipse(x + 0.5, 39.5, 1.6, 1.6, "h")
        cv.put(x, 40, "s")


@art("illus.kp.sunfu_letter")
def kp_sunfu_letter(cv, r):
    # the Sun household's letter of introduction on a lacquer tray, sealed in red
    cv.rect(0, 0, W, H, "w")
    for x in range(0, W, 5):
        cv.vl(x, 0, 47, "x")
    cv.rect(8, 5, 48, 39, "Q")
    cv.frame(8, 5, 48, 39, "g")
    cv.frame(9, 6, 46, 37, "x")
    cv.hl(10, 53, 7, "f")
    # tall envelope with the red centre panel
    cv.rect(22, 9, 18, 31, "S")
    cv.vl(39, 9, 39, "h")
    cv.hl(22, 39, 39, "h")
    cv.rect(28, 11, 6, 26, "r")
    cv.vl(28, 11, 36, "R")
    for y in range(14, 34, 4):
        cv.hl(30, 32, y, "p")
    cv.rect(23, 33, 4, 4, "r")
    cv.frame(23, 33, 4, 4, "d")
    # jade tassel beside it
    cv.ellipse(47, 22, 3, 3, "j")
    cv.put(46, 21, "J")
    cv.vl(47, 25, 34, "r")
    cv.pts([(46, 35), (47, 35), (48, 35), (46, 36), (48, 36)], "R")
    cv.vl(47, 14, 18, "r")


@art("illus.st.ask_kin")
def st_ask_kin(cv, r):
    # at an old acquaintance's gate: the door opens a crack, someone peers out
    sky(cv, "grey", 10)
    wall_plaster(cv, 0, 6, W, 36, "h", "P", r)
    tile_roof(cv, 0, W - 1, 4, 2)
    cv.rect(28, 10, 28, 32, "f")
    tile_roof(cv, 27, 56, 8, 3)
    cv.rect(30, 14, 24, 28, "K")
    lay = layer()
    lay.rect(30, 14, 24, 28, "x")
    person(lay, 43, 44, OLDWOMAN, arm="fwd", face=-1)
    clip(lay, 38, 14, 46, 42)
    cv.paste(lay, 0, 0)
    plank_door(cv, 30, 14, 8, 28, "b", "w", ring=False)
    plank_door(cv, 46, 14, 8, 28, "b", "w", ring=False)
    cv.vl(37, 14, 41, "B")
    cv.pts([(36, 27), (47, 27)], "Y")
    ground(cv, 42, "slab")
    a = person(cv, 18, 46, RUHUA_ST, arm="fwd", arm2="hold", face=1)
    hx, hy = a["hand2"]
    cv.rect(hx - 4, hy - 1, 5, 4, "B")
    cv.hl(hx - 4, hx, hy - 1, "P")


@art("illus.st.beg")
def st_beg(cv, r):
    # sitting against the wall at the street corner, a bowl set out; a coin drops in
    sky(cv, "grey", 8)
    wall_plaster(cv, 0, 4, W, 36, "s", "t", r)
    tile_roof(cv, 0, W - 1, 2, 2)
    cv.rect(0, 30, W, 10, "t")
    cv.hl(0, W - 1, 30, "E")
    ground(cv, 40, "slab")
    person(cv, 16, 44, RUHUA_ST, legs="kneel", arm="low", face=1)
    bowl(cv, 23, 42, "m", "x")
    cv.put(25, 42, "Y")
    a = person(cv, 44, 46, FEDORA.but(coat="i", coat2="n"), legs="walk", arm="low", face=-1)
    hx, hy = a["hand"]
    cv.pts([(hx - 3, hy + 2), (hx - 6, hy + 5)], "Y")
    cv.pts([(hx - 4, hy + 3), (hx - 7, hy + 7)], "e")


@art("illus.st.carry")
def st_carry(cv, r):
    # carrying sacks at the wharf: up the gangplank from the boat, a sack on her shoulder
    sky(cv, "grey", 18)
    for x0, w0, h0 in ((0, 14, 6), (14, 10, 8), (40, 12, 5), (52, 12, 7)):
        cv.rect(x0, 18 - h0, w0, h0, "s")
        cv.hl(x0 - 1, x0 + w0, 18 - h0, "t")
    water(cv, r, 18, 48, "i", "I", "m", 22)
    cv.rect(0, 30, 26, 18, "s")
    for y in range(30, 48, 4):
        cv.hl(0, 25, y, "t")
    cv.vl(25, 30, 47, "E")
    boat(cv, 36, 44, 26, "w", "q")
    for i in range(3):
        rice_sack(cv, 3 + i * 7, 24, 7, 5, "P", tie=False)
    rice_sack(cv, 6, 19, 7, 5, "P", tie=False)
    cv.line(24, 31, 44, 39, "B")
    cv.line(24, 32, 44, 40, "b")
    a = person(cv, 33, 36, RUHUA_ST, legs="walk", arm="head", face=-1, lean=-1)
    hx, hy = a["hand"]
    rice_sack(cv, hx - 5, hy - 5, 10, 6, "P", tie=False)
    small_person(cv, 6, 42, WORKER, "stand", face=1)


@art("illus.st.copy")
def st_copy(cv, r):
    # copying out pages at a long desk, stacks to the left and right
    wall_plaster(cv, 0, 0, W, 30, "P", "B", r)
    lattice(cv, 22, 3, 20, 13, "w", "h", 5)
    ground(cv, 30, "floor")
    person(cv, 32, 42, RUHUA_ST, legs="sit", arm="give", face=1)
    table(cv, 6, 33, 52, 15, "w", "b")
    for i in range(5):
        cv.rect(8, 29 - i * 2, 12, 2, "p" if i % 2 else "h")
        cv.vl(19, 29 - i * 2, 30 - i * 2, "P")
    for i in range(3):
        cv.rect(46, 29 - i * 2, 10, 2, "h" if i % 2 else "p")
    paper(cv, 34, 30, 10, 4, "p", "b", None, r, 2)
    cv.rect(22, 31, 5, 2, "f")
    cv.line(37, 26, 39, 31, "B")
    cv.glow(32, 8, 14, 10, 0.5)


@art("illus.st.errand")
def st_errand(cv, r):
    # running an errand: over the arched stone bridge with a parcel under her arm
    sky(cv, "day", 26)
    for x0, w0, h0 in ((0, 16, 9), (16, 12, 7), (44, 10, 8), (54, 10, 10)):
        cv.rect(x0, 26 - h0, w0, h0, "h")
        cv.hl(x0 - 1, x0 + w0, 26 - h0, "E")
    water(cv, r, 26, 48, "I", "m", "h", 20)
    # bridge
    for x in range(4, 60):
        t = (x - 32) / 28.0
        top = int(round(22 + 10 * t * t))
        cv.vl(x, top, 34, "s")
        cv.put(x, top, "m")
        cv.put(x, top - 1, "t")
    for x in range(14, 51):
        t = (x - 32) / 18.0
        if abs(t) < 1:
            bot = int(round(46 - 12 * math.sqrt(1 - t * t)))
            for y in range(bot, 48):
                cv.put(x, y, "n" if (x + y) % 5 else "i")
    for x in range(14, 51):
        t = (x - 32) / 18.0
        if abs(t) < 1:
            cv.put(x, int(round(46 - 12 * math.sqrt(1 - t * t))) - 1, "t")
    for x in range(6, 58, 6):
        t = (x - 32) / 28.0
        cv.vl(x, int(round(22 + 10 * t * t)) - 3, int(round(22 + 10 * t * t)) - 1, "t")
    a = person(cv, 30, 22, RUHUA_ST, legs="run", arm="hold", arm2="swing", face=1)
    hx, hy = a["hand"]
    cv.rect(hx - 2, hy - 2, 4, 3, "B")
    cv.hl(hx - 2, hx + 1, hy - 2, "P")
    cv.vl(hx, hy - 2, hy, "b")


@art("illus.st.gamble")
def st_gamble(cv, r):
    # a street gambling stall: the painted wheel spins under a lantern, a few watch
    sky(cv, "dusk", 12)
    lay = layer()
    wall_plaster(lay, 0, 8, W, 32, "h", "P", r)
    tile_roof(lay, 0, W - 1, 6, 2)
    ground(lay, 40, "slab")
    lay.remap(DARK)
    cv.paste(lay, 0, 0)
    cx, cy, rad = 32, 22, 9
    cols = ["R", "p", "q", "Y", "j", "p"]
    for y in range(cy - rad, cy + rad + 1):
        for x in range(cx - rad, cx + rad + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > rad:
                continue
            if d > rad - 1.2:
                c = "k"
            elif d < 1.5:
                c = "Y"
            else:
                a = (math.atan2(y + 0.5 - cy, x + 0.5 - cx) + math.pi) / (2 * math.pi)
                c = cols[int(a * 6) % 6]
            cv.put(x, y, c)
    cv.pts([(cx, cy - rad - 2), (cx - 1, cy - rad - 3), (cx + 1, cy - rad - 3)], "y")
    cv.vl(cx, cy + rad, 34, "w")
    table(cv, 18, 34, 28, 14, "b", "B")
    cv.rect(22, 31, 5, 3, "h")
    cv.rect(36, 32, 4, 2, "Y")
    lantern(cv, 52, 9, "r")
    cv.glow(40, 20, 22, 16, 0.7)
    person(cv, 50, 46, STRANGER.but(coat="f", hat="cap", hatc="q", body="jacket"), arm="upfwd",
           face=-1)
    small_person(cv, 8, 46, WORKER, "stand", face=1)
    person(cv, 14, 47, RUHUA_ST, arm="down", face=1)


@art("illus.st.odd_job")
def st_odd_job(cv, r):
    # day labour at a building site: bricks carried in baskets past the bamboo scaffold
    sky(cv, "day", 40)
    cv.rect(26, 8, 38, 34, "t")
    for y in range(8, 42, 3):
        cv.hl(26, 63, y, "E")
        for x in range(26 + (y // 3 % 2) * 3, 64, 6):
            cv.vl(x, y, y + 2, "E")
    for x in (24, 36, 48, 60):
        cv.vl(x, 4, 41, "B")
    for y in (12, 22, 32):
        cv.hl(22, 63, y, "B")
        cv.hl(22, 63, y + 1, "b")
    small_person(cv, 42, 22, WORKER, "stand", face=-1)
    ground(cv, 40, "earth")
    cv.rect(0, 40, W, 8, "o")
    for i in range(4):
        cv.rect(4 + i, 36 - i * 2, 12 - i * 2, 2, "d")
        cv.hl(4 + i, 15 - i, 36 - i * 2, "R")
    a = person(cv, 30, 46, RUHUA_ST, legs="walk", arm="head", face=1)
    hx, hy = a["hand"]
    cv.line(hx - 11, hy + 1, hx + 10, hy - 1, "B")
    for bx in (hx - 13, hx + 7):
        cv.rect(bx, hy + 4, 7, 5, "B")
        cv.hl(bx, bx + 6, hy + 4, "P")
        cv.rect(bx + 1, hy + 2, 5, 2, "d")
        cv.vl(bx + 3, hy, hy + 3, "P")


@art("illus.st.pawn_own")
def st_pawn_own(cv, r):
    # at another pawnshop's high grilled window she reaches up with her last bangle
    cv.rect(0, 0, W, 40, "q")
    for y in range(0, 40, 4):
        for x in range((y // 4 % 2) * 4, W, 8):
            cv.hl(x, x + 6, y, "f")
    cv.rect(18, 6, 34, 18, "w")
    cv.frame(17, 5, 36, 20, "x")
    cv.rect(20, 8, 30, 12, "c")
    for x in range(21, 50, 3):
        cv.vl(x, 8, 19, "x")
    cv.rect(16, 24, 38, 3, "b")
    cv.hl(16, 53, 24, "B")
    cv.rect(37, 20, 8, 4, "N")
    cv.hl(37, 44, 20, "P")
    ground(cv, 40, "slab")
    a = person(cv, 26, 47, RUHUA_ST, arm="upfwd", arm2="down", face=1)
    hx, hy = a["hand"]
    cv.ellipse(hx + 1.5, hy - 2, 2.5, 2, "h")
    cv.ellipse(hx + 1.5, hy - 2, 1.2, 0.8, "q")
    cv.put(hx + 3, hy - 3, "W")
    cv.glow(35, 14, 16, 9, 0.7)


@art("illus.st.scavenge")
def st_scavenge(cv, r):
    # picking along the riverbank among the reeds, a basket on her back
    sky(cv, "grey", 16)
    cv.rect(0, 12, W, 4, "s")
    water(cv, r, 16, 30, "s", "m", "h", 10)
    cv.rect(0, 28, W, 20, "o")
    cv.poly([(0, 26), (W, 30), (W, 48), (0, 48)], "o")
    cv.rect(0, 40, W, 8, "B")
    for x in range(0, W, 3):
        if 18 < x < 44:
            continue
        h = 6 + (x * 7) % 5
        cv.line(x, 34, x + (1 if x % 2 else -1), 34 - h, "l")
        cv.put(x + (1 if x % 2 else -1), 33 - h, "B")
    a = person(cv, 30, 45, RUHUA_ST, legs="squat", arm=(4, 3), face=1)
    hx, hy = a["head"]
    cv.rect(hx - 8, hy + 2, 6, 8, "B")
    for y in range(hy + 3, hy + 10, 2):
        cv.hl(hx - 8, hx - 3, y, "b")
    cv.hl(hx - 9, hx - 2, hy + 2, "P")
    cv.rect(40, 42, 3, 4, "j")
    cv.put(41, 41, "J")
    cv.rect(46, 44, 5, 2, "i")
    cv.pts([(36, 45), (37, 45)], "m")


@art("illus.st.stall")
def st_stall(cv, r):
    # a cloth on the ground by the road, a few things laid out for sale
    sky(cv, "day", 8)
    shopfront(cv, 0, 4, 32, 30, r, "h", "b")
    shopfront(cv, 32, 6, 32, 28, r, "P", "w", banner="j")
    ground(cv, 34, "slab")
    cv.poly([(10, 38), (44, 38), (48, 46), (6, 46)], "i")
    cv.hl(10, 44, 38, "I")
    for x in range(10, 46, 4):
        cv.put(x, 45, "I")
    bowl(cv, 13, 40, "h", "i")
    cv.rect(21, 39, 3, 5, "h")
    cv.put(22, 38, "h")
    cv.hl(21, 23, 41, "i")
    cv.rect(27, 41, 5, 2, "Q")
    cv.rect(33, 41, 5, 2, "Q")
    cv.ellipse(42, 41.5, 2.5, 2, "Y")
    cv.put(41, 41, "y")
    person(cv, 26, 37, RUHUA_ST, legs="squat", arm="low", face=1)
    person(cv, 56, 47, GENTRY.but(coat="B", coat2="b"), arm="low", face=-1, lean=1)


@art("illus.st.watch")
def st_watch(cv, r):
    # night watch at a warehouse gate: lantern in one hand, the wooden clapper in the other
    sky(cv, "night", 16)
    stars(cv, r, 10, 12)
    moon(cv, 54, 6, 3)
    lay = layer()
    lay.rect(0, 10, W, 32, "t")
    for y in range(10, 42, 3):
        lay.hl(0, W - 1, y, "E")
    tile_roof(lay, 0, W - 1, 8, 2)
    lay.rect(20, 16, 26, 26, "x")
    plank_door(lay, 22, 18, 22, 24, "b", "w")
    ground(lay, 42, "slab")
    at_night(cv, lay)
    a = person(cv, 14, 46, RUHUA_ST, arm="give", arm2="chest", face=1)
    hx, hy = a["hand"]
    cv.vl(hx + 1, hy, hy + 2, "k")
    lantern(cv, hx + 1, hy + 3, "r", string=False)
    hx2, hy2 = a["hand2"]
    cv.rect(hx2 - 1, hy2 - 3, 2, 4, "B")
    cv.line(hx2, hy2, hx2 + 3, hy2 - 3, "P")
    cv.glow(hx + 1, hy + 6, 12, 9, 1.0)


@art("illus.st.write_letters")
def st_write_letters(cv, r):
    # a letter-writing table at the street corner; an old woman tells her what to say
    sky(cv, "day", 8)
    wall_plaster(cv, 0, 4, W, 36, "h", "P", r)
    tile_roof(cv, 0, W - 1, 2, 2)
    cv.poly([(4, 12), (44, 12), (40, 16), (8, 16)], "B")
    cv.hl(4, 44, 12, "P")
    cv.vl(8, 16, 40, "b")
    cv.vl(40, 16, 40, "b")
    paper(cv, 12, 18, 8, 10, "p", "b", "r", r)
    ground(cv, 40, "slab")
    person(cv, 18, 44, RUHUA_ST, legs="sit", arm="give", face=1)
    table(cv, 22, 34, 16, 14, "B")
    paper(cv, 25, 31, 9, 4, "p", "b", None, r, 2)
    cv.line(29, 27, 31, 31, "B")
    envelope(cv, 34, 31, 4, 3, "h", "r")
    person(cv, 50, 46, OLDWOMAN, arm="give", arm2="down", face=-1)


# ---------------------------------------------------------------------- END OF DRAWERS

# --------------------------------------------------------------------------- driver


def out_rel(art_id):
    assert art_id.startswith("illus.")
    return "art/ai/illus/%s.png" % art_id.split(".", 1)[1]


def render(art_id):
    cv = Cv(W, H)
    ILLUS[art_id](cv, rng_for(art_id))
    holes = [(x, y) for y in range(H) for x in range(W) if cv.a[y][x] is None]
    if holes and os.environ.get("ILLUS_DEV"):
        print("HOLES", art_id, holes[:3])
        for x, y in holes:
            cv.a[y][x] = "R"
        holes = []
    assert not holes, (art_id, "transparent pixels", holes[:5])
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


def build_sheet(ids, images, path, scale=3, cols=6):
    from PIL import ImageDraw, ImageFont

    font = ImageFont.load_default()
    cell_w = W * scale + 12
    label_h = 14
    cell_h = H * scale + label_h + 8
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w + 8, rows * cell_h + 8), (0x80, 0x78, 0x6c, 255))
    d = ImageDraw.Draw(sheet)
    for n, aid in enumerate(ids):
        im = images[aid]
        big = im.resize((W * scale, H * scale), Image.NEAREST)
        x = 4 + (n % cols) * cell_w + 6
        y = 4 + (n // cols) * cell_h
        sheet.alpha_composite(big, (x, y))
        label = aid.split(".", 1)[1]
        tw = d.textlength(label, font=font)
        d.text((x + (W * scale - tw) / 2, y + H * scale + 3), label, fill=(255, 255, 255, 255),
               font=font)
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
    p.add_argument("--frag", default="")
    p.add_argument("--list", action="store_true")
    a = p.parse_args(argv)
    only = a.only
    if only and not only.startswith("illus."):
        only = "illus." + only
    ids = sorted(i for i in ILLUS if i.startswith(only))
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
            im.resize((W * 8, H * 8), Image.NEAREST).save(os.path.join(a.zoom, aid + ".png"))
    if a.sheet:
        build_sheet(ids, images, a.sheet)
    if a.frag:
        frag = {}
        for aid in sorted(ILLUS):
            frag[aid] = {"ai": out_rel(aid), "_provenance": PROVENANCE}
        os.makedirs(os.path.dirname(os.path.abspath(a.frag)), exist_ok=True)
        with open(a.frag, "w", encoding="utf-8") as f:
            json.dump(frag, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
    print("%s %d images%s" % ("CHECK" if a.check else "WROTE", len(ids), (", %d problems" % bad) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
