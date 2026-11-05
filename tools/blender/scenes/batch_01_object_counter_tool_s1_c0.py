# Counter-tool prop (prop.candle, 8x16): a short red candle burning in a brass candlestick on the counter
# top, seen from the front and a little above, warm light from the upper left.
# No registered pack has a candle or candlestick (both are on PROPS_NEEDED.md, "蜡烛与铜烛台"), and red
# line 1 forbids scripting them from boxes, so CANDLE stays None until a human-made model is registered in
# MODELS.csv; until then this renders only the counter-top slab and back wall (shell, allowed by red line 1).
# The flame is a small self-lit plane (I-204), placed only together with the candle model. Composition is
# not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
import math

import bl_lib as L

SIZE = (8, 16)
VARIANTS = ("prop.candle",)
IDS = {"prop.candle": "prop.candle"}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# (pack constant, model file, scale, flame height above the counter top) once a candlestick pack is
# registered, e.g. (L.CANDLE_PACK, "candlestick.fbx", 1.0, 0.2). Real candle in candlestick ~15 cm tall
# = about 0.2 units.
CANDLE = None


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def build(variant, toon=True):
    # Counter-top slab and the wall behind it: room shell only.
    L.box("countertop", (1.2, 0.8, 0.08), (0.0, 0.2, -0.04), (0.16, 0.085, 0.04))
    L.plane("backwall", (2.0, 1.0), (0.0, 0.6, 0.4), (math.radians(90), 0, 0), (0.05, 0.03, 0.018))
    if CANDLE is not None:
        pack, name, scale, flame_z = CANDLE
        L.load(pack, name, (0.0, 0.0, 0.0), 0.0, scale, tag="candle")
        # Flame: a small self-lit plane facing the camera at the tip of the wick.
        L.emit_plane("flame", (0.018, 0.04), (0.0, -0.005, flame_z + 0.02), (math.radians(90), 0, 0),
                     (1.0, 0.62, 0.18), 6.0)
    # Front, slightly above, framing ~0.13 x 0.26 units around the candle (8:16 is 1:2).
    L.camera((0.0, -0.75, 0.3), (0.0, 0.0, 0.12), 85)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the counter.
        L.light('SUN', (0, 0, 5), 2.4, (1.0, 0.84, 0.60), rot=(math.radians(50), 0, math.radians(-45)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        L.light('AREA', (-0.6, -0.6, 0.9), 40, (1.0, 0.84, 0.60),
                rot=(math.radians(50), 0, math.radians(-45)), size=0.5)
        if CANDLE is not None:
            L.light('POINT', (0.0, -0.02, CANDLE[3] + 0.03), 2.0, (1.0, 0.62, 0.25), size=0.01)
