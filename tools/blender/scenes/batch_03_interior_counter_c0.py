# Counter interior, batch 03: the main counter backdrop (bg.counter.day / dusk / night, 320x180) and nine
# 64x48 card illustrations shot from other angles in the same room. One room shell; camera, lights and a few
# props change per variant.
# Backdrop (I-203): the clerk's eye sits just above a bare counter top. The counter's far edge is on y=100 and
# its near edge on y~150 of the 320x180 image. The back wall fills y<100, with the doorway at x 112..208
# (card_layout.gd DOOR / COUNTER / UNDER divided by SCALE 4). The counter top and wall stay empty for
# S_HOTSPOTS, S_PROP_SPOTS, S_SIGN, S_DOOR_FLAG and S_CURIO. The night oil lamp at about (302, 78) is the
# code-drawn prop.lamp, so only its light is here. day / dusk / night differ in lights only (pixel-aligned).
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: lattice double-door leaves; Chinese white-wall black-tile houses (the
# KayKit City row houses stand in, as in the sample); counter rail, abacus, cash box, rope and brass lock,
# coins, cloth purse, cloth bundle, rice sack, bamboo basket, lattice window, ladder; and every person
# (stranger's hand, short-jacket men, old man in skullcap, travelling buyers, village woman, messenger).
# Until those are registered, the card variants show only their setting.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS),
# or teach render.py / list_jobs.py to read SIZES. Card cameras are framed for 4:3.
# Model orientations are taken from the sample scenes: furniture fronts face -y and City houses face +y at
# rot_z=0.
# NOT YET RENDERED: writing this file and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.counter.day', 'bg.counter.dusk', 'bg.counter.night', 'illus.bf.any.mystery_box',
            'illus.bf.any.quiet_fee', 'illus.es.counter', 'illus.ky.old_customers', 'illus.ky.traveling_buyers',
            'illus.ev.1939.countryside_word', 'illus.ev.1939.district_levy', 'illus.ev.any.rain_leak',
            'illus.fa.1938.kin_money',)
