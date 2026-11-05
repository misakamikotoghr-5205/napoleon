# Shopfront interior, batch 10: illus.nt.early_sleep (64x48), the shop shut early for the night, seen from
# inside towards the plank front. Seven planks stand in their channel, the last slot is still open onto the
# dark street and the last plank leans against the wall beside it. One lantern glow by the door.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: Jiangnan door planks (door_A leaves narrowed with L.stretch stand in for
# them, as in batch_06), paper lantern (only its light is here), the wall hook it hangs from.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST/CITY helpers: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import batch_10_interior_shopfront_c0 + SCENES entry
# "batch_10_interior_shopfront_c0": batch_10_interior_shopfront_c0) or render.py rejects --scene.
# door_A is 1.6 wide and 2.8 high with its origin on the hinge, the leaf runs along +x at rot_z=0; narrowed
# to PLANK_W by an x stretch. Cameras look towards +y, the front is at y = FW.
# Only models from registered KayKit packs are loaded; no images, no props from box/plane, so check_sources()
# has nothing to reject.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.nt.early_sleep',)
IDS = {'illus.nt.early_sleep': 'illus.nt.early_sleep'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.nt.early_sleep',)

FW = 3.0        # front wall y (plank opening); cameras look towards +y
BW = -3.0       # back edge of floor / ceiling
SW = 3.4        # side walls at x = +-SW
CEIL = 3.4
OPEN_X = -1.6   # plank opening spans x OPEN_X..OPEN_X + SLOTS * PLANK_W
SLOTS = 8
PLANK_W = 0.4
PLANK_H = 2.8
STREET = 2.4    # depth of the street outside

WOOD_DARK = (0.06, 0.035, 0.02)
WOOD = (0.16, 0.09, 0.045)
PLANK = (0.20, 0.11, 0.05)
PLASTER = (0.34, 0.30, 0.24)
LANTERN = (1.0, 0.58, 0.24)
MOON = (0.40, 0.52, 1.0)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _room():
    # Shell only (red line 1): floor, ceiling, walls, posts, beams, the plank channel above and below.
    depth = FW - BW
    open_w = SLOTS * PLANK_W
    L.plane("floor", (2 * SW, depth), (0, (FW + BW) / 2, 0), (0, 0, 0), (0.10, 0.06, 0.035))
    L.plane("ceiling", (2 * SW, depth), (0, (FW + BW) / 2, CEIL), (math.radians(180), 0, 0), WOOD_DARK)
    left = OPEN_X + SW
    right = SW - (OPEN_X + open_w)
    L.box("wall_front_l", (left, 0.3, CEIL), (-SW + left / 2, FW + 0.15, CEIL / 2), PLASTER)
    L.box("wall_front_r", (right, 0.3, CEIL), (SW - right / 2, FW + 0.15, CEIL / 2), PLASTER)
    L.box("transom", (open_w, 0.3, CEIL - PLANK_H), (OPEN_X + open_w / 2, FW + 0.15, (CEIL + PLANK_H) / 2),
          WOOD)
    for x in (OPEN_X - 0.12, OPEN_X + open_w + 0.12):
        L.box("doorpost", (0.24, 0.4, CEIL), (x, FW, CEIL / 2), WOOD_DARK)
    # Upper and lower channel rails the planks slot into.
    L.box("rail_top", (open_w + 0.48, 0.4, 0.16), (OPEN_X + open_w / 2, FW, PLANK_H + 0.08), WOOD_DARK)
    L.box("rail_sill", (open_w + 0.48, 0.4, 0.1), (OPEN_X + open_w / 2, FW, 0.05), WOOD_DARK)
    L.box("wall_left", (0.3, depth, CEIL), (-SW - 0.15, (FW + BW) / 2, CEIL / 2), PLASTER)
    L.box("wall_right", (0.3, depth, CEIL), (SW + 0.15, (FW + BW) / 2, CEIL / 2), PLASTER)
    for y in (-0.6, 1.8):
        L.box("beam", (2 * SW, 0.26, 0.26), (0, y, CEIL - 0.13), WOOD_DARK)


def _street():
    # Outside the last open slot: street floor, the house across, a self-lit night sky (shell, red line 1).
    cx = OPEN_X + (SLOTS - 0.5) * PLANK_W
    L.plane("street", (8, STREET + 0.4), (cx, FW + 0.3 + STREET / 2, 0), (0, 0, 0), (0.05, 0.05, 0.06))
    L.box("street_wall", (8, 0.3, 2.6), (cx, FW + 0.3 + STREET, 1.3), (0.10, 0.10, 0.12))
    L.emit_plane("sky", (10, 4), (cx, FW + 0.3 + STREET + 0.2, 4.4), (math.radians(90), 0, 0),
                 (0.06, 0.08, 0.18), 0.8)


def _plank(x, y, lean=0.0):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, y, 0.1), 0.0, 1.0, tag="door_plank")
    L.stretch(d, PLANK_W / 1.6, 1.0, 1.0)
    for o in d:
        if o.parent is None:
            # Negative x rotation tips the top towards +y (against the wall).
            o.rotation_euler[0] = lean
    L.recolor(d, PLANK)


def _planks():
    # All but the last slot filled; the last plank leans on the wall right of the opening.
    for i in range(SLOTS - 1):
        _plank(OPEN_X + i * PLANK_W, FW - 0.05)
    _plank(OPEN_X + SLOTS * PLANK_W + 0.45, FW - 0.62, -math.radians(12))


def _props():
    # The shop floor by the front: a stool and a small table pushed aside for the night.
    L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (-2.2, 1.6, 0), 0.4, 1.0, tag="stool"), WOOD)
    L.recolor(L.load(L.FURNITURE, "table_small.gltf", (-2.4, 0.4, 0), 0.1, 1.0, tag="table"),
              (0.18, 0.10, 0.05))


# variant: (camera location, look-at point, lens mm).
CAMS = {
    'illus.nt.early_sleep': ((-0.5, -2.2, 1.45), (0.3, FW, 1.3), 26),
}


def _lights(variant, toon):
    # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
    L.world((0.03, 0.035, 0.07), 0.08 if toon else 0.5)
    # Lantern on its hook by the left doorpost (lantern and hook missing, only the light).
    L.light('POINT', (OPEN_X - 0.5, FW - 0.5, 2.2), 90, LANTERN, size=0.1)
    # Cold street light through the last open slot.
    L.light('AREA', (OPEN_X + (SLOTS - 0.5) * PLANK_W, FW + 1.2, 3.0), 40, MOON, size=1.5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _street()
    _planks()
    _props()
    loc, look, lens = CAMS[variant]
    L.camera(loc, look, lens)
    _lights(variant, toon)
