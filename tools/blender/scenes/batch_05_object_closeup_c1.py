# Close-up still lifes, batch 05 part 2 (object:closeup): twelve more 64x48 card faces, each a few props on a
# surface (counter top, desk, dark tabletop) or on the ground against a wall (plank floor, stone-slab lane),
# with its own camera pitch / side angle and day, dusk or night light. One variant per art id;
# illus.fa.any.kin_money and illus.kp.leverage.li are night scenes lit by an oil lamp, illus.gl.1939.rice_ready
# is year-end dusk.
# Same shell / camera / light scheme as batch_05_object_closeup_c0.py. Registered packs (MODELS.csv: KayKit
# Furniture / Restaurant / City Builder) have almost none of these props; they are on PROPS_NEEDED.md (汇款信封,
# 银元, 红对联纸, 木格窗, 灯笼, 绣花钱袋, 铜钱, 油灯, 汇票, 竹米筐, 木米勺, 米袋, 手, 铜挂锁, 玉镯金饰, 红纸斗方, 当票,
# 毛笔, 砚台, 交代纸, 铜钥匙, 戥子, 路条, 布巾, 金条, 红手印条子, 细绳, 手稿纸页). Red line 1 forbids scripting props
# from boxes and planes, so those MODELS entries stay empty until a human-made model is registered; until then
# those variants render only their shell (allowed by red line 1) with camera and light already set.
# Filled entries use the KayKit stand-ins PROPS_NEEDED.md allows: 首饰柜 cabinet_small (same model, scale and
# colour as illus.es.jewel_cabinet in c0, as the ASSET_LIST note asks), 木匣 cabinet_small squashed to a low
# box, 米缸 jar_A_large in glazed-pottery brown, 货架 shelf_A_big in dark wood, 课本 book_single. All are
# placeholders, not final props.
# illus.kp.hu_owes uses the 红手印条子 model shared with the four illus.dm.* cards (ASSET_LIST note).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file; stand-in scales, framing, dusk and night lamp energies are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.fa.1939.year_remittance', 'illus.fa.any.found_purse', 'illus.fa.any.kin_money',
            'illus.fa.any.rice_dip', 'illus.gl.1938.redeem_cabinet', 'illus.gl.1939.rice_ready',
            'illus.kp.blank_ticket', 'illus.kp.brother_note', 'illus.kp.gate_pass', 'illus.kp.gold_bar',
            'illus.kp.hu_owes', 'illus.kp.leverage.li',)
