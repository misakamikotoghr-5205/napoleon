# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# City gate exterior, batch 16: one 320x180 backdrop (bg.stage.1939) and five 64x48 card illustrations at
# the town gate of Qingxi. One grey-brick city wall with crenels runs across the picture, a gate passage
# through it under a stepped head and a timber gate tower on top; white-wall black-tile houses stand outside
# the wall on both sides of the approach road and the town's roofs show over the wall and through the gate.
# The 1939 variants are snow scenes (snow on roofs, wall top and ground); the 1940 ones are bare winter.
# Camera, light, gate-leaf state and a few props change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: every person (guards seen from behind without badges, queueing townsfolk
# carrying New Year goods, refugees in torn padded jackets, children, onlookers, patrolman, Ruhua in a short
# jacket), cloth bundles, wooden barricades / chevaux-de-frise, sentry box, the big notice with a red frame,
# passes and papers, lanterns. Until those are registered, the cards show only their setting and the few
# props below; bg.stage.1939 keeps the queue area in the lower half empty.
# Stand-ins that are what they look like: KayKit door_A leaves (stretched) for the plank gate leaves (as in
# batch_13 / batch_14); table_small and chair_stool_wood for the inspection table and stool, crate /
# crate_lid for goods set down at the table (stand-ins PROPS_NEEDED.md allows).
# Architecture (city wall, crenels, gate passage and its stepped head, gate tower body, posts and roofs,
# houses, snow lying on roofs and wall, road, canal, quay and bridge deck) is shell built from L.box /
# L.plane. A proper city-wall / gate-tower model is on PROPS_NEEDED.md ("城门城墙"); this massing is only
# until it arrives. Modern KayKit city props are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: the wall runs along x, its outer face at y=FACE faces -y (the camera side), the town lies on
# +y. The gate passage is centred on x=0; the forecourt between the outer house rows and the wall runs from
# about y=0.4 to y=FACE. door_A runs from its hinge along +x at rot_z=0 (glTF bounds x 0..1.6, height 2.8);
# crate is about 0.8 high at scale 1.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.stage.1939', 'illus.ev.1939.gate_check', 'illus.ev.1939.refugee_cold', 'illus.ev.1940.gate_tight',
            'illus.ev.1940.wang_regime', 'illus.gl.1939.gate_passed',)
