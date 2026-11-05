# Counter-tool prop (prop.cashbox, 48x26): a small wooden cash box with a brass lock plate sitting on the
# counter top, seen from the front and a little above, light from the upper left.
# No registered pack has a wooden box with a lock plate (it is on PROPS_NEEDED.md, "木匣"; the Furniture
# cabinet_small listed there is a stand-in only), and red line 1 forbids scripting one from boxes, so CASHBOX
# stays None until a human-made model is registered in MODELS.csv; until then this renders only the
# counter-top slab and back wall (shell, allowed by red line 1). Composition is not from the creator's
# sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
import math

import bl_lib as L

SIZE = (48, 26)
VARIANTS = ("prop.cashbox",)
IDS = {"prop.cashbox": "prop.cashbox"}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# (pack constant, model file, scale, dark-wood rgb) once a lockable wooden box pack is registered, e.g.
# (L.BOX_PACK, "cashbox.fbx", 1.0, (0.18, 0.09, 0.04)). Real box ~40x20x15 cm = 0.53x0.27x0.2 units.
CASHBOX = None


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def build(variant, toon=True):
    # Counter-top slab and the wall behind it: room shell only.
    L.box("countertop", (3.0, 1.6, 0.08), (0.0, 0.3, -0.04), (0.16, 0.085, 0.04))
    L.plane("backwall", (4.0, 2.0), (0.0, 1.1, 0.6), (math.radians(90), 0, 0), (0.05, 0.03, 0.018))
    if CASHBOX is not None:
        pack, name, scale, rgb = CASHBOX
        L.recolor(L.load(pack, name, (0.0, 0.0, 0.0), 0.0, scale, tag="cashbox"), rgb)
    # Front, slightly above, framing ~0.75 x 0.4 units around the box (48:26 is about 2:1).
    L.camera((0.0, -1.4, 0.7), (0.0, 0.0, 0.1), 50)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the counter.
        L.light('SUN', (0, 0, 5), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-45)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        L.light('AREA', (-1.2, -1.0, 1.6), 120, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-45)), size=1.0)
