# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Market street exterior, batch 19: one market lane in Qingxi town for the bg.market background (320x180)
# and three 64x48 event cards. Stone-paved lane between two rows of white-wall black-tile shop houses, a row
# of stall tables down the lane; camera, light and stall goods change per variant.
# SIZE is the background's 320x180; render the three illus.* variants with --size 64x48.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: striped awning, bamboo stall shed, hanging changshan / short jackets,
# folded cloth bolts, bamboo baskets, blank shop sign, firewood bundles, carrying pole, steelyard, red
# lanterns, New Year goods, firewood seller, farmer with straw hat, buyer, townsfolk in padded coats / crowd.
# Until those are registered, the cards show only the lane, the stalls and the few props below.
# Stand-ins that are what they look like: KayKit tables as stall boards, restaurant crates (plain or with
# vegetables) as produce boxes. The night lantern glow is point lights only, no lantern bodies.
# Architecture (paving, house walls, doors, pent eaves, roofs) is shell built from L.box / L.plane. Modern
# KayKit city props (cars, street lights, hydrants) are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Orientation: the lane runs along x, centre line y=0; house fronts face the lane at y=+LANE and y=-LANE.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.market', 'illus.ev.1939.charcoal_spike', 'illus.ev.1939.night_market',
            'illus.ev.any.market_haggle',)
IDS = {'bg.market': 'bg.market', 'illus.ev.1939.charcoal_spike': 'illus.ev.1939.charcoal_spike',
       'illus.ev.1939.night_market': 'illus.ev.1939.night_market',
       'illus.ev.any.market_haggle': 'illus.ev.any.market_haggle'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.ev.1939.night_market',)
WINTER = ('illus.ev.1939.charcoal_spike',)

LANE = 3.2      # half width of the lane: house fronts at y=+-LANE
D = 5.0         # house depth
HW = 4.4        # house front width
H = 4.0         # eaves height
ROOF = math.radians(28)
STALL_Y = 1.6   # stall row along the +y side of the lane

PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
PLASTER_COLD = (0.66, 0.67, 0.68)
TILE = (0.07, 0.07, 0.08)
WOOD_DARK = (0.10, 0.055, 0.03)
STALL_WOOD = (0.30, 0.18, 0.09)
PAVING = (0.38, 0.36, 0.33)
PAVING_COLD = (0.42, 0.42, 0.43)
PAVING_NIGHT = (0.20, 0.17, 0.14)
LANTERN = (1.0, 0.42, 0.18)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.40), (0.30, 0.72), (0.8, 1.0))
    if variant in WINTER:
        return ((0, 0.18), (0.08, 0.46), (0.30, 0.76), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, side, rgb):
    # Two tilted slabs of shell (pitched roof over a wall box); `side` +1 for houses on +y, -1 on -y.
    rise = (d / 2) * math.tan(ROOF)
    for s, dy in ((1, d / 4), (-1, 3 * d / 4)):
        b = L.box(name, (w + 0.6, d / 2 / math.cos(ROOF) + 0.5, 0.18), (cx, y0 + side * dy, z + rise / 2), rgb)
        b.rotation_euler[0] = s * side * ROOF


def _house(name, cx, side, wall, h):
    y0 = side * LANE
    L.box(name + "_body", (HW, D, h), (cx, y0 + side * D / 2, h / 2), wall)
    # Wide dark shop opening and a pent eave over the ground floor.
    L.box(name + "_door", (2.6, 0.06, 2.3), (cx, y0 - side * 0.02, 1.15), WOOD_DARK)
    b = L.box(name + "_pent", (HW + 0.3, 0.9, 0.12), (cx, y0 - side * 0.3, 2.85), TILE)
    b.rotation_euler[0] = side * math.radians(20)
    _roof(name + "_roof", cx, HW, y0, D + 0.6, h, side, TILE)


def _lane(variant):
    paving = PAVING_NIGHT if variant in NIGHT else PAVING_COLD if variant in WINTER else PAVING
    L.plane("paving", (90, 2 * LANE + 0.4), (0, 0, 0), (0, 0, 0), paving)
    walls = (PLASTER_COLD, PLASTER_OLD) if variant in WINTER else (PLASTER, PLASTER_OLD)
    for side in (1, -1):
        for i, cx in enumerate((-22.5, -18.0, -13.5, -9.0, -4.5, 0.0, 4.5, 9.0, 13.5, 18.0, 22.5)):
            _house("house", cx + (2.2 if side < 0 else 0.0), side, walls[(i + (side < 0)) % 2],
                   H + (0.5 if i % 3 == 1 else 0.0))


def _stall(x, y, rot=0.0):
    j = L.load(L.FURNITURE, "table_medium_long.gltf", (x, y, 0), rot, 1.0, tag="stall")
    L.recolor(j, STALL_WOOD)
    return j


def _crate(name, loc, rot=0.0, s=0.55, sat=0.6, val=0.9):
    j = L.load(L.RESTAURANT, name, loc, rot, s, tag="crate")
    if name in ("crate.gltf", "crate_lid.gltf"):
        L.recolor(j, (0.36, 0.22, 0.10))
    else:
        L.tone(j, sat=sat, val=val)
    return j


