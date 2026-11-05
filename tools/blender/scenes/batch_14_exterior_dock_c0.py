# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Dock exterior, batch 14: one 320x180 backdrop (bg.dock) and seven 64x48 card illustrations at the canal
# landing of Qingxi town. One stone quay along the canal with a flight of stone steps down to the water, a
# row of white-wall black-tile houses behind it (one with a back door) and a far bank across the water;
# camera, light, back-door state and a few props change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: wupeng boat / cargo boat / wooden sailing junk, small steam launch,
# stone mooring bollard, hemp rice sacks, tarpaulin over the crates, paper lanterns, ship ticket, account
# book, copper coins, bamboo pole, straw hats, and every person (porters in short jackets, boatmen, river
# traders, toll collector in a long gown, clerk counting sacks, onlooking townsfolk, hand holding the
# ticket). Lanterns are light only. Until those are registered, the cards show only their setting and the
# few props below.
# Stand-ins that are what they look like: KayKit crate / crate_lid for the wooden cargo crates, door_A
# leaves (stretched) for the plank back door (as in batch_13), table_small and chair_stool_wood for the toll
# table and stool (stand-ins PROPS_NEEDED.md allows).
# Architecture (quay wall, stone steps, coping, far bank, house walls, door frames, eaves, roofs) and the
# water surface are shell built from L.box / L.plane. Modern KayKit city props are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: the quay edge runs along x at y=0, land (quay top z=0) on +y, water on -y at z=WATER.
# House fronts face -y at y=HY. door_A runs from its hinge along +x at rot_z=0 (glTF bounds x 0..1.6,
# height 2.8). crate is about 0.8 high at scale 1.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.dock', 'illus.bf.1938.night_cargo', 'illus.bf.any.ship_ticket', 'illus.ky.dockhands',
            'illus.ev.1938.dock_night', 'illus.ev.1938.wharf_due', 'illus.fa.1938.requisition', 'illus.st.carry',)
IDS = {'bg.dock': 'bg.dock', 'illus.bf.1938.night_cargo': 'illus.bf.1938.night_cargo',
       'illus.bf.any.ship_ticket': 'illus.bf.any.ship_ticket', 'illus.ky.dockhands': 'illus.ky.dockhands',
       'illus.ev.1938.dock_night': 'illus.ev.1938.dock_night', 'illus.ev.1938.wharf_due': 'illus.ev.1938.wharf_due',
       'illus.fa.1938.requisition': 'illus.fa.1938.requisition', 'illus.st.carry': 'illus.st.carry'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.dock',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

NIGHT = ('illus.bf.1938.night_cargo', 'illus.ev.1938.dock_night')
MORNING = ('illus.bf.any.ship_ticket',)
OVERCAST = ('illus.fa.1938.requisition',)

WATER = -1.05   # water surface
QH = 1.7        # quay wall height below the quay top (z=0)
HY = 4.5        # house fronts
D = 5.0         # house depth
HW = 4.4        # house front width
H = 4.4         # eaves height
DOOR_W = 1.4
DOOR_H = 2.3
ROOF = math.radians(28)
STEP_X = 0.0    # centre of the stone steps
STEP_W = 2.4
STEPS = 4
RISE = 0.275
TREAD = 0.4
FAR = -13.0     # far bank quay edge

WOOD_DARK = (0.10, 0.055, 0.03)
PLANK = (0.16, 0.09, 0.045)
CRATE = (0.35, 0.20, 0.09)
CRATE_LID = (0.42, 0.25, 0.11)
PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
STONE_LIGHT = (0.50, 0.48, 0.44)
STONE_WET = (0.22, 0.22, 0.21)
WATER_RGB = (0.08, 0.12, 0.13)
DARK = (0.02, 0.015, 0.01)

# The back door of the house at x=0 stands open only while the crates go in.
OPEN = ('illus.bf.1938.night_cargo',)
# Right leaf hinges at the right jamb; rot_z = pi lies it in the opening, toward pi/2 swings it in (+y).
RIGHT_LEAF = {'shut': math.pi, 'open': math.pi / 2 + math.radians(15)}


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in MORNING:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, rgb):
    # Two tilted slabs of shell (pitched roof over a wall box); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, d / 2 / math.cos(ROOF) + 0.5, 0.18), (cx, y, z + rise / 2), rgb)
        b.rotation_euler[0] = s * ROOF


def _leaf(x, w, h, rot, rgb):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, HY + 0.15, 0.1), rot, 1.0, tag="door_plank")
    L.stretch(d, w / 1.6, w / 1.6, h / 2.8)
    L.recolor(d, rgb)
    return d


