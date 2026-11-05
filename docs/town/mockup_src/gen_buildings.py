"""3/4 top-down (Stardew-like) Jiangnan buildings for 青溪镇.

Every building PNG is anchored bottom-left: its last row is the ground line
(front edge of the stone step). Place with  y = street_line - h.
"""
import os
import random
from pix import Cv, C, ASSETS, mix, alpha, font_mask, desaturate

OUT = os.path.join(ASSETS, "buildings")
OV = 4          # eave overhang each side
UP = 6          # head-room margin for upturned eaves / ridge ornaments


# ------------------------------------------------------------------ roof
def roof_layer(w, h, seed, ridge=True, upturn=3, moss=0.08, grass=True, light=0):
    """Return Cv (w, h+UP) containing a tiled roof seen from front-above."""
    rnd = random.Random(seed)
    r = Cv(w, h)
    pal = [C.rf4, C.rf3, C.rf2, C.rf1, C.rf0]
    top = 4 if ridge else 1
    eave = h - 4
    for y in range(h):
        for x in range(w):
            k = x % 4
            if ridge and y < 4:
                col = [C.rf3, C.rf2, C.rf1, C.rf0][y]
                if y in (1, 2) and x % 5 == 2 and 3 < x < w - 4:
                    col = C.rf0
                r.put(x, y, col)
                continue
            if y >= eave:
                yy = y - eave
                if yy == 0:
                    col = C.rf1
                elif yy in (1, 2):
                    disc = [[C.rf3, C.rf4, C.rf3, C.rf0], [C.rf2, C.rf3, C.rf1, C.rf0]][yy - 1]
                    col = disc[k]
                else:
                    col = C.rf0
                r.put(x, y, col)
                continue
            # tile field
            t = (y - top) / max(1, eave - top)
            lip = (y - top) % 4 == 3
            base = [1, 2, 3, 4][k]  # index into pal: cover-tile hi, mid, shade, channel
            if lip:
                base = [0, 1, 2, 4][k]
            # gentle light gradient: brighter near the ridge
            if t < 0.3 and k in (1, 2) and (x + y) % 2 == 0:
                base -= 1
            if t > 0.75 and k in (0, 1) and (x + y) % 2 == 1:
                base += 1
            base = max(0, min(4, base - light))
            col = pal[base]
            if k == 3 and t > 0.45 and rnd.random() < moss:
                col = rnd.choice([C.g1, C.g1, C.g2])
            if rnd.random() < 0.012 and k in (0, 1):
                col = C.rf4
            r.put(x, y, col)
    # ridge ornaments + 瓦松 tufts
    if ridge and grass:
        for _ in range(max(1, w // 40)):
            gx = rnd.randint(8, w - 9)
            r.put(gx, 0, C.g3); r.put(gx + 1, 0, C.g2)
    out = Cv(w, h + UP)
    # column shift = upturned ends
    L = min(10, w // 4)
    for x in range(w):
        d = min(x, w - 1 - x)
        s = 0
        if d < L:
            s = int(round(upturn * ((L - d) / L) ** 2))
        for y in range(h):
            p = r.get(x, y)
            if p[3]:
                out.put(x, y + UP - s, p)
        # thicken the curling eave tip
        if d < 2:
            out.put(x, h + UP - s - 5, C.rf1)
            out.put(x, h + UP - s - 6, C.rf2)
    if ridge:
        # ridge-end curls (鸱尾 / 哺鸡脊-ish)
        for side in (0, 1):
            x = 1 if side == 0 else w - 2
            dx = 1 if side == 0 else -1
            s = int(round(upturn * 1.0))
            base_y = UP - s
            for i, (ox, oy) in enumerate(((0, -1), (0, -2), (dx, -3), (2 * dx, -3), (2 * dx, -2))):
                out.put(x + ox, base_y + oy, C.rf1 if i < 4 else C.rf2)
            out.put(x, base_y - 3, C.rf3)
    return out


def under_eave_shadow(c, x, y, w, rows=(0.55, 0.38, 0.22, 0.1)):
    for i, a in enumerate(rows):
        for xx in range(x, x + w):
            p = c.get(xx, y + i)
            if p[3]:
                c.put(xx, y + i, mix(p, C.black, a))


def rafters(c, x, y, w):
    c.rect(x, y, w, 2, C.wood0)
    for xx in range(x + 1, x + w - 1, 3):
        c.put(xx, y, C.wood2)
        c.put(xx, y + 1, C.wood1)


# ------------------------------------------------------------------ walls
def plaster(c, x, y, w, h, seed, stain=0.5):
    rnd = random.Random(seed)
    c.rect(x, y, w, h, C.ww1)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            r = rnd.random()
            if r < 0.04:
                c.put(xx, yy, C.ww0)
            elif r < 0.07:
                c.put(xx, yy, C.ww2)
    # rain streaks running down from the eaves + rising damp
    for _ in range(int(w * stain / 4)):
        sx = rnd.randint(x, x + w - 1)
        ln = rnd.randint(3, max(4, h // 2))
        for yy in range(y + h - ln, y + h):
            if rnd.random() < 0.65:
                c.put(sx, yy, C.ww2 if rnd.random() < 0.7 else C.ww3)
    for _ in range(int(w * stain / 6)):
        sx = rnd.randint(x, x + w - 1)
        ln = rnd.randint(2, 6)
        for yy in range(y, y + ln):
            if rnd.random() < 0.6:
                c.put(sx, yy, C.ww2)
    # damp band near the plinth
    c.dither(x, y + h - 4, w, 4, C.ww1, C.ww2, 0.35)


def plinth(c, x, y, w, h=4, seed=0):
    rnd = random.Random(seed + 7)
    c.rect(x, y, w, h, C.st2)
    c.hline(x, x + w - 1, y, C.st4)
    c.hline(x, x + w - 1, y + h - 1, C.st1)
    xx = x + rnd.randint(2, 6)
    while xx < x + w - 1:
        c.vline(xx, y + 1, y + h - 2, C.st1)
        xx += rnd.randint(6, 11)


def step(c, x, y, w, h=3):
    c.rect(x, y, w, h, C.st3)
    c.hline(x, x + w - 1, y, C.st5)
    c.hline(x, x + w - 1, y + h - 1, C.st1)
    c.put(x, y + 1, C.st4)
    c.vline(x + w - 1, y, y + h - 1, C.st1)


def post(c, x, y, h, w=3):
    c.rect(x, y, w, h, C.wood1)
    c.vline(x, y, y + h - 1, C.wood2)
    c.vline(x + w - 1, y, y + h - 1, C.wood0)
    # stone base
    c.rect(x - 1, y + h - 2, w + 2, 2, C.st3)
    c.hline(x - 1, x + w, y + h - 2, C.st4)


def beam(c, x, y, w, h=3):
    c.rect(x, y, w, h, C.wood1)
    c.hline(x, x + w - 1, y, C.wood2)
    c.hline(x, x + w - 1, y + h - 1, C.wood0)


def planks(c, x, y, w, h, seed=0, dark=False):
    rnd = random.Random(seed)
    a, b = (C.wood1, C.wood0) if dark else (C.wood2, C.wood1)
    c.rect(x, y, w, h, a)
    for xx in range(x, x + w):
        if (xx - x) % 4 == 3:
            c.vline(xx, y, y + h - 1, C.dkbrown)
        elif (xx - x) % 4 == 0:
            c.vline(xx, y, y + h - 1, mix(a, C.tan, 0.3))
        for yy in range(y, y + h):
            if rnd.random() < 0.06:
                c.put(xx, yy, b)
    # cross battens
    for yy in (y + 2, y + h - 4):
        c.hline(x, x + w - 1, yy, b)


def lattice(c, x, y, w, h, frame=None, paper=None, glow=False):
    frame = frame or C.wood1
    paper = paper or (C.lamp_pale if glow else C.paper)
    c.rect(x, y, w, h, paper)
    for yy in range(y + 1, y + h - 1):
        for xx in range(x + 1, x + w - 1):
            if (xx - x) % 3 == 0 or (yy - y) % 3 == 0:
                c.put(xx, yy, mix(frame, paper, 0.35))
    # inner highlight top-left
    c.hline(x + 1, x + w - 2, y + 1, C.paper_hi if not glow else C.lamp)
    c.frame(x, y, w, h, frame)
    c.hline(x, x + w - 1, y + h, C.wood0)  # sill shadow


def doorway(c, x, y, w, h, interior=None):
    """Dark opening with a hint of floor light."""
    c.rect(x, y, w, h, C.dkbrown)
    c.rect(x, y + h - 3, w, 3, C.wood0)
    c.hline(x, x + w - 1, y + h - 3, C.wood1)
    if interior:
        interior(c, x, y, w, h)


def plaque(c, cx, y, text, face=None, ink=None, border=None, size=12, pad=3):
    face = face or C.black
    ink = ink or C.gold
    border = border or C.wood1
    m = font_mask(text, size, spacing=1)
    w = m.width + pad * 2 + 2
    h = m.height + pad * 2
    x = cx - w // 2
    c.rect(x, y, w, h, face)
    c.frame(x, y, w, h, border)
    c.hline(x + 1, x + w - 2, y + 1, mix(face, C.white, 0.15))
    c.hline(x, x + w - 1, y + h, C.dkbrown)  # drop shadow
    c.text(x + pad + 1, y + pad, text, ink, size, spacing=1)
    return x, y, w, h


def hanging_lantern(c, x, y):
    lan = Cv.load(os.path.join(ASSETS, "props", "lantern_red.png"))
    c.blit(lan, x - 4, y)


def cloth_banner(c, x, y, ch, cloth, ink, h=22, w=13, pole=True):
    """幌子: cloth hanging from a pole jutting out of the facade."""
    if pole:
        c.hline(x - 2, x + w + 1, y, C.wood1)
        c.put(x - 2, y - 1, C.wood2)
    c.rect(x, y + 1, w, h, cloth)
    c.vline(x, y + 1, y + h, mix(cloth, C.white, 0.25))
    c.vline(x + w - 1, y + 1, y + h, mix(cloth, C.black, 0.25))
    for xx in range(x, x + w):  # dovetail hem
        if (xx - x) % 4 in (1, 2):
            c.put(xx, y + h + 1, cloth)
        if (xx - x) % 4 == 0:
            c.put(xx, y + h, CLEAR)
    m = font_mask(ch, 12)
    c.text(x + (w - m.width) // 2, y + 3 + (h - 6 - m.height) // 2, ch, ink, 12)


CLEAR = (0, 0, 0, 0)


# ------------------------------------------------------------------ shells
def shell(fw, roof_h, wall_h, seed, upper_h=0, pent_h=0, step_h=3, light=0, moss=0.08):
    """Allocate a building canvas and draw roof(s). Returns (canvas, geometry dict)."""
    W = fw + 2 * OV
    H = UP + roof_h + upper_h + pent_h + wall_h + step_h
    c = Cv(W, H)
    g = {"W": W, "H": H, "fx": OV, "fw": fw}
    y = UP + roof_h
    g["upper_y"] = y
    g["pent_y"] = y + upper_h
    g["wall_y"] = y + upper_h + pent_h
    g["ground"] = H - step_h          # first row of the step
    g["roof"] = roof_layer(W, roof_h, seed, upturn=3, moss=moss, light=light)
    g["pent"] = roof_layer(W - 2, pent_h + 1, seed + 1, ridge=False, upturn=2, moss=moss) if pent_h else None
    return c, g


def finish(c, g, step_w=None):
    """Draw roofs over everything (they overhang) and the step."""
    if g.get("pent") is not None:
        c.blit(g["pent"], 1, g["pent_y"] - UP - 1)
    c.blit(g["roof"], 0, 0)
    step(c, OV - 1, g["ground"], (step_w or g["fw"]) + 2)


# ================================================================== shops
def interior_rice(c, x, y, w, h):
    # shelves + counter with rice baskets
    for yy in range(y + 3, y + h - 12, 5):
        c.hline(x + 1, x + w - 2, yy, C.wood1)
        for xx in range(x + 2, x + w - 3, 4):
            c.rect(xx, yy - 2, 2, 2, C.paper_old)
    cy = y + h - 11
    c.rect(x, cy, w, 9, C.wood1)
    c.hline(x, x + w - 1, cy, C.tan)
    c.hline(x, x + w - 1, cy + 1, C.wood3)
    for xx in range(x + 2, x + w - 2, 6):
        c.vline(xx, cy + 2, cy + 8, C.wood0)
    for i, bx in enumerate(range(x + 4, x + w - 3, 9)):
        c.ellipse(bx, cy - 1, 3.5, 2, C.wood3)
        c.ellipse(bx, cy - 2, 2.8, 1.6, C.ww0 if i % 2 == 0 else C.paper)
        c.put(bx - 1, cy - 3, C.white)


def interior_pharmacy(c, x, y, w, h):
    # 百子柜: wall of little drawers
    c.rect(x + 1, y + 2, w - 2, h - 12, C.wood1)
    for yy in range(y + 3, y + h - 11, 3):
        for xx in range(x + 2, x + w - 2, 3):
            c.rect(xx, yy, 2, 2, C.wood2)
            c.put(xx, yy, C.wood3)
            c.put(xx + 1, yy + 1, C.gold if (xx + yy) % 2 else C.wood0)
    cy = y + h - 10
    c.rect(x, cy, w, 8, C.wood0)
    c.hline(x, x + w - 1, cy, C.wood3)
    c.hline(x, x + w - 1, cy + 1, C.wood2)
    # jars + scale on counter
    c.rect(x + 3, cy - 3, 3, 3, C.ww0); c.put(x + 3, cy - 3, C.white); c.put(x + 5, cy - 1, C.ww2)
    c.rect(x + w - 6, cy - 4, 3, 4, C.jade); c.put(x + w - 6, cy - 4, C.jade_hi)


def interior_tea(c, x, y, w, h):
    c.rect(x, y, w, h, C.wood0)
    # warm glow
    c.dither(x, y + 2, w, h - 6, C.wood0, C.wood1, 0.4)
    # hanging lantern inside
    c.rect(x + w // 2 - 1, y + 3, 3, 4, C.lamp)
    c.put(x + w // 2, y + 2, C.wood1)
    for tx in range(x + 4, x + w - 6, 12):
        ty = y + h - 9
        c.rect(tx, ty, 8, 2, C.wood3)
        c.hline(tx, tx + 7, ty, C.tan)
        c.vline(tx + 1, ty + 2, ty + 6, C.wood1)
        c.vline(tx + 6, ty + 2, ty + 6, C.wood1)
        c.put(tx + 3, ty - 1, C.ww0); c.put(tx + 5, ty - 1, C.ww1)


def interior_pawn(c, x, y, w, h):
    # the famous high counter (高柜台) that customers had to reach up to
    c.rect(x, y, w, h, C.dkbrown)
    cy = y + 9
    c.rect(x, cy, w, h - 9, C.wood0)
    c.hline(x, x + w - 1, cy, C.wood3)
    c.hline(x, x + w - 1, cy + 1, C.wood1)
    for xx in range(x + 2, x + w - 1, 4):
        c.vline(xx, cy + 3, y + h - 4, C.wood1)
    # a lamp glow behind the counter + clerk silhouette
    c.rect(x + w - 6, y + 2, 2, 3, C.lamp)
    c.put(x + w - 6, y + 1, C.flame)
    c.rect(x + 3, y + 3, 4, 6, C.rf1)
    c.rect(x + 4, y + 1, 2, 2, C.skin_lo)


def gable_wall(c, gx, gw, ground, top, seed=110, char="当"):
    """Stepped 马头墙 gable facing the street, giant painted character."""
    # three levels, symmetric: outer, middle, centre
    ow, mw = 11, 10
    cw = gw - 2 * (ow + mw)
    lv = [(0, ow, top + 26), (ow, ow + mw, top + 13), (ow + mw, ow + mw + cw, top),
          (ow + mw + cw, ow + 2 * mw + cw, top + 13), (ow + 2 * mw + cw, gw, top + 26)]
    for (x0, x1, ty) in lv:
        plaster(c, gx + x0, ty + 4, x1 - x0, ground - ty - 4, seed + x0, stain=0.55)
    for i, (x0, x1, ty) in enumerate(lv):
        a0, a1 = gx + x0 - 1, gx + x1
        # tile cap: 4 rows
        c.rect(a0, ty, a1 - a0 + 1, 4, C.rf1)
        c.hline(a0, a1, ty, C.rf3)
        c.hline(a0, a1, ty + 1, C.rf2)
        for xx in range(a0, a1 + 1, 3):
            c.put(xx, ty + 3, C.rf0)
            c.put(xx + 1, ty + 2, C.rf2)
        # 座头 horse-head on the outer end of each lower step / both ends of the crown
        ends = []
        if i < 2:
            ends = [a0]
        elif i > 2:
            ends = [a1]
        else:
            ends = [a0, a1]
        for ex in ends:
            dx = -1 if (ex == a0) else 1
            c.rect(ex - (2 if dx < 0 else 0), ty - 2, 3, 3, C.rf1)
            c.put(ex + dx, ty - 3, C.rf2)
            c.put(ex + 2 * dx, ty - 4, C.rf1)
            c.put(ex, ty - 2, C.rf3)
        # ink frieze under the cap + cap shadow
        for xx in range(a0 + 1, a1):
            p = c.get(xx, ty + 4)
            if p[3]:
                c.put(xx, ty + 4, mix(p, C.black, 0.4))
        c.hline(a0 + 2, a1 - 2, ty + 6, C.ww3)
        for xx in range(a0 + 3, a1 - 2, 4):
            c.put(xx, ty + 7, C.ww3)
    # giant character, bold ink
    m = font_mask(char, 36, index=0)
    from PIL import ImageFilter
    m = m.filter(ImageFilter.MaxFilter(3)).point(lambda v: 255 if v > 100 else 0)
    mx = gx + (gw - m.width) // 2
    my = top + 32
    mp = m.load()
    rnd = random.Random(seed)
    for yy in range(m.height):
        for xx in range(m.width):
            if mp[xx, yy]:
                col = C.black if rnd.random() > 0.05 else C.rf1
                c.put(mx + xx, my + yy, col)
    plinth(c, gx, ground - 6, gw, 6, seed=3)
    return lv


def build_pawnshop():
    """德厚当: two-storey shop + stepped white gable (马头墙) on the right with a giant 当."""
    gw = 52          # gable wall width
    sw = 70          # shop section facade width
    roof_h, upper_h, pent_h, lower_h = 22, 21, 7, 34
    shop_h = UP + roof_h + upper_h + pent_h + lower_h + 3
    top = 3
    H = shop_h + 14
    W = OV + sw + gw + 1
    c = Cv(W, H)
    ground = H - 3
    sx = OV
    gx = OV + sw
    off = H - shop_h
    wall_y = off + UP + roof_h + upper_h + pent_h
    upper_y = off + UP + roof_h
    # gable first (shop roof overlaps its left edge a little)
    gable_wall(c, gx, gw, ground, top)
    # upper storey
    plaster(c, sx, upper_y, sw, upper_h + pent_h, 101, stain=0.3)
    lattice(c, sx + 4, upper_y + 6, 12, 10)
    lattice(c, sx + sw - 16, upper_y + 6, 12, 10)
    # lower storey
    c.rect(sx, wall_y, sw, lower_h, C.wood1)
    beam(c, sx, wall_y, sw, 3)
    planks(c, sx + 3, wall_y + 3, 20, lower_h - 3, seed=3)
    planks(c, sx + sw - 23, wall_y + 3, 20, lower_h - 3, seed=4)
    dw = 20
    dx = sx + (sw - dw) // 2
    c.rect(dx - 2, wall_y + 2, dw + 4, lower_h - 2, C.st3)
    c.vline(dx - 2, wall_y + 2, wall_y + lower_h - 1, C.st4)
    doorway(c, dx, wall_y + 4, dw, lower_h - 4, interior_pawn)
    c.rect(dx, wall_y + 4, 3, lower_h - 4, C.rf1)
    c.vline(dx, wall_y + 4, wall_y + lower_h - 1, C.rf2)
    c.rect(dx + dw - 3, wall_y + 4, 3, lower_h - 4, C.rf1)
    c.vline(dx + dw - 1, wall_y + 4, wall_y + lower_h - 1, C.rf0)
    c.rect(dx, wall_y + lower_h - 3, dw, 3, C.wood1)
    c.hline(dx, dx + dw - 1, wall_y + lower_h - 3, C.wood3)
    post(c, sx, wall_y, lower_h, 3)
    post(c, sx + sw - 3, wall_y, lower_h, 3)
    under_eave_shadow(c, sx, wall_y, sw, rows=(0.5, 0.3, 0.15))
    pent = roof_layer(sw + 5, pent_h + 1, 105, ridge=False, upturn=2)
    c.blit(pent, sx - 3, off + UP + roof_h + upper_h - UP - 1)
    under_eave_shadow(c, sx, upper_y, sw, rows=(0.5, 0.3, 0.15))
    roof = roof_layer(sw + OV + 1, roof_h, 106, upturn=3, moss=0.1)
    c.blit(roof, 0, off)
    plaque(c, sx + sw // 2, upper_y + 3, "德厚当", face=C.black, ink=C.gold, border=C.wood1)
    hanging_lantern(c, sx + 6, wall_y + 2)
    hanging_lantern(c, sx + sw - 6, wall_y + 2)
    # vertical paper tag with 当 by the door
    tx = dx + dw + 3
    c.rect(tx, wall_y + 7, 7, 14, C.paper_hi)
    c.frame(tx, wall_y + 7, 7, 14, C.wood0)
    c.hline(tx + 1, tx + 5, wall_y + 10, C.black); c.put(tx + 1, wall_y + 9, C.black); c.put(tx + 5, wall_y + 9, C.black)
    c.vline(tx + 3, wall_y + 8, wall_y + 11, C.black)
    c.hline(tx + 1, tx + 5, wall_y + 13, C.black)
    c.vline(tx + 5, wall_y + 13, wall_y + 18, C.black)
    c.hline(tx + 1, tx + 5, wall_y + 16, C.black)
    c.hline(tx + 1, tx + 5, wall_y + 18, C.black)
    # shop eave shadow falling on the gable's left edge
    for yy in range(off + UP + 4, ground):
        for k, a in ((0, 0.35), (1, 0.18)):
            p = c.get(gx + k, yy)
            if p[3]:
                c.put(gx + k, yy, mix(p, C.black, a))
    step(c, sx - 1, ground, sw + 2)
    c.rect(gx, ground, gw + 1, 3, C.st2)
    c.hline(gx, gx + gw, ground, C.st4)
    return c


def build_rice():
    fw = 66
    c, g = shell(fw, 26, 44, 201)
    x, wy, gr = g["fx"], g["wall_y"], g["ground"]
    lh = gr - wy
    c.rect(x, wy, fw, lh, C.wood1)
    beam(c, x, wy, fw, 3)
    # fascia board above the opening
    c.rect(x, wy + 3, fw, 14, C.wood2)
    c.hline(x, x + fw - 1, wy + 16, C.wood0)
    oy = wy + 17
    doorway(c, x + 3, oy, fw - 6, lh - 17, interior_rice)
    # a stack of shutter boards leaning at the right (taken down for the day)
    planks(c, x + fw - 12, oy, 9, lh - 17, seed=9)
    post(c, x, wy, lh, 3)
    post(c, x + fw - 3, wy, lh, 3)
    post(c, x + fw // 2 - 1, wy + 16, lh - 16, 2)
    under_eave_shadow(c, x, wy, fw)
    finish(c, g)
    plaque(c, x + fw // 2 - 8, wy + 3, "米行", face=C.gold, ink=C.black, border=C.wood0)
    # cloth banner with 米
    cloth_banner(c, x + fw - 17, wy + 3, "米", C.ww0, C.black, h=17, w=13)
    return c


def build_pharmacy():
    fw = 62
    c, g = shell(fw, 22, 34, 301, upper_h=21, pent_h=7)
    x = g["fx"]
    uy, py, wy, gr = g["upper_y"], g["pent_y"], g["wall_y"], g["ground"]
    lh = gr - wy
    plaster(c, x, uy, fw, py - uy + 7, 303, stain=0.35)
    lattice(c, x + 3, uy + 6, 10, 10)
    lattice(c, x + fw - 13, uy + 6, 10, 10)
    c.rect(x, wy, fw, lh, C.wood1)
    beam(c, x, wy, fw, 3)
    # lower lattice windows (glowing a little) + central opening
    lattice(c, x + 3, wy + 5, 14, 14)
    planks(c, x + 3, wy + 20, 14, lh - 20, seed=5)
    lattice(c, x + fw - 17, wy + 5, 14, 14)
    planks(c, x + fw - 17, wy + 20, 14, lh - 20, seed=6)
    doorway(c, x + 19, wy + 3, fw - 38, lh - 3, interior_pharmacy)
    post(c, x, wy, lh); post(c, x + 17, wy, lh, 2); post(c, x + fw - 19, wy, lh, 2); post(c, x + fw - 3, wy, lh)
    under_eave_shadow(c, x, wy, fw, rows=(0.5, 0.3, 0.15))
    under_eave_shadow(c, x, uy, fw, rows=(0.5, 0.3, 0.15))
    finish(c, g)
    plaque(c, x + fw // 2, uy + 3, "药铺", face=C.black, ink=C.gold, border=C.wood1)
    # 葫芦 gourd sign hanging from the pent eave
    gx, gy = x + 9, wy + 1
    c.vline(gx, gy, gy + 3, C.wood0)
    c.put(gx - 1, gy + 3, C.seal_red); c.put(gx + 1, gy + 3, C.seal_red)
    c.ellipse(gx, gy + 6, 2, 2, C.gold)
    c.ellipse(gx, gy + 11, 3.4, 3.4, C.gold)
    c.put(gx - 1, gy + 5, C.lamp); c.put(gx - 2, gy + 10, C.lamp); c.put(gx - 1, gy + 9, C.lamp)
    c.put(gx + 2, gy + 12, C.wood3); c.put(gx + 1, gy + 14, C.wood3)
    from_outline_pixels(c, [(gx - 2, gy + 5), (gx + 2, gy + 5), (gx - 4, gy + 11), (gx + 4, gy + 11), (gx, gy + 15)])
    return c


def from_outline_pixels(c, pts):
    for (x, y) in pts:
        c.put(x, y, C.dkbrown)


def build_teahouse():
    fw = 74
    c, g = shell(fw, 22, 34, 401, upper_h=21, pent_h=7)
    x = g["fx"]
    uy, py, wy, gr = g["upper_y"], g["pent_y"], g["wall_y"], g["ground"]
    lh = gr - wy
    # upper floor: open gallery with 美人靠 railing + lanterns
    c.rect(x, uy, fw, py - uy + 7, C.wood0)
    for xx in range(x + 2, x + fw - 2, 9):
        lattice(c, xx, uy + 3, 7, 7, glow=True)
    # railing
    c.rect(x, uy + 13, fw, 7, C.wood2)
    c.hline(x, x + fw - 1, uy + 13, C.tan)
    for xx in range(x + 1, x + fw - 1, 2):
        c.vline(xx, uy + 15, uy + 19, C.wood1)
    c.hline(x, x + fw - 1, uy + 20, C.wood0)
    c.rect(x, wy, fw, lh, C.wood1)
    beam(c, x, wy, fw, 3)
    doorway(c, x + 3, wy + 3, fw - 6, lh - 3, interior_tea)
    for px_ in (x, x + 24, x + 48, x + fw - 3):
        post(c, px_, wy, lh)
    under_eave_shadow(c, x, wy, fw, rows=(0.45, 0.25, 0.1))
    under_eave_shadow(c, x, uy, fw, rows=(0.45, 0.25, 0.1))
    finish(c, g)
    plaque(c, x + fw // 2, uy - 1 + 3, "茶馆", face=C.black, ink=C.gold, border=C.wood1)
    hanging_lantern(c, x + 12, wy + 1)
    hanging_lantern(c, x + fw - 12, wy + 1)
    return c


def build_police():
    fw = 66
    c, g = shell(fw, 24, 44, 501)
    x, wy, gr = g["fx"], g["wall_y"], g["ground"]
    lh = gr - wy
    # grey brick facade (Republican government style)
    c.rect(x, wy, fw, lh, C.wall2)
    for yy in range(wy, gr):
        off = 0 if ((yy - wy) // 3) % 2 == 0 else 3
        if (yy - wy) % 3 == 2:
            c.hline(x, x + fw - 1, yy, C.mist)
        else:
            for xx in range(x + off, x + fw, 6):
                c.put(xx, yy, C.mist)
    rnd = random.Random(5)
    for _ in range(40):
        c.put(x + rnd.randint(0, fw - 1), wy + rnd.randint(0, lh - 1), C.wall1)
    # pilasters
    for px_ in (x, x + fw - 4):
        c.rect(px_, wy, 4, lh, C.fog)
        c.vline(px_, wy, gr - 1, C.white)
        c.vline(px_ + 3, wy, gr - 1, C.mist)
    # shuttered windows
    for wx in (x + 7, x + fw - 19):
        c.rect(wx, wy + 12, 12, 16, C.wall0)
        c.rect(wx + 1, wy + 13, 5, 14, C.indigo1)
        c.rect(wx + 6, wy + 13, 5, 14, C.indigo1)
        for yy in range(wy + 14, wy + 27, 2):
            c.hline(wx + 1, wx + 10, yy, C.indigo0)
        c.hline(wx - 1, wx + 12, wy + 28, C.fog)
        c.hline(wx - 1, wx + 12, wy + 29, C.mist)
    # door, boarded up
    dx, dw = x + fw // 2 - 9, 18
    c.rect(dx - 2, wy + 10, dw + 4, lh - 10, C.fog)
    c.rect(dx, wy + 12, dw, lh - 12, C.dkred)
    c.vline(dx + dw // 2, wy + 12, gr - 1, C.black)
    for yy in (wy + 16, wy + 26, wy + 34):
        c.hline(dx + 1, dx + dw - 2, yy, mix(C.dkred, C.black, 0.4))
    # boards (X)
    for (x0, y0, x1, y1) in ((dx - 2, wy + 14, dx + dw + 1, gr - 6), (dx - 2, gr - 6, dx + dw + 1, wy + 14)):
        for t in range(3):
            c.line(x0, y0 + t, x1, y1 + t, C.tan if t == 0 else C.wood3)
    c.rect(dx - 3, wy + 22, dw + 6, 3, C.wood3)
    c.hline(dx - 3, dx + dw + 2, wy + 22, C.tan)
    for nx in (dx - 2, dx + dw + 1):
        c.put(nx, wy + 23, C.gray)
    # chain + padlock
    c.hline(dx + 5, dx + 12, wy + 28, C.silver)
    c.rect(dx + 7, wy + 28, 4, 4, C.gold)
    c.put(dx + 8, wy + 27, C.silver); c.put(dx + 9, wy + 27, C.silver)
    c.put(dx + 9, wy + 30, C.dkbrown)
    # sign board above door
    sx, sy = x + fw // 2, wy + 1
    plaque(c, sx, sy, "警察所", face=C.ww0, ink=C.black, border=C.wall0)
    # torn notice pasted on the wall
    nx, ny = x + 6, wy + 31
    c.rect(nx, ny, 9, 9, C.paper)
    c.hline(nx + 1, nx + 6, ny + 2, C.gray)
    c.hline(nx + 1, nx + 5, ny + 4, C.gray)
    c.put(nx + 8, ny + 8, C.wall2); c.put(nx + 7, ny + 8, C.ww3)
    c.rect(nx + 5, ny + 5, 3, 2, C.seal_red)
    under_eave_shadow(c, x, wy, fw)
    finish(c, g)
    # weeds at the base (unused building)
    for wx in (x + 2, x + 20, x + fw - 6, x + fw - 24):
        c.put(wx, gr - 1, C.g3); c.put(wx + 1, gr - 2, C.g2); c.put(wx + 2, gr - 1, C.g3)
    # cobweb in the eave corner
    for i in range(5):
        c.put(x + fw - 4 - i, wy + 1 + i, C.ww1)
    c.put(x + fw - 6, wy + 1, C.ww1); c.put(x + fw - 4, wy + 3, C.ww1)
    # desaturate + dim = locked / not yet available
    c.recolor(lambda p: desaturate(mix(p, C.wall1, 0.12), 0.55))
    return c


def build_post():
    fw = 62
    c, g = shell(fw, 22, 34, 601, upper_h=21, pent_h=7)
    x = g["fx"]
    uy, py, wy, gr = g["upper_y"], g["pent_y"], g["wall_y"], g["ground"]
    lh = gr - wy
    plaster(c, x, uy, fw, py - uy + 7, 603, stain=0.25)
    # arched windows upstairs
    for wx in (x + 5, x + fw - 15):
        c.rect(wx, uy + 7, 10, 10, C.postgreen)
        c.ellipse(wx + 4.5, uy + 7, 5, 3, C.postgreen)
        c.rect(wx + 2, uy + 8, 6, 8, C.wa3)
        c.vline(wx + 5, uy + 7, uy + 15, C.postgreen)
        c.put(wx + 2, uy + 8, C.wa5)
    c.rect(x, wy, fw, lh, C.ww1)
    plaster(c, x, wy, fw, lh, 604, stain=0.4)
    # green door (arched) + counter window
    dx = x + fw // 2 - 8
    c.rect(dx, wy + 6, 16, lh - 6, C.postgreen)
    c.ellipse(dx + 7.5, wy + 6, 8, 4, C.postgreen)
    c.rect(dx + 2, wy + 6, 12, lh - 6, C.dkbrown)
    c.rect(dx + 2, wy + 6, 5, lh - 6, C.postgreen_hi)
    c.vline(dx + 2, wy + 6, gr - 1, C.jade_hi)
    c.put(dx + 6, wy + 18, C.gold)
    for wx in (x + 4, x + fw - 18):
        c.rect(wx, wy + 8, 14, 13, C.postgreen)
        c.rect(wx + 1, wy + 9, 12, 11, C.wa3)
        c.vline(wx + 7, wy + 9, wy + 19, C.postgreen)
        c.hline(wx + 1, wx + 12, wy + 14, C.postgreen)
        c.put(wx + 2, wy + 10, C.wa5); c.put(wx + 3, wy + 10, C.wa5)
        c.hline(wx - 1, wx + 14, wy + 21, C.st4)
    plinth(c, x, gr - 4, fw, 4)
    under_eave_shadow(c, x, wy, fw, rows=(0.5, 0.3, 0.15))
    under_eave_shadow(c, x, uy, fw, rows=(0.5, 0.3, 0.15))
    finish(c, g)
    plaque(c, x + fw // 2, uy + 3, "邮电局", face=C.postgreen, ink=C.ww0, border=C.g0)
    return c


def build_sun_gate():
    """孙府: high white wall with a gatehouse, black lacquer doors, stone drums."""
    fw = 92
    gh_w = 44
    H = UP + 20 + 50 + 4
    W = fw + 2 * OV
    c = Cv(W, H)
    ground = H - 4
    x0 = OV
    # side walls
    wall_top = UP + 16
    plaster(c, x0, wall_top + 3, fw, ground - wall_top - 3, 701, stain=0.5)
    c.rect(x0 - 1, wall_top, fw + 2, 3, C.rf1)
    c.hline(x0 - 1, x0 + fw, wall_top, C.rf3)
    for xx in range(x0, x0 + fw, 3):
        c.put(xx, wall_top + 2, C.rf0)
    under_eave_shadow(c, x0, wall_top + 3, fw, rows=(0.35, 0.15))
    # leak windows (漏窗): round frames with tile-lattice inside
    for lx in (x0 + 9, x0 + fw - 21):
        cxw, cyw = lx + 6, wall_top + 20
        c.ellipse(cxw, cyw, 6.5, 6.5, C.ww3)
        c.ellipse(cxw, cyw, 5.2, 5.2, C.g1)
        for yy in range(cyw - 5, cyw + 6):
            for xx in range(cxw - 5, cxw + 6):
                if (xx - cxw) ** 2 + (yy - cyw) ** 2 <= 27 and ((xx + yy) % 4 == 0 or (xx - yy) % 4 == 0):
                    c.put(xx, yy, C.ww1)
        c.put(cxw - 3, cyw - 3, C.g2)
    plinth(c, x0, ground - 5, fw, 5, seed=2)
    # gatehouse
    gx = x0 + (fw - gh_w) // 2
    gy = UP + 20
    c.rect(gx, gy, gh_w, ground - gy, C.ww1)
    c.rect(gx + 4, gy + 4, gh_w - 8, ground - gy - 4, C.st3)
    dx, dw = gx + 9, gh_w - 18
    c.rect(dx, gy + 12, dw, ground - gy - 12, C.rf0)
    c.rect(dx + 1, gy + 13, dw // 2 - 1, ground - gy - 14, C.rf1)
    c.rect(dx + dw // 2 + 1, gy + 13, dw // 2 - 2, ground - gy - 14, C.rf1)
    c.vline(dx + 1, gy + 13, ground - 2, C.rf2)
    for (kx) in (dx + dw // 2 - 3, dx + dw // 2 + 3):
        c.ellipse(kx, gy + 24, 1.5, 1.5, C.gold, filled=False)
        c.put(kx, gy + 22, C.lamp)
    for yy in range(gy + 16, ground - 2, 4):  # door nails
        for xx in range(dx + 3, dx + dw - 2, 4):
            c.put(xx, yy, C.wood3)
    c.hline(dx, dx + dw - 1, gy + 12, C.st4)
    roof = roof_layer(gh_w + 10, 22, 702, upturn=4)
    c.blit(roof, gx - 5, gy - 22 - UP + 4)
    plaque(c, gx + gh_w // 2, gy + 1, "孙府", face=C.black, ink=C.gold, border=C.gold)
    # stone drums (抱鼓石)
    for sx in (dx - 6, dx + dw + 1):
        c.ellipse(sx + 2.5, ground - 7, 3, 3, C.st3)
        c.ellipse(sx + 1.5, ground - 8, 1.5, 1.5, C.st4)
        c.rect(sx, ground - 4, 6, 4, C.st2)
        c.hline(sx, sx + 5, ground - 4, C.st4)
    hanging_lantern(c, gx + 4, gy + 6)
    hanging_lantern(c, gx + gh_w - 4, gy + 6)
    # steps
    step(c, gx - 2, ground, gh_w + 4, 2)
    step(c, gx - 4, ground + 2, gh_w + 8, 2)
    c.rect(x0 - 1, ground, gx - x0 - 1, 4, C.st2)
    c.rect(gx + gh_w + 5, ground, x0 + fw - gx - gh_w - 4, 4, C.st2)
    return c


def back_roofs(w=128, seed=900):
    """Tileable distant roof band for the top of town scenes (w x 40)."""
    rnd = random.Random(seed)
    c = Cv(w, 44)
    x = -10
    while x < w:
        bw = rnd.randint(30, 52)
        top = rnd.randint(4, 14)
        r = roof_layer(bw, 30, rnd.randint(0, 999), upturn=3, moss=0.05, grass=False)
        r.recolor(lambda p: mix(p, C.wall0, 0.35))
        c.blit(r, x, top - UP)
        x += bw - 4
    # bits of tree canopy between roofs
    for _ in range(3):
        tx = rnd.randint(0, w)
        c.ellipse(tx, 6, 8, 6, C.g1)
        c.ellipse(tx - 2, 4, 5, 3, C.g2)
    return c


def gen_all():
    os.makedirs(OUT, exist_ok=True)
    blds = {
        "pawnshop_dehoudang": build_pawnshop(),
        "rice_mihang": build_rice(),
        "pharmacy_yaopu": build_pharmacy(),
        "teahouse_chaguan": build_teahouse(),
        "police_jingchasuo_locked": build_police(),
        "post_youdianju": build_post(),
        "sunfu_gate": build_sun_gate(),
        "back_roofs_strip": back_roofs(),
    }
    for k, v in blds.items():
        v.save(os.path.join(OUT, k + ".png"))
    return blds


if __name__ == "__main__":
    gen_all()
