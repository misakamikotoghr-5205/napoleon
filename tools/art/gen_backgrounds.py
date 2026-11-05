#!/usr/bin/env python3
"""Background generator for the 德厚当 counter view (deterministic, palette-only).

Outputs (320x180, opaque):
  art/bg/counter_day.png    morning, misty street through the open shop door
  art/bg/counter_dusk.png   warm orange-brown dusk street, long shadows
  art/bg/counter_night.png  door shut with 门板, oil-lamp pool on the right
  art/bg/candle.png         序章第一幕: 门缝 + candle glow (candle sprite drawn in)
  art/bg/title.png          night 江南 water-town title backdrop (top-centre kept calm)
Contact sheet: art/_preview/backgrounds.png

Run from project root:  python3 tools/art/gen_backgrounds.py
Hotspot rects in data/layout.json are left as plain wood / wall; tools are drawn by the engine.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview, load_layout  # noqa: E402

W, H = 320, 180
LAY = load_layout()
DX, DY, DW, DH = LAY["regions"]["door"]        # 112, 8, 96, 92
DX1, DY1 = DX + DW, DY + DH                    # 208, 100
COUNTER_Y, UNDER_Y = LAY["regions"]["counter_top"][1], LAY["regions"]["under"][1]  # 100, 150
_lamp = LAY["hotspots"]["lamp"]["rect"]
LAMP_X = _lamp[0] + _lamp[2] // 2              # 302
LAMP_Y = _lamp[1] + _lamp[3] // 2              # 84
LATTICES = [(14, 16, 68, 50), (238, 14, 68, 48)]   # 木格纸窗 on both wall sides
BLDS = [(112, 131, 40), (132, 150, 30), (151, 171, 46), (172, 207, 30)]  # opposite street
DOOR_SHADOW = [(112, 66), (150, 66), (124, 99), (112, 99)]    # dusk: shadow of door jamb
OUT_DIR = os.path.join("art", "bg")

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# ------------------------------------------------------------------ helpers
def thr(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def hz(x, y, s=0.0):
    """Deterministic pseudo-random in [0, 1)."""
    v = math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
    return v - math.floor(v)


def ramp_px(c, x, y, ramp, v):
    """Pick a colour on a dark->light palette ramp, Bayer-dithered between steps."""
    f = clamp(v) * (len(ramp) - 1)
    lo = min(int(f), len(ramp) - 2)
    c.dither(x, y, 1, 1, ramp[lo], ramp[lo + 1], f - lo)


def blend(c, x, y, col_a, col_b, level):
    c.dither(x, y, 1, 1, col_a, col_b, level)


def pixels_of(canvas):
    return [(x, y) for y in range(canvas.h) for x in range(canvas.w) if canvas.px[x, y][3]]


def inside(pts, x, y):
    """Even-odd point-in-polygon test (pixel centre)."""
    px, py = x + 0.5, y + 0.5
    hit = False
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if (y0 > py) != (y1 > py):
            xi = x0 + (py - y0) * (x1 - x0) / (y1 - y0)
            if px < xi:
                hit = not hit
    return hit


# ------------------------------------------------------------------ materials
# Day / dusk: one dark->light ramp per material kind.
MATS = {
    "day": {
        "sky":     [P.wall2, P.mist, P.fog, P.white],
        "bld":     [P.wall1, P.wall2, P.mist],
        "plaster": [P.wall2, P.mist, P.fog, P.white],
        "brick":   [P.wall0, P.wall1, P.wall2, P.mist],
        "wood":    [P.dkbrown, P.wood0, P.wood1, P.wood2, P.wood3, P.tan],
        "under":   [P.black, P.dkbrown, P.wood0, P.wood1],
        "paper":   [P.paper_old, P.paper, P.paper_hi],
    },
    "dusk": {
        "sky":     [P.wood1, P.wood2, P.wood3, P.tan, P.lamp_pale, P.lamp],
        "bld":     [P.black, P.dkbrown, P.wood0, P.wood1],
        "street":  [P.dkbrown, P.wood1, P.wood2, P.wood3, P.tan, P.lamp_pale],
        "plaster": [P.dkbrown, P.wood1, P.wood2, P.wood3, P.tan, P.paper_old],
        "brick":   [P.dkbrown, P.wood0, P.wood1, P.wood2, P.wood3],
        "wood":    [P.black, P.dkbrown, P.wood0, P.wood1, P.wood2, P.wood3, P.tan],
        "under":   [P.black, P.dkbrown, P.wood0, P.wood1],
        "paper":   [P.wood3, P.tan, P.paper_old, P.paper],
    },
}
# Night: cool blue-black ambient (wall0 / black dithering) mixed with a warm lamp ramp.
NIGHT_WARM = [P.black, P.dkbrown, P.wood0, P.wood1, P.wood2, P.wood3, P.tan, P.lamp_pale, P.lamp]
NIGHT_COOL = {
    "plaster": [P.wall0, P.wall1, P.wall2, P.mist],
    "brick":   [P.wall0, P.wall1, P.wall2, P.mist],
    "wood":    [P.dkbrown, P.wood0, P.wood1],
    "under":   [P.dkbrown, P.wood0, P.wood1],
    "paper":   [P.dkbrown, P.wood0, P.wood1, P.wood2],
}


def lamp_light(x, y):
    """Oil-lamp pool on the right of the counter; fades to near-dark on the left."""
    dx = (x - LAMP_X) / 215.0
    dy = (y - LAMP_Y) / 125.0
    d = math.sqrt(dx * dx + dy * dy)
    if d < 0.07:
        return 1.0
    return max(0.0, 1.0 - d) ** 1.5 * 0.95 + 0.06


def put(c, mode, x, y, kind, v, floor=0.0):
    """floor: minimum lamp light (keeps counter edge / door planks readable at night)."""
    if mode == "night":
        I = max(floor, lamp_light(x, y) * (0.5 + 0.5 * clamp(v)))
        if thr(x, y) < clamp(I / 0.3):
            ramp_px(c, x, y, NIGHT_WARM, I * 1.1)
        else:
            ramp_px(c, x, y, NIGHT_COOL[kind], 0.3 + 0.5 * clamp(v))
    else:
        ramp_px(c, x, y, MATS[mode][kind], v)


# ------------------------------------------------------------------ regions
def in_door(x, y):
    return DX <= x < DX1 and DY <= y < DY1


def in_frame(x, y):
    return DX - 4 <= x < DX1 + 4 and DY - 4 <= y < DY1 and not in_door(x, y)


def paint_wall(c, mode):
    """Plaster above, blue-grey 青砖 courses below; door region skipped."""
    for y in range(0, COUNTER_Y):
        for x in range(W):
            if in_door(x, y) or in_frame(x, y):
                continue
            if y < 58:
                v = 0.55 + 0.12 * (y / 58.0) - (0.12 if y < 6 else 0.0)
                v += 0.05 * (hz(x, y) - 0.5)
                put(c, mode, x, y, "plaster", v)
            else:
                r = (y - 58) // 6
                off = 8 if r % 2 else 0
                ly = (y - 58) % 6
                if ly == 5 or (x + off) % 16 == 0:
                    put(c, mode, x, y, "brick", 0.08)     # mortar
                else:
                    bx = (x + off) // 16
                    v = 0.5 + 0.25 * hz(bx, r, 3) + (0.12 if ly == 0 else 0.0)
                    put(c, mode, x, y, "brick", v)


def paint_frame(c, mode):
    """Wooden door jamb + lintel around the doorway."""
    for y in range(DY - 4, DY1):
        for x in range(DX - 4, DX1 + 4):
            if in_door(x, y):
                continue
            v = 0.47
            if y < DY - 2:
                v = 0.6
            if y == DY - 1 or x in (DX - 1, DX1):
                v = 0.25
            put(c, mode, x, y, "wood", v)


def paint_lattice(c, mode, x0, y0, w, h):
    """木格纸窗: wood grid with paper panes."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            lx, ly = x - x0, y - y0
            if lx < 2 or lx >= w - 2 or ly < 2 or ly >= h - 2:
                put(c, mode, x, y, "wood", 0.45)
            elif lx % 8 == 3 or ly % 8 == 3:
                put(c, mode, x, y, "wood", 0.35)
            else:
                put(c, mode, x, y, "paper", 0.7)


