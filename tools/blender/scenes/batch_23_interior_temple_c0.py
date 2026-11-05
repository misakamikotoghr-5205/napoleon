# NOT YET RENDERED: this session was not allowed to write files or run Blender/Python, so framing, light
# and model scales are unchecked (scales come from the glTF bounds). Render every variant before use.
# Register in scenes/__init__.py, or render.py rejects --scene: add batch_23_interior_temple_c0 to the import
# line and the SCENES entry "batch_23_interior_temple_c0": batch_23_interior_temple_c0.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# City-god temple (城隍庙), batch 23: one 320x180 backdrop (bg.temple) and two 64x48 card illustrations.
# A three-bay main hall on a low stone platform: red pillars, a plain beam across them, a black-tile pitched
# roof, a row of lattice door leaves in the middle bay, red plank walls in the side bays. A paved forecourt
# in front, between red, tile-capped courtyard walls. Inside the hall: a dim room with two red pillars
# framing the back wall where the shrine goes.
# bg.temple: temple fair by day, the forecourt seen from its far end. The middle of the frame is kept clear
#   for the game's wheel; the altar tables stand to either side of the steps.
# illus.bf.wheel: close on the incense table in front of the hall, between the red pillars. The wheel goes
#   behind the table and is missing (see below), so the card shows only the table and the hall front.
# illus.ev.any.temple_lot: inside the hall by candlelight, low behind the kneeler's place, looking at the
#   incense table and the back wall.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out. All are already on PROPS_NEEDED.md: incense burner (香炉), paper lanterns (纸灯笼), candles and
# candlesticks (蜡烛与铜烛台), lot tube (签筒和竹签), painted wheel (彩绘轮盘; its sector texture also needs a
# textured model, red line 1 forbids loading other images), shrine with red curtain (神龛), straw cushion
# (蒲团), the kneeling worshipper seen from behind (通用镇民群众), and the temple gate (城隍庙山门).
# The candle flames are only a warm point light where the candlesticks will stand.
# Stand-ins:
# - Restaurant door_A, stretched and recoloured red, for the lattice door leaves (格扇门); PROPS_NEEDED.md
#   lists it as a placeholder for drafts only, to be replaced.
# - Restaurant pillar_A, stretched and recoloured red, for the red pillars (木柱梁架 allows pillar_A/B).
# - Not yet listed on PROPS_NEEDED.md: Furniture table_medium_long, stretched to 2.0 x 0.7 x 0.95 and
#   recoloured red lacquer, for the long altar table (供桌香案). Add it to that row or drop it.
# Architecture (platform, steps, beams, walls, roof, ceiling, paving) is shell built from L.box / L.plane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md sections 1.2 and 1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# No dense meshes (book_set etc.) are loaded, so nothing needs L.noline.
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Only models from registered KayKit packs are loaded and no images, so check_sources() has nothing to reject.
# Orientation: the hall faces -y (the camera side). glTF bounds at scale 1: pillar_A 0.6 x 0.6 x 4.1 (pivot
# at its foot), door_A x 0..1.6 from the hinge, 2.8 high, table_medium_long 3 x 2 x 1 (pivot at the floor).
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.temple', 'illus.bf.wheel', 'illus.ev.any.temple_lot',)
IDS = {'bg.temple': 'bg.temple', 'illus.bf.wheel': 'illus.bf.wheel',
       'illus.ev.any.temple_lot': 'illus.ev.any.temple_lot'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.temple',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

DUSK = ()
NIGHT = ('illus.ev.any.temple_lot',)  # candlelit hall: darkest band pressed down like a night scene

GY = 3.0         # front edge of the platform
PH = 0.5         # platform height
BAY = 3.6        # bay width (three bays)
HALF = 1.5 * BAY
CH = 3.6         # pillar height above the platform
FY = GY + 0.5    # front pillar row
DY = GY + 1.7    # door wall (the porch is between FY and DY)
BY = DY + 6.0    # back wall of the hall
DH = 3.0         # door leaf height
LEAF = 0.85      # door leaf width, four leaves in the middle bay
CW = 9.0         # courtyard walls at x = +-CW
CY0 = GY - 14.0  # far end of the courtyard walls
ROOF = math.radians(28)

PILLAR_RED = (0.40, 0.05, 0.03)
DOOR_RED = (0.30, 0.05, 0.03)
PLANK_RED = (0.26, 0.05, 0.03)
LACQUER = (0.32, 0.05, 0.03)
WALL_RED = (0.42, 0.10, 0.06)
BEAM = (0.20, 0.05, 0.03)
DARK = (0.05, 0.03, 0.025)
INSIDE = (0.12, 0.05, 0.03)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
STONE_DARK = (0.28, 0.27, 0.25)
PAVING = (0.42, 0.40, 0.36)
FLOOR = (0.18, 0.16, 0.14)
CANDLE = (1.0, 0.62, 0.30)


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


def _pillar(x, y):
    p = L.load(L.RESTAURANT, "pillar_A.gltf", (x, y, PH), 0.0, 1.0, tag="pillar")
    L.stretch(p, 0.7, 0.7, CH / 4.1)
    L.recolor(p, PILLAR_RED)
    L.box("pillar_base", (0.55, 0.55, 0.16), (x, y, PH + 0.08), STONE_DARK)


def _table(x, y, z, rot=0.0):
    t = L.load(L.FURNITURE, "table_medium_long.gltf", (x, y, z), rot, 1.0, tag="altar_table")
    L.stretch(t, 2.0 / 3.0, 0.35, 0.95)
    L.recolor(t, LACQUER)


def _hall():
    # Low stone platform, two steps up to it in front of the middle bay.
    L.box("platform", (2 * HALF + 2.0, BY - GY + 0.6, PH), (0, (GY + BY + 0.6) / 2, PH / 2), STONE)
    L.box("platform_edge", (2 * HALF + 2.1, 0.3, 0.1), (0, GY + 0.15, PH - 0.05), STONE_DARK)
    for k in (1, 2):
        d = 0.4 * (3 - k)
        L.box("step", (BAY + 1.0, d, PH / 2 * k), (0, GY - d / 2, PH / 4 * k), STONE)
    # Four red pillars across the front, a plain beam over them.
    for i in range(4):
        _pillar(-HALF + i * BAY, FY)
    L.box("front_beam", (2 * HALF + 0.6, 0.32, 0.45), (0, FY, PH + CH - 0.22), BEAM)
    L.box("front_beam_low", (2 * HALF + 0.2, 0.22, 0.2), (0, FY, PH + CH - 0.75), BEAM)
    L.box("porch_ceiling", (2 * HALF + 0.6, DY - FY + 0.4, 0.15), (0, (FY + DY) / 2, PH + CH + 0.08), BEAM)
    # Door wall: red plank walls in the side bays, four door leaves (closed) in the middle bay.
    side = HALF - BAY / 2
    for s in (-1, 1):
        L.box("front_wall", (side, 0.2, CH), (s * (BAY / 2 + side / 2), DY, PH + CH / 2), PLANK_RED)
    L.box("door_lintel", (BAY, 0.24, CH - DH), (0, DY, PH + (CH + DH) / 2), BEAM)
    L.box("threshold", (BAY, 0.26, 0.16), (0, DY, PH + 0.08), BEAM)
    for i in range(4):
        d = L.load(L.RESTAURANT, "door_A.gltf", (-2 * LEAF + i * LEAF, DY - 0.05, PH), 0.0, 1.0, tag="door_leaf")
        L.stretch(d, LEAF / 1.6, LEAF / 1.6, DH / 2.8)
        L.recolor(d, DOOR_RED)
    # Inside: side and back walls, ceiling, floor, two red pillars framing the shrine's place.
    L.box("hall_floor", (2 * HALF, BY - DY, 0.04), (0, (DY + BY) / 2, PH + 0.02), FLOOR)
    L.box("hall_back", (2 * HALF + 0.4, 0.2, CH + 0.4), (0, BY, PH + CH / 2 + 0.2), INSIDE)
    for s in (-1, 1):
        L.box("hall_side", (0.2, BY - DY + 0.2, CH + 0.4), (s * (HALF + 0.1), (DY + BY) / 2, PH + CH / 2 + 0.2),
              INSIDE)
    L.box("hall_ceiling", (2 * HALF + 0.4, BY - DY + 0.2, 0.15), (0, (DY + BY) / 2, PH + CH + 0.2), DARK)
    L.box("hall_beam", (2 * HALF, 0.3, 0.4), (0, BY - 2.2, PH + CH - 0.1), BEAM)
    for x in (-BAY / 2, BAY / 2):
        _pillar(x, BY - 1.0)
    # Pitched roof over porch and hall, a ridge on top.
    y0, d = GY - 0.4, BY - GY + 1.0
    rise = _roof("hall_roof", 0, 2 * HALF + 1.4, y0, d, PH + CH + 0.3)
    L.box("hall_ridge", (2 * HALF + 1.6, 0.35, 0.35), (0, y0 + d / 2, PH + CH + 0.3 + rise + 0.1), TILE)


def _court():
    L.plane("ground", (60, 50), (0, 0, 0), (0, 0, 0), STONE_DARK)
    L.box("forecourt", (2 * CW, GY - CY0, 0.03), (0, (GY + CY0) / 2, 0.015), PAVING)
    L.box("path", (BAY, GY - CY0, 0.035), (0, (GY + CY0) / 2, 0.0175), STONE)
    # Red courtyard walls along both sides, tile-capped, joined to the hall's ends.
    for s in (-1, 1):
        L.box("court_wall", (0.5, GY - CY0 + 1.5, 3.0), (s * CW, (GY + CY0) / 2 + 0.75, 1.5), WALL_RED)
        L.box("court_skirt", (0.55, GY - CY0 + 1.5, 0.5), (s * CW, (GY + CY0) / 2 + 0.75, 0.25), STONE_DARK)
        L.box("court_cap", (0.9, GY - CY0 + 1.8, 0.22), (s * CW, (GY + CY0) / 2 + 0.75, 3.1), TILE)
        cx = s * (HALF + 1.0 + (CW - HALF - 1.0) / 2)
        L.box("court_corner", (CW - HALF - 1.0, 0.5, 3.0), (cx, GY + 1.2, 1.5), WALL_RED)
        L.box("court_corner_cap", (CW - HALF - 0.8, 0.9, 0.22), (cx, GY + 1.2, 3.1), TILE)


def _props(variant):
    if variant == 'bg.temple':
        # Altar tables to either side of the steps; the middle of the frame stays empty for the wheel.
        for s in (-1, 1):
            _table(s * 3.6, GY - 1.6, 0.0)
    elif variant == 'illus.bf.wheel':
        # Incense table in front of the steps; the wheel (missing) stands behind it.
        _table(0.0, GY - 1.2, 0.0)
    elif variant == 'illus.ev.any.temple_lot':
        # Incense table in front of the shrine's place, between the inner pillars.
        _table(0.0, BY - 1.9, PH)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # From the far end of the forecourt: hall front and the red walls, empty paving in the middle.
    'bg.temple': ((0.0, GY - 16.0, 2.0), (0.0, GY + 1.0, 3.0), 24),
    # Close three-quarter view on the incense table, red pillars and door leaves behind.
    'illus.bf.wheel': ((1.4, GY - 5.2, 1.5), (0.0, GY + 0.6, 1.7), 30),
    # Low, from behind where the worshipper kneels, looking at the table and the back wall.
    'illus.ev.any.temple_lot': ((0.4, BY - 5.0, PH + 1.1), (0.0, BY - 0.5, PH + 1.2), 26),
}


def _lights(variant, toon):
    if variant in NIGHT:
        # Candlelight: almost no ambient light, two warm points where the candlesticks stand on the table,
        # a faint cool spill through the door lattice behind the camera.
        L.world((0.10, 0.08, 0.07), 0.12 if toon else 0.4)
        for x in (-0.6, 0.6):
            L.light('POINT', (x, BY - 1.9, PH + 1.25), 25 if toon else 50, CANDLE, size=0.1)
        L.light('AREA', (0.0, DY + 0.4, PH + 2.6), 60, (0.75, 0.80, 0.95), rot=(math.radians(60), 0, 0), size=3.0)
        return
    # Temple fair by day: warm sun from the front left, broad fill from the forecourt.
    L.world((0.78, 0.80, 0.84), 0.9 if toon else 0.6)
    L.light('SUN', (0, 0, 8), 3.0, (1.0, 0.94, 0.82), rot=(math.radians(42), 0, math.radians(-28)))
    L.light('AREA', (0.0, GY - 7.0, 4.5), 140, (0.98, 0.97, 0.94), rot=(math.radians(40), 0, 0), size=6)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _court()
    _hall()
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
