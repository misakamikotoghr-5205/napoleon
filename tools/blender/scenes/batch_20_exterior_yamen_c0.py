# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Yamen exterior, batch 20: one 320x180 backdrop (bg.stage.1940) and three 64x48 card illustrations at the
# county yamen gate of Qingxi, spring 1940. A three-bay gate hall on a raised stone platform: red pillars,
# a plain beam across them, black-tile pitched roof, plaster back wall with the double gate in the middle
# bay, splayed plaster screen walls either side, white-wall black-tile houses beyond. A paved forecourt
# runs down to the street. Camera, light, gate-leaf state and a few props change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: the blank plaque (空白匾额, old and new), the big notice
# (告示和贴墙单据), bundled old papers (散页文书), willow in bud (柳树), sedan chair (轿子), gift boxes
# (木匣), wooden ladder (木梯), and every person (townsfolk crowd seen from behind, the new official and his
# attendants, bearers, workmen). Until those are registered, the cards show only their setting and the few
# props below; the beam over the gate is left bare where the plaque goes, and the left screen wall is left
# bare where the notice goes.
# Stand-ins that are what they look like: KayKit door_A leaves (stretched, recoloured) for the plank gate
# leaves (as in batch_13 / batch_14 / batch_16); restaurant crate / crate_lid for the wooden crate
# (stand-in PROPS_NEEDED.md allows); KayKit city bush as spring greenery at the forecourt edge.
# Architecture (platform, steps, pillars, beams, walls, roofs, houses, paving, street) is shell built from
# L.box / L.plane. A proper yamen gate-hall model is on PROPS_NEEDED.md ("衙门门楼"); this massing is only
# until it arrives. Modern KayKit city props (cars, street lights, hydrants) are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: the gate hall faces -y (the camera side); the platform's front edge is at y=GY, the town
# street runs along x in front of the forecourt. door_A runs from its hinge along +x at rot_z=0 (glTF bounds
# x 0..1.6, height 2.8); crate is about 0.8 high at scale 1.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.stage.1940', 'illus.bf.1940.yamen_crate', 'illus.ev.1940.new_official', 'illus.ev.1940.signboard',)
IDS = {'bg.stage.1940': 'bg.stage.1940', 'illus.bf.1940.yamen_crate': 'illus.bf.1940.yamen_crate',
       'illus.ev.1940.new_official': 'illus.ev.1940.new_official',
       'illus.ev.1940.signboard': 'illus.ev.1940.signboard'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.stage.1940',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

DUSK = ()
NIGHT = ()
# Gate leaves stand open into the hall, except while the plaque is being changed.
OPEN = ('bg.stage.1940', 'illus.bf.1940.yamen_crate', 'illus.ev.1940.new_official')

GY = 4.0        # front edge of the platform
PH = 0.6        # platform height
PW = 13.0       # platform width
PD = 5.0        # platform depth
BAY = 3.4       # bay width (three bays)
CH = 3.8        # pillar height above the platform
FY = GY + 0.5   # front pillar row
BY = GY + 2.6   # back wall (gate wall)
DW = 3.0        # gate opening width
DH = 3.0        # gate opening height
HW = 4.4        # house front width
HD = 4.0        # house depth
HH = 3.4        # house eaves height
ROOF = math.radians(28)

PILLAR_RED = (0.40, 0.05, 0.03)
GATE_RED = (0.25, 0.04, 0.025)
BEAM = (0.20, 0.05, 0.03)
DARK = (0.04, 0.03, 0.025)
PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
STONE_DARK = (0.28, 0.27, 0.25)
PAVING = (0.42, 0.40, 0.36)
ROAD = (0.34, 0.32, 0.29)
GROUND = (0.26, 0.27, 0.19)    # damp spring earth with new grass
CRATE = (0.35, 0.20, 0.09)
CRATE_LID = (0.42, 0.25, 0.11)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.12), (0.08, 0.42), (0.30, 0.72), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z):
    # Two tilted slabs of shell (pitched roof, ridge along x); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    slope = d / 2 / math.cos(ROOF) + 0.5
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, slope, 0.18), (cx, y, z + rise / 2), TILE)
        b.rotation_euler[0] = s * ROOF
    return rise


