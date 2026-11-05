#!/usr/bin/env python3
"""Town building sprites for 青溪镇, reusing the mockup builders.

Writes art/town/buildings/*.png and tools/art/town/building_meta.json.
Does not touch docs/town/mockup_src.
"""
import os
import sys
import json
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C, mix, font_mask
import gen_buildings as gb

OUT = os.path.join(ROOT, "art", "town", "buildings")
META_PATH = os.path.join(ROOT, "tools", "art", "town", "building_meta.json")

# Exact roof-tile colours. wall0 is 1 step from rf1, so match exactly.
RF = {C.rf0[:3], C.rf1[:3], C.rf2[:3], C.rf3[:3], C.rf4[:3]}


def door_at(opening, dw=16, dh=24):
    """16×24 interaction rect sitting on the bottom centre of an opening."""
    ox, oy, ow, oh = opening
    x = ox + max(0, (ow - dw) // 2)
    y = oy + max(0, oh - dh)
    return [int(x), int(y), dw, dh]


def pack_meta(c, door, roof_split, variants=None):
    w, h = c.w, c.h
    x, y, dw, dh = door
    if not (dw == 16 and dh == 24 and 0 <= x and x + dw <= w and 0 <= y and y + dh <= h):
        raise SystemExit("bad door %s on %dx%d" % (door, w, h))
    if not (0 < roof_split < h):
        raise SystemExit("bad roof_split %s on h=%d" % (roof_split, h))
    return {
        "size": [w, h],
        "door": [x, y, dw, dh],
        "footprint": [0, roof_split, w, h - roof_split],
        "roof_split_y": roof_split,
        "variants": variants or {},
    }


def paint_night(c, darken_until, lamps):
    """Darken roof tiles above the front wall; light 2–4 window pixels."""
    n = c.copy()
    limit = max(0, min(darken_until, n.h))
    for y in range(limit):
        for x in range(n.w):
            p = n.get(x, y)
            if p[3] and p[:3] in RF:
                n.put(x, y, mix(p, C.rf0, 0.25))
    placed = []
    for x, y in lamps:
        fx, fy = x, y
        if n.get(fx, fy)[3] == 0:
            found = None
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if n.get(x + dx, y + dy)[3]:
                        found = (x + dx, y + dy)
                        break
                if found:
                    break
            if not found:
                continue
            fx, fy = found
        n.put(fx, fy, C.flame if len(placed) % 2 == 0 else C.lamp)
        placed.append((fx, fy))
        if len(placed) == 4:
            break
    if len(placed) < 2:
        raise SystemExit("night variant needs 2–4 lamp pixels, got %s" % placed)
    return n


# ---------------------------------------------------------------- new builds
def build_baogong():
    """保公所: grey-white official front, dark plaque, a notice, modest roof.

    Canvas is 70×90, the same footprint class as the post office.
    """
    fw, roof_h, wall_h = 62, 22, 59
    c, g = gb.shell(fw, roof_h, wall_h, 801, moss=0.03, light=1)
    x, wy, gr = g["fx"], g["wall_y"], g["ground"]
    lh = gr - wy
    gb.plaster(c, x, wy, fw, lh, 802, stain=0.22)
    # grey pilasters + a stone lintel: official, not a shopfront
    for px in (x, x + fw - 5):
        c.rect(px, wy, 5, lh, C.wall1)
        c.vline(px, wy, gr - 1, C.fog)
        c.vline(px + 4, wy, gr - 1, C.wall0)
    c.rect(x, wy, fw, 4, C.wall2)
    c.hline(x, x + fw - 1, wy, C.mist)
    c.hline(x, x + fw - 1, wy + 3, C.wall0)
    # one shuttered window on the right
    wx, wynd = x + fw - 20, wy + 8
    c.rect(wx - 1, wynd - 1, 14, 16, C.wall0)
    gb.lattice(c, wx, wynd, 12, 14, frame=C.wall1, paper=C.ww0)
    c.hline(wx - 1, wx + 12, wynd + 14, C.st3)
    gb.plinth(c, x, gr - 4, fw, 4, seed=8)
    # closed double door over the plinth, stone surround
    dw, dh = 16, 24
    dx = x + (fw - dw) // 2
    dy = gr - dh
    c.rect(dx - 3, dy - 4, dw + 6, dh + 4, C.wall1)
    c.hline(dx - 3, dx + dw + 2, dy - 4, C.fog)
    c.vline(dx - 3, dy - 4, gr - 1, C.fog)
    c.vline(dx + dw + 2, dy - 4, gr - 1, C.wall0)
    c.rect(dx, dy, dw, dh, C.wood0)
    c.rect(dx, dy, dw // 2, dh, C.dkbrown)
    c.vline(dx, dy, dy + dh - 1, C.wood2)
    c.vline(dx + dw // 2, dy, dy + dh - 1, C.black)
    c.vline(dx + dw - 1, dy, dy + dh - 1, C.black)
    for yy in (dy + 5, dy + 13):
        c.hline(dx + 1, dx + dw - 2, yy, C.wood1)
    c.put(dx + dw // 2 - 2, dy + dh // 2, C.gold)
    c.put(dx + dw // 2 + 1, dy + dh // 2, C.gold)
    gb.under_eave_shadow(c, x, wy, fw, rows=(0.42, 0.24, 0.12))
    gb.finish(c, g)
    # dark vertical plaque 保公所 (the 保 is the office mark)
    chars = "保公所"
    gap = 1
    masks = [font_mask(ch, 12) for ch in chars]
    th = sum(m.height + gap for m in masks) - gap
    tw = max(m.width for m in masks)
    bw, bh = tw + 6, th + 6
    bx, by = x + 7, wy + 8
    c.rect(bx, by, bw, bh, C.black)
    c.frame(bx, by, bw, bh, C.gold)
    c.hline(bx + 1, bx + bw - 2, by + 1, mix(C.black, C.gold, 0.35))
    c.text_v(bx + 3, by + 3, chars, C.gold, 12, gap=gap)
    # pasted notice
    nx, ny = x + fw - 20, wy + 28
    c.rect(nx, ny, 13, 16, C.paper_hi)
    c.frame(nx, ny, 13, 16, C.paper_old)
    c.hline(nx, nx + 12, ny + 16, C.ww3)
    c.hline(nx + 2, nx + 10, ny + 3, C.gray)
    c.hline(nx + 2, nx + 8, ny + 6, C.gray)
    c.hline(nx + 2, nx + 10, ny + 9, C.gray)
    c.rect(nx + 7, ny + 11, 4, 3, C.seal_red)
    c.put(nx + 8, ny + 12, C.dkred)
    roof_split = g["upper_y"]  # main roof ends, grey wall begins
    return c, door_at((dx, dy, dw, dh)), roof_split, g["wall_y"]


def build_police_open():
    """警察所 with the door shut, not condemned: no boards, no padlock, full colour."""
    fw = 66
    c, g = gb.shell(fw, 24, 44, 501)
    x, wy, gr = g["fx"], g["wall_y"], g["ground"]
    lh = gr - wy
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
    for px_ in (x, x + fw - 4):
        c.rect(px_, wy, 4, lh, C.fog)
        c.vline(px_, wy, gr - 1, C.white)
        c.vline(px_ + 3, wy, gr - 1, C.mist)
    for wx in (x + 7, x + fw - 19):
        c.rect(wx, wy + 12, 12, 16, C.wall0)
        c.rect(wx + 1, wy + 13, 5, 14, C.indigo1)
        c.rect(wx + 6, wy + 13, 5, 14, C.indigo1)
        for yy in range(wy + 14, wy + 27, 2):
            c.hline(wx + 1, wx + 10, yy, C.indigo0)
        c.hline(wx - 1, wx + 12, wy + 28, C.fog)
        c.hline(wx - 1, wx + 12, wy + 29, C.mist)
    # closed door — same red leaves as the locked sprite, no X, no lock
    dx, dw = x + fw // 2 - 9, 18
    dy, dh = wy + 12, lh - 12
    c.rect(dx - 2, wy + 10, dw + 4, lh - 10, C.fog)
    c.rect(dx, dy, dw, dh, C.dkred)
    c.rect(dx, dy, dw // 2, dh, mix(C.dkred, C.black, 0.18))
    c.vline(dx + dw // 2, dy, gr - 1, C.black)
    c.vline(dx, dy, dy + dh - 1, mix(C.dkred, C.white, 0.15))
    c.vline(dx + dw - 1, dy, dy + dh - 1, mix(C.dkred, C.black, 0.35))
    for yy in (wy + 16, wy + 26, wy + 34):
        c.hline(dx + 1, dx + dw - 2, yy, mix(C.dkred, C.black, 0.4))
    c.put(dx + dw // 2 - 2, wy + 28, C.gold)
    c.put(dx + dw // 2 + 2, wy + 28, C.gold)
    gb.plaque(c, x + fw // 2, wy + 1, "警察所", face=C.ww0, ink=C.black, border=C.wall0)
    # neat notice, not a torn condemnation
    nx, ny = x + 6, wy + 31
    c.rect(nx, ny, 9, 9, C.paper)
    c.hline(nx + 1, nx + 6, ny + 2, C.gray)
    c.hline(nx + 1, nx + 5, ny + 4, C.gray)
    c.hline(nx + 1, nx + 6, ny + 6, C.gray)
    c.rect(nx + 5, ny + 5, 3, 2, C.seal_red)
    gb.under_eave_shadow(c, x, wy, fw)
    gb.finish(c, g)
    roof_split = g["upper_y"]
    return c, door_at((dx, dy, dw, dh)), roof_split, g["wall_y"]


def build_dock_shed():
    """Low open dock shed: tiled roof, posts, no full wall, sign 埠. ~64×48."""
    fw, roof_h, wall_h = 56, 16, 23
    c, g = gb.shell(fw, roof_h, wall_h, 901, step_h=3, moss=0.1, light=0)
    x, wy, gr = g["fx"], g["wall_y"], g["ground"]
    lh = gr - wy
    # far wall is only a short band under the eaves; the bay stays open
    gb.planks(c, x + 6, wy + 2, fw - 12, 6, seed=11, dark=True)
    gb.rafters(c, x, wy, fw)
    gb.beam(c, x, wy + 1, fw, 2)
    for px in (x, x + 17, x + fw - 20, x + fw - 3):
        gb.post(c, px, wy, lh, 3)
    # crate and a rope coil standing in the open bay
    c.rect(x + fw - 15, gr - 10, 9, 8, C.wood1)
    c.hline(x + fw - 15, x + fw - 7, gr - 10, C.wood3)
    c.vline(x + fw - 15, gr - 10, gr - 3, C.wood2)
    c.hline(x + fw - 15, x + fw - 7, gr - 6, C.wood0)
    c.ellipse(x + 14, gr - 5, 4, 2.2, C.wood0)
    c.ellipse(x + 14, gr - 6, 2.6, 1.3, C.wood2)
    c.put(x + 14, gr - 6, C.tan)
    gb.under_eave_shadow(c, x, wy, fw, rows=(0.45, 0.22))
    gb.finish(c, g)
    gb.plaque(c, x + 16, wy + 4, "埠", face=C.wood0, ink=C.paper_hi, border=C.tan, size=12)
    roof_split = g["upper_y"]
    # open bay, bottom centre — the way onto the dock
    return c, [(c.w - 16) // 2, c.h - 24, 16, 24], roof_split, g["wall_y"]


def build_market_stall():
    """Open market stall: tan cloth awning, baskets, sign 集. 56×40."""
    W, H = 56, 40
    c = Cv(W, H)
    # posts
    for px in (4, W - 7):
        c.rect(px, 8, 3, 28, C.wood1)
        c.vline(px, 8, 35, C.wood2)
        c.vline(px + 2, 8, 35, C.wood0)
    # awning frame
    c.rect(2, 6, W - 4, 3, C.wood1)
    c.hline(2, W - 3, 6, C.wood2)
    c.hline(2, W - 3, 8, C.wood0)
    for y in range(9, 17):
        for x in range(3, W - 3):
            stripe = (x // 4) % 2 == 0
            col = C.tan if stripe else mix(C.tan, C.paper_hi, 0.28)
            if y >= 15:
                col = mix(col, C.wood0, 0.35)
            c.put(x, y, col)
    c.hline(3, W - 4, 9, mix(C.tan, C.white, 0.35))
    for x in range(3, W - 3):
        if (x // 3) % 2 == 0:
            c.put(x, 17, C.tan)
            c.put(x, 18, mix(C.tan, C.dkbrown, 0.25))
    # counter
    c.rect(8, 26, 40, 5, C.wood2)
    c.hline(8, 47, 26, C.wood3)
    c.hline(8, 47, 27, C.tan)
    c.hline(8, 47, 30, C.wood0)
    c.vline(10, 31, 37, C.wood1)
    c.vline(44, 31, 37, C.wood1)
    # baskets of goods
    for bx, fill in ((16, C.paper), (28, C.g3), (39, C.paper_old)):
        c.ellipse(bx, 25, 5, 3, C.wood1)
        c.ellipse(bx, 24, 3.4, 2, C.wood3)
        c.ellipse(bx, 23, 2.6, 1.4, fill)
    # hanging sign 集
    sig = font_mask("集", 12)
    sw, sh = sig.width + 6, sig.height + 5
    sx, sy = (W - sw) // 2, 11
    c.vline(W // 2, 8, sy, C.wood0)
    c.rect(sx, sy, sw, sh, C.seal_red)
    c.frame(sx, sy, sw, sh, C.dkred)
    c.hline(sx + 1, sx + sw - 2, sy + 1, mix(C.seal_red, C.white, 0.25))
    c.text(sx + 3, sy + 2, "集", C.paper_hi, 12)
    c.hline(6, W - 7, H - 1, C.st1)
    roof_split = 20  # cloth awning ends, stall front begins
    return c, [ (W - 16) // 2, H - 24, 16, 24], roof_split, roof_split


def main():
    os.makedirs(OUT, exist_ok=True)
    # Geometry of the mockup builders (roof ends where the upper wall begins).
    # shell: upper_y = UP + roof_h. Pawnshop roof is blitted at off=14.
    # Sun gatehouse roof bottom is blit_y + UP + roof_h = 30.
    pawn = gb.build_pawnshop()
    rice = gb.build_rice()
    pharm = gb.build_pharmacy()
    tea = gb.build_teahouse()
    post = gb.build_post()
    sun = gb.build_sun_gate()
    locked = gb.build_police()
    police, police_door, police_split, police_wall = build_police_open()
    bao, bao_door, bao_split, _bao_wall = build_baogong()
    dock, dock_door, dock_split, _dock_wall = build_dock_shed()
    stall, stall_door, stall_split, _stall_wall = build_market_stall()

    if (police.w, police.h) != (locked.w, locked.h):
        raise SystemExit("police size mismatch %s vs locked %s" % (
            (police.w, police.h), (locked.w, locked.h)))

    # Door openings measured from the builders (x, y, w, h), then snapped to 16×24.
    # pawn: doorway (29, 74, 20, 30) centred near x=39
    # rice: open front (7, 49, 60, 27)
    # pharmacy: (23, 59, 24, 31)
    # teahouse: (7, 59, 68, 31)
    # post: green door (27, 62, 16, 28), ground at 90
    # sun: lacquer doors (37, 38, 26, 38)
    specs = {
        "pawnshop": (pawn, door_at((29, 74, 20, 30)), 42, 70),
        "ricehall": (rice, door_at((7, 49, 60, 27)), 32, 32),
        "pharmacy": (pharm, door_at((23, 59, 24, 31)), 28, 56),
        "teahouse": (tea, door_at((7, 59, 68, 31)), 28, 56),
        "post": (post, door_at((27, 62, 16, 28)), 28, 56),
        "sunfu": (sun, door_at((37, 38, 26, 38)), 30, None),
        "police": (police, police_door, police_split, police_wall),
        "baogong": (bao, bao_door, bao_split, None),
        "dock_shed": (dock, dock_door, dock_split, None),
        "market_stall": (stall, stall_door, stall_split, None),
    }

    nights = {
        "pawnshop": [(10, 51), (13, 53), (60, 51), (63, 53)],
        "teahouse": [(8, 33), (9, 35), (17, 33), (26, 34)],
        "ricehall": [(18, 53), (20, 55), (46, 54)],
        "pharmacy": [(9, 36), (12, 38), (55, 36), (58, 38)],
        "post": [(12, 37), (14, 39), (54, 37), (56, 39)],
    }
    night_names = {
        "pawnshop": "pawnshop_night.png",
        "teahouse": "teahouse_night.png",
        "ricehall": "ricehall_night.png",
        "pharmacy": "pharmacy_night.png",
        "post": "post_night.png",
    }

    meta = {}
    for bid, (cv, door, split, _wall) in specs.items():
        variants = {}
        cv.save(os.path.join(OUT, bid + ".png"))
        if bid in nights:
            darken = _wall if _wall else split
            night = paint_night(cv, darken, nights[bid])
            fn = night_names[bid]
            night.save(os.path.join(OUT, fn))
            variants["night"] = "art/town/buildings/" + fn
        if bid == "police":
            locked.save(os.path.join(OUT, "police_locked.png"))
            variants["locked"] = "art/town/buildings/police_locked.png"
        meta[bid] = pack_meta(cv, door, split, variants)

    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("BUILDINGS_OK")
    print(json.dumps(meta, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
