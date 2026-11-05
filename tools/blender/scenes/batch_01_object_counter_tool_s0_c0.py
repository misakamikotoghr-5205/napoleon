# Counter-tool prop (prop.abacus, 52x22): a dark wooden abacus lying flat on the counter top, seen from the
# front and a little above, light from the upper left.
# No registered pack has an abacus (it is on PROPS_NEEDED.md), and red line 1 forbids scripting one from
# boxes, so ABACUS stays None until a human-made model is registered in MODELS.csv; until then this renders
# only the counter-top slab and back wall (shell, allowed by red line 1). Composition is not from the
# creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
import math

import bl_lib as L

SIZE = (52, 22)
VARIANTS = ("prop.abacus",)
IDS = {"prop.abacus": "prop.abacus"}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# (pack constant, model file, scale, dark-wood rgb) once an abacus pack is registered, e.g.
# (L.ABACUS_PACK, "abacus.fbx", 1.0, (0.10, 0.05, 0.025)). Real abacus ~40x15 cm = 0.53x0.2 units.
ABACUS = None


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def build(variant, toon=True):
    # Counter-top slab and the wall behind it: room shell only.
    L.box("countertop", (3.0, 1.6, 0.08), (0.0, 0.3, -0.04), (0.16, 0.085, 0.04))
    L.plane("backwall", (4.0, 2.0), (0.0, 1.1, 0.6), (math.radians(90), 0, 0), (0.05, 0.03, 0.018))
    if ABACUS is not None:
        pack, name, scale, rgb = ABACUS
        L.recolor(L.load(pack, name, (0.0, 0.0, 0.0), 0.0, scale, tag="abacus"), rgb)
    # Front, slightly above, framing ~0.7 x 0.3 units around the abacus (52:22 is about 5:2).
    L.camera((0.0, -1.35, 0.55), (0.0, 0.0, 0.03), 50)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the counter.
        L.light('SUN', (0, 0, 5), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-45)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        L.light('AREA', (-1.2, -1.0, 1.6), 120, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-45)), size=1.0)
