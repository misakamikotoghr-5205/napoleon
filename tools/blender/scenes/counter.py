# Pawnshop main counter backdrop (bg.counter.day / dusk / night, 320x180), seen from the clerk's
# side: counter top in the lower third, back wall with an open double door onto a lane.
# Pipeline demo only: this layout was arranged by Claude while looking at the current AI backdrop, so it
# must not ship and is not a composition template (BLENDER_PIPELINE.md section 0). Copy the code
# structure, not the layout.
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ("day", "dusk", "night")
IDS = {"day": "bg.counter.day", "dusk": "bg.counter.dusk", "night": "bg.counter.night"}
COLORS = (24, "mediancut")

BW = 6.0  # back wall y


def ramp(variant):
    if variant == "night":
        return ((0.0, 0.07), (0.03, 0.22), (0.15, 0.55), (0.6, 1.0))
    return ((0.0, 0.20), (0.06, 0.42), (0.25, 0.72), (0.8, 1.0))


def _room():
    wood_dark = (0.10, 0.055, 0.03)
    wood = (0.20, 0.11, 0.05)
    plaster = (0.66, 0.60, 0.47)
    L.plane("floor", (14, 14), (0, 2, 0), (0, 0, 0), (0.16, 0.12, 0.09))
    L.plane("ceiling", (14, 11.4), (0, 0.4, 4.0), (math.radians(180), 0, 0), wood_dark)
    # Back wall with a wide doorway (plain boxes): left, right, lintel, door frame.
    L.box("wall_l", (3.4, 0.3, 4.0), (-3.3, BW, 2.0), plaster)
    L.box("wall_r", (3.4, 0.3, 4.0), (3.3, BW, 2.0), plaster)
    L.box("lintel", (3.2, 0.3, 1.1), (0, BW, 3.45), plaster)
    L.box("doorframe_t", (3.5, 0.36, 0.18), (0, BW - 0.02, 2.9), wood_dark)
    for x in (-1.68, 1.68):
        L.box("doorframe_s", (0.18, 0.36, 2.9), (x, BW - 0.02, 1.45), wood_dark)
    for x, rz in ((-5.0, math.pi / 2), (5.0, -math.pi / 2)):
        L.recolor(L.load(L.RESTAURANT, "wall.gltf", (x, BW - 2.0, 0), rz, 1.0, tag="wall"), plaster)
    for x in (-3.3, 3.3):
        L.box("wainscot", (3.4, 0.05, 1.0), (x, BW - 0.17, 0.5), wood)
    for x in (-5.0, 5.0):
        L.box("post", (0.3, 0.3, 4.0), (x, BW - 0.3, 2.0), wood_dark)
    L.box("beam", (10, 0.35, 0.35), (0, BW - 0.4, 3.82), wood_dark)
    # Two door leaves folded back flat against the wall; red couplet boards on the door posts.
    for x, rz in ((-1.78, math.pi), (1.78, 0.0)):
        L.recolor(L.load(L.RESTAURANT, "door_A.gltf", (x, BW - 0.33, 0), rz, 1.0, tag="door"), (0.16, 0.08, 0.04))
    # DEMO PLACEHOLDER: scripted boxes standing in for couplets. Not allowed in production scenes
    # (red line 1): use a registered human-made model or leave them out.
    for x in (-1.68, 1.68):
        L.box("couplet", (0.26, 0.04, 1.7), (x, BW - 0.22, 1.85), (0.55, 0.06, 0.05))
    # Back wall: cabinet and jar shelf on the left, notice board and jar shelf on the right.
    L.tone(L.load(L.FURNITURE, "cabinet_medium_decorated.gltf", (-3.9, BW - 0.75, 0), 0.0, 1.0, tag="cabinet"),
           sat=0.35, val=0.65)
    for x0, z in ((-4.8, 2.55), (3.1, 2.0)):
        L.tone(L.load(L.FURNITURE, "shelf_A_big.gltf", (x0 + 0.9, BW - 0.27, z), 0.0, 0.95, tag="shelf"), sat=0.3, val=0.55)
        L.jars_on(x0 + 0.15, x0 + 1.6, BW - 0.5, z + 0.1, int(x0 * 7))
    L.tone(L.load(L.FURNITURE, "pictureframe_large_B.gltf", (3.9, BW - 0.27, 3.0), 0.0, 0.9, tag="frame"), sat=0.25, val=0.9)


