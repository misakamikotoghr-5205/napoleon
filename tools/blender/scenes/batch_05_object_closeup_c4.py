# Close-up still lifes, batch 05 part 5 (object:closeup / object:item): twelve item.* pawn-goods pictures
# (64x64): the ten-tael gold bar, four pieces of jewellery, four 1930s Western medicines and three rice sacks.
# Each is a prop on a surface (dark tabletop, counter top, home table) or a sack on the ground against a wall,
# with its own camera pitch / side angle and day or dusk light. One variant per art id.
# Same shell / camera / light scheme as batch_05_object_closeup_c0.py .. _c3.py. The camera fits the image
# width, so the props stay centred.
# None of these props exist in the registered packs (MODELS.csv: KayKit Furniture / Restaurant / City Builder),
# and PROPS_NEEDED.md gives no KayKit stand-in for them (金条, 银饰, 金簪, 白玉坠, 西药瓶盒, 米袋). Red line 1
# forbids scripting props from boxes and planes, so every MODELS entry stays empty until a human-made model is
# registered; until then these variants render only their shell (allowed by red line 1) with camera and light
# already set. The three rice variants must share one sack model and differ only in the grain (note column).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: framing and light are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 64)
VARIANTS = ('item.goldbar.bar_ten', 'item.jewelry.bangle', 'item.jewelry.hairpin', 'item.jewelry.jade',
            'item.jewelry.ring', 'item.medicine.aspirin', 'item.medicine.iodine', 'item.medicine.quinine',
            'item.medicine.sulfa', 'item.rice.broken', 'item.rice.jing', 'item.rice.nuo',)
IDS = {'item.goldbar.bar_ten': 'item.goldbar.bar_ten', 'item.jewelry.bangle': 'item.jewelry.bangle',
       'item.jewelry.hairpin': 'item.jewelry.hairpin', 'item.jewelry.jade': 'item.jewelry.jade',
       'item.jewelry.ring': 'item.jewelry.ring', 'item.medicine.aspirin': 'item.medicine.aspirin',
       'item.medicine.iodine': 'item.medicine.iodine', 'item.medicine.quinine': 'item.medicine.quinine',
       'item.medicine.sulfa': 'item.medicine.sulfa', 'item.rice.broken': 'item.rice.broken',
       'item.rice.jing': 'item.rice.jing', 'item.rice.nuo': 'item.rice.nuo'}
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
SPEC = {
    'item.goldbar.bar_ten': ('darkwood', 'dusk', 0.45, 0.0, 44, -14, 2.6, 0.0),
    'item.jewelry.bangle': ('darkwood', 'day', 0.25, 0.0, 62, 10, 2.8, 0.0),
    'item.jewelry.hairpin': ('counter', 'day', 0.32, 0.0, 56, -18, 2.8, 0.0),
    'item.jewelry.jade': ('darkwood', 'dusk', 0.22, 0.0, 66, 6, 2.8, 0.0),
    'item.jewelry.ring': ('counter', 'day', 0.12, 0.0, 52, 16, 3.0, 0.0),
    'item.medicine.aspirin': ('counter', 'day', 0.25, 0.04, 34, -12, 2.6, 0.0),
    'item.medicine.iodine': ('hometable', 'day', 0.18, 0.06, 18, 10, 2.6, 0.0),
    'item.medicine.quinine': ('counter', 'day', 0.22, 0.07, 22, -8, 2.6, 0.0),
    'item.medicine.sulfa': ('darkwood', 'day', 0.18, 0.01, 48, 14, 2.6, 0.0),
    'item.rice.broken': ('shopwall', 'day', 1.1, 0.45, 40, -10, 2.2, 0.55),
    'item.rice.jing': ('shopwall', 'day', 1.1, 0.45, 40, -10, 2.2, 0.55),
    'item.rice.nuo': ('shopwall', 'day', 1.1, 0.45, 40, -10, 2.2, 0.55),
}

# variant: [(pack constant, model file, (x, y, z), rot_z, scale or (sx, sy, sz), rgb or None), ...] around the
# look point (0, 0). Fill these once a pack is registered. Dense meshes go in NOLINE.
MODELS = {
    'item.goldbar.bar_ten': [],    # ten-tael big gold bar, clearly longer and thicker than bar_one, stamped
    'item.jewelry.bangle': [],     # round old silver bangle, fine engraved flowers (bump map)
    'item.jewelry.hairpin': [],    # long thin gold hairpin, a small flower at the tip
    'item.jewelry.jade': [],       # white jade pendant on an old cord
    'item.jewelry.ring': [],       # small silver ring, simple engraved pattern
    'item.medicine.aspirin': [],   # aspirin tablets in a paper box, illegible printed maker label
    'item.medicine.iodine': [],    # small brown glass iodine bottle, stopper and paper label
    'item.medicine.quinine': [],   # glass bottle of white quinine tablets, paper seal over the mouth, unopened
    'item.medicine.sulfa': [],     # small round tin of sulfa powder, paper label on the lid
    'item.rice.broken': [],        # open cloth sack, rim rolled down, broken rice showing (same sack for all)
    'item.rice.jing': [],          # same sack, local short round translucent japonica, no marks on the sack
    'item.rice.nuo': [],           # same sack, milky opaque glutinous rice
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
