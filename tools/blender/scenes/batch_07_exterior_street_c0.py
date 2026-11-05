# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Street exterior, batch 07: two 320x180 backdrops (bg.stage.1938, bg.street) and ten 64x48 card
# illustrations on the bridge-head street of Qingxi town. One street of shopfronts along a canal quay;
# camera, light, weather (rain-wet / snow / fire glow) and a few props change per variant.
# bg.stage.1938 (I-202): the text box covers the lower 45%, so the shop row and roofs sit in the top
# 55% (camera shift, see _camera).
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: stone arch bridge, bare willows, white-wall black-tile houses (plain
# shell boxes give only their massing), Jiangnan plank shopfront (KayKit door_A leaves stand in for the door
# planks, as in batch_06), wooden barricade, sandbags, notices with red seals, paper lanterns, cloth shop
# banners, carrying pole and baskets, old clothes, writing brush, inkstone, white paper, fortune-teller's
# banner pole, small spinning wheel, copper coins, wooden water buckets, flames and smoke, footprints in the
# snow, and every person (police in dark uniform from behind, townsfolk in padded jackets queueing, junk
# collector with pole, man in long gown with lantern, passers-by, squatting gamblers, neighbours with
# buckets, Shen Ruhua sitting). Lanterns and the fire are light only. Until those are registered, the cards
# show only their setting and the few props below.
# Stand-ins that are what they look like: KayKit crates for the junk collector's load, pot_A recoloured as
# a copper basin, bowl / plate as porcelain, table_small / table_low and wooden stools for the street
# stalls, bowl_small as the beggar's bowl. Puddles and snow are ground surface (shell), not objects.
# Modern KayKit city props (streetlight, cars, hydrant, bench, traffic lights) are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: shop fronts face -y at y=0, the street runs along x on -y, the canal quay edge is at y=QUAY.
# door_A runs from its hinge along +x at rot_z=0 (glTF bounds x 0..1.6, height 2.8).
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.stage.1938', 'bg.street', 'illus.ky.junk_runners', 'illus.ev.1938.night_patrol',
            'illus.ev.1939.patrol', 'illus.ev.any.cezi_stall', 'illus.ev.any.curfew', 'illus.ev.any.gamble_stall',
            'illus.fa.any.clear_road', 'illus.fa.any.fire_next_door', 'illus.fa.any.snow_day', 'illus.st.beg',)
IDS = {'bg.stage.1938': 'bg.stage.1938', 'bg.street': 'bg.street', 'illus.ky.junk_runners': 'illus.ky.junk_runners',
       'illus.ev.1938.night_patrol': 'illus.ev.1938.night_patrol', 'illus.ev.1939.patrol': 'illus.ev.1939.patrol',
       'illus.ev.any.cezi_stall': 'illus.ev.any.cezi_stall', 'illus.ev.any.curfew': 'illus.ev.any.curfew',
       'illus.ev.any.gamble_stall': 'illus.ev.any.gamble_stall', 'illus.fa.any.clear_road': 'illus.fa.any.clear_road',
       'illus.fa.any.fire_next_door': 'illus.fa.any.fire_next_door', 'illus.fa.any.snow_day': 'illus.fa.any.snow_day',
       'illus.st.beg': 'illus.st.beg'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.stage.1938', 'bg.street')
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

NIGHT = ('illus.ev.1938.night_patrol', 'illus.fa.any.fire_next_door')
DUSK = ('illus.ev.any.curfew',)
OVERCAST = ('bg.stage.1938', 'bg.street', 'illus.st.beg', 'illus.fa.any.snow_day')
SNOW = ('illus.fa.any.snow_day',)
WET = ('bg.street', 'illus.fa.any.clear_road')
# The middle shop has its middle bay swung in (trading); every other variant has every bay shut.
OPEN = ('illus.ky.junk_runners', 'illus.ev.any.cezi_stall', 'illus.ev.any.gamble_stall', 'illus.fa.any.clear_road')

W = 6.4        # shopfront width
D = 5.5        # shop depth (+y)
PITCH = 2.0    # door bay pitch; three bays centred at -2, 0, 2
G = 3.5        # ground storey height
H = 6.4        # eaves height of the upper storey
LEAF = 1.15    # door_A scale: 1.84 wide, 3.22 high
ROOF = math.radians(28)
QUAY = -7.0    # canal-side edge of the street
FIRE_X = 6.8   # the burning shop next door

WOOD_DARK = (0.10, 0.055, 0.03)
WOOD = (0.20, 0.11, 0.05)
PLANK = (0.16, 0.09, 0.045)
PLASTER = (0.78, 0.76, 0.70)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
WET_STONE = (0.24, 0.23, 0.22)
SNOWY = (0.86, 0.88, 0.92)
WATER = (0.04, 0.06, 0.08)

# Street row, left to right: (kind, centre x, upper-storey colour or house height).
ROW = (('house', -13.6, 5.4), ('shop', -6.8, PLASTER), ('shop', 0.0, WOOD), ('shop', 6.8, PLASTER),
       ('house', 13.6, 5.8))


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, rgb):
    # Two tilted slabs of shell (pitched roof over a wall box); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, d / 2 / math.cos(ROOF) + 0.5, 0.18), (cx, y, z + rise / 2), rgb)
        b.rotation_euler[0] = s * ROOF