def _props(variant):
    if variant == 'bg.market':
        # Clothes stall row: the cloth, baskets and awnings are missing models; boxes under and beside.
        for x in (-6.0, -2.0, 2.0, 6.0):
            _stall(x, STALL_Y)
        for x, r in ((-7.4, 0.2), (-0.1, -0.3), (7.6, 0.4)):
            _crate("crate.gltf", (x, STALL_Y - 0.9, 0), r)
        _crate("crate_lid.gltf", (-7.4, STALL_Y - 0.9, 0.5), 0.2)
        for x in (-4.0, 4.0):
            j = L.load(L.FURNITURE, "chair_stool_wood.gltf", (x, STALL_Y - 1.0, 0), 0.0, 1.0, tag="stool")
            L.recolor(j, STALL_WOOD)
    elif variant == 'illus.ev.1939.charcoal_spike':
        # One near-empty firewood stall: bare board, two empty crates (wood bundles are missing models).
        _stall(0.0, STALL_Y)
        _crate("crate.gltf", (-1.3, STALL_Y - 0.8, 0), 0.3)
        _crate("crate.gltf", (1.4, STALL_Y - 0.6, 0), -0.4)
        _crate("crate_lid.gltf", (1.9, STALL_Y + 0.5, 0), 1.1)
    elif variant == 'illus.ev.1939.night_market':
        # Stalls on both sides with goods; the lanterns are missing, their light is kept (see _lights).
        for x in (-7.5, -3.0, 1.5, 6.0):
            _stall(x, STALL_Y)
            _stall(x + 1.5, -STALL_Y)
        goods = ("crate_buns.gltf", "crate_onions.gltf", "crate_carrots.gltf", "crate_potatoes.gltf")
        for i, x in enumerate((-7.5, -3.0, 1.5, 6.0)):
            _crate(goods[i], (x - 0.5, STALL_Y, 0.75), 0.1 * i, 0.45, sat=0.7, val=0.85)
            _crate(goods[(i + 2) % 4], (x + 2.0, -STALL_Y, 0.75), -0.1 * i, 0.45, sat=0.7, val=0.85)
    elif variant == 'illus.ev.any.market_haggle':
        # Vegetable stall up close: two crates of greens on the ground where the farmer set his load down.
        _stall(0.6, STALL_Y + 0.4)
        _crate("crate_lettuce.gltf", (-0.8, 0.2, 0), 0.15, 0.6, sat=0.8)
        _crate("crate_carrots.gltf", (0.6, 0.0, 0), -0.2, 0.6, sat=0.8)
        _crate("crate_tomatoes.gltf", (0.0, STALL_Y + 0.4, 0.75), 0.0, 0.45, sat=0.8)
        _crate("crate_potatoes.gltf", (1.3, STALL_Y + 0.4, 0.75), 0.2, 0.45, sat=0.7)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Wide view down the lane from the -y side, the clothes stall row across the frame.
    'bg.market': ((0.0, -2.6, 1.7), (0.0, LANE, 1.5), 22),
    # Close on the one bare firewood stall, a little high.
    'illus.ev.1939.charcoal_spike': ((-1.2, -2.3, 2.0), (0.2, STALL_Y, 0.6), 30),
    # Long view down the crowded lane, stalls on both sides.
    'illus.ev.1939.night_market': ((-14.0, 0.2, 1.7), (2.0, 0.0, 1.0), 28),
    # Low, near the produce crates on the ground and the stall behind.
    'illus.ev.any.market_haggle': ((-1.6, -2.4, 1.3), (0.4, 1.0, 0.5), 30),
}


def _lights(variant, toon):
    if variant in NIGHT:
        L.world((0.05, 0.06, 0.12), 0.35)
        L.light('SUN', (0, 0, 6), 0.25, (0.55, 0.62, 0.95), rot=(math.radians(30), 0, math.radians(20)))
        # Lantern glow over each stall (lantern models are missing).
        for x in (-7.5, -3.0, 1.5, 6.0):
            L.light('POINT', (x, STALL_Y - 0.6, 2.4), 90, LANTERN, size=0.3)
            L.light('POINT', (x + 1.5, -STALL_Y + 0.6, 2.4), 90, LANTERN, size=0.3)
    elif variant in WINTER:
        L.world((0.70, 0.74, 0.82), 0.8)
        # Low, pale winter sun.
        L.light('SUN', (0, 0, 6), 2.2, (0.92, 0.94, 1.0), rot=(math.radians(62), 0, math.radians(-30)))
        L.light('AREA', (0.0, -3.0, 4.0), 80, (0.85, 0.90, 1.0), rot=(math.radians(40), 0, 0), size=4)
    else:
        L.world((0.80, 0.82, 0.86), 0.9)
        L.light('SUN', (0, 0, 6), 3.4, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-25)))
        L.light('AREA', (0.0, -3.0, 4.0), 120, (1.0, 0.97, 0.92), rot=(math.radians(40), 0, 0), size=4)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _lane(variant)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
