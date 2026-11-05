# Furniture props, batch 21: four transparent-background sprites for the old-town map and the shop.
# prop.bed (32x28): wooden bed, blue-flowered quilt, two pillows, 3/4 view from above.
# prop.clothes_rack (32x40): wooden clothes rack with a pawned long gown and a red qipao hung on it, no body.
# prop.curio (52x38): the empty curio shelf on the counter's right wall, two rows of three cells that must line
#   up with curio_cell (old objects are placed into it by code, so its camera is also theirs).
# prop.shelf (208x50): long back-wall goods shelf of cloth bundles and wooden boxes, a plaque and a red-cloth
#   shrine with red candles in the middle.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and are already on PROPS_NEEDED.md: blue-print quilt (棉被和枕头), hung long gown and qipao and the
# wooden clothes rack (挂着的衣服), curio shelf (博古架), cloth bundles (布包袱), blue-and-white vase (青花瓷瓶),
# shrine (神龛), red candles (蜡烛与铜烛台). prop.clothes_rack and prop.curio therefore render only their
# shell (floor / wall) with their own camera until those models are registered.
# Stand-ins that PROPS_NEEDED.md lists for these props: bed_single_A for the narrow wooden bed, pillow_A for
# the pillows, shelf_B_large (dark wood) for the long goods shelf, cabinet_small for the wooden boxes,
# pictureframe_large_B for the plaque (blank, so nothing is readable). jar_* from Restaurant stand in for
# crocks on the shelf.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import batch_21_object_furniture_c0 + SCENES entry
# "batch_21_object_furniture_c0": batch_21_object_furniture_c0) or render.py rejects --scene.
# SIZE is the bed size and render.py only reads SIZE, so render the others with --size SIZES[variant]
# (32x40, 52x38, 208x50), or teach render.py to use SIZES.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Orientation: furniture fronts face -y at rot_z=0; walls stand at y = WALL behind the props.
# Only models from registered KayKit packs are loaded (all files checked present under tools/blender/models)
# and no images, so check_sources() has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
import math

import bl_lib as L

SIZE = (32, 28)
VARIANTS = ('prop.bed', 'prop.clothes_rack', 'prop.curio', 'prop.shelf',)
IDS = {'prop.bed': 'prop.bed', 'prop.clothes_rack': 'prop.clothes_rack', 'prop.curio': 'prop.curio',
       'prop.shelf': 'prop.shelf'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ()
DUSK = ()

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height).
SPEC = {
    'prop.bed': ((32, 28), 3.0, 0.4),
    'prop.clothes_rack': ((32, 40), 2.6, 1.2),
    'prop.curio': ((52, 38), 2.4, 1.6),
    'prop.shelf': ((208, 50), 9.0, 1.1),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

WALL = 1.0
WOOD_DARK = (0.07, 0.04, 0.022)
WOOD = (0.20, 0.11, 0.05)
BED = (0.22, 0.10, 0.045)
PILLOW = (0.55, 0.52, 0.44)
FLOOR = (0.12, 0.075, 0.042)
PLASTER = (0.60, 0.56, 0.48)
PLANK = (0.06, 0.035, 0.02)
LACQUER = (0.025, 0.018, 0.012)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _m(pack, name, loc, rot=0.0, scale=1.0, rgb=None, tag="", line=True, sat=None, val=1.0):
    objs = L.load(pack, name, loc, rot, scale, tag=tag)
    if rgb is not None:
        L.recolor(objs, rgb)
    elif sat is not None:
        L.tone(objs, sat=sat, val=val)
    if not line:
        L.noline(objs)
    return objs


def _bed():
    # Floor only; the sprite is cut out, the floor just catches the shadow. Bed head towards +y.
    L.plane("floor", (8, 8), (0, 0, 0), (0, 0, 0), FLOOR)
    _m(L.FURNITURE, "bed_single_A.gltf", (0, 0, 0), 0.0, 1.0, BED, tag="bed")
    # Two pillows side by side at the head (height unchecked). The blue quilt has no model (PROPS_NEEDED).
    for x in (-0.22, 0.22):
        _m(L.FURNITURE, "pillow_A.gltf", (x, 0.75, 0.5), 0.0, 0.6, PILLOW, tag="pillow")


def _clothes_rack():
    # Shell only until the hung-clothes model is registered (挂着的衣服 on PROPS_NEEDED.md).
    L.plane("floor", (8, 6), (0, 0, 0), (0, 0, 0), FLOOR)
    L.plane("backwall", (8, 4), (0, WALL, 2.0), (math.radians(90), 0, 0), PLASTER)


def _curio():
    # Shell only: the counter's right plaster wall. The curio shelf (博古架) has no model, and a KayKit shelf
    # would not give the two-by-three cells that must match curio_cell.
    L.plane("rightwall", (6, 4), (0, WALL, 2.0), (math.radians(90), 0, 0), PLASTER)
    L.box("wainscot", (6, 0.05, 0.8), (0, WALL - 0.025, 0.4), WOOD)


def _shelf():
    L.plane("floor", (14, 4), (0, 0, 0), (0, 0, 0), FLOOR)
    L.plane("backwall", (14, 4), (0, WALL, 2.0), (math.radians(90), 0, 0), PLANK)
    # Four shelf units, two each side of the middle bay kept for the plaque and the shrine (scales unchecked).
    for x in (-3.4, -1.9, 1.9, 3.4):
        _m(L.FURNITURE, "shelf_B_large.gltf", (x, WALL - 0.3, 0), 0.0, 1.0, WOOD_DARK, tag="shelf")
    # Wooden boxes and crocks on the shelf boards (board heights unchecked).
    jars = ("jar_A_medium", "jar_C_small", "jar_B_medium", "jar_D_small")
    for i, x in enumerate((-3.4, -1.9, 1.9, 3.4)):
        _m(L.FURNITURE, "cabinet_small.gltf", (x - 0.25, WALL - 0.35, 0.05), 0.0, 0.45, WOOD, tag="box")
        _m(L.RESTAURANT, jars[i] + ".gltf", (x + 0.3, WALL - 0.35, 0.95), 0.0, 0.8, tag="jar", sat=0.35, val=0.9)
        _m(L.FURNITURE, "cabinet_small.gltf", (x, WALL - 0.35, 1.75), 0.0, 0.35, WOOD, tag="box")
    # Blank plaque above the middle bay; the shrine, its table and the candles below it have no model.
    _m(L.FURNITURE, "pictureframe_large_B.gltf", (0, WALL - 0.05, 2.3), 0.0, 1.0, LACQUER, tag="plaque")


BUILD = {
    'prop.bed': _bed,
    'prop.clothes_rack': _clothes_rack,
    'prop.curio': _curio,
    'prop.shelf': _shelf,
}


def build(variant, toon=True):
    (w, h), extent, height = SPEC[variant]
    BUILD[variant]()
    # Blender's sensor (36 mm) fits the longer image side, so the lens follows from distance and extent.
    if variant == 'prop.bed':
        # 3/4 view from above, from the front left.
        dist = 4.5
        look = (0.0, 0.0, height)
        L.camera((-dist * 0.5, -dist * 0.7, height + dist * 0.6), look, 36.0 * dist / extent)
    else:
        # Straight on, eye level with the prop's centre.
        dist = extent * 2.5
        L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the wall.
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-40)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-40)), size=extent)