IDS = {'bg.stage.1939': 'bg.stage.1939', 'illus.ev.1939.gate_check': 'illus.ev.1939.gate_check',
       'illus.ev.1939.refugee_cold': 'illus.ev.1939.refugee_cold',
       'illus.ev.1940.gate_tight': 'illus.ev.1940.gate_tight',
       'illus.ev.1940.wang_regime': 'illus.ev.1940.wang_regime',
       'illus.gl.1939.gate_passed': 'illus.gl.1939.gate_passed'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.stage.1939',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

SNOW = ('bg.stage.1939', 'illus.ev.1939.gate_check', 'illus.ev.1939.refugee_cold', 'illus.gl.1939.gate_passed')
DUSK = ('illus.ev.1939.refugee_cold',)
NIGHT = ()

WY = 6.0        # wall centre line
T = 3.0         # wall thickness
WH = 5.0        # wall height
FACE = WY - T / 2   # outer wall face
BACK = WY + T / 2   # inner wall face
GW = 2.8        # gate passage width
GH = 3.0        # passage height up to the stepped head
HEAD = 3        # steps of the head
TW = 9.0        # gate tower width
TD = 2.6        # gate tower depth
TH = 2.4        # gate tower wall height
HW = 4.4        # house front width
HD = 4.0        # house depth
HH = 3.4        # house eaves height
HY = -4.0       # outer house fronts
ROOF = math.radians(28)

BRICK = (0.20, 0.20, 0.21)
BRICK_DARK = (0.12, 0.12, 0.13)
PASSAGE = (0.06, 0.06, 0.07)
TOWER_WOOD = (0.22, 0.07, 0.04)
WOOD_DARK = (0.10, 0.055, 0.03)
PLANK = (0.16, 0.09, 0.045)
CRATE = (0.35, 0.20, 0.09)
CRATE_LID = (0.42, 0.25, 0.11)
PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
TILE = (0.07, 0.07, 0.08)
SNOW_RGB = (0.86, 0.88, 0.92)
GROUND_SNOW = (0.70, 0.72, 0.77)
GROUND_BARE = (0.28, 0.25, 0.21)
ROAD = (0.36, 0.35, 0.34)
STONE = (0.40, 0.38, 0.35)
WATER_RGB = (0.08, 0.11, 0.13)

# Gate leaves stand open against the passage walls, except in 1940 when the right one is half shut.
TIGHT = ('illus.ev.1940.gate_tight',)
RIGHT_LEAF = {'open': math.pi / 2, 'half': math.pi * 0.78}


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.12), (0.08, 0.42), (0.30, 0.72), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, snow):
    # Two tilted slabs of shell (pitched roof, ridge along x); rotation about x lifts the +y side.
    # With snow, a thinner white slab lies on each tile slab.
    rise = (d / 2) * math.tan(ROOF)
    slope = d / 2 / math.cos(ROOF) + 0.5
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, slope, 0.18), (cx, y, z + rise / 2), TILE)
        b.rotation_euler[0] = s * ROOF
        if snow:
            c = L.box(name + "_snow", (w + 0.4, slope - 0.25, 0.1), (cx, y, z + rise / 2 + 0.14), SNOW_RGB)
            c.rotation_euler[0] = s * ROOF


def _house(name, cx, y0, wall, snow, h=HH):
    """House massing facing -y at y0; doors and windows wait for the missing house module."""
    L.box(name + "_body", (HW, HD, h), (cx, y0 + HD / 2, h / 2), wall)
    L.box(name + "_plinth", (HW + 0.05, HD + 0.05, 0.35), (cx, y0 + HD / 2, 0.17), STONE)
    _roof(name + "_roof", cx, HW, y0, HD + 0.6, h, snow)


def _leaf(x, y, w, h, rot):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, y, 0.0), rot, 1.0, tag="gate_leaf")
    L.stretch(d, w / 1.6, w / 1.6, h / 2.8)
    L.recolor(d, PLANK)
    return d


