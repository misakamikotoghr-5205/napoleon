# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Office interior, batch 15: two 320x180 backdrops (bg.baogong, bg.post) and four 64x48 card illustrations
# set in one plaster-and-timber town office room in Qingxi. A long public counter (cabinets under a plank top)
# runs across the room, shelves stand on the back wall, and a window on the left wall (light only) lets the day
# in. Camera, light and desk props change per variant. The baogong hall and the post agency share the counter
# set, which the shot list allows.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: wall clock, blank wooden plaque / blank signboard, notice board with
# blank notices, wooden lattice window (only its light is here), long wooden bench, glass display case,
# iron counter railing, mail bags, money bag, the shop's wooden seal, abacus, writing brush, ink stone,
# bamboo baskets of white cocoons, a long-gown clerk, the dark-uniformed official, the complainant in a short
# jacket, Shen Ruhua. Until those are registered, the cards show only their setting and the props below.
# Stand-ins that are what they look like: rows of cabinet_medium under a shell plank top for the counter (as in
# batch 11), shelf_B_large with book_set bundles for the letter pigeonholes (as in batch 11), shelf_A_big for
# the goods shelf, crate for the cocoon crates (empty, no cocoons) and parcels, table_medium_long /
# table_medium / table_small for the desks, book_single for ledgers and papers, chair_A_wood /
# chair_stool_wood for seats.
# Floor, walls, ceiling, wainscot, posts, beams, the counter-top slab and the dais are shell from L.box / L.plane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import batch_15_interior_office_c0 + SCENES entry
# "batch_15_interior_office_c0": batch_15_interior_office_c0) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: furniture fronts face -y at rot_z=0. Cameras look towards +y, the back wall is at y = BW and
# the window wall at x = -SW. Only models from registered KayKit packs are loaded and no images, so
# check_sources() has nothing to reject.
import math

import bpy
import mathutils

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.baogong', 'bg.post', 'illus.bf.1938.bail_shop', 'illus.ev.1939.cocoon_desk',
            'illus.fa.any.false_charge', 'illus.st.copy',)
