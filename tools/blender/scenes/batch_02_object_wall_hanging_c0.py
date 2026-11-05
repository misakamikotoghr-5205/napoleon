# Wall-hanging props, batch 02 (I-205): the door flag on its bamboo pole by the door (blue, plus the red and
# white signal versions) and the blank wooden sign hung by a cord above the door's right side. Seen straight
# from the front at eye level against the shop's plank front, light from the upper left. One variant per art id.
# No registered pack (MODELS.csv: KayKit Furniture / Restaurant / City Builder) has either prop; both are on
# PROPS_NEEDED.md (竹竿门旗, 空白木招牌). Red line 1 forbids scripting props from boxes and planes, and a KayKit
# picture frame is not a sign, so every MODELS entry stays empty until a human-made model is registered; until
# then each variant renders only the wall and eave beam (shell, allowed by red line 1) with its own camera.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# SIZE is the door flag size and render.py only reads SIZE, so render prop.sign with --size 26x34
# (SIZES[variant]), or teach render.py to use SIZES.
# prop.door_flag / _red / _white share models, camera and lights; only the cloth colour differs (pixel-aligned).
# NOT YET RENDERED: writing this file and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (12, 40)
VARIANTS = ('prop.door_flag', 'prop.door_flag_red', 'prop.door_flag_white', 'prop.sign',)
IDS = {'prop.door_flag': 'prop.door_flag', 'prop.door_flag_red': 'prop.door_flag_red',
       'prop.door_flag_white': 'prop.door_flag_white', 'prop.sign': 'prop.sign'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

FLAGS = ('prop.door_flag', 'prop.door_flag_red', 'prop.door_flag_white')

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height above the
# floor). 1 unit ~ 0.75 m: flag cloth 0.25x1 m on a ~1.6 m pole (2.1 units), sign 0.4x1.2 m hung by cord.
SPEC = {
    'prop.door_flag': ((12, 40), 2.3, 2.6),
    'prop.door_flag_red': ((12, 40), 2.3, 2.6),
    'prop.door_flag_white': ((12, 40), 2.3, 2.6),
    'prop.sign': ((26, 34), 1.9, 3.1),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

# Cloth colour per flag variant (linear), applied with L.recolor(objs, rgb, names=FLAG_CLOTH) to the cloth
# meshes only, so the bamboo pole keeps its own colour and the three renders stay pixel-aligned.
FLAG_RGB = {
    'prop.door_flag': (0.05, 0.10, 0.28),        # indigo cotton
    'prop.door_flag_red': (0.42, 0.05, 0.04),
    'prop.door_flag_white': (0.62, 0.60, 0.54),  # unbleached, not paper white
}
FLAG_CLOTH = ("cloth", "flag")  # mesh-name parts of the cloth; fix once the model is in

# key: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None), ...]
# Fill in once a pack is registered, e.g. 'door_flag': [(L.FLAG_PACK, "door_flag.fbx", (0, 0, 0), 0.0, 1.0,
# None)]. Fine bamboo nodes or rope strands that ink solid also need L.noline(objs).
MODELS = {
    'door_flag': [],  # bamboo pole ~1.6 m leaning out from the door post, narrow cloth ~0.25x1 m; all 3 colours
    'sign': [],       # blank wooden signboard ~0.4x1.2 m (portrait), framed, hung from the eave by two cords
}


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if "dusk" in variant:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _models(variant):
    return MODELS['door_flag' if variant in FLAGS else 'sign']


def build(variant, toon=True):
    (w, h), extent, height = SPEC[variant]
    # Shop front (plank wall) and the eave beam over it: room shell only, sized to the frame.
    L.plane("frontwall", (extent * 4, extent * 3), (0.0, 0.3, height), (math.radians(90), 0, 0),
            (0.06, 0.035, 0.02))
    L.box("eave", (extent * 4, 0.5, 0.18), (0.0, 0.05, height + extent * 0.62), (0.03, 0.018, 0.01))
    for pack, name, loc, rot_z, scale, rgb in _models(variant):
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
        if variant in FLAGS:
            L.recolor(objs, FLAG_RGB[variant], names=FLAG_CLOTH)
    # Straight on, eye level with the prop's centre. Blender's sensor (36 mm) fits the longer image side
    # (height for both sizes), so the lens follows from the distance and the extent wanted along it.
    dist = extent * 2.5
    L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, in front of the wall.
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-40)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-40)), size=extent)