def _house(name, cx, y0, wall, h=HH):
    """House massing facing -y at y0; doors and windows wait for the missing house module."""
    L.box(name + "_body", (HW, HD, h), (cx, y0 + HD / 2, h / 2), wall)
    L.box(name + "_plinth", (HW + 0.05, HD + 0.05, 0.35), (cx, y0 + HD / 2, 0.17), STONE)
    _roof(name + "_roof", cx, HW, y0, HD + 0.6, h)


def _leaf(x, y, w, h, rot):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, y, PH), rot, 1.0, tag="gate_leaf")
    L.stretch(d, w / 1.6, w / 1.6, h / 2.8)
    L.recolor(d, GATE_RED)
    return d


def _gate(variant):
    # Raised stone platform with three steps up to it in front of the middle bay.
    L.box("platform", (PW, PD, PH), (0, GY + PD / 2, PH / 2), STONE)
    L.box("platform_edge", (PW + 0.1, 0.3, 0.12), (0, GY + 0.15, PH - 0.06), STONE_DARK)
    for k in (1, 2, 3):
        d = 0.4 * (4 - k)
        L.box("step", (BAY + 1.4, d, 0.2 * k), (0, GY - d / 2, 0.1 * k), STONE)
    # Four red pillars across the front, a plain beam over them (the plaque's place, left bare).
    half = 1.5 * BAY
    for i in range(4):
        x = -half + i * BAY
        L.box("pillar", (0.36, 0.36, CH), (x, FY, PH + CH / 2), PILLAR_RED)
        L.box("pillar_base", (0.55, 0.55, 0.18), (x, FY, PH + 0.09), STONE_DARK)
    L.box("front_beam", (2 * half + 0.6, 0.32, 0.45), (0, FY, PH + CH - 0.22), BEAM)
    L.box("front_beam_low", (2 * half + 0.2, 0.22, 0.2), (0, FY, PH + CH - 0.75), BEAM)
    # Back wall with the gate opening in the middle bay; hall side walls.
    side = half - DW / 2
    for s in (-1, 1):
        L.box("gate_wall", (side, 0.3, CH), (s * (DW / 2 + side / 2), BY, PH + CH / 2), PLASTER)
        L.box("gate_wall_skirt", (side, 0.32, 0.6), (s * (DW / 2 + side / 2), BY, PH + 0.3), STONE_DARK)
        L.box("hall_side", (0.3, BY - FY, CH), (s * (half + 0.2), (FY + BY) / 2, PH + CH / 2), PLASTER)
    L.box("gate_lintel", (DW, 0.3, CH - DH), (0, BY, PH + (CH + DH) / 2), BEAM)
    for s in (-1, 1):
        L.box("gate_post", (0.22, 0.34, DH), (s * (DW / 2 + 0.11), BY, PH + DH / 2), BEAM)
    L.box("threshold", (DW, 0.34, 0.22), (0, BY, PH + 0.11), BEAM)
    # Dim hall behind the gate.
    L.box("hall_floor", (DW + 1.0, 4.0, 0.04), (0, BY + 2.1, PH + 0.02), STONE_DARK)
    L.box("hall_back", (DW + 2.0, 0.2, CH), (0, BY + 4.2, PH + CH / 2), DARK)
    for s in (-1, 1):
        L.box("hall_wall", (0.2, 4.0, CH), (s * (DW / 2 + 0.6), BY + 2.1, PH + CH / 2), DARK)
    L.box("hall_ceiling", (DW + 2.0, 4.4, 0.2), (0, BY + 2.1, PH + CH + 0.1), DARK)
    # Gate leaves: open into the hall, or shut flush in the opening.
    lw = DW / 2
    if variant in OPEN:
        _leaf(-lw, BY + 0.15, lw, DH, math.pi / 2)
        _leaf(lw, BY + 0.15, lw, DH, math.pi / 2)
    else:
        _leaf(-lw, BY - 0.05, lw, DH, 0.0)
        _leaf(0.0, BY - 0.05, lw, DH, 0.0)
    # Pitched roof over the hall, a ridge on top.
    y0, d = GY - 0.4, BY - GY + 1.2
    rise = _roof("gate_roof", 0, 2 * half + 1.0, y0, d, PH + CH)
    L.box("gate_ridge", (2 * half + 1.2, 0.35, 0.35), (0, y0 + d / 2, PH + CH + rise + 0.1), TILE)
    # Splayed screen walls (八字墙) running forward from the platform ends, tile-capped.
    for s in (-1, 1):
        ax, ay = s * (PW / 2 - 0.2), GY + 0.8
        bx, by = s * (PW / 2 + 3.2), GY - 1.2
        length = math.hypot(bx - ax, by - ay)
        ang = math.atan2(by - ay, bx - ax)
        cx, cy = (ax + bx) / 2, (ay + by) / 2
        L.box("screen_wall", (length, 0.5, 3.0), (cx, cy, 1.5), PLASTER, rot_z=ang)
        L.box("screen_skirt", (length + 0.05, 0.55, 0.5), (cx, cy, 0.25), STONE_DARK, rot_z=ang)
        L.box("screen_cap", (length + 0.3, 0.9, 0.22), (cx, cy, 3.1), TILE, rot_z=ang)


