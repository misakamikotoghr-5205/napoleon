"""Pawnshop interior atlas + furniture, composed like mockup A2.

art/town/tiles/interior.png  256x32
Row 0 is the tiles the pawnshop map actually uses:
  floor_0 quiet boards, floor_1 door path, floor_2 darker staff floor,
  wall_2 / wall_0 / wall_1 stacked into a 3-tile back wall,
  counter_face / block_0 not walkable.

Furniture is transparent, lit from the top-left, and left-anchored
(see prop_meta.json) so a row of counters and the back shelf tile exactly.
"""
import os
import random
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C

TILE = 16
OUT_TILES = os.path.join(ROOT, "art", "town", "tiles", "interior.png")
OUT_PROPS = os.path.join(ROOT, "art", "town", "props")


# ---------------------------------------------------------------- tiles
def floor_planks(seed, shift=0, dark=False):
    """Quiet horizontal boards. One butt joint, almost no speckle."""
    hi, mid, lo = (C.wood1, C.wood0, C.dkbrown) if dark else (C.wood3, C.wood2, C.wood1)
    joint = C.dkbrown if dark else C.wood0
    c = Cv(16, 16, mid)
    for y in range(16):
        phase = (y + shift) % 4
        band = (y + shift) // 4
        butt = (2 + band * 5 + seed * 3) % 16
        for x in range(16):
            if phase == 3:
                col = joint
            elif phase == 0:
                col = hi
            elif phase == 2:
                col = lo
            else:
                col = mid
            if phase != 3 and x == butt:
                col = joint
            c.put(x, y, col)
    return c


def floor_rug():
    c = Cv(16, 16, C.seal_red)
    for y in range(16):
        for x in range(16):
            if x in (0, 15) or y in (0, 15):
                col = C.gold
            elif x in (1, 14) or y in (1, 14):
                col = C.dkred
            elif abs(x - 8) + abs(y - 8) <= 3:
                col = C.dkred
            else:
                col = C.seal_red
            c.put(x, y, col)
    return c


def wall_top():
    """Beam, then the same plaster the mid tile starts with."""
    c = Cv(16, 16, C.ww1)
    for y in range(16):
        for x in range(16):
            if y == 0:
                col = C.dkbrown
            elif y < 4:
                col = C.wood1 if x % 2 == 0 else C.wood0
            elif y == 4:
                col = C.wood0
            elif y == 5:
                col = C.ww2
            else:
                col = C.ww1 if (x + y) % 9 else C.ww2
            c.put(x, y, col)
    return c


def wall_mid(dark=False):
    a, b = (C.ww2, C.ww3) if dark else (C.ww1, C.ww2)
    c = Cv(16, 16, a)
    for y in range(16):
        for x in range(16):
            c.put(x, y, a if (x * 2 + y) % 9 else b)
    return c


def wall_base():
    """Plaster over a wood wainscot, so three stacked tiles read as one wall."""
    c = wall_mid(False)
    for y in range(8, 16):
        for x in range(16):
            phase = x % 4
            if phase == 3:
                col = C.wood0
            elif phase == 0:
                col = C.wood3
            else:
                col = C.wood1
            c.put(x, y, col)
    c.hline(0, 15, 7, C.wood2)
    c.hline(0, 15, 8, C.wood0)
    return c


def wall_side():
    c = Cv(16, 16, C.wood1)
    for y in range(16):
        for x in range(16):
            if x in (0, 15):
                col = C.dkbrown
            elif x == 1:
                col = C.wood3
            elif x >= 13:
                col = C.wood0
            elif y % 8 == 0:
                col = C.wood0
            else:
                col = C.wood1
            c.put(x, y, col)
    return c


def tile_counter_top():
    return floor_planks(9, 0, False)


def tile_counter_face():
    c = Cv(16, 16, C.wood0)
    for y in range(16):
        for x in range(16):
            col = C.wood0
            if y == 0:
                col = C.gold
            elif y == 1:
                col = C.wood1
            elif y >= 14:
                col = C.dkbrown
            elif x % 8 == 0:
                col = C.dkbrown
            c.put(x, y, col)
    return c


