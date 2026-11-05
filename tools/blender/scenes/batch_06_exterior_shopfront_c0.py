# NOT YET RENDERED: writing this file and running Blender were not permitted in the session that produced it.
# Shopfront exterior, batch 06: the title backdrop (bg.title, 320x180) and eleven 64x48 card illustrations
# on the street in front of 德厚当 and the rice shop next door. One street; camera, lights, door leaves and a
# few props change per variant.
# Title (I-201): the left half and the top third stay quiet (night sky and water) for the title, the shop
# sits on the right half across the river. No sign text anywhere (no sign model exists anyway).
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: a Jiangnan two-storey plank shopfront with removable door planks (the
# KayKit restaurant door_A leaves stand in for the planks), blank signboard, cloth shop banner, stone arch
# bridge, white-wall black-tile houses (plain shell boxes give only their massing), new moon, door bar,
# red couplets, paper lanterns, watchman's clapper, levy notices / fines / rice notice (whole, torn, stamped),
# rice measure and rice sacks, cloth bundles, ledger in hand, good-citizen pass, and every person (queueing
# neighbours, police in black uniform, man in long gown with notebook, Shen Ruhua in blue, creditor in hat and
# gown, watchman, rice-shop clerk, onlookers, the knocking silhouette). Lamps and lanterns are light only.
# Until those are registered, the card variants show only their setting.
# Stand-ins that are what they look like: KayKit crates for rice bins / sacks, kitchen counters (stretched,
# as in batch_03) for the rice-shop counter.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# SIZE is the backdrop size, and render.py / list_jobs.py only read SIZE and COLORS. Render the cards with
# --size 64x48 (SIZES[variant]) and quantise them with pix.py --colors 20 --method maxcoverage (CARD_COLORS).
# Card cameras are framed for 4:3.
# Orientation: the street is on -y, shop fronts face -y at y=0. door_A runs from its hinge along +x at rot_z=0
# (glTF bounds x 0..1.6, height 2.8); kitchen-counter fronts face -y at rot_z=0 (batch_03 turns them by pi).
import math

import bl_lib as L

SIZE = (320, 180)
VARIANTS = ('bg.title', 'illus.es.shopfront', 'illus.ky.needy_neighbors', 'illus.ev.1938.levy_call',
            'illus.ev.1938.police_check', 'illus.ev.1938.rice_line', 'illus.ev.1939.year_debt',
            'illus.ev.1940.curfew', 'illus.ev.1940.levy_rename', 'illus.ev.1940.rice_notice',
            'illus.fa.1938.door_fine', 'illus.fa.any.night_knock',)
IDS = {'bg.title': 'bg.title', 'illus.es.shopfront': 'illus.es.shopfront',
       'illus.ky.needy_neighbors': 'illus.ky.needy_neighbors', 'illus.ev.1938.levy_call': 'illus.ev.1938.levy_call',
       'illus.ev.1938.police_check': 'illus.ev.1938.police_check',
       'illus.ev.1938.rice_line': 'illus.ev.1938.rice_line', 'illus.ev.1939.year_debt': 'illus.ev.1939.year_debt',
       'illus.ev.1940.curfew': 'illus.ev.1940.curfew', 'illus.ev.1940.levy_rename': 'illus.ev.1940.levy_rename',
       'illus.ev.1940.rice_notice': 'illus.ev.1940.rice_notice',
       'illus.fa.1938.door_fine': 'illus.fa.1938.door_fine', 'illus.fa.any.night_knock': 'illus.fa.any.night_knock'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

BACKDROPS = ('bg.title',)
SIZES = {v: (SIZE if v in BACKDROPS else (64, 48)) for v in VARIANTS}
CARD_COLORS = (20, "maxcoverage")

NIGHT = ('bg.title', 'illus.ev.1939.year_debt', 'illus.fa.any.night_knock')
DUSK = ('illus.ev.1940.curfew',)
SNOW = ('illus.ev.1939.year_debt',)
# Pawnshop with the middle plank door swung in (open for business); every other variant has it shut.
OPEN = ('bg.title', 'illus.es.shopfront', 'illus.ky.needy_neighbors', 'illus.ev.1938.police_check',
        'illus.ev.1939.year_debt')

PX = 0.0       # pawnshop centre x
RX = 6.8       # rice shop centre x (next door, right)
W = 6.4        # shopfront width
D = 5.5        # shop depth (+y)
PITCH = 2.0    # door bay pitch; three bays centred at -2, 0, 2
G = 3.5        # ground storey height
H = 6.4        # eaves height of the upper storey
LEAF = 1.15    # door_A scale: 1.84 wide, 3.22 high
ROOF = math.radians(28)

WOOD_DARK = (0.10, 0.055, 0.03)
WOOD = (0.20, 0.11, 0.05)
PLANK = (0.16, 0.09, 0.045)
PLASTER = (0.78, 0.76, 0.70)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
SNOWY = (0.86, 0.88, 0.92)


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


def _shopfront(name, cx, leaves, upper, snow):
    """Two-storey shop shell at cx; `leaves` is one of 'shut' / 'open' / None for each of the three bays."""
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
    for i, state in enumerate(leaves):
        if state is None:
            continue
        x = cx + (i - 1) * PITCH - 0.92
        # Shut: in the opening. Open: swung in on its hinge, standing along +y.
        d = L.load(L.RESTAURANT, "door_A.gltf", (x, 0.12, 0.16), 0.0 if state == 'shut' else math.pi / 2,
                   LEAF, tag="door_plank")
        L.recolor(d, PLANK)


def _rice_counter():
    # Rice-shop counter just inside the open front, bins (crates) on and beside it.
    for x in (RX - 1.0, RX + 1.0):
        c = L.load(L.RESTAURANT, "kitchencounter_straight_A.gltf", (x, 2.2, 0.16), 0.0, 1.0, tag="counter")
        L.stretch(c, 1.0, 0.5, 1.1)
        L.recolor(c, WOOD)
    for x in (RX - 1.4, RX + 0.2):
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (x, 2.3, 1.26), 0.0, 0.5, tag="rice_bin"),
                  (0.42, 0.30, 0.16))


