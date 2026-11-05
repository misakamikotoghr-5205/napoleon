# Close-up still lifes, batch 05 part 3 (object:closeup): twelve more 64x48 card faces, each a few props on a
# surface (counter top, desk, dark tabletop, home table, offering table) or on the ground against a wall, with its
# own camera pitch / side angle and day, dusk or night light. One variant per art id; illus.lf.any.lamp_oil is a
# night scene lit only by its dying oil-lamp flame; illus.lf.1939.new_year_goods and illus.lf.1939.year_tab are
# year-end dusk; illus.kp.silver_keepsake is a dim late-afternoon keepsake shot.
# Same shell / camera / light scheme as batch_05_object_closeup_c0.py and _c1.py. Registered packs (MODELS.csv:
# KayKit Furniture / Restaurant / City Builder) have almost none of these props; they are on PROPS_NEEDED.md
# (船期单, 米样小布袋, 竹篮/藤篮, 布巾, 西药瓶盒, 良民证/户口纸, 圆顶礼帽, 红手印条子, 银饰, 信封和礼封, 木印章, 长烟袋,
# 青菜, 锡箔纸锭和线香, 供桌香案, 腊鱼腊肉, 红纸斗方, 算盘, 毛笔, 砚台, 铜煤油灯). Red line 1 forbids scripting props
# from boxes and planes, so those MODELS entries stay empty until a human-made model is registered; until then
# those variants render only their shell (allowed by red line 1) with camera and light already set.
# Filled entries use the KayKit stand-ins PROPS_NEEDED.md allows: 账本 book_single (blue cloth cover), 饭菜碗碟
# bowl / bowl_small / plate as plain white porcelain (no food models: the KayKit dishes are Western), 货架
# shelf_A_big in dark wood. 方桌/饭桌/木桌/供桌 are the shell table-top slab (台面板), not a table model, since
# only the top is in frame. All are placeholders, not final props.
# illus.kp.ma_owes and illus.lf.1939.year_tab use the 红手印条子 model shared with the illus.dm.* / kp.hu_owes cards.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file; stand-in scales, framing, dusk and lamp energies are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.kp.leverage.wu', 'illus.kp.leverage.zhang', 'illus.kp.liangmin', 'illus.kp.ma_owes',
            'illus.kp.silver_keepsake', 'illus.kp.sunfu_letter', 'illus.kp.zhao_favor',
            'illus.lf.1938.qingming_prep', 'illus.lf.1939.new_year_goods', 'illus.lf.1939.year_tab',
            'illus.lf.1940.census_chit', 'illus.lf.any.lamp_oil',)