def tile_block():
    """Dark plinth under shelves and at the counter returns. Not a speckled floor."""
    return floor_planks(7, 2, True)


def stamp(sheet, col, row, tile):
    ox, oy = col * TILE, row * TILE
    for y in range(TILE):
        for x in range(TILE):
            p = tile.get(x, y)
            if len(p) < 4 or p[3] == 0:
                p = C.wood1
            sheet.put(ox + x, oy + y, (p[0], p[1], p[2], 255))


def build_tiles():
    sheet = Cv(256, 32, C.wood1)
    row0 = [
        floor_planks(1, 0, False),
        floor_planks(2, 2, False),
        floor_planks(3, 0, True),
        floor_rug(),
        wall_mid(False),
        wall_base(),
        wall_side(),
        tile_counter_top(),
        tile_counter_face(),
        tile_block(),
        wall_top(),
        wall_mid(True),
        floor_planks(4, 1, False),
        floor_planks(5, 3, False),
        wall_base(),
        floor_planks(6, 1, True),
    ]
    row1 = []
    for i in range(16):
        row1.append(floor_planks(20 + i, shift=i % 4, dark=(i % 5 == 4)))
    for col, tile in enumerate(row0):
        stamp(sheet, col, 0, tile)
    for col, tile in enumerate(row1):
        stamp(sheet, col, 1, tile)
    return sheet


# ---------------------------------------------------------------- shared bits
def cloth(c, x, y, w, h, body, hi, dark, dot=None):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            col = body
            if xx == x or yy == y:
                col = hi
            if xx == x + w - 1 or yy == y + h - 1:
                col = dark
            c.put(xx, yy, col)
    mid = x + w // 2
    c.line(x + 1, y + 1, mid, y + h - 2, dark)
    c.line(x + w - 2, y + 1, mid, y + h - 2, dark)
    if dot is not None and w > 4:
        c.put(x + w - 3, y + 2, dot)


def jar(c, x, y, body, hi):
    c.rect(x + 1, y, 4, 2, hi)
    c.rect(x, y + 2, 6, 6, body)
    c.hline(x, x + 5, y + 2, hi)
    c.vline(x + 5, y + 2, y + 7, C.wood0)
    c.put(x + 2, y + 4, hi)


