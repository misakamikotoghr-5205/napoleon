# Storeroom interior, batch 08: nine 64x48 card illustrations shot in one back storeroom. One room shell
# (plank floor, plaster walls, a plank door in the back wall, shelves of jars and book bundles along the back
# and left walls); camera, lights and a few props change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: rice sacks, straw mat, cloth bundles / paper-wrapped goods, wet cloth,
# wooden ladder, feather duster, rag, oil lamp (only its light is here; lamp_table is a modern lamp), rope,
# Chinese brass padlock and keys, brass-banded door fittings, and every person (patrolman, the heroine in
# blue, uniformed man, thief silhouette). Until those are registered, the cards show only their setting.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3), and it does not
# follow the sample scenes/storeroom.py layout.
# bl_lib has no place()/FURN/REST/CITY-place helpers: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# Model orientations are taken from the sample scenes: furniture fronts face -y at rot_z=0. door_A is 1.6
# wide and 2.8 high with its origin on the hinge (BLENDER_PIPELINE.md 4.5).
# Only models present in tools/blender/models/ (registered KayKit packs) are loaded; no images, no props from
# box/plane, so check_sources() has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.bf.1939.rice_hoard', 'illus.es.storeroom', 'illus.nt.tidy', 'illus.ev.1940.shop_search',
            'illus.fa.any.damp_loss', 'illus.fa.any.requisition', 'illus.fa.any.theft',
            'illus.gl.1938.storeroom', 'illus.kp.mystery_box',)