IDS = {'illus.fa.1939.year_remittance': 'illus.fa.1939.year_remittance',
       'illus.fa.any.found_purse': 'illus.fa.any.found_purse', 'illus.fa.any.kin_money': 'illus.fa.any.kin_money',
       'illus.fa.any.rice_dip': 'illus.fa.any.rice_dip',
       'illus.gl.1938.redeem_cabinet': 'illus.gl.1938.redeem_cabinet',
       'illus.gl.1939.rice_ready': 'illus.gl.1939.rice_ready', 'illus.kp.blank_ticket': 'illus.kp.blank_ticket',
       'illus.kp.brother_note': 'illus.kp.brother_note', 'illus.kp.gate_pass': 'illus.kp.gate_pass',
       'illus.kp.gold_bar': 'illus.kp.gold_bar', 'illus.kp.hu_owes': 'illus.kp.hu_owes',
       'illus.kp.leverage.li': 'illus.kp.leverage.li'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" kinds are a slab whose top face is z = 0 with a wall
# behind; "ground" kinds are a floor plane at z = 0 with a wall close behind the props.
SURFACES = {
    'counter': ('top', (0.16, 0.085, 0.04), (0.05, 0.03, 0.018)),      # shop counter top
    'desk': ('top', (0.10, 0.055, 0.03), (0.04, 0.025, 0.015)),        # writing desk
    'darkwood': ('top', (0.05, 0.028, 0.015), (0.03, 0.018, 0.01)),    # dark worn tabletop
    'hometable': ('top', (0.13, 0.075, 0.04), (0.42, 0.40, 0.35)),     # home table, whitewashed wall
    'planks': ('ground', (0.09, 0.055, 0.03), (0.07, 0.045, 0.028)),   # storeroom / back-room plank floor
    'homefloor': ('ground', (0.11, 0.10, 0.09), (0.40, 0.38, 0.33)),   # tamped home floor, whitewashed wall
    'lane': ('ground', (0.15, 0.15, 0.14), (0.10, 0.10, 0.11)),        # stone-slab lane, grey brick wall
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the props.
SPEC = {
    'illus.fa.1939.year_remittance': ('hometable', 'day', 0.9, 0.05, 30, -14, 2.0, 0.0),
    'illus.fa.any.found_purse': ('lane', 'day', 0.6, 0.0, 48, 16, 2.2, 0.9),
    'illus.fa.any.kin_money': ('darkwood', 'night', 0.7, 0.04, 42, 10, 2.2, 0.0),
    'illus.fa.any.rice_dip': ('planks', 'day', 1.0, 0.35, 26, -16, 2.0, 0.5),
    'illus.gl.1938.redeem_cabinet': ('counter', 'day', 1.3, 0.40, 12, -18, 2.0, 0.0),
    'illus.gl.1939.rice_ready': ('homefloor', 'dusk', 1.6, 0.45, 10, 14, 2.0, 0.35),
    'illus.kp.blank_ticket': ('counter', 'day', 0.9, 0.04, 34, 6, 2.2, 0.0),
    'illus.kp.brother_note': ('counter', 'day', 0.85, 0.05, 36, 15, 2.2, 0.0),
    'illus.kp.gate_pass': ('desk', 'day', 0.5, 0.0, 70, -6, 2.4, 0.0),
    'illus.kp.gold_bar': ('counter', 'day', 0.6, 0.04, 44, -12, 2.2, 0.0),
    'illus.kp.hu_owes': ('darkwood', 'day', 0.55, 0.0, 64, 10, 2.4, 0.0),
    'illus.kp.leverage.li': ('desk', 'night', 0.8, 0.05, 38, -14, 2.2, 0.0),
}

# 木匣 stand-in: cabinet_small squashed to a low box (x, y, z scale), about 40x20x15 cm.
BOX = (0.32, 0.18, 0.16)

# variant: [(pack constant, model file, (x, y, z), rot_z, scale or (sx, sy, sz), rgb or None), ...] around the
# look point (0, 0). Fill the empty ones once a pack is registered. Dense meshes (book pages, straw, rice
# grains) go in NOLINE.
MODELS = {
    'illus.fa.1939.year_remittance': [],  # remittance envelope, silver-dollar stack, blank red couplet paper;
                                          # lattice window with paper cuts and a red lantern behind
    'illus.fa.any.found_purse': [],       # embroidered purse dropped on the slabs, a few copper coins
    'illus.fa.any.kin_money': [],         # opened envelope, small silver-dollar stack, draft (pseudo-script), oil lamp
    'illus.fa.any.rice_dip': [],          # full bamboo rice basket, wooden scoop, cloth sack, one hand
    'illus.gl.1938.redeem_cabinet': [     # lacquer jewel cabinet, brass padlock with key and red tassel; jade, gold
        (L.FURNITURE, "cabinet_small.gltf", (0.0, 0.15, 0.0), 0.0, 0.6, (0.26, 0.06, 0.03)),
    ],
    'illus.gl.1939.rice_ready': [         # rice vat with a blank red square paper, a few rice sacks
        (L.RESTAURANT, "jar_A_large.gltf", (-0.15, 0.1, 0.0), 0.0, 1.6, (0.20, 0.10, 0.045)),
    ],
    'illus.kp.blank_ticket': [            # blank ticket (border + shop seal), brush, inkstone; shelf behind
        (L.FURNITURE, "shelf_A_big.gltf", (0.0, 1.35, 0.0), 0.0, 1.0, (0.10, 0.055, 0.03)),
    ],
    'illus.kp.brother_note': [            # folded note, old brass key, small steelyard in its wooden box
        (L.FURNITURE, "cabinet_small.gltf", (0.22, 0.12, 0.0), math.radians(-10), BOX, (0.22, 0.12, 0.06)),
    ],
    'illus.kp.gate_pass': [],             # small road pass with red seal on a cloth
    'illus.kp.gold_bar': [                # small gold bar on folded red cloth, wooden box behind
        (L.FURNITURE, "cabinet_small.gltf", (0.12, 0.22, 0.0), math.radians(8), BOX, (0.22, 0.12, 0.06)),
    ],
    'illus.kp.hu_owes': [],               # folded thumbprint slip tied with string (shared slip model)
    'illus.kp.leverage.li': [             # textbook with manuscript pages tucked in, oil lamp / candle, brush
        (L.FURNITURE, "book_single.gltf", (0.05, 0.05, 0.0), math.radians(12), 1.0, (0.16, 0.20, 0.30)),
    ],
}
NOLINE = ("book_set.gltf", "book_single.gltf")

# Night variants: lamp position relative to the look point; the lamp is a warm point light at the
# oil lamp spot (its flame plane is added together with the lamp model, as in batch 01).
LAMPS = {
    'illus.fa.any.kin_money': (-0.30, 0.22, 0.35),
    'illus.kp.leverage.li': (0.32, 0.25, 0.40),
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
        lx, ly, lz = LAMPS[variant]
        # Point light falls off with distance; scaled to the close-up frame (counter night: 160 W at ~2.5 units).
        lamp_w = 30.0 * extent * extent
        if toon:
            L.world((0.30, 0.32, 0.45), 0.15)
            # Points along (-x, +y, -z): weak cold moonlight from the upper right.
            L.light('SUN', (0, 0, 5), 0.35, (0.55, 0.62, 0.85), rot=(math.radians(55), 0, math.radians(40)))
            L.light('POINT', (lx, ly, lz), lamp_w, (1.0, 0.62, 0.28), size=0.05)
        else:
            L.world((0.04, 0.045, 0.07), 0.7)
            L.light('AREA', (r, -r, look_z + r), 8 * extent, (0.55, 0.62, 0.85),
                    rot=(math.radians(55), 0, math.radians(40)), size=extent)
            L.light('POINT', (lx, ly, lz), lamp_w, (1.0, 0.62, 0.28), size=0.05)
        return
    # Day / dusk: key light from the side opposite the camera yaw, so the side faces the camera sees get shadow.
    # Dusk is a lower, weaker, redder sun.
    side = -1.0 if yaw >= 0 else 1.0
    if t == 'dusk':
        rot = (math.radians(68), 0, math.radians(55 * side))
        warm, sun_w, area_w, sky = (1.0, 0.68, 0.42), 1.9, 80, (0.50, 0.42, 0.40)
    else:
        rot = (math.radians(50), 0, math.radians(40 * side))
        warm = (0.96, 0.92, 0.84) if surface in ('lane', 'hometable', 'homefloor') else (1.0, 0.88, 0.68)
        sun_w, area_w, sky = 2.6, 120, (0.55, 0.50, 0.45)
    if toon:
        L.world(sky, 0.3)
        L.light('SUN', (0, 0, 5), sun_w, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), area_w * extent, warm, rot=rot, size=extent)
