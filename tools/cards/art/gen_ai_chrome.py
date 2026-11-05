#!/usr/bin/env python3
"""Card-game chrome art (frames, wheel faces, props, two backdrops), drawn in code.

    python3 tools/cards/art/gen_ai_chrome.py [--out=<root>] [--only=<id prefix>] [--check] [--sheet=<png>]

Writes art/ai/<category>/<rest>.png for each id in IDS (id = <category>.<rest>).
Deterministic: each picture's RNG is random.Random(first 8 bytes of sha256(art_id)),
pixels use integer math or fixed float formulas, and PNGs are saved with a fixed zlib
level and no ancillary chunks, so the same script gives byte-identical files.

Colors come from data/cards/theme/palette.dev.json keys (and the v0.4 data/palette.json
names, prefixed "L."), plus integer mixes of those. No text, letters or numbers are drawn.

Frames follow docs/cards/ART_SPEC.md section 3: nine-slice margin 6 on every side; the four
6x6 corners carry the ornament, the edges are flat runs that stretch cleanly, the centre is
one flat colour (card paper; guide_bubble / guide_note keep their own paper keys).
Wheel faces only draw the dial (ring, face, hub); the UI draws the sectors.

--check   regenerate in memory and compare with the files on disk (exit 1 on any difference)
--sheet   write a contact sheet (x3, ids under each picture) to the given path
"""

import argparse
import hashlib
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CLEAR = (0, 0, 0, 0)

FRAME_IDS = (
    "frame.big_fate", "frame.contact", "frame.demand", "frame.estate", "frame.event",
    "frame.fate", "frame.gold", "frame.guide_bubble", "frame.guide_note", "frame.hero",
    "frame.kept", "frame.life", "frame.news", "frame.night", "frame.prison", "frame.self",
    "frame.street",
)
WHEEL_IDS = ("wheel.big", "wheel.fair", "wheel.gamble", "wheel.month")
PROP_IDS = (
    "prop.fortune.char", "prop.fortune.slip", "prop.fortune.tube",
    "prop.letter", "prop.notice", "prop.ticket",
)
BG_IDS = ("bg.prison", "bg.temple")
IDS = FRAME_IDS + WHEEL_IDS + PROP_IDS + BG_IDS

SIZES = {
    "frame.guide_note": (24, 24),
    "frame.hero": (27, 36),
    "prop.fortune.char": (24, 24),
    "prop.fortune.slip": (24, 32),
    "prop.fortune.tube": (16, 32),
    "prop.letter": (24, 32),
    "prop.notice": (24, 32),
    "prop.ticket": (24, 32),
}


def base_size(art_id):
    if art_id in SIZES:
        return SIZES[art_id]
    cat = art_id.split(".", 1)[0]
    return {"frame": (36, 50), "wheel": (120, 120), "bg": (320, 180)}[cat]


def out_rel(art_id):
    cat, rest = art_id.split(".", 1)
    return "art/ai/%s/%s.png" % (cat, rest)


# --------------------------------------------------------------------------- colors

def _hex(h):
    s = h.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def load_colors():
    with open(os.path.join(ROOT, "data", "cards", "theme", "palette.dev.json"), encoding="utf-8") as f:
        dev = json.load(f)["colors"]
    with open(os.path.join(ROOT, "data", "palette.json"), encoding="utf-8") as f:
        old = json.load(f)
    c = {}
    for k, v in dev.items():
        if len(v.lstrip("#")) == 6:
            c[k] = _hex(v)
    for name, v in zip(old["names"], old["colors"]):
        c["L." + name] = _hex(v)
    return c


C = load_colors()