def _house(name, cx, w, h, y0, d, snow):
    # Massing only (red line 1): wall box and roof; the real white-wall black-tile house is a missing model.
    L.box(name, (w, d, h), (cx, y0 + d / 2, h / 2), PLASTER)
    _roof(name + "_roof", cx, w, y0, d, h, SNOWY if snow else TILE)


def _shopfront(name, cx, open_mid, upper, snow):
    """Two-storey shop shell at cx, three bays of door planks; the middle bay swung in when open_mid."""
    L.plane(name + "_floor", (W, D), (cx, D / 2, 0.16), (0, 0, 0), (0.14, 0.10, 0.07))
    L.box(name + "_rear", (W, 0.3, G), (cx, D, G / 2), (0.30, 0.22, 0.15))
    L.box(name + "_ceiling", (W, D, 0.2), (cx, D / 2, G + 0.3), WOOD_DARK)
    for s in (-1, 1):
        L.box(name + "_side", (0.3, D, H), (cx + s * (W / 2 + 0.15), D / 2, H / 2), PLASTER)
    L.box(name + "_sill", (W, 0.5, 0.16), (cx, 0.0, 0.08), STONE)
    for i in range(4):
        L.box(name + "_post", (0.22, 0.3, G), (cx + (i - 1.5) * PITCH, 0.0, G / 2), WOOD_DARK)
    L.box(name + "_transom", (W, 0.2, G - 2.8 * LEAF), (cx, 0.05, (G + 2.8 * LEAF) / 2), WOOD)
    L.box(name + "_beam", (W + 0.4, 0.4, 0.4), (cx, 0.0, G + 0.2), WOOD_DARK)
    # Pent eave between the storeys, then the upper front wall set back a little.
    b = L.box(name + "_pent", (W + 0.8, 1.2, 0.14), (cx, -0.45, G + 0.6), SNOWY if snow else TILE)
    b.rotation_euler[0] = math.radians(20)
    L.box(name + "_upper", (W, 0.3, H - G - 0.4), (cx, 0.35, (H + G + 0.4) / 2), upper)
    L.box(name + "_upbeam", (W + 0.4, 0.4, 0.3), (cx, 0.3, H - 0.15), WOOD_DARK)
    _roof(name + "_roof", cx, W, 0.2, D, H, SNOWY if snow else TILE)
    for i in range(3):
        is_open = open_mid and i == 1
        x = cx + (i - 1) * PITCH - 0.92
        # Shut: in the opening. Open: swung in on its hinge, standing along +y.
        d = L.load(L.RESTAURANT, "door_A.gltf", (x, 0.12, 0.16), math.pi / 2 if is_open else 0.0,
                   LEAF, tag="door_plank")
        L.recolor(d, PLANK)


