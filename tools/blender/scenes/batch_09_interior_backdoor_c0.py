# Back door interior, batch 09: the shop's back room at night, seen towards the plank back door.
# bg.candle (320x180): pitch-dark room, the door shut but for a crack of cold light, one candle glow on a
# small table in the middle. illus.nt.backdoor (64x48): the door half open onto the black lane, a lantern
# glow just outside it.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: candle and candlestick (only its light is here), paper lantern (only its
# light), cloth bundle, the hand / arm passing it in, a plank door with Chinese battens (door_A stands in as
# the door leaf). Until those are registered, illus.nt.backdoor shows only the open door and the lane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST/CITY helpers: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# SIZE is the 320x180 background; illus.nt.backdoor is a 64x48 card, render it with --size 64x48.
# door_A is 1.6 wide and 2.8 high with its origin on the hinge; a negative rot_z swings it into the room.
# Only models from registered KayKit packs are loaded; no images, no props from box/plane, so check_sources()
# has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.candle', 'illus.nt.backdoor',)
IDS = {'bg.candle': 'bg.candle', 'illus.nt.backdoor': 'illus.nt.backdoor'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('bg.candle', 'illus.nt.backdoor')

BW = 3.0        # back wall y (with the door); cameras look towards +y
SW = 3.4        # side walls at x = +-SW
FW = -3.0       # front edge of floor / ceiling
CEIL = 3.4
DOOR_X = -0.8   # hinge of the back door; the leaf spans x DOOR_X..DOOR_X+DOOR_W when shut
DOOR_W = 1.6
DOOR_H = 2.8
LANE = 2.2      # width of the lane behind the door

WOOD_DARK = (0.06, 0.035, 0.02)
WOOD = (0.16, 0.09, 0.045)
PLASTER = (0.34, 0.30, 0.24)
CRATE = (0.28, 0.16, 0.07)
CANDLE = (1.0, 0.58, 0.24)
MOON = (0.40, 0.52, 1.0)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room():
    # Shell only (red line 1): floor, ceiling, walls, wainscot, posts, beams, door frame.
    depth = BW - FW
    L.plane("floor", (2 * SW, depth), (0, (BW + FW) / 2, 0), (0, 0, 0), (0.10, 0.06, 0.035))
    L.plane("ceiling", (2 * SW, depth), (0, (BW + FW) / 2, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    left = DOOR_X + SW
    right = SW - (DOOR_X + DOOR_W)
    L.box("wall_back_l", (left, 0.3, CEIL), (-SW + left / 2, BW + 0.15, CEIL / 2), PLASTER)
    L.box("wall_back_r", (right, 0.3, CEIL), (SW - right / 2, BW + 0.15, CEIL / 2), PLASTER)
    L.box("lintel", (DOOR_W, 0.3, CEIL - DOOR_H), (DOOR_X + DOOR_W / 2, BW + 0.15, (CEIL + DOOR_H) / 2), PLASTER)
    L.box("wainscot_back_l", (left - 0.1, 0.06, 0.9), (-SW + (left - 0.1) / 2, BW - 0.03, 0.45), WOOD)
    L.box("wainscot_back_r", (right - 0.1, 0.06, 0.9), (SW - (right - 0.1) / 2, BW - 0.03, 0.45), WOOD)
    for x in (DOOR_X - 0.1, DOOR_X + DOOR_W + 0.1):
        L.box("doorpost", (0.2, 0.36, DOOR_H + 0.1), (x, BW - 0.02, (DOOR_H + 0.1) / 2), WOOD_DARK)
    L.box("door_head", (DOOR_W + 0.4, 0.36, 0.2), (DOOR_X + DOOR_W / 2, BW - 0.02, DOOR_H + 0.1), WOOD_DARK)
    L.box("threshold", (DOOR_W + 0.4, 0.36, 0.08), (DOOR_X + DOOR_W / 2, BW - 0.02, 0.04), WOOD_DARK)
    L.box("wall_left", (0.3, depth, CEIL), (-SW - 0.15, (BW + FW) / 2, CEIL / 2), PLASTER)
    L.box("wall_right", (0.3, depth, CEIL), (SW + 0.15, (BW + FW) / 2, CEIL / 2), PLASTER)
    for y in (-0.8, 1.6):
        L.box("beam", (2 * SW, 0.26, 0.26), (0, y, CEIL - 0.13), WOOD_DARK)
    for x in (-SW + 0.13, SW - 0.13):
        L.box("post", (0.26, 0.26, CEIL), (x, BW - 0.13, CEIL / 2), WOOD_DARK)


def _lane(variant):
    # Behind the door: lane floor, the opposite house wall, and a self-lit sky plane (shell, red line 1).
    cx = DOOR_X + DOOR_W / 2
    L.plane("lane", (8, LANE + 0.4), (cx, BW + 0.3 + LANE / 2, 0), (0, 0, 0), (0.05, 0.05, 0.06))
    L.box("lane_wall", (8, 0.3, 2.6), (cx, BW + 0.3 + LANE, 1.3), (0.10, 0.10, 0.12))
    if variant == 'bg.candle':
        # Seen only through the crack: one cold, flat glow.
        L.emit_plane("night", (4, 4), (cx, BW + 0.6, 1.6), (math.radians(90), 0, 0), (0.30, 0.40, 0.75), 1.6)
    else:
        L.emit_plane("sky", (10, 4), (cx, BW + 0.3 + LANE + 0.2, 4.4), (math.radians(90), 0, 0),
                     (0.06, 0.08, 0.18), 0.8)


def _door(variant):
    # Shut but for a crack (about 8 cm at the latch side) in bg.candle; half open in illus.nt.backdoor.
    swing = -0.05 if variant == 'bg.candle' else -1.0
    d = L.load(L.RESTAURANT, "door_A.gltf", (DOOR_X, BW, 0), swing, 1.0, tag="door")
    L.recolor(d, (0.20, 0.11, 0.05))


def _props(variant):
    if variant == 'bg.candle':
        # The candle stands on this table (candle itself missing, only its light). Stools barely catch it.
        t = L.load(L.FURNITURE, "table_small.gltf", (0.4, 0.4, 0), 0.2, 1.0, tag="table")
        L.recolor(t, (0.18, 0.10, 0.05))
        for x, y, r in ((-0.5, 0.0, 0.5), (1.2, 0.9, -0.3)):
            L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (x, y, 0), r, 1.0, tag="stool"),
                      (0.20, 0.11, 0.05))
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (2.4, 2.2, 0), 0.15, 1.0, tag="crate"), CRATE)
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (-2.5, 2.3, 0), -0.1, 0.9, tag="crate"), CRATE)
        L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (-1.9, BW - 0.35, 0), 0.0, 1.2, tag="shelf"),
               sat=0.3, val=0.45)
    else:
        # Crates stacked by the door jamb inside; the bundle and the hand are missing models.
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (1.6, BW - 0.6, 0), 0.1, 0.9, tag="crate"), CRATE)
        L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (1.6, BW - 0.6, 0.72), 0.1, 0.9, tag="crate"),
                  (0.34, 0.20, 0.09))


