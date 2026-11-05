# Counter interior, batch 03 part 2: twelve 64x48 card illustrations in the same room as
# batch_03_interior_counter_c0 (its room shell, counter, shelves and street are reused, not copied), each with
# its own camera, light and the few props a registered pack actually has.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: every person (district clerk in dark uniform, old man in long gown and
# skullcap, young companion, woman in cloth jacket / Shen Ruhua, stranger in a low-brimmed hat, short-jacket
# man, the shopkeeper's hands); red-stamped fine, levy notice and levy slips, ticket spike, abacus, cash box,
# small wooden casket, silver dollars / copper cash on red string, ingots, embroidered purse, cloth bundles,
# folded cotton coat, teapot, blue-and-white vase, red lanterns, fu-character square, oil lamp. The lamp, the
# lanterns and the doorway are present as light only.
# Stand-ins that are what they look like: book_set for ledgers, bowl_small for tea bowls, KayKit jars as the
# shop's goods.
# Composition (cameras, prop positions) was chosen by Claude, not from the creator's sketch: per
# BLENDER_PIPELINE.md section 1.2/1.3 these are layout drafts until the creator supplies placements.
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene; this module imports
# batch_03_interior_counter_c0 relatively, so it must be loaded through the scenes package (render.py does).
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# NOT YET RENDERED: writing this file and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

from . import batch_03_interior_counter_c0 as room

SIZE = (64, 48)
VARIANTS = ('illus.fa.1939.district_fine', 'illus.fa.1940.old_buyer', 'illus.fa.any.found_claim',
            'illus.fa.any.regular_intro', 'illus.fa.any.stranger_deal', 'illus.fa.any.street_fine',
            'illus.st.pawn_own', 'illus.gl.1938.levy_clear', 'illus.gl.1939.clear_books',
            'illus.gl.1940.cash_left', 'illus.gl.1940.levy_done', 'illus.lf.1939.pawn_coat',)
