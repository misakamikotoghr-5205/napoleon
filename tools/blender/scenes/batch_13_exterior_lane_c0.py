# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Lane exterior, batch 13: eleven 64x48 card illustrations in a residential lane of Qingxi town. One row of
# white-wall black-tile house fronts faces the lane (front row, facing -y), a second row stands across it;
# camera, light, door state and a few props change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: every person (Shen Ruhua with a small bundle, kind neighbour, clerk in
# a long gown with a register, policeman, household with an old man and children, quarrelling neighbours in
# short jackets / long gowns, peacemaker, quarrelling women, old man peeping through the gate, creditor and
# landlord in long gowns holding account / rent books, mourners in white, craftsman on the roof), oil lamp,
# small cloth bundle, bamboo laundry poles and hung clothes, white cloth drapes, white paper lanterns,
# candles, firewood bundles and woodpile, wooden ladder, rain streaks and drips. The oil lamp and lanterns
# are light only. Until those are registered, the cards show only their setting and the few props below.
# Stand-ins that are what they look like: KayKit door_A leaves (stretched) for the plank house doors, the
# gate leaves and the loose broken door board; pot_large recoloured as the wooden basin under the leak;
# table_medium recoloured as the offering table.
# Architecture (walls, door frames, stone gate frame, gate hood, eaves, roofs, the leak gap in the roof) is
# room shell built from L.box / L.plane. Modern KayKit city props are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Orientation: front-row house fronts face -y at y=0, the lane runs along x between y=0 and y=-LANE.
# door_A runs from its hinge along +x at rot_z=0 (glTF bounds x 0..1.6, height 2.8).
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.bf.any.street_bed', 'illus.ev.1940.household_count', 'illus.ev.any.alley_row',
            'illus.fa.any.neighbor_row', 'illus.st.ask_kin', 'illus.lf.1938.spring_roof',
            'illus.lf.1939.fuel_stock', 'illus.lf.any.debt_due', 'illus.lf.any.funeral', 'illus.lf.any.rent',
            'illus.lf.any.repair_house',)
IDS = {'illus.bf.any.street_bed': 'illus.bf.any.street_bed',
       'illus.ev.1940.household_count': 'illus.ev.1940.household_count',
       'illus.ev.any.alley_row': 'illus.ev.any.alley_row', 'illus.fa.any.neighbor_row': 'illus.fa.any.neighbor_row',
       'illus.st.ask_kin': 'illus.st.ask_kin', 'illus.lf.1938.spring_roof': 'illus.lf.1938.spring_roof',
       'illus.lf.1939.fuel_stock': 'illus.lf.1939.fuel_stock', 'illus.lf.any.debt_due': 'illus.lf.any.debt_due',
       'illus.lf.any.funeral': 'illus.lf.any.funeral', 'illus.lf.any.rent': 'illus.lf.any.rent',
       'illus.lf.any.repair_house': 'illus.lf.any.repair_house'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.bf.any.street_bed',)
DUSK = ('illus.st.ask_kin', 'illus.lf.any.debt_due')
OVERCAST = ('illus.lf.1938.spring_roof', 'illus.lf.1939.fuel_stock', 'illus.lf.any.funeral')
WET = ('illus.lf.1938.spring_roof',)

LANE = 3.6     # lane width
D = 5.0        # house depth
HW = 4.0       # house front width
H = 4.6        # eaves height
DOOR_W = 1.7
DOOR_H = 2.5
ROOF = math.radians(28)

WOOD_DARK = (0.10, 0.055, 0.03)
WOOD = (0.20, 0.11, 0.05)
PLANK = (0.16, 0.09, 0.045)
PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
WET_STONE = (0.24, 0.23, 0.22)
DARK = (0.02, 0.015, 0.01)

# Hero door at x=0 per variant: (style, leaf state). style: 'plain' plank door, 'stone' stone gate frame
# (shikumen), 'gate' courtyard gate with a tiled hood. State of the right leaf: 'shut', 'ajar' (a crack
# open), 'open' (swung in).
HERO = {
    'illus.bf.any.street_bed': ('plain', 'open'),
    'illus.ev.1940.household_count': ('plain', 'open'),
    'illus.ev.any.alley_row': ('plain', 'shut'),
    'illus.fa.any.neighbor_row': ('plain', 'open'),
    'illus.st.ask_kin': ('gate', 'ajar'),
    'illus.lf.1938.spring_roof': ('plain', 'shut'),
    'illus.lf.1939.fuel_stock': ('plain', 'shut'),
    'illus.lf.any.debt_due': ('plain', 'open'),
    'illus.lf.any.funeral': ('plain', 'open'),
    'illus.lf.any.rent': ('stone', 'open'),
    'illus.lf.any.repair_house': ('plain', 'shut'),
}
# Right leaf hinges at the right jamb; rot_z = pi lies it in the opening, toward pi/2 swings it in (+y).
RIGHT_LEAF = {'shut': math.pi, 'ajar': math.pi - math.radians(25), 'open': math.pi / 2 + math.radians(15)}


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, rgb):
    # Two tilted slabs of shell (pitched roof over a wall box); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, d / 2 / math.cos(ROOF) + 0.5, 0.18), (cx, y, z + rise / 2), rgb)
        b.rotation_euler[0] = s * ROOF