def box(c, x, y, w, h, body, hi, dark):
    c.rect(x, y, w, h, body)
    c.hline(x, x + w - 1, y, hi)
    c.vline(x, y, y + h - 1, hi)
    c.hline(x, x + w - 1, y + h - 1, dark)
    c.vline(x + w - 1, y, y + h - 1, dark)
    if w > 4:
        c.put(x + w // 2, y + h // 2, C.gold)


def books(c, x, y):
    cols = (C.indigo1, C.seal_red, C.wood2, C.indigo0, C.wood3)
    for i, col in enumerate(cols):
        c.vline(x + i, y, y + 7, col)
        c.put(x + i, y, C.paper if i % 2 == 0 else C.gold)


def vase(c, x, y, body=C.indigo1, hi=C.indigo2):
    c.hline(x + 1, x + 3, y, hi)
    c.rect(x + 1, y + 1, 3, 3, body)
    c.rect(x, y + 4, 5, 4, body)
    c.hline(x, x + 4, y + 7, C.indigo0)
    c.put(x + 2, y + 5, hi)


# ---------------------------------------------------------------- shelf
def prop_shelf():
    """One back-wall run: goods, 德厚当 plaque, 财神 niche. 208x50, left-anchored."""
    w, h = 208, 50
    c = Cv(w, h)
    # dark back so the bundles read
    c.rect(0, 0, w, h, C.wood0)
    for y in range(4, 43):
        for x in range(2, w - 2):
            if (x + y) % 7 == 0:
                c.put(x, y, C.dkbrown)
    # cornice
    c.rect(0, 0, w, 3, C.wood2)
    c.hline(0, w - 1, 0, C.wood3)
    c.hline(0, w - 1, 2, C.wood0)
    # side posts
    for px in (0, w - 3):
        c.rect(px, 0, 3, h, C.wood1)
        c.vline(px, 0, h - 1, C.wood3)
        c.vline(px + 2, 0, h - 1, C.wood0)
    boards = (12, 26, 40)
    # center bay is the shrine, not more bundles
    bays = ((4, 76), (132, 202))
    fills = (
        (
            (6, 4, "cloth", C.indigo1, C.indigo2, C.indigo0),
            (16, 4, "cloth", C.wood3, C.tan, C.wood1),
            (26, 4, "jar", C.wood2, C.tan),
            (34, 4, "cloth", C.seal_red, C.flame, C.dkred),
            (44, 4, "vase", C.indigo1, C.indigo2),
            (52, 4, "box", C.wood2, C.wood3),
            (62, 4, "cloth", C.indigo2, C.blue_hi, C.indigo0),
        ),
        (
            (6, 14, "books", None, None, None),
            (14, 14, "box", C.seal_red, C.flame),
            (24, 14, "cloth", C.indigo1, C.indigo2, C.indigo0),
            (34, 14, "vase", C.ww1, C.seal_red),
            (42, 14, "jar", C.wood3, C.tan),
            (50, 14, "cloth", C.wood3, C.tan, C.wood1),
            (60, 14, "box", C.gold, C.lamp),
        ),
        (
            (6, 28, "cloth", C.indigo0, C.indigo2, C.indigo1),
            (16, 28, "cloth", C.seal_red, C.flame, C.dkred),
            (26, 28, "books", None, None, None),
            (34, 28, "jar", C.wood1, C.wood3),
            (42, 28, "cloth", C.wood3, C.tan, C.wood0),
            (52, 28, "vase", C.indigo0, C.indigo2),
            (60, 28, "box", C.wood1, C.wood3),
        ),
    )
    for (x0, _x1), row in ((bays[0], 0), (bays[1], 0)):
        pass
    for bi, base in enumerate(boards):
        for x0, _x1 in bays:
            pack = fills[bi]
            # right bay mirrors the same recipe, shifted
            origin = x0
            for item in pack:
                dx, kind = item[0], item[2]
                x = origin + dx
                y = base - 8
                if kind == "cloth":
                    cloth(c, x, y, 9, 7, item[3], item[4], item[5], C.paper if bi != 1 else None)
                elif kind == "jar":
                    jar(c, x, y + 1, item[3], item[4])
                elif kind == "box":
                    box(c, x, y + 2, 8, 6, item[3], item[4], C.dkbrown)
                elif kind == "books":
                    books(c, x, y + 1)
                elif kind == "vase":
                    vase(c, x, y, item[3], item[4])
    # boards over the feet of the goods
    for yb in boards:
        c.hline(3, 76, yb, C.wood3)
        c.hline(3, 76, yb + 1, C.wood1)
        c.hline(132, w - 4, yb, C.wood3)
        c.hline(132, w - 4, yb + 1, C.wood1)
    # shrine bay
    sx0, sx1 = 80, 128
    c.rect(sx0, 4, sx1 - sx0, 38, C.wood0)
    # plaque
    c.rect(sx0 + 8, 5, 32, 12, C.black)
    c.frame(sx0 + 8, 5, 32, 12, C.gold)
    try:
        c.text(sx0 + 10, 6, "德厚当", C.gold, 11)
    except Exception:
        c.hline(sx0 + 12, sx0 + 28, 10, C.gold)
    # niche
    c.rect(sx0 + 10, 19, 28, 16, C.dkred)
    c.rect(sx0 + 8, 17, 32, 3, C.wood2)
    c.hline(sx0 + 8, sx0 + 39, 17, C.wood3)
    c.rect(sx0 + 18, 22, 6, 8, C.seal_red)
    c.rect(sx0 + 19, 20, 4, 3, C.gold)
    c.put(sx0 + 20, 23, C.skin)
    c.put(sx0 + 21, 23, C.skin)
    for kx in (sx0 + 13, sx0 + 32):
        c.rect(kx, 28, 2, 5, C.seal_red)
        c.put(kx, 27, C.flame)
        c.put(kx + 1, 26, C.lamp)
    # divider posts around the shrine
    for px in (78, 128):
        c.vline(px, 3, 42, C.wood1)
        c.vline(px + 1, 3, 42, C.wood0)
    # drawer plinth
    c.rect(2, 43, w - 4, 7, C.wood1)
    c.hline(2, w - 3, 43, C.wood3)
    for dx in range(6, w - 12, 14):
        c.rect(dx, 45, 10, 3, C.wood2)
        c.hline(dx, dx + 9, 45, C.wood3)
        c.put(dx + 5, 46, C.gold)
    c.hline(0, w - 1, h - 1, C.dkbrown)
    c.outline(C.dkbrown)
    return c


# ---------------------------------------------------------------- counter
def _counter_top(c, x0, x1):
    for y in range(8, 16):
        for x in range(x0, x1 + 1):
            if y == 8 or x == x0:
                col = C.tan
            elif y == 15:
                col = C.wood1
            elif (y % 2) == 0:
                col = C.wood3
            else:
                col = C.wood2
            c.put(x, y, col)
    c.hline(x0, x1, 16, C.tan)
    c.hline(x0, x1, 17, C.gold)


def _counter_face(c, x0, x1):
    for y in range(18, 42):
        for x in range(x0, x1 + 1):
            col = C.wood0
            if x == x0:
                col = C.wood1
            elif x == x1 or y >= 40:
                col = C.dkbrown
            c.put(x, y, col)
    # raised panels
    span = x1 - x0 - 4
    if span < 8:
        return
    n = max(1, span // 18)
    pw = (span - (n - 1) * 2) // n
    px = x0 + 3
    for _ in range(n):
        c.rect(px, 22, pw, 14, C.wood1)
        c.hline(px, px + pw - 1, 22, C.wood2)
        c.vline(px, 22, 35, C.wood2)
        c.hline(px, px + pw - 1, 35, C.dkbrown)
        c.put(px + 2, 24, C.gold)
        c.put(px + pw - 3, 33, C.gold)
        px += pw + 2


def _abacus(c, x, y):
    c.rect(x, y, 22, 7, C.wood1)
    c.hline(x, x + 21, y, C.wood3)
    c.hline(x, x + 21, y + 6, C.wood0)
    for r in range(4):
        c.hline(x + 2, x + 19, y + 1 + r, C.wood0)
        for k in range(5):
            col = C.wood0 if k < 2 else C.tan
            c.put(x + 3 + k * 3, y + 1 + r, col)


def _ledger(c, x, y):
    c.rect(x, y, 8, 7, C.paper)
    c.rect(x + 8, y, 8, 7, C.paper_old)
    c.vline(x + 8, y, y + 6, C.wood0)
    for yy in (y + 2, y + 4):
        c.hline(x + 1, x + 6, yy, C.wall1)
        c.hline(x + 10, x + 14, yy, C.wall1)
    c.put(x + 2, y + 5, C.seal_red)


def _lamp(c, x, lip):
    # foot on the lip, glass and flame above it
    c.hline(x, x + 8, lip, C.wood1)
    c.rect(x + 1, lip - 4, 7, 4, C.gold)
    c.hline(x + 1, x + 7, lip - 4, C.lamp)
    c.rect(x + 3, lip - 12, 3, 8, C.fog)
    c.vline(x + 3, lip - 12, lip - 5, C.white)
    c.vline(x + 5, lip - 12, lip - 5, C.wall2)
    c.put(x + 4, lip - 14, C.flame)
    c.put(x + 4, lip - 13, C.lamp)
    c.put(x + 5, lip - 13, C.flame)
    c.put(x + 4, lip - 8, C.flame)


def _magnifier(c, x, y):
    c.ellipse(x + 3, y + 3, 3, 2, C.fog)
    c.ellipse(x + 3, y + 3, 3, 2, C.wood1, filled=False)
    c.line(x + 5, y + 5, x + 9, y + 7, C.wood2)


def _bundle_top(c, x, y):
    cloth(c, x, y, 12, 7, C.indigo1, C.indigo2, C.indigo0, C.paper)


def _chest(c, x, y):
    """账箱, lid ajar, telegraph key showing."""
    c.rect(x, y + 3, 16, 8, C.wood1)
    c.hline(x, x + 15, y + 3, C.wood3)
    c.hline(x, x + 15, y + 10, C.dkbrown)
    c.rect(x + 1, y, 14, 4, C.wood2)  # lid tilted up
    c.hline(x + 1, x + 14, y, C.wood3)
    c.rect(x + 3, y + 5, 8, 4, C.wood0)  # dark inside
    c.hline(x + 4, x + 9, y + 6, C.gold)  # key lever
    c.put(x + 4, y + 5, C.lamp)
    c.put(x + 8, y + 7, C.gold)
    c.put(x + 12, y + 6, C.gold)  # latch


def _seal_dang(c, x, y):
    c.rect(x, y, 12, 12, C.seal_red)
    c.hline(x, x + 11, y, C.flame)
    c.vline(x, y, y + 11, C.flame)
    try:
        c.text(x + 1, y + 1, "当", C.black, 11)
    except Exception:
        c.rect(x + 3, y + 3, 6, 6, C.black)


def prop_counter(decor):
    w, h = 64, 44
    c = Cv(w, h)
    _counter_top(c, 0, w - 1)
    _counter_face(c, 0, w - 1)
    if decor == "seal":
        _seal_dang(c, 8, 23)
        _bundle_top(c, 40, 8)
    elif decor == "tools":
        _ledger(c, 8, 8)
        _abacus(c, 28, 8)
    elif decor == "lamp":
        _lamp(c, 10, 16)
        _magnifier(c, 28, 9)
        _bundle_top(c, 44, 8)
    c.outline(C.dkbrown)
    return c


def prop_counter_gate():
    """Left 16px is the 腰门; the next two tiles hold the 账箱. 48px so the east passage stays clear."""
    w, h = 48, 44
    c = Cv(w, h)
    # opening above the gate, so the staff floor shows through
    _counter_top(c, 18, w - 1)
    _counter_face(c, 18, w - 1)
    # posts of the gate
    c.rect(0, 16, 3, 26, C.wood1)
    c.vline(0, 16, 41, C.wood3)
    c.rect(14, 16, 3, 26, C.wood1)
    c.vline(16, 16, 41, C.wood0)
    c.hline(0, 16, 16, C.wood2)
    # swing leaves, waist height
    for x0, body in ((3, C.wood2), (9, C.wood1)):
        c.rect(x0, 26, 5, 15, body)
        c.hline(x0, x0 + 4, 26, C.wood3)
        c.hline(x0, x0 + 4, 40, C.dkbrown)
    c.put(7, 32, C.gold)
    c.put(10, 32, C.gold)
    _chest(c, 26, 6)
    c.outline(C.dkbrown)
    return c


# ---------------------------------------------------------------- other props
def prop_stairs():
    c = Cv(16, 46)
    n = 7
    for i in range(n):
        y = 2 + i * 6
        x = 1 + (n - 1 - i) // 2
        c.rect(x, y, 12, 2, C.wood3)
        c.hline(x, x + 11, y, C.tan)
        c.rect(x, y + 2, 12, 4, C.wood1)
        c.vline(x + 11, y + 2, y + 5, C.dkbrown)
    c.vline(1, 2, 44, C.wood2)
    c.outline(C.dkbrown)
    return c


def prop_bed():
    c = Cv(32, 28)
    c.rect(2, 1, 28, 7, C.wood2)
    c.hline(2, 29, 1, C.wood3)
    c.vline(29, 1, 7, C.wood0)
    c.rect(6, 4, 8, 3, C.paper)
    c.rect(16, 4, 8, 3, C.paper_old)
    c.rect(4, 8, 24, 14, C.wood1)
    for y in range(10, 20):
        for x in range(6, 26):
            col = C.indigo1
            if (x + y) % 5 == 0:
                col = C.indigo0
            elif (x * 2 + y) % 7 == 0:
                col = C.indigo2
            c.put(x, y, col)
    c.rect(4, 20, 24, 4, C.wood2)
    c.hline(4, 27, 20, C.wood3)
    c.hline(4, 27, 23, C.wood0)
    c.rect(4, 24, 3, 3, C.wood1)
    c.rect(25, 24, 3, 3, C.wood1)
    c.outline(C.dkbrown)
    return c


def prop_door():
    """Indigo 门帘 into the storeroom."""
    c = Cv(32, 46)
    c.rect(2, 4, 28, 40, C.dkbrown)
    c.rect(0, 1, 32, 4, C.wood1)
    c.hline(0, 31, 1, C.wood3)
    mid = 16
    for x in range(4, 28):
        if abs(x - mid) <= 1:
            continue
        hang = 40 if abs(x - mid) > 4 else 38
        for y in range(6, hang):
            col = C.indigo1
            if (x % 4) == 0:
                col = C.indigo0
            elif (x % 4) == 1:
                col = C.indigo2
            c.put(x, y, col)
    rnd = random.Random(5)
    for _ in range(28):
        x = rnd.randint(5, 26)
        y = rnd.randint(10, 34)
        if abs(x - mid) > 1:
            c.put(x, y, C.ww1)
    c.rect(4, 6, 24, 3, C.indigo0)
    c.hline(4, 27, 42, C.wood2)
    try:
        c.rect(11, 8, 10, 10, C.paper)
        c.text(12, 9, "库", C.dkbrown, 10)
    except Exception:
        pass
    c.outline(C.dkbrown)
    return c


def prop_calendar():
    c = Cv(16, 32)
    c.rect(1, 1, 14, 22, C.paper_hi)
    # qipao poster
    c.rect(5, 4, 6, 8, C.seal_red)
    c.rect(6, 3, 4, 3, C.skin)
    c.put(7, 4, C.hair)
    c.put(8, 4, C.hair)
    c.rect(4, 12, 8, 6, C.seal_red)
    c.hline(6, 9, 14, C.gold)
    # tear-off pad
    c.rect(2, 20, 12, 10, C.paper)
    c.hline(2, 13, 20, C.paper_old)
    for yy in (23, 26):
        c.hline(4, 11, yy, C.wall1)
    c.put(10, 27, C.seal_red)
    c.outline(C.dkbrown)
    return c


def prop_back_door():
    c = Cv(16, 32)
    c.rect(1, 1, 14, 30, C.wood1)
    c.rect(4, 4, 8, 22, C.dkbrown)
    c.hline(1, 14, 1, C.wood3)
    c.vline(1, 1, 30, C.wood3)
    c.vline(14, 1, 30, C.wood0)
    c.put(11, 16, C.gold)
    c.hline(3, 12, 28, C.wood2)
    c.outline(C.dkbrown)
    return c


def prop_bench():
    c = Cv(48, 14)
    c.rect(2, 2, 44, 5, C.wood2)
    c.hline(2, 45, 2, C.wood3)
    c.hline(2, 45, 6, C.wood0)
    for x in (4, 40):
        c.rect(x, 7, 3, 5, C.wood1)
        c.vline(x + 2, 7, 11, C.wood0)
    c.outline(C.dkbrown)
    return c


def prop_rack():
    c = Cv(32, 40)
    c.vline(4, 4, 36, C.wood1)
    c.vline(27, 4, 36, C.wood0)
    c.hline(4, 27, 6, C.wood2)
    # coat
    c.rect(6, 7, 8, 16, C.indigo0)
    c.hline(6, 13, 7, C.indigo2)
    c.rect(8, 22, 4, 8, C.indigo1)
    # qipao
    c.rect(16, 8, 8, 18, C.seal_red)
    c.hline(16, 23, 8, C.flame)
    c.vline(20, 12, 22, C.gold)
    # tags
    c.rect(8, 4, 5, 4, C.paper)
    c.put(10, 5, C.seal_red)
    c.rect(18, 4, 5, 4, C.paper)
    c.put(20, 5, C.seal_red)
    c.rect(3, 36, 4, 3, C.wood1)
    c.rect(25, 36, 4, 3, C.wood1)
    c.outline(C.dkbrown)
    return c


def prop_plant():
    c = Cv(14, 26)
    c.rect(3, 18, 8, 6, C.wood1)
    c.hline(2, 11, 18, C.wood3)
    c.hline(3, 10, 23, C.wood0)
    for x, y in ((4, 16), (6, 14), (7, 10), (8, 15), (5, 8), (9, 12), (7, 6)):
        c.put(x, y, C.g2 if y < 12 else C.g4)
        c.put(x + 1, y, C.g4)
    c.vline(7, 8, 18, C.g2)
    c.outline(C.dkbrown)
    return c


def prop_broom():
    c = Cv(8, 22)
    c.line(3, 1, 4, 12, C.wood3)
    for x in range(1, 7):
        c.line(4, 12, x, 20, C.wood1)
    c.put(2, 19, C.tan)
    c.put(5, 20, C.wood2)
    c.outline(C.dkbrown)
    return c


def prop_trunk():
    c = Cv(16, 14)
    c.rect(1, 3, 14, 9, C.wood1)
    c.hline(1, 14, 3, C.wood3)
    c.hline(1, 14, 11, C.dkbrown)
    c.rect(6, 6, 4, 3, C.gold)
    c.put(7, 7, C.dkbrown)
    c.hline(2, 13, 5, C.wood2)
    c.outline(C.dkbrown)
    return c


def prop_lamp():
    c = Cv(12, 22)
    _lamp(c, 1, 18)
    c.outline(C.dkbrown)
    return c


def prop_telegraph():
    """Kept as its own sprite: a locked 账箱 with the key showing."""
    c = Cv(20, 16)
    _chest(c, 2, 3)
    c.outline(C.dkbrown)
    return c


def main():
    os.makedirs(os.path.dirname(OUT_TILES), exist_ok=True)
    os.makedirs(OUT_PROPS, exist_ok=True)
    sheet = build_tiles()
    if sheet.w != 256 or sheet.h != 32:
        print("INTERIOR_BAD_SIZE %d %d" % (sheet.w, sheet.h))
        return 1
    alpha = sheet.img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo != 255 or hi != 255:
        print("INTERIOR_ALPHA %s %s" % (lo, hi))
        return 1
    sheet.save(OUT_TILES)
    props = (
        ("shelf.png", prop_shelf()),
        ("counter.png", prop_counter("seal")),
        ("counter_mid.png", prop_counter("tools")),
        ("counter_lamp.png", prop_counter("lamp")),
        ("counter_gate.png", prop_counter_gate()),
        ("stairs.png", prop_stairs()),
        ("bed.png", prop_bed()),
        ("storeroom_door.png", prop_door()),
        ("calendar.png", prop_calendar()),
        ("back_door.png", prop_back_door()),
        ("pawn_bench.png", prop_bench()),
        ("clothes_rack.png", prop_rack()),
        ("plant.png", prop_plant()),
        ("broom.png", prop_broom()),
        ("trunk.png", prop_trunk()),
        ("lamp.png", prop_lamp()),
        ("telegraph.png", prop_telegraph()),
    )
    for name, cv in props:
        cv.save(os.path.join(OUT_PROPS, name))
        print(name, cv.w, cv.h)
    print("INTERIOR_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
