# Close-up still lifes, batch 05 (object:closeup / object:fortune / interior:temple): twelve 64x48 card faces,
# each a few props on a surface (counter top, desk, dark tabletop) or on the ground against a wall (plank
# floor, lane, temple yard), with its own camera pitch / side angle and day or night light. One variant per
# art id; illus.bf.1940.night_road and illus.nt.accounts are night scenes lit by a lantern / oil lamp.
# Registered packs (MODELS.csv: KayKit Furniture / Restaurant / City Builder) have almost none of these props;
# they are on PROPS_NEEDED.md (红手印条子, 米袋, 折叠衣物, 小本子, 毛笔, 砚台, 铜钱/银元, 铁锹, 草帽, 账本, 算盘,
# 油灯, 当票碎片, 证件, 印章, 签筒, 布幌子, 彩绘轮盘, 柴捆, 杆秤, 灯笼, 手). Red line 1 forbids scripting props from
# boxes and planes, so those MODELS entries stay empty until a human-made model is registered; until then
# those variants render only their shell (allowed by red line 1) with camera and light already set.
# Filled entries use the KayKit stand-ins PROPS_NEEDED.md allows: 摊桌 table_small, 凳子 chair_stool_wood,
# 首饰柜 cabinet_small (the listed cabinet_small_decorated stand-in is not used: its decorations may show
# modern clutter on top; switch back if it turns out clean). All are placeholders, not final props.
# The four 红手印条子 cards (dm.goods / info / money / people) must share one slip model (ASSET_LIST note).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# NOT YET RENDERED: running Blender was not permitted in the session that produced this file; stand-in
# scales, framing and night lamp energies are estimates to check on the first render.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.bf.1940.night_road', 'illus.dm.goods', 'illus.dm.info', 'illus.dm.money', 'illus.dm.people',
            'illus.es.jewel_cabinet', 'illus.nt.accounts', 'illus.tk.de196', 'illus.ev.1940.papers_swap',
            'illus.ev.any.fortune_teller', 'illus.ev.any.wheel_go', 'illus.fa.1939.charcoal_wind',)
