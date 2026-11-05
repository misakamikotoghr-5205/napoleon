# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Country road exterior, batch 24: three 64x48 card illustrations on the earth road leading out of Qingxi.
# One road runs straight away from the camera along +y between paddy fields with low earth ridges, a drainage
# ditch on its left; the town's white-wall black-tile houses stand at the road's town end. Camera, light,
# weather (snow) and a few props change per variant.
# illus.ev.1938.road_pass: the checkpoint at the town's edge, houses close on both sides of the road.
# illus.ev.1939.snow_road: the road outside town buried under snow, empty, the town only a grey line far off.
# illus.ev.any.demand_return: dusk on the road, low sun behind the far town; the youth would be small, far off.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: wooden barrier pole / road block, sentry box, every person (guards without
# badges, travellers holding up passes, the tired youth in a short jacket with a bundle on his back), cloth
# bundles, passes, bare trees. Until those are registered, the cards show only their setting and the few
# props below.
# Stand-ins that are what they look like: table_small and chair_stool_wood for the pass inspection table and
# stool, crate / crate_lid for goods set down at the check (as in batch_16).
# Architecture (houses, roofs, snow on roofs) and ground (fields, ridges, road, ruts, ditch water, snow banks)
# are shell built from L.box / L.plane. Modern KayKit city props (streetlight, cars, hydrant, bench, traffic
# lights, asphalt road tiles) are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Cameras are framed for 4:3. Orientation: the road centre line is x=0, running along +y away from the
# camera; house massing is symmetric, so it needs no rotation.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.ev.1938.road_pass', 'illus.ev.1939.snow_road', 'illus.ev.any.demand_return',)
IDS = {'illus.ev.1938.road_pass': 'illus.ev.1938.road_pass', 'illus.ev.1939.snow_road': 'illus.ev.1939.snow_road',
       'illus.ev.any.demand_return': 'illus.ev.any.demand_return'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

SNOW = ('illus.ev.1939.snow_road',)
DUSK = ('illus.ev.any.demand_return',)
NIGHT = ()

RW = 3.2        # road width
DITCH_X = -3.4  # drainage ditch centre, left of the road
HW = 4.4        # house front width
HD = 4.0        # house depth
HH = 3.4        # house eaves height
ROOF = math.radians(28)

WOOD_DARK = (0.10, 0.055, 0.03)
PLANK = (0.16, 0.09, 0.045)
CRATE = (0.35, 0.20, 0.09)
CRATE_LID = (0.42, 0.25, 0.11)
PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
TILE = (0.07, 0.07, 0.08)
STONE = (0.40, 0.38, 0.35)
SNOW_RGB = (0.86, 0.88, 0.92)
SNOW_SHADE = (0.72, 0.75, 0.82)
FIELD = (0.24, 0.22, 0.13)      # winter stubble
RIDGE = (0.30, 0.24, 0.16)
ROAD = (0.38, 0.30, 0.20)       # packed earth
RUT = (0.27, 0.21, 0.14)
WATER_RGB = (0.08, 0.11, 0.13)

# y of the nearest pair of town houses along the road, per variant.
TOWN_Y = {'illus.ev.1938.road_pass': 3.0, 'illus.ev.1939.snow_road': 46.0, 'illus.ev.any.demand_return': 34.0}


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.12), (0.08, 0.42), (0.30, 0.72), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, snow):
    # Two tilted slabs of shell (pitched roof, ridge along y, parallel to the road); rotation about y lifts
    # the outer edges. With snow, a thinner white slab lies on each tile slab.
    rise = (w / 2) * math.tan(ROOF)
    slope = w / 2 / math.cos(ROOF) + 0.5
    for s, x in ((-1, cx - w / 4), (1, cx + w / 4)):
        b = L.box(name, (slope, d + 0.6, 0.18), (x, y0 + d / 2, z + rise / 2), TILE)
        b.rotation_euler[1] = s * ROOF
        if snow:
            c = L.box(name + "_snow", (slope - 0.25, d + 0.4, 0.1), (x, y0 + d / 2, z + rise / 2 + 0.14), SNOW_RGB)
            c.rotation_euler[1] = s * ROOF


def _house(name, cx, y0, wall, snow, h=HH):
    """House massing with its long side on the road; doors and windows wait for the missing house module."""
    L.box(name + "_body", (HW, HD, h), (cx, y0 + HD / 2, h / 2), wall)
    L.box(name + "_plinth", (HW + 0.05, HD + 0.05, 0.35), (cx, y0 + HD / 2, 0.17), STONE)
    _roof(name + "_roof", cx, HW, y0, HD, h, snow)


