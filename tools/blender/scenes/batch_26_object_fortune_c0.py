# Fortune-stall props, batch 26 (object:fortune): three small sprites for the fortune-teller stall UI.
# prop.fortune.char (24x24): the 测字 button icon, a sheet of red paper with one ink character and a writing
#   brush beside it on the stall table, seen from high above.
# prop.fortune.slip (24x32): one red-tipped bamboo lot slip drawn from the tube, standing slightly tilted,
#   straight-on at its own height, ink dots for the lot text.
# prop.fortune.tube (16x32): the bamboo lot tube with a red cloth band, full of slips, on the stall table, low
#   front view; the draw animation shakes this image, so it is framed with room above the slip tips.
# Missing models: no registered pack has these. PROPS_NEEDED.md lists 红纸字帖 (under 红纸对联和斗方), 毛笔 and
# 签筒和竹签 with the stand-in column empty, and red line 1 forbids scripted stand-ins (a box is not a slip).
# KayKit book_single / Restaurant cuttingboard were rejected as stand-ins for the red paper because they read
# as a different object. So every variant renders only its shell (stall tabletop, plus the temple-red wall
# behind the slip and the tube) with its own camera and light; the props go in when their models are
# registered. The character on the paper and the lot text must be unreadable strokes / ink dots (ASSET_LIST
# note), drawn in the prop model's own texture, never an outside image.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import batch_26_object_fortune_c0 + SCENES entry
# "batch_26_object_fortune_c0": batch_26_object_fortune_c0) or render.py rejects --scene.
# SIZE is the char icon size and render.py only reads SIZE, so render the others with --size SIZES[variant]
# (24x32, 16x32), or teach render.py to use SIZES.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# No model and no image is loaded, so L.LOADED stays empty and check_sources() has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing and light are unchecked. Render every variant before use.
import math

import bl_lib as L

SIZE = (24, 24)
VARIANTS = ('prop.fortune.char', 'prop.fortune.slip', 'prop.fortune.tube',)
IDS = {'prop.fortune.char': 'prop.fortune.char', 'prop.fortune.slip': 'prop.fortune.slip',
       'prop.fortune.tube': 'prop.fortune.tube'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ()
DUSK = ()

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height).
# Real sizes the frames are cut for (1 unit ~ 0.75 m): red paper ~0.3 m square with a 0.2 m brush, slip
# ~0.2 m long, tube ~0.2 m tall with slips standing ~0.08 m out of it.
SPEC = {
    'prop.fortune.char': ((24, 24), 0.55, 0.0),
    'prop.fortune.slip': ((24, 32), 0.40, 0.14),
    'prop.fortune.tube': ((16, 32), 0.48, 0.19),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

TABLE = (0.12, 0.068, 0.035)      # worn stall tabletop
TEMPLE_WALL = (0.30, 0.07, 0.04)  # red-washed temple-yard wall behind the stall
WALL = 0.12


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _tabletop():
    # Slab whose top face is z = 0.
    L.box("tabletop", (2.0, 1.4, 0.06), (0.0, 0.2, -0.03), TABLE)


def _char():
    # Stall tabletop only; the red paper (红纸字帖) and the brush (毛笔) have no model (PROPS_NEEDED).
    _tabletop()


def _slip():
    # Tabletop and the temple-red wall close behind; the red-tipped slip (竹签) has no model (PROPS_NEEDED).
    _tabletop()
    L.plane("backwall", (2.0, 1.2), (0.0, WALL, 0.6), (math.radians(90), 0, 0), TEMPLE_WALL)


def _tube():
    # Tabletop and the temple-red wall further back; the lot tube with its slips (签筒, 竹签) has no model.
    _tabletop()
    L.plane("backwall", (2.0, 1.2), (0.0, WALL * 3, 0.6), (math.radians(90), 0, 0), TEMPLE_WALL)


BUILD = {
    'prop.fortune.char': _char,
    'prop.fortune.slip': _slip,
    'prop.fortune.tube': _tube,
}


def build(variant, toon=True):
    (w, h), extent, height = SPEC[variant]
    BUILD[variant]()
    # Blender's sensor (36 mm) fits the longer image side, so the lens follows from distance and extent.
    if variant == 'prop.fortune.char':
        # Nearly top-down (70 deg pitch), turned a little to the right, so the paper reads as a flat sheet and
        # the brush lying across its corner keeps its length.
        dist = 1.6
        a, b = math.radians(70), math.radians(8)
        L.camera((dist * math.cos(a) * math.sin(b), -dist * math.cos(a) * math.cos(b), height + dist * math.sin(a)),
                 (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(35), 0, math.radians(-40))       # high from the upper left, short brush shadow
    elif variant == 'prop.fortune.slip':
        # Straight on at the slip's middle, wall just behind, so the red tip and the ink dots face the camera.
        dist = 1.4
        L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(45), 0, math.radians(-30))       # from the upper left, grazing the wall
    else:
        # Low front view, a little from above (12 deg) so the tube mouth and the fan of slip heads both show.
        dist = 1.8
        a = math.radians(12)
        L.camera((0.0, -dist * math.cos(a), height + dist * math.sin(a)), (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(50), 0, math.radians(35))        # from the upper right, behind the camera
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=sun)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68), rot=sun, size=extent)