def paint_street(c, mode):
    """Opened doorway: misty opposite buildings, notice, passers-by, ground."""
    day = mode == "day"
    for y in range(DY, DY1):
        for x in range(DX, DX1):
            top = None
            for a, b, t in BLDS:
                if a <= x <= b:
                    top = t
            if y >= 66:
                if day:
                    kind, v = "sky", 0.9 - 0.12 * (y - 66) / 33.0 + 0.08 * math.sin(x * 0.07 + y * 0.3)
                else:
                    kind, v = "street", 0.5 - 0.1 * (y - 66) / 33.0 + 0.04 * math.sin(x * 0.2 + y * 0.9)
                    if (y - 66) % 7 == 6:
                        v -= 0.2
                    if inside(DOOR_SHADOW, x, y):
                        v -= 0.28
            elif top is not None and y >= top:
                if y == top:
                    kind, v = "bld", (0.1 if day else 0.0)
                else:
                    kind, v = "bld", (0.5 if day else 0.22)
            else:
                kind = "sky"
                v = (0.92 - 0.42 * (y - DY) / 58.0) if day else (0.22 + 0.7 * (y - DY) / 58.0)
            put(c, mode, x, y, kind, v)

    # 告示 pasted on the opposite wall: only the red seal shows
    nx, ny, nw, nh = 188, 33, 12, 17
    for y in range(ny, ny + nh):
        for x in range(nx, nx + nw):
            edge = x in (nx, nx + nw - 1) or y in (ny, ny + nh - 1)
            put(c, mode, x, y, "paper", 0.45 if edge else 0.9)
    sx, sy = 193, 38
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            if not (abs(dx) == 1 and abs(dy) == 1):
                c.pixel(sx + dx, sy + dy, P.seal_red)

    # faint passer-by silhouettes (mist-dimmed)
    figs = [(120, 96, 24), (199, 94, 20)]
    for cx, base, h in figs:
        sil = Canvas(W, H)
        sil.ellipse(cx, base - h + 3, 2, 2, P.black)
        sil.poly([(cx - 3, base - h + 6), (cx + 3, base - h + 6), (cx + 4, base), (cx - 4, base)], P.black)
        colA, colB = (P.wall0, P.wall1) if day else (P.black, P.wood1)
        for x, y in pixels_of(sil):
            if DX <= x < DX1 and DY <= y < DY1:
                blend(c, x, y, colA, colB, 0.3 if day else 0.35)

    # door sill
    for y, v in ((96, 0.85), (97, 0.6), (98, 0.45), (99, 0.3)):
        for x in range(DX, DX1):
            put(c, mode, x, y, "wood", v)