IDS = {'illus.bf.1939.rice_hoard': 'illus.bf.1939.rice_hoard', 'illus.es.storeroom': 'illus.es.storeroom',
       'illus.nt.tidy': 'illus.nt.tidy', 'illus.ev.1940.shop_search': 'illus.ev.1940.shop_search',
       'illus.fa.any.damp_loss': 'illus.fa.any.damp_loss', 'illus.fa.any.requisition': 'illus.fa.any.requisition',
       'illus.fa.any.theft': 'illus.fa.any.theft', 'illus.gl.1938.storeroom': 'illus.gl.1938.storeroom',
       'illus.kp.mystery_box': 'illus.kp.mystery_box'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.bf.1939.rice_hoard', 'illus.nt.tidy', 'illus.fa.any.theft', 'illus.kp.mystery_box')
DUSK = ('illus.fa.any.damp_loss', 'illus.fa.any.requisition', 'illus.gl.1938.storeroom')
# Variants with a gap on the back shelf (goods taken away).
GAP = ('illus.ev.1940.shop_search', 'illus.fa.any.requisition', 'illus.fa.any.theft')
# Variants with the back door standing open.
OPEN = ('illus.fa.any.requisition', 'illus.fa.any.theft')

BW = 3.4        # back wall y (with the door); cameras look towards +y
SW = 3.6        # side walls at x = +-SW
FW = -3.0       # front edge of the floor / ceiling, y
CEIL = 3.6
DOOR_X = 1.3    # hinge of the back door; the leaf spans x DOOR_X..DOOR_X+1.6
DOOR_W = 1.6
DOOR_H = 2.8
LAMP_STOOL = (-2.6, 2.2)   # x, y of the stool in the left corner (night lamp, tidy, mystery box)

WOOD_DARK = (0.08, 0.045, 0.025)
WOOD = (0.20, 0.11, 0.05)
CRATE = (0.35, 0.20, 0.09)
CRATE_LID = (0.42, 0.25, 0.11)
PLASTER = (0.50, 0.44, 0.34)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room(variant):
    # Shell only (red line 1): floor, ceiling, walls, wainscot, posts, beams, door frame.
    depth = BW - FW
    L.plane("floor", (2 * SW, depth), (0, (BW + FW) / 2, 0), (0, 0, 0), (0.13, 0.08, 0.045))
    L.plane("ceiling", (2 * SW, depth), (0, (BW + FW) / 2, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    # Back wall around the door opening.
    left = DOOR_X + SW
    right = SW - (DOOR_X + DOOR_W)
    L.box("wall_back_l", (left, 0.3, CEIL), (-SW + left / 2, BW + 0.15, CEIL / 2), PLASTER)
    L.box("wall_back_r", (right, 0.3, CEIL), (SW - right / 2, BW + 0.15, CEIL / 2), PLASTER)
    L.box("lintel", (DOOR_W, 0.3, CEIL - DOOR_H), (DOOR_X + DOOR_W / 2, BW + 0.15, (CEIL + DOOR_H) / 2), PLASTER)
    L.box("wainscot_back", (left, 0.06, 0.9), (-SW + left / 2, BW - 0.03, 0.45), WOOD)
    for x in (DOOR_X - 0.1, DOOR_X + DOOR_W + 0.1):
        L.box("doorpost", (0.2, 0.36, DOOR_H + 0.1), (x, BW - 0.02, (DOOR_H + 0.1) / 2), WOOD_DARK)
    L.box("door_head", (DOOR_W + 0.4, 0.36, 0.2), (DOOR_X + DOOR_W / 2, BW - 0.02, DOOR_H + 0.1), WOOD_DARK)
    # Side walls. The damp-loss card puts the window wall model on the left, so its plain wall moves out
    # behind it and only closes the room.
    lx = -SW - (0.75 if variant == 'illus.fa.any.damp_loss' else 0.15)
    L.box("wall_left", (0.3, depth, CEIL), (lx, (BW + FW) / 2, CEIL / 2), PLASTER)
    L.box("wall_right", (0.3, depth, CEIL), (SW + 0.15, (BW + FW) / 2, CEIL / 2), PLASTER)
    for y in (-1.0, 1.4):
        L.box("beam", (2 * SW, 0.26, 0.26), (0, y, CEIL - 0.13), WOOD_DARK)
    L.box("post", (0.26, 0.26, CEIL), (-SW + 0.13, BW - 0.13, CEIL / 2), WOOD_DARK)


def _window():
    # Left wall from the registered wall models (4 x 4, 0.5 thick): a closed lattice window by the shelf.
    for y, k in ((-0.6, "wall.gltf"), (2.2, "wall_window_closed.gltf")):
        w = L.load(L.RESTAURANT, k, (-SW - 0.25, y, 0), math.pi / 2, 0.9, tag="wall")
        L.tone(w, sat=0.25, val=0.6)


def _door(variant):
    swing = -1.25 if variant in OPEN else 0.0
    d = L.load(L.RESTAURANT, "door_A.gltf", (DOOR_X, BW, 0), swing, 1.0, tag="door")
    L.recolor(d, (0.24, 0.13, 0.06))
    if variant in OPEN:
        rgb, strength = ((0.10, 0.14, 0.30), 0.9) if variant in NIGHT else ((0.85, 0.55, 0.30), 1.2)
        L.emit_plane("yard", (6, 5), (DOOR_X + DOOR_W / 2, BW + 2.5, 2.0), (math.radians(90), 0, 0), rgb, strength)


def _shelves(variant):
    # Two tall shelves on the back wall left of the door, one on the left wall.
    for x in (-2.35, -0.45):
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (x, BW - 0.35, 0), 0.0, 1.3, tag="shelf"),
               sat=0.3, val=0.5)
    if variant != 'illus.fa.any.damp_loss':
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (-SW + 0.35, 0.6, 0), -math.pi / 2, 1.3, tag="shelf"),
               sat=0.3, val=0.5)
        for z in (1.05, 2.05):
            for i, k in enumerate(("jar_B_large", "jar_D_large", "jar_C_large")):
                L.tone(L.load(L.RESTAURANT, k + ".gltf", (-SW + 0.45, 0.0 + i * 0.5, z), 0.0, 0.8, tag="jar"),
                       sat=0.35, val=0.85)
    y = BW - 0.45
    for z in (1.05, 2.05):
        if variant in GAP and z == 1.05:
            # One bay left empty: the goods that were taken.
            L.jars_on(-3.2, -1.9, y, z, int(z * 7))
            L.jars_on(-0.6, 0.3, y, z, int(z * 7) + 3)
        else:
            L.jars_on(-3.2, 0.3, y, z, int(z * 7) + (1 if variant in NIGHT else 0))


