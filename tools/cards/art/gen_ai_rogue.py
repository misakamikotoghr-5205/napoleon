#!/usr/bin/env python3
"""AI pixel art for the card game, batch "rogue": the roguelite v1 curio shelf, relics and customer sources.

    python3 tools/cards/art/gen_ai_rogue.py [--out=<root>] [--only=<id prefix>] [--check] [--force]
                                            [--zoom=<dir>] [--sheet=<png>] [--frag=<json>] [--list]
                                            [--palette]

The 19 ids of docs/cards/rogue/ROGUE_V1.md section 12:
  prop.curio            52x38  the wall shelf (scene x4): dark frame, 3 x 2 empty cells of 16 x 16,
                               frame 2 px left/right and 3 px top/bottom, no gap between cells
  prop.relic.<slug>     32x32  twelve old objects on transparent ground (x2 in a cell / drawer, x4 on a card)
  illus.ky.<slug>       64x48  six customer-source scenes, opaque (x2 on a card)
Writes art/ai/<category>/<rest>.png for art id <category>.<rest>, plus its .png.import sidecar
(art_common.render_png_import; an existing valid uid is kept, otherwise the deterministic one).

Every picture is drawn here in code, pixel by pixel (no image model, no fonts, no source images).

* Deterministic: same script -> byte-identical files. Each picture's RNG is
  random.Random(first 8 bytes of sha256(art_id)); geometry uses + - * / and sqrt only (no
  trigonometry, so no libm differences); the PNG is written by this script with the standard
  library (IHDR/IDAT/IEND only, 8-bit RGBA, filter 0 on every row, zlib level 9); ids are sorted.
* Colors: only values of keys in data/cards/theme/palette.dev.json, copied below (as of
  2026-10-25) so a later palette edit does not silently change shipped pixels. --palette checks
  that every key still exists (exit 1 if one is gone) and notes values that drifted.
* No letters, numbers or readable characters. The old signboard carries abstract gold strokes only.
* Existing files under art/ai are never overwritten unless --force is given (re-running over this
  script's own output); --check compares PNG and .import bytes without writing (exit 1 on any difference).
* No third-party modules: --zoom and --sheet also use the built-in PNG writer.

Batch owner: ai:claude:opus-5.5:2026-10-25:art-rogue (RG3). Spec: docs/cards/ART_SPEC.md, ROGUE_V1.md section 12.
"""

import argparse
import hashlib
import json
import math
import os
import random
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_common as ac  # noqa: E402  (stdlib only)

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PROVENANCE = "ai:claude:opus-5.5:2026-10-25:art-rogue"

# palette.dev.json keys (opaque ones) and their 2026-10-25 values; one letter each for the pixel maps.
PAL = {
    "K": ("scene_void", "#0d0a08"),
    "k": ("ink", "#1f1712"),
    "x": ("wood_1", "#2b1c12"),
    "w": ("wood", "#3a2a1e"),
    "v": ("wood_3", "#4a3423"),
    "b": ("ink_soft", "#5a3f2a"),
    "u": ("umber", "#6b4a2e"),
    "B": ("frame_person", "#7a5634"),
    "o": ("ink_3", "#7a6650"),
    "t": ("text_3", "#94806a"),
    "T": ("text_2", "#c4ae8a"),
    "P": ("paper_old", "#d9c49a"),
    "p": ("paper", "#f4e2b0"),
    "h": ("hud_ink", "#efe3c7"),
    "S": ("seal_paper", "#f4efe0"),
    "W": ("guide_bubble", "#fff6dc"),
    "N": ("night_tint", "#f2d9b8"),
    "c": ("candle_tint", "#ffdba8"),
    "y": ("lamp", "#ffd25a"),
    "Z": ("gold_pale", "#fff0b8"),
    "e": ("gold_hi", "#e8c35a"),
    "a": ("btn_day", "#d9a53c"),
    "Y": ("btn_primary_bot", "#b98a1f"),
    "g": ("gold", "#a07a2c"),
    "s": ("frame_street", "#8a5a24"),
    "L": ("ribbon_ink", "#5a3a08"),
    "r": ("seal", "#b3372a"),
    "R": ("btn_day_confirm", "#c8452c"),
    "q": ("seal_dark", "#86231a"),
    "X": ("frame_big_fate", "#5d2b3b"),
    "E": ("bad", "#e0715a"),
    "j": ("jade", "#2f6b5a"),
    "J": ("almanac_yi", "#9fd38f"),
    "G": ("good", "#4a6a3a"),
    "f": ("frame_fate", "#55683f"),
    "i": ("indigo", "#34506d"),
    "I": ("btn_day_night", "#5c6aa8"),
    "D": ("frame_news", "#5d6a74"),
    "m": ("mist", "#9aa4aa"),
    "M": ("dialog_me", "#a9cdf0"),
    "A": ("btn_day_night_hi", "#b9c4f0"),
    "Q": ("frame_prison", "#3a3a3e"),
    "C": ("card_night_bot", "#22242f"),
    "V": ("frame_night", "#5c5f78"),
    "H": ("card_prison_top", "#d9d6cf"),
    "U": ("card_prison_bot", "#b9b5ab"),
}


def _rgba(hx):
    hx = hx.lstrip("#")
    return (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16), 255)


COL = {ch: _rgba(v[1]) for ch, v in PAL.items()}
CLEAR = (0, 0, 0, 0)
ALLOWED = set(COL.values()) | {CLEAR}