def paint_boards(c, mode):
    """Night: shut door of vertical 门板 with two cross battens and nails."""
    for y in range(DY, DY1):
        for x in range(DX, DX1):
            k = (x - DX) // 12
            off = (x - DX) % 12
            base = 0.32 + 0.26 * hz(k, 1, 4)
            v = base
            if off == 0:
                v = 0.04
            elif off in (4, 9):
                v = base + 0.12
            if x == DX + 48:
                v = 0.03                     # meeting seam of the two leaves
            if y < DY + 4:
                v = 0.2                      # top rail
            for by in (36, 74):
                if by <= y < by + 3:
                    v = 0.18
                    if (x - DX) % 24 == 6 and y == by + 1:
                        v = 0.9              # iron nail
            v += 0.04 * math.sin(y * 0.5)
            put(c, mode, x, y, "wood", v, floor=0.2)


def paint_counter(c, mode):
    """Dark polished planks: highlight lip at y=100..102, seams every ~14px."""
    seams = (114, 128, 142)
    for y in range(COUNTER_Y, UNDER_Y):
        band = sum(1 for s in seams if y > s)
        for x in range(W):
            floor = 0.0
            if y in seams:
                v = 0.04
            elif y == COUNTER_Y:
                v = 0.95
                floor = 0.4                          # lamp-lit edge across the width
            elif y == COUNTER_Y + 1:
                v = 0.78
                floor = 0.22
            elif y == COUNTER_Y + 2:
                v = 0.6
                floor = 0.12
            else:
                v = 0.3 + 0.1 * hz(band, 0, 2)
                v += 0.07 * math.sin((y + 0.8 * math.sin(x * 0.045 + band)) * 2.3)
                if y < 112:
                    v += 0.07 * (112 - y) / 12.0   # polish sheen near the edge
                floor = 0.08
            put(c, mode, x, y, "wood", v, floor=floor)


def paint_under(c, mode):
    """Under-counter cabinet front: panel stiles, rail and grain."""
    for y in range(UNDER_Y, H):
        for x in range(W):
            if y == UNDER_Y:
                v = 0.08
            elif y == UNDER_Y + 1:
                v = 0.28
            elif y >= 178:
                v = 0.12 if y == 178 else 0.05
            else:
                v = 0.3 + 0.06 * math.sin(y * 1.9 + math.sin(x * 0.03) * 1.3)
            if x in (96, 224) or x in (0, W - 1):
                v = 0.05
            elif x in (97, 225):
                v = 0.42
            put(c, mode, x, y, "under", v)


def scene(mode):
    c = Canvas(W, H, P.black)
    paint_wall(c, mode)
    for rect in LATTICES:
        paint_lattice(c, mode, *rect)
    paint_frame(c, mode)
    if mode == "night":
        paint_boards(c, mode)
    else:
        paint_street(c, mode)
    paint_counter(c, mode)
    paint_under(c, mode)
    return c