def _crate(loc, rot, scale, lid=True):
    L.recolor(L.load(L.RESTAURANT, "crate.gltf", loc, rot, scale, tag="crate"), CRATE)
    if lid:
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (loc[0], loc[1], loc[2] + 0.8 * scale), rot, scale,
                         tag="crate"), CRATE_LID)


def _bundle(loc, rot, scale=0.6):
    b = L.load(L.FURNITURE, "book_set.gltf", loc, rot, scale, tag="bundle")
    L.tone(b, sat=0.25, val=0.75)
    L.noline(b)


def _stool():
    s = L.load(L.FURNITURE, "chair_stool_wood.gltf", (LAMP_STOOL[0], LAMP_STOOL[1], 0), 0.4, 1.0, tag="stool")
    L.recolor(s, (0.26, 0.14, 0.06))


def _props(variant):
    if variant == 'illus.bf.1939.rice_hoard':
        # Stacked crates in the right half (the rice sacks and straw mat are missing models).
        for x, y, z, r in ((1.0, 1.4, 0, 0.1), (1.85, 1.5, 0, -0.08), (1.4, 1.45, 0.8, 0.05), (0.4, 0.9, 0, 0.3)):
            _crate((x, y, z), r, 1.0, lid=(z > 0 or x < 0.5))
    elif variant == 'illus.es.storeroom':
        _crate((2.2, 1.6, 0), 0.15, 1.0)
        _crate((2.7, 0.6, 0), -0.2, 1.0, lid=False)
        _crate((2.4, 1.5, 0.8), 0.25, 0.8)
    elif variant == 'illus.nt.tidy':
        _stool()
        _bundle((-2.2, BW - 0.45, 0.35), 0.0)
    elif variant == 'illus.ev.1940.shop_search':
        # Goods pulled off the shelf onto the floor.
        _crate((0.6, 1.2, 0), 0.7, 0.8, lid=False)
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (1.3, 0.7, 0), 1.9, 0.8, tag="crate"), CRATE_LID)
        for x, y, r in ((-0.6, 1.0, 0.4), (-1.3, 0.5, 2.1), (0.1, 0.3, -0.8)):
            _bundle((x, y, 0), r)
        L.tone(L.load(L.RESTAURANT, "jar_C_medium.gltf", (-0.2, 1.6, 0), 0.0, 0.9, tag="jar"), sat=0.35, val=0.9)
    elif variant == 'illus.fa.any.damp_loss':
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (-SW + 0.6, 0.0, 0), -math.pi / 2, 1.3, tag="shelf"),
               sat=0.3, val=0.5)
        for z in (1.05, 2.05):
            for i in range(3):
                _bundle((-SW + 0.7, -0.5 + i * 0.5, z + 0.05), math.pi / 2)
        _crate((-2.3, 1.6, 0), 0.2, 1.0)
    elif variant == 'illus.fa.any.requisition':
        _crate((2.8, 0.8, 0), -0.15, 0.9)
    elif variant == 'illus.fa.any.theft':
        _crate((-1.5, 1.4, 0), 0.25, 0.8, lid=False)
    elif variant == 'illus.gl.1938.storeroom':
        _crate((-0.4, 2.3, 0), 0.0, 0.9)
        _crate((-1.2, 2.4, 0), -0.1, 0.9, lid=False)
    elif variant == 'illus.kp.mystery_box':
        _stool()
        # The box of unknown origin, alone in the corner near the lamp (cover cloth and rope are missing).
        _crate((-1.8, 1.0, 0), 0.35, 1.1)


