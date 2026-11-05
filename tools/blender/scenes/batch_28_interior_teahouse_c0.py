# NOT YET RENDERED: this session was not allowed to write files, so this module was not saved or run in
# Blender. Framing, light and model scales are unchecked. Render both variants before use.
# Register in scenes/__init__.py, or render.py rejects --scene: add batch_28_interior_teahouse_c0 to the import
# line and the SCENES entry "batch_28_interior_teahouse_c0": batch_28_interior_teahouse_c0.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Teahouse (茶馆), batch 28: one 320x180 backdrop (bg.teahouse) and one 64x48 card illustration
# (illus.nw.rumor). A plank-floored hall under dark beams: the street door open in the back wall on the left
# (an opening in the wall shell, a sky plane and a street house behind it), the counter with the tea-leaf
# jars on the right, square tables with stools in the middle, the blank board high on the back wall.
# bg.teahouse: the whole hall from the front, door to the street on the left, counter on the right.
#   Section 7 lists it as not shipping yet; the board and the tea flag stay blank.
# illus.nw.rumor: close on the corner by the counter, the stove pot on its end and a table with tea bowls,
#   where Zhou Ma leans over to the two tea drinkers.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out. All are already on PROPS_NEEDED.md: red lanterns (纸灯笼; only warm point lights hang where they go),
# long benches (长凳), teapot (茶壶), the tea flag (布幌子), the brick stove (砖砌灶台), the notice on the wall.
# Zhou Ma (周妈) and the tea drinkers are custom characters (PROPS_NEEDED.md, characters), left out too.
# Stand-ins, as listed in PROPS_NEEDED.md: Furniture table_medium for the square tables (方桌),
# Restaurant kitchencounter_straight_B dark wood for the counter (办事长柜台), Restaurant jar_*_large in
# earthen colours for the tea-leaf jars (陶坛罐), Restaurant bowl_small white for the tea bowls (青花碗碟),
# Furniture pictureframe_large_B black for the blank board (空白匾额), Restaurant pot_A for the iron pot of the
# stove. Furniture chair_stool_wood stools stand in the place of the benches; City building_B_withoutBase,
# recoloured, is the house across the street.
# Room shell (floor, walls, door opening, posts, beams, ceiling, street ground, sky) is L.box / L.plane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md sections 1.2 and 1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# No dense meshes (book_set etc.) are loaded, so nothing needs L.noline.
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the card with
# --size 64x48 (SIZES[variant]) and quantise it with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Only models from a registered KayKit pack are loaded and no images, so check_sources() has nothing to reject.
import math