def _ground():
    L.plane("ground", (80, 60), (0, 0, 0), (0, 0, 0), GROUND)
    # Paved forecourt from the steps down to the street; the street runs along x.
    L.box("forecourt", (PW + 4.0, 7.0, 0.03), (0, GY - 3.5, 0.015), PAVING)
    L.box("street", (80, 4.0, 0.025), (0, GY - 9.0, 0.0125), ROAD)


def _houses():
    # Beyond the screen walls: house rows fronting the street line, and town roofs behind the hall.
    for i, cx in enumerate((-12.6, -17.2, -21.8, 12.6, 17.2, 21.8)):
        _house("house", cx, GY + 0.6 * (i % 2), PLASTER if i % 2 else PLASTER_OLD)
    for i, cx in enumerate((-9.0, -4.4, 0.0, 4.4, 9.0)):
        _house("town_far", cx, BY + 6.0, PLASTER_OLD if i % 2 else PLASTER, HH + 1.6)


def _bushes():
    # New spring green at the forecourt corners.
    for x in (-8.6, 8.6):
        L.tone(L.load(L.CITY, "bush.gltf", (x, GY - 2.4, 0), 0.4 * x, 1.1, tag="bush"), sat=0.8, val=0.9)


def _props(variant):
    if variant == 'illus.bf.1940.yamen_crate':
        # Crate set down on the platform by the right pillar, lid off beside it (the papers are missing).
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (2.6, GY + 1.3, PH), 0.2, 0.55, tag="crate"), CRATE)
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (3.5, GY + 1.0, PH), 0.9, 0.55, tag="crate"), CRATE_LID)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Gate hall and screen walls in the upper 55%; the forecourt below left clear for the crowd.
    'bg.stage.1940': ((0.0, GY - 17.0, 2.2), (0.0, GY + 1.0, 3.2), 24),
    # Close on the crate by the right red pillar, the open gate behind.
    'illus.bf.1940.yamen_crate': ((4.6, GY - 2.6, 1.6), (2.0, GY + 1.6, 1.8), 30),
    # Low three-quarter view from the street, the empty forecourt where the sedan chair stops.
    'illus.ev.1940.new_official': ((-7.0, GY - 9.0, 1.6), (0.5, GY + 1.0, 2.6), 26),
    # Head-on, looking up at the bare beam where the plaque is swapped, the gate shut.
    'illus.ev.1940.signboard': ((0.8, GY - 5.5, 1.6), (0.0, GY + 1.5, 3.8), 30),
}


def _lights(variant, toon):
    L.world((0.78, 0.82, 0.86), 0.9)
    # Mild spring day: warm sun from the front left, broad fill from the forecourt.
    L.light('SUN', (0, 0, 8), 3.0, (1.0, 0.96, 0.86), rot=(math.radians(42), 0, math.radians(-28)))
    L.light('AREA', (0.0, GY - 6.0, 4.5), 140, (0.98, 0.98, 0.95), rot=(math.radians(40), 0, 0), size=6)
    if variant in OPEN:
        # A little light inside the hall so the open gate is not a black hole.
        L.light('POINT', (0.0, BY + 1.5, PH + 2.6), 40, (1.0, 0.92, 0.80), size=0.5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _ground()
    _gate(variant)
    _houses()
    _bushes()
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
