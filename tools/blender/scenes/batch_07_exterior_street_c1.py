# NOT YET RENDERED: writing files and running Blender were not permitted in the session that produced this
# file, so framing, light and model scales are unchecked. Render every variant before use.
# Street exterior, batch 07 (second module): three 64x48 card illustrations on the same bridge-head street
# of Qingxi town as batch_07_exterior_street_c0, whose street shell (_street) and sky (_sky) are reused so
# the cards match the backdrops.
# illus.st.gamble: a low gambling table on the street at dusk, stake plate and dice bowl, stools around,
# lit by lanterns (light only).
# illus.st.stall: a blue cloth spread on the flagstones in front of a shut shop, bowls and a plate on it.
# illus.st.write_letters: a small square table at the street corner with two stools, overcast day.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out and belong on PROPS_NEEDED.md: small spinning wheel (roulette), copper coins, paper lanterns, cloth
# awning, small trinkets / jewellery, writing brush, inkstone, letter paper (pseudo-characters only), and
# every person (onlookers in silhouette, Shen Ruhua, the old woman, a passer-by in a long gown). Lanterns
# are light only. Until those are registered, the cards show only their setting and the props below.
# Stand-ins that are what they look like: table_low / table_small and wooden stools as street furniture,
# rug_rectangle_A recoloured indigo as the stall's ground cloth, bowl / bowl_small / plate as porcelain.
# Modern KayKit city props (streetlight, cars, hydrant, bench, traffic lights) are deliberately not used.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Orientation as in c0: shop fronts face -y at y=0, the street runs along x on -y.
import math

import bl_lib as L

from . import batch_07_exterior_street_c0 as S

SIZE = (64, 48)
VARIANTS = ('illus.st.gamble', 'illus.st.stall', 'illus.st.write_letters',)
IDS = {'illus.st.gamble': 'illus.st.gamble', 'illus.st.stall': 'illus.st.stall',
       'illus.st.write_letters': 'illus.st.write_letters'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

DUSK = ('illus.st.gamble',)
OVERCAST = ('illus.st.write_letters',)

PORCELAIN = (0.80, 0.82, 0.84)
INDIGO = (0.06, 0.12, 0.32)

GAMBLE_AT = (-4.6, -2.0)
STALL_AT = (1.6, -1.2)
LETTER_AT = (5.2, -1.6)


def ramp(variant):
    if variant in DUSK:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _gamble():
    x, y = GAMBLE_AT
    L.recolor(L.load(L.FURNITURE, "table_low.gltf", (x, y, 0), 0.0, 1.0, tag="gamble_table"), S.WOOD)
    L.recolor(L.load(L.RESTAURANT, "plate.gltf", (x - 0.25, y, 0.42), 0.0, 1.0, tag="stake_plate"),
              (0.62, 0.58, 0.50))
    L.recolor(L.load(L.RESTAURANT, "bowl.gltf", (x + 0.3, y + 0.1, 0.42), 0.0, 1.0, tag="dice_bowl"), PORCELAIN)
    for dx, dy, r in ((-1.0, 0.2, 0.3), (1.0, -0.1, -0.2), (0.1, 0.9, 0.1)):
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (x + dx, y + dy, 0), r, 0.9, tag="stool"),
                  S.WOOD_DARK)


def _stall():
    x, y = STALL_AT
    L.recolor(L.load(L.FURNITURE, "rug_rectangle_A.gltf", (x, y, 0.01), 0.0, 0.8, tag="stall_cloth"), INDIGO)
    for k, dx, dy in (("bowl.gltf", -0.45, 0.1), ("bowl_small.gltf", 0.0, -0.2), ("plate.gltf", 0.45, 0.15),
                      ("bowl_small.gltf", 0.35, -0.3)):
        L.recolor(L.load(L.RESTAURANT, k, (x + dx, y + dy, 0.03), 0.0, 1.0, tag="stall_ware"), PORCELAIN)


def _letters():
    x, y = LETTER_AT
    L.recolor(L.load(L.FURNITURE, "table_small.gltf", (x, y, 0), 0.0, 1.0, tag="letter_table"), S.WOOD)
    for dx in (-0.85, 0.85):
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (x + dx, y, 0), 0.0, 0.9, tag="stool"),
                  S.WOOD_DARK)


# variant: (camera location, look-at point, lens mm). Card cameras framed for 4:3.
CAMS = {
    'illus.st.gamble': ((-2.4, -5.4, 1.5), (-4.6, -1.6, 0.6), 30),
    'illus.st.stall': ((3.0, -4.4, 1.7), (1.4, -0.8, 0.5), 32),
    'illus.st.write_letters': ((3.2, -4.8, 1.4), (5.4, -1.2, 0.9), 32),
}


def _lights(variant, toon):
    if variant in DUSK:
        S._sky((1.0, 0.55, 0.25), 1.5)
        L.world((0.50, 0.32, 0.22), 0.5)
        L.light('SUN', (0, 0, 6), 2.4, (1.0, 0.55, 0.28), rot=(math.radians(72), 0, math.radians(110)))
        # Two paper lanterns hung over the table (light only), the main light of the card.
        x, y = GAMBLE_AT
        for dx in (-0.7, 0.7):
            L.light('POINT', (x + dx, y + 0.4, 2.2), 70, (1.0, 0.62, 0.28), size=0.15)
    elif variant in OVERCAST:
        S._sky((0.62, 0.66, 0.70), 1.6)
        L.world((0.70, 0.72, 0.76), 0.9)
        L.light('SUN', (0, 0, 6), 1.2, (0.88, 0.92, 1.0), rot=(math.radians(30), 0, math.radians(-15)))
        L.light('AREA', (5.0, -6.0, 4.0), 260, (0.92, 0.95, 1.0), rot=(math.radians(50), 0, 0), size=6)
    else:
        S._sky((0.80, 0.86, 0.92), 2.0)
        L.world((0.80, 0.80, 0.78), 0.9)
        L.light('SUN', (0, 0, 6), 3.5, (1.0, 0.96, 0.86), rot=(math.radians(40), 0, math.radians(-20)))
        L.light('AREA', (1.5, -5.0, 4.0), 220, (1.0, 0.97, 0.92), rot=(math.radians(50), 0, 0), size=5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    S._street(variant)
    {'illus.st.gamble': _gamble, 'illus.st.stall': _stall, 'illus.st.write_letters': _letters}[variant]()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