IDS = {'bg.baogong': 'bg.baogong', 'bg.post': 'bg.post', 'illus.bf.1938.bail_shop': 'illus.bf.1938.bail_shop',
       'illus.ev.1939.cocoon_desk': 'illus.ev.1939.cocoon_desk',
       'illus.fa.any.false_charge': 'illus.fa.any.false_charge', 'illus.st.copy': 'illus.st.copy'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.baogong', 'bg.post')
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

NIGHT = ('illus.bf.1938.bail_shop',)
DUSK = ('illus.st.copy',)

BW = 3.0        # back wall y
FW = -5.0       # front edge of floor / ceiling, y
SW = 5.0        # side walls at x = +-SW
CEIL = 3.6
TOP = 1.05      # counter-top height
CY = 0.9        # counter centre y
CX0, CX1 = -3.3, 2.2    # counter ends, x
WIN = (-SW + 0.2, -1.0, 2.0)    # where the lattice window would be (its light only)

WOOD_DARK = (0.08, 0.045, 0.025)
WOOD = (0.20, 0.11, 0.05)
TOP_WOOD = (0.28, 0.15, 0.07)
DESK = (0.24, 0.13, 0.06)
PLASTER = (0.62, 0.58, 0.50)
FLOOR = (0.13, 0.08, 0.045)
CRATE = (0.42, 0.30, 0.16)

# Objects with these tags start at z=0 and are set onto the desk under them by _lift().
ON_DESK = ("ledger", "notice", "docket")


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room():
    # Shell only (red line 1): floor, ceiling, walls, wainscot, posts, beams.
    depth = BW - FW
    cy = (BW + FW) / 2
    L.plane("floor", (2 * SW, depth), (0, cy, 0), (0, 0, 0), FLOOR)
    L.plane("ceiling", (2 * SW, depth), (0, cy, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    L.box("wall_back", (2 * SW, 0.3, CEIL), (0, BW + 0.15, CEIL / 2), PLASTER)
    L.box("wainscot_back", (2 * SW, 0.06, 0.9), (0, BW - 0.03, 0.45), WOOD)
    for s in (-1, 1):
        L.box("wall_side", (0.3, depth, CEIL), (s * (SW + 0.15), cy, CEIL / 2), PLASTER)
        L.box("wainscot_side", (0.06, depth, 0.9), (s * (SW - 0.03), cy, 0.45), WOOD)
        for y in (BW - 0.13, -1.6):
            L.box("post", (0.26, 0.26, CEIL), (s * (SW - 0.13), y, CEIL / 2), WOOD_DARK)
    for y in (-2.4, 0.3, 2.6):
        L.box("beam", (2 * SW, 0.26, 0.26), (0, y, CEIL - 0.13), WOOD_DARK)


def _counter():
    # Long public counter: a row of registered cabinets under a shell plank top, clerk side behind (+y).
    n = 5
    step = (CX1 - CX0) / n
    for i in range(n):
        c = L.load(L.FURNITURE, "cabinet_medium.gltf", (CX0 + step * (i + 0.5), CY, 0), 0.0, 1.0, tag="counter")
        L.recolor(c, (0.22, 0.12, 0.055))
    L.box("countertop", (CX1 - CX0 + 0.3, 1.0, 0.1), ((CX0 + CX1) / 2, CY, TOP - 0.05), TOP_WOOD)


def _book(loc, rot, scale=0.8, val=0.7, tag="ledger"):
    b = L.load(L.FURNITURE, "book_single.gltf", loc, rot, scale, tag=tag)
    L.tone(b, sat=0.25, val=val)
    L.noline(b)
    return b


def _shelf_with_bundles(x, kind, val=0.8, tag="files"):
    L.tone(L.load(L.FURNITURE, kind, (x, BW - 0.35, 0), 0.0, 1.2, tag="shelf"), sat=0.3, val=0.5)
    for z in (1.0, 1.9):
        for dx in (-0.3, 0.05, 0.4):
            b = L.load(L.FURNITURE, "book_set.gltf", (x + dx, BW - 0.45, z), 0.0, 0.5, tag=tag)
            L.tone(b, sat=0.2, val=val)
            L.noline(b)


def _crate(loc, rot, rgb=CRATE, tag="cocoon_crate"):
    L.recolor(L.load(L.RESTAURANT, "crate.gltf", loc, rot, 0.5, tag=tag), rgb)


def _desk(name, loc, rot, rgb=DESK):
    d = L.load(L.FURNITURE, name, loc, rot, 1.0, tag="desk")
    L.recolor(d, rgb)
    return d


def _chair(loc, rot, name="chair_A_wood.gltf"):
    L.recolor(L.load(L.FURNITURE, name, loc, rot, 1.0, tag="chair"), WOOD)


def _props(variant):
    if variant == 'bg.baogong':
        # Baogong office hall: long counter, file shelves behind, clerk's stool and ledgers.
        _counter()
        for x in (-2.6, -0.6, 3.0):
            _shelf_with_bundles(x, "shelf_B_large.gltf", val=0.75)
        _chair((-1.2, CY + 1.0, 0), 0.2, "chair_stool_wood.gltf")
        _book((-1.6, CY - 0.1, TOP), 0.2, tag="counter_book")
        _book((0.9, CY + 0.1, TOP), -0.3, val=0.6, tag="counter_book")
        # Public side: a desk against the right wall where forms are filled in.
        _desk("table_medium.gltf", (3.9, -1.0, 0), math.pi / 2)
        _chair((3.2, -1.0, 0), -math.pi / 2, "chair_stool_wood.gltf")
    elif variant == 'bg.post':
        # Post agency: same counter, a wall of letter pigeonholes behind, parcels by the counter end.
        _counter()
        for x in (-2.8, -1.2, 0.4, 2.0):
            _shelf_with_bundles(x, "shelf_B_large.gltf", val=0.9, tag="mail")
        _chair((-0.6, CY + 1.0, 0), -0.2, "chair_stool_wood.gltf")
        _book((-2.4, CY - 0.1, TOP), 0.1, tag="mail")
        _book((-2.35, CY - 0.05, TOP + 0.06), 0.4, tag="mail")
        for loc, rot in (((2.9, CY + 0.2, 0), 0.1), ((3.3, CY + 0.7, 0), -0.2), ((3.0, CY + 0.4, 0.4), 0.3)):
            _crate(loc, rot, (0.36, 0.24, 0.12), tag="parcel")
    elif variant == 'illus.bf.1938.bail_shop':
        # Police-post desk under the lamp: a ledger and a notice where the bail is put down.
        _desk("table_medium.gltf", (0.0, 0.0, 0), 0.0, WOOD)
        _chair((0.0, 0.8, 0), math.pi)
        _book((-0.25, -0.05, 0.0), 0.15, 0.9, val=0.6)
        _book((0.3, 0.1, 0.0), -0.4, 0.7, val=0.85, tag="notice")
        _shelf_with_bundles(-0.8, "shelf_A_big.gltf", val=0.6)
    elif variant == 'illus.ev.1939.cocoon_desk':
        # Cocoon hall: registration desk with the ledger, crates waiting in front, goods shelves behind.
        _desk("table_medium_long.gltf", (0.0, 0.6, 0), 0.0)
        _chair((0.2, 1.4, 0), math.pi + 0.15)
        _book((0.25, 0.55, 0.0), 0.1, 0.9, val=0.85)
        _book((-0.5, 0.65, 0.0), -0.3, 0.7, val=0.6)
        for x in (-1.6, 1.4):
            L.tone(L.load(L.FURNITURE, "shelf_A_big.gltf", (x, BW - 0.35, 0), 0.0, 1.2, tag="goods_shelf"),
                   sat=0.3, val=0.5)
        for loc, rot in (((-1.2, -0.6, 0), 0.1), ((-0.5, -0.9, 0), -0.15), ((0.6, -0.7, 0), 0.2),
                         ((-0.9, -0.75, 0.4), -0.05)):
            _crate(loc, rot)
    elif variant == 'illus.fa.any.false_charge':
        # The official's desk on a raised dais at the back, empty floor in front where the accuser stands.
        L.box("dais", (3.6, 2.0, 0.25), (0.0, BW - 1.0, 0.125), WOOD_DARK)
        _desk("table_medium_long.gltf", (0.0, BW - 1.3, 0.25), 0.0, (0.16, 0.08, 0.04))
        _chair((0.0, BW - 0.6, 0.25), math.pi)
        _book((-0.4, BW - 1.35, 0.0), 0.1, 0.8, val=0.6, tag="docket")
        _shelf_with_bundles(-2.6, "shelf_B_large.gltf", val=0.6)
    elif variant == 'illus.st.copy':
        # Small desk by the window: an open account book and a second one waiting.
        _desk("table_small.gltf", (-SW + 0.7, -1.0, 0), math.pi / 2)
        _chair((-SW + 1.4, -1.0, 0), math.pi / 2, "chair_stool_wood.gltf")
        _book((-SW + 0.7, -1.05, 0.0), 0.1, 0.9, val=0.9)
        _book((-SW + 0.65, -0.65, 0.0), -0.25, 0.7, val=0.55)


def _lift():
    # Desk heights are unchecked until rendered, so books tagged ON_DESK are set onto the top of
    # the desk mesh under them, using its world bounding box.
    bpy.context.view_layer.update()
    desks = [o for o in bpy.data.objects if o.type == 'MESH' and o.get("tag") == "desk"]
    for o in bpy.data.objects:
        if o.parent is not None or o.get("tag") not in ON_DESK:
            continue
        top = None
        for d in desks:
            pts = [d.matrix_world @ mathutils.Vector(c) for c in d.bound_box]
            if (min(p.x for p in pts) <= o.location.x <= max(p.x for p in pts)
                    and min(p.y for p in pts) <= o.location.y <= max(p.y for p in pts)):
                z = max(p.z for p in pts)
                top = z if top is None else max(top, z)
        if top is not None:
            o.location.z = top


# variant: (camera location, look-at point, lens mm).
CAMS = {
    'bg.baogong': ((-0.4, -4.6, 1.9), (0.0, BW, 1.3), 22),
    'bg.post': ((1.6, -4.4, 1.8), (-0.6, BW, 1.3), 24),
    'illus.bf.1938.bail_shop': ((0.5, -1.4, 1.6), (0.0, 0.05, 0.75), 30),
    'illus.ev.1939.cocoon_desk': ((1.8, -2.8, 1.6), (-0.1, 0.4, 0.6), 26),
    'illus.fa.any.false_charge': ((0.9, -2.6, 0.9), (0.0, BW - 1.3, 1.1), 26),
    'illus.st.copy': ((-SW + 2.0, -2.2, 1.5), (-SW + 0.7, -0.9, 0.7), 30),
}


def _lights(variant, toon):
    if variant in NIGHT:
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        # Hanging kerosene lamp over the desk (light only, lamp missing).
        L.light('POINT', (0.2, 0.0, 1.8), 120, (1.0, 0.62, 0.28), size=0.12)
        L.light('AREA', (-1.5, -1.5, 3.0), 15, (0.50, 0.58, 0.90), rot=(math.radians(50), 0, math.radians(-30)),
                size=4)
    elif variant in DUSK:
        L.world((0.45, 0.36, 0.30), 0.35 if toon else 0.5)
        # Low, warm light through the left window onto the desk (rotation about y aims the area light at +x).
        L.light('AREA', WIN, 220, (1.0, 0.72, 0.45), rot=(0, math.radians(-75), math.radians(-15)), size=1.4)
        L.light('SUN', (0, 0, 5), 0.8, (1.0, 0.80, 0.60), rot=(math.radians(60), 0, math.radians(-70)))
    else:
        L.world((0.70, 0.66, 0.60), 0.6 if toon else 0.5)
        # Daylight through the left window plus a soft fill from the open front.
        L.light('AREA', WIN, 260, (1.0, 0.95, 0.86), rot=(0, math.radians(-70), 0), size=2.0)
        L.light('SUN', (0, 0, 6), 2.2, (1.0, 0.92, 0.80), rot=(math.radians(45), 0, math.radians(-30)))
        L.light('AREA', (0, -3.5, 3.0), 120, (1.0, 0.97, 0.92), rot=(math.radians(55), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _props(variant)
    _lift()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