# ------------------------------------------------------------------ candle
CANDLE_RAMP = [P.black, P.dkbrown, P.wood0, P.wood1, P.wood2, P.wood3, P.tan, P.lamp_pale, P.lamp]


def build_candle():
    """序章第一幕: door crack in the dark frame, candle glow. Candle sprite is drawn by the engine."""
    c = Canvas(W, H, P.black)
    crack_x = 161
    for y in range(H):
        for x in range(W):
            # candle glow circle centred near (158,100)
            d = math.hypot((x - 158) / 76.0, (y - 100) / 60.0)
            I = clamp(1.0 - d) ** 1.4
            seam = x in (40, 118, 200, 280)
            plank = 0.07 + 0.05 * hz(x // 40, 0, 5)
            if seam:
                plank *= 0.4
            dx = abs(x - crack_x)
            half = 2 if 50 < y < 130 else 1          # crack opening: 3..5 px wide
            if dx <= half:
                # faint moonlit blue between the leaves, brighter streak in the middle
                ramp_px(c, x, y, [P.black, P.indigo0, P.indigo1], 0.25 + 0.2 * hz(x, y, 2)
                        + (0.15 if dx == 0 else 0.0))
                continue
            if dx == half + 1:
                ramp_px(c, x, y, [P.black, P.dkbrown, P.wood0, P.wood1], 0.45 + 0.3 * I)  # dark frame edge
                continue
            if dx == half + 2:
                ramp_px(c, x, y, [P.black, P.dkbrown, P.wood0, P.wood1], 0.3 + 0.4 * I)   # bevel, lit by glow
                continue
            v = plank + I * (0.95 + 0.05 * hz(x, y, 1))
            ramp_px(c, x, y, CANDLE_RAMP, v)
    return c


# ------------------------------------------------------------------ title
TITLE_SKY = [P.black, P.indigo0, P.indigo1, P.indigo2, P.mist, P.fog]
TITLE_WALL = [P.indigo1, P.indigo2, P.mist, P.fog]


def house(c, x0, x1, roof_y, base, v, win=(), lit=None):
    """白墙黛瓦 silhouette: whitewashed wall, dark tiled roof with upturned eaves."""
    w = x1 - x0 + 1
    for y in range(roof_y + 9, base):
        for x in range(x0, x1 + 1):
            vv = v - 0.12 * (y - roof_y) / float(base - roof_y)
            ramp_px(c, x, y, TITLE_WALL, vv)
    pts = [(x0 - 3, roof_y + 9), (x0 + 1, roof_y + 3), (x0 + w // 2, roof_y),
           (x1 - 1, roof_y + 3), (x1 + 3, roof_y + 9), (x1 + 2, roof_y + 10), (x0 - 2, roof_y + 10)]
    c.poly(pts, P.indigo0)
    for y in range(roof_y, roof_y + 11):
        for x in range(x0 - 4, x1 + 5):
            if c.get(x, y) == P.indigo0 and (y - roof_y) % 3 == 0:
                c.pixel(x, y, P.indigo1)              # tile rows
    for wx, wy, ww, wh in win:
        c.rect(wx, wy, ww, wh, P.black)
    if lit:
        lx, ly, lw, lh = lit
        c.rect(lx, ly, lw, lh, P.lamp)
        c.vline(lx + lw // 2, ly, ly + lh - 1, P.wood1)
        c.hline(lx, lx + lw - 1, ly + lh // 2, P.wood1)


def build_title():
    c = Canvas(W, H, P.black)
    # night sky, kept calm and dark along the top centre for the title text
    for y in range(0, 116):
        for x in range(W):
            v = 0.04 + 0.42 * (y / 116.0) ** 1.3 + 0.03 * (hz(x, y, 1) - 0.5)
            ramp_px(c, x, y, TITLE_SKY, v)
    for y in range(0, 50):
        for x in range(W):
            if (x < 88 or x > 232) and hz(x, y, 9) > 0.9982:
                c.pixel(x, y, P.fog)
    c.ellipse(266, 26, 6, 6, P.fog)                      # moon (crescent)
    c.ellipse(269, 24, 5, 5, P.indigo0)

    # low mist band across the water-town
    for y in range(60, 124):
        band = clamp(1.0 - abs(y - 96) / 34.0)
        for x in range(W):
            m = clamp(0.5 + 0.5 * math.sin(x * 0.035 + y * 0.11))
            ramp_px(c, x, y, [P.indigo1, P.indigo2, P.mist, P.fog], 0.15 + 0.5 * m * band)

    # far row behind the bridge
    house(c, 94, 118, 84, 106, 0.42, win=[(100, 92, 3, 4)])
    house(c, 122, 146, 78, 106, 0.38, win=[(128, 88, 3, 4), (138, 88, 3, 4)])
    house(c, 176, 198, 82, 106, 0.4)
    house(c, 200, 224, 88, 106, 0.34, win=[(206, 96, 3, 4)])
    for y in range(78, 106):
        for x in range(90, 230):
            if c.get(x, y) != P.black and y > 90:
                blend(c, x, y, P.indigo1, P.mist, 0.12)

    # near houses on both banks
    house(c, 0, 35, 46, 116, 0.62, win=[(6, 66, 5, 7), (24, 66, 5, 7), (6, 90, 5, 8), (24, 90, 5, 8)])
    house(c, 38, 68, 58, 116, 0.55, win=[(44, 72, 5, 7), (58, 72, 5, 7)], lit=(51, 94, 5, 6))
    house(c, 71, 94, 70, 116, 0.45, win=[(76, 88, 4, 6), (86, 88, 4, 6)])
    house(c, 284, 319, 44, 116, 0.6, win=[(290, 64, 5, 7), (306, 64, 5, 7), (290, 88, 5, 8), (306, 88, 5, 8)])
    house(c, 252, 281, 60, 116, 0.52, win=[(258, 76, 4, 7), (270, 76, 4, 7)])
    house(c, 222, 249, 72, 116, 0.42, win=[(228, 90, 4, 6), (240, 90, 4, 6)])

    # canal: dark water with ripples and the lit window's reflection
    for y in range(116, H):
        for x in range(W):
            v = 0.25 + 0.1 * (y - 116) / 64.0
            ramp_px(c, x, y, [P.black, P.indigo0, P.indigo1, P.indigo2], v)
            if y % 5 == 2 and hz(x, y, 6) > 0.86:
                ramp_px(c, x, y, [P.indigo2, P.mist, P.fog], 0.5)
            if 50 <= x <= 56 and 117 <= y <= 130 and (y % 3 != 0 or hz(x, y, 4) > 0.3):
                ramp_px(c, x, y, [P.indigo1, P.wood3, P.lamp], 0.65)

    # mist hugging the waterline
    for y in range(110, 124):
        for x in range(W):
            m = clamp(0.5 + 0.5 * math.sin(x * 0.05 + y * 0.4))
            ramp_px(c, x, y, [P.indigo1, P.indigo2, P.mist], 0.2 + 0.35 * m)

    # arched stone bridge over the canal, centred at x=160
    arch_cx, arch_cy = 160, 150
    for y in range(110, arch_cy + 1):
        for x in range(112, 209):
            dxo, dyo = (x - arch_cx) / 46.0, (y - arch_cy) / 40.0
            dxi, dyi = (x - arch_cx) / 34.0, (y - arch_cy) / 30.0
            if dxo * dxo + dyo * dyo > 1.0:
                continue
            if dxi * dxi + dyi * dyi <= 1.0:
                ramp_px(c, x, y, [P.black, P.indigo0], 0.1)     # water under the arch
                continue
            ang = math.atan2(arch_cy - y, x - arch_cx)
            seg = ang / (math.pi / 11)
            if abs(seg - round(seg)) < 0.08:
                ramp_px(c, x, y, [P.black, P.wall0, P.wall1], 0.2)   # voussoir joint
            else:
                ramp_px(c, x, y, [P.wall0, P.wall1, P.wall2, P.mist], 0.5)
    # deck and railing
    for y in range(103, 110):
        for x in range(112, 209):
            v = 0.75 if y == 103 else (0.5 if y < 109 else 0.2)
            ramp_px(c, x, y, [P.wall0, P.wall1, P.wall2, P.mist, P.fog], v)
    c.hline(112, 208, 101, P.fog)
    c.hline(112, 208, 102, P.mist)
    for x in range(112, 209, 8):
        c.vline(x, 102, 105, P.mist)
    return c


# ------------------------------------------------------------------ main
def main():
    out = {}
    out["counter_day"] = scene("day")
    out["counter_dusk"] = scene("dusk")
    out["counter_night"] = scene("night")
    out["candle"] = build_candle()
    out["title"] = build_title()
    paths = []
    for name, canvas in out.items():
        rel = os.path.join(OUT_DIR, name + ".png")
        canvas.save(rel)
        paths.append(rel)
    sheet = preview(paths, os.path.join("art", "_preview", "backgrounds.png"), scale=2)
    print("wrote", len(paths), "backgrounds; preview:", sheet)


if __name__ == "__main__":
    main()