def _wall(variant, snow):
    # Two wall blocks either side of the passage, the stepped head over it, the block above.
    half = 30.0
    seg = half - GW / 2
    for s in (-1, 1):
        L.box("wall", (seg, T, WH), (s * (GW / 2 + seg / 2), WY, WH / 2), BRICK)
        L.box("wall_foot", (seg, T + 0.1, 0.5), (s * (GW / 2 + seg / 2), WY, 0.25), BRICK_DARK)
    step = 0.32
    for i in range(HEAD):
        w = GW - 2 * step * (i + 1)
        for s in (-1, 1):
            L.box("gate_head", ((GW - w) / 2, T, step), (s * (GW + w) / 4, WY, GH + step * (i + 0.5)), BRICK)
    top = GH + step * HEAD
    L.box("gate_lintel", (GW, T, WH - top), (0, WY, (WH + top) / 2), BRICK)
    # Dark brick ring round the passage mouth, set just proud of the face.
    L.box("gate_ring", (GW + 0.5, 0.06, 0.3), (0, FACE - 0.03, top + 0.15), BRICK_DARK)
    for s in (-1, 1):
        L.box("gate_ring", (0.25, 0.06, top), (s * (GW / 2 + 0.12), FACE - 0.03, top / 2), BRICK_DARK)
    L.box("passage_floor", (GW, T, 0.04), (0, WY, 0.02), ROAD)
    # Gate leaves inside the passage near the town side.
    lw = GW / 2
    _leaf(-GW / 2, BACK - 0.3 - lw, lw, GH, math.pi / 2)
    if variant in TIGHT:
        _leaf(GW / 2, BACK - 0.3, lw, GH, RIGHT_LEAF['half'])
    else:
        _leaf(GW / 2, BACK - 0.3 - lw, lw, GH, RIGHT_LEAF['open'])
    # Crenels along the outer edge, parapet along the inner edge, snow on the wall walk.
    x = -half + 0.5
    while x < half:
        L.box("crenel", (0.55, 0.45, 0.6), (x, FACE + 0.22, WH + 0.3), BRICK)
        if snow:
            L.box("crenel_snow", (0.6, 0.5, 0.08), (x, FACE + 0.22, WH + 0.64), SNOW_RGB)
        x += 1.1
    L.box("parapet", (2 * half, 0.4, 0.5), (0, BACK - 0.2, WH + 0.25), BRICK)
    if snow:
        L.box("wall_snow", (2 * half, T - 0.6, 0.08), (0, WY, WH + 0.04), SNOW_RGB)
    # Gate tower: dark timber body with posts on the wall walk, pitched roof.
    ty = WY - TD / 2
    L.box("tower_body", (TW, TD, TH), (0, WY, WH + TH / 2), TOWER_WOOD)
    L.box("tower_sill", (TW + 0.4, TD + 0.4, 0.25), (0, WY, WH + 0.12), BRICK_DARK)
    for i in range(6):
        L.box("tower_post", (0.22, 0.22, TH), (-TW / 2 + i * TW / 5, ty - 0.12, WH + TH / 2), WOOD_DARK)
    L.box("tower_beam", (TW + 0.2, 0.26, 0.25), (0, ty - 0.12, WH + TH - 0.12), WOOD_DARK)
    L.box("tower_window", (TW - 1.2, 0.05, 0.7), (0, ty - 0.03, WH + TH * 0.6), PASSAGE)
    _roof("tower_roof", 0, TW + 0.6, WY - TD / 2 - 0.6, TD + 1.2, WH + TH, snow)


def _ground(variant, snow):
    L.plane("ground", (80, 60), (0, 0, 0), (0, 0, 0), GROUND_SNOW if snow else GROUND_BARE)
    # Trodden road through the gate and on into the town.
    L.box("road", (GW + 0.6, 40, 0.03), (0, 2.0, 0.015), ROAD)
    if variant in BACKDROPS:
        # Canal across the foreground with stone quay edges and a flat stone bridge deck (water town).
        L.plane("canal", (80, 3.0), (0, -10.5, -0.6), (0, 0, 0), WATER_RGB)
        for y in (-9.0, -12.0):
            L.box("quay", (80, 0.3, 0.8), (0, y, -0.4), STONE)
        L.box("bridge_deck", (GW + 0.6, 3.6, 0.25), (0, -10.5, 0.0), STONE)


def _houses(snow):
    # Outside the wall: rows either side of the approach road, fronts facing -y, a forecourt before the gate.
    for i, cx in enumerate((-7.0, -11.6, -16.2, -20.8, 7.0, 11.6, 16.2, 20.8)):
        _house("house", cx, HY + 0.4 * (i % 2), PLASTER if i % 2 else PLASTER_OLD, snow)
    # Inside the wall: the town's roofs over the wall and down the street seen through the gate.
    for i, cx in enumerate((-12.0, -7.0, -2.6, 2.6, 7.0, 12.0)):
        _house("town", cx, BACK + 2.5, PLASTER_OLD if i % 2 else PLASTER, snow)
    for i, cx in enumerate((-9.0, -4.0, 4.0, 9.0)):
        _house("town_far", cx, BACK + 9.0, PLASTER if i % 2 else PLASTER_OLD, snow, HH + 1.6)