def _leaf(x, w, h, rot, rgb):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, 0.15, 0.1), rot, 1.0, tag="door_plank")
    L.stretch(d, w / 1.6, w / 1.6, h / 2.8)
    L.recolor(d, rgb)
    return d


def _front(name, cx, style, state, wall):
    """House front at cx facing -y: wall with a doorway, frame, two door leaves, eave and roof."""
    pw = (HW - DOOR_W) / 2
    for s in (-1, 1):
        L.box(name + "_pier", (pw, 0.3, H), (cx + s * (DOOR_W / 2 + pw / 2), 0.15, H / 2), wall)
    L.box(name + "_lintel", (DOOR_W, 0.3, H - DOOR_H), (cx, 0.15, (H + DOOR_H) / 2), wall)
    L.box(name + "_body", (HW, D - 0.3, H), (cx, 0.9 + (D - 0.3) / 2, H / 2), wall)
    # Dark room just inside the doorway (seen when a leaf is open).
    L.box(name + "_inside", (DOOR_W, 0.6, DOOR_H), (cx, 0.6, DOOR_H / 2), DARK)
    L.box(name + "_sill", (DOOR_W + 0.3, 0.5, 0.1), (cx, -0.05, 0.05), STONE)
    if style == 'stone':
        # Shikumen: thick stone frame and a raised stone pediment over the lintel.
        for s in (-1, 1):
            L.box(name + "_jamb", (0.32, 0.45, DOOR_H + 0.3),
                  (cx + s * (DOOR_W / 2 + 0.16), -0.05, (DOOR_H + 0.3) / 2), STONE)
        L.box(name + "_head", (DOOR_W + 0.9, 0.45, 0.35), (cx, -0.05, DOOR_H + 0.3), STONE)
        L.box(name + "_pediment", (DOOR_W + 0.4, 0.3, 0.6), (cx, -0.02, DOOR_H + 0.75), STONE)
    else:
        for s in (-1, 1):
            L.box(name + "_post", (0.14, 0.34, DOOR_H), (cx + s * (DOOR_W / 2 + 0.07), 0.05, DOOR_H / 2),
                  WOOD_DARK)
        L.box(name + "_head", (DOOR_W + 0.3, 0.34, 0.16), (cx, 0.05, DOOR_H + 0.08), WOOD_DARK)
    if style == 'gate':
        # Gate hood: a small tiled roof on a beam over the courtyard gate.
        b = L.box(name + "_hood", (DOOR_W + 1.2, 1.1, 0.14), (cx, -0.4, DOOR_H + 0.75), TILE)
        b.rotation_euler[0] = math.radians(24)
        L.box(name + "_hoodbeam", (DOOR_W + 0.9, 0.25, 0.22), (cx, -0.15, DOOR_H + 0.4), WOOD_DARK)
    elif style == 'plain':
        b = L.box(name + "_pent", (HW + 0.3, 1.0, 0.12), (cx, -0.35, DOOR_H + 0.9), TILE)
        b.rotation_euler[0] = math.radians(20)
    leaf_rgb = WOOD_DARK if style == 'gate' else PLANK
    _leaf(cx - DOOR_W / 2, DOOR_W / 2, DOOR_H, 0.0, leaf_rgb)
    _leaf(cx + DOOR_W / 2, DOOR_W / 2, DOOR_H, RIGHT_LEAF[state], leaf_rgb)
    _roof(name + "_roof", cx, HW, 0.0, D + 0.6, H, TILE)


