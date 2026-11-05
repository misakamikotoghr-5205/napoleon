# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Canal exterior, batch 18: five 64x48 card illustrations on one stretch of canal in Qingxi town. Stone
# quay on the near bank (with a muddy reed shore at its downstream end), water, and a row of white-wall
# black-tile houses on a stone quay across the water; camera, light and weather change per variant.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: stone arch bridge, wupeng boat, willows, reeds, bamboo basket, small
# cloth bag, rain streaks, boatman with straw hat and pole, Shen Ruhua (running / crouching). Until those
# are registered, the cards show only their setting and the few props below.
# Stand-ins that are what they look like: KayKit bush for the willow crowns (as in batch_06 c1), toned-down
# restaurant bowls (bowl_dirty / bowl_small / bowl) lying on the mud for the broken pots and jars.
# Architecture (quays, coping, steps, house walls, doors, eaves, roofs), the mud shore and the water surface
# are shell built from L.box / L.plane. Modern KayKit city props are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Orientation: the canal runs along x; near quay edge at y=0 with land on -y (quay top z=0), water on +y at
# z=WATER, far quay edge at y=FAR with house fronts facing -y at y=FAR+HY.
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.fa.1940.spring_rain', 'illus.st.errand', 'illus.st.scavenge', 'illus.gl.1938.low_heat',
            'illus.gl.1940.heat_quiet',)
