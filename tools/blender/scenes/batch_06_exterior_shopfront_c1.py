# batch_06_exterior_shopfront_c1.py
# NOT RENDERED: this file was not written to disk, Blender was not run, and render.py's check_sources() was not run on it.
# To use it: save as tools/blender/scenes/batch_06_exterior_shopfront_c1.py and register it in scenes/__init__.py
# (add it to the `from . import ...` line and the SCENES dict), or render.py rejects --scene.
# Shopfront exterior, batch 06 part 2: five 64x48 card illustrations of the 德厚当 front. It reuses the street,
# shop shell and door leaves of batch_06_exterior_shopfront_c0 with the same coordinates: street on -y, shop
# fronts face -y at y=0, pawnshop centred on x=0, door bays at x=-2, 0, 2.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: crossed seal strips, blank signboard / name plaque, lattice window, red
# couplets, red paper lanterns, the new-rules notice, the paper slip on the door frame, willow tree, and
# Shen Ruhua (short padded jacket). Lanterns are light only. Until those are registered, each variant shows
# only its setting (shut, open or snowed-in front), with its own framing and lighting.
# The composition does not come from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Only bench.gltf, trash_A.gltf, bush.gltf (City pack) and door_A.gltf (Restaurant pack, via c0) are loaded.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Cameras are framed for 4:3.
import math

import bl_lib as L

from . import batch_06_exterior_shopfront_c0 as S

SIZE = (64, 48)
VARIANTS = ('illus.fa.any.shop_sealed', 'illus.gl.1938.keep_shop', 'illus.gl.1939.quiet_year',
            'illus.gl.1940.stand_rules', 'illus.lf.1940.door_paper',)