IDS = {'illus.fa.1939.district_fine': 'illus.fa.1939.district_fine',
       'illus.fa.1940.old_buyer': 'illus.fa.1940.old_buyer',
       'illus.fa.any.found_claim': 'illus.fa.any.found_claim',
       'illus.fa.any.regular_intro': 'illus.fa.any.regular_intro',
       'illus.fa.any.stranger_deal': 'illus.fa.any.stranger_deal',
       'illus.fa.any.street_fine': 'illus.fa.any.street_fine', 'illus.st.pawn_own': 'illus.st.pawn_own',
       'illus.gl.1938.levy_clear': 'illus.gl.1938.levy_clear',
       'illus.gl.1939.clear_books': 'illus.gl.1939.clear_books',
       'illus.gl.1940.cash_left': 'illus.gl.1940.cash_left',
       'illus.gl.1940.levy_done': 'illus.gl.1940.levy_done', 'illus.lf.1939.pawn_coat': 'illus.lf.1939.pawn_coat'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

TOP = room.TOP
RW = room.RW
BW = room.BW

DUSK = ('illus.fa.any.stranger_deal', 'illus.gl.1939.clear_books', 'illus.lf.1939.pawn_coat')
NIGHT = ('illus.gl.1940.cash_left',)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _ledger(loc, rot_z, scale=0.55, val=0.7):
    b = L.load(L.FURNITURE, "book_set.gltf", loc, rot_z, scale, tag="ledger")
    L.tone(b, sat=0.25, val=val)
    L.noline(b)


def _props(variant):
    # Counter-top props stand on TOP; the customer side is +y of the counter (y=0.5).
    if variant == 'illus.fa.1940.old_buyer':
        # Goods set out on the counter for the old customer to choose from.
        for x, k in ((-0.7, "jar_C_large"), (0.0, "jar_B_large"), (0.65, "jar_D_medium")):
            L.tone(L.load(L.RESTAURANT, k + ".gltf", (x, 0.55, TOP), 0.0, 0.8, tag="jar"), sat=0.35, val=0.95)
    elif variant == 'illus.fa.any.regular_intro':
        for x in (-0.35, 0.3):
            L.tone(L.load(L.RESTAURANT, "bowl_small.gltf", (x, 0.7, TOP), 0.0, 1.3, tag="teabowl"),
                   sat=0.3, val=0.95)
    elif variant == 'illus.gl.1938.levy_clear':
        _ledger((0.15, 0.45, TOP), 0.25)
    elif variant == 'illus.gl.1939.clear_books':
        _ledger((-0.35, 0.45, TOP), -0.15)
        _ledger((0.45, 0.5, TOP), 0.4, 0.45, 0.6)
    elif variant == 'illus.gl.1940.cash_left':
        _ledger((-0.5, 0.4, TOP), 0.1, 0.5, 0.6)


# variant: (camera location, look-at point, lens mm). Cameras are framed for 4:3.
CAMS = {
    # Customer's view, slightly left: counter top and the goods shelves behind it.
    'illus.fa.1939.district_fine': ((1.6, 3.4, 2.2), (-0.4, -0.2, 1.9), 30),
    'illus.fa.1940.old_buyer': ((-1.3, 3.2, 2.3), (0.3, -0.6, 1.8), 28),
    # Across the counter from the right, its length running into the picture.
    'illus.fa.any.found_claim': ((3.6, 2.6, 2.4), (-0.6, 0.3, 1.8), 26),
    'illus.fa.any.regular_intro': ((-2.2, 2.9, 2.6), (0.3, 0.5, 1.9), 28),
    # From near the door, low and backlit at dusk.
    'illus.fa.any.stranger_deal': ((0.6, 6.4, 1.5), (0.0, 0.2, 1.9), 30),
    # Over the clerk's shoulder towards the customer side and the doorway.
    'illus.fa.any.street_fine': ((0.8, -1.6, 2.9), (0.0, 3.0, 1.6), 28),
    # Looking up at the high counter from below, customer side.
    'illus.st.pawn_own': ((0.3, 2.6, 0.9), (0.0, 0.4, 2.3), 24),
    # Close, high views on the counter top.
    'illus.gl.1938.levy_clear': ((0.5, 1.8, 3.0), (0.0, 0.5, TOP), 30),
    'illus.gl.1939.clear_books': ((-0.8, 2.1, 2.8), (0.2, 0.3, TOP), 30),
    'illus.gl.1940.cash_left': ((0.9, 1.9, 2.6), (0.0, 0.4, TOP), 30),
    # Rear wall on the right above the counter, where the stamped notice would hang.
    'illus.gl.1940.levy_done': ((-1.5, 2.8, 2.4), (2.6, RW, 2.3), 28),
    'illus.lf.1939.pawn_coat': ((-0.4, 3.0, 2.7), (0.2, 0.3, 1.9), 30),
}


def _lights(variant, toon):
    door = (0, BW - 0.6, 2.4)
    if variant in NIGHT:
        room._sky((0.10, 0.15, 0.36), 1.6)
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        L.light('AREA', door, 80, (0.45, 0.55, 1.0), rot=(math.radians(-90), 0, 0), size=2.5)
        # Oil lamp on the counter beside the money (light only, the lamp model is missing).
        L.light('POINT', (0.7, 0.3, TOP + 0.45), 90, (1.0, 0.62, 0.28), size=0.2)
    elif variant in DUSK:
        room._sky((1.0, 0.58, 0.26), 1.5)
        L.world((0.50, 0.32, 0.22), 0.5)
        L.light('SUN', (0, 0, 6), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(70), 0, math.radians(180)))
        L.light('AREA', door, 350, (1.0, 0.60, 0.30), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, 5.0, 3.8), 120, (1.0, 0.80, 0.60), rot=(math.radians(-55), 0, 0), size=5)
        if variant == 'illus.gl.1939.clear_books':
            # Year-end lanterns over the counter (light only, the lantern model is missing).
            for x in (-1.2, 1.2):
                L.light('POINT', (x, 0.2, 3.3), 40, (1.0, 0.30, 0.18), size=0.2)
    else:
        room._sky((0.95, 0.93, 0.85), 2.5)
        L.world((0.80, 0.80, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(35), 0, math.radians(150)))
        L.light('AREA', door, 500, (1.0, 0.96, 0.88), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, -1.6, 3.6), 260, (1.0, 0.97, 0.92), rot=(math.radians(60), 0, 0), size=5)
        L.light('AREA', (0, 5.0, 3.8), 260, (1.0, 0.95, 0.85), rot=(math.radians(-55), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    room._room()
    room._counter()
    room._street()
    room._rear_shelves()
    room._side_shelves()
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
