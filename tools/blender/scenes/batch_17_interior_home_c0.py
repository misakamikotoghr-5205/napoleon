# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Home interior, batch 17: six 64x48 card illustrations set in one plaster-and-timber family room in Qingxi
# (sitting room / bedroom of a town house). The room shell is the same in every variant; furniture, table
# props, camera and light change per variant so the six cards read apart: a guarantee handed across a square
# table (day), a family dinner under the lamp (night), a girl ill in bed (day), a cold spring day by the
# brazier (cold dusk), the New Year table under red lantern light (night), the doctor at the bedside (day).
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: every person (Sun laoye in mandarin jacket and skullcap, the family and
# Ruhua, the sick girl, the quilt-wrapped figure, the old doctor in a long gown), canopy (frame) bed and its
# curtains, quilts, wooden lattice paper window (only its light is here), landscape hanging scroll, stamped
# paper deed, money bag, long benches, oil lamp and red paper lanterns (only their light is here), chopsticks,
# dumplings, fish dish, blank red couplet strips, the doctor's medicine chest.
# Stand-ins that are what they look like: table_medium for the square (eight-immortals) table, table_medium_long
# for the dinner table, chair_stool_wood for stools, chair_A_wood for chairs, bed_single_A for the bed,
# pillow_A for the pillow, book_single for papers, pictureframe_large_A for a framed picture on the back wall,
# bowl / bowl_small / plate / stew_pot for the dishes, pot_large dark-toned for the charcoal brazier,
# crate (small) for a wooden box by the doctor's stool, door_A for the room door.
# Floor, walls, ceiling, wainscot, posts and beams are shell from L.box / L.plane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT, ...).
# Register in scenes/__init__.py (import batch_17_interior_home_c0 + SCENES entry
# "batch_17_interior_home_c0": batch_17_interior_home_c0) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Orientation: furniture fronts face -y at rot_z=0. Cameras look towards +y, the back wall is at y = BW and
# the window wall at x = -SW. Only models from registered KayKit packs are loaded and no images, so
# check_sources() has nothing to reject.
import math

import bpy
import mathutils

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.bf.any.sun_guarantee', 'illus.nt.family_dinner', 'illus.fa.any.illness',
            'illus.lf.1938.spring_chill', 'illus.lf.any.new_year', 'illus.lf.any.see_doctor',)