def mix(a, b, num, den):
    """Integer blend: a*(den-num)/den + b*num/den, opaque."""
    k = den - num
    return ((a[0] * k + b[0] * num) // den, (a[1] * k + b[1] * num) // den,
            (a[2] * k + b[2] * num) // den, 255)


def lit(c, num=1, den=3):
    return mix(c, C["lamp"], num, den)


def shade(c, num=1, den=3):
    return mix(c, C["ink"], num, den)


def rng_for(art_id):
    digest = hashlib.sha256(art_id.encode("utf-8")).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def bayer_on(x, y, level):
    """True where an ordered dither of strength level (0..16) puts the second colour."""
    return BAYER[y % 4][x % 4] < level


# --------------------------------------------------------------------------- canvas

class Cv:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), fill)
        self.px = self.im.load()

    def p(self, x, y, c):
        if c is not None and 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x, y, w, h, c):
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px[xx, yy] = c

    def box(self, x, y, w, h, c):
        self.hl(x, x + w - 1, y, c)
        self.hl(x, x + w - 1, y + h - 1, c)
        self.vl(x, y, y + h - 1, c)
        self.vl(x + w - 1, y, y + h - 1, c)

    def hl(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.p(x, y, c)

    def vl(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.p(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.p(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts, c):
        ImageDraw.Draw(self.im).polygon([tuple(p) for p in pts], fill=c)

    def ell(self, x0, y0, x1, y1, c, outline=None):
        ImageDraw.Draw(self.im).ellipse([x0, y0, x1, y1], fill=c, outline=outline)

    def pat(self, x, y, rows, cmap):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in cmap:
                    self.p(x + i, y + j, cmap[ch])

    def dither(self, x, y, w, h, ca, cb, level):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, cb if bayer_on(xx, yy, level) else ca)

    def vgrad(self, x, y, w, h, cols):
        """Banded vertical ramp through cols with 4x4 ordered dither at each step."""
        n = len(cols) - 1
        for yy in range(h):
            f = yy * n * 16 // max(1, h - 1)
            i = min(f // 16, n - 1)
            lv = f - i * 16
            for xx in range(x, x + w):
                self.p(xx, y + yy, cols[i + 1] if bayer_on(xx, y + yy, lv) else cols[i])

    def recolor(self, x, y, w, h, fn):
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px[xx, yy] = fn(xx, yy, self.px[xx, yy])

    def glow(self, cx, cy, rx, ry, strength, tint, num=1, den=3):
        """Dithered elliptical light pool: pixels inside get mixed toward tint."""
        for yy in range(max(0, cy - ry), min(self.h, cy + ry + 1)):
            for xx in range(max(0, cx - rx), min(self.w, cx + rx + 1)):
                d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if d >= 1.0:
                    continue
                lv = int((1.0 - d) * strength)
                if bayer_on(xx, yy, lv):
                    c = self.px[xx, yy]
                    if c[3]:
                        self.px[xx, yy] = mix(c, tint, num, den)

    def flip_x(self):
        self.im = self.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        self.px = self.im.load()


# --------------------------------------------------------------------------- frames
# Every card frame shares one build (the family look of art/ai/frame/person.png):
#   index 0 rim, 1 lit (top/left) or shaded (bottom/right) band pixel, 2 band, 3 inner ink line,
#   4-5 paper; the paper right inside the top and left bands takes the frame's shadow.
# Each edge is the same pixel run along its whole length, so the 6px nine-slice stretches cleanly.
# The 6x6 corners carry a type emblem; the frame colour is the palette key frame_<type>.

def _mitre_full(cv, top, left, bottom, right):
    w, h = cv.w, cv.h
    for i in range(6):
        cv.hl(i, w - 1 - i, i, top[i])
        cv.hl(i, w - 1 - i, h - 1 - i, bottom[i])
        cv.vl(i, i + 1, h - 2 - i, left[i])
        cv.vl(w - 1 - i, i + 1, h - 2 - i, right[i])


def _corners(cv, rows, cmap, which=("tl", "tr", "bl", "br")):
    """Draw a 6x6 top-left pattern on each corner, mirrored for the others."""
    w, h = cv.w, cv.h
    for corner in which:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch not in cmap:
                    continue
                x = i if corner in ("tl", "bl") else w - 1 - i
                y = j if corner in ("tl", "tr") else h - 1 - j
                cv.p(x, y, cmap[ch])


# 6x6 top-left corner emblems ('.' keeps the band underneath; mirrored onto the other corners).
#   k ink, a emblem colour, b emblem detail, h emblem highlight
CORNER = {
    # event: square fret plate (a hollow square in a square)
    "event": ("kkkkkk",
              "khaaak",
              "kakkak",
              "kakkak",
              "kaaaak",
              "kkkkkk"),
    # fate: round silver boss
    "fate": (".kkkk.",
             "khhaak",
             "khaaak",
             "kaabak",
             "kaabbk",
             ".kkkk."),
    # big fate: red lozenge with a gold eye
    "big_fate": ("..kk..",
                 ".kaak.",
                 "kahbak",
                 "kabbak",
                 ".kaak.",
                 "..kk.."),
    # demand: iron angle bracket nailed over the corner
    "demand": ("kkkkkk",
               "khhhhk",
               "khbkkk",
               "khk...",
               "khk...",
               "kkk..."),
    # life: two leaves on a twig
    "life": (".kk...",
             "khak..",
             "kaabkk",
             ".kbkak",
             "..kaak",
             "...kk."),
    # kept: red ribbon wrapped across the corner
    "kept": ("kak...",
             "ahak..",
             "kahak.",
             ".kahak",
             "..kahk",
             "...kk."),
    # estate: brick block
    "estate": ("kkkkkk",
               "khhbhk",
               "kbbbbk",
               "kabaak",
               "kbbbbk",
               "kkkkkk"),
    # night: four-point star
    "night": ("..k...",
              ".kak..",
              "kahak.",
              ".kak..",
              "..k...",
              "......"),
    # street: paper lantern
    "street": (".kkk..",
               "kaaak.",
               "khbak.",
               "kaaak.",
               ".kkk..",
               "..k..."),
    # prison: iron grille
    "prison": ("kkkkkk",
               "kakakk",
               "kakakk",
               "kakakk",
               "kakakk",
               "kkkkkk"),
    # self: jade disc with a hole
    "self": (".kkkk.",
             "khhaak",
             "khkkak",
             "kakkbk",
             "kaabbk",
             ".kkkk."),
    # contact: two linked rings on an indigo plate (h over b at one crossing, b over h at the other)
    "contact": ("khhkkk",
                "hkkhkk",
                "hkkhbk",
                "khbkkb",
                "kkbkkb",
                "kkkbbk"),
    # gold: plum blossom
    "gold": (".kak..",
             "kahak.",
             "ahbha.",
             "kahak.",
             ".kak..",
             "......"),
}

# type -> (band, rim, emblem a, emblem b, emblem highlight)
FRAME_STYLE = {
    "event": ("frame_event", "ink", "L.tan", "ink", "L.lamp_pale"),
    "fate": ("frame_fate", "ink", "mist", "L.wall2", "L.fog"),
    "big_fate": ("frame_big_fate", "scene_void", "seal", "gold", "gold_glow"),
    "demand": ("frame_demand", "ink", "L.silver", "ink", "L.fog"),
    "life": ("frame_life", "ink", "+life_leaf", "good", "+life_hi"),
    "kept": ("frame_kept", "ink", "seal", "seal", "+kept_hi"),
    "estate": ("frame_estate", "ink", "L.wood3", "L.wood2", "L.tan"),
    "night": ("frame_night", "ink", "lamp", "lamp", "paper"),
    "street": ("frame_street", "ink", "seal", "lamp", "L.flame"),
    "prison": ("frame_prison", "scene_void", "L.silver", "ink", "L.fog"),
    "self": ("frame_self", "ink", "+jade_lt", "jade", "+jade_hi"),
    "contact": ("frame_contact", "ink", "paper_old", "mist", "paper"),
    "gold": ("frame_gold", "ink", "seal", "gold_glow", "L.flame"),
}


def _col(key):
    if key.startswith("+"):
        return {
            "+life_leaf": mix(C["good"], C["paper"], 2, 5),
            "+life_hi": mix(C["good"], C["paper"], 3, 5),
            "+kept_hi": mix(C["seal"], C["lamp"], 2, 5),
            "+jade_lt": mix(C["jade"], C["paper"], 2, 5),
            "+jade_hi": mix(C["jade"], C["paper"], 3, 5),
        }[key]
    return C[key]


def card_frame(kind, w, h):
    band_k, rim_k, a_k, b_k, h_k = FRAME_STYLE[kind]
    band = C[band_k]
    rim = C[rim_k]
    paper = C["paper"]
    shadow = C["paper_old"]
    ink = C["ink"]
    hi = mix(band, C["paper"], 2, 5)
    lo = mix(band, ink, 2, 5)
    if kind == "big_fate":
        hi = lo = band
    top = (rim, hi, band, ink, shadow, paper)
    bottom = (rim, lo, band, ink, paper, paper)
    if kind == "big_fate":
        # black lacquer band, a gold rule where the band meets the paper
        top = (rim, band, band, C["gold"], shadow, paper)
        bottom = (rim, band, band, C["gold"], paper, paper)
    elif kind == "gold":
        # bright glow line outside, deeper gold inside, double width
        top = (rim, C["gold_glow"], band, C["gold"], ink, shadow)
        bottom = (rim, band, band, C["gold"], ink, paper)
    elif kind == "prison":
        # iron band with a cold sheen
        top = (rim, C["L.gray"], band, ink, shadow, paper)
        bottom = (rim, band, band, ink, paper, paper)
    cv = Cv(w, h)
    cv.rect(0, 0, w, h, paper)
    _mitre_full(cv, top, top, bottom, bottom)
    cmap = {"k": ink, "a": _col(a_k), "b": _col(b_k), "h": _col(h_k)}
    if kind == "night":
        cmap["k"] = mix(band, ink, 1, 2)
    if kind == "kept":
        cmap["k"] = C["L.dkred"]
    if kind == "contact":
        cmap["k"] = mix(band, ink, 1, 2)
    _corners(cv, CORNER[kind], cmap)
    return cv


def draw_frame(art_id, rng):
    kind = art_id.split(".", 1)[1]
    w, h = base_size(art_id)
    if kind == "guide_bubble":
        return _guide_bubble(w, h)
    if kind == "guide_note":
        return _guide_note(w, h)
    if kind == "hero":
        return _hero_frame(w, h)
    if kind == "news":
        return _news_frame(w, h)
    return card_frame(kind, w, h)


def _news_frame(w, h):
    """News: newsprint double rule (grey band + thin ink rule) and a dog-eared top-right corner."""
    band = C["frame_news"]
    paper = C["paper"]
    ink = C["ink"]
    gap = mix(C["paper"], band, 1, 3)
    hi = mix(band, C["paper"], 2, 5)
    lo = mix(band, ink, 2, 5)
    top = (ink, hi, band, gap, ink, C["paper_old"])
    bottom = (ink, lo, band, gap, ink, paper)
    cv = Cv(w, h)
    cv.rect(0, 0, w, h, paper)
    _mitre_full(cv, top, top, bottom, bottom)
    # printer's corner block: solid square with a light dot
    sq = ("kkkkk.",
          "khmmk.",
          "kmmmk.",
          "kmmmk.",
          "kkkkk.",
          "......")
    _corners(cv, sq, {"k": ink, "m": band, "h": hi}, which=("tl", "bl", "br"))
    # dog-ear: the top-right corner folded down; outside the fold is transparent
    # (the missing triangle above the crease is transparent; the flap lies below it)
    fold = ("kxxxxx",
            "kkxxxx",
            "kfkxxx",
            "kffkxx",
            "kfffkx",
            "kkkkkk")
    fmap = {"x": CLEAR, "k": ink, "f": C["paper_old"]}
    for j, row in enumerate(fold):
        for i, ch in enumerate(row):
            cv.p(w - 6 + i, j, fmap[ch])
    return cv


def _guide_bubble(w, h):
    bub = C["guide_bubble"]
    ink = C["guide_ink"]
    warm = mix(C["guide_bubble"], C["paper_old"], 2, 3)
    sh = C["ink_soft"]
    cv = Cv(w, h)
    cv.rect(0, 0, w, h, bub)
    # Edge profiles (outside -> inside). Drop shadow sits outside the ink on bottom/right.
    top = (ink, bub, warm, bub, bub, bub)
    left = top
    bottom = (sh, ink, bub, warm, bub, bub)
    right = bottom
    _mitre_full(cv, top, left, bottom, right)
    tl = ("xxxkkk",
          "xkkbbb",
          "xkbbww",
          "kbbwbb",
          "kbwbbb",
          "kbwbbb")
    tr = ("kkkxxx",
          "bbbkkx",
          "wbbbkx",
          "bwbbbk",
          "bbwbbk",
          "bbwbks")
    bl = ("kbbwbb",
          "kbbwbb",
          "xkbbwb",
          "xkkbbb",
          "xxskkk",
          "xxxsss")
    br = ("bbwbks",
          "bwbbks",
          "wbbkks",
          "bbkksx",
          "kkkssx",
          "sssxxx")
    cmap = {"x": CLEAR, "k": ink, "b": bub, "w": warm, "s": sh}
    for rows, ox, oy in ((tl, 0, 0), (tr, w - 6, 0), (bl, 0, h - 6), (br, w - 6, h - 6)):
        cv.pat(ox, oy, rows, cmap)
    return cv


def _guide_note(w, h):
    """Annotation slip pinned to the scene: paper, red margin rule, red pin, dog-ear."""
    note = C["guide_note"]
    edge = C["ink_soft"]
    shadow = mix(note, C["paper_old"], 2, 3)
    rule = C["seal"]
    cv = Cv(w, h)
    cv.rect(0, 0, w, h, note)
    top = (edge, note, note, note, note, note)
    left = (edge, note, note, rule, note, note)
    bottom = (edge, shadow, note, note, note, note)
    right = (edge, shadow, note, note, note, note)
    _mitre_full(cv, top, left, bottom, right)
    # keep the red rule running through the left corners
    for y in range(1, h - 1):
        cv.p(3, y, rule)
    # pin (top-left)
    pin = ("......",
           "...kk.",
           "..kaak",
           "..kabk",
           "...kk.",
           "....s.")
    cv.pat(0, 0, pin, {"k": C["ink"], "a": C["seal"], "b": C["lamp"], "s": shadow})
    # dog-ear (top-right)
    fold = ("xxxxxk",
            "xxxxkf",
            "xxxkff",
            "xxkfff",
            "xkffff",
            "kkkkkk")
    fold = ("xxxxxk", "xxxxke", "xxxkfe", "xxkffe", "xkfffe", "keeeee")
    cv.pat(w - 6, 0, fold, {"x": CLEAR, "k": edge, "f": C["paper_old"], "e": edge})
    return cv


def _hero_frame(w, h):
    """27x36 hero frame (x4 on screen): thin bright ring, clear centre.

    The hero bar draws its own dark panel and cream labels (name, stats) inside the frame,
    so the centre and the two inner ring rows stay transparent, like the placeholder."""
    clear = (0, 0, 0, 0)
    ring = C["hero_ring"]
    gold = C["gold"]
    ink = C["ink"]
    top = (ink, ring, gold, ink, clear, clear)
    left = top
    bottom = (ink, gold, gold, ink, clear, clear)
    right = bottom
    cv = Cv(w, h)
    _mitre_full(cv, top, left, bottom, right)
    stud = ("kkkk..",
            "kabk..",
            "kbgk..",
            "kkkk..",
            "......",
            "......")
    _corners(cv, stud, {"k": ink, "a": C["lamp"], "b": ring, "g": gold})
    return cv


# --------------------------------------------------------------------------- wheels
# 120x120 dial, transparent outside radius 60 (the face rotates while it spins).
# Only the dial is drawn: outer rim with beads, a decorated band, a plain face and the hub.
# No sector lines and no marks that could be counted as sectors (the UI draws the sectors).

WHEEL_STYLE = {
    # rim, rim beads (a, b alternate), band, band dots, face, face line, hub, hub centre
    "month": ("indigo", "paper", "paper", "+indigo_dk", "paper", "paper_old", "+indigo_lt",
              "L.gold", "indigo"),
    "big": ("frame_big_fate", "gold", "gold_glow", "seal", "gold", "wood", "wood_mid",
            "gold", "seal"),
    "fair": ("jade", "seal", "lamp", "seal", "paper", "paper", "paper_old", "L.gold", "seal"),
    "gamble": ("seal", "L.gold", "L.gold", "ink", "L.gold", "paper_old", "L.paper_old",
               "ink", "L.gold"),
}


def _wcol(key):
    if key.startswith("+"):
        return {
            "+indigo_dk": mix(C["indigo"], C["ink"], 1, 2),
            "+indigo_lt": mix(C["indigo"], C["paper"], 1, 3),
        }[key]
    return C[key]


def draw_wheel(art_id, rng):
    kind = art_id.split(".", 1)[1]
    (rim_k, bead_a_k, bead_b_k, band_k, dot_k, face_k, line_k, hub_k, hubc_k) = WHEEL_STYLE[kind]
    rim, bead_a, bead_b = _wcol(rim_k), _wcol(bead_a_k), _wcol(bead_b_k)
    band, dot, face, fline = _wcol(band_k), _wcol(dot_k), _wcol(face_k), _wcol(line_k)
    hub, hubc = _wcol(hub_k), _wcol(hubc_k)
    ink = C["ink"]
    w, h = 120, 120
    cv = Cv(w, h)
    rim_hi = mix(rim, C["paper"], 1, 4)
    rim_lo = mix(rim, ink, 1, 3)
    band_hi = mix(band, C["paper"], 1, 5)
    band_lo = mix(band, ink, 1, 4)
    face_sh = mix(face, ink, 1, 7)

    def r2(r):
        return int(round(4 * r * r))

    def tone(x, y, s, lo, mid, hi):
        """Three tones with short dithered steps between them (s = lit side, -1..1)."""
        if s > 0.65:
            return hi
        if s > 0.35:
            return hi if bayer_on(x, y, int((s - 0.35) / 0.3 * 16)) else mid
        if s > -0.35:
            return mid
        if s > -0.65:
            return lo if bayer_on(x, y, int((-0.35 - s) / 0.3 * 16)) else mid
        return lo

    for y in range(h):
        for x in range(w):
            X = 2 * x - 119
            Y = 2 * y - 119
            d2 = X * X + Y * Y
            if d2 > r2(60):
                continue
            r = math.sqrt(d2) / 2.0 if d2 else 0.5
            # light from upper left: positive = lit side
            s = -(X + Y) / (2.0 * r * 1.4142135623730951) if d2 else 0.0
            if d2 > r2(59):
                c = ink
            elif d2 > r2(56):
                c = tone(x, y, s, rim_lo, rim, rim_hi)
            elif d2 > r2(55):
                c = ink
            elif d2 > r2(49):
                c = tone(x, y, s, band_lo, band, band_hi)
            elif d2 > r2(48):
                c = ink
            elif d2 > r2(9):
                c = face
                # the raised band shades the face just inside its upper-left edge
                if d2 > r2(45) and s > 0.2 and bayer_on(x, y, int(min(1.0, (s - 0.2) * 2.0) * 10)):
                    c = face_sh
                # two quiet guide circles on the face
                if r2(35.5) < d2 <= r2(36.5) or r2(21.5) < d2 <= r2(22.5):
                    c = fline
            elif d2 > r2(8):
                c = ink
            else:
                c = tone(x, y, s, mix(hub, ink, 1, 3), hub, mix(hub, C["paper"], 2, 5))
                if d2 <= r2(2.5):
                    c = hubc
            cv.p(x, y, c)

    # beads on the rim: many and evenly spaced so they never read as a sector count
    n = 36
    for i in range(n):
        ang = 2.0 * math.pi * i / n
        bx = int(round(59.5 + 57.5 * math.cos(ang)))
        by = int(round(59.5 + 57.5 * math.sin(ang)))
        col = bead_a if i % 2 == 0 else bead_b
        cv.p(bx, by, col)
        cv.p(bx - 1, by, col)
        cv.p(bx, by - 1, col)
        cv.p(bx - 1, by - 1, mix(col, C["paper"], 1, 2) if col != C["paper"] else col)
    # dots around the band
    n = 24
    for i in range(n):
        ang = 2.0 * math.pi * (i + 0.5) / n
        bx = int(round(59.5 + 52.0 * math.cos(ang)))
        by = int(round(59.5 + 52.0 * math.sin(ang)))
        if kind == "month":
            # alternating full and half discs, a moon-phase border
            _phase_dot(cv, bx, by, i, dot, band)
        elif kind == "gamble":
            _coin_dot(cv, bx, by, dot, ink)
        elif kind == "big":
            _diamond_dot(cv, bx, by, dot, C["gold_glow"])
        else:
            _flower_dot(cv, bx, by, dot, C["lamp"] if i % 2 else C["paper"])
    return cv


def _phase_dot(cv, x, y, i, light, dark):
    shapes = (("aa", "aa"), ("ab", "ab"), ("bb", "bb"), ("ba", "ba"))
    rows = shapes[i % 4]
    for j, row in enumerate(rows):
        for k, ch in enumerate(row):
            cv.p(x - 1 + k, y - 1 + j, light if ch == "a" else mix(dark, C["ink"], 1, 2))
    # thin ink cap so each disc reads round
    cv.p(x - 1, y - 2, None)


def _coin_dot(cv, x, y, gold, ink):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        cv.p(x + dx, y + dy, gold)
    cv.p(x, y, ink)


def _diamond_dot(cv, x, y, a, b):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        cv.p(x + dx, y + dy, a)
    cv.p(x, y, b)


def _flower_dot(cv, x, y, a, b):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        cv.p(x + dx, y + dy, a)
    cv.p(x, y, b)


# --------------------------------------------------------------------------- props
# Scene props (x4 on the counter) and fortune-stall pieces. Transparent around the object.
# Writing is only suggested: short brush marks in columns that never form a character.

SOFT_SHADOW = (31, 23, 18, 96)


def _brush_column(cv, x, y0, y1, rng, ink, light=None):
    """A column of brush marks: dots, short drops and ticks, with gaps (unreadable)."""
    y = y0
    while y <= y1:
        kind = rng.randrange(5)
        if kind == 0:
            cv.p(x, y, ink)
            y += 2
        elif kind == 1:
            cv.p(x, y, ink)
            cv.p(x, y + 1, ink)
            y += 3
        elif kind == 2:
            cv.p(x, y, ink)
            cv.p(x + 1, y + 1, ink)
            y += 3
        elif kind == 3:
            cv.p(x - 1, y, ink)
            cv.p(x, y, ink)
            cv.p(x, y + 1, light or ink)
            y += 3
        else:
            y += 1


def _paper_sheet(cv, x, y, w, h, body, edge, shade_col):
    cv.rect(x, y, w, h, body)
    cv.box(x, y, w, h, edge)
    # shadow on the counter, right and bottom
    for yy in range(y + 1, y + h + 1):
        cv.p(x + w, yy, SOFT_SHADOW)
    for xx in range(x + 1, x + w + 1):
        cv.p(xx, y + h, SOFT_SHADOW)
    # lit top-left inner edge, shaded bottom-right inner edge
    cv.hl(x + 1, x + w - 2, y + 1, mix(body, C["paper"], 1, 2))
    cv.vl(x + w - 2, y + 2, y + h - 2, shade_col)
    cv.hl(x + 2, x + w - 2, y + h - 2, shade_col)


def _seal(cv, x, y, size, red, paper):
    """Square seal with a plain ring and centre pip inside (a mark, not a word)."""
    cv.rect(x, y, size, size, red)
    if size >= 5:
        cv.box(x + 1, y + 1, size - 2, size - 2, mix(red, paper, 1, 2))
        cv.p(x + size // 2, y + size // 2, mix(red, paper, 1, 2))
    # worn ink: a couple of paper flecks
    cv.p(x + size - 1, y, mix(red, paper, 1, 3))
    cv.p(x, y + size - 1, mix(red, paper, 1, 3))


def draw_prop(art_id, rng):
    name = art_id.split(".", 1)[1]
    w, h = base_size(art_id)
    cv = Cv(w, h)
    if name == "notice":
        _prop_notice(cv, rng)
    elif name == "ticket":
        _prop_ticket(cv, rng)
    elif name == "letter":
        _prop_letter(cv, rng)
    elif name == "fortune.tube":
        _prop_tube(cv, rng)
    elif name == "fortune.slip":
        _prop_slip(cv, rng)
    elif name == "fortune.char":
        _prop_char(cv, rng)
    else:
        raise SystemExit("no prop painter for %s" % art_id)
    return cv


def _prop_notice(cv, rng):
    """A demand note: rough yellowed sheet, title band, columns of marks, red seal, a tack."""
    body = mix(C["paper"], C["paper_old"], 1, 2)
    edge = C["ink_soft"]
    sh = mix(body, C["L.paper_old"], 1, 2)
    _paper_sheet(cv, 2, 2, 20, 28, body, edge, sh)
    # torn bottom-left corner
    cv.p(2, 29, CLEAR)
    cv.p(3, 29, edge)
    cv.p(2, 28, edge)
    # heavy title marks across the top (three thick blots)
    for x in (6, 11, 16):
        cv.rect(x, 5, 2, 2, C["ink"])
    cv.p(8, 6, C["ink"])
    cv.p(13, 5, C["ink"])
    cv.hl(4, 19, 8, mix(body, C["ink_soft"], 1, 2))
    # body: four columns of brush marks, right to left
    for x in (18, 14, 10, 6):
        _brush_column(cv, x, 10, 24 if x != 6 else 19, rng, C["ink"], C["ink_soft"])
    # red seal over the last column and the date line
    _seal(cv, 4, 21, 5, C["seal"], body)
    cv.p(9, 25, C["seal"])
    # iron tack at the top centre
    cv.rect(11, 1, 2, 2, C["L.gray"])
    cv.p(11, 1, C["L.silver"])
    cv.p(12, 3, SOFT_SHADOW)


def _prop_ticket(cv, rng):
    """A pawn ticket torn off its stub: red printed frame, header band, a cursive amount line."""
    body = C["paper"]
    red = C["seal"]
    red_lt = mix(C["seal"], C["paper"], 2, 5)
    edge = C["ink_soft"]
    sh = C["paper_old"]
    _paper_sheet(cv, 2, 1, 20, 30, body, edge, sh)
    # torn left edge from the stub book (zig-zag)
    for y in range(2, 30):
        if y % 3 == 0:
            cv.p(2, y, CLEAR)
            cv.p(3, y, edge)
    # half of the stub-crossing seal left on the torn edge
    for y in range(13, 19):
        cv.p(3, y, red)
    cv.p(4, 14, red)
    cv.p(4, 15, red)
    cv.p(4, 16, red)
    cv.p(4, 17, red)
    # printed frame (double rule)
    cv.box(5, 3, 15, 26, red)
    cv.box(6, 4, 13, 24, red_lt)
    # header band with three plain studs
    cv.rect(6, 4, 13, 4, red)
    for x in (8, 12, 16):
        cv.p(x, 5, body)
        cv.p(x, 6, body)
    # columns
    cv.vl(10, 8, 27, red_lt)
    cv.vl(15, 8, 27, red_lt)
    cv.hl(6, 18, 12, red_lt)
    # printed small marks in the side columns
    for x in (8, 17):
        for y in range(14, 26, 3):
            cv.p(x, y, mix(C["ink_soft"], body, 1, 3))
    # the clerk's big handwritten entry down the middle column (bold marks, no letters)
    _brush_column(cv, 12, 13, 25, rng, C["ink"], C["ink"])
    _brush_column(cv, 13, 14, 24, rng, C["ink"])
    # shop seal, lower right
    _seal(cv, 16, 23, 3, red, body)


def _prop_letter(cv, rng):
    """A vertical envelope: red address panel, sender line, stamp with postmark, one fold."""
    body = mix(C["paper"], C["paper_old"], 1, 3)
    edge = C["ink_soft"]
    sh = C["paper_old"]
    _paper_sheet(cv, 2, 1, 20, 30, body, edge, sh)
    red = C["seal"]
    # red address panel
    cv.box(8, 11, 7, 18, red)
    cv.vl(9, 12, 27, mix(red, body, 2, 3))
    _brush_column(cv, 11, 13, 26, rng, C["ink"], C["ink_soft"])
    _brush_column(cv, 12, 14, 23, rng, C["ink"])
    # sender line, small, lower left
    _brush_column(cv, 5, 18, 27, rng, C["ink_soft"])
    # stamp, perforated edge, top right
    sx, sy = 15, 2
    cv.rect(sx, sy, 6, 7, C["paper_hi"] if "paper_hi" in C else C["paper"])
    for i in range(6):
        if i % 2 == 0:
            cv.p(sx + i, sy, body)
            cv.p(sx + i, sy + 6, body)
    for j in range(7):
        if j % 2 == 0:
            cv.p(sx, sy + j, body)
            cv.p(sx + 5, sy + j, body)
    cv.rect(sx + 1, sy + 1, 4, 5, C["jade"])
    cv.rect(sx + 2, sy + 2, 2, 2, mix(C["jade"], C["paper"], 1, 2))
    cv.p(sx + 2, sy + 4, C["L.gold"])
    cv.p(sx + 3, sy + 4, C["L.gold"])
    # postmark: a closed ink ring over the stamp's lower-left corner
    ring = (".kkk.",
            "k...k",
            "k...k",
            "k...k",
            ".kkk.")
    cv.pat(12, 5, ring, {"k": C["ink_soft"]})
    # horizontal fold across the middle: crease shadow + lit lip
    for x in range(3, 21):
        if cv.get(x, 15) not in (red,):
            cv.p(x, 15, mix(cv.get(x, 15), C["ink_soft"], 1, 2))
        if cv.get(x, 16) not in (red,):
            cv.p(x, 16, mix(cv.get(x, 16), C["paper"], 1, 2))


def _prop_tube(cv, rng):
    """Bamboo fortune tube with sticks fanned out of the mouth."""
    ink = C["ink"]
    stick = C["L.tan"]
    stick_lt = C["L.lamp_pale"]
    tip = C["seal"]
    # sticks first (behind the rim)
    sticks = ((3, 2, 4, 9), (5, 0, 6, 9), (7, 1, 7, 9), (9, 0, 9, 9), (11, 2, 10, 9), (12, 4, 11, 9))
    for i, (x0, y0, x1, y1) in enumerate(sticks):
        cv.line(x0, y0, x1, y1, stick if i % 2 else stick_lt)
        cv.p(x0, y0, tip if i in (1, 3, 5) else stick)
        if i in (1, 3):
            cv.p(x0, y0 + 1, tip)
    # tube body
    x0, x1 = 2, 13
    for y in range(9, 31):
        for x in range(x0, x1 + 1):
            if x == x0 or x == x1:
                c = ink
            elif x <= x0 + 2:
                c = C["L.wood3"] if x == x0 + 1 else C["L.tan"]
            elif x >= x1 - 2:
                c = C["L.wood2"] if x == x1 - 2 else C["L.wood1"]
            else:
                c = C["L.wood3"]
            cv.p(x, y, c)
    cv.hl(x0, x1, 31, ink)
    cv.hl(x0 + 1, x1 - 1, 30, C["L.wood1"])
    # mouth: dark inside with a lit lip
    cv.hl(x0, x1, 9, ink)
    cv.hl(x0 + 1, x1 - 1, 10, C["L.wood0"])
    cv.hl(x0 + 1, x1 - 1, 11, C["L.lamp_pale"])
    # sticks visible inside the mouth
    for x in (4, 6, 7, 9, 10):
        cv.p(x, 10, stick)
    # bamboo nodes
    for y in (16, 27):
        cv.hl(x0 + 1, x1 - 1, y, C["L.wood1"])
        cv.hl(x0 + 1, x1 - 2, y + 1, C["L.tan"])
    # red paper band with a gold rim around the middle
    cv.hl(x0 + 1, x1 - 1, 19, C["L.gold"])
    for y in (20, 21, 22, 23):
        for x in range(x0 + 1, x1):
            cv.p(x, y, mix(C["seal"], C["paper"], 1, 4) if x <= x0 + 2 else (C["L.dkred"] if x >= x1 - 2 else C["seal"]))
    cv.hl(x0 + 1, x1 - 1, 24, C["L.gold"])
    cv.p(7, 21, C["L.gold"])
    cv.p(8, 22, C["L.gold"])
    cv.p(7, 22, C["lamp"])
    cv.p(8, 21, C["lamp"])


def _prop_slip(cv, rng):
    """One fortune stick, pulled from the tube: red-dipped head, bamboo body, a brush mark."""
    ink = C["ink"]
    x0, x1 = 9, 14
    for y in range(1, 32):
        for x in range(x0, x1 + 1):
            if x == x0 or x == x1:
                c = ink
            elif x == x0 + 1:
                c = C["L.lamp_pale"]
            elif x == x1 - 1:
                c = C["L.wood3"]
            else:
                c = C["L.tan"]
            cv.p(x, y, c)
    # rounded head dipped in red
    cv.p(x0, 1, CLEAR)
    cv.p(x1, 1, CLEAR)
    cv.hl(x0 + 1, x1 - 1, 0, ink)
    cv.p(x0, 2, ink)
    cv.p(x1, 2, ink)
    for y in range(1, 9):
        for x in range(x0 + 1, x1):
            cv.p(x, y, C["seal"] if x != x0 + 1 else mix(C["seal"], C["paper"], 1, 3))
        cv.p(x1 - 1, y, C["L.dkred"])
    cv.hl(x0 + 1, x1 - 1, 9, C["L.dkred"])
    # a sparse column of brush dots and a small seal pip lower down
    for x, y in ((12, 12), (11, 13), (12, 16), (12, 17), (11, 20), (12, 23), (12, 24)):
        cv.p(x, y, ink)
    cv.p(12, 28, C["seal"])
    cv.hl(x0, x1, 31, ink)


def _prop_char(cv, rng):
    """Character reading: a square of red paper with a loose ink mark, and a brush across it."""
    ink = C["ink"]
    red = C["seal"]
    # red paper square, slightly lit along the top-left
    cv.rect(2, 3, 16, 16, red)
    cv.box(2, 3, 16, 16, C["L.dkred"])
    cv.hl(3, 16, 4, mix(red, C["paper"], 1, 3))
    cv.vl(3, 4, 17, mix(red, C["paper"], 1, 3))
    for x in range(3, 19):
        cv.p(x, 19, SOFT_SHADOW)
    for y in range(4, 20):
        cv.p(18, y, SOFT_SHADOW)
    # one big teardrop brush dot (the first stroke of any character, alone it says nothing)
    drop = ("k......",
            ".kk....",
            ".kkkk..",
            "..kkkkk",
            "..kkkkk",
            "...kkk.")
    cv.pat(5, 6, drop, {"k": ink})
    cv.p(8, 8, C["ink_soft"])
    # brush lying across the lower right: bamboo handle, brass ferrule, inked tip
    for i in range(11):
        x = 21 - i
        y = 5 + i
        cv.p(x - 1, y, ink)
        cv.p(x, y, C["L.lamp_pale"])
        cv.p(x + 1, y, C["L.tan"])
        cv.p(x + 2, y, ink)
    cv.hl(20, 23, 4, ink)
    cv.p(22, 5, ink)
    # ferrule
    for x, y in ((10, 16), (11, 16), (9, 17), (10, 17), (11, 17)):
        cv.p(x, y, C["L.gold"])
    cv.p(12, 16, ink)
    # tip, tapering down-left
    for x, y in ((8, 18), (9, 18), (10, 18), (7, 19), (8, 19), (9, 19), (6, 20), (7, 20), (5, 21)):
        cv.p(x, y, ink)


# --------------------------------------------------------------------------- backdrops
# 320x180, x4 on screen. Same stage grid as the counter plates (docs/cards/ART_SPEC.md 12.2):
# wall 0-100, centre opening 112..208 x 8..100, a table front from y=100 that the busts stand
# behind, the area under it to y=180. The centre (customer spot 136..184) is kept quiet.


def _pillar(cv, x, w, y0, y1, base, lit_c, dark_c, edge):
    for y in range(y0, y1):
        for i in range(w):
            if i == 0 or i == w - 1:
                c = edge
            elif i <= w // 4:
                c = lit_c
            elif i >= w - 1 - w // 4:
                c = dark_c
            else:
                c = base
            cv.p(x + i, y, c)


def _bricks(cv, x0, y0, x1, y1, rng, tones, mortar, mask=None):
    """Exposed brick courses (8x4 bricks, running bond) inside an irregular patch."""
    for y in range(y0, y1):
        row = (y - y0) // 4
        for x in range(x0, x1):
            if mask is not None and not mask(x, y):
                continue
            off = 4 if row % 2 else 0
            bx = (x - x0 + off) // 8
            if (y - y0) % 4 == 3 or (x - x0 + off) % 8 == 7:
                cv.p(x, y, mortar)
            else:
                t = tones[(bx * 7 + row * 3 + (bx * row) % 5) % len(tones)]
                cv.p(x, y, t)


def _crack(cv, x, y, steps, rng, col):
    for _ in range(steps):
        cv.p(x, y, col)
        y += 1
        x += rng.choice((-1, 0, 0, 1))


def _smoke(cv, x, y0, y1, rng, col, phase):
    """Rising incense smoke: a thin wavering line that frays as it climbs."""
    y = y0
    t = phase
    while y > y1:
        frac = (y0 - y) / float(max(1, y0 - y1))
        dx = int(round(2.5 * math.sin(t))) + int(frac * 10)
        if rng.random() > frac * 0.8:
            cv.p(x + dx, y, col)
            if frac > 0.4 and rng.random() < 0.5:
                cv.p(x + dx + 1, y, col)
        y -= 1
        t += 0.22


def _lantern(cv, cx, cy, rx, ry, red, red_lit, red_dk, gold, ink):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            d = ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2
            if d > 1.0:
                continue
            c = red
            if x - cx < -rx * 0.35 and y - cy < ry * 0.3:
                c = red_lit
            elif x - cx > rx * 0.45:
                c = red_dk
            if d > 0.8:
                c = red_dk if x > cx else red
            cv.p(x, y, c)
    # ribs
    for x in (cx - rx // 2, cx + rx // 2):
        for y in range(cy - ry + 2, cy + ry - 1):
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 < 0.9:
                cv.p(x, y, red_dk)
    cv.rect(cx - rx // 2, cy - ry - 2, rx + 1, 2, gold)
    cv.hl(cx - rx // 2, cx + rx // 2, cy - ry - 3, ink)
    cv.rect(cx - rx // 2, cy + ry, rx + 1, 2, gold)
    cv.vl(cx, cy + ry + 2, cy + ry + 6, red_dk)
    cv.p(cx - 1, cy + ry + 6, red)
    cv.p(cx + 1, cy + ry + 6, red)


def draw_bg(art_id, rng):
    name = art_id.split(".", 1)[1]
    if name == "prison":
        return _bg_prison(rng)
    if name == "temple":
        return _bg_temple(rng)
    raise SystemExit("no backdrop painter for %s" % art_id)


def _bg_prison(rng):
    W, H = 320, 180
    cv = Cv(W, H, C["ink"])
    ink = C["ink"]
    void = C["scene_void"]
    wall = mix(C["L.wall1"], C["L.wood1"], 1, 2)
    wall_dk = mix(wall, ink, 1, 3)
    wall_lt = mix(wall, C["paper_old"], 1, 5)
    grime = mix(wall, ink, 1, 5)
    iron = C["L.gray"]
    iron_lt = C["L.silver"]
    wood = C["wood"]
    wood_m = C["wood_mid"]
    wood_l = C["L.wood2"]

    # ceiling and beam
    cv.rect(0, 0, W, 9, void)
    cv.rect(0, 6, W, 4, wood)
    cv.hl(0, W - 1, 6, wood_m)
    cv.hl(0, W - 1, 10, ink)
    # plaster wall with a dark grimy skirt
    cv.rect(0, 11, W, 89, wall)
    for y in range(74, 100):
        lv = min(16, (y - 74) * 16 // 18)
        for x in range(W):
            if bayer_on(x, y, lv):
                cv.p(x, y, grime)
    cv.hl(0, W - 1, 11, wall_dk)
    # exposed brick where the plaster fell away
    tones = (mix(C["L.wood2"], C["L.dkred"], 1, 3), mix(C["L.wood1"], C["L.dkred"], 1, 4),
             mix(C["L.wood2"], wall, 1, 2))

    def blob(cx, cy, rx, ry, seed):
        def inside(x, y):
            a = math.atan2((y - cy) / float(ry), (x - cx) / float(rx))
            wob = 0.28 * math.sin(3 * a + seed) + 0.16 * math.sin(7 * a + 2 * seed) + 0.08 * math.sin(13 * a)
            return ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2 < (1.0 + wob) ** 2 * 0.8
        return inside

    patch_a = blob(84, 62, 19, 10, 1.3)
    patch_b = blob(252, 32, 16, 9, 4.1)

    _bricks(cv, 60, 48, 110, 78, rng, tones, wall_dk, patch_a)
    _bricks(cv, 232, 20, 274, 46, rng, tones, wall_dk, patch_b)
    # broken plaster lip around the patches: lit on the lower-right rim, shadowed on the upper-left
    for (x0, y0, x1, y1, inside) in ((58, 46, 112, 80, patch_a), (230, 18, 276, 48, patch_b)):
        for y in range(y0, y1):
            for x in range(x0, x1):
                if inside(x, y):
                    continue
                if inside(x + 1, y) or inside(x, y + 1):
                    cv.p(x, y, wall_dk)
                elif inside(x - 1, y) or inside(x, y - 1):
                    cv.p(x, y, wall_lt)
    # cracks and damp streaks
    _crack(cv, 22, 12, 30, rng, wall_dk)
    _crack(cv, 290, 46, 24, rng, wall_dk)
    _crack(cv, 216, 60, 14, rng, wall_dk)
    for x in range(40, 66):
        for y in range(42, 72):
            if bayer_on(x, y, 3 + (x * 7) % 5) and (x * 13 + y) % 9 < 3:
                cv.p(x, y, grime)

    # high barred window, cold light outside
    wx, wy, ww, wh = 34, 18, 36, 22
    cv.rect(wx - 3, wy - 3, ww + 6, wh + 6, wall_dk)
    cv.rect(wx - 3, wy + wh, ww + 6, 3, wall_lt)
    cv.rect(wx, wy, ww, wh, C["L.indigo1"])
    for y in range(wy, wy + wh):
        for x in range(wx, wx + ww):
            if bayer_on(x, y, 4 + (y - wy) // 3):
                cv.p(x, y, C["L.indigo2"])
    cv.p(wx + 26, wy + 5, C["L.fog"])
    cv.p(wx + 9, wy + 3, C["L.fog"])
    cv.box(wx - 1, wy - 1, ww + 2, wh + 2, ink)
    for bx in range(wx + 3, wx + ww - 1, 6):
        cv.vl(bx, wy, wy + wh - 1, iron_lt)
        cv.vl(bx + 1, wy, wy + wh - 1, iron)
        cv.vl(bx + 2, wy, wy + wh - 1, ink)
    cv.hl(wx, wx + ww - 1, wy + 10, iron)
    cv.hl(wx, wx + ww - 1, wy + 11, ink)
    # the light shaft falling down-right across the wall and onto the table
    shaft = (wx + 1, wy + wh + 3, wx + ww - 1, 118)

    def in_shaft(x, y):
        if y < wy + wh + 3 or y > 116:
            return False
        t = (y - (wy + wh + 3)) * 0.75
        return wx + 2 + t <= x <= wx + ww - 2 + t
    for y in range(wy + wh + 3, 117):
        for x in range(wx, 140):
            if in_shaft(x, y) and bayer_on(x, y, 3 if y < 100 else 4):
                cv.p(x, y, mix(cv.get(x, y), C["mist"], 1, 3))

    # the cell front: timber posts, iron bars, a dark corridor beyond
    cv.rect(116, 14, 88, 86, void)
    # corridor: far wall, a dim lamp, a floor that recedes
    cv.rect(132, 24, 56, 50, C["L.wall0"])
    cv.rect(116, 74, 88, 26, mix(C["L.wall0"], void, 1, 2))
    cv.poly([(116, 100), (132, 74), (188, 74), (204, 100)], mix(C["L.wall0"], C["L.wall1"], 1, 3))
    cv.line(116, 100, 132, 74, void)
    cv.line(203, 100, 188, 74, void)
    cv.vl(131, 24, 74, void)
    cv.vl(188, 24, 74, void)
    cv.rect(178, 34, 4, 5, C["L.flame"])
    cv.p(179, 35, C["lamp"])
    cv.p(180, 36, C["lamp"])
    cv.glow(180, 37, 26, 22, 9, C["L.flame"], 1, 3)
    cv.rect(108, 8, 8, 92, wood)
    cv.rect(204, 8, 8, 92, wood)
    cv.vl(108, 8, 99, wood_l)
    cv.vl(109, 8, 99, wood_m)
    cv.vl(115, 8, 99, ink)
    cv.vl(204, 8, 99, ink)
    cv.vl(205, 8, 99, wood_m)
    cv.vl(211, 8, 99, ink)
    cv.rect(108, 8, 104, 6, wood)
    cv.hl(108, 211, 8, wood_l)
    cv.hl(108, 211, 13, ink)
    for bx in range(119, 203, 9):
        cv.vl(bx, 14, 99, iron_lt)
        cv.vl(bx + 1, 14, 99, iron)
        cv.vl(bx + 2, 14, 99, ink)
    for sy in (26, 78):
        cv.rect(116, sy, 88, 3, iron)
        cv.hl(116, 203, sy, iron_lt)
        cv.hl(116, 203, sy + 3, ink)
        for bx in range(119, 203, 9):
            cv.p(bx + 1, sy + 1, ink)
    # lock plate on the right of the gate
    cv.rect(190, 44, 10, 14, iron)
    cv.box(190, 44, 10, 14, ink)
    cv.hl(191, 198, 45, iron_lt)
    cv.p(195, 49, ink)
    cv.vl(195, 50, 52, ink)
    cv.vl(196, 50, 52, void)

    # plank bed against the right wall, straw mat and a thin blanket
    cv.rect(224, 74, 92, 26, wood)
    cv.hl(224, 315, 74, wood_l)
    cv.hl(224, 315, 75, wood_m)
    cv.hl(224, 315, 80, ink)
    for x in (224, 315):
        cv.vl(x, 74, 99, ink)
    for x in range(226, 314):
        for y in range(68, 74):
            if bayer_on(x, y, 3 + (x % 3)):
                cv.p(x, y, C["L.wood3"])
            else:
                cv.p(x, y, C["L.wood2"])
    cv.hl(226, 313, 68, C["L.wood3"])
    for x in range(228, 312, 5):
        cv.p(x, 71, C["L.wood2"])
    cv.rect(288, 62, 24, 9, C["L.silver"])
    cv.hl(288, 311, 62, C["L.fog"])
    cv.hl(288, 311, 66, C["L.gray"])
    cv.hl(288, 311, 70, ink)
    cv.vl(311, 62, 70, ink)
    # wooden pail by the left wall
    cv.rect(10, 82, 18, 18, wood_m)
    cv.vl(10, 82, 99, ink)
    cv.vl(27, 82, 99, ink)
    cv.vl(11, 83, 99, wood_l)
    for y in (85, 94):
        cv.hl(10, 27, y, iron)
    cv.hl(9, 28, 81, ink)
    cv.hl(10, 27, 82, wood_l)

    # the table the visitor sits across
    cv.rect(0, 100, W, 13, wood_m)
    for y in (104, 108):
        cv.hl(0, W - 1, y, wood)
    for i in range(70):
        x = rng.randrange(W)
        y = rng.choice((101, 102, 105, 106, 109, 110, 111))
        cv.hl(x, x + rng.randrange(3, 9), y, rng.choice((wood, wood_l)))
    cv.hl(0, W - 1, 100, wood_l)
    cv.rect(0, 113, W, 13, wood)
    cv.hl(0, W - 1, 113, ink)
    cv.hl(0, W - 1, 114, wood_m)
    cv.hl(0, W - 1, 125, ink)
    for x in range(0, W, 64):
        cv.vl(x, 114, 124, ink)
    # under the table: dark flagstone floor, legs, a stretcher, a little straw
    floor = mix(C["L.wall0"], wood, 1, 2)
    cv.vgrad(0, 126, W, 54, [void, mix(floor, void, 1, 2), floor])
    for y in (150, 164):
        cv.hl(0, W - 1, y, mix(floor, void, 1, 2))
    for x in range(10, W, 46):
        cv.vl(x, 151, 163, mix(floor, void, 1, 2))
    for x in range(33, W, 46):
        cv.vl(x, 165, 179, mix(floor, void, 1, 2))
    for x0 in (14, 298):
        cv.rect(x0, 126, 9, 54, wood)
        cv.vl(x0, 126, 179, wood_m)
        cv.vl(x0 + 8, 126, 179, ink)
    cv.rect(23, 160, 275, 4, wood)
    cv.hl(23, 297, 160, wood_m)
    cv.hl(23, 297, 164, ink)
    for _ in range(18):
        x = rng.randrange(30, 296)
        y = rng.randrange(166, 178)
        L = rng.randrange(2, 5)
        cv.line(x, y, x + L, y + rng.choice((-1, 0, 1)), C["L.wood2"])

    # candle stub on a chipped dish (left), and its warm pool
    cv.rect(26, 104, 18, 3, C["L.silver"])
    cv.hl(27, 42, 104, C["L.fog"])
    cv.hl(26, 43, 107, ink)
    cv.p(30, 104, C["L.gray"])
    cv.rect(32, 94, 6, 10, C["L.white"])
    cv.vl(37, 94, 103, C["paper_old"])
    cv.vl(31, 94, 103, ink)
    cv.vl(38, 94, 103, ink)
    cv.p(33, 95, C["paper_old"])
    cv.p(36, 96, C["paper_old"])
    cv.vl(35, 92, 93, ink)
    cv.rect(34, 87, 3, 5, C["L.flame"])
    cv.p(35, 86, C["L.flame"])
    cv.vl(35, 88, 90, C["lamp"])
    cv.p(35, 89, C["L.white"])
    cv.glow(35, 96, 46, 26, 12, C["lamp"], 1, 4)
    cv.glow(35, 94, 20, 14, 12, C["lamp"], 1, 4)
    # enamel bowl and chopsticks (right)
    cv.rect(262, 103, 18, 5, C["L.white"])
    cv.hl(261, 280, 102, C["L.indigo2"])
    cv.hl(262, 279, 103, C["L.fog"])
    cv.hl(263, 278, 108, ink)
    cv.p(261, 103, ink)
    cv.p(280, 103, ink)
    cv.p(268, 104, C["L.gray"])
    cv.line(258, 101, 286, 99, C["L.tan"])
    cv.line(258, 102, 286, 100, C["L.wood2"])
    # tin cup
    cv.rect(290, 99, 7, 8, C["L.silver"])
    cv.vl(290, 99, 106, C["L.fog"])
    cv.vl(296, 99, 106, C["L.gray"])
    cv.hl(290, 296, 98, ink)
    cv.hl(290, 296, 107, ink)
    cv.p(297, 101, ink)
    cv.p(298, 102, ink)
    cv.p(297, 104, ink)
    # gloom in the upper corners
    for y in range(11, 60):
        for x in range(W):
            edge = min(x, W - 1 - x)
            lv = max(0, 7 - edge // 6) - (y - 11) // 8
            if lv > 0 and bayer_on(x, y, lv) and cv.get(x, y)[3]:
                cv.p(x, y, mix(cv.get(x, y), ink, 1, 2))
    return cv


def _bg_temple(rng):
    W, H = 320, 180
    cv = Cv(W, H, C["ink"])
    ink = C["ink"]
    void = C["scene_void"]
    red = C["seal"]
    red_lt = mix(C["seal"], C["L.flame"], 1, 3)
    red_dk = C["L.dkred"]
    gold = C["L.gold"]
    gold_dk = C["gold"]
    wood = C["wood"]
    wood_m = C["wood_mid"]
    tile = C["L.wall1"]
    tile_dk = C["L.wall0"]
    tile_lt = C["L.wall2"]
    stone = C["L.wall2"]
    stone_lt = C["mist"]
    smoke = C["L.fog"]

    # --- facade wall behind everything: lattice doors on both sides
    cv.rect(0, 22, W, 78, wood)
    for (x0, x1) in ((10, 96), (224, 310)):
        cv.rect(x0, 26, x1 - x0, 70, wood_m)
        n = 3
        pw = (x1 - x0) // n
        for k in range(n):
            px = x0 + k * pw
            cv.box(px, 26, pw, 70, ink)
            cv.vl(px + 1, 27, 94, C["L.wood2"])
            # lattice: paper behind a grid of thin bars
            lx0, ly0, lx1, ly1 = px + 4, 31, px + pw - 4, 66
            cv.rect(lx0, ly0, lx1 - lx0, ly1 - ly0, C["paper_old"])
            for y in range(ly0, ly1):
                for x in range(lx0, lx1):
                    if (x - lx0) % 5 == 0 or (y - ly0) % 5 == 0:
                        cv.p(x, y, wood_m)
                    elif (x - lx0 + y - ly0) % 10 == 5 and (x - lx0) % 5 == 2:
                        cv.p(x, y, wood_m)
            cv.box(lx0 - 1, ly0 - 1, lx1 - lx0 + 2, ly1 - ly0 + 2, ink)
            # lower panel with an inset
            cv.rect(px + 4, 71, pw - 8, 20, wood)
            cv.box(px + 4, 71, pw - 8, 20, ink)
            cv.box(px + 6, 73, pw - 12, 16, C["L.wood2"])
    # warm light on the paper lattice from inside the hall
    for (cx, cy) in ((53, 48), (267, 48)):
        cv.glow(cx, cy, 44, 24, 6, C["lamp"], 1, 4)

    # --- centre: the dim main hall and the City God on his altar
    cv.rect(112, 22, 96, 78, void)
    cv.rect(116, 30, 88, 70, mix(void, wood, 1, 2))
    # altar platform
    cv.rect(118, 78, 84, 22, wood)
    cv.hl(118, 201, 78, gold_dk)
    cv.hl(118, 201, 79, wood_m)
    cv.rect(124, 84, 72, 12, red_dk)
    cv.box(124, 84, 72, 12, gold_dk)
    # seated figure, in shadow: winged official cap, gold face, dark red robe
    fx, oy = 160, 5
    robe_lt = mix(red_dk, red, 1, 2)
    cv.poly([(fx - 22, 78), (fx - 18, 54 + oy), (fx - 10, 46 + oy), (fx + 10, 46 + oy),
             (fx + 18, 54 + oy), (fx + 22, 78)], red_dk)
    cv.poly([(fx - 22, 78), (fx - 18, 54 + oy), (fx - 10, 46 + oy), (fx - 6, 46 + oy),
             (fx - 12, 56 + oy), (fx - 16, 78)], robe_lt)
    cv.rect(fx - 4, 46 + oy, 8, 10, mix(red_dk, ink, 1, 2))
    cv.hl(fx - 10, fx + 10, 68, gold_dk)
    face = mix(gold, wood, 1, 2)
    cv.rect(fx - 5, 36 + oy, 10, 10, face)
    cv.vl(fx - 5, 36 + oy, 44 + oy, mix(gold, wood, 1, 4))
    cv.vl(fx + 4, 36 + oy, 44 + oy, mix(gold, ink, 1, 2))
    cv.p(fx - 5, 45 + oy, mix(red_dk, ink, 1, 2))
    cv.p(fx + 4, 45 + oy, mix(red_dk, ink, 1, 2))
    cv.p(fx - 3, 39 + oy, ink)
    cv.p(fx + 2, 39 + oy, ink)
    # long black beard
    cv.poly([(fx - 3, 43 + oy), (fx + 2, 43 + oy), (fx + 1, 53 + oy), (fx - 1, 54 + oy),
             (fx - 2, 53 + oy)], ink)
    # official's cap with side wings, edged in dim gold so it reads against the dark hall
    rim = mix(ink, gold, 2, 5)
    cv.rect(fx - 17, 29 + oy, 34, 4, rim)
    cv.rect(fx - 16, 30 + oy, 32, 2, ink)
    cv.rect(fx - 7, 26 + oy, 14, 11, rim)
    cv.rect(fx - 6, 27 + oy, 12, 9, ink)
    cv.hl(fx - 5, fx + 4, 27 + oy, mix(ink, gold, 1, 4))
    cv.hl(fx - 7, fx + 6, 35 + oy, gold_dk)
    # court tablet held before the chest
    cv.rect(fx - 1, 50 + oy, 3, 11, C["paper_old"])
    cv.vl(fx + 1, 50 + oy, 60 + oy, C["L.paper_old"])
    # altar candles and their glow
    for ax in (128, 192):
        cv.rect(ax, 70, 3, 8, red)
        cv.p(ax, 70, red_lt)
        cv.rect(ax, 66, 3, 3, C["L.flame"])
        cv.p(ax + 1, 66, C["lamp"])
        cv.p(ax + 1, 65, C["lamp"])
        cv.hl(ax - 2, ax + 4, 78, gold)
    cv.glow(130, 66, 30, 22, 8, C["lamp"], 1, 4)
    cv.glow(193, 66, 30, 22, 8, C["lamp"], 1, 4)
    # valance across the top of the hall opening
    cv.rect(112, 22, 96, 4, red)
    cv.hl(112, 207, 22, red_lt)
    for x in range(112, 208):
        if (x - 112) % 8 in (0, 7):
            continue
        sag = 1 if (x - 112) % 8 in (1, 6) else 2
        cv.vl(x, 26, 25 + sag, red)
    for x in range(112, 208, 8):
        cv.p(x + 4, 28, gold)
    cv.hl(112, 207, 24, gold)

    # --- pillars (red lacquer, stone drums)
    for (px, pw) in ((-4, 14), (98, 14), (208, 14), (310, 14)):
        _pillar(cv, px, pw, 22, 96, red, red_lt, red_dk, ink)
        cv.rect(px - 2, 94, pw + 4, 6, stone)
        cv.hl(px - 2, px + pw + 1, 94, stone_lt)
        cv.hl(px - 2, px + pw + 1, 99, ink)
    # hanging boards on the inner pillars: black lacquer, gold rim, gold dabs (no characters)
    for bx in (99, 209):
        cv.rect(bx, 34, 12, 52, ink)
        cv.box(bx, 34, 12, 52, gold_dk)
        cv.vl(bx + 1, 35, 84, mix(ink, gold, 1, 4))
        y = 38
        while y < 82:
            k = rng.randrange(3)
            if k == 0:
                cv.rect(bx + 5, y, 2, 2, gold)
                y += 5
            elif k == 1:
                cv.p(bx + 4, y, gold)
                cv.p(bx + 5, y + 1, gold)
                cv.p(bx + 6, y + 2, gold)
                y += 6
            else:
                cv.vl(bx + 6, y, y + 2, gold)
                cv.p(bx + 4, y + 1, gold)
                y += 6

    # --- eave: tile ribs, round tile ends, painted beam, brackets
    cv.rect(0, 0, W, 13, tile)
    for x in range(0, W, 6):
        cv.vl(x, 0, 12, tile_dk)
        cv.vl(x + 1, 0, 12, tile_lt)
    cv.hl(0, W - 1, 12, ink)
    for x in range(3, W, 6):
        cv.rect(x - 2, 12, 5, 4, tile_dk)
        cv.p(x - 1, 12, tile_lt)
        cv.p(x, 13, tile_lt)
        cv.hl(x - 2, x + 2, 16, ink)
    cv.rect(0, 17, W, 6, red_dk)
    cv.hl(0, W - 1, 17, red)
    seg = (C["L.indigo1"], C["jade"], gold_dk, C["jade"])
    for i, x in enumerate(range(0, W, 16)):
        cv.rect(x + 2, 18, 12, 3, seg[i % 4])
        cv.p(x + 7, 19, gold)
        cv.p(x + 8, 19, gold)
    cv.hl(0, W - 1, 22, ink)

    # --- lanterns hung from the eave, and their light
    for lx in (56, 264):
        cv.vl(lx, 23, 27, ink)
        cv.glow(lx, 38, 34, 26, 9, C["lamp"], 1, 4)
        _lantern(cv, lx, 38, 8, 9, red, red_lt, red_dk, gold, ink)
        cv.p(lx - 3, 34, C["lamp"])
    # a string of small lanterns for the fair, across the hall front
    for i, x in enumerate(range(20, 300, 20)):
        if 104 <= x <= 216 or x in (56, 264):
            continue
        cv.p(x, 24 + (i % 2), ink)
        cv.rect(x - 1, 25 + (i % 2), 3, 4, red if i % 3 else C["L.flame"])
        cv.p(x - 1, 25 + (i % 2), red_lt)

    # --- courtyard: bronze incense burner (left), candle rack (right)
    bronze = mix(C["L.gold"], C["wood"], 1, 2)
    bronze_lt = mix(C["L.gold"], C["paper"], 1, 4)
    bronze_dk = mix(C["L.gold"], C["ink"], 2, 3)
    bx, by = 48, 80
    for y in range(by - 10, by + 11):
        for x in range(bx - 24, bx + 25):
            d = ((x - bx) / 24.5) ** 2 + ((y - by) / 10.5) ** 2
            if d <= 1.0:
                c = bronze
                if x < bx - 10 and y < by:
                    c = bronze_lt
                elif x > bx + 12 or y > by + 6:
                    c = bronze_dk
                if d > 0.86:
                    c = ink
                cv.p(x, y, c)
    cv.rect(bx - 26, 68, 53, 4, bronze)
    cv.hl(bx - 26, bx + 26, 68, bronze_lt)
    cv.hl(bx - 26, bx + 26, 72, ink)
    cv.box(bx - 26, 67, 53, 6, ink)
    for ex in (bx - 22, bx + 18):
        cv.box(ex, 60, 5, 8, ink)
        cv.vl(ex + 1, 61, 66, bronze_lt)
    for lx in (bx - 16, bx - 1, bx + 14):
        cv.rect(lx, 90, 3, 10, bronze_dk)
        cv.vl(lx, 90, 99, ink)
    cv.hl(bx - 12, bx + 12, 78, bronze_dk)
    for x in range(bx - 10, bx + 11, 4):
        cv.p(x, 77, bronze_lt)
    for (px, py) in ((bx - 8, 84), (bx + 9, 82), (bx + 2, 87)):
        cv.p(px, py, C["jade"])
        cv.p(px + 1, py, mix(C["jade"], C["paper"], 1, 3))
    # incense sticks bundled in the ash, glowing tips, smoke rising
    for i, sx in enumerate(range(bx - 9, bx + 10, 3)):
        top = 56 + (i * 5) % 7
        cv.vl(sx, top, 67, C["L.dkred"])
        cv.p(sx, top, C["L.flame"])
        cv.p(sx, top - 1, C["lamp"])
    srng = random.Random(7)
    for i, sx in enumerate((bx - 6, bx, bx + 6)):
        _smoke(cv, sx, 54, 24, srng, smoke, i * 1.7)
        _smoke(cv, sx + 1, 52, 30, srng, C["mist"], i * 1.7 + 0.8)
    # candle rack: two iron tiers of red votive candles
    rx0, rx1 = 238, 304
    for ty in (84, 94):
        cv.rect(rx0, ty, rx1 - rx0, 2, C["L.gray"])
        cv.hl(rx0, rx1 - 1, ty, C["L.silver"])
        cv.hl(rx0, rx1 - 1, ty + 2, ink)
    for x in (rx0 + 2, rx1 - 3):
        cv.vl(x, 84, 99, C["L.gray"])
        cv.vl(x + 1, 84, 99, ink)
    for row, ty in enumerate((84, 94)):
        for j, x in enumerate(range(rx0 + 6 + row * 4, rx1 - 4, 8)):
            hgt = 5 + (j * 3 + row) % 4
            cv.rect(x, ty - hgt, 3, hgt, red)
            cv.p(x, ty - hgt, red_lt)
            cv.vl(x + 2, ty - hgt, ty - 1, red_dk)
            cv.p(x + 1, ty - hgt - 1, ink)
            cv.p(x + 1, ty - hgt - 2, C["L.flame"])
            cv.p(x + 1, ty - hgt - 3, C["lamp"])
    cv.glow(271, 82, 44, 26, 10, C["lamp"], 1, 4)

    # --- offering table: wooden top, red frontal with gold bands, stone floor
    cv.rect(0, 100, W, 8, wood_m)
    cv.hl(0, W - 1, 100, C["L.wood2"])
    cv.hl(0, W - 1, 104, wood)
    cv.hl(0, W - 1, 107, ink)
    cloth = mix(red, red_dk, 1, 2)
    cloth_dk = mix(red_dk, ink, 1, 4)
    cv.rect(0, 108, W, 42, cloth)
    for x in range(W):
        for y in range(108, 150):
            if bayer_on(x, y, 4 + ((x // 7) % 3)) and (x % 14) >= 9:
                cv.p(x, y, cloth_dk)
    cv.rect(0, 109, W, 4, gold_dk)
    cv.hl(0, W - 1, 109, gold)
    for x in range(2, W, 6):
        cv.p(x, 111, red_dk)
        cv.p(x + 1, 111, red_dk)
    cv.hl(0, W - 1, 113, red_dk)
    # side panels and a round gold medallion (cloud scroll, not a character)
    for x in (40, 279):
        cv.vl(x, 114, 149, gold_dk)
    mx, my = 160, 131
    for y in range(my - 11, my + 12):
        for x in range(mx - 14, mx + 15):
            d = ((x - mx) / 14.5) ** 2 + ((y - my) / 11.5) ** 2
            if d <= 1.0:
                c = gold_dk if d > 0.8 else cloth_dk
                if 0.45 < d <= 0.6:
                    c = gold
                cv.p(x, y, c)
    flower = ("...g...",
              "..ggg..",
              ".g.g.g.",
              "gggrggg",
              ".g.g.g.",
              "..ggg..",
              "...g...")
    cv.pat(mx - 3, my - 3, flower, {"g": gold, "r": C["seal"]})
    # fringe
    for x in range(W):
        cv.p(x, 148, gold_dk if x % 3 else red_dk)
        if x % 3 == 0:
            cv.p(x, 149, gold_dk)
    cv.hl(0, W - 1, 150, ink)
    # stone floor
    cv.rect(0, 151, W, 29, stone)
    for y in range(151, 180):
        for x in range(W):
            if bayer_on(x, y, (y - 151) // 2):
                cv.p(x, y, tile)
    for y in (158, 168):
        cv.hl(0, W - 1, y, tile_dk)
    for row, (y0, y1) in enumerate(((151, 158), (159, 168), (169, 179))):
        for x in range(row * 14, W, 40 + row * 8):
            cv.vl(x, y0, y1, tile_dk)
    cv.hl(0, W - 1, 151, stone_lt)
    # kneeling cushion peeking out from under the frontal
    for y in range(151, 160):
        for x in range(142, 179):
            d = ((x - 160) / 18.0) ** 2 + ((y - 151) / 8.5) ** 2
            if d <= 1.0:
                c = C["L.wood3"]
                if d > 0.75:
                    c = ink
                elif y < 154 and x < 160:
                    c = C["L.tan"]
                elif y > 156 or x > 170:
                    c = C["L.wood2"]
                cv.p(x, y, c)
    for x in range(147, 175, 4):
        cv.p(x, 154, C["L.wood2"])

    # --- things on the table (left and right; the middle stays clear)
    # plate of oranges
    cv.hl(56, 82, 106, C["L.silver"])
    cv.hl(57, 81, 107, ink)
    for (ox, oy) in ((60, 101), (66, 101), (72, 101), (78, 101), (63, 96), (69, 96), (75, 96), (69, 91)):
        cv.ell(ox - 3, oy - 3, ox + 2, oy + 2, C["L.flame"], ink)
        cv.p(ox - 1, oy - 1, C["lamp"])
    # small incense pot with three sticks
    cv.rect(90, 98, 12, 8, bronze)
    cv.box(90, 98, 12, 8, ink)
    cv.hl(91, 100, 99, bronze_lt)
    for sx in (93, 96, 99):
        cv.vl(sx, 88, 97, C["L.dkred"])
        cv.p(sx, 88, C["L.flame"])
    _smoke(cv, 96, 86, 66, random.Random(11), smoke, 0.5)
    # fortune tube with sticks
    tx = 236
    for i, sx in enumerate(range(tx + 1, tx + 11, 2)):
        cv.vl(sx, 84 + (i * 3) % 4, 92, C["L.tan"])
        if i % 2:
            cv.p(sx, 84 + (i * 3) % 4, red)
    cv.rect(tx, 92, 12, 15, C["L.wood3"])
    cv.box(tx, 92, 12, 15, ink)
    cv.vl(tx + 1, 93, 105, C["L.tan"])
    cv.vl(tx + 10, 93, 105, C["L.wood2"])
    cv.rect(tx + 1, 97, 10, 4, red)
    cv.hl(tx + 1, tx + 10, 97, gold)
    # divination blocks: two red crescents
    for (jx, flip) in ((258, 0), (268, 1)):
        pts = (".rrrr.", "rrrrrr", ".kkkk.") if flip == 0 else (".kkkk.", "rrrrrr", ".rrrr.")
        cv.pat(jx, 102, pts, {"r": red, "k": red_dk})
    # pewter candlesticks with tall red candles at the two ends
    for cx in (20, 296):
        cv.rect(cx - 3, 104, 8, 3, C["L.silver"])
        cv.hl(cx - 3, cx + 4, 107, ink)
        cv.rect(cx, 92, 2, 12, C["L.silver"])
        cv.rect(cx - 1, 76, 4, 16, red)
        cv.vl(cx - 1, 76, 91, red_lt)
        cv.vl(cx + 2, 76, 91, red_dk)
        cv.p(cx, 75, ink)
        cv.rect(cx, 71, 2, 4, C["L.flame"])
        cv.p(cx, 71, C["lamp"])
        cv.p(cx, 70, C["lamp"])
        cv.glow(cx + 1, 74, 22, 16, 9, C["lamp"], 1, 4)
    return cv


# --------------------------------------------------------------------------- dispatch

DRAW = {"wheel": draw_wheel, "prop": draw_prop, "bg": draw_bg}


def render(art_id):
    cat = art_id.split(".", 1)[0]
    rng = rng_for(art_id)
    if cat == "frame":
        cv = draw_frame(art_id, rng)
    else:
        cv = DRAW[cat](art_id, rng)
    want = base_size(art_id)
    if (cv.w, cv.h) != want or cv.im.size != want:
        raise SystemExit("%s drew %s, base is %s" % (art_id, cv.im.size, want))
    return Image.frombytes("RGBA", cv.im.size, cv.im.convert("RGBA").tobytes())


def png_bytes(im):
    import io
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=False, compress_level=9)
    return buf.getvalue()


# --------------------------------------------------------------------------- sheet

GLYPHS = {}


def _sheet(images, path):
    """Contact sheet x3 with ids under each cell (labels use PIL's default bitmap font)."""
    from PIL import ImageFont

    font = ImageFont.load_default()
    k = 3
    pad = 10
    label_h = 14
    rows = []
    row = []
    row_w = 0
    max_w = 1500
    for art_id, im in images:
        cw = max(im.width * k, 8 * len(art_id) // 1 + 4)
        if row and row_w + cw + pad > max_w:
            rows.append(row)
            row, row_w = [], 0
        row.append((art_id, im, cw))
        row_w += cw + pad
    if row:
        rows.append(row)
    sheet_w = max(sum(c[2] + pad for c in r) for r in rows) + pad
    sheet_h = sum(max(c[1].height * k for c in r) + label_h + pad for r in rows) + pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (92, 84, 76, 255))
    d = ImageDraw.Draw(sheet)
    y = pad
    for r in rows:
        x = pad
        rh = max(c[1].height * k for c in r)
        for art_id, im, cw in r:
            big = im.resize((im.width * k, im.height * k), Image.Resampling.NEAREST)
            # checker behind transparency so holes are visible
            for cy in range(0, big.height, 6):
                for cx in range(0, big.width, 6):
                    col = (150, 140, 150, 255) if (cx // 6 + cy // 6) % 2 else (120, 112, 120, 255)
                    d.rectangle([x + cx, y + cy, x + min(cx + 5, big.width - 1), y + min(cy + 5, big.height - 1)], fill=col)
            sheet.alpha_composite(big, (x, y))
            d.text((x, y + rh + 2), art_id, fill=(255, 250, 230, 255), font=font)
            x += cw + pad
        y += rh + label_h + pad
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sheet.save(path)


# --------------------------------------------------------------------------- main

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=ROOT)
    ap.add_argument("--only", default="")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--sheet", default="")
    args = ap.parse_args(argv)
    ids = [i for i in IDS if i.startswith(args.only)]
    bad = 0
    images = []
    for art_id in ids:
        im = render(art_id)
        images.append((art_id, im))
        data = png_bytes(im)
        path = os.path.join(args.out, out_rel(art_id).replace("/", os.sep))
        if args.check:
            if not os.path.isfile(path) or open(path, "rb").read() != data:
                print("DIFF %s" % out_rel(art_id))
                bad += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
    if args.sheet:
        _sheet(images, args.sheet)
    if args.check:
        print("CHECK %s %d ids" % ("FAILED" if bad else "OK", len(ids)))
        return 1 if bad else 0
    print("wrote %d pictures" % len(ids))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