def _rice_stock(x0, n):
    # Crates stacked by the rice-shop door, standing in for rice sacks.
    for i in range(n):
        x, z = x0 + (i % 2) * 0.85, 0.0 if i < 2 else 0.8
        L.recolor(L.load(L.RESTAURANT, "crate.gltf", (x + (0.4 if z else 0), -0.6, z), 0.1 * i, 0.5,
                         tag="rice_sack"), (0.35, 0.20, 0.09))


def _street(variant):
    snow = variant in SNOW
    ground = SNOWY if snow else STONE
    if variant == 'bg.title':
        # Quay along the river; the camera stands on the far bank.
        L.plane("quay", (60, 16), (0, 5.0, 0), (0, 0, 0), ground)
        L.box("quay_wall", (60, 0.6, 1.4), (0, -3.3, -0.5), (0.22, 0.21, 0.20))
        L.plane("water", (80, 40), (0, -23.0, -0.9), (0, 0, 0), (0.03, 0.05, 0.10))
    else:
        L.plane("street", (60, 20), (0, 0.0, 0), (0, 0, 0), ground)
    pawn = ('open' if variant in OPEN else 'shut')
    _shopfront("pawn", PX, ('shut', pawn, 'shut'), WOOD, snow)
    if variant == 'illus.ev.1938.rice_line':
        rice = (None, None, None)
    elif variant in DUSK + NIGHT:
        rice = ('shut', 'shut', 'shut')
    else:
        rice = ('shut', None, 'shut')
    _shopfront("rice", RX, rice, PLASTER, snow)
    if variant != 'bg.title':
        _house("house_l", -6.8, W, 5.6, 0.0, D, snow)
    _house("house_r", 13.4, W, 5.2, 0.4, D, snow)
    # Back row for the skyline (right of the title only, the left stays sky).
    for x, h in ((3.5, 7.4), (10.0, 6.8), (16.5, 7.8)):
        _house("house_back", x, 6.0, h, D + 2.5, 5.0, snow)


def _props(variant):
    if variant == 'illus.ev.1938.rice_line':
        _rice_counter()
        _rice_stock(RX + 3.6, 3)
    elif variant == 'illus.ev.1940.rice_notice':
        _rice_stock(RX + 1.4, 3)
    elif variant in ('illus.ky.needy_neighbors', 'illus.es.shopfront'):
        # Bench under the pawnshop eave where the queue would wait.
        L.recolor(L.load(L.CITY, "bench.gltf", (PX - 4.2, -0.9, 0), 0.0, 1.0, tag="bench"), WOOD)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # From the far bank, level, the shop on the right half; shift_y lifts the frame (see _camera).
    'bg.title': ((PX - 5.5, -18.0, 1.5), (PX - 5.5, 0.0, 1.5), 35),
    'illus.es.shopfront': ((PX + 2.5, -9.0, 2.6), (PX, 0.0, 3.2), 30),
    'illus.ky.needy_neighbors': ((PX - 4.5, -7.0, 1.8), (PX + 0.5, 0.0, 1.8), 30),
    'illus.ev.1938.levy_call': ((PX + 0.6, -3.2, 2.0), (PX + 0.4, 0.0, 1.9), 32),
    'illus.ev.1938.police_check': ((PX + 3.5, -6.0, 1.7), (PX - 0.5, 0.0, 1.7), 30),
    'illus.ev.1938.rice_line': ((RX - 1.2, -5.5, 2.0), (RX + 0.3, 2.0, 1.5), 28),
    'illus.ev.1939.year_debt': ((PX - 2.8, -6.5, 1.6), (PX + 0.3, 0.0, 2.4), 28),
    'illus.ev.1940.curfew': ((PX + 5.5, -5.0, 1.8), (PX, 0.0, 2.0), 28),
    'illus.ev.1940.levy_rename': ((PX - 0.9, -2.8, 1.9), (PX - 0.6, 0.0, 1.9), 34),
    'illus.ev.1940.rice_notice': ((RX - 4.5, -4.5, 1.8), (RX - 2.6, 0.0, 2.0), 30),
    'illus.fa.1938.door_fine': ((PX + 1.1, -2.2, 1.5), (PX + 1.0, 0.0, 1.5), 35),
    'illus.fa.any.night_knock': ((PX - 3.0, -5.0, 1.2), (PX + 0.3, 0.0, 1.5), 28),
}