IDS = {'illus.bf.1940.night_road': 'illus.bf.1940.night_road', 'illus.dm.goods': 'illus.dm.goods',
       'illus.dm.info': 'illus.dm.info', 'illus.dm.money': 'illus.dm.money', 'illus.dm.people': 'illus.dm.people',
       'illus.es.jewel_cabinet': 'illus.es.jewel_cabinet', 'illus.nt.accounts': 'illus.nt.accounts',
       'illus.tk.de196': 'illus.tk.de196', 'illus.ev.1940.papers_swap': 'illus.ev.1940.papers_swap',
       'illus.ev.any.fortune_teller': 'illus.ev.any.fortune_teller',
       'illus.ev.any.wheel_go': 'illus.ev.any.wheel_go',
       'illus.fa.1939.charcoal_wind': 'illus.fa.1939.charcoal_wind'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Shell surfaces: (kind, surface rgb, wall rgb). "top" kinds are a slab whose top face is z = 0 with a wall
# behind; "ground" kinds are a floor plane at z = 0 with a wall close behind the props.
SURFACES = {
    'counter': ('top', (0.16, 0.085, 0.04), (0.05, 0.03, 0.018)),      # shop counter top
    'desk': ('top', (0.10, 0.055, 0.03), (0.04, 0.025, 0.015)),        # account-room writing desk
    'darkwood': ('top', (0.05, 0.028, 0.015), (0.03, 0.018, 0.01)),    # dark worn tabletop
    'office': ('top', (0.20, 0.13, 0.07), (0.30, 0.28, 0.24)),         # office desk, whitewashed wall
    'planks': ('ground', (0.09, 0.055, 0.03), (0.07, 0.045, 0.028)),   # storeroom / back-room plank floor
    'lane': ('ground', (0.15, 0.15, 0.14), (0.10, 0.10, 0.11)),        # stone-slab lane, grey brick wall
    'temple': ('ground', (0.17, 0.16, 0.14), (0.30, 0.07, 0.04)),      # temple yard, red-washed wall
}

# variant: (surface, time, frame width in units, look height, camera pitch deg, camera yaw deg,
# distance factor, wall distance behind the look point). 1 unit ~ 0.75 m. The sensor (36 mm) fits the image
# width, so lens = 36 * distance factor. Positive yaw moves the camera to the right of the props.
SPEC = {
    'illus.bf.1940.night_road': ('lane', 'night', 0.9, 0.55, 20, -15, 1.8, 0.6),
    'illus.dm.goods': ('planks', 'day', 1.4, 0.30, 22, 10, 2.0, 0.5),
    'illus.dm.info': ('counter', 'day', 0.75, 0.02, 55, -8, 2.2, 0.0),
    'illus.dm.money': ('counter', 'day', 0.6, 0.04, 35, 12, 2.2, 0.0),
    'illus.dm.people': ('planks', 'day', 1.6, 0.55, 8, -12, 2.0, 0.25),
    'illus.es.jewel_cabinet': ('counter', 'day', 1.3, 0.40, 12, 18, 2.0, 0.0),
    'illus.nt.accounts': ('desk', 'night', 0.9, 0.08, 40, 0, 2.2, 0.0),
    'illus.tk.de196': ('darkwood', 'day', 0.55, 0.0, 72, 5, 2.4, 0.0),
    'illus.ev.1940.papers_swap': ('office', 'day', 0.8, 0.02, 45, -20, 2.2, 0.0),
    'illus.ev.any.fortune_teller': ('lane', 'day', 2.6, 0.55, 16, 20, 1.6, 0.9),
    'illus.ev.any.wheel_go': ('temple', 'day', 1.8, 1.0, 4, 0, 1.8, 0.4),
    'illus.fa.1939.charcoal_wind': ('planks', 'day', 1.3, 0.70, 6, 8, 2.0, 0.35),
}

# variant: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None), ...] around the look point
# (0, 0). Fill the empty ones once a pack is registered, e.g. (L.SLIP_PACK, "slip_thumbprint.fbx",
# (0, 0, 0.001), 0.2, 1.0, None). Dense meshes (book pages, abacus beads, straw, firewood) need L.noline(objs).
MODELS = {
    'illus.bf.1940.night_road': [],   # folded road pass with red seal (border + seal only), paper lantern, hand
    'illus.dm.goods': [],             # rice sack with the thumbprint slip tied on, folded clothes
    'illus.dm.info': [],              # thumbprint slip, open small notebook, writing brush
    'illus.dm.money': [],             # thumbprint slip, small stack of copper coins / silver dollars
    'illus.dm.people': [],            # thumbprint slip, iron spade and straw hat against the wall
    'illus.es.jewel_cabinet': [       # red-brown lacquer cabinet with many small drawers, brass pulls; jewellery
        (L.FURNITURE, "cabinet_small.gltf", (0.0, 0.15, 0.0), 0.0, 0.6, (0.26, 0.06, 0.03)),
    ],
    'illus.nt.accounts': [],          # open ledger (pseudo-script), abacus, oil lamp, brush resting on inkstone
    'illus.tk.de196': [],             # torn pawn-ticket pieces, border lines and part of the red seal only
    'illus.ev.1940.papers_swap': [],  # old papers, new papers with red seal, seal
    'illus.ev.any.fortune_teller': [  # stall table (+ cloth), stool; banner pole, lot tube, brush and inkstone
        (L.FURNITURE, "table_small.gltf", (0.0, 0.2, 0.0), 0.0, 1.0, (0.14, 0.08, 0.04)),
        (L.FURNITURE, "chair_stool_wood.gltf", (0.85, -0.15, 0.0), math.radians(20), 1.0, (0.16, 0.09, 0.045)),
    ],
    'illus.ev.any.wheel_go': [],      # painted wheel on a wooden stand, pointer on top (game wheel colours)
    'illus.fa.1939.charcoal_wind': [],  # bundle of firewood hung on a steelyard, weight, a few copper coins
}

# Night variants: lamp position relative to the look point; the lamp is a warm point light at the
# lantern / oil lamp spot (its flame plane is added together with the lamp model, as in batch 01).
LAMPS = {
    'illus.bf.1940.night_road': (-0.35, 0.05, 0.75),
    'illus.nt.accounts': (-0.30, 0.25, 0.40),
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
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
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
    # Day: key light from the side opposite the camera yaw, so the side faces the camera sees get shadow.
    side = -1.0 if yaw >= 0 else 1.0
    rot = (math.radians(50), 0, math.radians(40 * side))
    warm = (0.96, 0.92, 0.84) if surface in ('office', 'temple', 'lane') else (1.0, 0.88, 0.68)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        L.light('SUN', (0, 0, 5), 2.6, warm, rot=rot)
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        # SUN rot (a, 0, c) points along (-sin c sin a, cos c sin a, -cos a); the area light sits up the beam.
        d = (-math.sin(rot[2]) * math.sin(rot[0]), math.cos(rot[2]) * math.sin(rot[0]))
        L.light('AREA', (-d[0] * r, -d[1] * r, look_z + r * 1.3), 120 * extent, warm, rot=rot, size=extent)