def _lane():
    # A lane running away from the door with rows of houses on both sides; the sky plane is per variant.
    L.plane("street", (14, 40), (0, BW + 20, 0.01), (0, 0, 0), (0.42, 0.38, 0.33))
    kinds = ("B", "F", "A", "E", "C", "G", "D", "H")
    for side in (-1, 1):
        y, i = BW + 2.6, (0 if side < 0 else 3)
        while y < BW + 34:
            h = L.load(L.CITY, "building_%s_withoutBase.gltf" % kinds[i % len(kinds)], (side * 3.6, y, -0.4),
                       side * math.pi / 2, 3.0, tag="opposite")
            L.tone(h, sat=0.3, val=0.8)
            y += 5.2
            i += 1


def _counter():
    wood = (0.20, 0.11, 0.05)
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        c = L.load(L.RESTAURANT, "kitchencounter_straight_A.gltf", (x, 0.0, 0), 0.0, 1.0, tag="counter")
        L.stretch(c, 1.0, 0.6, 1.2)
        L.recolor(c, wood)
    L.box("countertop", (10.4, 1.5, 0.08), (0, 0.0, 1.24), (0.28, 0.15, 0.07))
    L.tone(L.load(L.FURNITURE, "book_set.gltf", (-0.9, 0.1, 1.40), 0.1, 0.5, tag="book"), sat=0.25, val=0.7)
    L.tone(L.load(L.FURNITURE, "lamp_table.gltf", (-1.85, 0.25, 1.28), 0.0, 0.6, tag="lamp"), sat=0.6, hue=0.48)
    L.tone(L.load(L.FURNITURE, "pictureframe_standing_A.gltf", (1.7, 0.2, 1.28), -0.35, 1.2, tag="pawn"), sat=0.35, val=0.8)


def _sky(rgb, strength):
    L.emit_plane("sky", (40, 30), (0, BW + 36, 8), (math.radians(90), 0, 0), rgb, strength)


def build(variant, toon):
    _room()
    _lane()
    _counter()
    L.camera((0.0, -5.0, 1.75), (0.0, BW, 1.75), 36)
    lamp = (-1.85, 0.25, 1.75)
    if variant == "day":
        L.world((0.80, 0.80, 0.78), 0.9)
        _sky((0.95, 0.93, 0.85), 2.5)
        L.light('SUN', (0, 0, 5), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(35), 0, math.radians(150)))
        L.light('AREA', (0, BW - 0.6, 2.4), 500, (1.0, 0.96, 0.88), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, -3.0, 3.5), 300, (1.0, 0.97, 0.92), rot=(math.radians(60), 0, 0), size=6)
    elif variant == "dusk":
        L.world((0.50, 0.32, 0.22), 0.5)
        _sky((1.0, 0.58, 0.26), 1.5)
        L.light('SUN', (0, 0, 5), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(70), 0, math.radians(180)))
        L.light('AREA', (0, BW - 0.6, 2.4), 350, (1.0, 0.60, 0.30), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('AREA', (0, -3.0, 3.5), 120, (1.0, 0.80, 0.60), rot=(math.radians(60), 0, 0), size=6)
        L.light('POINT', lamp, 25, (1.0, 0.66, 0.30), size=0.2)
    elif variant == "night":
        # Cel shading has no exposure control, so the ambient must be much lower than for Cycles.
        L.world((0.05, 0.06, 0.12), 0.15 if toon else 0.7)
        _sky((0.10, 0.15, 0.36), 1.6)
        for y in (BW + 5, BW + 12, BW + 19, BW + 26):
            L.light('POINT', (-1.2 if y % 2 else 1.2, y, 2.6), 40, (1.0, 0.7, 0.35), size=0.15)
        L.light('AREA', (0, BW - 0.6, 2.4), 150, (0.45, 0.55, 1.0), rot=(math.radians(-90), 0, 0), size=2.5)
        L.light('POINT', lamp, 160, (1.0, 0.62, 0.28), size=0.2)
    else:
        raise ValueError("unknown variant %s" % variant)
