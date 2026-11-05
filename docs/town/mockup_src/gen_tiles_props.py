"""Tiles (16x16) and small props for the top-down 青溪镇 mockups."""
import os
import random
from pix import Cv, C, ASSETS, mix, alpha, from_ascii

T = os.path.join(ASSETS, "tiles")
PR = os.path.join(ASSETS, "props")


# ---------------------------------------------------------------- stone road
SLAB_TONES = None


def _tones():
    return [C.st3, mix(C.st3, C.st2, 0.35), mix(C.st3, C.st4, 0.3), mix(C.st2, C.st3, 0.55), mix(C.st3, C.st4, 0.12)]


def _slab(c, x, y, w, h, rnd, base=None, crack=False, wear=0.0):
    base = base or rnd.choice(_tones())
    c.rect(x, y, w, h, base)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            r = rnd.random()
            if r < 0.045:
                c.put(xx, yy, mix(base, C.st1, 0.3))
            elif r < 0.08:
                c.put(xx, yy, mix(base, C.st5, 0.3))
    if wear > 0:
        cx, cy = x + w / 2, y + h / 2
        for yy in range(y + 1, y + h - 1):
            for xx in range(x + 1, x + w - 1):
                d = ((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (h / 2)) ** 2
                if d < 0.6 and rnd.random() < wear:
                    c.put(xx, yy, mix(base, C.st5, 0.25))
    # soft bevel: lit top edge, slightly darker bottom/right edge
    for xx in range(x, x + w):
        c.put(xx, y, mix(c.get(xx, y), C.st5, 0.4))
        c.put(xx, y + h - 1, mix(c.get(xx, y + h - 1), C.st1, 0.22))
    for yy in range(y + 1, y + h):
        c.put(x + w - 1, yy, mix(c.get(x + w - 1, yy), C.st1, 0.18))
        c.put(x, yy, mix(c.get(x, yy), C.st4, 0.15))
    if crack and w > 6:
        xx = x + rnd.randint(2, w - 3)
        yy = y + 1
        n = rnd.randint(3, h)
        for i in range(n):
            if yy >= y + h - 1:
                break
            c.put(xx, yy, mix(base, C.st0, 0.55))
            if rnd.random() < 0.45:
                xx += rnd.choice([-1, 1])
                xx = max(x + 1, min(x + w - 2, xx))
            else:
                yy += 1


def _joints(c, rnd, moss, x0=0, y0=0, w=None, h=None, edge_moss=None):
    w = w or c.w
    h = h or c.h
    J = C.st1
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            p = c.get(x, y)
            if p[:3] == J[:3]:
                m = moss if edge_moss is None else edge_moss(x, y)
                r = rnd.random()
                c.put(x, y, mix(J, C.st2, 0.25))
                if r < 0.25:
                    c.put(x, y, mix(J, C.st0, 0.35))
                if rnd.random() < m:
                    c.put(x, y, rnd.choice([C.g1, C.g2, C.g2, C.g3]))
                    if rnd.random() < 0.3:
                        c.put(x + rnd.choice([-1, 1]), y, C.g2)


def road_tile(seed, rows=((0, 7, (15,)), (8, 7, (7, 15))), crack=False, moss=0.0, wear=0.0, puddle=False):
    """16x16 slab tile. Each row: (y, h, joint xs). Joint at x=15 is the tile seam."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.st1)
    for (ry, rh, joints) in rows:
        x0 = 0
        for j in sorted(joints):
            _slab(c, x0, ry, j - x0, rh, rnd, crack=crack and rnd.random() < 0.6, wear=wear)
            x0 = j + 1
        if x0 < 16:
            _slab(c, x0, ry, 16 - x0, rh, rnd, wear=wear)
    _joints(c, rnd, moss)
    if puddle:
        for y in range(9, 14):
            for x in range(3, 13):
                d = ((x - 8) / 5.2) ** 2 + ((y - 11.5) / 2.4) ** 2
                if d < 1:
                    c.put(x, y, C.wa2 if d > 0.55 else C.wa3)
        c.hline(5, 7, 10, C.wa5)
        c.put(9, 11, C.wa4)
    return c


def slab_field(w, h, seed, row_h=(8, 9, 10, 11), length=(12, 38), moss_fn=None, wear_band=None, crack=0.08):
    """Procedural running-bond slab pavement (no visible 16px grid). Returns Cv(w, h)."""
    rnd = random.Random(seed)
    c = Cv(w, h, C.st1)
    y = 0
    while y < h:
        rh = rnd.choice(row_h)
        x = -rnd.randint(0, 20)
        while x < w:
            ln = rnd.randint(*length)
            wear = 0.0
            if wear_band and wear_band[0] <= y <= wear_band[1]:
                wear = 0.35
            _slab(c, max(0, x), y, min(w, x + ln - 1) - max(0, x), rh - 1, rnd, crack=rnd.random() < crack, wear=wear)
            x += ln
        y += rh
    _joints(c, rnd, 0.0, edge_moss=moss_fn or (lambda x, y: 0.06))
    return c


def gen_road():
    variants = {
        "road_a": dict(seed=1, rows=((0, 7, (15,)), (8, 7, (7, 15)))),
        "road_b": dict(seed=2, rows=((0, 7, (7, 15)), (8, 7, (15,)))),
        "road_c": dict(seed=3, rows=((0, 7, (11, 15)), (8, 7, (4, 15))), crack=True, moss=0.35),
        "road_d": dict(seed=4, rows=((0, 15, (15,)),), wear=0.45),
        "road_e": dict(seed=5, rows=((0, 7, (5, 15)), (8, 7, (11, 15))), moss=0.18),
        "road_f": dict(seed=6, rows=((0, 7, (15,)), (8, 7, (15,))), crack=True, wear=0.3),
        "road_puddle": dict(seed=7, rows=((0, 7, (15,)), (8, 7, (7, 15))), puddle=True),
    }
    for name, kw in variants.items():
        road_tile(**kw).save(os.path.join(T, name + ".png"))
    # a pre-baked seamless-ish street texture for quick compositing
    slab_field(256, 96, 77, wear_band=(30, 60)).save(os.path.join(T, "street_slabs_256x96.png"))


# ---------------------------------------------------------------- ground
def gen_ground():
    # dirt
    rnd = random.Random(11)
    c = Cv(16, 16, C.dirt1)
    c.noise(0, 0, 16, 16, [C.dirt0, C.dirt2, C.dirt2], 0.22, rnd)
    for _ in range(3):
        x, y = rnd.randint(1, 13), rnd.randint(1, 13)
        c.put(x, y, C.st3); c.put(x + 1, y, C.st2); c.put(x, y + 1, C.dirt0); c.put(x + 1, y + 1, C.dirt0)
        c.put(x, y - 1, C.st4)
    c.save(os.path.join(T, "dirt.png"))

    for i, flowers in enumerate((False, True)):
        rnd = random.Random(20 + i)
        c = Cv(16, 16, C.g2)
        c.noise(0, 0, 16, 16, [C.g1, C.g3], 0.25, rnd)
        for _ in range(7):
            x, y = rnd.randint(0, 14), rnd.randint(2, 15)
            c.put(x, y, C.g3); c.put(x, y - 1, C.g4); c.put(x + 1, y - 2, C.g4)
            c.put(x + 1, y + 1, C.g1)
        if flowers:
            for _ in range(3):
                x, y = rnd.randint(1, 14), rnd.randint(1, 14)
                col = rnd.choice([C.white, C.lamp, C.pink])
                c.put(x, y, col); c.put(x, y + 1, C.g1)
        c.save(os.path.join(T, "grass_%d.png" % (i + 1)))


# ---------------------------------------------------------------- water
def water_tile(seed):
    rnd = random.Random(seed)
    c = Cv(16, 16, mix(C.wa2, C.wa3, 0.25))
    # broad dithered bands
    for y in range(16):
        for x in range(16):
            if rnd.random() < 0.14:
                c.put(x, y, C.wa2)
    # ripple streaks
    for _ in range(4):
        x, y = rnd.randint(0, 12), rnd.randint(0, 15)
        ln = rnd.randint(2, 5)
        c.hline(x, x + ln, y, C.wa3)
        if rnd.random() < 0.6:
            c.hline(x + 1, x + ln - 1, y, C.wa4)
        c.hline(x + 1, x + ln + 1, (y + 1) % 16, C.wa1)
    for _ in range(2):
        x, y = rnd.randint(0, 14), rnd.randint(0, 15)
        c.put(x, y, C.wa5)
    return c


def gen_water():
    water_tile(31).save(os.path.join(T, "water_1.png"))
    water_tile(32).save(os.path.join(T, "water_2.png"))
    water_tile(33).save(os.path.join(T, "water_3.png"))


# ---------------------------------------------------------------- embankment
def embank_tile(seed, moss=0.15):
    """Horizontal canal edge: land coping (top) -> stone wall face -> waterline (bottom)."""
    rnd = random.Random(seed)
    c = Cv(16, 16, CLEAR_())
    # coping slab
    c.rect(0, 0, 16, 3, C.st3)
    c.hline(0, 15, 0, C.st4)
    c.hline(0, 15, 2, C.st2)
    c.put(rnd.randint(2, 13), 1, C.st4)
    c.vline(15 if seed % 2 else 7, 0, 2, C.st1)
    # lip shadow
    c.hline(0, 15, 3, C.st0)
    # wall face: 2 courses of blocks
    for row, (y0, h) in enumerate(((4, 4), (8, 4))):
        off = 0 if row == 0 else 4
        c.rect(0, y0, 16, h, C.st1)
        for bx in range(-8 + off, 16, 8):
            base = rnd.choice([C.st1, C.st2, mix(C.st1, C.st2, 0.5)])
            c.rect(bx + 1, y0, 7, h - 1, base)
            c.hline(bx + 1, bx + 7, y0, mix(base, C.st3, 0.5))
        c.hline(0, 15, y0 + h - 1, C.st0)
    c.noise(0, 4, 16, 8, [C.g1, C.g2], moss, rnd)
    # damp streaks
    for _ in range(2):
        x = rnd.randint(0, 15)
        for y in range(7, 12):
            if rnd.random() < 0.7:
                c.put(x, y, mix(c.get(x, y), C.wa0, 0.35))
    # waterline: dark reflected wall
    c.rect(0, 12, 16, 4, C.wa1)
    c.hline(0, 15, 12, C.wa0)
    c.hline(0, 15, 13, C.wa0)
    for x in range(16):
        if rnd.random() < 0.3:
            c.put(x, 14, C.wa2)
        if rnd.random() < 0.15:
            c.put(x, 13, C.g1)
    return c


def CLEAR_():
    return (0, 0, 0, 0)


def gen_embank():
    embank_tile(41).save(os.path.join(T, "embank_1.png"))
    embank_tile(42, moss=0.3).save(os.path.join(T, "embank_2.png"))
    # vertical coping for the side of a water lane (land on left, water on right)
    rnd = random.Random(43)
    c = Cv(16, 16)
    c.rect(0, 0, 4, 16, C.st3)
    c.vline(0, 0, 15, C.st4)
    c.vline(3, 0, 15, C.st2)
    for y in (5, 11):
        c.hline(0, 3, y, C.st1)
    c.rect(4, 0, 12, 16, C.wa2)
    c.vline(4, 0, 15, C.wa0)
    c.vline(5, 0, 15, C.wa1)
    c.vline(6, 0, 15, C.wa1)
    c.save(os.path.join(T, "lane_edge_left.png"))
    c.mirror_x().save(os.path.join(T, "lane_edge_right.png"))
    # river steps (河埠头) going down into the water, 32x16
    c = Cv(32, 20)
    for i, y in enumerate((0, 4, 8, 12)):
        tone = [C.st4, C.st3, C.st2, C.st1][i]
        c.rect(2 + i, y, 28 - 2 * i, 4, tone)
        c.hline(2 + i, 29 - i, y, mix(tone, C.st5, 0.5))
        c.hline(2 + i, 29 - i, y + 3, mix(tone, C.st0, 0.5))
    c.rect(0, 0, 2, 16, C.st1); c.rect(30, 0, 2, 16, C.st1)
    c.vline(0, 0, 15, C.st2)
    c.rect(0, 16, 32, 4, C.wa1)
    c.hline(4, 27, 16, C.wa3)
    c.noise(0, 4, 32, 12, [C.g1, C.g2], 0.06, random.Random(44))
    c.save(os.path.join(T, "river_steps_32x20.png"))


# ---------------------------------------------------------------- willow
def willow(w, h, seed, out):
    """Weeping willow: crown clumps + curtains of hanging leaf strands, trunk visible below."""
    import math
    rnd = random.Random(seed)
    c = Cv(w, h)
    cx = w // 2
    base = h - 1
    tw = max(3, w // 11)
    crown_y = int(h * 0.30)
    # trunk with a gentle S-curve
    for y in range(int(h * 0.28), base + 1):
        t = (base - y) / (base - h * 0.28)
        off = int(round(1.6 * math.sin(t * 2.6)))
        wid = tw + (2 if y > base - 3 else 0)
        x0 = cx - wid // 2 + off
        c.hline(x0, x0 + wid - 1, y, C.wood1)
        c.put(x0, y, C.wood2)
        if wid > 3:
            c.put(x0 + 1, y, C.wood3 if y % 5 else C.wood2)
        c.put(x0 + wid - 1, y, C.wood0)
        if rnd.random() < 0.3:
            c.put(x0 + rnd.randint(1, wid - 1), y, C.wood0)
    # branches
    for (ang, ln) in ((-60, 0.42), (-20, 0.38), (25, 0.36), (65, 0.40), (-95, 0.3), (100, 0.3)):
        a_ = math.radians(ang - 90)
        x1 = cx + math.cos(a_) * ln * w
        y1 = int(h * 0.30) + math.sin(a_) * ln * h * 0.45
        c.line(cx, int(h * 0.36), int(x1), int(y1), C.wood0)
    # crown clumps
    clumps = []
    for i in range(7):
        ang = rnd.uniform(-math.pi, 0)
        rr = rnd.uniform(0.15, 0.42)
        bx = cx + math.cos(ang) * rr * w
        by = crown_y + math.sin(ang) * rr * h * 0.32
        clumps.append((bx, by, rnd.uniform(w * 0.15, w * 0.21), rnd.uniform(h * 0.09, h * 0.13)))
    clumps.append((cx, crown_y - h * 0.1, w * 0.26, h * 0.13))
    clumps.append((cx + w * 0.05, crown_y + h * 0.02, w * 0.3, h * 0.09))
    for (bx, by, rx, ry) in clumps:
        c.ellipse(bx, by, rx, ry, C.g2)
    for (bx, by, rx, ry) in clumps:
        c.ellipse(bx - rx * 0.25, by - ry * 0.3, rx * 0.6, ry * 0.5, C.g3)
    for (bx, by, rx, ry) in clumps:
        c.ellipse(bx - rx * 0.4, by - ry * 0.5, rx * 0.25, ry * 0.22, C.g4)
    # crown texture: leaf flecks
    for y in range(h):
        for x in range(w):
            p = c.get(x, y)
            if p[3] and p[:3] in (C.g2[:3], C.g3[:3]) and rnd.random() < 0.12:
                c.put(x, y, C.g1 if rnd.random() < 0.5 else C.g4)
    crown = c.copy()
    # hanging strands (curtain)
    for x in range(1, w - 1, 1):
        dxn = (x - cx + 0.5) / (w / 2)
        if abs(dxn) > 0.97:
            continue
        if x % 2 == 1 and rnd.random() < 0.3:
            continue
        # find crown bottom at this column
        top = None
        for y in range(h - 1, -1, -1):
            if crown.get(x, y)[3] and crown.get(x, y)[:3] != C.wood0[:3] and crown.get(x, y)[:3] != C.wood1[:3]:
                top = y
                break
        if top is None:
            top = crown_y
        ln = int(h * (0.52 - 0.2 * abs(dxn)) + rnd.randint(-6, 5))
        sx = x
        for i in range(ln):
            y = top - 2 + i
            if y >= base - 4:
                break
            t = i / max(1, ln)
            if dxn < -0.15:
                col = C.g4 if (i % 3) else C.g3
            elif dxn > 0.35:
                col = C.g2 if (i % 3) else C.g1
            else:
                col = C.g3 if (i % 3) else C.g2
            if t > 0.8:
                col = C.g2 if dxn < 0.35 else C.g1
            c.put(sx, y, col)
            if i % 4 == 2 and rnd.random() < 0.6:   # little leaf to the side
                c.put(sx + (1 if (i // 4) % 2 else -1), y, mix(col, C.g1, 0.3))
            if rnd.random() < 0.08:
                sx += rnd.choice([-1, 1]) if 1 < sx < w - 2 else 0
    # dark outline only around the crown silhouette top half
    src = c.img.copy().load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx_, dy_ in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    xx, yy = x + dx_, y + dy_
                    if 0 <= xx < w and 0 <= yy < h and src[xx, yy][3] and crown.get(xx, yy)[3] and yy < crown_y + h * 0.12:
                        c.put(x, y, C.g0)
                        break
    c.save(out)
    return c


def rickshaw(out):
    """黄包车 parked, seen from the side (3/4), 30x22."""
    c = Cv(30, 22)
    # shafts resting on the ground
    c.line(14, 15, 29, 20, C.wood2)
    c.line(14, 14, 29, 19, C.wood3)
    # body / seat
    c.rect(4, 7, 11, 7, C.rf1)
    c.rect(5, 8, 9, 3, C.seal_red)
    c.hline(5, 13, 8, C.lantern_hi)
    c.rect(4, 13, 12, 2, C.wood1)
    # folding hood
    c.poly([(3, 7), (5, 1), (12, 1), (14, 6), (14, 7), (3, 7)], C.rf1)
    c.hline(5, 12, 1, C.rf3)
    c.line(5, 1, 3, 7, C.rf3)
    for x in (7, 10):
        c.vline(x, 2, 6, C.rf0)
    # wheel
    c.ellipse(8, 15, 6, 6, C.dkbrown, filled=False)
    c.ellipse(8, 15, 5, 5, C.gray, filled=False)
    for (dx, dy) in ((0, -4), (0, 4), (-4, 0), (4, 0), (-3, -3), (3, 3), (-3, 3), (3, -3)):
        c.line(8, 15, 8 + dx, 15 + dy, C.silver)
    c.rect(7, 14, 3, 3, C.wood0)
    c.outline(C.dkbrown)
    c.save(out)


def well(out):
    c = Cv(18, 16)
    c.ellipse(8.5, 9, 8, 5.5, C.st2)
    c.ellipse(8.5, 8, 8, 5, C.st3)
    c.ellipse(8.5, 7.5, 6, 3.5, C.st4)
    c.ellipse(8.5, 7.8, 4.2, 2.4, C.wa0)
    c.hline(6, 10, 7, C.wa1)
    c.rect(1, 9, 16, 4, C.st2)
    for x in range(1, 17, 5):
        c.vline(x, 9, 12, C.st1)
    c.hline(1, 16, 9, C.st3)
    # wooden bucket on the rim
    c.rect(12, 3, 4, 4, C.wood2)
    c.hline(12, 15, 3, C.tan)
    c.hline(12, 15, 5, C.gray)
    c.line(12, 3, 14, 0, C.wood1); c.line(15, 3, 14, 0, C.wood1)
    c.outline(C.dkbrown)
    c.save(out)


def chicken(out):
    rows = [
        "..r.....",
        ".www....",
        "wwEw..t.",
        ".wwwwtt.",
        ".wwwwww.",
        "..wwww..",
        "..y..y..",
    ]
    c = Cv(8, 8)
    from_ascii(rows, {"w": C.ww0, "r": C.seal_red, "E": C.dkbrown, "t": C.wood3, "y": C.flame}, c)
    c.put(0, 3, C.flame)
    c.put(4, 4, C.ww2); c.put(5, 4, C.ww2)
    c.outline(C.dkbrown)
    c.save(out)


def grass_tuft(out, seed=0):
    rnd = random.Random(seed)
    c = Cv(8, 6)
    for x in range(1, 7):
        hgt = rnd.randint(2, 5)
        for y in range(6 - hgt, 6):
            c.put(x, y, C.g3 if y < 4 else C.g2)
        c.put(x, 6 - hgt, C.g4)
    c.save(out)


def bush(seed, out, w=16, h=14, flowers=False):
    rnd = random.Random(seed)
    c = Cv(w, h)
    blobs = [(w * 0.3, h * 0.6, 4.5), (w * 0.62, h * 0.55, 5), (w * 0.47, h * 0.38, 5)]
    for (bx, by, r) in blobs:
        c.ellipse(bx, by, r, r * 0.85, C.g2)
    for (bx, by, r) in blobs:
        c.ellipse(bx - 1, by - 1.5, r * 0.55, r * 0.45, C.g3)
        c.ellipse(bx - 1.5, by - 2, r * 0.25, r * 0.22, C.g4)
    for y in range(h):
        for x in range(w):
            p = c.get(x, y)
            if p[3] and y > h * 0.62 and rnd.random() < 0.5:
                c.put(x, y, C.g1)
    if flowers:
        for _ in range(5):
            x, y = rnd.randint(3, w - 4), rnd.randint(2, h - 5)
            if c.get(x, y)[3]:
                c.put(x, y, rnd.choice([C.flower, C.pink, C.white]))
    c.outline(C.g0)
    c.save(out)


# ---------------------------------------------------------------- props
def lantern(out, col=None):
    col = col or C.lantern
    c = Cv(9, 14)
    c.vline(4, 0, 1, C.wood0)  # cord
    c.rect(2, 2, 5, 1, C.wood0)  # top cap
    c.ellipse(4, 6.5, 3.6, 3.8, col)
    c.vline(1, 5, 8, mix(col, C.lantern_hi, 0.6))
    c.vline(2, 4, 9, C.lantern_hi)
    c.vline(6, 4, 9, C.dkred)
    c.vline(7, 5, 8, C.dkred)
    c.hline(2, 6, 6, C.lamp)  # glowing rib
    c.put(3, 4, C.lamp_pale)
    c.rect(2, 10, 5, 1, C.wood0)  # bottom cap
    c.vline(4, 11, 13, C.gold)
    c.put(3, 13, C.seal_red); c.put(5, 13, C.seal_red)
    c.outline(C.dkbrown)
    c.save(out)


def lantern_post(out):
    """Kerosene street lamp on a wooden post with stone base (16x32)."""
    c = Cv(16, 34)
    # stone base
    c.rect(4, 28, 8, 5, C.st2)
    c.hline(4, 11, 28, C.st4)
    c.vline(4, 28, 32, C.st3)
    c.vline(11, 29, 32, C.st1)
    # post
    c.rect(7, 10, 3, 18, C.wood1)
    c.vline(7, 10, 27, C.wood2)
    c.vline(9, 10, 27, C.wood0)
    # bracket
    c.rect(6, 9, 5, 1, C.wood0)
    # lamp box
    c.rect(4, 1, 9, 2, C.rf1)  # little roof
    c.hline(3, 13, 2, C.rf0)
    c.put(3, 1, C.rf2); c.put(13, 1, C.rf2)
    c.rect(5, 3, 7, 6, C.lamp_pale)
    c.rect(6, 4, 5, 4, C.lamp)
    c.vline(5, 3, 8, C.wood0); c.vline(11, 3, 8, C.wood0); c.vline(8, 3, 8, C.wood0)
    c.put(7, 5, C.paper_hi); c.put(9, 6, C.flame)
    c.hline(5, 11, 8, C.wood0)
    c.outline(C.dkbrown)
    c.save(out)


def rice_sacks(out):
    c = Cv(20, 16)

    def sack(x, y, w, h, stamp=True):
        c.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, C.paper_old)
        c.ellipse(x + w / 2 - 1, y + h / 2 - 1, w / 2 - 2, h / 2 - 2, C.paper)
        c.ellipse(x + w / 2 - 2, y + h / 2 - 2, w / 4, h / 5, C.paper_hi)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                p = c.get(xx, yy)
                if p[3] and (xx + yy) % 3 == 0 and p[:3] == C.paper[:3]:
                    c.put(xx, yy, C.paper_old)
        # tied top
        c.put(x + w // 2, y, C.wood3); c.put(x + w // 2 - 1, y, C.wood2)
        if stamp:
            c.rect(x + w // 2 - 1, y + h // 2, 3, 2, C.seal_red)
            c.put(x + w // 2, y + h // 2 + 2, C.dkred)
    sack(0, 5, 10, 11)
    sack(9, 6, 10, 10)
    sack(4, 0, 10, 9, stamp=False)
    c.outline(C.dkbrown)
    c.save(out)


def barrel(out):
    c = Cv(12, 15)
    c.rect(1, 3, 10, 11, C.wood2)
    for x in (1, 4, 7, 10):
        c.vline(x, 3, 13, C.wood1)
    c.vline(2, 3, 13, C.wood3)
    c.vline(3, 3, 13, C.tan)
    c.vline(10, 3, 13, C.wood0)
    for y in (5, 11):
        c.hline(1, 10, y, C.gray)
        c.put(2, y, C.silver)
    c.ellipse(5.5, 2.5, 5, 2, C.wood1)
    c.ellipse(5.5, 2.5, 3.5, 1.2, C.wood0)
    c.hline(2, 9, 1, C.wood3)
    c.outline(C.dkbrown)
    c.save(out)


def water_vat(out):
    c = Cv(16, 15)
    c.ellipse(7.5, 8.5, 7, 6, C.wood0)
    c.ellipse(6, 7.5, 4, 4, C.wood1)
    c.ellipse(4.5, 7, 1.5, 2.5, C.wood2)
    c.put(4, 6, C.tan)
    c.ellipse(7.5, 3, 6.5, 2.4, C.dkbrown)
    c.ellipse(7.5, 3.3, 5.3, 1.6, C.wa1)
    c.hline(5, 8, 3, C.wa3)
    c.hline(2, 13, 1, C.wood2)
    c.rect(4, 14, 8, 1, C.wood0)
    c.outline(C.dkbrown)
    c.save(out)


def laundry_pole(out):
    c = Cv(48, 34)
    # bamboo X-stands
    for bx in (3, 44):
        c.line(bx - 3, 33, bx + 1, 3, C.g3)
        c.line(bx + 3, 33, bx - 1, 3, C.gold)
    # pole
    c.hline(0, 47, 5, C.gold)
    c.hline(0, 47, 4, C.lamp_pale)
    for x in range(0, 48, 7):
        c.put(x, 5, C.wood3)

    def cloth(x, w, h, col, hi, lo, pattern=None):
        c.rect(x, 6, w, h, col)
        c.vline(x, 6, 5 + h, hi)
        c.vline(x + w - 1, 6, 5 + h, lo)
        c.hline(x, x + w - 1, 6, lo)
        if pattern:
            for yy in range(8, 6 + h, 3):
                for xx in range(x + 1, x + w - 1, 3):
                    c.put(xx, yy, pattern)
        # hem wave
        for xx in range(x, x + w):
            if (xx - x) % 3 == 1:
                c.put(xx, 6 + h, col)
    cloth(8, 9, 14, C.indigo2, C.blue_hi, C.indigo1, pattern=C.white)  # 蓝印花布
    cloth(19, 8, 11, C.white, C.ww0, C.fog)
    # trousers
    c.rect(29, 6, 9, 5, C.wall1)
    c.rect(29, 11, 4, 10, C.wall1); c.rect(34, 11, 4, 10, C.wall1)
    c.vline(29, 6, 20, C.wall2); c.vline(34, 11, 20, C.wall2)
    cloth(39, 4, 8, C.seal_red, C.lantern_hi, C.dkred)
    c.outline(C.dkbrown)
    c.save(out)


def boat(out, w=48, h=22, boatman=True):
    c = Cv(w, h)
    mid = h - 9
    # hull silhouette (top-down 3/4: long ellipse deck + visible side)
    for x in range(w):
        t = (x - w / 2 + 0.5) / (w / 2)
        half = int(5 * (1 - t ** 4) ** 0.5) if abs(t) < 1 else 0
        if half <= 0:
            continue
        up = int(3 * t ** 6)  # upturned ends
        y0 = mid - half - up
        y1 = mid + half // 2 - up
        c.vline(x, y0, y1, C.wood2)            # deck
        c.vline(x, y1 + 1, y1 + 4, C.wood0)    # hull side
        c.put(x, y1 + 1, C.wood1)
        c.put(x, y0, C.wood3)
        if x % 5 == 0:
            c.vline(x, y0 + 1, y1, C.wood1)    # deck planks
    # awning (乌篷): black arched mats
    ax0, ax1 = int(w * 0.32), int(w * 0.68)
    for x in range(ax0, ax1 + 1):
        top = mid - 9
        c.vline(x, top, mid + 1, C.rf1)
        c.put(x, top, C.rf3)
        c.put(x, top + 1, C.rf2)
        if (x - ax0) % 4 == 0:
            c.vline(x, top + 1, mid + 1, C.rf0)
    c.vline(ax0, mid - 9, mid + 2, C.rf0)
    c.rect(ax0 + 2, mid - 3, ax1 - ax0 - 3, 4, C.rf0)   # dark opening
    c.hline(ax0 + 2, ax1 - 2, mid - 3, C.wood1)
    if boatman:
        bx = int(w * 0.82)
        # oar
        c.line(bx + 2, mid - 6, bx + 7, mid + 6, C.wood3)
        # body
        c.rect(bx - 1, mid - 9, 3, 6, C.indigo1)
        c.put(bx - 1, mid - 9, C.indigo2)
        c.rect(bx - 1, mid - 3, 3, 2, C.wood0)
        c.rect(bx - 1, mid - 12, 3, 3, C.skin)
        # straw hat
        c.hline(bx - 3, bx + 3, mid - 12, C.tan)
        c.hline(bx - 2, bx + 2, mid - 13, C.lamp_pale)
        c.put(bx, mid - 14, C.tan)
    c.outline(C.dkbrown)
    c.save(out)


def cat(out_sit, out_sleep):
    rows = [
        "..............",
        "..o.o.........",
        "..ooo.........",
        ".oEoEo........",
        ".ooOoo........",
        "..ooo.....t...",
        ".oWWoo.....t..",
        ".oWWooo....t..",
        ".oWoooooo.t...",
        ".ooooooooot...",
        ".oo.ooo.oo....",
    ]
    cmap = {"o": C.tabby1, "O": C.tabby0, "E": C.jade, "W": C.ww0, "t": C.tabby1}
    c = Cv(14, 12)
    from_ascii(rows, cmap, c)
    # stripes
    for (x, y) in ((5, 8), (6, 9), (7, 8), (2, 2), (4, 2)):
        c.put(x, y, C.tabby0)
    c.put(3, 4, C.pink)
    c.put(1, 6, C.tabby2); c.put(1, 7, C.tabby2)
    c.outline(C.dkbrown)
    c.save(out_sit)
    rows = [
        "..............",
        "....oooooo....",
        "..oooooooooo..",
        ".ooOoooooOooo.",
        ".tooooooooooo.",
        "..tttooooooW..",
        "..........WW..",
    ]
    c = Cv(14, 8)
    from_ascii(rows, cmap, c)
    c.put(11, 3, C.tabby0); c.put(12, 2, C.tabby1)
    c.put(4, 2, C.tabby2); c.put(5, 2, C.tabby2)
    c.outline(C.dkbrown)
    c.save(out_sleep)


def duck(out):
    rows = [
        "...ww...",
        "..wwbO..",
        "...ww...",
        "wwwwww..",
        ".wwwwW..",
    ]
    c = Cv(8, 6)
    from_ascii(rows, {"w": C.ww0, "W": C.fog, "b": C.dkbrown, "O": C.flame}, c)
    c.put(1, 3, C.fog)
    c.outline(C.dkbrown)
    c.save(out)


def tea_table(out):
    c = Cv(26, 18)
    # stools
    for sx in (0, 21):
        c.rect(sx, 9, 5, 2, C.wood3); c.hline(sx, sx + 4, 9, C.tan)
        c.rect(sx, 11, 5, 4, C.wood1); c.vline(sx + 2, 11, 14, C.wood0)
    # table top (3/4)
    c.rect(5, 3, 16, 6, C.wood2)
    c.hline(5, 20, 3, C.tan)
    c.hline(5, 20, 8, C.wood1)
    c.rect(5, 9, 16, 2, C.wood0)  # apron
    c.vline(6, 11, 16, C.wood1); c.vline(19, 11, 16, C.wood1)
    c.vline(7, 11, 16, C.wood0); c.vline(18, 11, 16, C.wood0)
    # teapot + cups
    c.ellipse(10, 4, 2.5, 2, C.ww1)
    c.put(9, 3, C.ww0); c.put(13, 4, C.ww2); c.put(10, 2, C.indigo2)
    c.put(15, 5, C.ww0); c.put(17, 4, C.ww0); c.put(15, 6, C.ww2)
    c.outline(C.dkbrown)
    c.save(out)


def notice_board(out):
    c = Cv(18, 26)
    c.rect(2, 2, 14, 14, C.wood1)
    c.frame(2, 2, 14, 14, C.wood0)
    c.rect(1, 1, 16, 2, C.rf1); c.hline(0, 17, 1, C.rf2)
    c.vline(3, 16, 25, C.wood1); c.vline(14, 16, 25, C.wood1)
    c.vline(4, 16, 25, C.wood0); c.vline(15, 16, 25, C.wood0)
    # posters
    c.rect(4, 4, 5, 7, C.paper_hi); c.hline(5, 7, 6, C.gray); c.hline(5, 7, 8, C.gray)
    c.rect(10, 5, 4, 8, C.paper); c.hline(10, 13, 5, C.seal_red); c.hline(11, 12, 8, C.gray); c.hline(11, 12, 10, C.gray)
    c.rect(5, 12, 4, 3, C.ww1)
    c.outline(C.dkbrown)
    c.save(out)


def herb_rack(out):
    c = Cv(24, 14)
    c.rect(1, 9, 22, 2, C.wood1)
    c.vline(2, 9, 13, C.wood0); c.vline(21, 9, 13, C.wood0)
    for (bx, col, col2) in ((6, C.wood3, C.g2), (17, C.tan, C.dkred)):
        c.ellipse(bx, 6, 6, 3.5, C.tan)
        c.ellipse(bx, 6, 4.8, 2.6, C.wood3)
        for _ in range(14):
            import random as _r
            pass
        for dx in range(-3, 4):
            for dy in (-1, 0, 1):
                if (dx + dy) % 2 == 0:
                    c.put(bx + dx, 6 + dy, col2)
        c.hline(bx - 4, bx + 4, 3, C.lamp_pale)
    c.outline(C.dkbrown)
    c.save(out)


def bench(out):
    c = Cv(26, 12)
    c.rect(1, 2, 24, 3, C.wood2)
    c.hline(1, 24, 2, C.tan)
    c.hline(1, 24, 4, C.wood1)
    c.rect(1, 5, 24, 1, C.wood0)
    for lx in (3, 21):
        c.rect(lx, 6, 2, 5, C.wood1)
        c.put(lx, 6, C.wood2)
    c.outline(C.dkbrown)
    c.save(out)


def flowerpot(out):
    c = Cv(10, 14)
    c.ellipse(4.5, 4, 4, 3.5, C.g2)
    c.ellipse(3.5, 3, 2, 1.8, C.g3)
    c.put(3, 2, C.g4); c.put(6, 2, C.flower); c.put(2, 5, C.flower); c.put(7, 4, C.pink)
    c.rect(2, 8, 6, 5, C.indigo2)
    c.hline(1, 8, 7, C.ww1)
    c.hline(1, 8, 8, C.ww0)
    c.vline(2, 9, 12, C.blue_hi)
    c.vline(7, 9, 12, C.indigo1)
    c.put(4, 10, C.ww0); c.put(5, 11, C.ww0)
    c.outline(C.dkbrown)
    c.save(out)


def mailbox(out):
    c = Cv(10, 18)
    c.rect(1, 3, 8, 14, C.postgreen)
    c.vline(1, 3, 16, C.postgreen_hi)
    c.vline(2, 3, 16, C.postgreen_hi)
    c.vline(8, 3, 16, C.g0)
    c.ellipse(4.5, 3, 4, 2, C.postgreen_hi)
    c.hline(2, 7, 2, C.jade_hi)
    c.rect(3, 6, 4, 1, C.dkbrown)
    c.rect(3, 9, 4, 3, C.lamp)
    c.put(4, 10, C.seal_red)
    c.rect(1, 16, 8, 1, C.g0)
    c.outline(C.dkbrown)
    c.save(out)


def bollard(out):
    c = Cv(7, 9)
    c.rect(1, 2, 5, 6, C.st2)
    c.ellipse(3, 2, 2.5, 1.4, C.st4)
    c.vline(1, 2, 7, C.st3)
    c.vline(5, 3, 7, C.st1)
    c.hline(1, 5, 5, C.wood2)  # rope
    c.outline(C.dkbrown)
    c.save(out)


def baskets(out):
    c = Cv(16, 12)
    for (bx, by, fill) in ((4, 6, C.ww0), (11, 7, C.g3)):
        c.ellipse(bx, by + 2, 4, 3, C.wood3)
        for x in range(bx - 4, bx + 5):
            if x % 2 == 0:
                c.vline(x, by + 1, by + 4, C.wood2)
        c.ellipse(bx, by, 3.5, 1.6, fill)
        c.put(bx - 1, by - 1, C.white if fill == C.ww0 else C.g4)
        c.hline(bx - 3, bx + 3, by + 2, C.tan)
    c.outline(C.dkbrown)
    c.save(out)


def crates(out):
    c = Cv(16, 16)

    def crate(x, y, w, h):
        c.rect(x, y, w, h, C.wood3)
        c.frame(x, y, w, h, C.wood1)
        c.line(x, y, x + w - 1, y + h - 1, C.wood2)
        c.hline(x, x + w - 1, y, C.tan)
    crate(0, 6, 9, 9)
    crate(8, 7, 8, 8)
    crate(3, 0, 8, 7)
    c.outline(C.dkbrown)
    c.save(out)


def ui_icons():
    U = os.path.join(ASSETS, "ui")
    # speech bubble "…"
    c = Cv(15, 12)
    c.rect(1, 0, 13, 8, C.ww0)
    c.rect(0, 1, 15, 6, C.ww0)
    c.hline(1, 13, 7, C.ww2)
    c.poly([(4, 8), (8, 8), (4, 11)], C.ww0)
    for x in (4, 7, 10):
        c.rect(x, 3, 2, 2, C.dkbrown)
    c.outline(C.dkbrown)
    c.save(os.path.join(U, "bubble_dots.png"))
    # exclamation marker (quest)
    c = Cv(9, 14)
    c.rect(2, 0, 5, 8, C.lamp)
    c.rect(3, 9, 3, 3, C.lamp)
    c.vline(2, 0, 7, C.paper_hi)
    c.vline(6, 1, 7, C.flame)
    c.put(5, 11, C.flame)
    c.outline(C.dkbrown)
    c.save(os.path.join(U, "exclaim.png"))
    # padlock
    c = Cv(11, 13)
    c.ellipse(5, 3.5, 3.5, 3.5, C.silver, filled=False)
    c.ellipse(5, 3.5, 2.5, 2.5, CLEAR_(), filled=True)
    c.clear_rect(3, 2, 5, 4)
    c.vline(2, 3, 6, C.silver); c.vline(8, 3, 6, C.silver)
    c.hline(3, 7, 0, C.silver)
    c.put(2, 1, C.silver); c.put(8, 1, C.silver)
    c.rect(1, 6, 9, 6, C.gold)
    c.hline(1, 9, 6, C.lamp)
    c.vline(1, 6, 11, C.lamp)
    c.vline(9, 7, 11, C.wood2)
    c.rect(4, 8, 2, 2, C.dkbrown); c.put(5, 10, C.dkbrown)
    c.outline(C.dkbrown)
    c.save(os.path.join(U, "padlock.png"))
    # coin (蚨)
    c = Cv(10, 10)
    c.ellipse(4.5, 4.5, 4.5, 4.5, C.gold)
    c.ellipse(4, 4, 3.4, 3.4, C.lamp)
    c.rect(4, 3, 2, 3, C.wood1)
    c.put(2, 2, C.paper_hi)
    c.outline(C.dkbrown)
    c.save(os.path.join(U, "coin.png"))
    # sun (weather)
    c = Cv(15, 15)
    c.ellipse(7, 7, 3.6, 3.6, C.lamp)
    c.ellipse(6, 6, 1.6, 1.6, C.paper_hi)
    for (dx, dy) in ((0, -6), (0, 6), (-6, 0), (6, 0), (-4, -4), (4, 4), (-4, 4), (4, -4)):
        c.put(7 + dx, 7 + dy, C.flame)
        c.put(7 + int(dx * 0.85), 7 + int(dy * 0.85), C.lamp)
    c.outline(C.wood1)
    c.save(os.path.join(U, "sun.png"))
    # cloud-sun (partly cloudy)
    c2 = Cv.load(os.path.join(U, "sun.png"))
    c2 = Cv(18, 15)
    c2.blit(Cv.load(os.path.join(U, "sun.png")), 0, 0)
    for (cx, cy, r) in ((10, 10, 3.5), (14, 10, 3), (12, 8, 3)):
        c2.ellipse(cx, cy, r, r * 0.8, C.ww0)
    c2.hline(8, 16, 12, C.fog)
    c2.save(os.path.join(U, "sun_cloud.png"))


# ---------------------------------------------------------------- bridge
def balustrade(w, seed=0):
    """Low stone railing seen from the front, w x 9."""
    c = Cv(w, 10)
    c.rect(0, 3, w, 5, C.st2)
    c.hline(0, w - 1, 2, C.st4)
    c.hline(0, w - 1, 3, C.st3)
    c.hline(0, w - 1, 8, C.st1)
    xs = list(range(0, w - 2, 12)) + [w - 3]
    for i in range(len(xs) - 1):
        a, b = xs[i] + 4, xs[i + 1] - 2
        if b - a > 3:
            c.frame(a, 4, b - a, 3, C.st1)
            c.hline(a + 1, b - 2, 5, mix(C.st2, C.st3, 0.5))
    for x in xs:
        c.rect(x, 0, 3, 9, C.st3)
        c.vline(x, 0, 8, C.st4)
        c.vline(x + 2, 1, 8, C.st1)
        c.hline(x, x + 2, 0, C.st5)
    rnd = random.Random(seed)
    c.noise(0, 3, w, 6, [C.g2, C.g1], 0.04, rnd)
    c.outline(C.st0)
    return c


def arch_face(w=56, h=24, r=15, seed=0):
    """South face of the arch bridge with its opening; bottom row = waterline."""
    rnd = random.Random(seed)
    c = Cv(w, h)
    cx, cy = (w - 1) / 2, h - 1
    # masonry
    for y in range(h):
        course = y // 4
        off = (course % 2) * 5
        for x in range(w):
            base = C.st2 if ((x + off) // 10 + course) % 3 else mix(C.st2, C.st1, 0.5)
            col = base
            if y % 4 == 0:
                col = mix(base, C.st3, 0.5)
            if (x + off) % 10 == 0 or y % 4 == 3:
                col = C.st1
            c.put(x, y, col)
    c.hline(0, w - 1, 0, C.st4)
    c.hline(0, w - 1, 1, C.st3)
    # opening + voussoir ring
    import math
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, (y - cy) * 1.0)
            if d < r:
                t = d / r
                col = C.wa0 if t > 0.55 else C.wa1
                c.put(x, y, col)
            elif d < r + 3:
                ang = math.degrees(math.atan2(cy - y, x - cx))
                col = C.st4 if d < r + 1 else C.st3
                if int(ang) % 18 < 2:
                    col = C.st1
                c.put(x, y, col)
    # far end of the tunnel (light)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx, (y - cy) * 1.15)
            if d < r * 0.5:
                c.put(x, y, C.wa2 if d > r * 0.32 else C.wa3)
    c.put(int(cx), int(cy - r - 1), C.st5)  # keystone
    c.put(int(cx) + 1, int(cy - r - 1), C.st5)
    # waterline reflection glints
    for x in range(int(cx - r + 3), int(cx + r - 2), 3):
        c.put(x, h - 1, C.wa3)
    # hanging ivy
    for _ in range(6):
        x = rnd.randint(1, w - 2)
        if abs(x - cx) < r + 2:
            continue
        ln = rnd.randint(3, 9)
        for y in range(1, 1 + ln):
            c.put(x, y, C.g3 if y % 2 else C.g2)
        c.put(x - 1, 2, C.g4)
    c.noise(0, 2, w, h - 2, [C.g1, C.g2], 0.03, rnd, mask_col=C.st2)
    return c


def gen_bridge():
    balustrade(48, 1).save(os.path.join(PR, "bridge_rail_48.png"))
    arch_face(56, 24, 15, 2).save(os.path.join(PR, "bridge_arch_face_56x24.png"))
    deck = slab_field(48, 72, 91, row_h=(11, 12, 13), length=(48, 60), crack=0.15)
    deck.recolor(lambda p: mix(p, C.st4, 0.18))
    deck.save(os.path.join(PR, "bridge_deck_48x72.png"))


def gen_all():
    os.makedirs(T, exist_ok=True)
    os.makedirs(PR, exist_ok=True)
    os.makedirs(os.path.join(ASSETS, "ui"), exist_ok=True)
    gen_road(); gen_ground(); gen_water(); gen_embank()
    willow(32, 48, 51, os.path.join(PR, "willow_32x48.png"))
    willow(48, 64, 52, os.path.join(PR, "willow_48x64.png"))
    bush(61, os.path.join(PR, "bush_1.png"))
    bush(62, os.path.join(PR, "bush_flower.png"), flowers=True)
    lantern(os.path.join(PR, "lantern_red.png"))
    lantern_post(os.path.join(PR, "lantern_post.png"))
    rice_sacks(os.path.join(PR, "rice_sacks.png"))
    barrel(os.path.join(PR, "barrel.png"))
    water_vat(os.path.join(PR, "water_vat.png"))
    laundry_pole(os.path.join(PR, "laundry_pole.png"))
    boat(os.path.join(PR, "boat_48x22.png"))
    boat(os.path.join(PR, "boat_32x16.png"), w=32, h=16, boatman=False)
    cat(os.path.join(PR, "cat_sit.png"), os.path.join(PR, "cat_sleep.png"))
    duck(os.path.join(PR, "duck.png"))
    tea_table(os.path.join(PR, "tea_table.png"))
    notice_board(os.path.join(PR, "notice_board.png"))
    herb_rack(os.path.join(PR, "herb_rack.png"))
    bench(os.path.join(PR, "bench.png"))
    flowerpot(os.path.join(PR, "flowerpot.png"))
    mailbox(os.path.join(PR, "mailbox.png"))
    bollard(os.path.join(PR, "bollard.png"))
    baskets(os.path.join(PR, "baskets.png"))
    crates(os.path.join(PR, "crates.png"))
    ui_icons()
    gen_bridge()
    rickshaw(os.path.join(PR, "rickshaw.png"))
    well(os.path.join(PR, "well.png"))
    chicken(os.path.join(PR, "chicken.png"))
    grass_tuft(os.path.join(PR, "grass_tuft_1.png"), 1)
    grass_tuft(os.path.join(PR, "grass_tuft_2.png"), 2)


if __name__ == "__main__":
    gen_all()
