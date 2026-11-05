# NOT SAVED, NOT YET RENDERED: this session was not allowed to write files or run Blender, so this module
# was not saved or run. Framing, light and model scales are unchecked. Render both variants before use.
# Register in scenes/__init__.py, or render.py rejects --scene: add batch_29_exterior_old_house_c0 to the import
# line and the SCENES entry "batch_29_exterior_old_house_c0": batch_29_exterior_old_house_c0.
# render.py refuses toon renders on Blender 4.2+ unless --allow-new-blender is passed (before check_sources).
# Old Shen house exterior, batch 29: two 64x48 card illustrations of the same place. A white-wall
# black-tile courtyard house on a stone-paved lane: the courtyard wall along the lane with a tile cap, a
# gatehouse (门楼) in the middle with a small tiled hood over the double plank gate and a stone step, the
# main hall behind the wall under a pitched black-tile roof, stepped horse-head gable walls (马头墙) at
# both ends of the hall rising above the roof.
# illus.es.old_house: day, wide three-quarter view from down the lane: wall, gatehouse, roof and both
#   horse-head gables; the right gate leaf stands ajar onto the courtyard.
# illus.bf.any.house_offer: late afternoon, close and low on the gatehouse from the lane, gate shut; the
#   stone step in front is left clear where the buyer stands holding out the envelope.
# Missing models: no registered pack has these, and red line 1 forbids scripted stand-ins, so they are left
# out. All are already on PROPS_NEEDED.md: the moon gate (月洞门; a round opening cannot be cut with
# L.box, so the courtyard wall is left plain), paper lanterns (纸灯笼; only a warm point light hangs where
# the one at the gate goes in house_offer), willow (柳树), the thick envelope (信封和礼封), the gatehouse
# brick hood (宅院门楼) and the house module (白墙黑瓦民居). The buyer in hat and long gown
# (礼帽长衫中年男, PROPS_NEEDED.md characters) is a custom character, left out too, so house_offer shows only
# its setting until he is registered.
# Stand-ins, as listed in PROPS_NEEDED.md: Restaurant door_A (stretched, recoloured) for the plank gate
# leaves (木板门), as in batch_13 / batch_14 / batch_16 / batch_20. KayKit City bush as greenery at the foot
# of the wall. Modern KayKit city props (cars, street lights, hydrants) are deliberately not used.
# Architecture (lane, step, walls, gatehouse, hall, roofs, gables, tile caps) is shell built from L.box /
# L.plane, only until the house and gatehouse modules arrive.
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md sections 1.2 and 1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.RESTAURANT / L.CITY, ...).
# No dense meshes (book_set etc.) are loaded, so nothing needs L.noline.
# Only models from a registered KayKit pack are loaded and no images, so check_sources() has nothing to reject.
# Orientation: the house faces -y (the camera side); the courtyard wall's lane face is at y=WY-WT/2, the
# lane runs along x. door_A runs from its hinge along +x at rot_z=0 (glTF bounds x 0..1.6, height 2.8).
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ('illus.bf.any.house_offer', 'illus.es.old_house',)
IDS = {'illus.bf.any.house_offer': 'illus.bf.any.house_offer', 'illus.es.old_house': 'illus.es.old_house'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

DUSK = ('illus.bf.any.house_offer',)
NIGHT = ()
# The right gate leaf stands ajar onto the courtyard; otherwise the gate is shut.
OPEN = ('illus.es.old_house',)

WY = 0.0        # courtyard wall centre line
WT = 0.4        # wall thickness
WL = 16.0       # courtyard wall length along the lane
WH = 3.0        # courtyard wall height
GW = 3.4        # gatehouse width
GH = 4.0        # gatehouse wall height
DW = 1.8        # gate opening width
DH = 2.4        # gate opening height
SH = 0.18       # stone step height
HY = 3.4        # main hall front wall y
HW = 10.0       # main hall width
HD = 6.0        # main hall depth
HH = 4.4        # main hall eaves height
ROOF = math.radians(28)

PLASTER = (0.80, 0.78, 0.72)
PLASTER_OLD = (0.64, 0.62, 0.57)
TILE = (0.06, 0.06, 0.07)
STONE = (0.42, 0.40, 0.36)
STONE_DARK = (0.28, 0.27, 0.25)
PAVING = (0.38, 0.37, 0.34)
YARD = (0.33, 0.31, 0.28)
WOOD = (0.16, 0.09, 0.045)
GATE = (0.10, 0.06, 0.035)
GROUND = (0.24, 0.25, 0.18)
LANTERN = (1.0, 0.55, 0.30)


def ramp(variant):
    if variant in NIGHT:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if variant in DUSK:
        return ((0, 0.12), (0.08, 0.42), (0.30, 0.72), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def _roof(name, cx, w, y0, d, z):
    # Two tilted slabs of shell (pitched roof, ridge along x); rotation about x lifts the +y side.
    rise = (d / 2) * math.tan(ROOF)
    slope = d / 2 / math.cos(ROOF) + 0.5
    for s, y in ((1, y0 + d / 4), (-1, y0 + 3 * d / 4)):
        b = L.box(name, (w + 0.6, slope, 0.18), (cx, y, z + rise / 2), TILE)
        b.rotation_euler[0] = s * ROOF
    return rise


def _ground():
    L.plane("ground", (80, 60), (0, 0, 0), (0, 0, 0), GROUND)
    # Stone-paved lane along the wall; packed-earth courtyard inside it.
    L.box("lane", (60, 5.0, 0.03), (0, WY - WT / 2 - 2.5, 0.015), PAVING)
    L.box("yard", (WL - 0.4, HY - WY, 0.03), (0, (WY + HY) / 2, 0.015), YARD)


def _wall():
    # Courtyard wall either side of the gatehouse: plaster over a stone skirt, a tile cap on top.
    side = (WL - GW) / 2
    for s in (-1, 1):
        cx = s * (GW / 2 + side / 2)
        L.box("yard_wall", (side, WT, WH), (cx, WY, WH / 2), PLASTER if s < 0 else PLASTER_OLD)
        L.box("yard_wall_skirt", (side + 0.02, WT + 0.04, 0.45), (cx, WY, 0.22), STONE_DARK)
        L.box("yard_wall_cap", (side + 0.1, WT + 0.5, 0.2), (cx, WY, WH + 0.1), TILE)
        # Side walls closing the courtyard back to the hall.
        L.box("yard_side", (WT, HY - WY, WH), (s * (WL / 2 - WT / 2), (WY + HY) / 2, WH / 2), PLASTER_OLD)
        L.box("yard_side_cap", (WT + 0.5, HY - WY + 0.1, 0.2), (s * (WL / 2 - WT / 2), (WY + HY) / 2, WH + 0.1),
              TILE)


def _leaf(x, y, w, rot):
    d = L.load(L.RESTAURANT, "door_A.gltf", (x, y, 0.2), rot, 1.0, tag="gate_leaf")
    L.stretch(d, w / 1.6, w / 1.6, (DH - 0.2) / 2.8)
    L.recolor(d, GATE)
    return d


def _gatehouse(variant):
    # Gatehouse wall, taller than the courtyard wall, with the gate opening in the middle.
    pier = (GW - DW) / 2
    for s in (-1, 1):
        cx = s * (DW / 2 + pier / 2)
        L.box("gate_wall", (pier, WT + 0.1, GH), (cx, WY, GH / 2), PLASTER)
        L.box("gate_skirt", (pier + 0.02, WT + 0.14, 0.5), (cx, WY, 0.25), STONE_DARK)
        L.box("gate_post", (0.2, WT + 0.16, DH), (s * (DW / 2 + 0.1), WY, DH / 2), STONE)
    L.box("gate_wall", (DW, WT + 0.1, GH - DH), (0, WY, (GH + DH) / 2), PLASTER)
    L.box("gate_lintel", (DW + 0.4, WT + 0.16, 0.22), (0, WY, DH + 0.11), STONE)
    L.box("threshold", (DW, WT + 0.16, 0.2), (0, WY, 0.1), STONE)
    L.box("step", (DW + 1.2, 0.9, SH), (0, WY - WT / 2 - 0.45, SH / 2), STONE)
    # Tiled hood over the gate: a beam out from the wall and a pitched tile hood on it, a ridge on top.
    L.box("hood_beam", (GW + 0.2, 0.5, 0.2), (0, WY - WT / 2 - 0.2, DH + 0.75), WOOD)
    y0, d = WY - WT / 2 - 0.7, WT + 1.4
    rise = _roof("hood_roof", 0, GW, y0, d, GH - 0.3)
    L.box("hood_ridge", (GW + 0.9, 0.3, 0.3), (0, y0 + d / 2, GH - 0.3 + rise + 0.1), TILE)
    # Gate leaves: shut flush in the opening, or the right one ajar onto the courtyard.
    lw = DW / 2
    _leaf(-lw, WY - 0.05, lw, 0.0)
    if variant in OPEN:
        _leaf(lw, WY + WT / 2, lw, 2.2)
    else:
        _leaf(0.0, WY - 0.05, lw, 0.0)


def _hall():
    # Main hall behind the courtyard: plaster body on a stone plinth, a dark wood band where the doors and
    # lattice windows of the missing house module go, a pitched tile roof with a ridge.
    cy = HY + HD / 2
    L.box("hall_body", (HW, HD, HH), (0, cy, HH / 2), PLASTER)
    L.box("hall_plinth", (HW + 0.05, HD + 0.05, 0.4), (0, cy, 0.2), STONE)
    L.box("hall_front", (HW - 2.4, 0.06, 2.6), (0, HY - 0.03, 1.7), WOOD)
    L.box("hall_eave_beam", (HW + 0.4, 0.3, 0.25), (0, HY - 0.15, HH - 0.12), WOOD)
    y0, d = HY - 0.8, HD + 1.6
    rise = _roof("hall_roof", 0, HW - 0.6, y0, d, HH)
    L.box("hall_ridge", (HW - 0.2, 0.35, 0.35), (0, y0 + d / 2, HH + rise + 0.1), TILE)
    # Horse-head gables: three stepped wall pieces at each end, each stepping above the roof slope,
    # each with its own tile cap and upturned end blocks.
    for s in (-1, 1):
        x = s * (HW / 2 + 0.15)
        for k, depth in enumerate((HD + 0.6, HD - 1.6, HD - 3.8)):
            top = HH + 0.6 + 0.9 * k
            L.box("gable", (0.3, depth, top), (x, cy, top / 2), PLASTER)
            L.box("gable_cap", (0.6, depth + 0.3, 0.22), (x, cy, top + 0.11), TILE)
            for e in (-1, 1):
                L.box("gable_head", (0.6, 0.35, 0.22), (x, cy + e * (depth / 2 + 0.1), top + 0.3), TILE)


def _town():
    # Neighbouring houses beside and behind the Shen house, plain massing.
    for i, cx in enumerate((-13.5, 13.5)):
        L.box("house_body", (8.0, 6.0, 3.8), (cx, 4.0, 1.9), PLASTER_OLD if i else PLASTER)
        _roof("house_roof", cx, 8.0, 0.4, 7.2, 3.8)
    for i, cx in enumerate((-8.0, 0.0, 8.0)):
        L.box("far_body", (7.6, 6.0, 5.2), (cx, 14.0, 2.6), PLASTER if i % 2 else PLASTER_OLD)
        _roof("far_roof", cx, 7.6, 10.4, 7.2, 5.2)


def _greenery():
    # Bushes at the foot of the wall.
    for x, r in ((-5.6, 0.3), (5.9, -0.8)):
        L.tone(L.load(L.CITY, "bush.gltf", (x, WY - WT / 2 - 0.6, 0), r, 1.0, tag="bush"), sat=0.7, val=0.8)


# variant: (camera location, look-at point, lens mm).
CAMS = {
    # Low and close on the gatehouse from the lane, a little to the right; the step in front is left clear in
    # the lower left third for the buyer, the gate and its tile hood fill the upper right.
    'illus.bf.any.house_offer': ((2.0, WY - 5.6, 1.45), (0.2, WY, 1.9), 30),
    # Three-quarter from down the lane: wall and gatehouse across the lower half, hall roof and both
    # horse-head gables against the sky above.
    'illus.es.old_house': ((-6.5, WY - 11.0, 2.0), (0.6, WY + 2.5, 3.0), 26),
}


def _lights(variant, toon):
    if variant in DUSK:
        # Late afternoon: low warm sun raking the wall from the left, cooler sky fill, a warm point where
        # the gate lantern will hang.
        L.world((0.62, 0.58, 0.56), 0.55)
        L.light('SUN', (0, 0, 8), 2.2, (1.0, 0.78, 0.52), rot=(math.radians(68), 0, math.radians(-55)))
        L.light('AREA', (0.0, WY - 6.0, 4.0), 90 if toon else 120, (0.80, 0.84, 0.95),
                rot=(math.radians(40), 0, 0), size=5)
        L.light('POINT', (1.3, WY - WT / 2 - 0.5, DH + 0.4), 30 if toon else 50, LANTERN, size=0.2)
    else:
        # Mild overcast day: soft sun from the front left, broad fill from the lane.
        L.world((0.78, 0.82, 0.86), 0.9)
        L.light('SUN', (0, 0, 8), 3.0, (1.0, 0.96, 0.88), rot=(math.radians(42), 0, math.radians(-30)))
        L.light('AREA', (0.0, WY - 7.0, 4.5), 140 if toon else 100, (0.98, 0.98, 0.95),
                rot=(math.radians(40), 0, 0), size=6)
    if variant in OPEN:
        # A little light in the courtyard so the open leaf is not a black slot.
        L.light('POINT', (0.0, WY + 1.5, 2.2), 40, (1.0, 0.94, 0.84), size=0.5)


def build(variant, toon=True):
    if variant not in VARIANTS:
        raise ValueError("unknown variant %s" % variant)
    _ground()
    _wall()
    _gatehouse(variant)
    _hall()
    _town()
    _greenery()
    L.camera(*CAMS[variant])
    _lights(variant, toon)
