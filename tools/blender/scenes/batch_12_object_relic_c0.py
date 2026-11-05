# Relic shelf items, batch 12 (object:relic): twelve 32x32 icons for the old objects shown in the
# curio-shelf (博古架) cells. Each is one object, mostly in a shelf cell (dark rosewood board with a back
# panel), a few on the plank floor against a wall (chest, umbrella) or on the wall (old signboard). The
# small icons use a near-front camera with a slight pitch, each with its own side angle so the set does
# not read as one repeated shot. 胡二's pipe and the forgotten umbrella are lit as dusk; the rest daylight.
# Registered packs (MODELS.csv: KayKit Furniture / Restaurant / City Builder) have none of these relics;
# they are on PROPS_NEEDED.md (蓝布门帘, 樟木箱, 铜药碾, 长烟袋, 戥子, 油纸伞, 撕页黄历, 算盘, 木印章与印泥盒,
# 当票). Red line 1 forbids scripting props from boxes and planes, so those MODELS entries stay empty until a
# human-made model is registered; until then those variants render only their shell (allowed by red line 1)
# with camera and light already set.
# Filled entries use the KayKit stand-ins PROPS_NEEDED.md allows: 青花碗碟 bowl_small (plain white porcelain
# block, no blue-and-white texture and no chipped rim: the 豁口 the note asks for needs the real model), 木匣
# cabinet_small (closed, so no stubs show: 当票 has no model), 空白匾额 pictureframe_large_B recoloured black
# lacquer (no gold engraving). All are placeholders, not final props.
# prop.relic.master_steelyard should share the prop.scale 戥子 model, aged; prop.relic.rosewood_abacus the
# prop.abacus model with a rosewood material (ASSET_LIST notes).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: neither writing this file nor running Blender was permitted in the session that
# produced it; stand-in scales and framing are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (32, 32)
VARIANTS = ('prop.relic.blue_curtain', 'prop.relic.camphor_chest', 'prop.relic.cat_bowl', 'prop.relic.chen_mortar',
            'prop.relic.hu2_pipe', 'prop.relic.master_steelyard', 'prop.relic.oilpaper_umbrella',
            'prop.relic.old_almanac', 'prop.relic.old_signboard', 'prop.relic.rosewood_abacus',
            'prop.relic.stub_box', 'prop.relic.sun_inkpad',)
