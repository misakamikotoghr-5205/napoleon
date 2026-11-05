"""Tiny pixel-art helper for the 德厚当 town mockups (self-contained, no repo writes).

    from pix import Cv, C, font_mask
    c = Cv(16, 16); c.rect(0, 0, 16, 16, C.white); c.save("assets/x.png")

C holds the 32 project palette colours (data/palette.json names) plus a few
extras for grass / water / foliage / warm stone. Colours are RGBA tuples.
"""
import json
import os
import random
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ASSETS = os.path.join(REPO, "art", "town")

ZEN = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"   # index 1 = Zen Hei Sharp (bitmap strikes)
UNIFONT = "/usr/share/fonts/opentype/unifont/unifont.otf"


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class _C:
    pass


C = _C()
with open(os.path.join(REPO, "data", "palette.json"), encoding="utf-8") as f:
    _pal = json.load(f)
for _n, _h in zip(_pal["names"], _pal["colors"]):
    setattr(C, _n, hexc(_h))

EXTRA = {
    # foliage / grass
    "g0": "#24361f", "g1": "#35502c", "g2": "#4f7238", "g3": "#6f9446", "g4": "#97b85c", "g5": "#c3d67e",
    # water
    "wa0": "#17303d", "wa1": "#21485a", "wa2": "#2f6175", "wa3": "#4a8597", "wa4": "#7fb4bd", "wa5": "#c4e0dc",
    # warm stone (青石 with a warm bias so the street feels sunny)
    "st0": "#3b3934", "st1": "#56534b", "st2": "#726d62", "st3": "#8f897b", "st4": "#aaa392", "st5": "#c9c1ac",
    # whitewash
    "ww0": "#f2eee2", "ww1": "#e3ddcc", "ww2": "#cdc6b2", "ww3": "#aaa391",
    # roof tiles (cool charcoal)
    "rf0": "#1c1f24", "rf1": "#2c3138", "rf2": "#3f464f", "rf3": "#58616b", "rf4": "#7a838c",
    # misc
    "skinm": "#dcae86", "blush": "#d98b78", "lantern": "#d8432f", "lantern_hi": "#f07a4a",
    "jade": "#3e7a5c", "jade_hi": "#5fa07a", "postgreen": "#2f5e3c", "postgreen_hi": "#4a8558",
    "blue_hi": "#6d8fc4", "dirt0": "#5b4632", "dirt1": "#7a5f43", "dirt2": "#987a58", "dirt3": "#b69a74",
    "tabby0": "#6b4a2a", "tabby1": "#b07a3c", "tabby2": "#e0b070", "pink": "#e6a0a0", "flower": "#e8607a",
    "shadow": "#000000",
}
for _n, _h in EXTRA.items():
    setattr(C, _n, hexc(_h))

CLEAR = (0, 0, 0, 0)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def alpha(col, a):
    return col[:3] + (a,)


_font_cache = {}


def font(size, path=ZEN, index=1):
    key = (path, size, index)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(path, size, index=index)
    return _font_cache[key]


def font_mask(text, size=12, path=ZEN, index=1, spacing=0):
    """Return a 1-bit-ish L mask of text rendered without anti-aliasing, tight bbox."""
    f = font(size, path, index)
    w = int(sum(f.getlength(ch) for ch in text) + spacing * len(text) + 4)
    h = size + 6
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    x = 0
    for ch in text:
        d.text((x, 0), ch, font=f, fill=255)
        x += f.getlength(ch) + spacing
    bb = m.getbbox()
    if bb:
        m = m.crop(bb)
    return m


