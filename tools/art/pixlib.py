"""Shared pixel-art helpers for 德厚当 generators (owner: Opus; workers: import, don't edit).

Usage (run from project root):
    import sys, os; sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    from pixlib import Canvas, P, load_layout
    c = Canvas(48, 64)              # transparent
    c.rect(10, 10, 20, 30, P.wood1) # filled rect x,y,w,h
    c.save("art/portraits/brother.png")

Only palette colours are allowed (P.<name> or P[i]). Canvas.save() asserts this.
"""
import json
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

with open(os.path.join(ROOT, "data", "palette.json"), encoding="utf-8") as _f:
    _PAL = json.load(_f)


def _hex(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class _Palette:
    def __init__(self):
        self.colors = [_hex(c) for c in _PAL["colors"]]
        for name, col in zip(_PAL["names"], self.colors):
            setattr(self, name, col)

    def __getitem__(self, i):
        return self.colors[i]


P = _Palette()
CLEAR = (0, 0, 0, 0)
ALLOWED = set(P.colors) | {CLEAR}


def load_layout():
    with open(os.path.join(ROOT, "data", "layout.json"), encoding="utf-8") as f:
        return json.load(f)


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()

    # --- primitives -------------------------------------------------------
    def pixel(self, x, y, col):
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

    def frame(self, x, y, w, h, col):
        """1px rectangle outline."""
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
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                d = ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2
                if filled and d <= 1.0:
                    self.pixel(x, y, col)
                elif not filled and 0.75 <= d <= 1.15:
                    self.pixel(x, y, col)

    def poly(self, pts, col):
        """Filled polygon (scanline, even-odd)."""
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
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
        """Ordered (Bayer 4x4) dither between two palette colours. level = share of col_b."""
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                t = (bayer[yy % 4][xx % 4] + 0.5) / 16.0
                self.pixel(xx, yy, col_b if t < level else col_a)

    def vgradient(self, x, y, w, h, cols):
        """Banded + dithered vertical gradient through a list of palette colours."""
        n = len(cols) - 1
        for yy in range(h):
            f = yy / max(1, h - 1) * n
            i = min(int(f), n - 1)
            self.dither(x, y + yy, w, 1, cols[i], cols[i + 1], f - i)

    def outline(self, col=None):
        """Add 1px outline around all opaque pixels (on transparent neighbours)."""
        col = col or P.dkbrown
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3] != 0:
                            self.px[x, y] = col
                            break

    def blit(self, other, x, y):
        for yy in range(other.h):
            for xx in range(other.w):
                c = other.px[xx, yy]
                if c[3] != 0:
                    self.pixel(x + xx, y + yy, c)

    def mirror_x(self):
        self.img = self.img.transpose(Image.FLIP_LEFT_RIGHT)
        self.px = self.img.load()

    # --- output -------------------------------------------------------------
    def check_palette(self):
        bad = set()
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[x, y]
                if c[3] == 0:
                    continue
                if c not in ALLOWED:
                    bad.add(c)
        return bad

    def save(self, rel_path):
        bad = self.check_palette()
        assert not bad, "non-palette colours in %s: %s" % (rel_path, list(bad)[:5])
        path = os.path.join(ROOT, rel_path)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.img.save(path)
        return path


def preview(rel_paths, out_rel, scale=4, bg=(40, 32, 26, 255)):
    """Contact sheet for quick visual review (not shipped)."""
    imgs = [Image.open(os.path.join(ROOT, p)) for p in rel_paths]
    w = sum(i.width for i in imgs) + 4 * (len(imgs) + 1)
    h = max(i.height for i in imgs) + 8
    sheet = Image.new("RGBA", (w, h), bg)
    x = 4
    for i in imgs:
        sheet.alpha_composite(i, (x, 4))
        x += i.width + 4
    sheet = sheet.resize((w * scale, h * scale), Image.NEAREST)
    out = os.path.join(ROOT, out_rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    return out
