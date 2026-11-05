"""16x16 town ground atlas: art/town/tiles/town.png (256x48, 16 cols x 3 rows).

Every pixel is opaque. Imported road / water / embank helpers are blitted into
16x16 cells; anything transparent is filled so the sheet has no alpha holes.
"""
import os
import sys
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C
from gen_tiles_props import road_tile, water_tile, embank_tile

OUT = os.path.join(ROOT, "art", "town", "tiles", "town.png")


def ensure16(src):
    """Blit src into a fresh opaque 16x16 cell (crop if larger)."""
    out = Cv(16, 16, C.st1)
    w = min(16, src.w)
    h = min(16, src.h)
    for y in range(h):
        for x in range(w):
            p = src.get(x, y)
            if not p or p[3] == 0:
                continue
            out.put(x, y, (p[0], p[1], p[2], 255))
    return out


def flip_v(src):
    src = ensure16(src)
    out = Cv(16, 16, C.st1)
    for y in range(16):
        for x in range(16):
            out.put(x, 15 - y, src.get(x, y))
    return out


def dirt_tile(seed):
    """Packed earth with pebbles. dirt_1 is seed 9."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.dirt1)
    for y in range(16):
        for x in range(16):
            r = rnd.random()
            if r < 0.16:
                c.put(x, y, C.dirt0)
            elif r < 0.34:
                c.put(x, y, C.dirt2)
            elif r < 0.40:
                c.put(x, y, C.wood1)
    for _ in range(3):
        x, y = rnd.randint(0, 13), rnd.randint(0, 13)
        c.rect(x, y, 3, 2, C.dirt0)
        c.put(x + 1, y, C.dirt2)
    for _ in range(5):
        x, y = rnd.randint(0, 14), rnd.randint(1, 14)
        c.put(x, y, C.wood1)
        c.put(x + 1, y, C.dirt0)
        c.put(x, y - 1, C.dirt2)
    return c


def grass_tile(seed, flowers=0):
    rnd = random.Random(seed)
    c = Cv(16, 16, C.g2)
    c.noise(0, 0, 16, 16, [C.g1, C.g3, C.g1], 0.36, rnd)
    for _ in range(10):
        x = rnd.randint(0, 15)
        y = rnd.randint(1, 15)
        h = rnd.randint(2, 3)
        for k in range(h):
            yy = y - k
            if yy < 0:
                break
            c.put(x, yy, C.g3 if k == h - 1 else C.g1)
        if x + 1 < 16 and rnd.random() < 0.45:
            c.put(x + 1, y, C.g2)
    # exactly `flowers` single pixels, one C.flower and one C.lamp when two
    cols = [C.flower, C.lamp]
    placed = []
    guard = 0
    while len(placed) < flowers and guard < 60:
        guard += 1
        x, y = rnd.randint(1, 14), rnd.randint(1, 14)
        if (x, y) in placed:
            continue
        if any(abs(x - px) + abs(y - py) < 3 for px, py in placed):
            continue
        c.put(x, y, cols[len(placed) % 2])
        placed.append((x, y))
    return c


def bank_w(seed=43):
    """Vertical canal edge: stone land on the LEFT, water on the right."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.wa1)
    # coping
    c.rect(0, 0, 3, 16, C.st3)
    c.vline(0, 0, 15, C.st4)
    c.vline(2, 0, 15, C.st2)
    for y in (0, 8):
        c.hline(0, 2, y, C.st1)
    c.put(1, rnd.randint(3, 12), C.st4)
    # lip shadow
    c.vline(3, 0, 15, C.st0)
    # two courses of wall blocks
    c.rect(4, 0, 8, 16, C.st1)
    for col_i, x0 in enumerate((4, 8)):
        off = 0 if col_i == 0 else 4
        for by in range(-8 + off, 16, 8):
            y0 = max(0, by + 1)
            y1 = min(15, by + 7)
            if y1 <= y0:
                continue
            base = C.st2 if ((col_i + by) // 4) % 2 == 0 else C.st1
            c.rect(x0, y0, 3, y1 - y0, base)
            c.vline(x0, y0, y1 - 1, C.st3)
        c.vline(x0 + 3, 0, 15, C.st0)
    for _ in range(5):
        c.put(rnd.randint(4, 10), rnd.randint(0, 15), rnd.choice([C.g1, C.g2, C.g2]))
    # damp streaks down the wall
    for _ in range(2):
        x = rnd.randint(5, 10)
        for y in range(rnd.randint(2, 6), 12):
            if rnd.random() < 0.65:
                c.put(x, y, C.wa0 if rnd.random() < 0.4 else C.st1)
    # waterline
    c.rect(12, 0, 4, 16, C.wa1)
    c.vline(12, 0, 15, C.wa0)
    c.vline(13, 0, 15, C.wa0)
    for y in range(16):
        if rnd.random() < 0.35:
            c.put(14, y, C.wa2)
        if rnd.random() < 0.18:
            c.put(15, y, C.wa3)
        if rnd.random() < 0.12:
            c.put(13, y, C.g1)
    for _ in range(3):
        y = rnd.randint(0, 15)
        c.hline(14, 15, y, C.wa3)
    return c


def dock_tile(seed, wet=False):
    """Walkable stone steps. wet=True darkens the lower treads."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.st2)
    tones = [C.st3, C.st3, C.st2, C.st1] if not wet else [C.st3, C.st2, C.st1, C.st1]
    for i, y in enumerate((0, 4, 8, 12)):
        base = tones[i]
        c.rect(0, y, 16, 4, base)
        c.hline(0, 15, y, C.st4 if base != C.st1 else C.st3)
        joint = C.wa0 if wet and i >= 2 else C.st1
        c.hline(0, 15, y + 3, joint)
        off = 3 if i % 2 == 0 else 7
        c.vline(off, y + 1, y + 2, C.st1)
        c.vline((off + 8) % 16, y + 1, y + 2, C.st1)
        for _ in range(3):
            c.put(rnd.randint(0, 15), y + rnd.randint(1, 2), rnd.choice([C.st1, C.st2, C.st3]))
    if wet:
        for y in range(10, 16):
            for x in range(16):
                if rnd.random() < 0.12 + (y - 10) * 0.07:
                    c.put(x, y, C.wa0 if y >= 14 else C.wa1)
        c.hline(0, 15, 15, C.wa0)
        c.hline(1, 14, 13, C.wa1)
    return c


def bridge_deck(seed=91):
    """Granite slabs with horizontal joints."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.st2)
    slabs = [C.st3, C.st4, C.st2, C.st3]
    for i, y in enumerate((0, 4, 8, 12)):
        base = slabs[i]
        c.rect(0, y, 16, 4, base)
        c.hline(0, 15, y, C.st4 if base != C.st4 else C.st3)
        c.hline(0, 15, y + 3, C.st1)  # horizontal joint
        vx = 6 if i % 2 == 0 else 11
        c.vline(vx, y + 1, y + 2, C.st1)
        for _ in range(4):
            xx = rnd.randint(0, 15)
            if xx == vx:
                continue
            c.put(xx, y + rnd.randint(1, 2), rnd.choice([C.st2, C.st3, C.st4]))
    return c


def bridge_rail(seed=17):
    """Walkable deck with a stone parapet hinted on the top 6 rows."""
    rnd = random.Random(seed)
    c = bridge_deck(seed + 3)
    c.rect(0, 0, 16, 6, C.st2)
    c.hline(0, 15, 0, C.st4)
    c.hline(0, 15, 1, C.st3)
    for x in (0, 7, 13):
        c.rect(x, 0, 3, 6, C.st3)
        c.vline(x, 0, 5, C.st4)
        c.vline(x + 2, 1, 5, C.st1)
        c.put(x + 1, 0, C.st4)
    # recessed panels between posts — still stone, not empty
    c.rect(3, 2, 4, 3, C.st1)
    c.hline(3, 6, 2, C.st2)
    c.hline(3, 6, 4, C.st2)
    c.rect(10, 2, 3, 3, C.st1)
    c.hline(10, 12, 2, C.st2)
    c.hline(10, 12, 4, C.st2)
    c.hline(0, 15, 5, C.st0)  # shadow where the rail meets the deck
    # deck edge just under the rail
    c.hline(0, 15, 6, C.st4)
    c.put(rnd.randint(1, 5), rnd.randint(2, 4), C.g2)
    c.put(rnd.randint(8, 14), 4, C.g1)
    return c


def bridge_arch(seed=5):
    """Opaque arch mouth: dark water inside a stone rim."""
    rnd = random.Random(seed)
    c = Cv(16, 16, C.st2)
    for y in range(16):
        off = 4 if (y // 4) % 2 else 0
        tone = C.st3 if (y // 4) % 2 == 0 else C.st2
        for x in range(16):
            c.put(x, y, C.st1 if (x + off) % 8 == 0 or y % 4 == 3 else tone)
    c.hline(0, 15, 0, C.st4)
    # semicircular mouth opening toward the bottom of the tile
    cx, cy, radius = 7.5, 15.2, 9.2
    for y in range(16):
        for x in range(16):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d < radius - 1.6:
                c.put(x, y, C.wa0 if d > radius * 0.52 else C.wa1)
            elif d < radius:
                c.put(x, y, C.st1)
    # keystone
    c.put(7, 5, C.st4)
    c.put(8, 5, C.st3)
    c.put(rnd.choice([1, 2, 14]), rnd.randint(1, 3), C.g2)
    return c


def stamp(sheet, col, row, tile):
    tile = ensure16(tile)
    ox, oy = col * 16, row * 16
    for y in range(16):
        for x in range(16):
            p = tile.get(x, y)
            if p[3] == 0:
                p = C.st1
            sheet.put(ox + x, oy + y, (p[0], p[1], p[2], 255))


def build():
    sheet = Cv(256, 48, C.st1)

    # row 0 — road, dirt, grass
    stamp(sheet, 0, 0, road_tile(1))
    stamp(sheet, 1, 0, road_tile(2, crack=True))
    stamp(sheet, 2, 0, road_tile(3, moss=0.25))
    stamp(sheet, 3, 0, road_tile(4, puddle=True))
    stamp(sheet, 4, 0, road_tile(5, wear=0.4))
    stamp(sheet, 5, 0, dirt_tile(3))
    stamp(sheet, 6, 0, dirt_tile(9))
    stamp(sheet, 7, 0, grass_tile(20))
    stamp(sheet, 8, 0, grass_tile(21))
    stamp(sheet, 9, 0, grass_tile(22, flowers=2))
    road_rows = (
        ((0, 7, (15,)), (8, 7, (7, 15))),
        ((0, 7, (7, 15)), (8, 7, (15,))),
        ((0, 7, (11, 15)), (8, 7, (4, 15))),
        ((0, 15, (15,)),),
        ((0, 7, (5, 15)), (8, 7, (11, 15))),
        ((0, 5, (15,)), (6, 5, (8, 15)), (11, 5, (3, 15))),
    )
    road_kw = (
        {},
        {"crack": True},
        {"moss": 0.18},
        {"wear": 0.3},
        {"crack": True, "moss": 0.12},
        {"wear": 0.22},
    )
    for i, seed in enumerate(range(11, 17)):
        stamp(sheet, 10 + i, 0, road_tile(seed, rows=road_rows[i], **road_kw[i]))

    # row 1 — water, banks, dock, bridge
    stamp(sheet, 0, 1, water_tile(1))
    stamp(sheet, 1, 1, water_tile(2))
    bank_n = embank_tile(1)
    stamp(sheet, 2, 1, bank_n)
    stamp(sheet, 3, 1, embank_tile(2, moss=0.3))
    stamp(sheet, 4, 1, flip_v(bank_n))
    west = bank_w(43)
    stamp(sheet, 5, 1, west)
    stamp(sheet, 6, 1, west.mirror_x())
    stamp(sheet, 7, 1, dock_tile(70, wet=False))
    stamp(sheet, 8, 1, dock_tile(71, wet=True))
    stamp(sheet, 9, 1, bridge_deck(91))
    stamp(sheet, 10, 1, bridge_rail(17))
    stamp(sheet, 11, 1, bridge_arch(5))
    for i, seed in enumerate(range(3, 7)):
        stamp(sheet, 12 + i, 1, water_tile(seed))

    # row 2 — extra roads, grass, dirt, water
    stamp(sheet, 0, 2, road_tile(21, rows=((0, 7, (9, 15)), (8, 7, (4, 15))), crack=True))
    stamp(sheet, 1, 2, road_tile(22, rows=((0, 5, (15,)), (6, 6, (6, 15)), (12, 4, (10, 15))), moss=0.22))
    stamp(sheet, 2, 2, road_tile(23, wear=0.45, moss=0.1))
    stamp(sheet, 3, 2, road_tile(24, rows=((0, 15, (8, 15)),), puddle=True))
    for i, seed in enumerate((30, 31, 32, 33)):
        stamp(sheet, 4 + i, 2, grass_tile(seed))
    for i, seed in enumerate((41, 42, 43, 44)):
        stamp(sheet, 8 + i, 2, dirt_tile(seed))
    for i, seed in enumerate((7, 8, 9, 10)):
        stamp(sheet, 12 + i, 2, water_tile(seed))

    # guarantee opacity
    for y in range(sheet.h):
        for x in range(sheet.w):
            p = sheet.get(x, y)
            if len(p) < 4 or p[3] != 255:
                sheet.put(x, y, C.st1 if (len(p) < 4 or p[3] == 0) else (p[0], p[1], p[2], 255))
    return sheet


def main():
    sheet = build()
    if sheet.w != 256 or sheet.h != 48:
        print("TILES_TOWN_BAD_SIZE %d %d" % (sheet.w, sheet.h))
        return 1
    alpha = sheet.img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo != 255 or hi != 255:
        print("TILES_TOWN_ALPHA %s %s" % (lo, hi))
        return 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("TILES_TOWN_OK 256 48")
    return 0


if __name__ == "__main__":
    sys.exit(main())
