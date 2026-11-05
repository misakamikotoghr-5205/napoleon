# Household stage props, batch 25: three small transparent-background sprites for the town stage (I-287).
# prop.broom (8x22): a bamboo broom standing upright, leaning on a wall, straight-on at eye level.
# prop.trash (30x28): a woven bamboo wastepaper basket on the floor, 3/4 view from above, front left.
# prop.trunk (16x14): the small rattan trunk the elder brother carried when he left home, low 3/4 view, front
#   right.
# Missing models: no registered pack has these, PROPS_NEEDED.md lists no KayKit stand-in for any of them
# (竹扫帚, 竹编纸篓, 小藤箱 are all on it with the stand-in column empty), and red line 1 forbids scripted
# stand-ins. City trash_A / trash_B (modern bins) and Restaurant crate (slatted crate) were rejected as
# stand-ins because they read as a different object. So every variant renders only its shell (floor, plus the
# wall the broom leans on) with its own camera and light, and the prop goes in when its model is registered.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import batch_25_object_household_c0 + SCENES entry
# "batch_25_object_household_c0": batch_25_object_household_c0) or render.py rejects --scene.
# SIZE is the broom size and render.py only reads SIZE, so render the others with --size SIZES[variant]
# (30x28, 16x14), or teach render.py to use SIZES.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# No model and no image is loaded, so L.LOADED stays empty and check_sources() has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing and light are unchecked. Render every variant before use.
import math

import bl_lib as L

SIZE = (8, 22)
VARIANTS = ('prop.broom', 'prop.trash', 'prop.trunk',)
IDS = {'prop.broom': 'prop.broom', 'prop.trash': 'prop.trash', 'prop.trunk': 'prop.trunk'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ()
DUSK = ()

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height).
# Real sizes the frames are cut for: broom ~1.4 m tall, basket ~0.35 m, trunk ~0.55 x 0.32 x 0.35 m.
SPEC = {
    'prop.broom': ((8, 22), 1.7, 0.75),
    'prop.trash': ((30, 28), 0.7, 0.18),
    'prop.trunk': ((16, 14), 0.9, 0.18),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

WALL = 0.25
FLOOR = (0.12, 0.075, 0.042)
PLASTER = (0.60, 0.56, 0.48)
BRICK_FLOOR = (0.20, 0.19, 0.17)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _broom():
    # Plank floor and the plaster wall it leans on; the bamboo broom (竹扫帚) has no model (PROPS_NEEDED).
    L.plane("floor", (4, 3), (0, 0, 0), (0, 0, 0), FLOOR)
    L.plane("backwall", (4, 3), (0, WALL, 1.5), (math.radians(90), 0, 0), PLASTER)


def _trash():
    # Grey brick floor of the counter room only; the woven basket (竹编纸篓) has no model (PROPS_NEEDED).
    L.plane("floor", (3, 3), (0, 0, 0), (0, 0, 0), BRICK_FLOOR)


def _trunk():
    # Plank floor only, the sprite is cut out; the rattan trunk (小藤箱) has no model (PROPS_NEEDED).
    L.plane("floor", (3, 3), (0, 0, 0), (0, 0, 0), FLOOR)


BUILD = {
    'prop.broom': _broom,
    'prop.trash': _trash,
    'prop.trunk': _trunk,
}


def build(variant, toon=True):
    (w, h), extent, height = SPEC[variant]
    BUILD[variant]()
    # Blender's sensor (36 mm) fits the longer image side, so the lens follows from distance and extent.
    if variant == 'prop.broom':
        # Straight on, eye level with the broom's middle, wall right behind it.
        dist = extent * 2.5
        L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(45), 0, math.radians(-35))       # from the upper left, grazing the wall
    elif variant == 'prop.trash':
        # 3/4 view from above, front left, so the basket's open mouth shows.
        dist = 2.2
        L.camera((-dist * 0.5, -dist * 0.7, height + dist * 0.75), (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(40), 0, math.radians(-50))
    else:
        # Low 3/4 view, front right, so the trunk's long side and its lid both read.
        dist = 2.4
        L.camera((dist * 0.55, -dist * 0.75, height + dist * 0.4), (0.0, 0.0, height), 36.0 * dist / extent)
        sun = (math.radians(50), 0, math.radians(35))        # from the upper right, behind the camera
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=sun)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68), rot=sun, size=extent)