def _crate(loc, rot, scale, lid=True):
    L.recolor(L.load(L.RESTAURANT, "crate.gltf", loc, rot, scale, tag="goods_crate"), CRATE)
    if lid:
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (loc[0], loc[1], loc[2] + 0.8 * scale), rot, scale,
                         tag="goods_crate"), CRATE_LID)


def _check_post(side):
    # Inspection table and stool beside the passage mouth; side -1 = left of the gate, 1 = right.
    L.recolor(L.load(L.FURNITURE, "table_small.gltf", (side * 2.4, FACE - 1.0, 0), 0.0, 1.0, tag="check_table"),
              WOOD_DARK)
    L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (side * 3.1, FACE - 0.4, 0), side * 0.3, 1.0,
                     tag="stool"), PLANK)


def _props(variant):
    if variant == 'illus.ev.1939.gate_check':
        _check_post(1)
        _crate((1.5, FACE - 1.6, 0), 0.2, 0.45, lid=False)
    elif variant == 'illus.ev.1940.gate_tight':
        _check_post(-1)
        for loc, rot in (((-1.6, FACE - 2.0, 0), 0.1), ((-1.9, FACE - 2.6, 0), -0.2)):
            _crate(loc, rot, 0.45)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Gate and tower in the upper 55%; canal, bridge and the queue space below.
    'bg.stage.1939': ((0.0, -17.0, 2.4), (0.0, FACE, 4.6), 26),
    'illus.ev.1939.gate_check': ((3.2, 0.6, 1.6), (0.6, FACE, 2.0), 28),
    # Along the wall foot left of the gate, the passage at the right edge.
    'illus.ev.1939.refugee_cold': ((1.5, 2.6, 1.3), (-3.5, FACE, 1.0), 24),
    'illus.ev.1940.gate_tight': ((5.5, -7.5, 2.6), (-0.5, FACE, 3.4), 26),
    # The stretch of wall right of the gate where the notice goes.
    'illus.ev.1940.wang_regime': ((4.8, 0.8, 1.5), (4.0, FACE, 2.2), 28),
    # Low in front of the passage, looking through it into the snowy town.
    'illus.gl.1939.gate_passed': ((0.3, 0.5, 1.2), (0.0, BACK + 6.0, 1.8), 28),
}


def _lights(variant, toon):
    if variant in DUSK:
        L.world((0.30, 0.36, 0.48), 0.45 if toon else 0.9)
        # Low cold light at the end of the day, grazing the wall face.
        L.light('SUN', (0, 0, 8), 1.2, (0.70, 0.78, 1.0), rot=(math.radians(68), 0, math.radians(-60)))
        L.light('AREA', (-3.0, FACE - 4.0, 3.5), 60, (0.75, 0.82, 1.0), rot=(math.radians(50), 0, 0), size=5)
    elif variant in SNOW:
        L.world((0.72, 0.76, 0.84), 0.9)
        # Overcast snow day: soft cool sun from the camera side, broad fill off the snow.
        L.light('SUN', (0, 0, 8), 2.0, (0.92, 0.95, 1.0), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (0.0, FACE - 5.0, 4.5), 160, (0.92, 0.95, 1.0), rot=(math.radians(40), 0, 0), size=6)
    else:
        L.world((0.70, 0.70, 0.72), 0.85)
        # Grey winter day, 1940.
        L.light('SUN', (0, 0, 8), 2.6, (1.0, 0.95, 0.86), rot=(math.radians(45), 0, math.radians(-30)))
        L.light('AREA', (0.0, FACE - 5.0, 4.5), 120, (0.95, 0.95, 0.95), rot=(math.radians(40), 0, 0), size=6)
    if variant == 'illus.gl.1939.gate_passed':
        # Light falling into the passage from the town side.
        L.light('AREA', (0.0, BACK + 1.5, 2.5), 80, (0.92, 0.95, 1.0), rot=(math.radians(-60), 0, 0), size=2.5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    snow = variant in SNOW
    _ground(variant, snow)
    _wall(variant, snow)
    _houses(snow)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