# One step lighter / darker for edge shading (light from the upper left, the shop lamp).
LIGHT = {
    "K": "k", "k": "x", "x": "w", "w": "v", "v": "b", "b": "u", "u": "B", "B": "T", "o": "t", "t": "T",
    "T": "P", "P": "p", "p": "W", "h": "W", "S": "W", "W": "W", "N": "W", "c": "W", "y": "Z", "Z": "W",
    "e": "y", "a": "e", "Y": "a", "g": "Y", "s": "g", "L": "s", "r": "R", "R": "E", "q": "r", "X": "q",
    "E": "c", "j": "f", "J": "W", "G": "f", "f": "J", "i": "I", "I": "M", "D": "m", "m": "H", "M": "A",
    "A": "W", "Q": "V", "C": "i", "V": "m", "H": "S", "U": "H",
}
DARK = {
    "K": "K", "k": "K", "x": "k", "w": "x", "v": "w", "b": "v", "u": "b", "B": "u", "o": "b", "t": "o",
    "T": "t", "P": "T", "p": "P", "h": "P", "S": "H", "W": "h", "N": "P", "c": "N", "y": "e", "Z": "y",
    "e": "a", "a": "Y", "Y": "g", "g": "s", "s": "L", "L": "x", "r": "q", "R": "r", "q": "X", "X": "k",
    "E": "R", "j": "C", "J": "f", "G": "j", "f": "G", "i": "C", "I": "i", "D": "Q", "m": "D", "M": "I",
    "A": "M", "Q": "C", "C": "K", "V": "Q", "H": "U", "U": "m",
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# Shading ramps, dark -> light.
R_PORC = ["U", "H", "S", "W"]
R_BLUE = ["C", "i", "I", "M"]
R_BRONZE = ["x", "b", "s", "g", "a", "e"]
R_BRASS = ["L", "g", "Y", "a", "e", "y"]
R_CAMPHOR = ["w", "b", "u", "B", "T"]
R_ROSE = ["K", "k", "X", "q"]
R_WOOD = ["K", "k", "x", "w", "v", "b"]
R_OCHRE = ["L", "s", "Y", "a", "e"]
R_YELLOW = ["g", "Y", "a", "e", "y"]
R_PAPER = ["t", "T", "P", "p"]
R_RED = ["X", "q", "r", "R", "E"]
R_GREY = ["C", "Q", "V", "D", "m"]


def bay(x, y, level):
    """True where a 4x4 ordered dither of strength level (0..1) picks the second colour."""
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0 < level


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def ramp_pick(ramp, v, x, y, dither=True):
    v = max(0.0, min(0.999, v))
    f = v * (len(ramp) - 1)
    i = int(f)
    if dither and i + 1 < len(ramp) and bay(x, y, (f - i) * 0.9):
        i += 1
    elif not dither:
        i = int(f + 0.5)
    return ramp[min(i, len(ramp) - 1)]


# --------------------------------------------------------------------------- canvas


class Cv:
    """Pixel canvas holding palette letters (None = transparent)."""

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
        return self.a[y][x] if self.inside(x, y) else None

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

    def pts(self, lst, c):
        for x, y in lst:
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

    def ellipse(self, cx, cy, rx, ry, c, test=None):
        """Filled ellipse through pixel centres; cx, cy may be half-integers."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if d <= 1.0 and (test is None or test(x, y, d)):
                    self.put(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        n = len(pts)
        for y in range(int(min(ys)), int(max(ys)) + 1):
            yc = y + 0.5
            xs = []
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
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                self.put(x + i, y + j, cmap.get(ch, ch) if cmap else ch)

    def recolor(self, frm, to, box=None):
        x0, y0, x1, y1 = box or (0, 0, self.w, self.h)
        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                if self.a[y][x] in frm:
                    self.a[y][x] = to

    def outline(self, c="k"):
        """1px outline on transparent pixels next to opaque ones (4-neighbourhood)."""
        src = [row[:] for row in self.a]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[yy][xx] is not None:
                        self.a[y][x] = c
                        break

    def edge_shade(self, skip="kK"):
        """Darken lower-right edges, lighten upper-left edges of each opaque area."""
        src = [row[:] for row in self.a]

        def clear(x, y):
            return not (0 <= x < self.w and 0 <= y < self.h) or src[y][x] is None or src[y][x] in "kK"

        for y in range(self.h):
            for x in range(self.w):
                c = src[y][x]
                if c is None or c in skip:
                    continue
                if clear(x + 1, y) or clear(x, y + 1):
                    self.a[y][x] = DARK.get(c, c)
                elif clear(x - 1, y) or clear(x, y - 1):
                    self.a[y][x] = LIGHT.get(c, c)

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                v = other.a[y][x]
                if v is not None:
                    self.put(ox + x, oy + y, v)

    def flip_x(self):
        self.a = [row[::-1] for row in self.a]

    def vgrad(self, x, y, w, h, ramp):
        """Banded vertical gradient top -> bottom with dithered seams."""
        for yy in range(y, y + h):
            t = (yy - y + 0.5) / max(1, h)
            for xx in range(x, x + w):
                self.put(xx, yy, ramp_pick(ramp, t, xx, yy))

    def pixels(self):
        return [[CLEAR if v is None else COL[v] for v in row] for row in self.a]


def dome(cv, cx, cy, rx, ry, ramp, only=None, bias=0.0, dither=True):
    """Shade the pixels of an ellipse as a dome lit from the upper left."""
    lx, ly, lz = -0.55, -0.6, 0.58
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not cv.inside(x, y) or cv.a[y][x] is None:
                continue
            if only is not None and cv.a[y][x] not in only:
                continue
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            nz = math.sqrt(1.0 - d)
            v = (nx * lx + ny * ly + nz * lz + 0.35) / 1.35 + bias
            cv.a[y][x] = ramp_pick(ramp, v, x, y, dither)


def band(cv, x0, x1, ramp, only, y0=0, y1=None, bias=0.0):
    """Vertical cylinder shading across x0..x1: brightest a third of the way in, darker to the right."""
    y1 = cv.h if y1 is None else y1
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            if not cv.inside(x, y) or cv.a[y][x] not in only:
                continue
            t = (x + 0.5 - x0) / max(1.0, (x1 + 1 - x0))
            v = 1.0 - abs(t - 0.32) * 1.5 + bias
            cv.a[y][x] = ramp_pick(ramp, v, x, y)


def hband(cv, y0, y1, ramp, only, x0=0, x1=None, bias=0.0):
    """Horizontal cylinder shading across rows y0..y1 (lit on top)."""
    x1 = cv.w - 1 if x1 is None else x1
    for y in range(y0, y1 + 1):
        t = (y + 0.5 - y0) / max(1.0, (y1 + 1 - y0))
        for x in range(x0, x1 + 1):
            if not cv.inside(x, y) or cv.a[y][x] not in only:
                continue
            v = 1.0 - abs(t - 0.3) * 1.5 + bias
            cv.a[y][x] = ramp_pick(ramp, v, x, y)


def stick(cv, ax, ay, bx, by, radius_at, colour_at):
    """A rod from A (s=0) to B (s=1); radius_at(s) and colour_at(s, side) pick each pixel.

    side is the signed distance from the axis in radii (-1 = upper-left edge, +1 = lower-right edge).
    """
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    length = math.sqrt(length2)
    px, py = -dy / length, dx / length          # unit normal
    if px + py > 0:                            # make "negative side" the upper-left one
        px, py = -px, -py
    xs = [ax, bx]
    ys = [ay, by]
    pad = 6
    for y in range(int(min(ys)) - pad, int(max(ys)) + pad + 1):
        for x in range(int(min(xs)) - pad, int(max(xs)) + pad + 1):
            qx, qy = x + 0.5 - ax, y + 0.5 - ay
            s = (qx * dx + qy * dy) / length2
            if s < 0.0 or s > 1.0:
                continue
            dist = qx * px + qy * py
            r = radius_at(s)
            if r <= 0.0 or abs(dist) > r:
                continue
            c = colour_at(s, -dist / r, x, y)
            if c is not None:
                cv.put(x, y, c)


def finish_sprite(cv, shade=True):
    if shade:
        cv.edge_shade()
    cv.outline("k")
    return cv


# --------------------------------------------------------------------------- prop.curio 52x38


def prop_curio(cv, r):
    """Wall curio shelf: dark frame, six 16 x 16 cells (2 px frame left/right, 3 px top/bottom)."""
    w, h = cv.w, cv.h
    cv.rect(0, 0, w, h, "w")
    # frame grain: long horizontal streaks
    for y in range(h):
        for x in range(w):
            n = (x * 7 + y * 13 + (x // 5) * 3) % 23
            if n == 0:
                cv.put(x, y, "x")
            elif n == 11 and (x + y) % 3 == 0:
                cv.put(x, y, "v")
    # outer frame edges: lit top-left, dark bottom-right, ink rim
    cv.hl(0, w - 1, 0, "k")
    cv.hl(0, w - 1, h - 1, "k")
    cv.vl(0, 0, h - 1, "k")
    cv.vl(w - 1, 0, h - 1, "k")
    cv.hl(1, w - 2, 1, "b")
    cv.vl(1, 1, h - 2, "v")
    cv.hl(1, w - 2, h - 2, "x")
    cv.vl(w - 2, 1, h - 2, "x")
    # crown moulding on the top rail
    for x in range(2, w - 2):
        cv.put(x, 2, "v" if x % 4 else "b")
    for row in range(2):
        for col in range(3):
            _curio_cell(cv, 2 + col * 16, 3 + row * 16, r)
    # small brass pins where the boards meet the frame
    for x, y in ((2, 3), (49, 3), (2, 34), (49, 34), (2, 19), (49, 19)):
        cv.put(x, y, "g")


def _curio_cell(cv, x0, y0, r):
    """One 16 x 16 cell interior: darker back, shadow under the board above, lit board below."""
    for y in range(16):
        for x in range(16):
            c = "x"
            if (x * 3 + y * 5 + x0) % 11 == 0:
                c = "k"
            elif (x + y * 2 + y0) % 13 == 0:
                c = "w"
            cv.put(x0 + x, y0 + y, c)
    # inner walls: the left wall faces away from the lamp (dark), the right wall faces it (lit)
    cv.vl(x0, y0, y0 + 15, "k")
    cv.vl(x0 + 15, y0, y0 + 15, "v")
    # ceiling shadow, floor board lit along its front edge
    cv.hl(x0, x0 + 15, y0, "K")
    cv.hl(x0 + 1, x0 + 15, y0 + 1, "k")
    cv.hl(x0 + 1, x0 + 14, y0 + 14, "w")
    cv.hl(x0, x0 + 15, y0 + 15, "b")
    cv.put(x0, y0 + 15, "w")


# --------------------------------------------------------------------------- relics 32x32


def relic_cat_bowl(cv, r):
    cx, cy = 16.0, 17.0
    # body: lower half of a deep ellipse under the rim
    cv.ellipse(cx, cy, 12.5, 10.5, "S", test=lambda x, y, d: y + 0.5 >= cy)
    cv.rect(11, 26, 11, 3, "H")
    dome(cv, cx, cy, 12.5, 10.5, R_PORC, only={"S"}, bias=0.12)
    cv.hl(11, 21, 28, "U")
    cv.hl(12, 20, 26, "U")
    # rim and inside
    cv.ellipse(cx, cy, 12.5, 4.5, "S")
    cv.ellipse(cx, cy + 0.3, 10.6, 3.3, "H")
    cv.ellipse(cx + 0.6, cy + 0.8, 8.5, 2.2, "U")
    # a little cat food at the bottom of the bowl
    cv.ellipse(cx + 1.0, cy + 1.0, 4.6, 1.4, "u")
    cv.pts([(15, 17), (17, 17), (19, 18), (14, 18)], "B")
    cv.pts([(16, 17), (18, 18)], "T")
    # blue bands following the curve of the body, and three flower sprays
    for x in range(4, 29):
        t = (x + 0.5 - cx) / 12.5
        if abs(t) >= 1.0:
            continue
        k = math.sqrt(1.0 - t * t)
        yb = int(cy + 10.5 * k * 0.42) + 1
        if cv.get(x, yb) in R_PORC:
            cv.put(x, yb, "i")
        yf = int(cy + 10.5 * k * 0.86)
        if abs(t) < 0.8 and cv.get(x, yf) in R_PORC:
            cv.put(x, yf, "i")
    for fx in (9, 16, 23):
        fy = 23 if fx == 16 else 22
        cv.pts([(fx, fy - 1), (fx - 1, fy), (fx + 1, fy), (fx, fy + 1)], "I")
        cv.put(fx, fy, "i")
        cv.pts([(fx + 2, fy - 1), (fx - 2, fy + 1)], "C")
    # rim highlight on the lit side
    cv.pts([(6, 15), (7, 14), (8, 14)], "W")
    # lumps of food
    cv.pts([(13, 17), (20, 18), (16, 19)], "b")
    cv.outline("k")
    # the chip: a V bitten out of the far rim, raw body showing at its edges
    cv.pts([(21, 11), (22, 11), (23, 11), (22, 12)], None)
    cv.pts([(21, 12), (23, 12), (22, 13)], "k")
    cv.pts([(20, 12), (24, 12), (21, 13), (23, 13)], "T")


def relic_stub_box(cv, r):
    # lid, hinged at the back edge and propped half open
    cv.poly([(9, 13), (28, 13), (26, 5), (8, 6)], "u")
    cv.poly([(10, 12), (27, 12), (25.5, 6.5), (9.5, 7)], "b")
    cv.hl(9, 27, 13, "w")
    # top opening with a stack of yellowed stubs
    cv.poly([(5, 18), (24, 18), (28, 13), (9, 13)], "x")
    for i in range(5):
        y = 17 - i
        x0 = 7 + i
        cv.hl(x0, x0 + 17, y, "P" if i % 2 else "T")
    cv.poly([(8, 15), (20, 15), (22, 12), (11, 12)], "p")
    cv.hl(11, 21, 12, "W")
    cv.pts([(13, 13), (14, 13), (17, 13), (18, 14), (12, 14)], "t")
    cv.pts([(15, 11), (16, 10), (17, 11)], "P")  # one stub sticks up
    cv.put(16, 11, "p")
    # box front and right side
    cv.rect(5, 18, 20, 11, "B")
    cv.poly([(24, 18), (28, 13), (28, 24), (24, 29)], "u")
    hband(cv, 18, 28, R_CAMPHOR, {"B"}, 5, 24, bias=-0.05)
    for x in range(6, 24, 4):
        cv.vl(x, 20, 27, "u" if x % 8 else "b")
    cv.hl(5, 24, 18, "T")
    # brass hasp
    cv.rect(13, 18, 3, 4, "a")
    cv.put(14, 20, "k")
    cv.pts([(13, 21), (15, 21)], "g")
    finish_sprite(cv, shade=False)


def relic_blue_curtain(cv, r):
    folds = [(4, 21, 24, 8), (6, 14, 22, 8), (5, 8, 22, 7)]
    for i, (x, y, w, h) in enumerate(folds):
        fold = Cv(32, 32)
        fold.rect(x + 2, y, w - 2, h, "I")
        fold.ellipse(x + 2.5, y + h / 2.0, 2.5, h / 2.0, "I")   # rounded fold on the left
        hband(fold, y, y + h - 1, R_BLUE, {"I"}, bias=0.05 - 0.08 * i)
        # quilting: dashed lighter stitches
        for xx in range(x + 3, x + w, 2):
            if (xx + i) % 4 == 0:
                fold.put(xx, y + h // 2, "M")
        for yy in range(y + 1, y + h - 1):
            fold.put(x + 9 + i, yy, "C" if yy % 2 else "i")
        # cotton showing at the folded edge
        fold.put(x + 1, y + h // 2, "S")
        fold.put(x + 1, y + h // 2 - 1, "H")
        fold.outline("k")
        cv.paste(fold, 0, 0)
    # a patch near the right end of the top fold
    cv.rect(19, 9, 5, 4, "D")
    cv.pts([(19, 9), (21, 9), (23, 9), (19, 11), (23, 11)], "m")
    cv.pts([(20, 12), (22, 12), (23, 12)], "Q")
    cv.pts([(18, 9), (18, 11), (24, 10), (24, 12)], "M")


def relic_oilpaper_umbrella(cv, r):
    ax, ay, bx, by = 6.0, 29.0, 27.0, 3.0

    def radius(s):
        if s < 0.07:
            return 1.6                       # handle knob
        if s < 0.36:
            return 1.05                      # bamboo shaft
        if s < 0.42:
            return 1.4 + (s - 0.36) * 30.0   # runner, flaring out
        if s < 0.62:
            return 3.2 + (s - 0.42) * 4.0
        if s < 0.96:
            return 4.0 * (0.96 - s) / 0.34 + 0.6
        return 0.9                           # tip

    def colour(s, side, x, y):
        if s < 0.07:
            return ramp_pick(["x", "b", "u"], 0.6 - side * 0.5, x, y)
        if s < 0.36:
            node = int(s * 60) % 7 == 0
            return "t" if node else ramp_pick(["t", "T", "P"], 0.65 - side * 0.5, x, y)
        if s >= 0.96:
            return "b"
        v = 0.62 - side * 0.45
        c = ramp_pick(R_OCHRE, v, x, y)
        # folded ribs: darker creases running along the canopy
        if abs(side + 0.35) < 0.12 or abs(side - 0.45) < 0.12:
            c = DARK.get(c, c)
        return c

    stick(cv, ax, ay, bx, by, radius, colour)
    # tie string around the bundle
    stick(cv, ax + (bx - ax) * 0.66, ay + (by - ay) * 0.66, ax + (bx - ax) * 0.69, ay + (by - ay) * 0.69,
          lambda s: 3.7, lambda s, side, x, y: "r" if side < 0.3 else "q")
    cv.outline("k")


def relic_old_almanac(cv, r):
    # page block (seen along the lower-right edge)
    cv.poly([(9, 25), (28, 20), (28, 24), (9, 29)], "p")
    for k in range(3):
        cv.line(10, 26 + k, 27, 21 + k, "P" if k % 2 == 0 else "T")
    # red paper slip sticking out of the pages
    cv.poly([(24, 22), (30, 17), (31, 18), (25, 23)], "r")
    cv.pts([(26, 20), (28, 18)], "R")
    # cover
    cv.poly([(4, 14), (23, 9), (28, 20), (9, 25)], "a")
    for y in range(32):
        for x in range(32):
            if cv.get(x, y) == "a":
                v = 0.75 - ((x - 4) + (y - 9)) / 48.0
                cv.put(x, y, ramp_pick(R_YELLOW, v, x, y))
    # spine strip with thread stitches
    cv.line(5, 15, 9, 24, "g", 2)
    for t in (0.15, 0.4, 0.65, 0.88):
        sx = int(5 + 4 * t)
        sy = int(15 + 9 * t)
        cv.put(sx + 2, sy, "h")
        cv.put(sx + 1, sy, "S")
    # title slip with abstract strokes (not characters)
    cv.poly([(9, 15), (12, 14), (15, 20), (12, 21)], "p")
    cv.pts([(11, 16), (12, 17), (12, 18), (13, 19)], "b")
    # curled top-right corner
    cv.poly([(20, 10), (23, 9), (24.5, 12.5)], "Z")
    cv.line(20, 10, 24, 12, "g")
    cv.outline("k")


def relic_chen_mortar(cv, r):
    # boat-shaped trough on two small feet, prow and stern turned up
    trough = [(1, 18), (5, 21), (27, 21), (31, 18), (29, 24), (23, 27), (9, 27), (3, 24)]
    cv.poly(trough, "s")
    for y in range(18, 28):
        for x in range(32):
            if cv.get(x, y) == "s":
                v = 0.78 - (y - 18) / 11.0 - (x - 4) / 90.0
                cv.put(x, y, ramp_pick(["x", "b", "s", "g"], v, x, y))
    cv.rect(9, 27, 3, 2, "w")
    cv.rect(21, 27, 3, 2, "w")
    # rim along the top, then the dark groove
    cv.hl(4, 28, 20, "a")
    cv.pts([(1, 18), (2, 18), (30, 18), (31, 18)], "a")
    cv.hl(6, 26, 21, "k")
    # verdigris on the lower body
    for y in range(23, 28):
        for x in range(3, 30):
            if cv.get(x, y) in ("x", "b", "s", "g") and (x * 5 + y * 3) % 7 == 0:
                cv.put(x, y, "j" if (x + y) % 2 else "f")
    cv.pts([(8, 25), (17, 26), (24, 24), (13, 23)], "J")
    # the grinding wheel standing in the groove: bright face, darker rim, hub hole
    wheel = Cv(32, 32)
    wheel.ellipse(16.0, 14.5, 7.0, 7.0, "s")
    wheel.ellipse(16.0, 14.5, 5.6, 5.6, "a")
    dome(wheel, 16.0, 14.5, 5.6, 5.6, ["g", "Y", "a", "e", "y"], only={"a"}, bias=0.0)
    wheel.ellipse(16.0, 14.5, 1.6, 1.6, "x")
    wheel.pts([(19, 18), (20, 17), (12, 18)], "j")
    wheel.outline("k")
    for y in range(32):
        for x in range(32):
            if wheel.a[y][x] is not None and y < 21:
                cv.put(x, y, wheel.a[y][x])
    # wooden axle handle through the hub, sticking out both sides
    cv.hl(4, 28, 14, "T")
    cv.hl(4, 28, 15, "u")
    cv.pts([(3, 14), (3, 15), (29, 14), (29, 15)], "b")
    cv.pts([(15, 14), (16, 14), (17, 14)], "B")
    cv.outline("k")


def relic_hu2_pipe(cv, r):
    # long stem, from the jade mouthpiece (left) to the brass bowl (right)
    def radius(s):
        return 1.3 if s < 0.16 else 1.0

    def colour(s, side, x, y):
        if s < 0.16:
            return ramp_pick(["G", "j", "J"], 0.6 - side * 0.5, x, y)
        if s > 0.93:
            return ramp_pick(R_BRASS, 0.6 - side * 0.4, x, y)
        return "u" if side < 0 else "b"

    stick(cv, 1.5, 23.5, 25.5, 13.5, radius, colour)
    # brass bowl
    cv.ellipse(26.5, 12.0, 3.2, 2.6, "Y")
    dome(cv, 26.5, 12.0, 3.2, 2.6, R_BRASS, only={"Y"}, bias=0.1)
    cv.hl(25, 28, 10, "e")
    cv.hl(25, 28, 9, "k")
    cv.put(26, 10, "x")
    cv.put(27, 10, "x")
    # cord and tobacco pouch
    cv.line(20, 16, 21, 19, "r")
    pouch = Cv(32, 32)
    pouch.ellipse(21.0, 24.0, 4.2, 4.0, "q")
    pouch.rect(19, 19, 5, 2, "q")
    dome(pouch, 21.0, 24.0, 4.2, 4.0, R_RED, only={"q"}, bias=-0.05)
    pouch.pts([(20, 23), (22, 25), (19, 26), (23, 22)], "e")
    pouch.hl(19, 23, 20, "R")
    pouch.outline("k")
    cv.paste(pouch, 0, 0)
    cv.outline("k")


def relic_camphor_chest(cv, r):
    # lid top, front, right side
    cv.poly([(4, 13), (24, 13), (28, 9), (8, 9)], "T")
    cv.rect(4, 13, 21, 15, "B")
    cv.poly([(24, 13), (28, 9), (28, 23), (24, 28)], "u")
    hband(cv, 13, 27, R_CAMPHOR, {"B"}, 4, 24)
    for x in range(5, 24):
        for y in range(14, 27):
            if (x * 3 + y) % 9 == 0 and cv.get(x, y) in R_CAMPHOR:
                cv.put(x, y, DARK.get(cv.get(x, y)))
    cv.hl(4, 24, 17, "b")           # lid seam
    cv.hl(4, 24, 16, "T")
    # brass corner guards
    for (x, y, dx, dy) in ((4, 13, 1, 1), (24, 13, -1, 1), (4, 27, 1, -1), (24, 27, -1, -1)):
        cv.pts([(x, y), (x + dx, y), (x + 2 * dx, y), (x, y + dy), (x, y + 2 * dy)], "a")
        cv.put(x + dx, y + dy, "e")
    cv.pts([(8, 9), (9, 9), (27, 9), (28, 10)], "e")
    cv.pts([(28, 22), (27, 23), (28, 23)], "g")
    # lock hasp and lock
    cv.rect(13, 15, 3, 5, "a")
    cv.put(14, 16, "e")
    cv.rect(12, 20, 5, 3, "Y")
    cv.hl(12, 16, 20, "e")
    cv.put(14, 21, "k")
    cv.outline("k")


def relic_master_steelyard(cv, r):
    # lifting cord
    cv.line(11, 2, 11, 8, "r")
    cv.pts([(10, 2), (12, 2), (10, 3), (12, 3)], "q")
    # beam with abstract marks
    cv.hl(3, 29, 8, "h")
    cv.hl(3, 29, 9, "T")
    for x in range(14, 28, 3):
        cv.put(x, 8, "g")
    cv.put(29, 8, "B")
    cv.put(29, 9, "u")
    cv.pts([(3, 8), (3, 9)], "a")
    # pan strings and pan
    for x in (2, 6, 10):
        cv.line(4, 10, x, 20, "P")
    cv.ellipse(6.0, 21.0, 5.5, 1.8, "a")
    dome(cv, 6.0, 21.0, 5.5, 1.8, R_BRASS, only={"a"}, bias=0.15)
    cv.hl(2, 10, 22, "g")
    # sliding weight on its string
    cv.line(22, 10, 22, 14, "P")
    weight = Cv(32, 32)
    weight.ascii(["..VV..", ".VDDV.", ".VDQV.", "VDDQQV", "VDQQQV", ".QQQQ."], 19, 14)
    weight.recolor({"V"}, "D", (19, 14, 21, 20))
    weight.outline("k")
    cv.paste(weight, 0, 0)
    # a loose length of silk cord hanging from the end
    cv.line(28, 10, 27, 15, "R")
    cv.line(27, 15, 29, 18, "r")
    cv.outline("k")


def relic_sun_inkpad(cv, r):
    # lid leaning on the right, painted top facing us
    lid = Cv(32, 32)
    lid.ellipse(24.5, 15.5, 5.0, 9.0, "U")
    lid.ellipse(24.0, 15.5, 4.0, 8.0, "S")
    dome(lid, 24.0, 15.5, 4.0, 8.0, R_PORC, only={"S"}, bias=0.1)
    lid.pts([(24, 11), (23, 12), (25, 12), (24, 13), (22, 15), (26, 16), (24, 18), (23, 19), (25, 19)], "I")
    lid.pts([(24, 12), (24, 19), (23, 15), (25, 15)], "i")
    lid.outline("k")
    cv.paste(lid, 0, 0)
    # round box with red paste
    box = Cv(32, 32)
    box.ellipse(12.0, 18.0, 9.5, 3.5, "S")
    box.rect(3, 18, 19, 6, "S")
    box.ellipse(12.0, 24.0, 9.5, 3.0, "S")
    band(box, 2, 21, R_PORC, {"S"}, 18, 28, bias=0.1)
    box.hl(3, 21, 22, "i")
    box.pts([(6, 24), (10, 25), (14, 25), (18, 24)], "I")
    box.ellipse(12.0, 18.0, 9.5, 3.5, "H")
    box.ellipse(12.0, 18.2, 8.0, 2.6, "r")
    dome(box, 12.0, 18.2, 8.0, 2.6, R_RED, only={"r"}, bias=0.05)
    box.pts([(8, 17), (9, 17), (10, 18)], "E")
    box.pts([(13, 18), (14, 18), (15, 19)], "q")
    box.outline("k")
    cv.paste(box, 0, 0)


def relic_rosewood_abacus(cv, r):
    x0, y0, x1, y1 = 2, 6, 29, 26
    cv.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, "X")
    cv.rect(x0 + 2, y0 + 2, x1 - x0 - 3, y1 - y0 - 3, "K")
    cv.hl(x0, x1, y0, "q")
    cv.vl(x0, y0, y1, "q")
    cv.hl(x0 + 1, x1, y1, "k")
    cv.vl(x1, y0 + 1, y1, "k")
    cv.hl(x0 + 1, x1 - 1, y0 + 1, "X")
    beam = y0 + 7
    rods = list(range(x0 + 4, x1 - 2, 4))
    for rx in rods:
        cv.vl(rx, y0 + 2, y1 - 2, "o")
    cv.hl(x0 + 1, x1 - 1, beam, "q")
    cv.hl(x0 + 1, x1 - 1, beam + 1, "X")
    for i, rx in enumerate(rods):
        up = (i * 5 + 1) % 3 == 0              # upper beads pushed down to the beam on some rods
        for k in range(2):
            by = (beam - 4 + k * 2) if up else (y0 + 2 + k * 2)
            _bead(cv, rx, by, i + k)
        pushed = (i * 3 + 2) % 5                 # lower beads pushed up to the beam on the rest
        for k in range(5):
            by = beam + 2 + k * 2 + (0 if k < pushed else 2)
            if by + 1 < y1 - 1:
                _bead(cv, rx, by, i + k)
    cv.outline("k")


def _bead(cv, x, y, n):
    cv.hl(x - 1, x + 1, y, "X")
    cv.hl(x - 1, x + 1, y + 1, "k")
    cv.put(x - 1, y, "q")
    cv.put(x, y, "E" if n % 3 == 0 else "R")


def relic_old_signboard(cv, r):
    # a split slab: straight top and bottom, broken ends
    outline_pts = [(2, 10), (24, 9), (26, 10), (25, 12), (28, 13), (27, 16), (30, 18), (27, 21), (29, 24),
                   (4, 25), (3, 21), (1, 19), (3, 16), (1, 13)]
    cv.poly(outline_pts, "v")
    hband(cv, 9, 25, R_WOOD[1:], {"v"}, bias=0.05)
    # raised moulding remnant along top and bottom
    cv.hl(2, 25, 11, "b")
    cv.hl(2, 25, 12, "x")
    cv.hl(4, 28, 23, "b")
    cv.hl(4, 28, 22, "x")
    # grain
    for y in (14, 17, 20):
        for x in range(3, 28):
            if (x + y) % 5 and cv.get(x, y) in R_WOOD:
                cv.put(x, y, "w" if (x * y) % 3 else "x")
    # abstract worn gilt strokes (no characters): a dot, a sweep, a hook, a flick
    gilt = [(6, 15), (7, 15), (6, 16),
            (10, 14), (11, 15), (12, 16), (13, 17), (14, 18), (15, 18),
            (18, 14), (18, 15), (19, 16), (19, 17), (18, 18), (17, 19),
            (22, 16), (23, 15), (24, 15)]
    for i, (x, y) in enumerate(gilt):
        cv.put(x, y, "e" if i % 3 else "g")
    cv.pts([(11, 14), (19, 15), (23, 16), (7, 16)], "Y")
    cv.pts([(9, 19), (21, 13)], "g")
    # cracks
    cv.line(26, 13, 22, 15, "k")
    cv.line(3, 17, 6, 18, "k")
    cv.outline("k")


# --------------------------------------------------------------------------- figures (64x48 scenes)
# A figure is drawn on an 18 x 30 sprite, facing right, feet on row 28, body centre column 7,
# outlined in ink, flipped for facing left and pasted into the scene.
# Template roles: h hair, s skin, S skin shade, e eye, c coat, C coat shade, d hem / belt,
# p trousers, P trouser shade, f shoes.

FW, FH = 18, 30
HEADS = {
    "short": ["..hhh..", ".hhhhh.", ".hhsse.", ".hssss.", "..ssS.."],
    "bun": [".hhh...", "hhhhhh.", "hhhsse.", ".hssss.", "..ssS.."],
    "old": ["..hhh..", ".hhhss.", ".hhsse.", ".hssss.", "..sSS.."],
}
TORSO = {
    "jacket": [
        ".....cc.........",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....cccccC......",
        "....dddddd......",
    ],
    "gown": [
        ".....cc.........",
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
    "boy_walk": [                       # a shorter figure (a servant boy)
        "....pppppp......",
        "....pp..ppp.....",
        "...pp....pp.....",
        "...PP....PP.....",
        "..ff.....fff....",
    ],
}
ARMS = {
    "down": (1, 5), "fwd": (4, 0), "give": (4, 2), "low": (3, 4), "hold": (3, 2), "chest": (2, 2),
    "up": (1, -6), "back": (-1, 5), "shoulder": (0, -2),
}


class Look:
    """Colours and kit of one figure."""

    def __init__(self, coat="i", coat2=None, legs="Q", hair="k", skin="N", hat=None, hatc="Q",
                 body="jacket", head="short", shoes="k", hem=None):
        self.coat = coat
        self.coat2 = coat2 or DARK.get(coat, coat)
        self.legs = legs
        self.legs2 = DARK.get(legs, legs)
        self.hair = hair
        self.skin = skin
        self.hat = hat
        self.hatc = hatc
        self.body = body
        self.head = head
        self.shoes = shoes
        self.hem = hem or self.coat2

    def cmap(self):
        return {"h": self.hair, "s": self.skin, "S": DARK.get(self.skin, self.skin), "e": "k",
                "c": self.coat, "C": self.coat2, "d": self.hem, "p": self.legs, "P": self.legs2,
                "f": self.shoes}


def _hat(sp, kind, c, x0, y0):
    d = DARK.get(c, c)
    if kind == "cap":
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.hl(x0 + 1, x0 + 5, y0 + 1, c)
        sp.hl(x0 + 5, x0 + 6, y0 + 1, d)
    elif kind == "fedora":
        sp.hl(x0 + 2, x0 + 4, y0 - 2, c)
        sp.hl(x0 + 1, x0 + 5, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, d)
        sp.hl(x0, x0 + 6, y0 + 1, c)
    elif kind == "skull":                   # melon-skin cap with a red knot
        sp.hl(x0 + 2, x0 + 4, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.put(x0 + 3, y0 - 2, "r")
    elif kind == "straw":                   # wide bamboo hat
        sp.put(x0 + 3, y0 - 2, c)
        sp.hl(x0 + 2, x0 + 4, y0 - 1, c)
        sp.hl(x0 + 1, x0 + 5, y0, c)
        sp.hl(x0 - 1, x0 + 7, y0 + 1, d)
    elif kind == "scarf":                   # head cloth
        sp.hl(x0 + 1, x0 + 4, y0, c)
        sp.hl(x0, x0 + 4, y0 + 1, c)
        sp.vl(x0, y0 + 1, y0 + 4, c)
        sp.put(x0 - 1, y0 + 3, d)


def person(cv, fx, fy, look, legs="stand", arm="down", arm2=None, face=1, drop=0, lean=0, outline="k"):
    """One figure with feet bottom at (fx, fy). Returns scene anchors (hand, hand2, head, top, chest)."""
    sp = Cv(FW, FH)
    cm = look.cmap()
    if look.body == "gown" and legs in ("stand", "walk"):
        legs = {"stand": "gown", "walk": "gown_walk"}[legs]
    lrows = LEGS[legs]
    ly = 28 - len(lrows) + 1
    top = ly - 12 + drop
    ty = top + 5
    sh_n = (8 + lean, ty + 1)
    sh_f = (5 + lean, ty + 1)

    def arm_line(sh, pose, col):
        off = ARMS[pose] if isinstance(pose, str) else pose
        hx, hy = sh[0] + off[0], sh[1] + off[1]
        tmp = Cv(FW, FH)
        tmp.line(sh[0], sh[1], hx, hy, "1")
        for yy in range(FH):
            for xx in range(FW):
                if tmp.a[yy][xx]:
                    sp.put(xx, yy, col if sp.a[yy][xx] is not None else look.coat)
        sp.put(hx, hy, look.skin)
        return (hx, hy)

    hand_f = arm_line(sh_f, arm2, look.coat2) if arm2 is not None else None
    sp.ascii(lrows, 0, ly, cm)
    sp.ascii(TORSO["gown" if look.body == "gown" else "jacket"], lean, ty, cm)
    sp.ascii(HEADS[look.head], 4 + lean, top, cm)
    if look.hat:
        _hat(sp, look.hat, look.hatc, 4 + lean, top)
    hand_n = arm_line(sh_n, arm, look.coat2) if arm else None
    if outline:
        sp.outline(outline)
    ox, oy = fx - 7, fy - 28
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
    return {"hand": tr(hand_n), "hand2": tr(hand_f), "head": tr((7 + lean, top + 2)), "top": oy + top,
            "chest": tr((7 + lean, ty + 2))}


def bundle(cv, x, y, c="I", w=6, h=5):
    """A cloth-wrapped bundle (包袱) hanging from (x, y): knot on top, folds on the body."""
    sp = Cv(w + 4, h + 4)
    sp.rect(1, 2, w, h, c)
    sp.pts([(1, 2), (w, 2), (1, h + 1), (w, h + 1)], None)
    sp.pts([(w // 2, 0), (w // 2 + 1, 0), (w // 2, 1), (w // 2 + 1, 1), (w // 2 - 1, 1)], DARK.get(c, c))
    for yy in range(3, h + 1):
        sp.put(1 + (yy * 2) % max(1, w - 1), yy, LIGHT.get(c, c))
    sp.hl(2, w - 1, h + 1, DARK.get(c, c))
    sp.outline("k")
    cv.paste(sp, x - (w // 2 + 1), y - 1)


def cloth_bag(cv, x, y, c="P", w=5, h=4):
    sp = Cv(w + 2, h + 4)
    sp.line(1, 2, w // 2 + 1, 0, DARK.get(c, c))
    sp.line(w // 2 + 1, 0, w, 2, DARK.get(c, c))
    sp.rect(1, 2, w, h, c)
    sp.hl(1, w, 2, LIGHT.get(c, c))
    sp.hl(1, w, h + 1, DARK.get(c, c))
    sp.outline("k")
    cv.paste(sp, x - (w // 2 + 1), y - 1)


def ticket(cv, x, y):
    cv.rect(x, y, 3, 4, "p")
    cv.put(x + 1, y + 2, "r")
    cv.put(x + 2, y, "P")
    cv.pts([(x - 1, y), (x - 1, y + 3), (x + 3, y + 4)], "k")


# --------------------------------------------------------------------------- scenery helpers


def interior(cv, r, floor_y=40):
    """Back wall of the shop: plaster with stains, a beam on top, a plank floor."""
    cv.vgrad(0, 0, cv.w, floor_y, ["T", "P", "P", "T"])
    for _ in range(26):
        x, y = r.randrange(cv.w), r.randrange(4, floor_y)
        if cv.get(x, y) in ("P", "T"):
            cv.put(x, y, "t")
    cv.rect(0, 0, cv.w, 4, "w")
    cv.hl(0, cv.w - 1, 4, "x")
    cv.hl(0, cv.w - 1, 0, "v")
    cv.rect(0, floor_y, cv.w, cv.h - floor_y, "v")
    for y in range(floor_y, cv.h):
        for x in range(cv.w):
            if (x + (y - floor_y) * 7) % 11 == 0:
                cv.put(x, y, "w")
    cv.hl(0, cv.w - 1, floor_y, "x")


def lattice_window(cv, x, y, w, h):
    cv.rect(x, y, w, h, "p")
    for xx in range(x, x + w, 3):
        cv.vl(xx, y, y + h - 1, "b")
    for yy in range(y, y + h, 3):
        cv.hl(x, x + w - 1, yy, "b")
    cv.rect(x - 1, y - 1, w + 2, 1, "w")
    cv.rect(x - 1, y + h, w + 2, 1, "w")
    cv.vl(x - 1, y - 1, y + h, "w")
    cv.vl(x + w, y - 1, y + h, "w")


def shelves(cv, r, x, y, w, rows=3, step=8):
    """Wall shelves with goods: boxes, jars, a vase, rolled cloth."""
    cv.rect(x, y, w, rows * step + 1, "x")
    for k in range(rows + 1):
        cv.hl(x, x + w - 1, y + k * step, "u")
        if k < rows:
            cv.hl(x, x + w - 1, y + k * step + 1, "k")
    cv.vl(x, y, y + rows * step, "w")
    cv.vl(x + w - 1, y, y + rows * step, "w")
    goods = [("jar", "S"), ("box", "B"), ("vase", "I"), ("roll", "r"), ("box", "Y"), ("jar", "J"),
             ("roll", "i"), ("vase", "S")]
    for k in range(rows):
        base = y + (k + 1) * step - 1
        gx = x + 2
        while gx < x + w - 4:
            kind, c = goods[r.randrange(len(goods))]
            if kind == "jar":
                cv.rect(gx, base - 3, 3, 4, c)
                cv.put(gx + 1, base - 4, DARK.get(c, c))
                cv.put(gx, base - 3, LIGHT.get(c, c))
                gx += 5
            elif kind == "box":
                cv.rect(gx, base - 2, 4, 3, c)
                cv.hl(gx, gx + 3, base - 2, LIGHT.get(c, c))
                gx += 6
            elif kind == "vase":
                cv.rect(gx + 1, base - 5, 1, 2, c)
                cv.rect(gx, base - 3, 3, 4, c)
                cv.put(gx, base - 3, LIGHT.get(c, c))
                gx += 5
            else:
                cv.rect(gx, base - 1, 5, 2, c)
                cv.put(gx + 4, base - 1, DARK.get(c, c))
                gx += 7


def counter_top(cv, y, x0=0, x1=None):
    """The pawnshop counter in the foreground, top edge lit."""
    x1 = cv.w - 1 if x1 is None else x1
    cv.rect(x0, y, x1 - x0 + 1, cv.h - y, "w")
    cv.hl(x0, x1, y, "B")
    cv.hl(x0, x1, y + 1, "u")
    cv.hl(x0, x1, y + 2, "x")
    for x in range(x0, x1 + 1, 9):
        cv.vl(x, y + 3, cv.h - 1, "x")
        cv.vl(x + 1, y + 3, cv.h - 1, "v")


def street_ground(cv, y0, r):
    cv.rect(0, y0, cv.w, cv.h - y0, "t")
    for y in range(y0, cv.h):
        for x in range(cv.w):
            if (y - y0) % 4 == 0 or (x + ((y - y0) // 4) * 5) % 9 == 0:
                cv.put(x, y, "o")
    for _ in range(12):
        x, y = r.randrange(cv.w), r.randrange(y0 + 1, cv.h)
        cv.put(x, y, "T")
    cv.hl(0, cv.w - 1, y0, "b")


def sky(cv, y1, ramp=("M", "A", "A", "h")):
    cv.vgrad(0, 0, cv.w, y1, list(ramp))


# --------------------------------------------------------------------------- illus.ky 64x48


def ky_traveling_buyers(cv, r):
    interior(cv, r, 40)
    shelves(cv, r, 38, 7, 24, rows=3, step=9)
    lattice_window(cv, 5, 9, 12, 10)
    a = Look(coat="D", legs="Q", hat="fedora", hatc="Q", body="gown")
    b = Look(coat="u", coat2="b", legs="w", hat="cap", hatc="v", hair="x")
    pa = person(cv, 18, 44, a, legs="stand", arm=(5, -2), arm2="down")     # points at the shelf
    pb = person(cv, 29, 45, b, legs="stand", arm="low", arm2="hold")
    cloth_bag(cv, pa["hand2"][0], pa["hand2"][1] + 1, "P")
    bundle(cv, pb["hand"][0] + 1, pb["hand"][1] + 1, "i", 5, 4)
    counter_top(cv, 45, 0, 63)


def ky_needy_neighbors(cv, r):
    sky(cv, 12)
    # shopfront: wall, eaves, the dark door, a hanging sign board without characters
    cv.rect(0, 8, 64, 34, "P")
    cv.rect(0, 6, 64, 3, "Q")
    cv.hl(0, 63, 9, "k")
    for x in range(0, 64, 3):
        cv.put(x, 7, "V")
    cv.rect(38, 14, 20, 28, "x")
    cv.rect(40, 16, 16, 26, "K")
    cv.vl(48, 16, 41, "x")
    cv.rect(39, 13, 22, 1, "w")
    cv.pts([(46, 28), (50, 28)], "g")
    cv.rect(30, 14, 5, 14, "w")          # vertical shop sign, plain board
    cv.rect(31, 15, 3, 12, "q")
    cv.vl(32, 16, 25, "r")
    street_ground(cv, 42, r)
    looks = [Look(coat="I", legs="Q", head="bun", hair="k"),
             Look(coat="t", coat2="o", legs="b", hair="Q", hat="scarf", hatc="H"),
             Look(coat="B", legs="w", head="old", hair="m")]
    xs = (34, 22, 10)
    for k, (lk, x) in enumerate(zip(looks, xs)):
        p = person(cv, x, 45 - (k % 2), lk, legs="stand", arm="hold", arm2="chest", lean=1 if k == 0 else 0)
        bundle(cv, p["hand"][0], p["hand"][1], ("i", "j", "D")[k], 6, 5)


def ky_junk_runners(cv, r):
    sky(cv, 20, ("h", "N", "N", "p"))
    # village wall and a roof line behind
    cv.rect(0, 18, 64, 24, "T")
    cv.rect(0, 15, 64, 4, "Q")
    for x in range(0, 64, 2):
        cv.put(x, 16, "V")
    cv.hl(0, 63, 19, "k")
    for _ in range(30):
        x, y = r.randrange(64), r.randrange(20, 41)
        cv.put(x, y, "t" if r.randrange(2) else "P")
    street_ground(cv, 41, r)
    man = Look(coat="t", coat2="o", legs="b", hat="straw", hatc="T", skin="N", shoes="w")
    p = person(cv, 31, 45, man, legs="walk", arm="shoulder", arm2="fwd")
    # carrying pole across the shoulder, two baskets on ropes
    sx, sy = p["hand"][0], p["hand"][1]
    cv.line(13, sy + 1, 50, sy - 1, "B")
    cv.line(13, sy + 2, 50, sy, "u")
    for bx in (15, 48):
        cv.line(bx - 3, sy + 2, bx, sy, "P")
        cv.line(bx + 3, sy + 2, bx, sy, "P")
        _basket(cv, bx, sy + 3, r)


def _basket(cv, cx, y, r):
    """A round bamboo basket (箩筐) full of odds and ends."""
    b = Cv(14, 14)
    b.rect(1, 4, 11, 8, "T")
    b.pts([(1, 11), (11, 11)], None)
    for yy in range(5, 12):
        for xx in range(1, 12):
            if b.get(xx, yy) and (xx + yy) % 3 == 0:
                b.put(xx, yy, "t")
    b.hl(1, 11, 4, "P")
    # junk on top: a copper basin rim, a cloth, a broken bowl
    b.hl(2, 7, 3, "s")
    b.hl(3, 6, 2, "g")
    b.rect(7, 1, 4, 3, "D")
    b.put(8, 1, "m")
    b.pts([(5, 3), (6, 3), (5, 2)], "S")
    b.outline("k")
    cv.paste(b, cx - 6, y)


def ky_old_customers(cv, r):
    interior(cv, r, 36)
    # open door behind, daylight
    cv.rect(6, 8, 18, 28, "x")
    cv.rect(8, 10, 14, 26, "h")
    cv.vgrad(8, 10, 14, 26, ["W", "h", "h", "P"])
    cv.rect(8, 30, 14, 6, "t")
    lattice_window(cv, 44, 10, 14, 10)
    old = Look(coat="i", coat2="C", legs="Q", hair="m", head="old", body="gown", hat="skull", hatc="k")
    p = person(cv, 30, 44, old, legs="stand", arm="give", arm2="down", drop=1, lean=1)
    ticket(cv, p["hand"][0], p["hand"][1] - 2)
    counter_top(cv, 40, 36, 63)
    # a ledger and brush on the counter
    cv.rect(46, 38, 8, 2, "p")
    cv.hl(46, 53, 39, "P")
    cv.line(56, 39, 60, 37, "b")


def ky_dockhands(cv, r):
    sky(cv, 24, ("A", "A", "h", "h"))
    # far bank
    cv.rect(0, 22, 64, 3, "D")
    for x in range(0, 64, 4):
        cv.put(x + 1, 21, "m")
    # water
    cv.rect(0, 25, 64, 12, "i")
    for y in range(25, 37):
        for x in range(64):
            if (x * 3 + y * 7) % 13 == 0:
                cv.put(x, y, "I")
            elif (x + y * 5) % 17 == 0:
                cv.put(x, y, "M")
    # moored boat with a mast
    cv.poly([(34, 30), (62, 30), (58, 35), (38, 35)], "w")
    cv.hl(34, 62, 30, "u")
    cv.rect(44, 25, 10, 5, "Q")
    cv.hl(44, 53, 25, "V")
    cv.vl(56, 4, 30, "b")
    cv.vl(57, 4, 30, "x")
    cv.line(56, 5, 40, 30, "t")
    # stone quay in front
    cv.rect(0, 37, 64, 11, "o")
    for y in range(37, 48):
        for x in range(64):
            if (y - 37) % 4 == 0 or (x + ((y - 37) // 4) * 6) % 11 == 0:
                cv.put(x, y, "t")
    cv.hl(0, 63, 37, "T")
    porter = Look(coat="B", coat2="b", legs="b", skin="P", hair="k", shoes="w")
    boatman = Look(coat="D", legs="Q", hat="straw", hatc="T", skin="P", shoes="w")
    # sack on the porter's far shoulder, behind his head (head of a walking figure at (14, 45): x 14, top row 28)
    sack = Cv(13, 9)
    sack.ellipse(6.0, 4.5, 5.6, 3.5, "P")
    dome(sack, 6.0, 4.5, 5.6, 3.5, R_PAPER, only={"P"})
    sack.pts([(1, 3), (11, 5)], "t")
    sack.pts([(1, 4), (11, 4)], "T")
    sack.outline("k")
    cv.paste(sack, 3, 27)
    person(cv, 14, 45, porter, legs="walk", arm="shoulder", arm2="down", drop=1)
    p2 = person(cv, 30, 46, boatman, legs="stand", arm="up", arm2="hold", face=-1)
    cv.line(p2["hand"][0], p2["hand"][1] - 6, p2["hand"][0] + 2, 46, "B")   # punting pole


def ky_big_households(cv, r):
    sky(cv, 14)
    # a gate tower of a big house: grey wall, tiled eaves, red door with brass rings
    cv.rect(0, 10, 64, 32, "H")
    for y in range(10, 42):
        for x in range(64):
            if (y % 5 == 0) or ((x + (y // 5) * 4) % 10 == 0):
                cv.put(x, y, "U")
    cv.rect(30, 4, 34, 6, "Q")
    for x in range(30, 64, 2):
        cv.put(x, 5, "V")
        cv.put(x + 1, 8, "C")
    cv.hl(29, 63, 9, "k")
    cv.rect(40, 14, 20, 28, "q")
    cv.rect(41, 15, 18, 27, "r")
    cv.vl(50, 15, 41, "q")
    for x in (46, 54):
        cv.ellipse(x + 0.5, 27.5, 1.5, 1.5, "a")
        cv.put(x, 27, "q")
    cv.rect(38, 12, 24, 2, "x")
    cv.rect(36, 40, 28, 2, "U")
    street_ground(cv, 42, r)
    steward = Look(coat="m", coat2="D", legs="Q", hair="k", body="gown", hat="skull", hatc="k")
    boy = Look(coat="i", legs="Q", hair="k", skin="N", shoes="k")
    person(cv, 27, 45, steward, legs="walk", arm="chest", arm2="back")
    pb = person(cv, 12, 46, boy, legs="boy_walk", arm="hold", arm2="down")
    bundle(cv, pb["hand"][0] + 1, pb["hand"][1], "I", 7, 5)


# --------------------------------------------------------------------------- registry and driver

DRAWERS = {
    "prop.curio": prop_curio,
    "prop.relic.cat_bowl": relic_cat_bowl,
    "prop.relic.stub_box": relic_stub_box,
    "prop.relic.blue_curtain": relic_blue_curtain,
    "prop.relic.oilpaper_umbrella": relic_oilpaper_umbrella,
    "prop.relic.old_almanac": relic_old_almanac,
    "prop.relic.chen_mortar": relic_chen_mortar,
    "prop.relic.hu2_pipe": relic_hu2_pipe,
    "prop.relic.camphor_chest": relic_camphor_chest,
    "prop.relic.master_steelyard": relic_master_steelyard,
    "prop.relic.sun_inkpad": relic_sun_inkpad,
    "prop.relic.rosewood_abacus": relic_rosewood_abacus,
    "prop.relic.old_signboard": relic_old_signboard,
    "illus.ky.traveling_buyers": ky_traveling_buyers,
    "illus.ky.needy_neighbors": ky_needy_neighbors,
    "illus.ky.junk_runners": ky_junk_runners,
    "illus.ky.old_customers": ky_old_customers,
    "illus.ky.dockhands": ky_dockhands,
    "illus.ky.big_households": ky_big_households,
}


def base_size(art_id):
    if art_id == "prop.curio":
        return (52, 38)
    if art_id.startswith("prop.relic."):
        return (32, 32)
    return (64, 48)


def out_rel(art_id):
    cat, rest = art_id.split(".", 1)
    return "art/ai/%s/%s.png" % (cat, rest)


def manifest_entry(art_id):
    """The data/cards/art/manifest.json entry for this id (ROGUE_V1.md section 12)."""
    cat, rest = art_id.split(".", 1)
    folder = {"prop": "props", "illus": "illus"}[cat]
    w, h = base_size(art_id)
    return {"base": [w, h], "human": "art/cards/%s/%s.png" % (folder, rest), "ai": out_rel(art_id),
            "_provenance": PROVENANCE, "placeholder": "art/_placeholder/cards/%s/%s.png" % (folder, rest)}


def render(art_id):
    w, h = base_size(art_id)
    cv = Cv(w, h)
    DRAWERS[art_id](cv, rng_for(art_id))
    px = cv.pixels()
    assert len(px) == h and all(len(row) == w for row in px), art_id
    opaque = art_id.startswith("illus.") or art_id == "prop.curio"
    for y, row in enumerate(px):
        for x, c in enumerate(row):
            assert c in ALLOWED, (art_id, x, y, c)
            if opaque:
                assert c != CLEAR, ("hole", art_id, x, y)
    if not opaque:
        for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
            assert px[y][x] == CLEAR, ("relic ground must stay transparent", art_id, x, y)
    return px


def png_bytes(px):
    h = len(px)
    w = len(px[0])
    raw = bytearray()
    for row in px:
        raw.append(0)
        for c in row:
            raw.extend(c)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def import_text(rel, out_root):
    """The .png.import sidecar: keep a valid uid already on disk (out root, then repo), else the deterministic one."""
    uid = ac.read_import_uid(os.path.join(out_root, rel + ".import")) or ac.read_import_uid(
        os.path.join(ROOT, rel + ".import")) or ac.deterministic_godot_uid(rel)
    return ac.render_png_import(rel, uid)


def scaled(px, k, ground=(0x80, 0x78, 0x6C, 255)):
    out = []
    for row in px:
        big = []
        for c in row:
            big.extend([c if c[3] else ground] * k)
        for _ in range(k):
            out.append(list(big))
    return out


def build_sheet(ids, images, path, k=6):
    cell_w, cell_h = 64 * k + 8, 48 * k + 8
    cols = 4
    rows = (len(ids) + cols - 1) // cols
    sheet = [[(0x80, 0x78, 0x6C, 255)] * (cols * cell_w) for _ in range(rows * cell_h)]
    for n, aid in enumerate(ids):
        big = scaled(images[aid], k)
        ox = (n % cols) * cell_w + 4
        oy = (n // cols) * cell_h + 4
        for y, row in enumerate(big):
            sheet[oy + y][ox:ox + len(row)] = row
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png_bytes(sheet))


def palette_check():
    """Exit 1 if a key of PAL is gone from palette.dev.json; note drifted values."""
    doc = ac.load_json(os.path.join(ROOT, ac.PALETTE_DEV))
    colors = doc.get("colors", {})
    bad = 0
    for ch in sorted(PAL):
        key, hx = PAL[ch]
        if key not in colors:
            print("PALETTE MISSING %s (%s)" % (key, ch))
            bad += 1
        elif colors[key].lower() != hx.lower():
            print("NOTE: palette %s is %s now, this batch keeps %s" % (key, colors[key], hx))
    print("PALETTE %s %d keys" % ("FAILED" if bad else "OK", len(PAL)))
    return 1 if bad else 0


def main(argv):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--out", default=ROOT)
    p.add_argument("--only", default="")
    p.add_argument("--check", action="store_true")
    p.add_argument("--force", action="store_true")
    p.add_argument("--zoom", default="")
    p.add_argument("--sheet", default="")
    p.add_argument("--frag", default="")
    p.add_argument("--list", action="store_true")
    p.add_argument("--palette", action="store_true")
    a = p.parse_args(argv)
    if a.palette:
        return palette_check()
    ids = sorted(i for i in DRAWERS if i.startswith(a.only))
    if a.list:
        for i in ids:
            print(i, out_rel(i))
        return 0
    out_root = os.path.abspath(a.out)
    images = {}
    bad = 0
    for aid in ids:
        px = render(aid)
        images[aid] = px
        data = png_bytes(px)
        rel = out_rel(aid)
        path = os.path.join(out_root, rel)
        imp = import_text(rel, out_root)
        if a.check:
            if not os.path.isfile(path) or open(path, "rb").read() != data:
                print("DIFF %s" % rel)
                bad += 1
            if not os.path.isfile(path + ".import") or open(path + ".import", encoding="utf-8").read() != imp:
                print("DIFF %s.import" % rel)
                bad += 1
            continue
        if os.path.exists(path) and not a.force and open(path, "rb").read() != data:
            print("SKIP (exists, use --force) %s" % rel)
            bad += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
            f.write(imp)
    if a.zoom:
        os.makedirs(a.zoom, exist_ok=True)
        for aid, px in images.items():
            k = 12 if len(px[0]) <= 32 else 8
            with open(os.path.join(a.zoom, aid + ".png"), "wb") as f:
                f.write(png_bytes(scaled(px, k)))
    if a.sheet:
        build_sheet(ids, images, a.sheet)
    if a.frag:
        frag = {aid: manifest_entry(aid) for aid in sorted(DRAWERS)}
        os.makedirs(os.path.dirname(os.path.abspath(a.frag)), exist_ok=True)
        with open(a.frag, "w", encoding="utf-8") as f:
            json.dump(frag, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
    print("%s %d images%s" % ("CHECK" if a.check else "WROTE", len(ids), (", %d problems" % bad) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