def _house(name, cx, wall, door=None):
    """House on the quay at cx facing the water (-y); with `door` ('shut' / 'open') it has a back door."""
    if door is None:
        L.box(name + "_body", (HW, D, H), (cx, HY + D / 2, H / 2), wall)
    else:
        pw = (HW - DOOR_W) / 2
        for s in (-1, 1):
            L.box(name + "_pier", (pw, 0.3, H), (cx + s * (DOOR_W / 2 + pw / 2), HY + 0.15, H / 2), wall)
        L.box(name + "_lintel", (DOOR_W, 0.3, H - DOOR_H), (cx, HY + 0.15, (H + DOOR_H) / 2), wall)
        L.box(name + "_body", (HW, D - 0.9, H), (cx, HY + 0.9 + (D - 0.9) / 2, H / 2), wall)
        # Dark room just inside the doorway (seen when a leaf is open).
        L.box(name + "_inside", (DOOR_W, 0.6, DOOR_H), (cx, HY + 0.6, DOOR_H / 2), DARK)
        L.box(name + "_sill", (DOOR_W + 0.3, 0.5, 0.1), (cx, HY - 0.05, 0.05), STONE)
        for s in (-1, 1):
            L.box(name + "_post", (0.12, 0.34, DOOR_H), (cx + s * (DOOR_W / 2 + 0.06), HY + 0.05, DOOR_H / 2),
                  WOOD_DARK)
        L.box(name + "_head", (DOOR_W + 0.3, 0.34, 0.14), (cx, HY + 0.05, DOOR_H + 0.07), WOOD_DARK)
        _leaf(cx - DOOR_W / 2, DOOR_W / 2, DOOR_H, 0.0, PLANK)
        _leaf(cx + DOOR_W / 2, DOOR_W / 2, DOOR_H, RIGHT_LEAF[door], PLANK)
    b = L.box(name + "_pent", (HW + 0.3, 0.9, 0.12), (cx, HY - 0.3, DOOR_H + 0.85), TILE)
    b.rotation_euler[0] = math.radians(20)
    _roof(name + "_roof", cx, HW, HY, D + 0.6, H, TILE)


def _quay(variant):
    # Quay top and wall, water, stone steps down to the water, coping along the edge.
    L.box("quay", (60, 14, QH), (0, 7.0, -QH / 2), STONE)
    L.plane("water", (80, 30), (0, -15.0, WATER), (0, 0, 0), WATER_RGB)
    L.box("quay_wet", (60, 0.04, 0.25), (0, -0.02, WATER + 0.12), STONE_WET)
    for i in range(STEPS):
        top = -RISE * (i + 1)
        depth = TREAD * (i + 1)
        L.box("step", (STEP_W, depth, top + QH), (STEP_X, -depth / 2, (top - QH) / 2),
              STONE_WET if i == STEPS - 1 else STONE_LIGHT)
    for x0, x1 in ((-30.0, STEP_X - STEP_W / 2), (STEP_X + STEP_W / 2, 30.0)):
        L.box("coping", (x1 - x0, 0.35, 0.12), ((x0 + x1) / 2, 0.17, 0.06), STONE_LIGHT)
    # Far bank: quay wall and a row of house massing facing the water (+y).
    L.box("far_quay", (60, 6, QH), (0, FAR - 3.0, -QH / 2), STONE)
    for i, (x, h) in enumerate(((-14.0, 4.2), (-9.0, 4.8), (-4.0, 4.4), (1.0, 5.0), (6.0, 4.4), (11.0, 4.6),
                                (16.0, 4.2))):
        y0 = FAR - 1.5 - D
        L.box("far_house", (4.6, D, h), (x, y0 + D / 2, h / 2), PLASTER_OLD if i % 2 else PLASTER)
        _roof("far_roof", x, 4.6, y0, D, h, TILE)
    # Near row on the quay; the house at x=0 has the back door.
    for i, cx in enumerate((-13.5, -9.0, -4.5, 0.0, 4.5, 9.0, 13.5)):
        wall = PLASTER if i % 2 else PLASTER_OLD
        if cx == 0.0:
            _house("backdoor", cx, wall, 'open' if variant in OPEN else 'shut')
        else:
            _house("house", cx, wall)


def _crate(loc, rot, scale, lid=True):
    L.recolor(L.load(L.RESTAURANT, "crate.gltf", loc, rot, scale, tag="cargo_crate"), CRATE)
    if lid:
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (loc[0], loc[1], loc[2] + 0.8 * scale), rot, scale,
                         tag="cargo_crate"), CRATE_LID)


