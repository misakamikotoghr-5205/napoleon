# Post office agency interior, batch 11: illus.nt.telegraph (64x48), the small postal/telegraph counter of
# the town agency at night. A low counter (two cabinets under a plank top) in the foreground right, a
# pigeonhole letter rack (shelves of bundled mail) on the plaster back wall, a stool behind the counter, and
# one warm kerosene-lamp glow on the counter top.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: brass telegraph key, blank telegram forms, pen / brush and ink stone,
# brass kerosene lamp (only its light is here; lamp_table is a modern lamp), proper pigeonhole letter rack
# (shelf_B_large with bundles stands in for it). Until those are registered the card shows only its setting.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST/CITY helpers: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import batch_11_interior_post_office_c0 + SCENES entry
# "batch_11_interior_post_office_c0": batch_11_interior_post_office_c0) or render.py rejects --scene.
# Furniture fronts face -y at rot_z=0; cameras look towards +y, the back wall is at y = BW.
# Only models from registered KayKit packs are loaded; no images, no props from box/plane (box/plane are
# floor, walls, ceiling, beams, posts and the counter-top slab only), so check_sources() has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.nt.telegraph',)
IDS = {'illus.nt.telegraph': 'illus.nt.telegraph'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.nt.telegraph',)
DUSK = ()

BW = 2.6        # back wall y; cameras look towards +y
FW = -3.0       # front edge of the floor / ceiling, y
SW = 3.0        # side walls at x = +-SW
CEIL = 3.4
TOP = 1.05      # counter-top height
COUNTER = (0.4, 0.6)    # x, y centre of the counter
LAMP = (0.95, 0.55, TOP + 0.35)   # where the kerosene lamp would stand (its glow only)

WOOD_DARK = (0.08, 0.045, 0.025)
WOOD = (0.20, 0.11, 0.05)
TOP_WOOD = (0.28, 0.15, 0.07)
PLASTER = (0.50, 0.44, 0.34)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room():
    # Shell only (red line 1): floor, ceiling, walls, wainscot, posts, beams.
    depth = BW - FW
    L.plane("floor", (2 * SW, depth), (0, (BW + FW) / 2, 0), (0, 0, 0), (0.13, 0.08, 0.045))
    L.plane("ceiling", (2 * SW, depth), (0, (BW + FW) / 2, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    L.box("wall_back", (2 * SW, 0.3, CEIL), (0, BW + 0.15, CEIL / 2), PLASTER)
    L.box("wainscot_back", (2 * SW, 0.06, 0.9), (0, BW - 0.03, 0.45), WOOD)
    for s in (-1, 1):
        L.box("wall_side", (0.3, depth, CEIL), (s * (SW + 0.15), (BW + FW) / 2, CEIL / 2), PLASTER)
        L.box("post", (0.26, 0.26, CEIL), (s * (SW - 0.13), BW - 0.13, CEIL / 2), WOOD_DARK)
    for y in (-0.8, 1.6):
        L.box("beam", (2 * SW, 0.26, 0.26), (0, y, CEIL - 0.13), WOOD_DARK)


def _rack():
    # Letter rack on the back wall behind the counter: two tall shelves filled with bundled mail.
    for x in (-0.55, 0.85):
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (x, BW - 0.35, 0), 0.0, 1.2, tag="rack"),
               sat=0.3, val=0.5)
        for z in (1.0, 1.9):
            for dx in (-0.3, 0.05, 0.4):
                b = L.load(L.FURNITURE, "book_set.gltf", (x + dx, BW - 0.45, z), 0.0, 0.5, tag="mail")
                L.tone(b, sat=0.2, val=0.8)
                L.noline(b)


def _counter():
    # Counter body from two registered cabinets; the plank top is a shell slab.
    cx, cy = COUNTER
    for dx in (-0.55, 0.55):
        c = L.load(L.FURNITURE, "cabinet_medium.gltf", (cx + dx, cy, 0), 0.0, 1.0, tag="counter")
        L.recolor(c, (0.22, 0.12, 0.055))
    L.box("countertop", (2.6, 1.0, 0.1), (cx, cy, TOP - 0.05), TOP_WOOD)
    # Stool for the clerk behind the counter.
    s = L.load(L.FURNITURE, "chair_stool_wood.gltf", (cx - 0.3, cy + 0.9, 0), 0.3, 1.0, tag="stool")
    L.recolor(s, (0.26, 0.14, 0.06))
    # A ledger left on the counter top.
    b = L.load(L.FURNITURE, "book_single.gltf", (cx - 0.5, cy - 0.1, TOP), 0.25, 0.8, tag="ledger")
    L.tone(b, sat=0.25, val=0.7)
    L.noline(b)


def _lights(variant, toon):
    if variant in NIGHT:
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        L.light('POINT', LAMP, 140, (1.0, 0.62, 0.28), size=0.12)
        L.light('AREA', (-1.5, -1.5, 3.0), 20, (0.50, 0.58, 0.90), rot=(math.radians(50), 0, math.radians(-30)),
                size=4)
    else:
        L.world((0.70, 0.66, 0.60), 0.6)
        L.light('AREA', (0, -2.0, 3.0), 200, (1.0, 0.95, 0.86), rot=(math.radians(55), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _rack()
    _counter()
    # Three-quarter view from the customer side, slightly above the counter top.
    L.camera((-1.6, -2.2, 1.9), (0.5, BW - 0.6, 1.15), 26)
    _lights(variant, toon)