def _street(variant):
    snow = variant in SNOW
    ground = SNOWY if snow else (WET_STONE if variant in WET else STONE)
    # Stone street between the shops and the quay, the canal beyond, a far bank of houses across it.
    L.plane("street", (60, -QUAY + 1.0), (0, QUAY / 2 - 0.5, 0), (0, 0, 0), ground)
    L.box("quay_wall", (60, 0.5, 1.2), (0, QUAY - 0.25, -0.4), (0.22, 0.21, 0.20))
    L.plane("water", (80, 16), (0, QUAY - 8.0, -0.8), (0, 0, 0), WATER)
    for x, h in ((-16.0, 5.0), (-9.0, 5.6), (-2.0, 4.8), (5.0, 5.4), (12.0, 5.0)):
        _house("far_bank", x, 6.0, h, QUAY - 22.0, 4.0, snow)
    for kind, x, extra in ROW:
        if kind == 'house':
            _house("house", x, W, extra, 0.2, D, snow)
        else:
            _shopfront("shop", x, variant in OPEN and x == 0.0, extra, snow)
    # Back row for the skyline.
    for x, h in ((-10.0, 7.2), (-3.5, 7.6), (3.5, 7.0), (10.0, 7.8)):
        _house("house_back", x, 6.0, h, D + 2.5, 5.0, snow)
    if variant in WET:
        # Standing water on the flagstones after the rain (ground surface, darker than the wet stone).
        for x, y, sx, sy in ((-3.0, -3.2, 2.2, 0.9), (1.6, -4.6, 1.4, 0.7), (4.2, -2.4, 1.8, 0.6),
                             (-6.0, -5.2, 1.2, 0.5)):
            L.plane("puddle", (sx, sy), (x, y, 0.01), (0, 0, 0), (0.10, 0.12, 0.15))


def _props(variant):
    if variant == 'illus.ky.junk_runners':
        # Two loads set down in the street: crates with a copper basin, a bowl and a plate on top.
        for x in (-2.2, -0.9):
            L.recolor(L.load(L.RESTAURANT, "crate.gltf", (x, -1.8, 0), 0.15, 0.5, tag="junk_load"),
                      (0.42, 0.30, 0.16))
        L.recolor(L.load(L.RESTAURANT, "pot_A.gltf", (-2.2, -1.8, 0.62), 0.0, 1.0, tag="copper_basin"),
                  (0.55, 0.28, 0.10))
        for k, x in (("bowl.gltf", -1.05), ("plate.gltf", -0.7)):
            L.recolor(L.load(L.RESTAURANT, k, (x, -1.8, 0.62), 0.0, 1.0, tag="porcelain"), (0.80, 0.82, 0.84))
    elif variant == 'illus.ev.any.cezi_stall':
        L.recolor(L.load(L.FURNITURE, "table_small.gltf", (-4.2, -1.4, 0), 0.0, 1.0, tag="cezi_table"), WOOD)
        for x, y in ((-4.2, -0.6), (-4.2, -2.3)):
            L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (x, y, 0), 0.0, 1.0, tag="stool"), WOOD_DARK)
    elif variant == 'illus.ev.any.gamble_stall':
        L.recolor(L.load(L.FURNITURE, "table_low.gltf", (3.4, -1.6, 0), 0.0, 1.0, tag="gamble_table"), WOOD)
        L.recolor(L.load(L.RESTAURANT, "plate.gltf", (3.4, -1.6, 0.42), 0.0, 1.0, tag="stake_plate"),
                  (0.62, 0.58, 0.50))
    elif variant == 'illus.st.beg':
        L.recolor(L.load(L.RESTAURANT, "bowl_small.gltf", (-2.9, -0.7, 0), 0.0, 1.2, tag="beg_bowl"),
                  (0.70, 0.70, 0.66))


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # From the quay end, down the street; shift keeps the shops in the top 55% (see _camera).
    'bg.stage.1938': ((-12.0, -9.5, 1.8), (2.0, 0.0, 2.4), 28),
    'bg.street': ((3.0, -11.0, 1.9), (1.5, 0.0, 2.6), 30),
    'illus.ky.junk_runners': ((-3.6, -5.8, 1.6), (-1.4, -1.0, 0.9), 30),
    'illus.ev.1938.night_patrol': ((2.6, -5.2, 1.6), (0.0, 0.0, 1.8), 28),
    'illus.ev.1939.patrol': ((9.6, -6.2, 1.7), (5.2, 0.0, 1.7), 30),
    'illus.ev.any.cezi_stall': ((-2.0, -4.8, 1.5), (-4.2, -1.2, 0.8), 32),
    'illus.ev.any.curfew': ((10.0, -4.6, 2.0), (-2.0, 0.0, 2.2), 26),
    'illus.ev.any.gamble_stall': ((5.4, -4.6, 1.3), (3.4, -1.4, 0.5), 32),
    'illus.fa.any.clear_road': ((-8.5, -9.0, 1.8), (2.0, -1.0, 1.8), 28),
    'illus.fa.any.fire_next_door': ((-1.0, -9.0, 2.0), (FIRE_X - 1.5, 0.0, 4.2), 28),
    'illus.fa.any.snow_day': ((8.0, -6.2, 1.8), (-1.0, -1.0, 1.4), 26),
    'illus.st.beg': ((-1.4, -3.0, 0.9), (-3.0, -0.4, 0.6), 32),
}