def _shop(name, cx):
    """The pawnshop front further down the lane: wooden front, three shut plank bays, taller roof."""
    w, h = 6.0, 5.4
    L.box(name + "_body", (w, D, h), (cx, 0.3 + D / 2, h / 2), WOOD)
    for i in range(4):
        L.box(name + "_post", (0.2, 0.3, 3.2), (cx + (i - 1.5) * 1.9, 0.0, 1.6), WOOD_DARK)
    L.box(name + "_beam", (w + 0.4, 0.4, 0.35), (cx, 0.0, 3.3), WOOD_DARK)
    for i in range(3):
        _leaf(cx + (i - 1) * 1.9 - 0.85, 1.7, 3.0, 0.0, PLANK)
    b = L.box(name + "_pent", (w + 0.6, 1.2, 0.14), (cx, -0.45, 3.9), TILE)
    b.rotation_euler[0] = math.radians(20)
    _roof(name + "_roof", cx, w, 0.3, D, h, TILE)


def _lane(variant):
    ground = WET_STONE if variant in WET else STONE
    L.plane("lane", (60, LANE + 0.6), (0, -LANE / 2, 0), (0, 0, 0), ground)
    style, state = HERO[variant]
    for i, cx in enumerate((-12.0, -8.0, -4.0, 0.0, 4.0)):
        wall = PLASTER if i % 2 else PLASTER_OLD
        if cx == 0.0:
            _front("hero", cx, style, state, wall)
        else:
            _front("house", cx, 'plain', 'shut', wall)
    if variant == 'illus.fa.any.neighbor_row':
        _shop("pawnshop", 9.0)
        _front("house", 14.0, 'plain', 'shut', PLASTER)
    else:
        _front("house", 8.0, 'plain', 'shut', PLASTER_OLD)
        _front("house", 12.0, 'plain', 'shut', PLASTER)
    # Opposite row: plain wall massing with roofs, fronts at y=-LANE.
    for i, (x, h) in enumerate(((-11.0, 4.4), (-6.0, 4.8), (-1.0, 4.4), (4.0, 5.0), (9.0, 4.6), (14.0, 4.4))):
        L.box("opp", (5.0, D, h), (x, -LANE - D / 2, h / 2), PLASTER_OLD if i % 2 else PLASTER)
        _roof("opp_roof", x, 5.0, -LANE - D, D, h, TILE)
    if variant in WET:
        # Standing water on the flagstones (ground surface).
        for x, y, sx, sy in ((0.7, -0.9, 1.4, 0.6), (-1.8, -2.2, 1.0, 0.5), (2.4, -2.6, 1.2, 0.5)):
            L.plane("puddle", (sx, sy), (x, y, 0.01), (0, 0, 0), (0.10, 0.12, 0.15))