# variant: (camera location, look-at point, lens mm). All framed for 64x48.
CAMS = {
    'illus.bf.1939.rice_hoard': ((-0.6, -1.6, 1.1), (1.3, 1.5, 0.8), 30),
    'illus.es.storeroom': ((1.6, -2.7, 1.7), (-0.6, BW, 1.7), 24),
    'illus.nt.tidy': ((-0.6, -0.4, 1.6), (-2.5, BW, 1.1), 28),
    'illus.ev.1940.shop_search': ((1.8, -1.6, 2.4), (-0.8, 1.6, 0.8), 24),
    'illus.fa.any.damp_loss': ((1.6, -1.2, 1.7), (-SW, 0.6, 1.5), 26),
    'illus.fa.any.requisition': ((-2.4, -2.0, 1.5), (0.6, BW, 1.4), 26),
    'illus.fa.any.theft': ((-1.2, -2.4, 1.4), (0.4, BW, 1.3), 24),
    'illus.gl.1938.storeroom': ((1.8, -0.6, 1.5), (DOOR_X + DOOR_W / 2, BW, 1.4), 30),
    'illus.kp.mystery_box': ((0.4, -1.4, 1.5), (-2.0, 1.4, 0.5), 30),
}


def _lights(variant, toon):
    lamp = (LAMP_STOOL[0], LAMP_STOOL[1], 0.9)
    door = (DOOR_X + DOOR_W / 2, BW - 0.4, 2.0)
    if variant in NIGHT:
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        if variant == 'illus.fa.any.theft':
            # Cold moonlight through the open door; no lamp.
            L.light('AREA', door, 180, (0.45, 0.55, 1.0), rot=(math.radians(-90), 0, 0), size=1.6)
            L.light('AREA', (0, -1.5, 3.2), 25, (0.50, 0.58, 0.90), rot=(math.radians(50), 0, 0), size=4)
        elif variant == 'illus.bf.1939.rice_hoard':
            L.light('POINT', (0.2, 0.6, 1.3), 110, (1.0, 0.62, 0.28), size=0.15)
        else:
            L.light('POINT', lamp, 120, (1.0, 0.62, 0.28), size=0.15)
    elif variant == 'illus.fa.any.damp_loss':
        # Grey rain light through the left window.
        L.world((0.30, 0.33, 0.38), 0.45)
        L.light('AREA', (-SW + 0.4, 1.8, 2.0), 260, (0.70, 0.78, 0.90), rot=(0, math.radians(-90), 0), size=2.0)
        L.light('AREA', (1.5, -1.5, 3.2), 80, (0.80, 0.82, 0.88), rot=(math.radians(45), 0, math.radians(30)),
                size=4)
    elif variant in DUSK:
        L.world((0.40, 0.28, 0.20), 0.45)
        if variant in OPEN:
            L.light('AREA', door, 320, (1.0, 0.60, 0.30), rot=(math.radians(-90), 0, 0), size=1.6)
        L.light('POINT', (2.6, 1.6, 1.8), 60, (1.0, 0.66, 0.30), size=0.15)
        L.light('AREA', (0, -1.5, 3.2), 70, (1.0, 0.80, 0.60), rot=(math.radians(50), 0, 0), size=4)
    else:
        # Day: light from a high window out of shot on the right, and a soft fill from the shop side.
        L.world((0.70, 0.66, 0.60), 0.6)
        L.light('AREA', (SW - 0.4, 0.8, 3.0), 380, (1.0, 0.92, 0.78), rot=(0, math.radians(60), 0), size=2.0)
        L.light('AREA', (0, -2.0, 3.2), 160, (1.0, 0.95, 0.86), rot=(math.radians(55), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room(variant)
    if variant == 'illus.fa.any.damp_loss':
        _window()
    _door(variant)
    _shelves(variant)
    _props(variant)
    loc, look, lens = CAMS[variant]
    L.camera(loc, look, lens)
    _lights(variant, toon)