IDS = {'bg.counter.day': 'bg.counter.day', 'bg.counter.dusk': 'bg.counter.dusk',
       'bg.counter.night': 'bg.counter.night', 'illus.bf.any.mystery_box': 'illus.bf.any.mystery_box',
       'illus.bf.any.quiet_fee': 'illus.bf.any.quiet_fee', 'illus.es.counter': 'illus.es.counter',
       'illus.ky.old_customers': 'illus.ky.old_customers',
       'illus.ky.traveling_buyers': 'illus.ky.traveling_buyers',
       'illus.ev.1939.countryside_word': 'illus.ev.1939.countryside_word',
       'illus.ev.1939.district_levy': 'illus.ev.1939.district_levy',
       'illus.ev.any.rain_leak': 'illus.ev.any.rain_leak', 'illus.fa.1938.kin_money': 'illus.fa.1938.kin_money'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.counter.day', 'bg.counter.dusk', 'bg.counter.night')
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

BW = 8.0       # front wall (with the street door) y; the clerk looks towards +y
RW = -2.6      # rear wall behind the clerk, y
SW = 7.0       # side walls at x = +-SW
TOP = 1.90     # counter top height (high pawnshop counter, ~1.4 m)
DOOR_W = 1.35  # half width of the doorway
DOOR_H = 3.28  # doorway height
CEIL = 4.2
LAMP = (3.8, BW - 0.4, 1.46)  # flame of the code-drawn prop.lamp, image (302, 78)

WOOD_DARK = (0.10, 0.055, 0.03)
WOOD = (0.20, 0.11, 0.05)
PLASTER = (0.66, 0.60, 0.47)


def ramp(variant):
    if variant == 'bg.counter.night':
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in ('bg.counter.dusk', 'illus.ev.any.rain_leak'):
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room():
    # Shell only (red line 1): floor, ceiling, walls, wainscot, posts, beams, door frame.
    L.plane("floor", (2 * SW, BW - RW), (0, (BW + RW) / 2, 0), (0, 0, 0), (0.16, 0.12, 0.09))
    L.plane("ceiling", (2 * SW, BW - RW), (0, (BW + RW) / 2, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    side = SW - DOOR_W
    for s in (-1, 1):
        L.box("wall_front", (side, 0.3, CEIL), (s * (DOOR_W + side / 2), BW + 0.15, CEIL / 2), PLASTER)
        L.box("wainscot", (side, 0.06, 1.6), (s * (DOOR_W + side / 2), BW - 0.03, 0.8), WOOD)
        L.box("wall_side", (0.3, BW - RW, CEIL), (s * (SW + 0.15), (BW + RW) / 2, CEIL / 2), PLASTER)
        L.box("doorpost", (0.22, 0.4, DOOR_H + 0.02), (s * (DOOR_W + 0.11), BW - 0.05, DOOR_H / 2), WOOD_DARK)
        L.box("post", (0.3, 0.3, CEIL), (s * 4.45, BW - 0.25, CEIL / 2), WOOD_DARK)
    L.box("lintel", (2 * DOOR_W, 0.3, CEIL - DOOR_H), (0, BW + 0.15, (CEIL + DOOR_H) / 2), PLASTER)
    L.box("beam_front", (2 * SW, 0.4, 0.42), (0, BW - 0.25, DOOR_H + 0.23), WOOD_DARK)
    L.box("wall_rear", (2 * SW, 0.3, CEIL), (0, RW - 0.15, CEIL / 2), PLASTER)
    L.box("wainscot_rear", (2 * SW, 0.06, 1.0), (0, RW + 0.03, 0.5), WOOD)
    for y in (1.2, 3.6, 6.0):
        L.box("beam", (2 * SW, 0.3, 0.3), (0, y, CEIL - 0.15), WOOD_DARK)


def _counter():
    # Counter body from the kitchen-counter model (as in the sample), fronts to the customer side, under a
    # plain top slab. The backdrop camera sees only the slab.
    for x in (-5.0, -3.0, -1.0, 1.0, 3.0):
        c = L.load(L.RESTAURANT, "kitchencounter_straight_A.gltf", (x, 0.5, 0), math.pi, 1.0, tag="counter")
        L.stretch(c, 1.0, 0.5, TOP - 0.12)
        L.recolor(c, WOOD)
    L.box("countertop", (10.6, 1.0, 0.12), (-0.3, 0.5, TOP - 0.06), (0.28, 0.15, 0.07))


def _rear_shelves():
    # Goods shelves on the wall behind the clerk; only card cameras see them.
    for x in (-3.2, 0.0, 3.2):
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (x, RW + 0.35, 0), math.pi, 1.3, tag="shelf"),
               sat=0.3, val=0.55)
    for x0, z in ((-4.4, 1.05), (-1.2, 1.05), (2.0, 1.05), (-4.4, 2.05), (2.0, 2.05)):
        L.jars_on(x0, x0 + 2.2, RW + 0.45, z, int(x0 * 3 + z * 5))


def _side_shelves():
    # Left wall of the customer area: shelves of jars, crates stacked by the door.
    for y in (3.2, 5.6):
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (-SW + 0.35, y, 0), math.pi / 2, 1.3, tag="shelf"),
               sat=0.3, val=0.55)
    for y, z in ((2.5, 1.05), (4.9, 1.05), (2.5, 2.05)):
        for i, k in enumerate(("jar_B_large", "jar_D_large", "jar_C_large")):
            L.tone(L.load(L.RESTAURANT, k + ".gltf", (-SW + 0.45, y + i * 0.5, z), 0.0, 0.8, tag="jar"),
                   sat=0.35, val=0.9)
    for x, y, z in ((-5.6, 7.0, 0), (-4.7, 7.1, 0), (-5.2, 7.0, 0.8)):
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (x, y, z), 0.0, 0.5, tag="crate"), (0.35, 0.20, 0.09))


def _street():
    # Street across the door; the opposite row of houses faces the shop.
    L.plane("street", (60, 12), (0, BW + 6, 0.01), (0, 0, 0), (0.42, 0.38, 0.33))
    for x, k in ((-7.5, "C"), (-3.5, "A"), (0.5, "B"), (4.5, "E"), (8.5, "F")):
        L.tone(L.load(L.CITY, "building_%s_withoutBase.gltf" % k, (x, BW + 8.5, -0.2), math.pi, 2.4,
                      tag="opposite"), sat=0.15, val=0.95)


def _sky(rgb, strength):
    L.emit_plane("sky", (80, 40), (0, BW + 30, 10), (math.radians(90), 0, 0), rgb, strength)


def _props(variant):
    if variant == 'illus.bf.any.mystery_box':
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (0.0, 0.5, TOP), 0.3, 0.45, tag="box"), (0.35, 0.20, 0.09))
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (0.0, 0.5, TOP + 0.36), 0.3, 0.45, tag="box"),
                  (0.42, 0.25, 0.11))
    elif variant == 'illus.es.counter':
        b = L.load(L.FURNITURE, "book_set.gltf", (0.6, 0.45, TOP), 0.2, 0.55, tag="ledger")
        L.tone(b, sat=0.25, val=0.7)
        L.noline(b)
    elif variant == 'illus.ev.any.rain_leak':
        L.recolor(L.load(L.RESTAURANT, "bowl.gltf", (-1.0, 4.6, 0), 0.0, 2.6, tag="basin"), (0.30, 0.17, 0.08))


