# NOT YET RENDERED: this session was not allowed to write files, so this module was not saved or run in
# Blender. Framing, light and the table scale are unchecked. Render both variants before use.
# Register in scenes/__init__.py, or render.py rejects --scene: add batch_27_interior_prison_c0 to the import
# line and the SCENES entry "batch_27_interior_prison_c0": batch_27_interior_prison_c0.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Prison cell (牢房), batch 27: one 320x180 backdrop (bg.prison) and one 64x48 card illustration
# (illus.pr.cell). A small stone-walled cell: a high small window in the back wall (an opening in the wall
# shell with a pale sky plane behind it), a low beam under a plank ceiling, a wooden table on the left.
# bg.prison: the whole cell from the front, table on the left, the window high on the right. Neutral light
#   (the game tints it cold in code, I-285); a warm point where the candle stands on the table.
# illus.pr.cell: close on the back right corner under the window, where the straw mat goes.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out. All are already on PROPS_NEEDED.md: the wooden-bar cell door (木栅牢门), straw mat (草席), the iron bars
# of the high window (高处小铁窗; only the opening in the wall is shell), candle and candlestick (蜡烛与铜烛台).
# The candle flame is only a warm point light where the candlestick will stand.
# Stand-ins: Furniture table_medium, recoloured dark wood, for the wooden table (方桌 lists it as a placeholder).
# Room shell (floor, walls, window opening, beam, ceiling, sky behind the window) is L.box / L.plane.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md sections 1.2 and 1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE, ...).
# No dense meshes (book_set etc.) are loaded, so nothing needs L.noline.
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the card with
# --size 64x48 (SIZES[variant]) and quantise it with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Only models from a registered KayKit pack are loaded and no images, so check_sources() has nothing to reject.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.prison', 'illus.pr.cell',)
IDS = {'bg.prison': 'bg.prison', 'illus.pr.cell': 'illus.pr.cell'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.prison',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

DUSK = ()
NIGHT = ()

HW = 3.0        # half width of the cell (x = -HW..HW)
FY = -1.0       # front of the cell (where the bar door will stand)
BY = 3.0        # back wall
H = 3.4         # wall height
T = 0.3         # wall thickness
WX = 1.4        # window centre x
WW = 0.7        # window width
WZ0, WZ1 = 2.3, 2.9  # window sill and lintel heights

STONE = (0.22, 0.21, 0.19)
STONE_DARK = (0.14, 0.13, 0.12)
FLOOR = (0.16, 0.14, 0.11)
PLANK = (0.12, 0.08, 0.05)
BEAM = (0.10, 0.06, 0.04)
WOOD = (0.20, 0.12, 0.06)
SKY = (0.62, 0.66, 0.70)
CANDLE = (1.0, 0.66, 0.34)

TABLE = (-1.7, 1.6)  # table position (x, y) on the left


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.12), (0.08, 0.42), (0.30, 0.72), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _shell():
    cy = (FY + BY) / 2
    d = BY - FY
    L.plane("floor", (2 * HW + 2, d + 2), (0, cy, 0), (0, 0, 0), FLOOR)
    # Back wall in four pieces around the window opening.
    yb = BY + T / 2
    left = WX - WW / 2 + HW
    right = HW - (WX + WW / 2)
    L.box("back_wall", (left, T, H), (-HW + left / 2, yb, H / 2), STONE)
    L.box("back_wall", (right, T, H), (HW - right / 2, yb, H / 2), STONE)
    L.box("back_wall", (WW, T, WZ0), (WX, yb, WZ0 / 2), STONE)
    L.box("back_wall", (WW, T, H - WZ1), (WX, yb, (H + WZ1) / 2), STONE)
    L.box("window_sill", (WW + 0.16, T + 0.08, 0.08), (WX, yb - 0.02, WZ0 - 0.04), STONE_DARK)
    L.emit_plane("sky", (WW + 1.0, WZ1 - WZ0 + 1.0), (WX, BY + 1.0, (WZ0 + WZ1) / 2), (math.radians(90), 0, 0),
                 SKY, 1.2)
    L.box("wall_skirt", (2 * HW, 0.06, 0.35), (0, BY - 0.03, 0.175), STONE_DARK)
    # Side walls, ceiling and a low beam across the cell.
    for s in (-1, 1):
        L.box("side_wall", (T, d + 1.0, H), (s * (HW + T / 2), cy + 0.5, H / 2), STONE)
        L.box("side_skirt", (0.06, d + 1.0, 0.35), (s * (HW - 0.03), cy + 0.5, 0.175), STONE_DARK)
    L.box("ceiling", (2 * HW + 2 * T, d + 1.0, 0.15), (0, cy + 0.5, H + 0.075), PLANK)
    L.box("beam", (2 * HW, 0.28, 0.3), (0, BY - 1.2, H - 0.15), BEAM)
    # Front wall stubs left and right of the doorway, a lintel over it (the bar door itself is missing).
    for s in (-1, 1):
        L.box("front_wall", (0.8, T, H), (s * (HW - 0.4), FY - T / 2, H / 2), STONE)
    L.box("front_lintel", (2 * HW - 1.6, T, 0.5), (0, FY - T / 2, H - 0.25), STONE)


def _props():
    t = L.load(L.FURNITURE, "table_medium.gltf", (TABLE[0], TABLE[1], 0.0), math.radians(90), 0.75, tag="table")
    L.recolor(t, WOOD)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # From just outside the doorway, slightly high: whole cell, table left, window high on the right.
    'bg.prison': ((0.2, FY - 2.4, 1.7), (0.0, BY, 1.5), 22),
    # Close on the back right corner: window above, empty floor where the straw mat goes.
    'illus.pr.cell': ((-0.4, 0.2, 1.4), (WX + 0.3, BY, 1.4), 26),
}


def _lights(variant, toon):
    # Neutral light: grey ambient, cool daylight falling in through the window, broad fill from the doorway,
    # a warm point where the candle will stand on the table (backdrop only).
    L.world((0.55, 0.55, 0.56), 0.45 if toon else 0.35)
    L.light('AREA', (WX, BY - 0.2, WZ0 + 0.3), 90 if toon else 140, (0.92, 0.95, 1.0),
            rot=(math.radians(-55), 0, 0), size=0.7)
    L.light('AREA', (0.0, FY - 1.5, 2.6), 80 if toon else 60, (0.96, 0.96, 0.96), rot=(math.radians(65), 0, 0),
            size=4.0)
    if variant == 'bg.prison':
        L.light('POINT', (TABLE[0], TABLE[1], 1.0), 20 if toon else 35, CANDLE, size=0.1)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _shell()
    _props()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