def _camera(variant):
    c = L.camera(*CAMS[variant])
    if variant == 'bg.stage.1938':
        # Frame moved down (in image widths) so the eaves and roofs land in the top 55%, the street below.
        c.data.shift_y = -0.12


def _sky(rgb, strength):
    L.emit_plane("sky", (140, 60), (0, 40.0, 14), (math.radians(90), 0, 0), rgb, strength)


def _lights(variant, toon):
    if variant == 'illus.fa.any.fire_next_door':
        # Night; the roof next door burning: orange light on and under the ridge (light only, no flame model).
        _sky((0.06, 0.03, 0.04), 1.0)
        L.world((0.05, 0.04, 0.06), 0.15 if toon else 0.7)
        L.light('SUN', (0, 0, 10), 0.5, (0.55, 0.65, 1.0), rot=(math.radians(55), 0, math.radians(-30)))
        L.light('POINT', (FIRE_X, 1.5, H + 1.6), 900, (1.0, 0.42, 0.12), size=0.6)
        L.light('POINT', (FIRE_X - 1.0, -1.2, G + 0.4), 250, (1.0, 0.50, 0.18), size=0.4)
    elif variant in NIGHT:
        _sky((0.02, 0.03, 0.09), 1.0)
        L.world((0.03, 0.04, 0.10), 0.15 if toon else 0.7)
        L.light('SUN', (0, 0, 10), 0.8, (0.55, 0.65, 1.0), rot=(math.radians(55), 0, math.radians(-30)))
        # Two paper lanterns carried along the shut fronts (light only), the main light of the card.
        for x in (-0.6, 1.0):
            L.light('POINT', (x, -0.9, 1.1), 60, (1.0, 0.62, 0.28), size=0.15)
    elif variant in DUSK:
        _sky((1.0, 0.55, 0.25), 1.5)
        L.world((0.50, 0.32, 0.22), 0.5)
        # Low sun straight down the street from the right, lanterns lit early by the doors (light only).
        L.light('SUN', (0, 0, 6), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(72), 0, math.radians(110)))
        L.light('AREA', (2.0, -5.0, 3.5), 80, (1.0, 0.80, 0.60), rot=(math.radians(45), 0, 0), size=5)
        for x in (-4.0, 2.6):
            L.light('POINT', (x, -0.6, 2.6), 30, (1.0, 0.62, 0.28), size=0.15)
    elif variant in OVERCAST:
        # Flat grey day: weak sun, broad sky light from the front.
        snow = variant in SNOW
        _sky((0.72, 0.76, 0.80) if snow else (0.62, 0.66, 0.70), 1.6)
        L.world((0.70, 0.72, 0.76), 0.9)
        L.light('SUN', (0, 0, 6), 1.2, (0.88, 0.92, 1.0), rot=(math.radians(30), 0, math.radians(-15)))
        L.light('AREA', (0.0, -8.0, 5.0), 320, (0.92, 0.95, 1.0), rot=(math.radians(55), 0, 0), size=8)
    else:
        _sky((0.80, 0.86, 0.92), 2.0)
        L.world((0.80, 0.80, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (0.0, -6.0, 4.0), 260, (1.0, 0.97, 0.92), rot=(math.radians(50), 0, 0), size=6)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _street(variant)
    _props(variant)
    _camera(variant)
    _lights(variant, toon)