# variant: (camera location, look-at point, lens mm). The three backdrops share 'bg.counter.day'.
CAMS = {
    'bg.counter.day': ((0.0, -1.0, TOP + 0.31), (0.0, BW, TOP + 0.31), 36),
    'illus.bf.any.mystery_box': ((0.9, 3.0, 2.75), (0.0, 0.5, 2.1), 30),
    'illus.bf.any.quiet_fee': ((-2.6, 3.4, 2.5), (-0.6, 0.3, 1.8), 28),
    'illus.es.counter': ((3.4, 6.2, 2.4), (0.0, -0.4, 1.5), 24),
    'illus.ky.old_customers': ((0.9, -1.9, 2.3), (0.0, BW, 1.7), 26),
    'illus.ky.traveling_buyers': ((2.2, 3.6, 2.6), (-0.8, RW, 1.6), 26),
    'illus.ev.1939.countryside_word': ((-1.2, -0.6, 2.2), (0.4, BW, 1.95), 34),
    'illus.ev.1939.district_levy': ((2.6, 2.6, 1.6), (-SW, 5.4, 1.1), 26),
    'illus.ev.any.rain_leak': ((2.2, 7.2, 0.8), (-0.8, 3.2, 2.7), 20),
    'illus.fa.1938.kin_money': ((0.7, -0.5, 3.1), (0.0, 1.6, TOP), 26),
}


def _camera(variant):
    key = 'bg.counter.day' if variant in BACKDROPS else variant
    loc, look, lens = CAMS[key]
    c = L.camera(loc, look, lens)
    if key == 'bg.counter.day':
        # Level camera with the horizon lifted to y=50 of 180 (shift is in units of the image width), so the
        # counter's far edge lands on y=100 and its near edge on y~150 while verticals stay straight.
        c.data.shift_y = -40.0 / SIZE[0]


def _lights(variant, toon):
    sky = {'bg.counter.dusk': ((1.0, 0.58, 0.26), 1.5), 'bg.counter.night': ((0.10, 0.15, 0.36), 1.6),
           'illus.ev.any.rain_leak': ((0.42, 0.46, 0.52), 1.2)}.get(variant, ((0.95, 0.93, 0.85), 2.5))
    _sky(*sky)
    door = (0, BW - 0.6, 2.4)
    if variant == 'bg.counter.dusk':
        L.world((0.50, 0.32, 0.22), 0.5)
        L.light('SUN', (0, 0, 6), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(70), 0, math.radians(180)))
        L.light('AREA', door, 350, (1.0, 0.60, 0.30), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, -1.6, 3.6), 90, (1.0, 0.80, 0.60), rot=(math.radians(60), 0, 0), size=5)
        L.light('POINT', LAMP, 30, (1.0, 0.66, 0.30), size=0.2)
    elif variant == 'bg.counter.night':
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        L.light('AREA', door, 120, (0.45, 0.55, 1.0), rot=(math.radians(-90), 0, 0), size=2.5)
        # Oil lamp at the foot of the right wall: the only warm source indoors.
        L.light('POINT', LAMP, 160, (1.0, 0.62, 0.28), size=0.2)
        # Two lit windows across the street (light only; no glowing planes).
        for x in (-1.0, 1.4):
            L.light('POINT', (x, BW + 7.6, 2.0), 35, (1.0, 0.70, 0.35), size=0.15)
    elif variant == 'illus.ev.any.rain_leak':
        L.world((0.30, 0.33, 0.38), 0.45)
        L.light('AREA', door, 220, (0.70, 0.78, 0.90), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (3.0, 2.0, 3.8), 120, (0.80, 0.82, 0.88), rot=(math.radians(40), 0, math.radians(60)),
                size=4)
    else:
        L.world((0.80, 0.80, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(35), 0, math.radians(150)))
        L.light('AREA', door, 500, (1.0, 0.96, 0.88), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, -1.6, 3.6), 260, (1.0, 0.97, 0.92), rot=(math.radians(60), 0, 0), size=5)
        if variant not in BACKDROPS:
            # Most cards look back at the counter from the customer side: fill from there too.
            L.light('AREA', (0, 5.0, 3.8), 260, (1.0, 0.95, 0.85), rot=(math.radians(-55), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _counter()
    _street()
    if variant not in BACKDROPS:
        _rear_shelves()
        _side_shelves()
        _props(variant)
    _camera(variant)
    _lights(variant, toon)