def _ground(variant, snow):
    L.plane("field", (140, 160), (0, 50, 0), (0, 0, 0), SNOW_RGB if snow else FIELD)
    # Packed earth road (snow: only a slightly sunken grey track shows where it runs).
    L.box("road", (RW, 150, 0.03), (0, 50, 0.015), SNOW_SHADE if snow else ROAD)
    if not snow:
        for x in (-0.7, 0.7):
            L.box("rut", (0.28, 150, 0.035), (x, 50, 0.02), RUT)
        L.plane("ditch", (1.2, 150), (DITCH_X, 50, 0.01), (0, 0, 0), WATER_RGB)
    else:
        # Drifts banked along both road edges, the ditch filled level.
        for s in (-1, 1):
            L.box("snow_bank", (0.9, 150, 0.22), (s * (RW / 2 + 0.45), 50, 0.11), SNOW_RGB)
    # Field ridges across the paddies on both sides, receding into the distance.
    y = -6.0
    while y < 110.0:
        for s in (-1, 1):
            L.box("ridge", (30.0, 0.35, 0.18), (s * (RW / 2 + 1.6 + 15.0), y, 0.09), SNOW_RGB if snow else RIDGE)
        y += 6.0 if y < 30 else 10.0


def _town(variant, snow):
    y0 = TOWN_Y[variant]
    walls = (PLASTER, PLASTER_OLD)
    for i in range(4):
        y = y0 + i * (HD + 0.8)
        for s in (-1, 1):
            _house("house", s * (RW / 2 + 1.0 + HW / 2), y, walls[(i + (s > 0)) % 2], snow, HH + 0.4 * (i % 2))
    # Second row behind for the skyline.
    for i, cx in enumerate((-14.0, -9.0, 9.0, 14.0)):
        _house("house_back", cx, y0 + 4.0 + 2.0 * (i % 2), walls[i % 2], snow, HH + 1.2)


def _props(variant):
    if variant == 'illus.ev.1938.road_pass':
        # Pass inspection table and stool at the right road edge by the first house; goods set down by it.
        L.recolor(L.load(L.FURNITURE, "table_small.gltf", (RW / 2 + 0.2, 1.6, 0), 0.0, 1.0, tag="check_table"),
                  WOOD_DARK)
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (RW / 2 + 0.9, 2.2, 0), 0.3, 1.0, tag="stool"),
                  PLANK)
        for loc, rot, lid in (((-0.9, 0.6, 0), 0.15, True), ((-1.3, 1.3, 0), -0.25, False)):
            L.recolor(L.load(L.RESTAURANT, "crate.gltf", loc, rot, 0.45, tag="goods_crate"), CRATE)
            if lid:
                L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (loc[0], loc[1], 0.8 * 0.45), rot, 0.45,
                                 tag="goods_crate"), CRATE_LID)


def _sky(rgb, strength):
    L.emit_plane("sky", (220, 80), (0, 130.0, 20), (math.radians(90), 0, 0), rgb, strength)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Out on the road looking back at the checkpoint and the first houses of the town.
    'illus.ev.1938.road_pass': ((2.6, -6.0, 1.7), (0.4, 3.0, 1.2), 28),
    # Standing in the snow, the buried road running off straight to a faint town on the horizon.
    'illus.ev.1939.snow_road': ((1.2, -6.0, 1.7), (0.0, 40.0, 0.9), 30),
    # Low on the road towards the town against the dusk sky; the figure would stand small mid-road.
    'illus.ev.any.demand_return': ((-0.8, -6.0, 1.3), (0.2, 34.0, 1.8), 34),
}


def _lights(variant, toon):
    if variant in DUSK:
        _sky((1.0, 0.55, 0.25), 1.5)
        L.world((0.50, 0.34, 0.24), 0.45 if toon else 0.9)
        # Low sun behind the town, slightly left: the road and the near sides of things fall into shadow.
        L.light('SUN', (0, 0, 8), 2.6, (1.0, 0.55, 0.28), rot=(math.radians(80), 0, math.radians(160)))
        L.light('AREA', (0.0, -8.0, 4.0), 60, (0.75, 0.62, 0.70), rot=(math.radians(55), 0, 0), size=6)
    elif variant in SNOW:
        _sky((0.72, 0.75, 0.80), 1.4)
        L.world((0.72, 0.76, 0.84), 0.9)
        # Heavy overcast: weak cool sun, broad fill off the snow.
        L.light('SUN', (0, 0, 8), 1.4, (0.90, 0.94, 1.0), rot=(math.radians(35), 0, math.radians(-20)))
        L.light('AREA', (0.0, -8.0, 5.0), 200, (0.92, 0.95, 1.0), rot=(math.radians(50), 0, 0), size=8)
    else:
        _sky((0.74, 0.78, 0.82), 1.8)
        L.world((0.72, 0.72, 0.72), 0.85)
        # Grey-bright winter day, 1938.
        L.light('SUN', (0, 0, 8), 3.0, (1.0, 0.95, 0.86), rot=(math.radians(45), 0, math.radians(-35)))
        L.light('AREA', (0.0, -8.0, 4.5), 140, (0.95, 0.95, 0.95), rot=(math.radians(45), 0, 0), size=6)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    snow = variant in SNOW
    _ground(variant, snow)
    _town(variant, snow)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
