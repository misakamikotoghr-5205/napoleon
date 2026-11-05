# Close-up still lifes, batch 05 part 6 (object:item): twelve item.* pawn-goods pictures (64x64): the xian rice
# sack, broken silver, three silver dollars (Yuan Shikai head, junk, dragon), three pieces of silverware (box,
# cup, spoon) and four household utensils (blue-and-white bowls, mantel clock, pewter teapot, hand warmer).
# Each is a prop on a surface (dark tabletop, counter top, home table) or a sack on the ground against a wall,
# with its own camera pitch / side angle and day or dusk light. One variant per art id.
# Same shell / camera / light scheme as batch_05_object_closeup_c0.py .. _c4.py. The camera fits the image
# width, so the props stay centred.
# Almost none of these props exist in the registered packs (MODELS.csv: KayKit Furniture / Restaurant / City
# Builder), and PROPS_NEEDED.md gives no KayKit stand-in for them (米袋, 碎银, 银元, 银器, 座钟和挂钟, 茶壶, 铜手炉).
# Red line 1 forbids scripting props from boxes and planes, so those MODELS entries stay empty until a human-made
# model is registered; until then those variants render only their shell (allowed by red line 1) with camera and
# light already set. The old cloth under the broken silver is a prop too, so it is not faked with a plane.
# item.utensils.bowl uses the stand-in PROPS_NEEDED.md allows for 青花碗碟: Restaurant bowl as a plain white
# porcelain block, no blue-and-white texture added. It is a placeholder, not the final prop.
# The xian sack must be the same sack model as item.rice.broken / jing / nuo in _c4.py (note column); the three
# silver dollars share one coin blank and differ only in the relief (note column).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file; the bowl scale, framing and light are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 64)
VARIANTS = ('item.rice.xian', 'item.silver.bits', 'item.silver.yuan_a', 'item.silver.yuan_b',
            'item.silver.yuan_c', 'item.silverware.box', 'item.silverware.cup', 'item.silverware.spoon',
            'item.utensils.bowl', 'item.utensils.clock', 'item.utensils.tinpot', 'item.utensils.warmer',)