IDS = {'illus.kp.leverage.wu': 'illus.kp.leverage.wu', 'illus.kp.leverage.zhang': 'illus.kp.leverage.zhang',
       'illus.kp.liangmin': 'illus.kp.liangmin', 'illus.kp.ma_owes': 'illus.kp.ma_owes',
       'illus.kp.silver_keepsake': 'illus.kp.silver_keepsake', 'illus.kp.sunfu_letter': 'illus.kp.sunfu_letter',
       'illus.kp.zhao_favor': 'illus.kp.zhao_favor', 'illus.lf.1938.qingming_prep': 'illus.lf.1938.qingming_prep',
       'illus.lf.1939.new_year_goods': 'illus.lf.1939.new_year_goods',
       'illus.lf.1939.year_tab': 'illus.lf.1939.year_tab', 'illus.lf.1940.census_chit': 'illus.lf.1940.census_chit',
       'illus.lf.any.lamp_oil': 'illus.lf.any.lamp_oil'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" kinds are a slab whose top face is z = 0 with a wall
# behind; "ground" kinds are a floor plane at z = 0 with a wall close behind the props.
SURFACES = {
    'counter': ('top', (0.16, 0.085, 0.04), (0.05, 0.03, 0.018)),      # shop counter top
    'desk': ('top', (0.10, 0.055, 0.03), (0.04, 0.025, 0.015)),        # writing desk
    'darkwood': ('top', (0.05, 0.028, 0.015), (0.03, 0.018, 0.01)),    # dark worn tabletop
    'hometable': ('top', (0.13, 0.075, 0.04), (0.42, 0.40, 0.35)),     # home table, whitewashed wall
    'altar': ('top', (0.14, 0.025, 0.015), (0.40, 0.38, 0.33)),        # red-lacquer offering table, whitewashed wall
    'homefloor': ('ground', (0.11, 0.10, 0.09), (0.40, 0.38, 0.33)),   # tamped home floor, whitewashed wall
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the props.
SPEC = {
    'illus.kp.leverage.wu': ('desk', 'day', 0.8, 0.05, 40, -12, 2.2, 0.0),
    'illus.kp.leverage.zhang': ('hometable', 'day', 0.75, 0.10, 34, 14, 2.2, 0.0),
    'illus.kp.liangmin': ('darkwood', 'day', 0.5, 0.0, 66, 8, 2.4, 0.0),
    'illus.kp.ma_owes': ('hometable', 'day', 0.9, 0.08, 28, -16, 2.0, 0.0),
    'illus.kp.silver_keepsake': ('darkwood', 'dusk', 0.45, 0.0, 58, -10, 2.4, 0.0),
    'illus.kp.sunfu_letter': ('desk', 'day', 0.6, 0.0, 52, 12, 2.2, 0.0),
    'illus.kp.zhao_favor': ('counter', 'day', 1.2, 0.08, 22, 16, 2.0, 0.0),
    'illus.lf.1938.qingming_prep': ('altar', 'day', 1.2, 0.08, 26, -10, 2.0, 0.0),
    'illus.lf.1939.new_year_goods': ('homefloor', 'dusk', 1.4, 0.50, 8, 12, 2.0, 0.35),
    'illus.lf.1939.year_tab': ('counter', 'dusk', 0.9, 0.05, 34, -14, 2.2, 0.0),
    'illus.lf.1940.census_chit': ('hometable', 'day', 0.7, 0.0, 56, 10, 2.2, 0.0),
    'illus.lf.any.lamp_oil': ('darkwood', 'night', 0.8, 0.10, 22, -12, 2.2, 0.0),
}

PORCELAIN = (0.80, 0.79, 0.74)  # plain white bowls (no blue-and-white texture on the stand-ins)
BOOK = (0.10, 0.15, 0.28)       # blue cloth account-book cover

# variant: [(pack constant, model file, (x, y, z), rot_z, scale or (sx, sy, sz), rgb or None), ...] around the
# look point (0, 0). Fill the empty ones once a pack is registered. Dense meshes (book pages) go in NOLINE.
MODELS = {
    'illus.kp.leverage.wu': [             # account book pressing a shipping slip and a small cloth rice-sample bag
        (L.FURNITURE, "book_single.gltf", (0.02, 0.04, 0.0), math.radians(10), 1.0, BOOK),
    ],
    'illus.kp.leverage.zhang': [],        # rattan basket, cover cloth lifted on a small powder box and a medicine vial
    'illus.kp.liangmin': [],              # folded good-citizen card (blank photo box, red seal) on a cloth
    'illus.kp.ma_owes': [],               # round felt hat and a red-thumbprint IOU on a square table
    'illus.kp.silver_keepsake': [],       # small longevity silver lock on an old red string, on red cloth
    'illus.kp.sunfu_letter': [],          # red-bordered envelope with the Sun family red seal
    'illus.kp.zhao_favor': [              # long pipe and a bunch of greens on the counter; dark shelf behind
        (L.FURNITURE, "shelf_A_big.gltf", (0.0, 1.8, 0.0), 0.0, 1.0, (0.10, 0.055, 0.03)),
    ],
    'illus.lf.1938.qingming_prep': [      # tin-foil ingots, incense sticks, a table of dishes
        (L.RESTAURANT, "plate.gltf", (-0.38, 0.12, 0.0), 0.0, 1.0, PORCELAIN),
        (L.RESTAURANT, "bowl.gltf", (0.0, 0.22, 0.0), 0.0, 1.0, PORCELAIN),
        (L.RESTAURANT, "bowl.gltf", (0.36, 0.10, 0.0), 0.0, 1.0, PORCELAIN),
        (L.RESTAURANT, "bowl_small.gltf", (0.10, -0.18, 0.0), 0.0, 1.0, PORCELAIN),
        (L.RESTAURANT, "bowl_small.gltf", (-0.16, -0.14, 0.0), 0.0, 1.0, PORCELAIN),
    ],
    'illus.lf.1939.new_year_goods': [],   # cured fish and pork hung from a pole, bamboo basket of red paper
    'illus.lf.1939.year_tab': [           # account book, abacus, a string-tied bundle of thumbprint IOUs
        (L.FURNITURE, "book_single.gltf", (-0.18, 0.06, 0.0), math.radians(-8), 1.0, BOOK),
    ],
    'illus.lf.1940.census_chit': [],      # ruled household-register sheet, brush, inkstone on the dinner table
    'illus.lf.any.lamp_oil': [],          # oil lamp with a weak flame, nearly empty oil bottle on a wooden table
}
NOLINE = ("book_set.gltf", "book_single.gltf")

# Night variants: (lamp position relative to the look point, energy factor). The lamp is a warm point light at
# the oil lamp spot (its flame plane comes with the lamp model, as in batch 01). lamp_oil's flame is the only
# light in the scene (ASSET_LIST note), so it gets no moonlight and a weak, low flame.
LAMPS = {
    'illus.lf.any.lamp_oil': ((-0.12, 0.12, 0.28), 14.0),
}


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
    _shell(surface, extent, wall_d * extent + 0.05)
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
    if t == 'night':
        (lx, ly, lz), k = LAMPS[variant]
        # Point light falls off with distance; scaled to the close-up frame (c1 lamps use 30 * extent^2).
        lamp_w = k * extent * extent
        L.world((0.02, 0.02, 0.03), 0.0)
        L.light('POINT', (lx, ly, lz), lamp_w, (1.0, 0.58, 0.24), size=0.03)
        return
    # Day / dusk: key light from the side opposite the camera yaw, so the side faces the camera sees get shadow.
    # Dusk is a lower, weaker, redder sun.
    side = -1.0 if yaw >= 0 else 1.0
    if t == 'dusk':
        rot = (math.radians(68), 0, math.radians(55 * side))
        warm, sun_w, area_w, sky = (1.0, 0.68, 0.42), 1.9, 80, (0.50, 0.42, 0.40)
    else:
        rot = (math.radians(50), 0, math.radians(40 * side))
        warm = (0.96, 0.92, 0.84) if surface in ('hometable', 'homefloor', 'altar') else (1.0, 0.88, 0.68)
        sun_w, area_w, sky = 2.6, 120, (0.55, 0.50, 0.45)
    if toon:
        L.world(sky, 0.3)
        L.light('SUN', (0, 0, 5), sun_w, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), area_w * extent, warm, rot=rot, size=extent)