class Cv:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()

    @staticmethod
    def load(path):
        im = Image.open(path).convert("RGBA")
        c = Cv(im.width, im.height)
        c.img = im
        c.px = im.load()
        return c

    def copy(self):
        c = Cv(self.w, self.h)
        c.img = self.img.copy()
        c.px = c.img.load()
        return c

    # primitives ---------------------------------------------------------
    def pixel(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(col) == 4 and col[3] < 255:
                if col[3] == 0:
                    return
                b = self.px[x, y]
                a = col[3] / 255.0
                if b[3] == 0:
                    self.px[x, y] = col
                else:
                    self.px[x, y] = tuple(int(round(b[i] * (1 - a) + col[i] * a)) for i in range(3)) + (max(b[3], col[3]),)
            else:
                self.px[x, y] = col

    def put(self, x, y, col):
        """Overwrite (no blending)."""
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = col

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x, y, w, h, col):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.pixel(xx, yy, col)

    def clear_rect(self, x, y, w, h):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, CLEAR)

    def frame(self, x, y, w, h, col):
        self.hline(x, x + w - 1, y, col)
        self.hline(x, x + w - 1, y + h - 1, col)
        self.vline(x, y, y + h - 1, col)
        self.vline(x + w - 1, y, y + h - 1, col)

    def hline(self, x0, x1, y, col):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.pixel(x, y, col)

    def vline(self, x, y0, y1, col):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.pixel(x, y, col)

    def line(self, x0, y0, x1, y1, col):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.pixel(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, col, filled=True):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                d = ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2
                if filled and d <= 1.0:
                    self.pixel(x, y, col)
                elif not filled and 0.7 <= d <= 1.15:
                    self.pixel(x, y, col)

    def poly(self, pts, col):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1])) + 1):
                    self.pixel(x, y, col)

    def dither(self, x, y, w, h, col_a, col_b, level=0.5):
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                t = (bayer[yy % 4][xx % 4] + 0.5) / 16.0
                self.pixel(xx, yy, col_b if t < level else col_a)

    def noise(self, x, y, w, h, cols, density, rnd, mask_col=None):
        """Sprinkle random pixels of cols over a region (optionally only where pixel==mask_col)."""
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if rnd.random() < density:
                    if mask_col is not None and self.get(xx, yy)[:3] != mask_col[:3]:
                        continue
                    self.pixel(xx, yy, rnd.choice(cols))

    def outline(self, col=None, diag=False):
        col = col or C.dkbrown
        src = self.img.copy().load()
        nb = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diag:
            nb = nb + ((1, 1), (-1, -1), (1, -1), (-1, 1))
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in nb:
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3] > 128:
                            self.px[x, y] = col
                            break

    def blit(self, other, x, y):
        im = other.img if isinstance(other, Cv) else other
        self.img.alpha_composite(im, (int(x), int(y))) if (x >= 0 and y >= 0 and x + im.width <= self.w and y + im.height <= self.h) else self._blit_clip(im, int(x), int(y))
        self.px = self.img.load()

    def _blit_clip(self, im, x, y):
        sx0, sy0 = max(0, -x), max(0, -y)
        sx1, sy1 = min(im.width, self.w - x), min(im.height, self.h - y)
        if sx1 <= sx0 or sy1 <= sy0:
            return
        part = im.crop((sx0, sy0, sx1, sy1))
        self.img.alpha_composite(part, (x + sx0, y + sy0))

    def text(self, x, y, s, col, size=12, path=ZEN, index=1, spacing=0, shadow=None):
        m = font_mask(s, size, path, index, spacing)
        mp = m.load()
        for yy in range(m.height):
            for xx in range(m.width):
                if mp[xx, yy] > 127:
                    if shadow is not None:
                        self.pixel(x + xx + 1, y + yy + 1, shadow)
        for yy in range(m.height):
            for xx in range(m.width):
                if mp[xx, yy] > 127:
                    self.pixel(x + xx, y + yy, col)
        return m.width, m.height

    def text_v(self, x, y, s, col, size=12, gap=1, **kw):
        """Vertical text (top to bottom), each glyph centred in a size-wide column."""
        cy = y
        for ch in s:
            m = font_mask(ch, size, **kw)
            self.text(x + (size - m.width) // 2, cy, ch, col, size, **kw)
            cy += m.height + gap
        return cy - y

    def mirror_x(self):
        c = Cv(self.w, self.h)
        c.img = self.img.transpose(Image.FLIP_LEFT_RIGHT)
        c.px = c.img.load()
        return c

    def recolor(self, fn):
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[x, y]
                if p[3]:
                    self.px[x, y] = fn(p)

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.img.save(path)
        return path


def from_ascii(rows, cmap, cv=None, x0=0, y0=0):
    h = len(rows)
    w = max(len(r) for r in rows)
    cv = cv or Cv(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in cmap and cmap[ch] is not None:
                cv.put(x0 + x, y0 + y, cmap[ch])
    return cv


def desaturate(col, t=0.6, toward=None):
    g = int(0.3 * col[0] + 0.59 * col[1] + 0.11 * col[2])
    tgt = toward or (g, g, g)
    return mix(col, tgt + (255,) if len(tgt) == 3 else tgt, t)[:3] + (col[3],)


def scale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def contact(paths_or_imgs, out, k=3, bg=(52, 44, 38, 255), cols=8, pad=4, labels=None):
    imgs = [Image.open(p).convert("RGBA") if isinstance(p, str) else p for p in paths_or_imgs]
    rows = [imgs[i:i + cols] for i in range(0, len(imgs), cols)]
    W = max(sum(i.width + pad for i in r) for r in rows) + pad
    H = sum(max(i.height for i in r) + pad for r in rows) + pad
    sheet = Image.new("RGBA", (W, H), bg)
    y = pad
    for r in rows:
        x = pad
        for i in r:
            sheet.alpha_composite(i, (x, y))
            x += i.width + pad
        y += max(i.height for i in r) + pad
    sheet = scale(sheet, k)
    sheet.save(out)
    return out