IDS = {'item.rice.xian': 'item.rice.xian', 'item.silver.bits': 'item.silver.bits',
       'item.silver.yuan_a': 'item.silver.yuan_a', 'item.silver.yuan_b': 'item.silver.yuan_b',
       'item.silver.yuan_c': 'item.silver.yuan_c', 'item.silverware.box': 'item.silverware.box',
       'item.silverware.cup': 'item.silverware.cup', 'item.silverware.spoon': 'item.silverware.spoon',
       'item.utensils.bowl': 'item.utensils.bowl', 'item.utensils.clock': 'item.utensils.clock',
       'item.utensils.tinpot': 'item.utensils.tinpot', 'item.utensils.warmer': 'item.utensils.warmer'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" kinds are a slab whose top face is z = 0 with a wall
# behind; "ground" kinds are a floor plane at z = 0 with a wall close behind the props.
SURFACES = {
    'counter': ('top', (0.16, 0.085, 0.04), (0.05, 0.03, 0.018)),      # shop counter top
    'darkwood': ('top', (0.05, 0.028, 0.015), (0.03, 0.018, 0.01)),    # dark worn tabletop
    'hometable': ('top', (0.13, 0.075, 0.04), (0.42, 0.40, 0.35)),     # home table, whitewashed wall
    'shopwall': ('ground', (0.09, 0.05, 0.028), (0.06, 0.036, 0.02)),  # shop plank floor, dark plank wall
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the props.
# The coins are near top-down so the relief reads; upright things (clock, teapot) are low and frontal.
SPEC = {
    'item.rice.xian': ('shopwall', 'day', 1.1, 0.45, 40, -10, 2.2, 0.55),   # same framing as the _c4 rice
    'item.silver.bits': ('darkwood', 'dusk', 0.25, 0.0, 58, 12, 2.8, 0.0),
    'item.silver.yuan_a': ('darkwood', 'day', 0.09, 0.0, 78, 0, 3.0, 0.0),
    'item.silver.yuan_b': ('darkwood', 'day', 0.09, 0.0, 78, 0, 3.0, 0.0),
    'item.silver.yuan_c': ('darkwood', 'day', 0.09, 0.0, 78, 0, 3.0, 0.0),
    'item.silverware.box': ('counter', 'day', 0.18, 0.02, 54, -14, 2.8, 0.0),
    'item.silverware.cup': ('counter', 'dusk', 0.12, 0.03, 26, 10, 3.0, 0.0),
    'item.silverware.spoon': ('darkwood', 'day', 0.20, 0.0, 62, -8, 2.8, 0.0),
    'item.utensils.bowl': ('hometable', 'day', 0.75, 0.08, 36, 12, 2.4, 0.0),
    'item.utensils.clock': ('hometable', 'dusk', 0.50, 0.20, 10, -12, 2.4, 0.0),
    'item.utensils.tinpot': ('counter', 'day', 0.30, 0.09, 20, 14, 2.6, 0.0),
    'item.utensils.warmer': ('darkwood', 'dusk', 0.26, 0.06, 34, -10, 2.6, 0.0),
}

PORCELAIN = (0.80, 0.79, 0.74)  # plain white bowls (no blue-and-white texture on the stand-ins)

# variant: [(pack constant, model file, (x, y, z), rot_z, scale or (sx, sy, sz), rgb or None), ...] around the
# look point (0, 0). Fill the empty ones once a pack is registered. Dense meshes go in NOLINE.
MODELS = {
    'item.rice.xian': [],          # same open cloth sack as _c4 rice, rim rolled down, long slim whitish grains
    'item.silver.bits': [],        # a few broken silver lumps of different sizes on a worn old cloth
    'item.silver.yuan_a': [],      # one Yuan Shikai dollar, profile head relief, fine reeded edge, dots for text
    'item.silver.yuan_b': [],      # same coin blank, junk (sailing boat) relief
    'item.silver.yuan_c': [],      # same coin blank, coiled dragon relief
    'item.silverware.box': [],     # small silver box, chased flowers and birds on the lid (bump map)
    'item.silverware.cup': [],     # small silver wine cup, chased scrolling flowers round the body
    'item.silverware.spoon': [],   # Chinese silver soup spoon (tiaogeng), fine lines on the handle
    'item.utensils.bowl': [        # a pair of bowls, the upper one nested slightly off-centre
        (L.RESTAURANT, "bowl.gltf", (-0.04, 0.02, 0.0), 0.0, 1.0, PORCELAIN),
        (L.RESTAURANT, "bowl.gltf", (0.07, -0.02, 0.06), math.radians(25), 1.0, PORCELAIN),
    ],
    'item.utensils.clock': [],     # square wooden-case mantel clock, dial with ticks only, no numerals
    'item.utensils.tinpot': [],    # grey-white pewter teapot, short spout, overhead handle
    'item.utensils.warmer': [],    # small round brass hand warmer, pierced flower holes in the lid, bail handle
}
NOLINE = ("book_set.gltf", "book_single.gltf")


def ramp(variant):
    t = SPEC[variant][1]
    if t == "night":
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if t == "dusk":
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _shell(surface, extent, wall_y):
    kind, top_rgb, wall_rgb = SURFACES[surface]
    if kind == 'top':
        L.box("tabletop", (extent * 4, extent * 2.5, 0.08), (0.0, extent * 0.5, -0.04), top_rgb)
        L.plane("backwall", (extent * 6, extent * 3), (0.0, extent * 1.6, extent * 1.2),
                (math.radians(90), 0, 0), wall_rgb)
    else:
        L.plane("ground", (extent * 6, extent * 4), (0.0, extent * 1.0, 0.0), (0, 0, 0), top_rgb)
        L.plane("wall", (extent * 6, extent * 3), (0.0, wall_y, extent * 1.5), (math.radians(90), 0, 0), wall_rgb)


def build(variant, toon=True):
    surface, t, extent, look_z, pitch, yaw, dist_k, wall_d = SPEC[variant]
    wall_y = wall_d * extent + 0.05
    _shell(surface, extent, wall_y)
    for pack, name, loc, rot_z, scale, rgb in MODELS[variant]:
        if isinstance(scale, tuple):
            objs = L.load(pack, name, loc, rot_z, 1.0, tag=variant)
            L.stretch(objs, *scale)
        else:
            objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
        if name in NOLINE:
            L.noline(objs)
    dist = extent * dist_k
    a, b = math.radians(pitch), math.radians(yaw)
    L.camera((dist * math.cos(a) * math.sin(b), -dist * math.cos(a) * math.cos(b), look_z + dist * math.sin(a)),
             (0.0, 0.0, look_z), 36.0 * dist_k)
    r = extent * 1.8
    # Key light from the side opposite the camera yaw, so the side faces the camera sees get shadow.
    # Dusk is a lower, weaker, redder sun.
    side = -1.0 if yaw >= 0 else 1.0
    if t == 'dusk':
        rot = (math.radians(68), 0, math.radians(55 * side))
        warm, sun_w, area_w, sky = (1.0, 0.68, 0.42), 1.9, 80, (0.50, 0.42, 0.40)
    else:
        rot = (math.radians(50), 0, math.radians(40 * side))
        warm = (0.96, 0.92, 0.84) if surface == 'hometable' else (1.0, 0.88, 0.68)
        sun_w, area_w, sky = 2.6, 120, (0.55, 0.50, 0.45)
    if toon:
        L.world(sky, 0.3)
        L.light('SUN', (0, 0, 5), sun_w, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), area_w * extent, warm, rot=rot, size=extent)
