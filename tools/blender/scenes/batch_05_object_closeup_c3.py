# Close-up still lifes, batch 05 part 4 (object:closeup / object:item): two 64x48 home-life card faces
# (illus.lf.any.rice_low, illus.lf.any.wedding_gift) and ten item.* pawn-goods pictures (ASSET_LIST base size
# 64x64), each a few props on a surface (home table, dark tabletop, counter top), on the ground against a wall,
# or hung on a wall, with its own camera pitch / side angle and day or dusk light. One variant per art id.
# SIZE is 64x48 for the whole module as requested. ASSET_LIST lists the item.* ids as 64x64, so render those with
# `--size 64x64`. The camera fits the image width, so the props stay centred and only the frame height grows.
# Same shell / camera / light scheme as batch_05_object_closeup_c0.py .. _c2.py. Registered packs (MODELS.csv:
# KayKit Furniture / Restaurant / City Builder) have almost none of these props; they are on PROPS_NEEDED.md
# (缸盖, 木米勺, 红喜帖, 红礼封, 画轴卷起裹蓝布, 叠好的衣物, 布匹, 信封一束, 货单纸叠, 捆绳, 金条). Red line 1 forbids
# scripting props from boxes and planes, so those MODELS entries stay empty until a human-made model is
# registered; until then those variants render only their shell (allowed by red line 1) with camera and light
# already set.
# Filled entries use the KayKit stand-ins PROPS_NEEDED.md allows: 陶米缸 jar_A_large in glazed-pottery brown,
# 行书条幅挂轴 pictureframe_large_A, 布面画册 book_single (blue cloth cover, closed). 木桌 is the shell
# table-top slab (台面板), not a table model, since only the top is in frame. All are placeholders, not final
# props; the pictureframe and the closed book show none of the ink brushwork / bird painting the notes ask for.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file; stand-in scales, the wall-hung frame height and framing are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.lf.any.rice_low', 'illus.lf.any.wedding_gift', 'item.art.calligraphy', 'item.art.flowers',
            'item.art.landscape', 'item.clothing.coat', 'item.clothing.qipao', 'item.clothing.robe',
            'item.clothing.scarf', 'item.documents.letter', 'item.documents.receipt', 'item.goldbar.bar_one',)