IDS = {'illus.fa.any.shop_sealed': 'illus.fa.any.shop_sealed', 'illus.gl.1938.keep_shop': 'illus.gl.1938.keep_shop',
       'illus.gl.1939.quiet_year': 'illus.gl.1939.quiet_year',
       'illus.gl.1940.stand_rules': 'illus.gl.1940.stand_rules',
       'illus.lf.1940.door_paper': 'illus.lf.1940.door_paper'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

NIGHT = ('illus.gl.1939.quiet_year',)
SNOW = ('illus.gl.1939.quiet_year',)
# Grey overcast day: the sealed shop and the paper on the door.
GREY = ('illus.fa.any.shop_sealed', 'illus.lf.1940.door_paper')
# Middle plank door swung in (open for business); every other variant has all three bays shut.
OPEN = ('illus.gl.1938.keep_shop', 'illus.gl.1940.stand_rules')

PX = S.PX


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in GREY:
        return ((0, 0.16), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _street(variant):
    snow = variant in SNOW
    L.plane("street", (60, 20), (0, 0.0, 0), (0, 0, 0), S.SNOWY if snow else S.STONE)
    mid = 'open' if variant in OPEN else 'shut'
    S._shopfront("pawn", PX, ('shut', mid, 'shut'), S.WOOD, snow)
    # Neighbours either side (massing only), a back row for the skyline in the wide shots.
    S._house("house_l", PX - 6.8, S.W, 5.6, 0.0, S.D, snow)
    S._house("house_r", PX + 6.8, S.W, 5.2, 0.4, S.D, snow)
    for x, h in ((PX - 3.5, 7.6), (PX + 3.5, 7.2)):
        S._house("house_back", x, 6.0, h, S.D + 2.5, 5.0, snow)


def _props(variant):
    if variant == 'illus.gl.1938.keep_shop':
        # Bench under the eave beside the open door.
        L.recolor(L.load(L.CITY, "bench.gltf", (PX - 2.2, -0.9, 0), 0.0, 1.0, tag="bench"), S.WOOD)
    elif variant == 'illus.fa.any.shop_sealed':
        # Rubbish left at the shut door of a shop nobody tends.
        L.tone(L.load(L.CITY, "trash_A.gltf", (PX + 2.4, -0.7, 0), 0.4, 0.8, tag="trash"), sat=0.3, val=0.7)
    elif variant == 'illus.gl.1940.stand_rules':
        # Green by the door where the willow should stand (bush only, the willow is a missing model).
        L.tone(L.load(L.CITY, "bush.gltf", (PX - 3.6, -1.2, 0), 0.0, 1.2, tag="bush"), sat=0.7, val=0.9)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Straight on, slightly high: three shut bays filling the width (the strips would cross the middle one).
    'illus.fa.any.shop_sealed': ((PX, -6.2, 2.4), (PX, 0.0, 1.9), 32),
    # Three-quarter view from the left, the whole two-storey front with the open door.
    'illus.gl.1938.keep_shop': ((PX - 4.0, -8.5, 2.2), (PX + 0.3, 0.0, 3.0), 30),
    # Low from the right in the snow, eaves and the lantern glow in frame.
    'illus.gl.1939.quiet_year': ((PX + 3.2, -6.5, 1.3), (PX, 0.0, 2.6), 28),
    # Low from the right, the open door and the post where the notice would hang.
    'illus.gl.1940.stand_rules': ((PX + 4.5, -6.0, 1.5), (PX - 0.6, 0.0, 2.2), 30),
    # Close on the post between the middle and right bays, raking light across the planks.
    'illus.lf.1940.door_paper': ((PX + 0.5, -2.0, 1.8), (PX + 1.0, 0.0, 1.8), 40),
}


def _sky(rgb, strength):
    L.emit_plane("sky", (120, 50), (0, 40.0, 12), (math.radians(90), 0, 0), rgb, strength)


def _lights(variant, toon):
    if variant in NIGHT:
        _sky((0.02, 0.03, 0.09), 1.0)
        L.world((0.04, 0.05, 0.10), 0.2 if toon else 0.8)
        # Cold snow light from the front left.
        L.light('SUN', (0, 0, 10), 0.9, (0.60, 0.70, 1.0), rot=(math.radians(55), 0, math.radians(-30)))
        # Red lanterns either side of the door (light only), a lamp behind the shut planks.
        for s in (-1, 1):
            L.light('POINT', (PX + s * 1.0, -0.6, 3.0), 60, (1.0, 0.28, 0.16), size=0.2)
        L.light('POINT', (PX, 1.2, 2.0), 40, (1.0, 0.62, 0.28), size=0.2)
    elif variant in GREY:
        _sky((0.62, 0.65, 0.70), 1.6)
        L.world((0.55, 0.57, 0.60), 0.8)
        L.light('SUN', (0, 0, 6), 1.8, (0.86, 0.90, 0.96), rot=(math.radians(50), 0, math.radians(-15)))
        if variant == 'illus.lf.1940.door_paper':
            # Raking light from the left across the planks and the post.
            L.light('AREA', (PX - 2.0, -1.5, 2.2), 90, (0.95, 0.95, 0.92),
                    rot=(math.radians(70), 0, math.radians(-70)), size=1.5)
        else:
            L.light('AREA', (PX, -6.0, 4.0), 160, (0.92, 0.94, 0.98), rot=(math.radians(50), 0, 0), size=6)
    else:
        _sky((0.80, 0.86, 0.92), 2.0)
        L.world((0.80, 0.80, 0.78), 0.9)
        if variant == 'illus.gl.1940.stand_rules':
            # Spring morning, low sun from the right.
            L.light('SUN', (0, 0, 6), 3.2, (1.0, 0.92, 0.78), rot=(math.radians(55), 0, math.radians(35)))
        else:
            L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (PX, -6.0, 4.0), 240, (1.0, 0.97, 0.92), rot=(math.radians(50), 0, 0), size=6)
        # Lamp inside the open door.
        L.light('POINT', (PX, 1.4, 2.0), 60, (1.0, 0.70, 0.40), size=0.2)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _street(variant)
    _props(variant)
    L.camera(*CAMS[variant])
    _lights(variant, toon)
