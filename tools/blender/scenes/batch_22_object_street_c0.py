# Street props, batch 22: four sprites with transparent backgrounds for the old-town map and the card stage.
# prop.bench (26x12): wooden bench next to the letter-writer's stall at the market.
# prop.boat (48x22): wupeng boat on the river, with a boatman in a bamboo hat at the stern holding the scull.
# prop.lantern_post (16x34): wooden lantern post on a stone base, with a lit lantern hanging at the top.
# prop.rice_sacks (20x16): three rice sacks piled together.
# Missing models: no registered pack has these. Red line 1 forbids scripted stand-ins, so they are left out.
# They are already on PROPS_NEEDED.md: wupeng boat and scull (乌篷船), boatman (过路船工), wooden lantern
# post (木灯杆), paper lantern (纸灯笼), rice sacks (米袋). Until those models are registered, prop.boat,
# prop.lantern_post and prop.rice_sacks render only their shell (water or ground) with their own camera and
# light. Not used: the KayKit streetlight is a modern iron lamp, and crate_* are wooden crates, not sacks.
# Stand-in not yet listed on PROPS_NEEDED.md: City bench.gltf, recoloured dark wood, stands in for the
# backless wooden bench (长凳). It is 0.4 x 0.15 x 0.1 units (city-block scale), so it is scaled x4.
# Add it to the 长凳 row or drop it.
# The composition does not come from the creator's sketch yet (BLENDER_PIPELINE.md sections 1.2 and 1.3).
# bl_lib has no place()/FURN/REST, so models load with L.load(L.CITY, ...).
# Register in scenes/__init__.py, or render.py rejects --scene. Add the import of
# batch_22_object_street_c0 and the SCENES entry "batch_22_object_street_c0": batch_22_object_street_c0.
# render.py only reads SIZE, and SIZE is the bench size. Render the other variants with --size SIZES[variant]
# (48x22, 16x34, 20x16), or teach render.py to use SIZES.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Only models from registered KayKit packs are loaded and no images, so check_sources() has nothing to reject.
# NOT YET RENDERED: the session that produced this file was not allowed to write files or run Blender.
# Framing, light, the bench's facing direction and its scale are unchecked. Render every variant before use.
import math

import bl_lib as L

SIZE = (26, 12)
VARIANTS = ('prop.bench', 'prop.boat', 'prop.lantern_post', 'prop.rice_sacks',)
IDS = {'prop.bench': 'prop.bench', 'prop.boat': 'prop.boat', 'prop.lantern_post': 'prop.lantern_post',
       'prop.rice_sacks': 'prop.rice_sacks'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('prop.lantern_post',)
DUSK = ('prop.boat',)

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height).
SPEC = {
    'prop.bench': ((26, 12), 2.0, 0.25),
    'prop.boat': ((48, 22), 9.0, 0.6),
    'prop.lantern_post': ((16, 34), 3.8, 1.7),
    'prop.rice_sacks': ((20, 16), 1.8, 0.45),
}
SIZES = {v: s[0] for v, s in SPEC.items()}

WOOD = (0.20, 0.11, 0.05)
STONE = (0.30, 0.29, 0.26)
EARTH = (0.16, 0.12, 0.08)
WATER = (0.05, 0.09, 0.10)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _bench():
    # The flagstone ground only catches the shadow; the sprite is cut out.
    L.plane("ground", (6, 6), (0, 0, 0), (0, 0, 0), STONE)
    L.recolor(L.load(L.CITY, "bench.gltf", (0, 0, 0), 0.0, 4.0, tag="bench"), WOOD)


def _boat():
    # River surface only. The boat, scull and boatman have no model (PROPS_NEEDED: 乌篷船, 过路船工).
    L.plane("water", (20, 12), (0, 0, 0), (0, 0, 0), WATER)


def _lantern_post():
    # Street ground only. The post, stone base and lantern have no model (PROPS_NEEDED: 木灯杆, 纸灯笼).
    L.plane("ground", (6, 6), (0, 0, 0), (0, 0, 0), STONE)


def _rice_sacks():
    # Packed-earth ground only. The sacks have no model (PROPS_NEEDED: 米袋).
    L.plane("ground", (6, 6), (0, 0, 0), (0, 0, 0), EARTH)


BUILD = {
    'prop.bench': _bench,
    'prop.boat': _boat,
    'prop.lantern_post': _lantern_post,
    'prop.rice_sacks': _rice_sacks,
}


def build(variant, toon=True):
    (w, h), extent, height = SPEC[variant]
    BUILD[variant]()
    # Blender's sensor (36 mm) fits the longer image side, so the lens follows from distance and extent.
    if variant == 'prop.boat':
        # Long, low side view across the river, slightly from above.
        dist = extent * 2.2
        L.camera((0.0, -dist, height + dist * 0.25), (0.0, 0.0, height), 36.0 * dist / extent)
    elif variant == 'prop.lantern_post':
        # Straight on, at eye level with the middle of the post.
        dist = extent * 2.5
        L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
    else:
        # 3/4 view from above, from the front right.
        dist = extent * 2.4
        L.camera((dist * 0.45, -dist * 0.75, height + dist * 0.5), (0.0, 0.0, height), 36.0 * dist / extent)
    if variant in NIGHT:
        # Night: very low ambient light, a warm point light where the lantern hangs (2.4 units up),
        # and a cool moon from the left.
        L.world((0.10, 0.11, 0.16), 0.15 if toon else 0.7)
        L.light('POINT', (0.0, -0.3, 2.4), 60 if toon else 120, (1.0, 0.62, 0.30), size=0.15)
        L.light('SUN', (0, 0, 6), 0.4, (0.55, 0.65, 0.95), rot=(math.radians(55), 0, math.radians(-60)))
    elif variant in DUSK:
        # Dusk: a low orange sun from behind the camera on the left, across the water.
        L.world((0.45, 0.36, 0.30), 0.3 if toon else 0.4)
        L.light('SUN', (0, 0, 6), 2.2, (1.0, 0.68, 0.40), rot=(math.radians(70), 0, math.radians(-30)))
    elif toon:
        L.world((0.55, 0.50, 0.45), 0.3)
        # Points along (+x, +y, -z): from the upper left, behind the camera.
        L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-40)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        r = extent * 1.8
        L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68),
                rot=(math.radians(50), 0, math.radians(-40)), size=extent)