IDS = {'illus.bf.any.sun_guarantee': 'illus.bf.any.sun_guarantee', 'illus.nt.family_dinner': 'illus.nt.family_dinner',
       'illus.fa.any.illness': 'illus.fa.any.illness', 'illus.lf.1938.spring_chill': 'illus.lf.1938.spring_chill',
       'illus.lf.any.new_year': 'illus.lf.any.new_year', 'illus.lf.any.see_doctor': 'illus.lf.any.see_doctor'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.nt.family_dinner', 'illus.lf.any.new_year')
DUSK = ('illus.lf.1938.spring_chill',)

BW = 2.5        # back wall y
FW = -4.0       # front edge of floor / ceiling, y
SW = 3.5        # side walls at x = +-SW
CEIL = 3.2
WIN = (-SW + 0.2, 0.6, 1.7)     # where the lattice window would be (its light only)

WOOD_DARK = (0.07, 0.04, 0.022)
WOOD = (0.20, 0.11, 0.05)
TABLE = (0.17, 0.085, 0.04)
PLASTER = (0.60, 0.56, 0.48)
FLOOR = (0.12, 0.075, 0.042)
BED = (0.22, 0.10, 0.045)
CLOTH = (0.30, 0.30, 0.36)
PORCELAIN = (0.78, 0.76, 0.68)
MEDICINE = (0.10, 0.06, 0.03)
IRON = (0.06, 0.05, 0.045)

# Props with these tags start at z=0 and are set onto the table / stool under them by _lift().
SURFACES = ("table", "stool")
ON_TOP = ("dish", "paper", "medicine")


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
    L.box("wainscot_back", (2 * SW, 0.05, 0.8), (0, BW - 0.025, 0.4), WOOD)
    for s in (-1, 1):
        L.box("wall_side", (0.3, depth, CEIL), (s * (SW + 0.15), cy, CEIL / 2), PLASTER)
        L.box("wainscot_side", (0.05, depth, 0.8), (s * (SW - 0.025), cy, 0.4), WOOD)
        L.box("post", (0.24, 0.24, CEIL), (s * (SW - 0.12), BW - 0.12, CEIL / 2), WOOD_DARK)
    for y in (-1.8, 0.4, 2.2):
        L.box("beam", (2 * SW, 0.24, 0.24), (0, y, CEIL - 0.12), WOOD_DARK)


def _m(pack, name, loc, rot=0.0, scale=1.0, rgb=None, tag="", line=True, sat=None, val=1.0):
    objs = L.load(pack, name, loc, rot, scale, tag=tag)
    if rgb is not None:
        L.recolor(objs, rgb)
    elif sat is not None:
        L.tone(objs, sat=sat, val=val)
    if not line:
        L.noline(objs)
    return objs


def _table(name, loc, rot=0.0, rgb=TABLE):
    return _m(L.FURNITURE, name, loc, rot, 1.0, rgb, tag="table")


def _stool(loc, rot=0.0):
    return _m(L.FURNITURE, "chair_stool_wood.gltf", loc, rot, 1.0, WOOD, tag="stool")


def _chair(loc, rot=0.0):
    return _m(L.FURNITURE, "chair_A_wood.gltf", loc, rot, 1.0, WOOD, tag="chair")


def _paper(loc, rot, scale=0.8, val=0.95):
    return _m(L.FURNITURE, "book_single.gltf", loc, rot, scale, tag="paper", line=False, sat=0.15, val=val)


def _dish(name, loc, rot=0.0, scale=1.0, rgb=PORCELAIN):
    return _m(L.RESTAURANT, name, loc, rot, scale, rgb, tag="dish")


def _bed(x, rot=0.0):
    # Single bed with its head against the back wall, a pillow on it (pillow height unchecked).
    _m(L.FURNITURE, "bed_single_A.gltf", (x, BW - 1.1, 0), rot, 1.0, BED, tag="bed")
    _m(L.FURNITURE, "pillow_A.gltf", (x, BW - 0.45, 0.5), rot, 1.0, CLOTH, tag="pillow")


def _picture(x, z=1.7):
    _m(L.FURNITURE, "pictureframe_large_A.gltf", (x, BW - 0.05, z), 0.0, 1.0, tag="picture", sat=0.35, val=0.8)


def _cabinet(x):
    _m(L.FURNITURE, "cabinet_small.gltf", (x, BW - 0.4, 0), 0.0, 1.0, WOOD_DARK, tag="cabinet")


def _props(variant):
    if variant == 'illus.bf.any.sun_guarantee':
        # Square table in the front room: the host's chair behind it, the visitor's stool in front,
        # papers laid across the table, a framed picture on the back wall.
        _table("table_medium.gltf", (0.0, 0.4, 0))
        _chair((0.0, 1.2, 0), math.pi)
        _stool((0.25, -0.45, 0), 0.2)
        _paper((0.05, 0.3, 0.0), 0.25, 0.9, 0.95)
        _paper((-0.35, 0.5, 0.0), -0.2, 0.7, 0.75)
        _picture(0.0)
        _cabinet(-2.4)
    elif variant == 'illus.nt.family_dinner':
        # Long table under the lamp, stools both sides, bowls round a shared pot and two plates.
        _table("table_medium_long.gltf", (0.0, 0.5, 0))
        for x in (-0.7, 0.7):
            _stool((x, -0.25, 0), 0.0)
            _stool((x, 1.25, 0), math.pi)
        _dish("stew_pot.gltf", (0.0, 0.5, 0.0), 0.0, 0.8, IRON)
        for loc in ((-0.65, 0.2, 0.0), (0.65, 0.2, 0.0), (-0.65, 0.8, 0.0), (0.65, 0.8, 0.0)):
            _dish("bowl_small.gltf", loc)
        _dish("plate.gltf", (-0.35, 0.55, 0.0), 0.0, 0.8)
        _dish("plate.gltf", (0.4, 0.45, 0.0), 0.0, 0.8)
        _cabinet(2.3)
    elif variant == 'illus.fa.any.illness':
        # Bed against the back wall by the window, stool at the bedside with a dark medicine bowl.
        _bed(-1.6)
        _stool((-0.7, BW - 1.4, 0), 0.3)
        _m(L.RESTAURANT, "bowl_small.gltf", (-0.7, BW - 1.4, 0.0), 0.0, 1.0, MEDICINE, tag="medicine")
    elif variant == 'illus.lf.1938.spring_chill':
        # Cold room: an iron brazier on the floor, an empty chair drawn up to it, the window wall beside.
        _m(L.RESTAURANT, "pot_large.gltf", (-0.6, 0.3, 0), 0.0, 1.0, IRON, tag="brazier")
        _chair((-0.2, 1.0, 0), math.pi + 0.5)
        _stool((-1.4, -0.2, 0), 0.4)
        _cabinet(1.6)
    elif variant == 'illus.lf.any.new_year':
        # Square table set for the New Year meal, stools round it, the door on the right wall (couplets missing).
        _table("table_medium.gltf", (0.0, 0.4, 0))
        for loc, rot in (((0.0, -0.4, 0), 0.0), ((0.0, 1.2, 0), math.pi), ((-0.8, 0.4, 0), math.pi / 2),
                         ((0.8, 0.4, 0), -math.pi / 2)):
            _stool(loc, rot)
        _dish("plate.gltf", (-0.2, 0.35, 0.0), 0.0, 0.9)
        _dish("plate.gltf", (0.25, 0.5, 0.0), 0.0, 0.75)
        _dish("bowl.gltf", (0.2, 0.15, 0.0), 0.0, 0.8)
        _dish("bowl_small.gltf", (-0.3, 0.7, 0.0))
        _picture(-1.6)
        _m(L.RESTAURANT, "door_A.gltf", (SW - 0.05, 0.4, 0), -math.pi / 2, 1.0, WOOD, tag="door")
    elif variant == 'illus.lf.any.see_doctor':
        # Bed against the back wall, the doctor's stool and a wooden box beside it, a chair by the foot.
        _bed(0.6)
        _stool((-0.4, BW - 1.3, 0), -0.2)
        _m(L.RESTAURANT, "crate.gltf", (-0.9, BW - 1.9, 0), 0.3, 0.35, (0.30, 0.17, 0.08), tag="box")
        _chair((1.9, 0.0, 0), math.pi * 0.85)
        _cabinet(-2.4)


def _lift():
    # Surface heights are unchecked until rendered, so props tagged ON_TOP are set onto the top of the
    # table / stool mesh under them, using its world bounding box.
    bpy.context.view_layer.update()
    tops = [o for o in bpy.data.objects if o.type == 'MESH' and o.get("tag") in SURFACES]
    for o in bpy.data.objects:
        if o.parent is not None or o.get("tag") not in ON_TOP:
            continue
        top = None
        for d in tops:
            pts = [d.matrix_world @ mathutils.Vector(c) for c in d.bound_box]
            if (min(p.x for p in pts) <= o.location.x <= max(p.x for p in pts)
                    and min(p.y for p in pts) <= o.location.y <= max(p.y for p in pts)):
                z = max(p.z for p in pts)
                top = z if top is None else max(top, z)
        if top is not None:
            o.location.z = top


# variant: (camera location, look-at point, lens mm). Framed for 4:3.
CAMS = {
    'illus.bf.any.sun_guarantee': ((0.9, -2.2, 1.6), (0.0, 0.6, 0.8), 30),
    'illus.nt.family_dinner': ((1.6, -2.0, 2.1), (0.0, 0.5, 0.6), 28),
    'illus.fa.any.illness': ((0.6, -1.2, 1.7), (-1.5, BW - 1.2, 0.5), 28),
    'illus.lf.1938.spring_chill': ((1.2, -2.2, 1.3), (-0.8, 0.6, 0.6), 28),
    'illus.lf.any.new_year': ((-1.2, -2.2, 1.7), (0.3, 0.5, 0.8), 28),
    'illus.lf.any.see_doctor': ((-1.4, -1.4, 1.6), (0.3, BW - 1.3, 0.5), 28),
}


def _lights(variant, toon):
    if variant == 'illus.nt.family_dinner':
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        # Oil lamp over the table (light only, lamp missing).
        L.light('POINT', (0.1, 0.5, 1.7), 140, (1.0, 0.62, 0.28), size=0.12)
        L.light('AREA', (-1.5, -1.5, 2.8), 12, (0.50, 0.58, 0.90), rot=(math.radians(50), 0, math.radians(-30)),
                size=4)
    elif variant == 'illus.lf.any.new_year':
        L.world((0.08, 0.05, 0.08), 0.15 if toon else 0.7)
        # Red paper lanterns (light only, lanterns missing): one over the table, one by the door.
        L.light('POINT', (0.0, 0.4, 2.0), 150, (1.0, 0.30, 0.15), size=0.2)
        L.light('POINT', (SW - 0.6, -0.4, 2.1), 70, (1.0, 0.25, 0.12), size=0.2)
        L.light('POINT', (-0.6, -0.6, 1.4), 40, (1.0, 0.70, 0.40), size=0.1)
    elif variant in DUSK:
        # Cold blue-grey from the frosted window, warm glow rising from the brazier.
        L.world((0.30, 0.34, 0.42), 0.35 if toon else 0.5)
        L.light('AREA', WIN, 160, (0.70, 0.80, 1.0), rot=(0, math.radians(-75), 0), size=1.6)
        L.light('POINT', (-0.6, 0.3, 0.75), 60, (1.0, 0.45, 0.18), size=0.15)
    else:
        L.world((0.70, 0.66, 0.60), 0.6 if toon else 0.5)
        # Daylight through the left window plus a soft fill from the open front.
        L.light('AREA', WIN, 240, (1.0, 0.95, 0.86), rot=(0, math.radians(-70), 0), size=2.0)
        L.light('SUN', (0, 0, 6), 2.0, (1.0, 0.92, 0.80), rot=(math.radians(45), 0, math.radians(-30)))
        L.light('AREA', (0, -3.0, 2.8), 100, (1.0, 0.97, 0.92), rot=(math.radians(55), 0, 0), size=4)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _room()
    _props(variant)
    _lift()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
