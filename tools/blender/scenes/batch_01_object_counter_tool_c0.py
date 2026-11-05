# Counter-tool props, batch 01 (I-204 / I-287): twelve small props each lying or standing on the counter
# top, seen from the front and a little above, light from the upper left. One variant per art id.
# No registered pack (MODELS.csv: KayKit Furniture / Restaurant / City Builder) has any of these props; they
# are all on PROPS_NEEDED.md (算盘, 蜡烛与铜烛台, 木匣, 铜煤油灯, 线装账簿, 铜框放大镜, 线装书和布面册,
# 布面档案簿, 戥子, 木印章与印泥盒, 电报机和铜电键). Furniture book_single / cabinet_small are listed there as
# stand-ins only, and red line 1 forbids scripting props from boxes, so every MODELS entry stays empty until a
# human-made model is registered; until then each variant renders only the counter-top slab and back wall
# (shell, allowed by red line 1) with its own camera. Composition is not from the creator's sketch yet
# (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# SIZE is the abacus size and render.py only reads SIZE, so render every other variant with
# --size <SIZES[variant]> (e.g. prop.candle: --size 8x16), or teach render.py to use SIZES.
# prop.lamp and prop.lamp_off share models, camera and lights; only the flame differs (pixel-aligned).
import math

import bl_lib as L

SIZE = (52, 22)
VARIANTS = ('prop.abacus', 'prop.candle', 'prop.cashbox', 'prop.lamp', 'prop.lamp_off', 'prop.ledger',
            'prop.magnifier', 'prop.medbook', 'prop.notebook', 'prop.scale', 'prop.stamp', 'prop.telegraph',)
IDS = {'prop.abacus': 'prop.abacus', 'prop.candle': 'prop.candle', 'prop.cashbox': 'prop.cashbox',
       'prop.lamp': 'prop.lamp', 'prop.lamp_off': 'prop.lamp_off', 'prop.ledger': 'prop.ledger',
       'prop.magnifier': 'prop.magnifier', 'prop.medbook': 'prop.medbook', 'prop.notebook': 'prop.notebook',
       'prop.scale': 'prop.scale', 'prop.stamp': 'prop.stamp', 'prop.telegraph': 'prop.telegraph'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop height, camera pitch deg).
# 1 unit ~ 0.75 m (abacus 40 cm = 0.53 units). Flat props get a steeper pitch so the cover reads.
SPEC = {
    'prop.abacus': ((52, 22), 0.70, 0.04, 22),
    'prop.candle': ((8, 16), 0.28, 0.20, 15),
    'prop.cashbox': ((48, 26), 0.72, 0.20, 25),
    'prop.lamp': ((20, 32), 0.62, 0.47, 12),
    'prop.lamp_off': ((20, 32), 0.62, 0.47, 12),
    'prop.ledger': ((40, 26), 0.50, 0.04, 35),
    'prop.magnifier': ((30, 20), 0.36, 0.03, 35),
    'prop.medbook': ((36, 16), 0.42, 0.03, 30),
    'prop.notebook': ((40, 26), 0.50, 0.04, 35),
    'prop.scale': ((40, 20), 0.52, 0.06, 25),
    'prop.stamp': ((24, 24), 0.26, 0.11, 22),
    'prop.telegraph': ((38, 28), 0.56, 0.25, 22),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

# variant: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None, flame height or None), ...]
# Fill in once a pack is registered, e.g. 'prop.abacus': [(L.ABACUS_PACK, "abacus.fbx", (0, 0, 0), 0.0, 1.0,
# (0.10, 0.05, 0.025), None)]. Dense meshes (book pages, abacus beads) also need L.noline(objs).
# The flame (a small self-lit plane, I-204) is placed only together with its model.
MODELS = {
    'prop.abacus': [],     # 13-rod dark-wood abacus ~40x15 cm
    'prop.candle': [],     # short red candle in a brass candlestick ~15 cm
    'prop.cashbox': [],    # wooden box with brass lock plate ~40x20x15 cm
    'prop.lamp': [],       # brass kerosene lamp with glass chimney ~35 cm; shared with prop.lamp_off
    'prop.ledger': [],     # blue cloth thread-bound ledger ~20x28 cm, blank label
    'prop.magnifier': [],  # brass-rim magnifier, ~10 cm lens, short wooden handle
    'prop.medbook': [],    # cloth-bound medicine book with label
    'prop.notebook': [],   # brown cloth hardcover file book tied with cord
    'prop.scale': [],      # silver steelyard: wooden beam ~30 cm, brass pan, weight
    'prop.stamp': [],      # square wooden seal ~8 cm + round ink-paste box
    'prop.telegraph': [],  # telegraph set in a closed wooden case
}
FLAME_ON = ('prop.candle', 'prop.lamp')


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if "dusk" in variant:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _models(variant):
    return MODELS['prop.lamp' if variant == 'prop.lamp_off' else variant]


def build(variant, toon=True):
    (w, h), extent, height, pitch = SPEC[variant]
    # Counter-top slab and the wall behind it: room shell only, sized to the frame.
    L.box("countertop", (extent * 4, extent * 2.5, 0.08), (0.0, extent * 0.5, -0.04), (0.16, 0.085, 0.04))
    L.plane("backwall", (extent * 6, extent * 3), (0.0, extent * 1.6, extent * 1.2),
            (math.radians(90), 0, 0), (0.05, 0.03, 0.018))
    flames = []
    for pack, name, loc, rot_z, scale, rgb, flame_z in _models(variant):
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
        if flame_z is not None:
            flames.append((loc[0], loc[1], loc[2] + flame_z))
    if variant in FLAME_ON:
        for fx, fy, fz in flames:
            L.emit_plane("flame", (0.018, 0.04), (fx, fy - 0.005, fz + 0.02), (math.radians(90), 0, 0),
                         (1.0, 0.62, 0.18), 6.0)
    # Front, slightly above. Blender's sensor (36 mm) fits the longer image side, so the lens follows from
    # the distance and the extent wanted along that side.
    dist = extent * 2.2
    look_z = height * 0.5
    a = math.radians(pitch)
    L.camera((0.0, -dist * math.cos(a), look_z + dist * math.sin(a)), (0.0, 0.0, look_z), 36.0 * dist / extent)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the counter.
        L.light('SUN', (0, 0, 5), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-45)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, r * 1.3), 120 * extent, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-45)), size=extent)
        if variant in FLAME_ON:
            for fx, fy, fz in flames:
                L.light('POINT', (fx, fy - 0.02, fz + 0.03), 2.0, (1.0, 0.62, 0.25), size=0.01)