import bpy
import mathutils

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.teahouse', 'illus.nw.rumor',)
IDS = {'bg.teahouse': 'bg.teahouse', 'illus.nw.rumor': 'illus.nw.rumor'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.teahouse',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

DUSK = ()
NIGHT = ()

SW = 4.5        # side walls at x = +-SW
FY = -3.5       # front edge of floor / ceiling, y
BY = 3.0        # back wall y
H = 3.3         # ceiling height
T = 0.25        # wall thickness
DX0, DX1 = -3.6, -2.2   # street door opening in the back wall (x)
DH = 2.4        # door opening height
CX = 2.4        # counter centre x
CY = BY - 1.4   # counter y

PLASTER = (0.55, 0.51, 0.44)
WAINSCOT = (0.12, 0.075, 0.04)
FLOOR = (0.13, 0.085, 0.05)
BEAM = (0.07, 0.04, 0.022)
WOOD = (0.20, 0.11, 0.05)
WOOD_DARK = (0.10, 0.055, 0.03)
LACQUER = (0.03, 0.02, 0.015)
PORCELAIN = (0.80, 0.79, 0.72)
IRON = (0.06, 0.05, 0.045)
STREET = (0.30, 0.28, 0.25)
HOUSE = (0.62, 0.60, 0.55)
SKY = (0.70, 0.72, 0.74)
LANTERN = (1.0, 0.55, 0.30)

TABLES = ((-0.9, 0.6), (1.0, -0.9), (-2.6, -1.4))   # square tables in bg.teahouse (x, y)
RUMOR_TABLE = (1.0, -0.1)                           # the table by the counter in illus.nw.rumor

# Props with these tags start at z=0 and are set onto the table / counter under them by _lift().
SURFACES = ("table", "counter")
ON_TOP = ("teabowl", "pot", "jar")


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _shell():
    # Shell only (red line 1): floor, walls with the door opening, wainscot, posts, beams, ceiling.
    cy = (BY + FY) / 2
    d = BY - FY
    L.plane("floor", (2 * SW + 1, d + 1), (0, cy, 0), (0, 0, 0), FLOOR)
    yb = BY + T / 2
    left = DX0 + SW
    right = SW - DX1
    L.box("back_wall", (left, T, H), (-SW + left / 2, yb, H / 2), PLASTER)
    L.box("back_wall", (right, T, H), (SW - right / 2, yb, H / 2), PLASTER)
    L.box("back_wall", (DX1 - DX0, T, H - DH), ((DX0 + DX1) / 2, yb, (H + DH) / 2), PLASTER)
    L.box("wainscot", (right, 0.05, 0.9), (SW - right / 2, BY - 0.02, 0.45), WAINSCOT)
    L.box("wainscot", (left, 0.05, 0.9), (-SW + left / 2, BY - 0.02, 0.45), WAINSCOT)
    for x in (DX0 - 0.08, DX1 + 0.08):
        L.box("door_post", (0.16, T + 0.1, DH), (x, yb, DH / 2), BEAM)
    L.box("door_lintel", (DX1 - DX0 + 0.32, T + 0.1, 0.16), ((DX0 + DX1) / 2, yb, DH + 0.08), BEAM)
    for s in (-1, 1):
        L.box("side_wall", (T, d + 1, H), (s * (SW + T / 2), cy, H / 2), PLASTER)
        L.box("side_wainscot", (0.05, d + 1, 0.9), (s * (SW - 0.02), cy, 0.45), WAINSCOT)
        for y in (BY - 0.15, 0.0, FY + 0.6):
            L.box("post", (0.22, 0.22, H), (s * (SW - 0.12), y, H / 2), BEAM)
    L.box("ceiling", (2 * SW + 2 * T, d + 1, 0.12), (0, cy, H + 0.06), WOOD_DARK)
    for y in (BY - 0.15, 0.0, FY + 0.6):
        L.box("beam", (2 * SW, 0.24, 0.28), (0, y, H - 0.14), BEAM)
    # Outside the door: street ground and the sky.
    L.plane("street", (8, 6), ((DX0 + DX1) / 2, BY + 3.0, -0.02), (0, 0, 0), STREET)
    L.emit_plane("sky", (14, 8), (-1.0, BY + 9.0, 3.5), (math.radians(90), 0, 0), SKY, 1.1)


def _street_house():
    h = L.load(L.CITY, "building_B_withoutBase.gltf", ((DX0 + DX1) / 2, BY + 4.2, 0.0), math.pi, 1.6,
               tag="house")
    L.recolor(h, HOUSE)


def _table(x, y, rot, bowls):
    L.recolor(L.load(L.FURNITURE, "table_medium.gltf", (x, y, 0.0), rot, 0.75, tag="table"), WOOD)
    for dx, dy, r in ((-0.85, 0.0, math.pi / 2), (0.85, 0.0, -math.pi / 2), (0.0, 0.85, math.pi)):
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (x + dx, y + dy, 0.0), r, 0.9, tag="stool"),
                  WOOD_DARK)
    for dx, dy in bowls:
        L.recolor(L.load(L.RESTAURANT, "bowl_small.gltf", (x + dx, y + dy, 0.0), 0.0, 1.2, tag="teabowl"),
                  PORCELAIN)