IDS = {'prop.relic.blue_curtain': 'prop.relic.blue_curtain', 'prop.relic.camphor_chest': 'prop.relic.camphor_chest',
       'prop.relic.cat_bowl': 'prop.relic.cat_bowl', 'prop.relic.chen_mortar': 'prop.relic.chen_mortar',
       'prop.relic.hu2_pipe': 'prop.relic.hu2_pipe', 'prop.relic.master_steelyard': 'prop.relic.master_steelyard',
       'prop.relic.oilpaper_umbrella': 'prop.relic.oilpaper_umbrella',
       'prop.relic.old_almanac': 'prop.relic.old_almanac', 'prop.relic.old_signboard': 'prop.relic.old_signboard',
       'prop.relic.rosewood_abacus': 'prop.relic.rosewood_abacus', 'prop.relic.stub_box': 'prop.relic.stub_box',
       'prop.relic.sun_inkpad': 'prop.relic.sun_inkpad'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" is a board whose top face is z = 0 with a panel
# behind (the shelf cell); "ground" is a floor plane at z = 0 with a wall behind.
SURFACES = {
    'shelf': ('top', (0.075, 0.035, 0.02), (0.035, 0.018, 0.012)),    # rosewood curio-shelf cell
    'planks': ('ground', (0.09, 0.055, 0.03), (0.07, 0.045, 0.028)),  # back-room plank floor, plank wall
    'plaster': ('ground', (0.09, 0.055, 0.03), (0.30, 0.28, 0.24)),   # whitewashed wall over a plank floor
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the object.
SPEC = {
    'prop.relic.blue_curtain': ('shelf', 'day', 0.55, 0.08, 25, -12, 2.2, 0.3),
    'prop.relic.camphor_chest': ('planks', 'day', 1.0, 0.25, 22, 18, 2.0, 0.45),
    'prop.relic.cat_bowl': ('shelf', 'day', 0.40, 0.04, 35, 8, 2.4, 0.3),
    'prop.relic.chen_mortar': ('shelf', 'day', 0.55, 0.06, 30, -20, 2.2, 0.3),
    'prop.relic.hu2_pipe': ('shelf', 'dusk', 0.70, 0.04, 40, 15, 2.2, 0.3),
    'prop.relic.master_steelyard': ('shelf', 'day', 0.55, 0.08, 28, -8, 2.2, 0.3),
    'prop.relic.oilpaper_umbrella': ('planks', 'dusk', 0.9, 0.45, 8, -15, 2.0, 0.2),
    'prop.relic.old_almanac': ('shelf', 'day', 0.40, 0.03, 50, 10, 2.4, 0.3),
    'prop.relic.old_signboard': ('plaster', 'day', 1.4, 0.75, 4, 12, 1.8, 0.05),
    'prop.relic.rosewood_abacus': ('shelf', 'day', 0.55, 0.06, 32, 20, 2.2, 0.3),
    'prop.relic.stub_box': ('shelf', 'day', 0.60, 0.15, 30, -16, 2.2, 0.35),
    'prop.relic.sun_inkpad': ('shelf', 'day', 0.40, 0.03, 38, -6, 2.4, 0.3),
}

PORCELAIN = (0.80, 0.79, 0.74)    # plain white bowl (no blue-and-white texture on the stand-in)
LACQUER = (0.035, 0.022, 0.016)   # black lacquer signboard stand-in
OLD_WOOD = (0.24, 0.12, 0.05)     # old wooden box stand-in

# variant: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None), ...] around the look point
# (0, 0). Fill the empty ones once a pack is registered. Dense meshes (book pages, abacus beads, folded
# cloth) need L.noline(objs).
MODELS = {
    'prop.relic.blue_curtain': [],        # folded quilted blue cloth door curtain, a neat stack
    'prop.relic.camphor_chest': [],       # camphor-wood chest, brass corner caps, brass padlock
    'prop.relic.cat_bowl': [              # chipped blue-and-white cat bowl, chip visible on the rim
        (L.RESTAURANT, "bowl_small.gltf", (0.0, 0.0, 0.0), 0.0, 1.0, PORCELAIN),
    ],
    'prop.relic.chen_mortar': [],         # boat-shaped brass herb grinder trough with its grinding wheel
    'prop.relic.hu2_pipe': [],            # long bamboo pipe, brass bowl, cloth tobacco pouch hanging on it
    'prop.relic.master_steelyard': [],    # small silver steelyard, brass pan, weight, aged
    'prop.relic.oilpaper_umbrella': [],   # furled bamboo-ribbed oil-paper umbrella leaning on the wall
    'prop.relic.old_almanac': [],         # thread-bound almanac lying flat, red ink marks (unreadable)
    'prop.relic.old_signboard': [         # old 德厚 board core, gold engraved strokes (unreadable)
        (L.FURNITURE, "pictureframe_large_B.gltf", (0.0, 0.0, 0.45), 0.0, 1.0, LACQUER),
    ],
    'prop.relic.rosewood_abacus': [],     # rosewood abacus (prop.abacus model, rosewood material)
    'prop.relic.stub_box': [              # open wooden box full of pawn-ticket stubs
        (L.FURNITURE, "cabinet_small.gltf", (0.0, 0.05, 0.0), 0.0, 0.3, OLD_WOOD),
    ],
    'prop.relic.sun_inkpad': [],          # round blue-and-white cinnabar inkpad box, lid beside it
}


def ramp(variant):
    t = SPEC[variant][1]
    if t == "night":
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if t == "dusk":
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _shell(surface, extent, wall_y):
    kind, low_rgb, wall_rgb = SURFACES[surface]
    if kind == 'top':
        L.box("shelfboard", (extent * 4, extent * 2.5, 0.06), (0.0, extent * 0.5, -0.03), low_rgb)
        L.plane("backpanel", (extent * 6, extent * 3), (0.0, wall_y, extent * 1.2), (math.radians(90), 0, 0),
                wall_rgb)
    else:
        L.plane("ground", (extent * 6, extent * 4), (0.0, extent * 1.0, 0.0), (0, 0, 0), low_rgb)
        L.plane("wall", (extent * 6, extent * 3), (0.0, wall_y, extent * 1.5), (math.radians(90), 0, 0), wall_rgb)


def build(variant, toon=True):
    surface, t, extent, look_z, pitch, yaw, dist_k, wall_d = SPEC[variant]
    _shell(surface, extent, wall_d * extent + 0.05)
    for pack, name, loc, rot_z, scale, rgb in MODELS[variant]:
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
    dist = extent * dist_k
    a, b = math.radians(pitch), math.radians(yaw)
    L.camera((dist * math.cos(a) * math.sin(b), -dist * math.cos(a) * math.cos(b), look_z + dist * math.sin(a)),
             (0.0, 0.0, look_z), 36.0 * dist_k)
    r = extent * 1.8
    # Key light from the side opposite the camera yaw, so the side faces the camera sees get shadow.
    side = -1.0 if yaw >= 0 else 1.0
    if t == 'dusk':
        rot = (math.radians(68), 0, math.radians(55 * side))
        warm, sun_w, fill = (1.0, 0.70, 0.45), 1.8, (0.50, 0.42, 0.40)
    else:
        rot = (math.radians(50), 0, math.radians(40 * side))
        warm, sun_w, fill = (1.0, 0.88, 0.68), 2.6, (0.55, 0.50, 0.45)
    if toon:
        L.world(fill, 0.3)
        L.light('SUN', (0, 0, 5), sun_w, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), 120 * extent * sun_w / 2.6, warm, rot=rot,
                size=extent)