def _props(variant):
    if variant == 'bg.dock':
        # Cargo waiting on the quay either side of the steps.
        for loc, rot in (((-2.6, 1.0, 0), 0.1), ((-3.4, 1.3, 0), -0.15), ((-2.9, 1.2, 0.4), 0.3),
                         ((2.8, 1.4, 0), -0.1)):
            _crate(loc, rot, 0.5)
    elif variant == 'illus.bf.1938.night_cargo':
        # Lidded crates carried up from the steps toward the open back door.
        for loc, rot in (((0.5, 1.4, 0), 0.2), ((-0.5, 2.6, 0), -0.1), ((-0.4, 2.6, 0.4), 0.15)):
            _crate(loc, rot, 0.5)
    elif variant == 'illus.ky.dockhands':
        for loc, rot in (((-3.0, 0.9, 0), 0.0), ((-3.5, 1.4, 0), 0.25), ((-3.2, 1.1, 0.4), -0.1),
                         ((1.9, 0.9, 0), 0.1), ((2.4, 1.2, 0), -0.2)):
            _crate(loc, rot, 0.5)
    elif variant == 'illus.ev.1938.dock_night':
        for loc, rot in (((1.8, 0.9, 0), 0.1), ((2.3, 1.3, 0), -0.2), ((2.0, 1.1, 0.4), 0.2)):
            _crate(loc, rot, 0.5, lid=False)
    elif variant == 'illus.ev.1938.wharf_due':
        # Toll table and stool on the quay beside the steps.
        L.recolor(L.load(L.FURNITURE, "table_small.gltf", (2.4, 1.2, 0), 0.0, 1.0, tag="toll_table"), WOOD_DARK)
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (2.4, 2.1, 0), 0.2, 1.0, tag="stool"), PLANK)
    elif variant == 'illus.fa.1938.requisition':
        # Rows of goods set out on the quay to be counted.
        for i in range(3):
            for j in range(2):
                _crate((-3.4 + i * 0.75, 0.9 + j * 0.75, 0), 0.05 * (i - j), 0.5, lid=False)
        _crate((-2.65, 1.3, 0.4), 0.1, 0.5)
    elif variant == 'illus.st.carry':
        _crate((1.6, 1.0, 0), 0.15, 0.5)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    'bg.dock': ((-1.5, -9.5, 2.2), (0.5, 3.0, 1.2), 26),
    'illus.bf.1938.night_cargo': ((3.0, -3.6, 1.2), (0.0, 2.5, 0.9), 28),
    'illus.bf.any.ship_ticket': ((1.2, 3.2, 1.6), (-1.5, FAR, 0.4), 32),
    'illus.ky.dockhands': ((-7.0, -3.4, 1.6), (0.5, 1.5, 0.2), 26),
    'illus.ev.1938.dock_night': ((2.4, -3.8, 0.3), (0.0, 0.8, -0.2), 28),
    'illus.ev.1938.wharf_due': ((5.0, -2.4, 1.3), (1.8, 1.4, 0.5), 30),
    'illus.fa.1938.requisition': ((-5.6, -2.8, 1.6), (-2.0, 1.4, 0.4), 30),
    'illus.st.carry': ((-1.8, -3.4, -0.5), (0.0, 0.8, 0.0), 28),
}


def _lights(variant, toon):
    if variant in NIGHT:
        L.world((0.03, 0.04, 0.10), 0.15 if toon else 0.7)
        # Moonlight from across the canal.
        L.light('SUN', (0, 0, 10), 0.6, (0.55, 0.65, 1.0), rot=(math.radians(55), 0, math.radians(20)))
        if variant == 'illus.bf.1938.night_cargo':
            # Lantern hung at the back door (light only).
            L.light('POINT', (0.0, HY - 0.5, 2.1), 70, (1.0, 0.60, 0.26), size=0.12)
        else:
            # Lantern on the moored boat at the foot of the steps (light only, boat missing), and one on the quay.
            L.light('POINT', (0.4, -1.8, WATER + 0.9), 60, (1.0, 0.60, 0.26), size=0.12)
            L.light('POINT', (0.0, 1.2, 1.8), 25, (1.0, 0.62, 0.30), size=0.12)
    elif variant in MORNING:
        L.world((0.70, 0.66, 0.62), 0.8)
        # Low early sun along the canal, haze off the water.
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.78, 0.55), rot=(math.radians(72), 0, math.radians(-100)))
        L.light('AREA', (0.0, -3.5, 4.0), 80, (0.95, 0.92, 0.88), rot=(math.radians(40), 0, 0), size=4)
    elif variant in OVERCAST:
        L.world((0.72, 0.74, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 1.0, (0.88, 0.92, 1.0), rot=(math.radians(30), 0, math.radians(-15)))
        L.light('AREA', (0.0, -3.5, 4.0), 140, (0.92, 0.95, 1.0), rot=(math.radians(40), 0, 0), size=4)
    else:
        L.world((0.80, 0.82, 0.86), 0.9)
        # Sun from the water side, so the house fronts and step faces are lit.
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (0.0, -3.5, 4.0), 120, (1.0, 0.97, 0.92), rot=(math.radians(40), 0, 0), size=4)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _quay(variant)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