def _props(variant):
    if variant == 'illus.lf.1938.spring_roof':
        # Wooden basin set under the eave where the roof leaks.
        L.recolor(L.load(L.RESTAURANT, "pot_large.gltf", (1.5, -0.55, 0.0), 0.0, 1.0, tag="wood_basin"),
                  (0.32, 0.18, 0.08))
    elif variant == 'illus.lf.any.funeral':
        # Offering table set out in front of the open door.
        L.recolor(L.load(L.FURNITURE, "table_medium.gltf", (0.0, -0.7, 0.0), 0.0, 0.8, tag="offering_table"),
                  WOOD_DARK)
    elif variant == 'illus.lf.any.repair_house':
        # A broken door board leaning against the wall left of the door; tiles missing on the roof.
        d = L.load(L.RESTAURANT, "door_A.gltf", (-1.85, -0.55, 0.0), 0.0, 1.0, tag="broken_board")
        L.stretch(d, 0.55, 0.55, 0.8)
        L.recolor(d, (0.24, 0.16, 0.10))
        for o in d:
            if o.parent is None:
                o.rotation_euler[0] += math.radians(-12)  # top leans back onto the wall (+y)
        d0 = D + 0.6
        rise = (d0 / 2) * math.tan(ROOF)
        b = L.box("roof_gap", (1.2, 1.0, 0.05),
                  (0.8, d0 / 4 - 0.1 * math.sin(ROOF), H + rise / 2 + 0.1 * math.cos(ROOF)), (0.20, 0.13, 0.07))
        b.rotation_euler[0] = ROOF


# variant: (camera location, look-at point, lens mm). Cameras stand in the lane (y between -LANE and 0).
CAMS = {
    'illus.bf.any.street_bed': ((1.6, -3.2, 1.5), (0.1, 0.0, 1.3), 30),
    'illus.ev.1940.household_count': ((-2.4, -3.3, 1.7), (0.3, 0.0, 1.4), 28),
    'illus.ev.any.alley_row': ((-10.0, -2.0, 1.7), (2.0, -1.0, 1.9), 26),
    'illus.fa.any.neighbor_row': ((-7.0, -2.6, 1.7), (6.0, -0.5, 2.0), 26),
    'illus.st.ask_kin': ((-1.0, -3.3, 1.4), (0.0, 0.0, 1.8), 28),
    'illus.lf.1938.spring_roof': ((2.8, -3.0, 0.9), (0.8, 0.0, 2.6), 26),
    'illus.lf.1939.fuel_stock': ((-3.4, -3.2, 1.6), (-1.6, 0.0, 1.6), 28),
    'illus.lf.any.debt_due': ((2.2, -3.3, 1.2), (0.0, 0.0, 1.5), 30),
    'illus.lf.any.funeral': ((-1.8, -3.3, 1.5), (0.0, 0.0, 1.4), 28),
    'illus.lf.any.rent': ((0.6, -3.3, 1.3), (0.0, 0.0, 1.8), 28),
    'illus.lf.any.repair_house': ((1.4, -3.3, 1.2), (-0.2, 0.0, 3.0), 24),
}


def _lights(variant, toon):
    if variant in NIGHT:
        L.world((0.03, 0.04, 0.10), 0.15 if toon else 0.7)
        L.light('SUN', (0, 0, 10), 0.6, (0.55, 0.65, 1.0), rot=(math.radians(55), 0, math.radians(-30)))
        # Oil lamp held in the open doorway (light only): warm spill out onto the lane.
        L.light('POINT', (0.4, -0.2, 1.4), 70, (1.0, 0.60, 0.26), size=0.12)
    elif variant in DUSK:
        L.world((0.50, 0.32, 0.22), 0.5)
        # Low sun down the lane from the left.
        L.light('SUN', (0, 0, 6), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(70), 0, math.radians(-110)))
        L.light('AREA', (0.0, -3.0, 3.5), 60, (1.0, 0.80, 0.60), rot=(math.radians(30), 0, 0), size=3)
    elif variant in OVERCAST:
        L.world((0.66, 0.70, 0.74) if variant in WET else (0.72, 0.74, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 1.0, (0.88, 0.92, 1.0), rot=(math.radians(30), 0, math.radians(-15)))
        L.light('AREA', (0.0, -3.2, 4.0), 140, (0.92, 0.95, 1.0), rot=(math.radians(40), 0, 0), size=4)
    else:
        L.world((0.80, 0.82, 0.86), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (0.0, -3.2, 4.0), 120, (1.0, 0.97, 0.92), rot=(math.radians(40), 0, 0), size=4)
    if variant == 'illus.lf.any.funeral':
        # Two white paper lanterns by the door (light only, models missing).
        for x in (-1.2, 1.2):
            L.light('POINT', (x, -0.5, 2.3), 25, (1.0, 0.95, 0.88), size=0.15)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _lane(variant)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