IDS = {'illus.fa.1940.spring_rain': 'illus.fa.1940.spring_rain', 'illus.st.errand': 'illus.st.errand',
       'illus.st.scavenge': 'illus.st.scavenge', 'illus.gl.1938.low_heat': 'illus.gl.1938.low_heat',
       'illus.gl.1940.heat_quiet': 'illus.gl.1940.heat_quiet'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

RAIN = ('illus.fa.1940.spring_rain',)
DUSK = ('illus.gl.1938.low_heat',)

WATER = -1.0    # water surface
QH = 1.6        # quay wall height below the quay top (z=0)
FAR = 9.0       # far quay edge
HY = 1.2        # far house fronts, back from the far quay edge
D = 5.0         # house depth
HW = 4.4        # house front width
H = 4.2         # eaves height
ROOF = math.radians(28)
SHORE_X = 6.0   # near quay ends here; mud and reed shore beyond (+x)

PLASTER = (0.78, 0.76, 0.70)
PLASTER_OLD = (0.62, 0.60, 0.55)
PLASTER_WET = (0.50, 0.50, 0.48)
TILE = (0.07, 0.07, 0.08)
WOOD_DARK = (0.10, 0.055, 0.03)
STONE = (0.40, 0.38, 0.35)
STONE_LIGHT = (0.50, 0.48, 0.44)
STONE_WET = (0.22, 0.22, 0.21)
MUD = (0.20, 0.15, 0.09)
WATER_RGB = (0.08, 0.12, 0.13)
WATER_RAIN = (0.10, 0.13, 0.14)
WATER_DUSK = (0.20, 0.13, 0.08)


def ramp(variant):
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    if variant in RAIN:
        return ((0, 0.16), (0.08, 0.46), (0.30, 0.76), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z, rgb):
    # Two tilted slabs of shell (pitched roof over a wall box); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, d / 2 / math.cos(ROOF) + 0.5, 0.18), (cx, y, z + rise / 2), rgb)
        b.rotation_euler[0] = s * ROOF


def _house(name, cx, wall, h):
    y0 = FAR + HY
    L.box(name + "_body", (HW, D, h), (cx, y0 + D / 2, h / 2), wall)
    # Dark doorway recess and a pent eave over the ground floor.
    L.box(name + "_door", (1.1, 0.06, 2.1), (cx - 0.8, y0 - 0.02, 1.05), WOOD_DARK)
    b = L.box(name + "_pent", (HW + 0.3, 0.9, 0.12), (cx, y0 - 0.3, 2.85), TILE)
    b.rotation_euler[0] = math.radians(20)
    _roof(name + "_roof", cx, HW, y0, D + 0.6, h, TILE)


def _canal(variant):
    wet = variant in RAIN
    stone = STONE_WET if wet else STONE
    coping = STONE if wet else STONE_LIGHT
    water = WATER_RAIN if wet else WATER_DUSK if variant in DUSK else WATER_RGB
    L.plane("water", (90, 40), (0, FAR / 2, WATER), (0, 0, 0), water)
    # Near quay (-y) up to SHORE_X, then a mud shore sloping into the water.
    L.box("quay", (SHORE_X + 40, 10, QH), ((SHORE_X - 40) / 2, -5.0, -QH / 2), stone)
    L.box("coping", (SHORE_X + 40, 0.35, 0.12), ((SHORE_X - 40) / 2, -0.17, 0.06), coping)
    L.box("quay_wet", (SHORE_X + 40, 0.04, 0.25), ((SHORE_X - 40) / 2, 0.02, WATER + 0.12), STONE_WET)
    shore = L.plane("shore", (40, 8), (SHORE_X + 20, -1.6, WATER + 0.35), (0, 0, 0), MUD)
    shore.rotation_euler[0] = math.radians(-9)
    L.box("bank", (40, 8, QH), (SHORE_X + 20, -8.0, -QH / 2), MUD)
    # Stone steps down to the water near the middle of the quay.
    for i in range(3):
        top = -0.3 * (i + 1)
        L.box("step", (2.0, 0.4 * (i + 1), top + QH), (-1.0, 0.2 * (i + 1), (top - QH) / 2), coping)
    # Far quay and its row of houses facing the water.
    L.box("far_quay", (90, 12, QH), (0, FAR + 6.0, -QH / 2), stone)
    L.box("far_coping", (90, 0.35, 0.12), (0, FAR + 0.17, 0.06), coping)
    walls = (PLASTER_WET, PLASTER_WET) if wet else (PLASTER, PLASTER_OLD)
    for i, cx in enumerate((-18.0, -13.5, -9.0, -4.5, 0.0, 4.5, 9.0, 13.5, 18.0)):
        _house("house", cx, walls[i % 2], H + (0.5 if i % 3 == 1 else 0.0))


def _willow(loc, scale):
    # Willow crown stand-in (bush only, the willow is a missing model).
    L.tone(L.load(L.CITY, "bush.gltf", loc, 0.0, scale, tag="willow_bush"), sat=0.6, val=0.85)


def _props(variant):
    if variant == 'illus.st.scavenge':
        # Broken pots and bowls washed up on the mud shore; the big bowl lies on its side.
        for name, loc, rot, s in (("bowl_dirty.gltf", (7.4, -1.0, WATER + 0.52), 0.4, 1.4),
                                  ("bowl_small.gltf", (8.2, -0.4, WATER + 0.44), 1.3, 1.5),
                                  ("bowl_dirty.gltf", (6.9, -0.2, WATER + 0.40), 2.2, 1.2),
                                  ("bowl.gltf", (8.7, -1.5, WATER + 0.60), 0.9, 1.3)):
            j = L.load(L.RESTAURANT, name, loc, rot, s, tag="debris")
            if name == "bowl.gltf":
                for o in j:
                    if o.parent is None:
                        o.rotation_euler[0] = math.radians(70)
            L.tone(j, sat=0.25, val=0.65)
    elif variant in ('illus.gl.1938.low_heat', 'illus.gl.1940.heat_quiet'):
        for x in (-6.5, 3.5):
            _willow((x, -1.4, 0), 2.2)
        _willow((-11.0, FAR + 0.6, 0), 2.0)
    elif variant == 'illus.st.errand':
        _willow((4.5, -1.3, 0), 2.0)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # High over the near quay, looking down across the rain-dark water to the wet roofs.
    'illus.fa.1940.spring_rain': ((-2.0, -6.0, 6.5), (1.0, FAR + 3.0, 2.8), 30),
    # Low along the near quay looking down the canal: the path she runs along.
    'illus.st.errand': ((-7.5, -3.2, 1.2), (2.0, 1.5, 0.3), 24),
    # Down at the mud shore at the end of the quay.
    'illus.st.scavenge': ((5.2, -4.0, 1.0), (7.8, -0.8, WATER + 0.4), 30),
    # Long view along the canal at dusk.
    'illus.gl.1938.low_heat': ((-12.0, -2.5, 1.8), (4.0, FAR - 1.0, 1.2), 26),
    # Straight across the calm water to the far houses.
    'illus.gl.1940.heat_quiet': ((0.0, -4.5, 1.6), (0.0, FAR + 2.0, 1.4), 28),
}


def _lights(variant, toon):
    if variant in RAIN:
        L.world((0.55, 0.58, 0.62), 0.9)
        L.light('SUN', (0, 0, 6), 0.8, (0.85, 0.90, 1.0), rot=(math.radians(25), 0, math.radians(-10)))
        L.light('AREA', (0.0, -2.0, 6.0), 160, (0.88, 0.92, 1.0), rot=(math.radians(30), 0, 0), size=6)
    elif variant in DUSK:
        L.world((0.45, 0.30, 0.22), 0.6)
        # Low sun down the canal from the west end.
        L.light('SUN', (0, 0, 6), 2.2, (1.0, 0.62, 0.35), rot=(math.radians(78), 0, math.radians(-110)))
        L.light('AREA', (0.0, -3.0, 4.0), 60, (0.85, 0.70, 0.75), rot=(math.radians(40), 0, 0), size=5)
    else:
        L.world((0.80, 0.82, 0.86), 0.9)
        # Sun from the camera side so the far house fronts are lit.
        L.light('SUN', (0, 0, 6), 3.4, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-25)))
        L.light('AREA', (0.0, -3.5, 4.0), 120, (1.0, 0.97, 0.92), rot=(math.radians(40), 0, 0), size=4)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _canal(variant)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