# variant: (camera location, look-at point, lens mm).
CAMS = {
    'bg.candle': ((0.6, -2.6, 1.5), (0.0, BW, 1.2), 24),
    'illus.nt.backdoor': ((0.9, -0.6, 1.4), (DOOR_X + DOOR_W / 2, BW + 0.6, 1.2), 28),
}


def _lights(variant, toon):
    # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
    L.world((0.03, 0.035, 0.07), 0.08 if toon else 0.5)
    if variant == 'bg.candle':
        # Candle flame just above the table top; a faint cold spill through the crack.
        L.light('POINT', (0.4, 0.4, 0.95), 70, CANDLE, size=0.05)
        L.light('AREA', (DOOR_X + DOOR_W, BW + 0.2, 1.4), 25, MOON, rot=(math.radians(90), 0, 0), size=0.3)
    else:
        # Lantern held just outside the doorway (lantern missing, only its light), and cold light down the lane.
        L.light('POINT', (DOOR_X + DOOR_W / 2 + 0.2, BW + 0.55, 1.3), 90, (1.0, 0.55, 0.22), size=0.1)
        L.light('AREA', (DOOR_X + DOOR_W / 2, BW + 1.2, 3.2), 40, MOON, size=2.0)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _lane(variant)
    _door(variant)
    _props(variant)
    loc, look, lens = CAMS[variant]
    L.camera(loc, look, lens)
    _lights(variant, toon)