IDS = {'illus.lf.any.rice_low': 'illus.lf.any.rice_low', 'illus.lf.any.wedding_gift': 'illus.lf.any.wedding_gift',
       'item.art.calligraphy': 'item.art.calligraphy', 'item.art.flowers': 'item.art.flowers',
       'item.art.landscape': 'item.art.landscape', 'item.clothing.coat': 'item.clothing.coat',
       'item.clothing.qipao': 'item.clothing.qipao', 'item.clothing.robe': 'item.clothing.robe',
       'item.clothing.scarf': 'item.clothing.scarf', 'item.documents.letter': 'item.documents.letter',
       'item.documents.receipt': 'item.documents.receipt', 'item.goldbar.bar_one': 'item.goldbar.bar_one'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" kinds are a slab whose top face is z = 0 with a wall
# behind; "ground" kinds are a floor plane at z = 0 with a wall close behind the props.
SURFACES = {
    'counter': ('top', (0.16, 0.085, 0.04), (0.05, 0.03, 0.018)),      # shop counter top
    'darkwood': ('top', (0.05, 0.028, 0.015), (0.03, 0.018, 0.01)),    # dark worn tabletop
    'hometable': ('top', (0.13, 0.075, 0.04), (0.42, 0.40, 0.35)),     # home table, whitewashed wall
    'homefloor': ('ground', (0.11, 0.10, 0.09), (0.40, 0.38, 0.33)),   # tamped home floor, whitewashed wall
    'shopwall': ('ground', (0.09, 0.05, 0.028), (0.06, 0.036, 0.02)),  # shop plank floor, dark plank wall
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the props.
SPEC = {
    'illus.lf.any.rice_low': ('homefloor', 'dusk', 1.3, 0.55, 48, -10, 2.0, 0.55),
    'illus.lf.any.wedding_gift': ('hometable', 'day', 0.7, 0.0, 50, 12, 2.2, 0.0),
    'item.art.calligraphy': ('shopwall', 'day', 1.3, 1.25, 4, 8, 2.2, 0.08),
    'item.art.flowers': ('darkwood', 'day', 0.6, 0.02, 58, -8, 2.4, 0.0),
    'item.art.landscape': ('counter', 'day', 0.8, 0.04, 36, 14, 2.2, 0.0),
    'item.clothing.coat': ('counter', 'day', 0.85, 0.06, 42, -12, 2.2, 0.0),
    'item.clothing.qipao': ('counter', 'day', 0.8, 0.06, 38, 10, 2.2, 0.0),
    'item.clothing.robe': ('darkwood', 'day', 0.85, 0.06, 44, 14, 2.2, 0.0),
    'item.clothing.scarf': ('darkwood', 'day', 0.6, 0.04, 50, -14, 2.4, 0.0),
    'item.documents.letter': ('darkwood', 'day', 0.55, 0.02, 54, 10, 2.4, 0.0),
    'item.documents.receipt': ('counter', 'day', 0.6, 0.03, 48, -10, 2.4, 0.0),
    'item.goldbar.bar_one': ('darkwood', 'dusk', 0.35, 0.0, 46, 12, 2.6, 0.0),
}

POTTERY = (0.20, 0.10, 0.045)  # dark brown glaze for the rice-jar stand-in
BOOK = (0.10, 0.15, 0.28)      # blue cloth album cover
FRAME = (0.12, 0.07, 0.035)    # dark wood for the scroll stand-in

# variant: [(pack constant, model file, (x, y, z), rot_z, scale or (sx, sy, sz), rgb or None), ...] around the
# look point (0, 0). Fill the empty ones once a pack is registered. Dense meshes (book pages) go in NOLINE.
MODELS = {
    'illus.lf.any.rice_low': [            # lidless glazed rice jar nearly empty, wooden scoop inside, lid beside
        (L.RESTAURANT, "jar_A_large.gltf", (0.0, 0.05, 0.0), 0.0, 1.6, POTTERY),
    ],
    'illus.lf.any.wedding_gift': [],      # blank red wedding invitation and red gift envelope on a wooden table
    'item.art.calligraphy': [             # running-script hanging scroll, half unrolled, abstract ink strokes
        (L.FURNITURE, "pictureframe_large_A.gltf", (0.0, 0.0, 0.75), 0.0, 1.0, FRAME),
    ],
    'item.art.flowers': [                 # cloth-bound album opened on a bird-on-branch page
        (L.FURNITURE, "book_single.gltf", (0.0, 0.02, 0.0), math.radians(-12), 1.0, BOOK),
    ],
    'item.art.landscape': [],             # rolled paper landscape scroll wrapped in a tied blue cloth
    'item.clothing.coat': [],             # folded blue padded cotton jacket with frog buttons
    'item.clothing.qipao': [],            # folded bolt of pale patterned qipao cloth (fabric, not a dress)
    'item.clothing.robe': [],             # folded navy cotton long gown, long sleeves
    'item.clothing.scarf': [],            # folded grey coarse-knit wool scarf
    'item.documents.letter': [],          # bundle of old family-letter envelopes tied with string
    'item.documents.receipt': [],         # string-tied stack of firm invoices, illegible grey marks
    'item.goldbar.bar_one': [],           # one-tael small gold bar with one recessed stamp
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
        if name.startswith("pictureframe"):
            loc = (loc[0], wall_y - 0.04, loc[2])  # hung flat on the wall, facing -y like counter.py's frame
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
        warm = (0.96, 0.92, 0.84) if surface in ('hometable', 'homefloor') else (1.0, 0.88, 0.68)
        sun_w, area_w, sky = 2.6, 120, (0.55, 0.50, 0.45)
    if toon:
        L.world(sky, 0.3)
        L.light('SUN', (0, 0, 5), sun_w, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), area_w * extent, warm, rot=rot, size=extent)