def _camera(variant):
    c = L.camera(*CAMS[variant])
    if variant == 'bg.title':
        # Level camera, frame centre raised to z~4.8 at the shop (shift in image widths, 18.5 m wide there),
        # so the roof ridge sits about a third down and the water fills the bottom.
        c.data.shift_y = 0.18


def _sky(rgb, strength):
    L.emit_plane("sky", (120, 50), (0, 40.0, 12), (math.radians(90), 0, 0), rgb, strength)


def _lights(variant, toon):
    if variant in NIGHT:
        _sky((0.02, 0.03, 0.09), 1.0)
        L.world((0.03, 0.04, 0.10), 0.15 if toon else 0.7)
        # Moonlight from the front left (light only, the moon model is missing).
        L.light('SUN', (0, 0, 10), 0.8, (0.55, 0.65, 1.0), rot=(math.radians(55), 0, math.radians(-30)))
        if variant == 'bg.title':
            # Oil lamps in the open door and the upper storey, their glow on the water, a few lit houses.
            L.light('POINT', (PX, 1.4, 2.0), 220, (1.0, 0.62, 0.28), size=0.2)
            L.light('POINT', (PX + 1.5, -0.2, G + 1.4), 70, (1.0, 0.62, 0.28), size=0.2)
            for x, y in ((PX - 0.4, -5.0), (PX + 1.2, -8.0)):
                L.light('POINT', (x, y, -0.6), 25, (1.0, 0.60, 0.25), size=0.15)
            for x in (RX + 1.0, 13.0):
                L.light('POINT', (x, -0.4, 2.2), 30, (1.0, 0.70, 0.35), size=0.15)
        elif variant == 'illus.ev.1939.year_debt':
            # Lamp inside the open door, red year-end lanterns either side (light only).
            L.light('POINT', (PX, 1.4, 2.0), 160, (1.0, 0.62, 0.28), size=0.2)
            for s in (-1, 1):
                L.light('POINT', (PX + s * 1.6, -0.6, 3.0), 45, (1.0, 0.30, 0.18), size=0.2)
        else:
            # Paper lantern set on the ground by the shut door (light only).
            L.light('POINT', (PX + 0.7, -0.7, 0.35), 50, (1.0, 0.62, 0.28), size=0.15)
    elif variant in DUSK:
        _sky((1.0, 0.55, 0.25), 1.5)
        L.world((0.50, 0.32, 0.22), 0.5)
        # Low sun down the street from the right.
        L.light('SUN', (0, 0, 6), 3.0, (1.0, 0.55, 0.28), rot=(math.radians(72), 0, math.radians(110)))
        L.light('AREA', (PX + 2.0, -5.0, 3.5), 80, (1.0, 0.80, 0.60), rot=(math.radians(45), 0, 0), size=5)
        # Watchman's lantern in the street (light only).
        L.light('POINT', (PX + 2.6, -2.0, 1.1), 30, (1.0, 0.62, 0.28), size=0.15)
    else:
        _sky((0.80, 0.86, 0.92), 2.0)
        L.world((0.80, 0.80, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (PX, -6.0, 4.0), 260, (1.0, 0.97, 0.92), rot=(math.radians(50), 0, 0), size=6)
        if variant in ('illus.ev.1938.rice_line', 'illus.ev.1940.rice_notice'):
            L.light('AREA', (RX, 1.0, G - 0.2), 120, (1.0, 0.90, 0.75), size=3)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _street(variant)
    _props(variant)
    _camera(variant)
    _lights(variant, toon)