def _counter():
    for dx in (-1.0, 1.0):
        L.recolor(L.load(L.RESTAURANT, "kitchencounter_straight_B.gltf", (CX + dx, CY, 0.0), math.pi, 1.0,
                         tag="counter"), WOOD_DARK)
    for k, dx in (("jar_A_large", -1.0), ("jar_C_large", -0.5)):
        L.tone(L.load(L.RESTAURANT, k + ".gltf", (CX + dx, CY + 0.1, 0.0), 0.0, 0.7, tag="jar"), sat=0.3, val=0.6)
    for dx in (0.2, 0.5):
        L.recolor(L.load(L.RESTAURANT, "bowl_small.gltf", (CX + dx, CY - 0.1, 0.0), 0.0, 1.2, tag="teabowl"),
                  PORCELAIN)
    # Tea-leaf jars on the shelf behind the counter.
    L.tone(L.load(L.FURNITURE, "shelf_B_large.gltf", (CX, BY - 0.35, 0.0), 0.0, 1.2, tag="shelf"),
           sat=0.3, val=0.5)
    kinds = ("jar_A_medium", "jar_B_medium", "jar_C_medium", "jar_D_medium")
    for j, z in enumerate((1.02, 1.82)):
        for i, dx in enumerate((-0.6, 0.0, 0.6)):
            k = kinds[(i + 2 * j) % len(kinds)]
            L.tone(L.load(L.RESTAURANT, k + ".gltf", (CX + dx, BY - 0.45, z), 0.0, 0.75, tag="tea_jar"),
                   sat=0.3, val=0.65)


def _stove_pot():
    # Only the iron pot of the brick stove (the stove itself is missing), on the near end of the counter.
    L.recolor(L.load(L.RESTAURANT, "pot_A.gltf", (CX + 1.5, CY - 0.05, 0.0), 0.0, 1.0, tag="pot"), IRON)


def _board():
    b = L.load(L.FURNITURE, "pictureframe_large_B.gltf", (0.4, BY - 0.05, 2.35), 0.0, 1.3, tag="board")
    L.recolor(b, LACQUER)


def _lift():
    # Surface heights are unchecked until rendered, so props tagged ON_TOP are set onto the top of the
    # table / counter mesh under them, using its world bounding box.
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


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # From the front of the hall, eye height: street door left, tables middle, counter right, board above.
    'bg.teahouse': ((0.0, FY - 0.3, 1.7), (-0.2, BY, 1.35), 20),
    # Close on the corner by the counter: the table with tea bowls in front, the counter and pot behind it.
    'illus.nw.rumor': ((-1.2, -2.4, 1.6), (1.6, 0.9, 0.8), 28),
}


def _lights(variant, toon):
    # Daylight: warm-grey ambient, daylight in through the street door, a broad fill from the front of the
    # hall, warm points where the red lanterns will hang under the beams.
    L.world((0.58, 0.55, 0.50), 0.45 if toon else 0.35)
    L.light('AREA', ((DX0 + DX1) / 2, BY - 0.3, 2.0), 120 if toon else 180, (0.95, 0.96, 1.0),
            rot=(math.radians(-60), 0, 0), size=1.4)
    L.light('AREA', (0.0, FY - 0.5, 2.8), 140 if toon else 90, (1.0, 0.95, 0.88), rot=(math.radians(60), 0, 0),
            size=5.0)
    lanterns = ((-1.4, 0.0), (1.6, 0.0)) if variant == 'bg.teahouse' else ((1.6, 0.0),)
    for x, y in lanterns:
        L.light('POINT', (x, y, H - 0.6), 25 if toon else 40, LANTERN, size=0.2)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _shell()
    _counter()
    _stove_pot()
    if variant == 'bg.teahouse':
        _street_house()
        _board()
        _table(TABLES[0][0], TABLES[0][1], 0.0, ((-0.2, -0.1), (0.25, 0.1)))
        _table(TABLES[1][0], TABLES[1][1], 0.15, ((0.0, 0.0),))
        _table(TABLES[2][0], TABLES[2][1], -0.1, ((0.2, -0.15), (-0.2, 0.15), (0.1, 0.25)))
    else:
        _table(RUMOR_TABLE[0], RUMOR_TABLE[1], 0.1, ((-0.25, 0.0), (0.2, 0.15)))
    _lift()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
